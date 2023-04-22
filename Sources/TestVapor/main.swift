import Vapor

let app = Application()
app.http.server.configuration.address = .hostname("127.0.0.1", port: 3100)
app.on(.GET, "/") { req in
	"Hi, you can replace the literal string below please."
}

class Updator {
	let s3: AWSS3Provider
	let file: String

	init() async throws {
		let source = ObjectStorageSource(
			name: nil,
			cloud: ObjectStorageCloudSource(
				region: "REGION",
				secretID: "SECRET_ID",
				secretKey: "SECRET_KEY",
				endpoint: nil),
			bucket: "BUCKET",
			path: ["PATH"])
		s3 = try await AWSS3Provider(source: source)
		file = "FILE"
	}

	func update() {
		Task.detached(priority: .background) {
			try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
			do {
				try await self.getIt()
			} catch {
				dump(error)
			}
			self.update()
		}
	}

	func getIt() async throws {
		if let resp = try await s3.get(key: file) {
			print("got file, len=", resp.body?.toBytes().getData().count as Any)
		} else {
			print("file not found")
		}

	}
}
let updator = try await Updator()
try await updator.getIt()
updator.update()

try app.run()
