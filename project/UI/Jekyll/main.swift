//  Copyright © 2020 The nef Authors.

import Foundation
import CLIKit
import nef
import Bow
import BowEffects

private let console = Console(script: "nef-jekyll",
                              description: "Render markdown files that can be consumed from Jekyll to generate a microsite",
                              arguments: .init(name: "project", placeholder: "path-to-input", description: "path to the folder containing Xcode Playgrounds to render"),
                                         .init(name: "output", placeholder: "path-to-output", description: "path where the resulting Markdown files will be generated"),
                                         .init(name: "main-page", placeholder: "path-to-index", description: "path to 'README.md' file to be used as the index page", default: "README.md"))


func arguments(console: CLIKit.Console) -> IO<CLIKit.Console.Error, (input: URL, output: URL, mainPage: URL)> {
    console.input().flatMap { args in
        guard let inputPath = args["project"]?.trimmingEmptyCharacters.expandingTildeInPath,
              let outputPath = args["output"]?.trimmingEmptyCharacters.expandingTildeInPath,
              let mainPagePath = args["main-page"]?.trimmingEmptyCharacters.expandingTildeInPath else {
                return IO.raiseError(CLIKit.Console.Error.arguments)
        }
        
        let input = URL(fileURLWithPath: inputPath, isDirectory: true)
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        let mainPage = mainPagePath == "README.md" ? output.appendingPathComponent("README.md") : URL(fileURLWithPath: mainPagePath, isDirectory: false)
        
        return IO.pure((input: input, output: output, mainPage: mainPage))
    }^
}

@discardableResult
func main() -> Either<CLIKit.Console.Error, Void> {
    arguments(console: console)
        .flatMap { (input, output, mainPage) in
            nef.Jekyll.render(playgroundsAt: input, mainPage: mainPage, into: output)
                      .provide(console)^
                      .mapLeft { _ in .render() }
                      .foldM({ _ in console.exit(failure: "rendering Xcode Playgrounds from '\(input.path)'") },
                             { _ in console.exit(success: "rendered Xcode Playgrounds in '\(output.path)'")   }) }^
        .reportStatus(in: console)
        .foldM({ e in console.exit(failure: "\(e)")        },
               { success in console.exit(success: success) })
        .unsafeRunSyncEither()
}


// #: - MAIN <launcher>
main()