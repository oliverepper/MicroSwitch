import Foundation
import GRPC
import JWTKit
import APNSwift
import NIO
import NIOTransportServices


enum APNService {
    struct Notification: APNSwiftNotification {
        let aps: APNSwiftPayload
        let payload: Data
    }

    enum Error: Swift.Error {
        case key
        case environment
    }

    public static func sendPush(notification: APNService.Notification, to token: String) throws -> EventLoopFuture<Void> {
        let config = try APNConfig.load(.default)

        guard let key = try? ECDSAKey.private(pem: Data(config.key.utf8)) else {
            throw Error.key
        }

        let apnsConfig = APNSwiftConfiguration(
            authenticationMethod: .jwt(
                key: key,
                keyIdentifier: .init(string: config.keyIdentifier),
                teamIdentifier: config.teamIdentifier),
            topic: config.topic,
            environment: config.environment == APNConfig.Environment.production ? .production : .sandbox,
            logger: logger,
            timeout: nil)

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        logger.info("Sending \(notification) to \(token)")

        return APNSwiftConnection.connect(configuration: apnsConfig, on: group.next(), logger: logger).flatMap { connection in
            return connection.send(notification, pushType: .alert, to: token).flatMap {
                connection.eventLoop.makeSucceededVoidFuture()
            }
        }
    }
}
