//  Copyright © 2019 The nef Authors.

import Foundation
import NefCore

/// Renders a page into Jekyll format.
///
/// - Parameters:
///   - content: content page in Xcode playground.
///   - outputPath: output where to write the Jekyll render.
///   - permalink: website relative url where locate the page.
///   - verbose: run in verbose mode.
///   - success: callback to notify if everything goes well.
///   - failure: callback with information to notify if something goes wrong.
public func renderJekyll(content: String,
                         to outputPath: String,
                         permalink: String,
                         verbose: Bool,
                         success: @escaping () -> Void,
                         failure: @escaping (String) -> Void) {
    
    let outputURL = URL(fileURLWithPath: outputPath)
    guard let rendered = JekyllGenerator(permalink: permalink).render(content: content, verbose: verbose) else { failure("can not render page into Jekyll format"); return }
    guard let _ = try? rendered.write(to: outputURL, atomically: true, encoding: .utf8) else { failure("invalid output path"); return }
    
    success()
}
