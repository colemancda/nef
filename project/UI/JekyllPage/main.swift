//  Copyright © 2019 The nef Authors.

import Foundation
import CLIKit
import NefModels
import NefCore
import NefJekyll
import Bow
import BowEffects

private let console = Console(script: "nef-jekyll-page",
                              description: "Render a markdown file from a Playground page that can be consumed from Jekyll",
                              arguments: .init(name: "page", placeholder: "playground's page", description: "path to playground page. ex. `/home/nef.playground/Pages/Intro.xcplaygroundpage`"),
                                         .init(name: "output", placeholder: "output Jekyll's markdown", description: "path where Jekyll markdown are saved to. ex. `/home`"),
                                         .init(name: "permalink", placeholder: "relative URL", description: "is the relative path where Jekyll will render the documentation. ex. `/about/`"),
                                         .init(name: "verbose", placeholder: "", description: "run jekyll page in verbose mode.", isFlag: true, default: "false"))


func arguments(console: CLIKit.Console) -> IO<CLIKit.Console.Error, (content: String, filename: String, output: URL, permalink: String, verbose: Bool)> {
    console.input().flatMap { args in
        guard let pagePath = args["page"]?.trimmingEmptyCharacters.expandingTildeInPath,
              let outputPath = args["output"]?.trimmingEmptyCharacters.expandingTildeInPath,
              let permalink = args["permalink"],
              let verbose = Bool(args["verbose"] ?? "") else {
                return IO.raiseError(CLIKit.Console.Error.arguments)
        }
        
        let page = pagePath.contains("Contents.swift") ? pagePath : "\(pagePath)/Contents.swift"
        let output = URL(fileURLWithPath: outputPath).appendingPathComponent("README.md")
        
        guard let pageContent = try? String(contentsOfFile: page), !pageContent.isEmpty else {
            return IO.raiseError(CLIKit.Console.Error.render(information: "could not read page content"))
        }
        
        return IO.pure((content: pageContent, filename: pagePath.filename.removeExtension, output: output, permalink: permalink, verbose: verbose))
    }^
}

func render(content: String, output: URL, permalink: String) -> IO<CLIKit.Console.Error, RendererOutput> {
    IO.async { callback in
        renderJekyll(content: content,
                     to: output.path,
                     permalink: permalink,
                     success: { output in callback(.right(output)) },
                     failure: { e in callback(.left(.render(information: e))) })
    }^
}

@discardableResult
func main() -> Either<CLIKit.Console.Error, Void> {
    func step(partial: UInt, duration: DispatchTimeInterval = .seconds(1)) -> Step {
        Step(total: 3, partial: partial, duration: duration)
    }
    
    let args = IOPartial<CLIKit.Console.Error>.var((content: String, filename: String, output: URL, permalink: String, verbose: Bool).self)
    let output = IOPartial<CLIKit.Console.Error>.var(RendererOutput.self)
    
    return binding(
           args <- arguments(console: console),
                |<-console.printStep(step: step(partial: 1), information: "Reading "+"arguments".bold),
                |<-console.printStatus(success: true),
                |<-console.printSubstep(step: step(partial: 1), information: ["filename: \(args.get.filename)", "output: \(args.get.output.path)", "permalink: \(args.get.permalink)", "verbose: \(args.get.verbose)"]),
                |<-console.printStep(step: step(partial: 2), information: "Render "+"Jekyll".bold+" (\(args.get.filename))".lightGreen),
         output <- render(content: args.get.content, output: args.get.output, permalink: args.get.permalink),
    yield: args.get.verbose ? output.get : nil)^
        .reportStatus(in: console)
        .foldM({ e   in console.exit(failure: "\(e)") },
               { rendered in
                    guard let rendered = rendered else { return console.exit(success: "rendered jekyll page.") }
                    return console.exit(success: "rendered jekyll page.\n\n• AST \n\t\(rendered.tree)\n\n• Trace \n\t\(rendered.output)")
               })
        .unsafeRunSyncEither()
}


// #: - MAIN <launcher>
main()
