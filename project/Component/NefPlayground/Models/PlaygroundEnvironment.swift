//  Copyright © 2020 The nef Authors.

import Foundation
import NefCommon
import NefModels

public struct PlaygroundEnvironment {
    public let console: Console
    public let shell: PlaygroundShell
    public let playgroundSystem: PlaygroundSystem
    public let fileSystem: FileSystem
    
    public init(console: Console, shell: PlaygroundShell, playgroundSystem: PlaygroundSystem, fileSystem: FileSystem) {
        self.console = console
        self.shell = shell
        self.playgroundSystem = playgroundSystem
        self.fileSystem = fileSystem
    }
}