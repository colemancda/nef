//  Copyright © 2019 The nef Authors.

import Foundation
import NefModels

public typealias Shell = (out: Console, run: PlaygroundShell)

public struct PlaygroundEnvironment {
    public let shell: Shell
    public let storage: FileSystem
    
    public init(console: Console, shell: PlaygroundShell, storage: FileSystem) {
        self.shell = (out: console, run: shell)
        self.storage = storage
    }
}
