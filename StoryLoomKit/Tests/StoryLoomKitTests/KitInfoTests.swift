import Testing
@testable import StoryLoomKit

@Suite("Package skeleton")
struct KitInfoTests {
    @Test("The package reports a semantic version")
    func versionIsSemantic() {
        let parts = KitInfo.version.split(separator: ".")
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { Int($0) != nil })
    }
}
