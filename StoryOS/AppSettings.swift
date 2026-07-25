//
//  AppSettings.swift
//  StoryLoom
//
//  Personal workspace preferences. These are local to this machine and never
//  written into the portable project: how you like to see the page is not part
//  of the novel (12-UI, "Layout adaptability").
//

import Combine
import SwiftUI

nonisolated enum PageViewMode: String, CaseIterable, Identifiable, Sendable {
    case continuous
    case page

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .continuous: "Continuous View"
        case .page: "Page View"
        }
    }
}

nonisolated enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case light
    case dark
    case system

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "Light (Default)"
        case .dark: "Dark"
        case .system: "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

    var symbolName: String {
        switch self {
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        case .system: "circle.lefthalf.filled"
        }
    }

    /// The next state in the cycle, so one button can reach all three.
    var next: AppAppearance {
        switch self {
        case .light: .dark
        case .dark: .system
        case .system: .light
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Page
    @Published var proseFace: ProseFace { didSet { store(proseFace.rawValue, "proseFace") } }
    @Published var proseSize: Double { didSet { store(proseSize, "proseSize") } }
    @Published var lineHeight: LineHeight { didSet { store(lineHeight.rawValue, "lineHeight") } }
    @Published var paragraphLayout: ParagraphLayout { didSet { store(paragraphLayout.rawValue, "paragraphLayout") } }
    @Published var measure: Measure { didSet { store(measure.rawValue, "measure") } }
    @Published var readingTheme: ReadingTheme { didSet { store(readingTheme.rawValue, "readingTheme") } }
    @Published var appearance: AppAppearance { didSet { store(appearance.rawValue, "appearance") } }
    @Published var viewMode: PageViewMode { didSet { store(viewMode.rawValue, "viewMode") } }

    // Composition
    @Published var showsFormatBar: Bool { didSet { store(showsFormatBar, "showsFormatBar") } }
    @Published var focusDepth: FocusDepth { didSet { store(focusDepth.rawValue, "focusDepth") } }
    @Published var typewriter: Bool { didSet { store(typewriter, "typewriter") } }
    @Published var highlightsDialogue: Bool { didSet { store(highlightsDialogue, "highlightsDialogue") } }

    // Text services
    @Published var checksSpelling: Bool { didSet { store(checksSpelling, "checksSpelling") } }
    @Published var checksGrammar: Bool { didSet { store(checksGrammar, "checksGrammar") } }
    @Published var smartQuotes: Bool { didSet { store(smartQuotes, "smartQuotes") } }
    @Published var smartDashes: Bool { didSet { store(smartDashes, "smartDashes") } }

    // Behaviour
    @Published var reopensLastProject: Bool { didSet { store(reopensLastProject, "reopensLastProject") } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        func read<T>(_ key: String, _ fallback: T) -> T {
            defaults.object(forKey: Self.prefix + key) as? T ?? fallback
        }
        func readEnum<T: RawRepresentable>(_ key: String, _ fallback: T) -> T where T.RawValue == String {
            guard let raw = defaults.string(forKey: Self.prefix + key) else { return fallback }
            return T(rawValue: raw) ?? fallback
        }

        proseFace = readEnum("proseFace", ProseFace.newYork)
        proseSize = read("proseSize", 17.0)
        lineHeight = readEnum("lineHeight", LineHeight.normal)
        paragraphLayout = readEnum("paragraphLayout", ParagraphLayout.spaced)
        measure = readEnum("measure", Measure.comfortable)
        readingTheme = readEnum("readingTheme", ReadingTheme.paper)
        appearance = readEnum("appearance", AppAppearance.light)
        viewMode = readEnum("viewMode", PageViewMode.page)

        showsFormatBar = read("showsFormatBar", true)
        focusDepth = readEnum("focusDepth", FocusDepth.off)
        typewriter = read("typewriter", false)
        highlightsDialogue = read("highlightsDialogue", false)

        checksSpelling = read("checksSpelling", true)
        checksGrammar = read("checksGrammar", false)
        smartQuotes = read("smartQuotes", true)
        smartDashes = read("smartDashes", true)

        reopensLastProject = read("reopensLastProject", true)
    }

    /// The resolved page, handed to the editor so it never reads settings itself.
    func proseStyle(appearance systemAppearance: ColorScheme) -> ProseStyle {
        ProseStyle(
            face: proseFace,
            size: proseSize,
            lineHeight: lineHeight,
            paragraphLayout: paragraphLayout,
            theme: readingTheme,
            appearance: self.appearance.colorScheme ?? systemAppearance,
            measure: measure,
            focus: focusDepth,
            typewriter: typewriter,
            highlightsDialogue: highlightsDialogue,
            viewMode: viewMode
        )
    }

    func resetPage() {
        proseFace = .newYork
        proseSize = 17
        lineHeight = .normal
        paragraphLayout = .spaced
        measure = .comfortable
        readingTheme = .paper
    }

    private static let prefix = "storyloom."

    private func store(_ value: Any, _ key: String) {
        defaults.set(value, forKey: Self.prefix + key)
    }
}
