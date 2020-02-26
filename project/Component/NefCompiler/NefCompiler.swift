//  Copyright © 2020 The nef Authors.

import Foundation
import NefCommon
import NefModels
import NefCore
import NefRender

import Bow
import BowEffects

public struct Compiler {
    public typealias Environment = RenderCompilerEnvironment<String>
    typealias RenderingOutput = NefCommon.RenderingOutput<String>
    typealias PlaygroundOutput  = NefCommon.PlaygroundOutput<String>
    typealias PlaygroundsOutput = NefCommon.PlaygroundsOutput<String>
    
    public init() {}
    
    public func nefPlayground(_ nefPlayground: NefPlaygroundURL, cached: Bool) -> EnvIO<Environment, RenderError, Void> {
        let rendered = EnvIO<Environment, RenderError, PlaygroundsOutput>.var()
        
        return binding(
            rendered <- self.renderPlaygrounds(atFolder: nefPlayground.appending(.contentFiles)),
                     |<-self.buildPlaygrounds(rendered.get, atNefPlayground: nefPlayground, cached: cached),
        yield: ())^
    }
    
    // MARK: private <renders>
    private func renderPlayground(_ playground: URL) -> EnvIO<Environment, RenderError, PlaygroundOutput> {
        EnvIO { env in
            env.render.playground(playground).provide(env.codeEnvironment)
        }
    }
    
    private func renderPlaygrounds(atFolder folder: URL) -> EnvIO<Environment, RenderError, PlaygroundsOutput> {
        EnvIO { env in
            env.render.playgrounds(at: folder).provide(env.codeEnvironment)
        }
    }
    
    // MARK: private <builders>
    private func buildPlaygrounds(_ playgrounds: PlaygroundsOutput, atNefPlayground: NefPlaygroundURL, cached: Bool) -> EnvIO<Environment, RenderError, Void> {
        playgrounds.traverse { info in
            self.buildPages(info.output, inPlayground: info.playground.url, atNefPlayground: atNefPlayground, cached: cached)
        }.void()^
    }
    
    private func buildPages(_ pages: PlaygroundOutput, inPlayground playground: URL, atNefPlayground nefPlayground: NefPlaygroundURL, cached: Bool) -> EnvIO<Environment, RenderError, Void> {
        let xcworkspace = EnvIO<Environment, RenderError, URL>.var()
        let frameworks = EnvIO<Environment, RenderError, [URL]>.var()
        
        return binding(
            xcworkspace <- self.xcworkspace(atFolder: nefPlayground.appending(.contentFiles)),
             frameworks <- self.compile(workspace: xcworkspace.get, atNefPlayground: nefPlayground, platform: pages.head.platform, cached: cached),
                        |<-self.compile(pages: pages, inPlayground: playground, atNefPlayground: nefPlayground, frameworks: frameworks.get),
        yield: ())^
    }
    
    // MARK: private <compiler>
    private func compile(page: RenderingOutput, filename: String, inPlayground: URL, atNefPlayground nefPlayground: NefPlaygroundURL, platform: Platform, frameworks: [URL]) -> EnvIO<Environment, RenderError, Void> {
        let page = page.output.all().joined()
        
        return EnvIO { (env: Environment) -> IO<RenderError, Void> in
            binding(
                |<-env.console.print(information: "\t• Compiling page '\(filename.removeExtension)'"),
                |<-env.compilerSystem
                      .compile(page: page, filename: filename, inPlayground: inPlayground, atNefPlayground: nefPlayground, platform: platform, frameworks: frameworks)
                      .contramap(\Environment.compilerEnvironment).provide(env)
                      .mapError { e in RenderError.content(info: e) },
            yield: ())^.reportStatus(console: env.console)
        }
    }
    
    private func compile(pages: PlaygroundOutput, inPlayground playground: URL, atNefPlayground nefPlayground: NefPlaygroundURL, frameworks: [URL]) -> EnvIO<Environment, RenderError, Void> {
        func compilePages(_ pages: PlaygroundOutput, inPlayground: URL, atNefPlayground: NefPlaygroundURL, frameworks: [URL]) -> EnvIO<Environment, RenderError, Void> {
            pages.traverse { info in
                self.compile(page: info.output, filename: info.page.escapedTitle, inPlayground: inPlayground, atNefPlayground: atNefPlayground, platform: info.platform, frameworks: frameworks)
            }.void()^
        }
        
        return EnvIO { env in
            binding(
                |<-compilePages(pages, inPlayground: playground, atNefPlayground: nefPlayground, frameworks: frameworks).provide(env),
                |<-env.console.print(information: "Building playground '\(playground.lastPathComponent.removeExtension)'"),
                |<-env.console.printStatus(success: true),
            yield: ())^
        }
    }
    
    private func compile(workspace: URL, atNefPlayground nefPlayground: NefPlaygroundURL, platform: Platform, cached: Bool) -> EnvIO<Environment, RenderError, [URL]> {
        func buildWorkspace(_ workspace: URL, atNefPlayground: NefPlaygroundURL, platform: Platform, cached: Bool) -> EnvIO<Environment, RenderError, URL> {
            EnvIO { env in
                env.compilerSystem.compile(xcworkspace: workspace, atNefPlayground: atNefPlayground, platform: platform, cached: cached)
                                  .provide(env.compilerEnvironment)
                                  .mapError { e in .workspace(workspace, info: e) }
            }
        }
        
        return EnvIO { env in
            let dependencies = IO<RenderError, URL>.var()
            
            return binding(
                             |<-env.console.print(information: "Building workspace '\(workspace.lastPathComponent.removeExtension)'"),
                dependencies <- buildWorkspace(workspace, atNefPlayground: nefPlayground, platform: platform, cached: cached).provide(env),
            yield: [dependencies.get])^.reportStatus(console: env.console)
        }
    }
    
    // MARK: private <utils>
    private func xcworkspace(atFolder folder: URL) -> EnvIO<Environment, RenderError, URL> {
        func getWorkspaces(atFolder folder: URL) -> EnvIO<Environment, PlaygroundSystemError, NEA<URL>> {
            EnvIO { env in env.playgroundSystem.xcworkspaces(at: folder).provide(env.fileSystem) }
        }
        
        func assertNumberOf(xcworkspaces: NEA<URL>, equalsTo total: Int) -> EnvIO<Environment, PlaygroundSystemError, Void> {
            xcworkspaces.all().count == total ? EnvIO.pure(())^ : EnvIO.raiseError(.xcworkspaces())^
        }
        
        let xcworkspaces = EnvIO<Environment, PlaygroundSystemError, NEA<URL>>.var()
        
        return binding(
            xcworkspaces <- getWorkspaces(atFolder: folder),
                         |<-assertNumberOf(xcworkspaces: xcworkspaces.get, equalsTo: 1),
        yield: xcworkspaces.get.head)^.mapError { _ in .getWorkspace(folder: folder) }^
    }
    
    func platform(in playgrounds: PlaygroundsOutput) -> Platform {
        playgrounds.head.output.head.platform
    }
}