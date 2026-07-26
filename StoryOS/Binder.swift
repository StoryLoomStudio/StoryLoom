//
//  Binder.swift
//  StoryLoom
//
//  The shape of the manuscript, as a tree.
//
//  This replaces an approach that could not do the job. The outline used to be
//  *derived*: every scene carried a `volume` and a `chapter` string, and folders
//  were runs of scenes that happened to agree. That buys you a two-level outline
//  for free and then stops dead — there is no third level, no fourth, and above
//  all no empty folder, because a folder with nothing in it is a run of no
//  scenes and therefore does not exist. A writer who makes "Part Three" before
//  writing Part Three found nothing happened.
//
//  So the structure is now a thing in its own right. A folder is an item, not a
//  coincidence; it has an identity, it can be renamed, nested, dragged, and left
//  empty for as long as the author likes. This is what a binder is, and it is
//  why every application of this kind has one.
//
//  The prose does not live here. A `.document` item holds an id and nothing
//  else; the words stay in `StoryProject.documents` and on disk as Markdown.
//  The tree says *where things are*, never *what they say*, so a corrupted or
//  missing binder costs an author their outline and never a sentence.
//

import Foundation

nonisolated struct BinderItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: Kind
    /// What this group *means* to the writer. Ignored by documents.
    ///
    /// Semantic, never structural. A Part is not required to sit inside a Volume
    /// and a Chapter is not required to sit inside a Part — the tree does not
    /// care, and neither does anything below this line. The type changes the
    /// word on the menu and the drawing on the row; it never constrains where
    /// the row is allowed to be. That is the whole point: a novelist who wants
    /// Chapter → Scene and nothing else should not have to decline two tiers.
    var group: GroupKind
    /// A group's name. Documents ignore this and use their own title, so the
    /// name of a scene cannot drift from the name of the row pointing at it.
    var name: String
    var children: [BinderItem]

    nonisolated enum Kind: String, Codable, Hashable, Sendable {
        case folder
        case document
    }

    nonisolated init(
        id: UUID = UUID(),
        kind: Kind,
        group: GroupKind = .folder,
        name: String = "",
        children: [BinderItem] = []
    ) {
        self.id = id
        self.kind = kind
        self.group = group
        self.name = name
        self.children = children
    }

    private enum CodingKeys: String, CodingKey { case id, kind, group, name, children }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(Kind.self, forKey: .kind)
        // Absent in binders written before groups had a meaning: those were all
        // plain folders, which is exactly what the default says.
        group = try c.decodeIfPresent(GroupKind.self, forKey: .group) ?? .folder
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        children = try c.decodeIfPresent([BinderItem].self, forKey: .children) ?? []
    }

    nonisolated static func folder(_ name: String, _ children: [BinderItem] = [], group: GroupKind = .folder) -> BinderItem {
        BinderItem(kind: .folder, group: group, name: name, children: children)
    }

    /// A leaf pointing at a document. The item's id *is* the document's id, so
    /// there is no second identifier to keep in step.
    nonisolated static func document(_ id: UUID) -> BinderItem {
        BinderItem(id: id, kind: .document)
    }

    var isFolder: Bool { kind == .folder }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled \(group.title)" : trimmed
    }
}

/// The four things a group can be. Only the last is a container with no
/// narrative meaning; the other three are the words novelists already use.
nonisolated enum GroupKind: String, CaseIterable, Codable, Hashable, Sendable {
    case volume
    case part
    case chapter
    case folder

    var title: String {
        switch self {
        case .volume: "Volume"
        case .part: "Part"
        case .chapter: "Chapter"
        case .folder: "Folder"
        }
    }

    var glyph: Glyph {
        switch self {
        case .volume: .volume
        case .part: .part
        case .chapter: .chapter
        case .folder: .folder
        }
    }
}

// MARK: - Reading the tree

/// `nonisolated` throughout: `StoryProject` is a `Sendable` value type that
/// reconciles its own tree during `init(from:)`, which is not on the main actor.
/// Under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` an unannotated extension is
/// main-actor bound, which makes that call a warning today and an error under
/// Swift 6 language mode. None of this touches UI, so none of it needs the actor.
nonisolated extension Array where Element == BinderItem {

    /// Every document id, in reading order. This is the manuscript's running
    /// order, and the only definition of it.
    var documentIDs: [UUID] {
        flatMap { item -> [UUID] in
            switch item.kind {
            case .document: [item.id]
            case .folder: item.children.documentIDs
            }
        }
    }

    /// Every item id, folders included.
    var allIDs: Set<UUID> {
        reduce(into: Set<UUID>()) { set, item in
            set.insert(item.id)
            set.formUnion(item.children.allIDs)
        }
    }

    func find(_ id: UUID) -> BinderItem? {
        for item in self {
            if item.id == id { return item }
            if let found = item.children.find(id) { return found }
        }
        return nil
    }

    /// True when `ancestor` contains `id` at any depth. Used to refuse a drag
    /// that would put a folder inside itself — which is the one drop that turns
    /// a tree into a lost subtree.
    func contains(_ id: UUID, under ancestor: UUID) -> Bool {
        guard let item = find(ancestor) else { return false }
        return item.children.allIDs.contains(id)
    }

    /// Where an item sits: its parent (nil at the root) and its index there.
    ///
    /// Resolved *after* a removal when a drag is being applied, because taking
    /// the item out shifts every sibling below it — computing the destination
    /// first is how a drop lands one row off.
    func location(of id: UUID) -> (parent: UUID?, index: Int)? {
        func search(_ items: [BinderItem], parent: UUID?) -> (UUID?, Int)? {
            for (index, item) in items.enumerated() {
                if item.id == id { return (parent, index) }
                if let found = search(item.children, parent: item.id) { return found }
            }
            return nil
        }
        return search(self, parent: nil)
    }

    // MARK: Editing

    /// Removes an item wherever it is, returning it.
    mutating func remove(_ id: UUID) -> BinderItem? {
        for index in indices {
            if self[index].id == id {
                return remove(at: index)
            }
            if let found = self[index].children.remove(id) { return found }
        }
        return nil
    }

    /// Inserts `item` into `parent` (or the root when nil) at `index`.
    mutating func insert(_ item: BinderItem, into parent: UUID?, at index: Int?) {
        guard let parent else {
            place(item, at: index)
            return
        }
        for position in indices {
            if self[position].id == parent, self[position].isFolder {
                self[position].children.place(item, at: index)
                return
            }
            self[position].children.insert(item, into: parent, at: index)
            if self[position].children.allIDs.contains(item.id) { return }
        }
    }

    /// Append when the index is missing or out of range, rather than trapping.
    /// A drop can land past the end of a list that shrank while it was in
    /// flight, and losing the item would be worse than putting it last.
    mutating func place(_ item: BinderItem, at index: Int?) {
        if let index, index >= 0, index <= count {
            insert(item, at: index)
        } else {
            append(item)
        }
    }

    mutating func setGroup(_ id: UUID, to group: GroupKind) {
        for index in indices {
            if self[index].id == id {
                self[index].group = group
                return
            }
            self[index].children.setGroup(id, to: group)
        }
    }

    mutating func rename(_ id: UUID, to name: String) {
        for index in indices {
            if self[index].id == id {
                self[index].name = name
                return
            }
            self[index].children.rename(id, to: name)
        }
    }

    /// Drops any leaf whose document no longer exists, and adds leaves for
    /// documents the tree has never heard of.
    ///
    /// The prose is the truth and the tree is a convenience. A scene that
    /// somehow escapes the binder — an external editor dropping a file into
    /// `manuscript/`, a merge going sideways — must still appear, or the author
    /// loses work they can see on disk. Strays land at the end, visibly.
    mutating func reconcile(with documentIDs: [UUID]) {
        let known = Set(documentIDs)
        prune(keeping: known)
        let present = Set(self.documentIDs)
        for id in documentIDs where !present.contains(id) {
            append(.document(id))
        }
    }

    private mutating func prune(keeping known: Set<UUID>) {
        for index in indices.reversed() {
            if self[index].isFolder {
                self[index].children.prune(keeping: known)
            } else if !known.contains(self[index].id) {
                remove(at: index)
            }
        }
    }
}
