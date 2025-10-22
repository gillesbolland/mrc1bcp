import Foundation

struct AutopilotCommand {
    static func run(with args: [String]) {
        var config = ConfigurationManager.getConfiguration()
        let prefs = config.preferences
        
        // Determine source and destination
        let sourcePath = args.count > 0 ? args[0] : (prefs.lastSourcePath ?? config.paths.defaultSourceVolume)
        let destinationPath = args.count > 1 ? args[1] : (prefs.lastDestinationPath ?? FileManager.default.currentDirectoryPath)
        
        // Ensure last run options exist
        guard let last = prefs.lastRun else {
            print(colorize("[ERROR] No previous interactive choices found. Run interactive mode once before using autopilot.", color: ConsoleColor.red))
            exit(1)
        }
        
        // Import (non-interactive)
        do {
            try ImportCommand.performImport(sourcePath: sourcePath, destinationPath: destinationPath, interactive: false)
        } catch {
            print(colorize("[ERROR] Autopilot import failed: \(error)", color: ConsoleColor.red))
            exit(1)
        }
        
        // Optimize or Transcode
        let conv = ConversionModule(destinationPath: destinationPath)
        do {
            if last.optimize {
                try conv.remuxFiles()
            } else if last.createProxies {
                try conv.transcodeFiles()
            }
        } catch {
            print(colorize("[WARNING] Autopilot media processing step failed: \(error)", color: ConsoleColor.yellow))
        }
        
        // Archive
        if last.createArchive {
            do {
                let arch = ArchiveModule(destinationPath: destinationPath)
                try arch.createArchive()
            } catch {
                print(colorize("[WARNING] Autopilot archive step failed: \(error)", color: ConsoleColor.yellow))
            }
        }
        
        // Eject
        if last.ejectAfterImport {
            let _ = runShellCommand("/usr/sbin/diskutil", arguments: ["eject", sourcePath])
        }
        
        // Update last paths
        if config.preferences.rememberLastPaths {
            config.preferences.lastSourcePath = sourcePath
            config.preferences.lastDestinationPath = destinationPath
            try? ConfigurationManager.updateConfiguration(config)
        }
    }
}
