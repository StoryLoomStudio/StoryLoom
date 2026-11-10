//
//  BinderMenu.swift
//  StoryLoom
//
//  The binder's context menus, built in AppKit.
//
//  They were SwiftUI `.contextMenu` blocks and would have stayed that way but
//  for one item. "Move to Trash" is the only entry in these menus that throws
//  away an evening's work, and it read exactly like Rename: `role: .destructive`
//  is correct semantics that AppKit draws no differently. Colouring the title
//  red fixes that until the pointer lands on it, at which point the row fills
//  with the accent colour and a fixed red sits on blue — a fixed title colour is
//  precisely the thing that cannot invert to white the way menu text does.
//
//  There is one hook for a menu row that paints itself: `NSMenuItem.view`. A
//  view-based item draws its own highlight, so it can be red on a muted grey
//  while its neighbours stay black on the accent. SwiftUI does not expose it, so
//  the menus are described here as data and built as an `NSMenu` — every
//  ordinary row a plain `NSMenuItem` that behaves exactly as it did, and only
//  the destructive one carrying a view.
//

import AppKit
import SwiftUI

// MARK: - Description

/// One row of a binder menu.
///
/// The menus stay declarative at the call site — the rows are still written as a
/// list in the order they appear — and this is the vocabulary they are written
/// in. `destructive` is a separate case rather than a flag on `item` because it
/// is a different kind of row underneath, not an ordinary one wearing a colour.
enum BinderMenuEntry {
    case item(String, isEnabled: Bool = true, action: () -> Void)
    case submenu(String, [BinderMenuEntry])
    case separator
    case destructive(String, action: () -> Void)
}

@MainActor
extension BinderMenuEntry {
    /// The same destination list belongs on both scene and group rows. Keeping
    /// it here makes the AppKit menu just as current as the old SwiftUI `Menu`:
    /// it is evaluated when the author opens the context menu, not when the
    /// binder last rendered.
    static func moveTo(_ ids: [UUID], in workspace: WorkspaceModel) -> BinderMenuEntry {
        let moving = Set(ids)
        var entries: [BinderMenuEntry] = [
            .item("Manuscript") { workspace.moveBinderItems(ids, into: nil, at: nil) },
            .separator,
        ]
        for destination in workspace.groupDestinations {
            let indent = String(repeating: "   ", count: destination.depth)
            // A group cannot be moved into itself or into anything it contains,
            // and with several selected it takes only one of them to rule a
            // destination out.
            let swallowsItsOwn = ids.contains { id in
                workspace.project.binder.contains(destination.id, under: id)
            }
            entries.append(
                .item(
                    indent + destination.item.displayName,
                    isEnabled: !moving.contains(destination.id) && !swallowsItsOwn
                ) { workspace.moveBinderItems(ids, into: destination.id, at: nil) }
            )
        }
        return .submenu("Move To", entries)
    }

    static func moveTo(_ id: UUID, in workspace: WorkspaceModel) -> BinderMenuEntry {
        moveTo([id], in: workspace)
    }
}

@MainActor
extension Array where Element == BinderMenuEntry {
    /// The menu for a selection of several rows.
    ///
    /// It offers what the single-row menus offer and nothing new: the same four
    /// verbs, aimed at everything highlighted. Rename is the one that cannot
    /// come along — six rows have six names — and it is the one an author would
    /// not have reached for anyway.
    ///
    /// The counted titles are deliberate. "Move to Trash" under a right-click
    /// that happened to land inside a selection reads as being about the row
    /// beneath the pointer; "Move 6 Items to Trash" cannot be misread.
    static func selection(in workspace: WorkspaceModel) -> [BinderMenuEntry] {
        let ids = workspace.binderSelectionRoots
        guard !ids.isEmpty else { return [] }

        let scenes = ids.filter { workspace.project.document($0) != nil }
        let groups = ids.filter { workspace.project.binder.find($0)?.isFolder == true }
        // A chapter and a scene inside it are two selected rows and one thing to
        // act on, so the count comes from what will actually move — and when
        // that collapses to one, the titles read as the single-row menu's do.
        let counted = ids.count == 1 ? "" : " \(ids.count) Items"

        var entries: [BinderMenuEntry] = [
            .item("Duplicate" + counted) { workspace.duplicateBinderItems(ids) },
            .moveTo(ids, in: workspace),
        ]

        if !scenes.isEmpty {
            entries.append(.submenu("Change Status", DocumentStatus.allCases.map { status in
                .item(status.title) { workspace.setStatus(status, for: scenes) }
            }))
        }
        if !groups.isEmpty {
            entries.append(.submenu("Change Type", GroupKind.allCases.map { kind in
                .item(kind.title) { workspace.changeGroupType(groups, to: kind) }
            }))
        }

        entries.append(.separator)
        entries.append(.destructive("Move" + counted + " to Trash") {
            workspace.trashBinderItems(ids)
        })
        return entries
    }
}

// MARK: - Construction

@MainActor
enum BinderMenu {
    static func build(_ entries: [BinderMenuEntry]) -> NSMenu {
        let menu = NSMenu()
        // Every row states its own `isEnabled`. Left on, AppKit would ask a
        // responder chain that knows nothing about these closures and grey out
        // the lot.
        menu.autoenablesItems = false
        for entry in entries { menu.addItem(item(for: entry)) }
        return menu
    }

    private static func item(for entry: BinderMenuEntry) -> NSMenuItem {
        switch entry {
        case .separator:
            return .separator()

        case let .item(title, isEnabled, action):
            let item = NSMenuItem(title: title, action: #selector(MenuAction.fire), keyEquivalent: "")
            let handler = MenuAction(action)
            item.target = handler
            // `target` is unowned. The menu is built fresh on every right-click
            // and nothing else holds the handler, so it has to be parked on the
            // item or the closure dies before the author picks anything.
            item.representedObject = handler
            item.isEnabled = isEnabled
            return item

        case let .submenu(title, entries):
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = build(entries)
            return item

        case let .destructive(title, action):
            let item = NSMenuItem(title: title, action: #selector(MenuAction.fire), keyEquivalent: "")
            let handler = MenuAction(action)
            item.target = handler
            item.representedObject = handler
            item.attributedTitle = NSAttributedString(
                string: title,
                attributes: [.foregroundColor: NSColor.systemRed]
            )
            return item
        }
    }
}

/// Carries a closure to something that can only call a selector.
@MainActor
private final class MenuAction: NSObject {
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    @objc func fire() { action() }
}

// MARK: - Attaching one to a row

extension View {
    /// The mouse handling a binder row has to do in AppKit rather than SwiftUI.
    ///
    /// Two clicks never reach SwiftUI here. A right-click, because the menu it
    /// opens has a row that paints itself — that is the whole story above. And a
    /// ⌘- or ⇧-click, because `List` answers those with its own idea of multiple
    /// selection at the same instant the workspace answers with the outline's:
    /// two handlers, one click, and a ⌘-click that adds a row and takes it
    /// straight back out again. Catching the event here means exactly one of
    /// them ever sees it.
    ///
    /// `entries` is called at the moment of the click, and late is the point:
    /// `Move To` lists the folders that exist now, and a menu opened inside a
    /// selection of several is a different menu.
    func binderRowMouse(id: UUID, entries: @escaping () -> [BinderMenuEntry]) -> some View {
        modifier(BinderRowMouse(id: id, entries: entries))
    }
}

private struct BinderRowMouse: ViewModifier {
    let id: UUID
    let entries: () -> [BinderMenuEntry]

    @EnvironmentObject private var workspace: WorkspaceModel
    @Environment(\.binderVisibleOrder) private var order

    func body(content: Content) -> some View {
        content.overlay(
            BinderRowMouseCatcher(
                onMenu: {
                    workspace.presentBinderMenu(for: id)
                    return BinderMenu.build(entries())
                },
                onModifierClick: { modifiers in
                    workspace.clickBinderRow(id, modifiers: modifiers, in: order)
                }
            )
        )
    }
}

private struct BinderRowMouseCatcher: NSViewRepresentable {
    let onMenu: () -> NSMenu
    let onModifierClick: (NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> RowMouseCatcher {
        let view = RowMouseCatcher()
        view.onMenu = onMenu
        view.onModifierClick = onModifierClick
        return view
    }

    func updateNSView(_ view: RowMouseCatcher, context: Context) {
        view.onMenu = onMenu
        view.onModifierClick = onModifierClick
    }
}

/// Sits over a binder row and is invisible to everything except the clicks it
/// is there for.
///
/// It has to be on top to see a click before the row does, and a view on top of
/// a row that took *every* left-click would cost the row its selection, its
/// drag, and the double-click that starts a rename. So it takes the clicks that
/// open a menu or change a multiple selection, and declines every other one by
/// failing hit-testing — a plain click goes to the row exactly as before.
private final class RowMouseCatcher: NSView {
    var onMenu: (() -> NSMenu)?
    var onModifierClick: ((NSEvent.ModifierFlags) -> Void)?

    /// The modifiers this view answers for. Control is not among them: AppKit
    /// turns a control-click into `menu(for:)` by itself, and taking the event
    /// first would stop it doing so.
    private static let claimed: NSEvent.ModifierFlags = [.command, .shift]

    override func menu(for event: NSEvent) -> NSMenu? {
        // Right-clicking a row selects it, the way it did when SwiftUI owned
        // this menu — a menu that names one chapter should not float over
        // another one that stayed highlighted.
        onMenu?()
    }

    override func mouseDown(with event: NSEvent) {
        let modifiers = event.modifierFlags
        guard !modifiers.contains(.control) else {
            // Left to AppKit, which opens the context menu from it.
            super.mouseDown(with: event)
            return
        }
        onModifierClick?(modifiers)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent else { return nil }
        switch event.type {
        case .rightMouseDown, .rightMouseUp:
            return super.hitTest(point)
        case .leftMouseDown, .leftMouseUp:
            let modifiers = event.modifierFlags
            guard modifiers.contains(.control) || !modifiers.isDisjoint(with: Self.claimed) else { return nil }
            return super.hitTest(point)
        default:
            return nil
        }
    }
}
