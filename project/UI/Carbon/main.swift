//  Copyright © 2020 The nef Authors.

import CLIKit
import NefCarbon

// #: - MAIN <launcher - AppKit>
_ = CarbonApplication {
    CommandLineTool<CarbonCommand>.unsafeRunSync()
}
