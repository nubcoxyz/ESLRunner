import Foundation

import ArgumentParser
import ESLogger
import Logging

// ParsableCommand has a "public static func main()" that then calls run()
@main
public struct ESLRunner: ParsableCommand {
    @Flag(name: .long, help: "Print JSON from *inside* ESLogger") var json = false
    @Flag(name: .long, help: "Short circuit ESLogger after JSON print") var jsonOnly = false
    @Flag(name: .shortAndLong, help: "ESLogger debug mode") var verbose = false
    @Flag(name: .long, help: "Debug mode (very verbose)") var verboseVerbose = false
    @Flag(name: .long, help: "Don't print JSON from *inside* ESLogger") var noJSON = false
    @Option(name: .long, help: "Read from filename") var infilename: String?
    @Argument var events: [String] = []

    enum ESLRunnerError: Error {
        case commandLineMissingEvents
        case userRequestedExit
    }

    public init() {}

    func eventPrinter(_ event: ESMessage) {
        print("*-*-*-*-*-*-*-*-*-*-*-\(event.event_type)")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        print("\(event.process.executable.path)")
        if let signingid = event.process.signing_id {
            print("\(signingid)")
        }
        print("pid: \(event.process.audit_token.pid) ppid: \(event.process.ppid)")
        if !noJSON {
            if let json = try? encoder.encode(event.event) {
                let theString = String(data: json, encoding: .utf8)
                print(theString ?? "ERROR - UNABLE TO CONVERT JSON OBJECT TO STRING")
            } else {
                print(event.event)
            }
        }
        print("code signing: \(event.process.codesigning_flags)")
    }

    func eventError(_ error: ESLogger.Error) {
        print("/\\/\\/\\/\\/\\/\\/ ERROR /\\/\\/\\/\\/\\/\\/")
        print("\(error)")
        print("/\\/\\/\\/\\/\\/\\/")
    }

    public mutating func run() throws {
        // provide exit hatch
        let signalCallback: sig_t = {_ in
            ESLRunner.exit(withError: ESLRunnerError.userRequestedExit)
        }
        signal(SIGINT, signalCallback)

        do {
            if events.count < 1 && infilename == nil {
                print("no events to listen for, need to specify at least one or filename")
                throw ESLRunnerError.commandLineMissingEvents
            }

            var logLevel: Logger.Level = .info
            if verbose {
                logLevel = .debug
            }
            if verboseVerbose {
                logLevel = .trace
            }

            let eslogger: ESLogger?
            if infilename != nil {
                eslogger = ESLoggerFile(withFileURL: URL(fileURLWithPath: infilename!),
                                        callHandler: eventPrinter,
                                        errorHandler: eventError,
                                        withLogLevel: logLevel)
            } else {
                eslogger = try ESLogger(forEvents: Set(events),
                                        callHandler: eventPrinter,
                                        errorHandler: eventError,
                                        withLogLevel: logLevel)
            }

            if json {
                eslogger?.printJSON = true
                eslogger?.onlyJSON = false
            }
            if jsonOnly {
                eslogger?.printJSON = true
                eslogger?.onlyJSON = false
            }

            if let esl = eslogger as? ESLoggerFile {
                esl.start()
            } else if let esl = eslogger {
                print("listening for \(esl.requestedEventNames.count) event types")
                try eslogger?.start()

                var lastDrop = 0
                while esl.isRunning {
                    Thread.sleep(forTimeInterval: 2)
                    if esl.eventsDropped > lastDrop {
                        print("******* DROPPED \(esl.eventsDropped-lastDrop)")
                        lastDrop = esl.eventsDropped
                    }
                }
            } else {
                print("eslogger is nil or unknown type")
            }
        } catch ESLogger.Error.noValidRequestedEvents {
            print("Validation Error - no valid events provided")
            return
        } catch {
            print("exception - \(error)")
        }
    }
}
