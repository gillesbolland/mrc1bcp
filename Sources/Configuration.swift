import Foundation

// MARK: - Configuration Structure

struct Configuration: Codable {
    var hevcTranscoding: HEVCSettings
    var paths: PathSettings
    var preferences: Preferences
    
    struct HEVCSettings: Codable {
        var enabled: Bool
        var dvBitrate: String
        var dvParameters: [String]
        var hdvBitrate: String
        var hdvParameters: [String]
        
        static var `default`: HEVCSettings {
            return HEVCSettings(
                enabled: false,
                dvBitrate: "13M",
                dvParameters: [
                    "-c:v", "hevc_videotoolbox",
                    "-tag:v", "hvc1",
                    "-pix_fmt", "yuv420p",
                    "-c:a", "aac",
                    "-b:a", "256k",
                    "-ar", "48000",
                    "-ac", "2"
                ],
                hdvBitrate: "26M",
                hdvParameters: [
                    "-c:v", "hevc_videotoolbox",
                    "-tag:v", "hvc1",
                    "-pix_fmt", "yuv420p",
                    "-c:a", "aac",
                    "-b:a", "256k",
                    "-ar", "48000",
                    "-ac", "2"
                ]
            )
        }
    }
    
    struct PathSettings: Codable {
        var ffmpegPath: String
        var mediainfoPath: String
        var defaultSourceVolume: String
        
        static var `default`: PathSettings {
            return PathSettings(
                ffmpegPath: "/opt/homebrew/bin/ffmpeg",
                mediainfoPath: "/opt/homebrew/bin/mediainfo",
                defaultSourceVolume: "/Volumes/VIDEO"
            )
        }
    }
    
    struct Preferences: Codable {
        var autoEjectAfterImport: Bool
        var createBackupBeforeConversion: Bool
        var verboseLogging: Bool
        var rememberLastPaths: Bool
        var lastSourcePath: String?
        var lastDestinationPath: String?
        var lastRun: LastRunOptions?
        
        struct LastRunOptions: Codable {
            var optimize: Bool
            var createProxies: Bool
            var createArchive: Bool
            var ejectAfterImport: Bool
        }
        
        static var `default`: Preferences {
            return Preferences(
                autoEjectAfterImport: false,
                createBackupBeforeConversion: false,
                verboseLogging: true,
                rememberLastPaths: false,
                lastSourcePath: nil,
                lastDestinationPath: nil,
                lastRun: nil
            )
        }
    }
    
    static var `default`: Configuration {
        return Configuration(
            hevcTranscoding: .default,
            paths: .default,
            preferences: .default
        )
    }
}

// MARK: - Configuration Manager

class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private let configDirectory: String
    private let configFilePath: String
    private var configuration: Configuration
    
    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.configDirectory = "\(home)/.config/mrc1bcp"
        self.configFilePath = "\(configDirectory)/config.json"
        
        // Load or create default configuration
        if let loadedConfig = ConfigurationManager.loadConfiguration(from: configFilePath) {
            self.configuration = loadedConfig
        } else {
            self.configuration = .default
        }
    }
    
    static func initializeIfNeeded() {
        let manager = shared
        
        // Ensure config directory exists
        do {
            try FileManager.default.ensureDirectoryExists(atPath: manager.configDirectory)
            
            // Create default config if it doesn't exist
            if !FileManager.default.fileExists(atPath: manager.configFilePath) {
                try manager.saveConfiguration()
                print(colorize("Created default configuration at \(manager.configFilePath)", color: ConsoleColor.green))
            }
        } catch {
            print(colorize("⚠️  Warning: Could not create configuration directory: \(error)", color: ConsoleColor.yellow))
        }
    }
    
    static func getConfiguration() -> Configuration {
        return shared.configuration
    }
    
    static func updateConfiguration(_ config: Configuration) throws {
        shared.configuration = config
        try shared.saveConfiguration()
    }
    
    private static func loadConfiguration(from path: String) -> Configuration? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(Configuration.self, from: data)
    }
    
    private func saveConfiguration() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(configuration)
        try data.write(to: URL(fileURLWithPath: configFilePath))
    }
}

// MARK: - Dependency Checker

struct DependencyChecker {
    static func checkDependencies() -> Bool {
        let config = ConfigurationManager.getConfiguration()
        var criticalDependenciesMet = true
        
        print("\nChecking dependencies...")
        
        // Check ffmpeg (REQUIRED)
        if !commandExists(at: config.paths.ffmpegPath) {
            print(colorize("[ERROR] ffmpeg not found at \(config.paths.ffmpegPath)", color: ConsoleColor.red))
            print(colorize("   Install with: brew install ffmpeg", color: ConsoleColor.yellow))
            criticalDependenciesMet = false
        } else {
            print(colorize("[OK] ffmpeg found", color: ConsoleColor.green))
        }
        
        // Check mediainfo (OPTIONAL - only for metadata extraction)
        if !commandExists(at: config.paths.mediainfoPath) {
            print(colorize("[WARNING] mediainfo not found - metadata extraction from files will be limited", color: ConsoleColor.yellow))
            print(colorize("   Install with: brew install mediainfo (recommended)", color: ConsoleColor.yellow))
        } else {
            print(colorize("[OK] mediainfo found", color: ConsoleColor.green))
        }
        
        print("")
        return criticalDependenciesMet
    }
    
    private static func commandExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
}
