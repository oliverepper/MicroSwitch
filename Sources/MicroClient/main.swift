import ArgumentParser
import Foundation
import GRPC

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
let uptimeFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.day, .hour, .minute, .second]
    formatter.unitsStyle = .full
    return formatter
}()
#endif

struct MicroClient: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A client to interact with a MicroSwitch server",
        version: "0.0.1",
        subcommands: [
            ServerInfo.self,
            AddToken.self,
            Invite.self,
            Signal.self
        ],
        defaultSubcommand: ServerInfo.self
    )
}

struct Options: ParsableArguments {
    @Option(name: .shortAndLong, help: "The hostname to connect to")
    var host = "::1"

    @Option(name: .shortAndLong, help: "The port to connect to")
    var port = 1979

    @Flag(name: .long, help: "Disable SSL")
    var insecure = false

    func getConnection() -> ClientConnection {
        let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)

        if (insecure) {
            return .init(
                configuration: .default(
                    target: .hostAndPort(host, port),
                    eventLoopGroup: group))
        }
        return ClientConnection.usingPlatformAppropriateTLS(for: group)
            .connect(host: host, port: port)
    }
}

extension MicroClient {

    struct ServerInfo: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Query the server for ServerInfo")

        @OptionGroup var options: Options

        func run() throws {

            let client = ServerInfoServiceClient(channel: options.getConnection())

            let request = client.info(.init())

            request.response.whenComplete { result in
                switch result {
                case let .success(info):
                    let startDate = info.startedAt.date
                    let uptime = Date().timeIntervalSince(startDate)
                    print("Server started at: \(info.startedAt.date)")
                    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
                    print("Server uptime: \(uptimeFormatter.string(from: uptime) ?? "Unknown")")
                    #else
                    // TODO: Format this better
                    print("Server uptime: \(uptime)")
                    #endif
                case let .failure(error):
                    print("Error: \(error)")
                }
            }

            _ = try? request.status.wait()
        }
    }

    struct AddToken: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Add push-token for a specific handle"
        )

        @OptionGroup var options: Options

        @Option(name: .shortAndLong, help: "The token to add")
        var token: String

        @Argument(help: "The handle to add the token to")
        var handle: String


        func run() throws {
            let client = PushServiceClient(channel: options.getConnection())

            let request = client.add(.with {
                $0.token = token
                $0.handle = handle
            })

            request.status.whenComplete { result in
                switch result {
                case let .success(status):
                    if let message = status.message {
                        print(message)
                    } else {
                        print("done")
                    }
                case let .failure(error):
                    print(error)
                }
            }

            _ = try request.status.wait()
        }
    }

    struct Invite: ParsableCommand {
        struct Payload: Codable {
            let sessionID: UUID
        }

        static var configuration = CommandConfiguration(
            abstract: "Add push-token for a specific handle"
        )

        @OptionGroup var options: Options

        @Argument(help: "The handle to add the token to")
        var handles: [String]

        @Option(help: "The handle to add the token to")
        var session: String


        func run() throws {
            guard let sessionID = UUID(uuidString: session),
            let data = try? JSONEncoder().encode(Payload(sessionID: sessionID)) else {
                print("\(session) ist not a valid UUID")
                return
            }

            let client = PushServiceClient(channel: options.getConnection())

            let request = client.invite(.with {
                $0.from = "Me"
                $0.to = handles
                $0.payload = data
            }) { response in
                print(response)
            }

            request.status.whenComplete { result in
                switch result {
                case let .success(status):
                    if let message = status.message {
                        print(message)
                    } else {
                        print("done")
                    }
                case let .failure(error):
                    print(error)
                }
            }

            _ = try request.status.wait()
        }
    }

    struct Signal: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Signal something"
        )

        @OptionGroup var options: Options

        func run() throws {
            let client = SignalServiceClient(channel: options.getConnection())

            let stream = client.signal { signal in
                print(signal)
            }

            stream.status.whenFailure { error in
                print(error)
            }

            var line: String
            repeat {
                line = readLine(strippingNewline: true) ?? ".q"
                if let cmd = line.components(separatedBy: " ").first {
                    if cmd == ".i" {
                        print("Not yet implemented")
                    }
                    if cmd == ".c" {
                        print("Sending connect")
                        _ = stream.sendMessage(.with {
                            $0.connect = .with {
                                if let first = line.components(separatedBy: " ").dropFirst().first,
                                   let id = UUID(uuidString: first) {
                                    $0.sessionID = id.uuidString
                                }
                            }
                        })
                    }
                    if cmd == ".b" {
                        print("Sending broadcast")
                        _ = stream.sendMessage(.with {
                            $0.broadcast = .with {
                                if let first = line.components(separatedBy: " ").dropFirst().first,
                                   let id = UUID(uuidString: first) {
                                    $0.sessionID = id.uuidString
                                    $0.payload = line.components(separatedBy: " ").dropFirst(2).joined(separator: " ").data(using: .utf8) ?? Data()
                                } else {
                                    $0.payload = line.components(separatedBy: " ").dropFirst().joined(separator: " ").data(using: .utf8) ?? Data()
                                }
                            }
                        })
                    }
                }
            } while line != ".q"

            _ = stream.sendEnd()

            _ = try? stream.status.wait()
        }
    }

}

MicroClient.main()
