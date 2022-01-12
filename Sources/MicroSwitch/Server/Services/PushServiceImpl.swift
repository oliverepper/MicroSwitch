import GRPC
import NIO
import SwiftProtobuf
import Logging
import Foundation

final class PushServiceInterceptorFactory: PushServiceServerInterceptorFactoryProtocol {
    func makeaddInterceptors() -> [ServerInterceptor<TokenRequest, Google_Protobuf_Empty>] {
        return [LoggingInterceptor()]
    }

    func makeinviteInterceptors() -> [ServerInterceptor<InvitationRequest, InvitationResponse>] {
        return [LoggingInterceptor()]
    }
}

final class PushServiceImpl: PushServiceProvider {
    var interceptors: PushServiceServerInterceptorFactoryProtocol? {
        return PushServiceInterceptorFactory()
    }

    func add(request: TokenRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Google_Protobuf_Empty> {
        if request.handle.isEmpty {
            return context.eventLoop.makeFailedFuture(GRPCStatus(code: .invalidArgument, message: "Handle is missing"))
        }

        var handle = Handle.load(request.handle)

        if handle.tokens.first(where: { $0 == request.token }) == nil {
            handle.tokens.append(request.token)
        } else {
            return context.eventLoop.makeFailedFuture(GRPCStatus(code: .alreadyExists, message: "Token was already saved"))
        }

        do {
            try handle.save()
            logger.info("Token \(request.token) added for handle \(request.handle)")
            return context.eventLoop.makeSucceededFuture(.init())
        } catch {
            logger.error("\(error)")
            return context.eventLoop.makeFailedFuture(GRPCStatus(code: .internalError, message: "Could not save \(request.token) for handle \(request.handle)"))
        }
    }

    func invite(request: InvitationRequest, context: StreamingResponseCallContext<InvitationResponse>) -> EventLoopFuture<GRPCStatus> {

        func send(_ code: GRPCStatus.Code, message: String) {
            context.sendResponse(.with {
                $0.code = Int32(code.rawValue) // code.rawValue is UInt8 internally
                $0.message = message
            }).cascade(to: nil)
        }

        request.to.forEach { recipient in
            let handle = Handle.load(recipient)

            if (handle.tokens.count < 1) {
                send(.invalidArgument, message: "No push token for recipient \(recipient)")
            }

            handle.tokens.forEach { token in
                do {
                    try APNService.sendPush(
                        notification: .init(aps: .init(
                            alert: .init(title: "Invitation", body: "New invite from \(handle.value)")
                        ), payload: request.payload),
                        to: token).cascade(to: nil)
                } catch {
                    logger.error("\(error)")
                    context.statusPromise.fail(GRPCStatus(code: .internalError, message: "\(error)"))
                }
                send(.ok, message: "Push to \(handle.value) requested")
            }
        }

        return context.eventLoop.makeSucceededFuture(.ok)
    }
}
