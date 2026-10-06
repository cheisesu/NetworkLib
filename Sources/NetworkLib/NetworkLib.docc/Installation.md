# Installing NetworkLib

Add NetworkLib to your app or package with Swift Package Manager.

## Overview

NetworkLib requires a Swift 6 toolchain and supports iOS 13 or later, tvOS 13 or later, and macOS 10.15 or later. Some APIs, including proxy connections, require newer operating system versions.

The instructions below target the first release, `0.0.1`, and require that version to be published as a Git tag in the repository.

### Add to an Xcode project

1. Open your project in Xcode and choose **File > Add Package Dependencies**.
2. Enter the repository URL: `https://github.com/cheisesu/NetworkLib.git`.
3. Select **Exact Version** and enter `0.0.1`.
4. Add the **NetworkLib** library product to your app target.

### Add to a Swift package

Add the dependency to the `dependencies` array in your `Package.swift` manifest:

```swift
dependencies: [
    .package(
        url: "https://github.com/cheisesu/NetworkLib.git",
        exact: "0.0.1"
    )
],
```

Then add the library product to the target that uses it:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "NetworkLib", package: "NetworkLib")
    ]
)
```

Replace `YourTarget` with your target's name and merge these entries into your existing manifest.

### Import the library

Import NetworkLib in the Swift files that use its APIs:

```swift
import NetworkLib
```

Continue with the connection example on the <doc:NetworkLib> welcome page.

### Current build requirements

The package currently attaches a SwiftLint build plugin to the library target. That plugin expects the SwiftLint executable at `/opt/homebrew/bin/swiftlint`.

The manifest also uses `unsafeFlags` for `-warnings-as-errors`. Swift Package Manager restricts using products containing unsafe build flags as versioned dependencies. These flags need to be removed or replaced before publishing a release intended for the version-based installation shown above.
