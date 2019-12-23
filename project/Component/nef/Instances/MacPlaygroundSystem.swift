//  Copyright © 2019 The nef Authors.

import Foundation
import NefCommon
import Bow
import BowEffects

class MacPlaygroundSystem: PlaygroundSystem {
    
    private let fileManager = FileManager.default
    
    func playgrounds(at folder: URL) -> IO<PlaygroundSystemError, NEA<URL>> {
        let xcworkspaces = IOPartial<PlaygroundSystemError>.var(NEA<URL>.self)
        let playgrounds = IOPartial<PlaygroundSystemError>.var(NEA<URL>.self)
        
        return binding(
            xcworkspaces <- self.xcworkspaces(at: folder),
             playgrounds <- self.readPlaygrounds(in: xcworkspaces.get),
        yield: playgrounds.get)^
    }
    
    func name(_ playground: URL) -> IO<PlaygroundSystemError, String> {
        fatalError()
    }
    
    func unique(playground: URL, in path: URL) -> IO<PlaygroundSystemError, URL> {
        fatalError()
    }
    
    func pages(in playground: URL) -> IO<PlaygroundSystemError, NEA<URL>> {
        fatalError()
    }
    
    // MARK: - helpers
    private func xcworkspaces(at folder: URL) -> IO<PlaygroundSystemError, NEA<URL>> {
        func isDependency(xcworkspace: URL) -> Bool {
            return xcworkspace.path.contains("/Pods/") || xcworkspace.path.contains("/Carthage/")
        }
        
        guard let enumerator = fileManager.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return IO.raiseError(PlaygroundSystemError.playgrounds())^
        }
        
        let xcworkspaces = enumerator.compactMap { file -> URL? in
            guard let fileURL = file as? URL, fileURL.pathExtension == "pbxproj" else { return nil }
            let xcodeproj = fileURL.deletingLastPathComponent()
            let xcworkspace = xcodeproj.deletingPathExtension().appendingPathExtension("xcworkspace")
            return fileManager.fileExists(atPath: xcworkspace.path) && !isDependency(xcworkspace: xcworkspace) ? xcworkspace : nil
        }
        
        return NEA<URL>.fromArray(xcworkspaces)
                       .fold({ IO.raiseError(.playgrounds(information: "not found any valid workspace in '\(folder.path)'")) },
                             { nea in IO.pure(nea) })^
    }
    
    private func readPlaygrounds(in xcworkspaces: NEA<URL>) -> IO<PlaygroundSystemError, NEA<URL>> {
        func readPlaygrounds(xcworkspace: URL) -> IO<PlaygroundSystemError, [URL]> {
            IO<PlaygroundSystemError, String>.invoke { try String(contentsOf: xcworkspace.appendingPathComponent("contents.xcworkspacedata")) }
                .map { content in
                    content.matches(pattern: "(?<=group:).*.playground(?=\")")
                           .map { playground in xcworkspace.deletingLastPathComponent().appendingPathComponent(playground) }
                }.flatMap { playgrounds in
                    playgrounds.map { $0.path }.allSatisfy(self.fileManager.fileExists)
                        ? IO.pure(playgrounds)
                        : IO.raiseError(.playgrounds(information: "some playgrounds are not linked properly"))
                }^
        }
        
        return xcworkspaces.all()
            .parFlatTraverse(readPlaygrounds)^
            .flatMap { array in
                NEA<URL>.fromArray(array).fold({ IO.raiseError(.playgrounds(information: "can not find any playground in the workspace")) },
                                               { nea in IO.pure(nea) })
            }^
    }
}


extension String {
    func matches(pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        return regex.matches(in: self, range: NSRange(location: 0, length: self.count))
                    .map { match in NSString(string: "\(self)").substring(with: match.range) as String }
    }
}
