//  Copyright © 2019 The nef Authors.

import CLIKit
import NefCarbon

// #: - MAIN <launcher - AppKit>
_ = CarbonApplication {
    CommandLineTool<CarbonPageCommand>.unsafeRunSync()
}
