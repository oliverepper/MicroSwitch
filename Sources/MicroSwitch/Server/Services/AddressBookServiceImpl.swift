import Foundation
import GRPC
import SwiftProtobuf
import NIO

final class AddressBookServiceInterceptorFactory: AddressBookServiceServerInterceptorFactoryProtocol {
    func makelistInterceptors() -> [ServerInterceptor<Google_Protobuf_Empty, Handle>] {
        return [LoggingInterceptor()]
    }
}

final class AddressBookServiceImpl: AddressBookServiceProvider {
    var interceptors: AddressBookServiceServerInterceptorFactoryProtocol? {
        return AddressBookServiceInterceptorFactory()
    }

    func list(request: Google_Protobuf_Empty, context: StreamingResponseCallContext<Handle>) -> EventLoopFuture<GRPCStatus> {
        Handle.list().forEach { handle in
            context.sendResponse(handle).cascade(to: nil)
        }

        return context.eventLoop.makeSucceededFuture(.ok)
    }
}
