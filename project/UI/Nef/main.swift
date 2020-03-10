//  Copyright © 2020 The nef Authors.

import Foundation
import CLIKit
import ArgumentParser
import Bow
import BowEffects

struct NefCommand: ConsoleCommand {
    
    static var configuration = CommandConfiguration(commandName: "nef",
                                                    abstract: "💊 steroids for Xcode Playgrounds",
                                                    subcommands: [VersionCommand.self,
                                                                  CompilerCommand.self,
                                                                  CleanCommand.self,
                                                                  PlaygroundCommand.self,
                                                                  PlaygroundBookCommand.self,
                                                                  MarkdownCommand.self,
                                                                  JekyllCommand.self,
                                                                  CarbonCommand.self])
    
    func main() -> IO<Console.Error, Void> {
        fatalError("should be invoked a subcommand")
    }
}

// #: - MAIN <launcher>
CompilerCommand.commandName = "compile"
CleanCommand.commandName = "clean"
PlaygroundCommand.commandName = "playground"
PlaygroundBookCommand.commandName = "ipad"
MarkdownCommand.commandName = "markdown"
JekyllCommand.commandName = "jekyll"
CarbonCommand.commandName = "carbon"

CommandLineTool<NefCommand>.unsafeRunSync()
