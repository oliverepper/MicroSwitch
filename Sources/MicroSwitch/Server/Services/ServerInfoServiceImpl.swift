import GRPC
import NIO
import SwiftProtobuf

final class ServerInfoServiceInterceptorFactory: ServerInfoServiceServerInterceptorFactoryProtocol {
    func makeinfoInterceptors() -> [ServerInterceptor<Google_Protobuf_Empty, ServerInfo>] {
        return [LoggingInterceptor()]
    }
}

class ServerInfoServiceImpl: ServerInfoServiceProvider {
    var interceptors: ServerInfoServiceServerInterceptorFactoryProtocol? {
        return ServerInfoServiceInterceptorFactory()
    }

    func info(request: Google_Protobuf_Empty, context: StatusOnlyCallContext) -> EventLoopFuture<ServerInfo> {
        return context.eventLoop.makeSucceededFuture(ServerInfo.load())
    }
}

