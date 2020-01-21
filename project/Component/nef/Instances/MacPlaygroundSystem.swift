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
             playgrounds <- self.getPlaygrounds(in: xcworkspaces.get),
        yield: playgrounds.get)^
    }
    
    func pages(in playground: URL) -> IO<PlaygroundSystemError, NEA<URL>> {
        func extractPages(in playground: URL) -> IO<PlaygroundSystemError, [URL]> {
            IO<PlaygroundSystemError, String>.invoke {
                let xcplayground = playground.appendingPathComponent("contents.xcplayground")
                return try String(contentsOf: xcplayground)
            }.map { content in
                content.matches(pattern: "(?<=name=').*(?=')")
                       .map { page in playground.appendingPathComponent("Pages")
                                                .appendingPathComponent(page)
                                                .appendingPathExtension("xcplaygroundpage") }
            }^
        }
        
        func checkNumberOfPages(_ pages: [URL], playground: URL) -> IO<PlaygroundSystemError, [URL]> {
            IO.invoke {
                guard pages.count == 0 else { return pages }
                throw PlaygroundSystemError.pages()
            }.handleErrorWith { e in
                self.fileManager.contentsOfDirectoryIO(atPath: playground.appendingPathComponent("Pages").path)
                    .mapLeft { _ in e }
                    .foldM({ e in IO.raiseError(e)^  },
                           { files in files.count == 1 ? IO.pure([playground.appendingPathComponent("Pages").appendingPathComponent(files.first!)])^
                                                       : IO.raiseError(.pages(information: "not found pages in '\(playground.path)'"))^ })
            }^
        }
        
        func validatePages(_ pages: [URL], playground: URL) -> IO<PlaygroundSystemError, [URL]> {
            pages.map { $0.path }.allSatisfy(self.fileManager.fileExists)
                ? IO.pure(pages)^
                : IO.raiseError(.pages(information: "some pages are not linked properly to '\(playground.path)'"))^
        }
        
        func buildNEA(pages: [URL], playground: URL) -> IO<PlaygroundSystemError, NEA<URL>> {
            NEA<URL>.fromArray(pages).fold({ IO.raiseError(.pages(information: "not found pages in '\(playground.path)'")) },
                                           { nea in IO.pure(nea) })^
        }
        
        return extractPages(in: playground)
                .flatMap { pages in checkNumberOfPages(pages, playground: playground) }
                .flatMap { pages in validatePages(pages, playground: playground)   }
                .flatMap { pages in buildNEA(pages: pages, playground: playground) }^
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
    
    private func getPlaygrounds(in xcworkspaces: NEA<URL>) -> IO<PlaygroundSystemError, NEA<URL>> {
        func extractPlaygrounds(from xcworkspace: URL) -> IO<PlaygroundSystemError, [URL]> {
            IO<PlaygroundSystemError, String>.invoke {
                try String(contentsOf: xcworkspace.appendingPathComponent("contents.xcworkspacedata"))
            }.map { content in
                content.matches(pattern: "(?<=group:).*.playground(?=\")")
                       .map { playground in xcworkspace.deletingLastPathComponent().appendingPathComponent(playground) }
            }^
        }
        
        func validatePlaygrounds(_ playgrounds: [URL]) -> IO<PlaygroundSystemError, [URL]> {
            playgrounds.map { $0.path }.allSatisfy(self.fileManager.fileExists)
                ? IO.pure(playgrounds)^
                : IO.raiseError(.playgrounds(information: "some playgrounds are not linked properly"))^
        }
        
        func buildNEA(playgrounds: [URL]) -> IO<PlaygroundSystemError, NEA<URL>> {
            NEA<URL>.fromArray(playgrounds).fold({ IO.raiseError(.playgrounds(information: "can not find any playground in the workspace")) },
                                                 { nea in IO.pure(nea) })^
        }
        
        return xcworkspaces.all()
            .parFlatTraverse(extractPlaygrounds)
            .flatMap(validatePlaygrounds)
            .flatMap(buildNEA)^
    }
}