import GRPC
import SwiftProtobuf
import NIO

final class LoggingInterceptor<T, U>: ServerInterceptor<T, U> where T: Message {
    override func receive(_ part: GRPCServerRequestPart<T>, context: ServerInterceptorContext<T, U>) {
        if logger.logLevel <= .debug {
            if case let .metadata(headers) = part {
                logger.debug("\(headers[":path"])")
            }
            if case let .message(request) = part,
               let jsonString = try? request.jsonString() {
                logger.debug("\(type(of: part)): \(jsonString)")
            }
        }
        context.receive(part)
    }

    override func send(_ part: GRPCServerResponsePart<U>, promise: EventLoopPromise<Void>?, context: ServerInterceptorContext<T, U>) {
        if logger.logLevel <= .debug {
            if case let .end(status, _) = part {
                logger.debug("Send: \(status)")
            }
        }

        context.send(part, promise: promise)
    }
}
