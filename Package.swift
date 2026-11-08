// swift-tools-version:6.1
// Package traits (SE-0450) need tools 6.1.

import PackageDescription


let package = Package(
    name: "MIOLayoutKit",
    platforms: [
        .macOS(.v12), .iOS( .v15 )
    ],
    products: [
        // Layout design and composition: model, DSL, engine, serialization, data provider.
        .library( name: "MIOLayoutKit", targets: ["MIOLayoutKit"] ),
        // Renderers: an app links the ones it needs, or none.
        .library( name: "MIOLayoutHTML", targets: ["MIOLayoutHTML"] ),
        .library( name: "MIOLayoutText", targets: ["MIOLayoutText"] ),
        .library( name: "MIOLayoutPDFLib", targets: ["MIOLayoutPDFLib"] ),
        .library( name: "MIOLayoutCoreGraphics", targets: ["MIOLayoutCoreGraphics"] ),
    ],
    traits: [
        // On by default: Xcode workspaces that use this as a local package cannot enable
        // traits. Builds that must not fetch PDFLib-Swift (web / wasm, apps without PDF)
        // turn it off: .package( url: "…/MIOLayoutKit", branch: "main", traits: [] )
        // On iOS PDFLib-Swift is never linked and MIOLayoutPDFLib compiles empty.
        .trait( name: "PDFLib", description: "PDF rendering with PDFLib (macOS / Linux)" ),
        .default( enabledTraits: ["PDFLib"] ),
    ],
    dependencies: [
        .package( url: "https://github.com/miolabs/MIOCore.git", from: "2.0.8" ),   // MCRuntime.superclass(of:)
        .package( url: "https://github.com/miolabs/PDFLib-Swift.git", branch: "main" )
    ],
    targets: [
        .target(
            name: "MIOLayoutKit",
            dependencies: [ .product( name: "MIOCore", package: "MIOCore" ) ]   // MCRuntime (class hierarchy)
        ),

        .target( name: "MIOLayoutHTML", dependencies: ["MIOLayoutKit"] ),
        .target( name: "MIOLayoutText", dependencies: ["MIOLayoutKit"] ),
        .target(
            name: "MIOLayoutPDFLib",
            dependencies: [
                "MIOLayoutKit",
                .product( name: "MIOCore", package: "MIOCore", condition: .when( traits: ["PDFLib"] ) ),
                .product( name: "PDFLib-Swift", package: "PDFLib-Swift", condition: .when( platforms: [.macOS, .linux], traits: ["PDFLib"] ) )
            ]
        ),
        .target(
            name: "MIOLayoutCoreGraphics",
            dependencies: [
                "MIOLayoutKit",
                .product( name: "MIOCore", package: "MIOCore", condition: .when( platforms: [.iOS] ) )
            ]
        ),

        .testTarget(
            name: "MIOLayoutKitTests",
            dependencies: ["MIOLayoutKit", "MIOLayoutHTML", "MIOLayoutText", "MIOLayoutPDFLib"],
            linkerSettings: [
                .linkedFramework( "SystemConfiguration", .when( platforms: [.macOS] ) )
            ]),
    ]
)
