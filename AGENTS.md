# Repository Guidelines

## Project Structure & Module Organization
- `removewalter-swift/`: main app target (`SwiftUI` + `SwiftData`), including `ContentView.swift`, app entrypoint, model types, and `Assets.xcassets`.
- `removewalter-swiftTests/`: unit and logic tests using the Swift `Testing` framework (`@Test`, `#expect`).
- `removewalter-swiftUITests/`: UI and launch/performance tests using `XCTest`.
- `removewalter-swift.xcodeproj/`: Xcode project, build settings, and the shared `removewalter-swift` scheme.

## Build, Test, and Development Commands
- `open removewalter-swift.xcodeproj`: open the project in Xcode for interactive development.
- `xcodebuild -project removewalter-swift.xcodeproj -scheme removewalter-swift -configuration Debug build`: build from the command line.
- `xcodebuild -project removewalter-swift.xcodeproj -scheme removewalter-swift -destination 'platform=iOS Simulator,name=iPhone 16' test`: run all tests.
- `xcodebuild -project removewalter-swift.xcodeproj -scheme removewalter-swift -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:removewalter-swiftTests`: run unit tests only.

## Coding Style & Naming Conventions
- Use standard Swift formatting with 4-space indentation and keep imports minimal.
- Use `UpperCamelCase` for types (`Item`, `ContentView`) and `lowerCamelCase` for methods/properties (`addItem`, `sharedModelContainer`).
- Keep file names aligned with primary types (`Item.swift`, `ContentView.swift`).
- Prefer small, focused SwiftUI views; move reusable logic/model behavior into dedicated files.
- No project-local `SwiftLint`/`SwiftFormat` config is currently committed, so rely on Xcode formatter and warnings.

## Testing Guidelines
- Add behavior-focused unit tests in `removewalter-swiftTests/` for model and app logic.
- Keep UI scenarios (launch, navigation, user flows) in `removewalter-swiftUITests/`.
- Name tests by observable behavior, e.g. `testAddItemCreatesRow`.
- Include a regression test for each bug fix when practical, then run the full `xcodebuild ... test` command before opening a PR.

## Commit & Pull Request Guidelines
- Existing history includes both an initial bootstrap commit and a Conventional Commit style message (`feat: ...`); prefer `type: concise summary` going forward.
- Keep commits scoped to one logical change and write imperative summaries.
- PRs should include: purpose, key implementation notes, how it was tested (commands run), and screenshots for UI-visible changes.
- Keep unrelated `project.pbxproj` churn out of feature PRs when possible.
