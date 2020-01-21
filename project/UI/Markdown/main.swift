//  Copyright © 2019 The nef Authors.

import Foundation
import CLIKit
import nef
import Bow
import BowEffects

private let console = Console(script: "nef-markdown",
                              description: "Render markdown files from Xcode Playground",
                              arguments: .init(name: "project", placeholder: "path-to-input", description: "path to the folder containing Xcode Playgrounds to render"),
                                         .init(name: "output", placeholder: "path-to-output", description: "path where the resulting Markdown files will be generated"))


func arguments(console: CLIKit.Console) -> IO<CLIKit.Console.Error, (input: URL, output: URL)> {
    console.input().flatMap { args in
        guard let inputPath = args["project"]?.trimmingEmptyCharacters.expandingTildeInPath,
              let outputPath = args["output"]?.trimmingEmptyCharacters.expandingTildeInPath else {
                return IO.raiseError(CLIKit.Console.Error.arguments)
        }
        
        let folder = URL(fileURLWithPath: inputPath, isDirectory: true)
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)

        return IO.pure((input: folder, output: output))
    }^
}

@discardableResult
func main() -> Either<CLIKit.Console.Error, Void> {
    arguments(console: console)
        .flatMap { (input, output) in
            nef.Markdown.render(playgroundsAt: input, into: output)
               .provide(console)^
               .mapLeft { _ in .render() }
               .foldM({ _ in console.exit(failure: "rendering Xcode Playgrounds from '\(input.path)'") },
                      { _ in console.exit(success: "rendered Xcode Playgrounds in '\(output.path)'")  }) }^
        .reportStatus(in: console)
        .foldM({ e in console.exit(failure: "\(e)")        },
               { success in console.exit(success: success) })
        .unsafeRunSyncEither()
}


// #: - MAIN <launcher>
main()