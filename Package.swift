// swift-tools-version:4.0
import PackageDescription

let package = Package(
	name: "SwiftParser",

	products: [
		.library(name: "SwiftParser", targets: ["SwiftParser"]),
	],

	dependencies: [
	],

	targets: [
		.testTarget(name: "SwiftParserTests", dependencies: ["SwiftParser"]),
		.target(name: "SwiftParser", path: "Sources")
	]
)
