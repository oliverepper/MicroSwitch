import GRPC
import NIO
import Foundation
import SwiftProtobuf
import Logging

enum SocketAddressKey: UserInfo.Key {
    typealias Value = SocketAddress
}

final class Session {
    let id = UUID()
    var contexts = [StreamingResponseCallContext<Signal>]()

    init() {
        logger.info("Session \(id) created")
    }

    @discardableResult func add(_ context: StreamingResponseCallContext<Signal>) -> Bool {
        guard contexts.first(where: { $0 === context }) == nil else {
            return false
        }
        contexts.append(context)
        logger.debug("Added port \(context) to session")
        return true
    }

    func remove(_ context: StreamingResponseCallContext<Signal>) {
        logger.info("Removing port \(context) from connection")
        contexts.removeAll(where: { $0 === context })
    }

    func peers(for context: StreamingResponseCallContext<Signal>) -> [StreamingResponseCallContext<Signal>] {
        return contexts.filter { $0 !== context }
    }
}

final class SignalServiceInterceptor: ServerInterceptor<Signal, Signal> {
    override func receive(_ part: GRPCServerRequestPart<Signal>, context: ServerInterceptorContext<Signal, Signal>) {

        if let address = context.remoteAddress {
            context.userInfo[SocketAddressKey.self] = address
        }

        context.receive(part)
    }
}

final class SignalServiceInterceptorFactory: SignalServiceServerInterceptorFactoryProtocol {
    func makesignalInterceptors() -> [ServerInterceptor<Signal, Signal>] {
        return [
            SignalServiceInterceptor(),
            LoggingInterceptor()
        ]
    }
}

var sessions = [UUID: Session]()
var sessionIDs = [AnyHashable: UUID]()

final class SignalServiceImpl: SignalServiceProvider {
    var interceptors: SignalServiceServerInterceptorFactoryProtocol? {
        return SignalServiceInterceptorFactory()
    }

    enum Error: Int32 {
        case signal
        case session

        var message: String {
            switch self {
            case .signal:
                return "Signal type missing"
            case .session:
                return "Session not available"
            }
        }
    }

    func signal(context: StreamingResponseCallContext<Signal>) -> EventLoopFuture<(StreamEvent<Signal>) -> Void> {

        return context.eventLoop.makeSucceededFuture { event in
            switch event {
            case let .message(signal):
                guard let type = signal.type else {
                    self.error(.signal, in: context)
                    return
                }

                switch type {
                case let .connect(data):
                    self.connection(data, in: context)
                case let .broadcast(data):
                    self.broadcast(data, in: context)
                case .error:
                    break
                }

            case .end:
                sessions.values.forEach { session in
                    self.remove(context, from: session)
                }
                context.statusPromise.succeed(.ok)
            }
        }
    }

    private func connection(_ connectMessage: Connect, in context: StreamingResponseCallContext<Signal>) {
        func associate(_ context: StreamingResponseCallContext<Signal>, with session: Session) {
            session.add(context)

            if let address = context.userInfo[SocketAddressKey.self] {
                sessionIDs[address.hashValue] = session.id
            }

            session.peers(for: context).forEach { peerContext in
                peerContext.sendResponse(.with {
                    $0.connect = .with {
                        $0.sessionID = session.id.uuidString
                        $0.from = context.userInfo[SocketAddressKey.self]?.description ?? "Unknown"
                        $0.connected = true
                    }
                }).cascade(to: nil)
            }
        }

        if connectMessage.sessionID.isEmpty {
            // create new session
            let session = Session()
            sessions[session.id] = session
            associate(context, with: session)
            // answer with sessionID
            context.sendResponse(.with {
                $0.connect = .with {
                    $0.from = context.userInfo[SocketAddressKey.self]?.description ?? "Unknown"
                    $0.sessionID = session.id.uuidString
                }
            }).cascade(to: nil)
        } else {
            // connect to session
            guard let session = session(for: connectMessage.sessionID) else {
                error(.session, in: context)
                return
            }
            associate(context, with: session)
        }

    }

    private func broadcast(_ broadcastMessage: Broadcast, in context: StreamingResponseCallContext<Signal>) {
        let sessionID = session(for: context)?.uuidString ?? broadcastMessage.sessionID
        guard let session = session(for: sessionID) else {
            error(.session, in: context)
            return
        }

        if session.add(context) {
            self.connection(.with {
                $0.sessionID = session.id.uuidString
            }, in: context)
        }

        let peers = session.peers(for: context)
        let countBytes = broadcastMessage.payload.count
        let countPeers = peers.count
        logger.debug("Sending \(countBytes) byte\(countBytes != 1 ? "s" : "") to \(countPeers) peer\(countPeers != 1 ? "s" : "")")
        peers.forEach { peerContext in
            peerContext.sendResponse(.with {
                $0.broadcast = .with {
                    $0.sessionID = session.id.uuidString
                    $0.payload = broadcastMessage.payload
                }
            }).cascade(to: nil)
        }
    }

    private func error(_ error: Error, in context: StreamingResponseCallContext<Signal>) {
        logger.error(.init(stringLiteral: error.message))
        context.sendResponse(.with {
            $0.error = .with {
                $0.code = error.rawValue
                $0.message = error.message
            }
        }).cascade(to: nil)
    }

    private func session(for id: String) -> Session? {
        if let uuid = UUID(uuidString: id) {
            return sessions[uuid]
        }
        return nil
    }

    private func session(for context: StreamingResponseCallContext<Signal>) -> UUID? {
        if let address = context.userInfo[SocketAddressKey.self],
           let uuid = sessionIDs[address.hashValue] {
            return uuid
        }
        return nil
    }

    private func remove(_ context: StreamingResponseCallContext<Signal>, from session: Session) {
        var address: String {
            context.userInfo[SocketAddressKey.self]?.description ?? "Unknown"
        }

        session.peers(for: context).forEach { peerContext in
            peerContext.sendResponse(.with {
                $0.connect = .with {
                    $0.sessionID = session.id.uuidString
                    $0.from = address
                    $0.connected = false
                }
            }).cascade(to: nil)
        }
        session.remove(context)
        if let address = context.userInfo[SocketAddressKey.self] {
            sessionIDs.removeValue(forKey: address.hashValue)
        }
        if session.contexts.isEmpty {
            sessions.removeValue(forKey: session.id)
        }
    }
}
