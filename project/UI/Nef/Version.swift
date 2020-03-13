//  Copyright © 2020 The nef Authors.

import Foundation
import CLIKit
import ArgumentParser
import nef
import Bow
import BowEffects

public struct VersionCommand: ParsableCommand {
    public static var commandName: String = "version"
    public static var configuration = CommandConfiguration(commandName: commandName,
                                                    abstract: "Get the build's version number")
    
    public init() {}
    
    public func run() throws {
        try nef.Version.info()
                .flatMap { version in Console.default.print(message: "Build's version number: \(version)", terminator: " ") }^
                .unsafeRunSync()
    }
}
