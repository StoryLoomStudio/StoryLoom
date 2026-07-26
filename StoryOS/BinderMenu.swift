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
    static func moveTo(_ id: UUID, in workspace: WorkspaceModel) -> BinderMenuEntry {
        .submenu(
            "Move To",
            [
                .item("Manuscript") { workspace.moveBinderItem(id, into: nil, at: nil) },
                .separator,
            ] + workspace.groupDestinations.map { destination in
                .item(
                    String(repeating: "   ", count: destination.depth) + destination.item.displayName,
                    isEnabled: destination.id != id && !workspace.project.binder.contains(destination.id, under: id)
                ) { workspace.moveBinderItem(id, into: destination.id, at: nil) }
            }
        )
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
            let item = NSMenuItem()
            item.view = DestructiveMenuItemView(title: title, action: action)
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

// MARK: - The destructive row

/// A menu row that paints itself, so it can be red on grey.
///
/// Everything AppKit does for an ordinary item — the highlight, the click, the
/// text — a view-based item owes itself. That is the price of the one thing it
/// buys: a highlight colour of its own.
private final class DestructiveMenuItemView: NSView {
    private let title: String
    private let action: () -> Void
    private var tracking: NSTrackingArea?

    /// The system highlight is inset from the menu's edges and rounded; these
    /// match it so the grey lands where the blue would have.
    private static let inset: CGFloat = 5
    private static let radius: CGFloat = 4
    private static let rowHeight: CGFloat = 22
    /// Where AppKit starts an item's title when nothing in the menu has a
    /// checkmark or an image. Not a queryable metric — if this row's text ever
    /// looks a pixel out against Rename above it, this is the number to nudge.
    private static let titleInset: CGFloat = 14

    init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: Self.rowHeight))
        // The menu is as wide as its widest row, and this row has to be able to
        // ask for width like the others — then stretch to whatever the menu
        // settles on, so the highlight spans it.
        autoresizingMask = [.width]
        frame.size = intrinsicContentSize
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var attributes: [NSAttributedString.Key: Any] {
        [.font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.systemRed]
    }

    override var intrinsicContentSize: NSSize {
        let text = (title as NSString).size(withAttributes: attributes)
        return NSSize(width: Self.titleInset * 2 + text.width, height: Self.rowHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        if enclosingMenuItem?.isHighlighted == true {
            // The grey macOS itself uses for a selection that hasn't got focus —
            // muted by construction, and it follows light and dark without being
            // told.
            NSColor.unemphasizedSelectedContentBackgroundColor.setFill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: Self.inset, dy: 0),
                xRadius: Self.radius,
                yRadius: Self.radius
            ).fill()
        }

        let text = title as NSString
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: Self.titleInset, y: (bounds.height - size.height) / 2),
            withAttributes: attributes
        )
    }

    override func mouseUp(with event: NSEvent) {
        enclosingMenuItem?.menu?.cancelTracking()
        // After the menu is gone, not during. Deleting the selected scene moves
        // focus, and doing that inside a live menu-tracking loop is how a rename
        // field ends up opening behind a menu that hasn't closed yet.
        DispatchQueue.main.async { [action] in action() }
    }

    // `isHighlighted` is the truth about hover, and it changes without telling
    // the view to redraw. This is what asks.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { needsDisplay = true }
    override func mouseExited(with event: NSEvent) { needsDisplay = true }
}

// MARK: - Attaching one to a row

extension View {
    /// Right-click opens `entries`, built at the moment of the click.
    ///
    /// Late is the point: `Move To` lists the folders that exist now, and
    /// `Change Status` greys the status the scene is already at.
    func binderContextMenu(
        onOpen: @escaping () -> Void = {},
        entries: @escaping () -> [BinderMenuEntry]
    ) -> some View {
        overlay(BinderContextMenu(onOpen: onOpen, entries: entries))
    }
}

private struct BinderContextMenu: NSViewRepresentable {
    let onOpen: () -> Void
    let entries: () -> [BinderMenuEntry]

    func makeNSView(context: Context) -> RightClickCatcher {
        let view = RightClickCatcher()
        view.onOpen = onOpen
        view.entries = entries
        return view
    }

    func updateNSView(_ view: RightClickCatcher, context: Context) {
        view.onOpen = onOpen
        view.entries = entries
    }
}

/// Sits over a binder row and is invisible to everything except a right-click.
///
/// It has to be on top to see the click before the row does, and a view on top
/// of a row that also took left-clicks would cost the row its selection, its
/// drag, and the double-click that starts a rename. So it takes the two events
/// that open a menu and declines every other one by failing hit-testing.
private final class RightClickCatcher: NSView {
    var onOpen: (() -> Void)?
    var entries: (() -> [BinderMenuEntry])?

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let entries else { return nil }
        // Right-clicking a row selects it, the way it did when SwiftUI owned
        // this menu — a menu that names one chapter should not float over
        // another one that stayed highlighted.
        onOpen?()
        return BinderMenu.build(entries())
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent else { return nil }
        switch event.type {
        case .rightMouseDown, .rightMouseUp:
            return super.hitTest(point)
        case .leftMouseDown, .leftMouseUp:
            return event.modifierFlags.contains(.control) ? super.hitTest(point) : nil
        default:
            return nil
        }
    }
}
