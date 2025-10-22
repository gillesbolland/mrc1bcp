import Foundation

// MARK: - Console Colors

struct ConsoleColor {
    static let reset = "\u{001B}[0m"
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan = "\u{001B}[36m"
    static let bold = "\u{001B}[1m"
}

func colorize(_ text: String, color: String) -> String {
    return "\(color)\(text)\(ConsoleColor.reset)"
}

// MARK: - Shell Command Execution

func runShellCommand(_ command: String, arguments: [String] = []) -> (output: String, exitCode: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    // IMPORTANT: Close stdin so process doesn't wait for input
    let stdinPipe = Pipe()
    process.standardInput = stdinPipe
    try? stdinPipe.fileHandleForWriting.close()
    
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return ("", -1)
    }
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    
    return (output, process.terminationStatus)
}

// MARK: - User Input Helpers

func promptUser(_ message: String, defaultValue: String = "y") -> String {
    print("\(message) ", terminator: "")
    if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty {
        return input
    }
    return defaultValue
}

func promptYesNo(_ message: String, defaultYes: Bool = true) -> Bool {
    let prompt = defaultYes ? "[Y/n]" : "[y/N]"
    let response = promptUser("\(message) \(prompt):", defaultValue: defaultYes ? "y" : "n")
    return response.lowercased().starts(with: "y")
}

// MARK: - File System Helpers

extension FileManager {
    func directoryExists(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    func ensureDirectoryExists(atPath path: String) throws {
        if !directoryExists(atPath: path) {
            try createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
    }
}

// MARK: - Date Formatting

extension DateFormatter {
    static let recordedDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    static let filename: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    static let touchCommand: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm.ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

// MARK: - Logging

class Logger {
    private let logFilePath: String
    
    init(destinationPath: String) {
        self.logFilePath = "\(destinationPath)/mrc1bcp.log"
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let logMessage = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
        
        // Print to console
        switch level {
        case .info:
            print(colorize("[INFO] \(message)", color: ConsoleColor.blue))
        case .success:
            print(colorize("[OK] \(message)", color: ConsoleColor.green))
        case .warning:
            print(colorize("[WARNING] \(message)", color: ConsoleColor.yellow))
        case .error:
            print(colorize("[ERROR] \(message)", color: ConsoleColor.red))
        case .debug:
            print(colorize("[DEBUG] \(message)", color: ConsoleColor.cyan))
        }
        
        // Append to log file
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFilePath) {
                if let fileHandle = FileHandle(forWritingAtPath: logFilePath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logFilePath))
            }
        }
    }
    
    enum LogLevel: String {
        case info = "INFO"
        case success = "SUCCESS"
        case warning = "WARNING"
        case error = "ERROR"
        case debug = "DEBUG"
    }
}

// MARK: - Progress Indicator

class ProgressIndicator {
    private var isRunning = false
    private var thread: Thread?
    
    func start(message: String) {
        isRunning = true
        print("\(message) ", terminator: "")
        fflush(stdout)
        
        thread = Thread {
            let spinChars = ["|", "/", "-", "\\"]
            var index = 0
            while self.isRunning {
                print("\u{8}\(spinChars[index])", terminator: "")
                fflush(stdout)
                Thread.sleep(forTimeInterval: 0.1)
                index = (index + 1) % spinChars.count
            }
        }
        thread?.start()
    }
    
    func stop(finalMessage: String = "Done") {
        isRunning = false
        thread?.cancel()
        print("\u{8}\(finalMessage)")
    }
}
