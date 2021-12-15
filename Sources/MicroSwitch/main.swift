import ArgumentParser
import Dispatch
import Files
import Foundation
import Logging
import SwiftProtobuf

let processName = ProcessInfo.processInfo.processName
var logger = Logger(label: processName)
private var signalSource: DispatchSourceSignal?

struct MicroSwitch: ParsableCommand {
    @Option(name: .shortAndLong, help: "The hostname to bind to")
    var host = "::1"

    @Option(name: .shortAndLong, help: "The port to bind to")
    var port = 1979

    @Flag(name: .shortAndLong, help: "Disable SSL")
    var insecure = false

    @Flag(name: .shortAndLong, help: "Force POSIX Sockets")
    var forcePosix = false

    @Flag(name: .shortAndLong, help: "Debug")
    var debug = false

    func run() {
        if debug {
            logger.logLevel = .debug
        }
        registerSIGINT()

        var info = ServerInfo.load()
        let startDate = Date()
        info.startedAt = .init(date: startDate)
        try? info.save()

        logger.info("Starting at \(startDate) pid \(ProcessInfo.processInfo.processIdentifier)")
        if (info.hasLastShutdown) {
            logger.info("Last shutdown \(info.lastShutdown.date)")
        } else {
            logger.info("First start")
        }

        MicroSwitchServer(host: host, port: port)
            .listen(insecure: insecure, forcePosix: forcePosix)
    }

    private func registerSIGINT() {
        let source = DispatchSource.makeSignalSource(
            signal: SIGINT,
            queue: .init(label: processName + ".shutdown.queue"))
        source.setEventHandler {
            print()
            var info = ServerInfo.load()
            info.lastShutdown = .init(date: Date())
            if let _ = try? info.save() {
                logger.info("Shutting down at \(info.lastShutdown.date)")
                exit(EXIT_SUCCESS)
            }
            exit(EXIT_FAILURE)
        }
        source.resume()
        signalSource = source
        signal(SIGINT, SIG_IGN)
    }

    private func exit(_ status: Int32) {
        #if os(Linux)
        Glibc.exit(status)
        #else
        Darwin.exit(status)
        #endif
    }
}

MicroSwitch.main()
