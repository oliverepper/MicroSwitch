import GRPC
import Logging
import NIO
import NIOSSL
import Foundation
import NIOTransportServices
import Files

final class MicroSwitchServer {
    private static let configFolder = "." + processName + "/etc"
    private static let certificateFilename = "fullchain.pem"
    private static let keyFilename = "privkey.pem"

    private var host: String
    private var port: Int

    enum Error: Swift.Error {
        case missing(String)
    }

    private func serverBuilder(for group: MultiThreadedEventLoopGroup) throws -> Server.Builder {
        guard let cert = try? Folder.current
                .subfolder(named: Self.configFolder)
                .file(named: Self.certificateFilename) else {
                    throw Error.missing("Certificate")
                }
        guard let key = try? Folder.current
                .subfolder(named: Self.configFolder)
                .file(named: Self.keyFilename) else {
                    throw Error.missing("Private Key")
                }

        return GRPC.Server.usingTLS(
            with: .makeServerConfigurationBackedByNIOSSL(
                certificateChain: [.certificate(try .init(file: cert.url.path, format: .pem))],
                privateKey: .privateKey(try .init(file: key.url.path, format: .pem))),
            on: group)
    }

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    private func serverBuilder(for group: NIOTSEventLoopGroup) throws -> Server.Builder {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: self.host,
            kSecReturnRef as String: kCFBooleanTrue!
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { throw Error.missing("Certificate from keychain") }
        let certificate = item as! SecCertificate

        var identity: SecIdentity?
        _ = withUnsafeMutablePointer(to: &identity) { ptr in
            SecIdentityCreateWithCertificate(nil, certificate, ptr)
        }

        guard let id = identity else { throw Error.missing("Private key in certificate") }

        return GRPC.Server.usingTLS(
            with: .makeServerConfigurationBackedByNetworkFramework(identity: id),
            on: group)
    }
    #endif

    private func serverBuilder(for group: EventLoopGroup) throws -> Server.Builder {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        if let g = group as? NIOTSEventLoopGroup {
            return try serverBuilder(for: g)
        }
        #endif
        if let g = group as? MultiThreadedEventLoopGroup {
            return try serverBuilder(for: g)
        }

        fatalError("Could not get a Server.Builder for group \(group)")
    }

    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    public func listen(insecure: Bool = false, forcePosix: Bool = false) {
        let group = forcePosix ? MultiThreadedEventLoopGroup(numberOfThreads: 1) : PlatformSupport.makeEventLoopGroup(loopCount: 1)
        
        logger.info("Using: \(group)")

        defer {
            logger.info("Shutting down")
            try? group.syncShutdownGracefully()
        }

        let builder = insecure ? GRPC.Server.insecure(group: group) : try! serverBuilder(for: group)

        let server = builder
            .withServiceProviders([
                ServerInfoServiceImpl(),
                PushServiceImpl(),
                AddressBookServiceImpl(),
                SignalServiceImpl()
            ])
            .bind(host: self.host, port: self.port)

        server.map {
            $0.channel.localAddress
        }.whenSuccess { address in
            if let address = address {
                   logger.info("Server listening on \(address)")
               }
        }

        do {
            _ = try server.flatMap {
                $0.onClose
            }.wait()
        } catch {
            logger.error("\(error)")
        }
    }
}
