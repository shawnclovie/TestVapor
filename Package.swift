// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "TestVapor",
	platforms: [
		.macOS(.v13),
		.iOS(.v13),
	],
    products: [
        .executable(name: "TestVapor", targets: ["TestVapor"]),
    ],
	dependencies: [
		.package(url: "https://github.com/awslabs/aws-sdk-swift",
				 exact: "0.15.0"),
		.package(url: "https://github.com/vapor/vapor.git",
				 from: "4.0.0"),
	],
    targets: [
        .executableTarget(name: "TestVapor", dependencies: [
			.product(name: "Vapor", package: "vapor"),
			.product(name: "AWSS3", package: "aws-sdk-swift"),
		]),
    ]
)
