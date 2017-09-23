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
		.target(name: "SwiftParser", path: "Sources")
	]
)
