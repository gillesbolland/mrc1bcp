import Foundation

// MARK: - Interactive Workflow

struct InteractiveWorkflow {
    static func start() {
        let config = ConfigurationManager.getConfiguration()
        
        // Step 1: Import
        print("\n" + colorize("STEP 1: Import clips from Sony HVR-MRC1", color: ConsoleColor.cyan + ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        
        let defaultSource = (ConfigurationManager.getConfiguration().preferences.rememberLastPaths ? (ConfigurationManager.getConfiguration().preferences.lastSourcePath ?? config.paths.defaultSourceVolume) : config.paths.defaultSourceVolume)
        let defaultDest = (ConfigurationManager.getConfiguration().preferences.rememberLastPaths ? (ConfigurationManager.getConfiguration().preferences.lastDestinationPath ?? FileManager.default.currentDirectoryPath) : FileManager.default.currentDirectoryPath)
        let sourcePath = promptSourcePath(defaultPath: defaultSource)
        let destinationPath = promptDestinationPath(defaultPath: defaultDest)
        
        do {
            try ImportCommand.performImport(sourcePath: sourcePath, destinationPath: destinationPath, interactive: true)
        } catch {
            print(colorize("[ERROR] Import failed: \(error)", color: ConsoleColor.red))
            exit(1)
        }
        
        // Ask about ejecting
        let eject = promptYesNo("Do you want to eject the memory card?", defaultYes: false)
        if eject {
            ejectVolume(sourcePath)
        }
        
        // Step 2: Conversion
        print("\n" + colorize("STEP 2: Optimize media for Final Cut Pro", color: ConsoleColor.cyan + ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        
        var optimizeChosen = false
        var proxiesChosen = false
        
        if !promptYesNo("Do you want to optimize the clips for Final Cut Pro (MOV)?", defaultYes: true) {
            print(colorize("[WARNING] Final Cut Pro might not be able to read original files directly.", color: ConsoleColor.yellow))
            
            let createProxies = promptYesNo("Would you like to create HEVC proxy files instead?", defaultYes: false)
            if createProxies {
                do {
                    let module = ConversionModule(destinationPath: destinationPath)
                    try module.transcodeFiles()
                    proxiesChosen = true
                } catch {
                    print(colorize("[ERROR] Transcoding failed: \(error)", color: ConsoleColor.red))
                }
            } else {
                let skipArchive = promptYesNo("Skip creating FCP Camera Archive as well?", defaultYes: false)
                if !skipArchive {
                    // Still create archive
                    try? createArchive(destinationPath: destinationPath)
                }
                print(colorize("Workflow completed", color: ConsoleColor.green))
                
                // Save last run options and return
                var cfg = ConfigurationManager.getConfiguration()
                cfg.preferences.lastRun = Configuration.Preferences.LastRunOptions(
                    optimize: optimizeChosen,
                    createProxies: proxiesChosen,
                    createArchive: !skipArchive,
                    ejectAfterImport: eject
                )
                try? ConfigurationManager.updateConfiguration(cfg)
                return
            }
        } else {
            // Perform optimization
            do {
                let module = ConversionModule(destinationPath: destinationPath)
                try module.remuxFiles()
                optimizeChosen = true
            } catch {
                print(colorize("[ERROR] Remux failed: \(error)", color: ConsoleColor.red))
                exit(1)
            }
            
            // Optional: Also create HEVC proxies
            if config.hevcTranscoding.enabled || promptYesNo("Do you also want to create HEVC proxy files?", defaultYes: false) {
                do {
                    let module = ConversionModule(destinationPath: destinationPath)
                    try module.transcodeFiles()
                    proxiesChosen = true
                } catch {
                    print(colorize("[WARNING] HEVC transcoding failed: \(error)", color: ConsoleColor.yellow))
                }
            }
        }
        
        // Step 3: Create FCP Archive
        print("\n" + colorize("STEP 3: Create Final Cut Pro Camera Archive", color: ConsoleColor.cyan + ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        
        let shouldCreateArchive = promptYesNo("Do you want to create a Final Cut Pro Camera Archive (.fcarch)?", defaultYes: true)
        if shouldCreateArchive {
            try? createArchive(destinationPath: destinationPath)
        }
        
        print("\n" + colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.green))
        print(colorize("  Workflow Completed Successfully!", color: ConsoleColor.green + ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.green))
        print("")
        
        // Save last run options
        var cfg = ConfigurationManager.getConfiguration()
        cfg.preferences.lastRun = Configuration.Preferences.LastRunOptions(
            optimize: optimizeChosen,
            createProxies: proxiesChosen,
            createArchive: shouldCreateArchive,
            ejectAfterImport: eject
        )
        try? ConfigurationManager.updateConfiguration(cfg)
    }
    
    private static func promptSourcePath(defaultPath: String) -> String {
        print(colorize("\nSource Memory Card", color: ConsoleColor.yellow))
        
        // Check if default path exists
        if FileManager.default.fileExists(atPath: defaultPath) {
            print(colorize("Suggested: \(defaultPath)", color: ConsoleColor.green))
            if promptYesNo("Use suggested source?", defaultYes: true) {
                return defaultPath
            }
        }
        
        // List available volumes
        let volumes = try? FileManager.default.contentsOfDirectory(atPath: "/Volumes")
        if let volumes = volumes, !volumes.isEmpty {
            print(colorize("\nAvailable volumes:", color: ConsoleColor.cyan))
            for volume in volumes {
                print("  - /Volumes/\(volume)")
            }
        }
        
        let path = promptUser("\nEnter source path:", defaultValue: defaultPath)
        return path
    }
    
    private static func promptDestinationPath(defaultPath: String) -> String {
        print(colorize("\nDestination Folder", color: ConsoleColor.yellow))
        print(colorize("Suggested: \(defaultPath)", color: ConsoleColor.cyan))
        
        if promptYesNo("Use suggested destination?", defaultYes: true) {
            return defaultPath
        }
        
        let path = promptUser("Enter destination path:", defaultValue: defaultPath)
        return path
    }
    
    private static func ejectVolume(_ volumePath: String) {
        print(colorize("\nEjecting volume...", color: ConsoleColor.cyan))
        let result = runShellCommand("/usr/sbin/diskutil", arguments: ["eject", volumePath])
        
        if result.exitCode == 0 {
            print(colorize("Volume ejected successfully", color: ConsoleColor.green))
        } else {
            print(colorize("[WARNING] Failed to eject volume", color: ConsoleColor.yellow))
        }
    }
    
    private static func createArchive(destinationPath: String) throws {
        let module = ArchiveModule(destinationPath: destinationPath)
        try module.createArchive()
    }
}
