import ArgumentParser
import StoryLoomKit

struct StoryLoom: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "storyloom",
        abstract: "Work with a StoryLoom project from the shell.",
        version: KitInfo.version
    )
}

StoryLoom.main()
