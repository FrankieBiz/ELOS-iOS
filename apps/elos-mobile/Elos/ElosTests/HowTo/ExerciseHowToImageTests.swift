import Testing
import UIKit
@testable import Elos

struct ExerciseHowToImageTests {
    @Test func bundledDemoImageResolves() {
        // The de-risk: a synchronized-group .xcassets must compile into the app bundle
        // and be resolvable by the same UIImage(named:) call the how-to sheet uses.
        #expect(UIImage(named: "Butterfly") != nil)
    }
}
