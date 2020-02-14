//  Copyright © 2020 The nef Authors.

import Foundation

public enum PlaygroundSystemError: Error {
    case xcworkspaces(information: String = "")
    case playgrounds(information: String = "")
    case pages(information: String = "")
}

extension PlaygroundSystemError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .xcworkspaces(let information):
            return "workspaces operation \(information.isEmpty ? "" : "(\(information))")"
        case .playgrounds(let information):
            return "playgrounds operation \(information.isEmpty ? "" : "(\(information))")"
        case .pages(let information):
            return "pages operation \(information.isEmpty ? "" : "(\(information))")"
        }
    }
}
