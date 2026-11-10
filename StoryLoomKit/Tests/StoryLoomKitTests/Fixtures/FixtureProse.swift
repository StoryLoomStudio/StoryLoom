// Filler prose for synthetic projects.
//
// Every word is invented from syllables or is a common English function word,
// and the generator is deterministic from its seed. Nothing here is, or is
// derived from, anyone's writing.

/// SplitMix64: small, fast, and identical on every run for the same seed.
nonisolated struct FixtureRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func int(_ range: Range<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.upperBound - range.lowerBound))
    }

    mutating func pick<T>(_ items: [T]) -> T { items[int(0..<items.count)] }

    mutating func chance(_ one: Int, in total: Int) -> Bool { int(0..<total) < one }
}

nonisolated enum FixtureProse {
    private static let onsets = ["b", "br", "d", "dr", "f", "g", "gl", "h", "k", "l", "m", "n", "p", "pr",
                                 "r", "s", "sh", "st", "t", "th", "v", "w", "z"]
    private static let vowels = ["a", "e", "i", "o", "u", "ae", "ia", "ou"]
    private static let codas = ["", "", "n", "r", "l", "s", "th", "k", "m", "nd", "rn"]
    private static let glue = ["the", "and", "of", "a", "in", "to", "was", "with", "over", "under", "that", "they"]

    /// An invented word of one to three syllables.
    static func word(_ rng: inout FixtureRandom) -> String {
        var result = ""
        for _ in 0..<rng.int(1..<4) {
            result += rng.pick(onsets) + rng.pick(vowels) + rng.pick(codas)
        }
        return result
    }

    static func capitalised(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst()
    }

    /// A two or three word title, capitalised.
    static func title(_ rng: inout FixtureRandom) -> String {
        (0..<rng.int(2..<4)).map { _ in capitalised(word(&rng)) }.joined(separator: " ")
    }

    /// One sentence. `names` are woven in now and then so mention indexes have
    /// something to find.
    static func sentence(_ rng: inout FixtureRandom, names: [String]) -> String {
        var parts: [String] = []
        for _ in 0..<rng.int(6..<15) {
            parts.append(rng.chance(1, in: 3) ? rng.pick(glue) : word(&rng))
        }
        if !names.isEmpty, rng.chance(1, in: 3) {
            parts.insert(rng.pick(names), at: rng.int(0..<parts.count))
        }
        var text = parts.joined(separator: " ")
        text = capitalised(text)
        let ending = rng.pick([".", ".", ".", ".", "?", "!"])
        return text + ending
    }

    static func paragraph(_ rng: inout FixtureRandom, names: [String], sentences: Int? = nil) -> String {
        let count = sentences ?? rng.int(3..<7)
        return (0..<count).map { _ in sentence(&rng, names: names) }.joined(separator: " ")
    }
}
