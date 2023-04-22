import Foundation
import AWSClientRuntime
import ClientRuntime
import AWSS3

public struct ObjectStorageCloudSource: Equatable {
	public var region: String?
	public var secretID: String
	public var secretKey: String
	public var endpoint: URL?
}

public struct ObjectStorageSource: Equatable {
	public var name: String?
	public var cloud: ObjectStorageCloudSource
	public var bucket: String
	public var path: [String]

	func fullpath(_ file: String) -> String {
		path.joined(separator: "/") + "/\(file)"
	}
}

extension ObjectStorageCloudSource: EndpointResolver,
									RegionResolver,
									RegionProvider {
	public var providers: [AWSClientRuntime.RegionProvider] {
		[self]
	}

	public func resolveRegion() async -> String? {
		region
	}

	public func getCredentials() -> Credentials {
		.init(accessKey: secretID, secret: secretKey, expirationTimeout: nil, sessionToken: nil)
	}

	public func resolve(params: EndpointParams) throws -> ClientRuntime.Endpoint {
		if let endpoint {
			let scheme = endpoint.scheme ?? "https"
			return .init(host: endpoint.host ?? "", path: endpoint.path,
						 port: Int16(endpoint.port ?? (scheme == "https" ? 443 : 80)),
						 protocolType: .init(rawValue: scheme))
		}
		return try DefaultEndpointResolver().resolve(params: params)
	}
}

public struct AWSS3Provider {
	public static let name = "aws"
	
	let client: S3Client
	public var source: ObjectStorageSource

	public init(source: ObjectStorageSource) async throws {
		guard !source.path.isEmpty else {
			throw NSError(domain: "path should not empty", code: 0)
		}
		let config = try await S3Client.S3ClientConfiguration(
			credentialsProvider: .fromStatic(source.cloud.getCredentials()),
			endpointResolver: source.cloud,
			regionResolver: source.cloud)
		client = .init(config: config)
		self.source = source
	}
	
	public func list(prefix: String, continueToken: String?, maxCount: Int) async throws -> ([String], String?) {
		let prefix = source.fullpath(prefix)
		let resp = try await client.listObjectsV2(input: .init(
			bucket: source.bucket,
			continuationToken: continueToken,
			maxKeys: maxCount > 0 ? maxCount : nil,
			prefix: prefix))
		let files = (resp.contents ?? []).map({ obj in
			obj.key ?? ""
		})
		return (files, resp.nextContinuationToken)
	}

	public func get(key: String) async throws -> GetObjectOutputResponse? {
		let key = source.fullpath(key)
		do {
			return try await client.getObject(input: .init(bucket: source.bucket, key: key))
		} catch {
			if isNotFound(error: error) {
				return nil
			}
			throw error
		}
	}
	
	private func isNotFound(error: Error) -> Bool {
		if case .client(let clientErr, _) = error as? ClientRuntime.SdkError<AWSS3.GetObjectOutputError>,
		   case .retryError(let retryErr) = clientErr,
		   case .service(let opErr, _) = retryErr as? ClientRuntime.SdkError<AWSS3.GetObjectOutputError>,
			   case .noSuchKey(_) = opErr {
			return true
		}
		return false
	}
	
	public func put(key: String, content: Data, contentType: String, expires: Date?, metadata: [String : String]?) async throws {
		let key = source.fullpath(key)
		_ = try await client.putObject(input: .init(
			body: .buffer(.init(data: content)),
			bucket: source.bucket,
			contentLength: content.count,
			contentType: contentType,
			expires: expires, key: key,
			metadata: metadata))
	}

	public func delete(key: String) async throws {
		let key = source.fullpath(key)
		_ = try await client.deleteObject(input: .init(bucket: source.bucket, key: key))
	}
}
