//  Copyright © 2020 The nef Authors.

import Foundation
import CLIKit
import nef
import Bow
import BowEffects

enum JekyllPageCommand: String {
    case page
    case output
    case permalink
    case verbose
}


@discardableResult
public func jekyllPage(script: String) -> Either<CLIKit.Console.Error, Void> {

    func arguments(console: CLIKit.Console) -> IO<CLIKit.Console.Error, (content: String, filename: String, output: URL, permalink: String, verbose: Bool)> {
        console.input().flatMap { args in
            guard let pagePath = args[JekyllPageCommand.page.rawValue]?.trimmingEmptyCharacters.expandingTildeInPath,
                  let outputPath = args[JekyllPageCommand.output.rawValue]?.trimmingEmptyCharacters.expandingTildeInPath,
                  let permalink = args[JekyllPageCommand.permalink.rawValue],
                  let verbose = Bool(args[JekyllPageCommand.verbose.rawValue] ?? "") else {
                    return IO.raiseError(.arguments)
            }
            
            let page = pagePath.contains("Contents.swift") ? pagePath : "\(pagePath)/Contents.swift"
            let filename = "README.md"
            let output = URL(fileURLWithPath: outputPath).appendingPathComponent(filename)
            
            guard let pageContent = try? String(contentsOfFile: page), !pageContent.isEmpty else {
                return IO.raiseError(CLIKit.Console.Error.render(information: "could not read page content"))
            }
            
            return IO.pure((content: pageContent, filename: filename, output: output, permalink: permalink, verbose: verbose))
        }^
    }
    
    func step(partial: UInt, duration: DispatchTimeInterval = .seconds(1)) -> Step {
        Step(total: 3, partial: partial, duration: duration)
    }
    
    let console = Console(script: script,
                          description: "Render a markdown file from a Playground page that can be consumed from Jekyll",
                          arguments: .init(name: JekyllPageCommand.page.rawValue, placeholder: "playground's page", description: "path to playground page. ex. `/home/nef.playground/Pages/Intro.xcplaygroundpage`"),
                                     .init(name: JekyllPageCommand.output.rawValue, placeholder: "output Jekyll's markdown", description: "path where Jekyll markdown are saved to. ex. `/home`"),
                                     .init(name: JekyllPageCommand.permalink.rawValue, placeholder: "relative URL", description: "relative path where Jekyll will render the documentation. ex. `/about/`"),
                                     .init(name: JekyllPageCommand.verbose.rawValue, placeholder: "", description: "run jekyll page in verbose mode.", isFlag: true, default: "false"))
    
    let args = IOPartial<CLIKit.Console.Error>.var((content: String, filename: String, output: URL, permalink: String, verbose: Bool).self)
    let output = IO<CLIKit.Console.Error, (url: URL, ast: String, rendered: String)>.var()
    
    return binding(
                |<-console.printStep(step: step(partial: 1), information: "Reading "+"arguments".bold),
           args <- arguments(console: console),
                |<-console.printStatus(success: true),
                |<-console.printSubstep(step: step(partial: 1), information: ["filename: \(args.get.filename)", "output: \(args.get.output.path)", "permalink: \(args.get.permalink)", "verbose: \(args.get.verbose)"]),
                |<-console.printStep(step: step(partial: 2), information: "Render "+"Jekyll".bold+" (\(args.get.filename))".lightGreen),
         output <- nef.Jekyll.renderVerbose(content: args.get.content, permalink: args.get.permalink, toFile: args.get.output)
                             .provide(console)
                             .mapError { e in .render() }^,
    yield: args.get.verbose ? Either<(ast: String, trace: String), URL>.left((ast: output.get.ast, trace: output.get.rendered))
                            : Either<(ast: String, trace: String), URL>.right(output.get.url))^
        .reportStatus(in: console)
        .foldM({ e in console.exit(failure: "\(e)") },
               { rendered in
                 rendered.fold({ (ast, trace) in console.exit(success: "rendered jekyll page.\n\n• AST \n\t\(ast)\n\n• Trace \n\t\(trace)") },
                               { (page)       in console.exit(success: "rendered jekyll page '\(page.path)'")                                })
               })
        .unsafeRunSyncEither()
}
