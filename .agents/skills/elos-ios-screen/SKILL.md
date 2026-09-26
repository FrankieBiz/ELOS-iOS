# Skill: elos-ios-screen

## Purpose
Add a new SwiftUI screen + ViewModel and wire it into navigation.

## Steps
1. Read current navigation structure in the Xcode project.
2. Create a new SwiftUI View under apps/elos-mobile/Elos/Features/<Feature>/.
3. Create a ViewModel (ObservableObject) in the same folder.
4. Wire the screen into existing navigation.
5. Use ApiClient/ViewModel for networking; never from Views.

## Constraints
- SwiftUI + MVVM only.
- Do not change backend code.
