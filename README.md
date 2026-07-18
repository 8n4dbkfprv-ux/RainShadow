# RainShadow

RainShadow is a shared Swift/SpriteKit noir detective RPG prototype for iOS/iPadOS and macOS. The current slice contains a rainy apartment establishing shot, a cinematic transition, a playable modular isometric detective office, and the arrival of Vivian Hart with the first case.

## Open and run

1. Open `RainShadow.xcodeproj` in Xcode.
2. Select **RainShadow iOS** or **RainShadow macOS**.
3. Run in landscape. Tap/click to skip the exterior after one second. Vivian then enters with the case. Select a numbered response, use **Continue** for the next passage, and finish with **End Dialogue**. On macOS, arrows/WASD change the focused response and Return/Space activates it.
4. After the introduction, tap/click the office floor to move and select its objects to inspect them.
5. Open **Personal Effects** from the lower-left office control. On macOS, `I` also toggles the inventory, arrows/WASD move its selection, and Return/Space/Escape closes it.

Minimum targets are iOS/iPadOS 18.0 and macOS 15.0. The legacy tvOS template target is outside this milestone.

## Verification

```sh
xcodebuild -project RainShadow.xcodeproj -scheme "RainShadow iOS" -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RainShadow.xcodeproj -scheme "RainShadow macOS" -configuration Debug CODE_SIGNING_ALLOWED=NO build
swift test --scratch-path /tmp/RainShadowSwiftPM
```

Use a `/tmp` scratch path for SwiftPM on file-provider-managed Desktop folders; this avoids Finder metadata interfering with ad-hoc signing of the test bundle.

Design, architecture, asset, and milestone documents are indexed in `Documentation/README.md`. Generated-source lineage is recorded in `ArtSource/Prompts/GenerationLog.md`.
