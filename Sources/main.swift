#!/usr/bin/env swift

import Foundation

// MARK: - Main Application Entry Point

struct MRC1BCP {
    static func main() {
        let args = CommandLine.arguments.dropFirst()
        
        if args.isEmpty {
            runInteractiveMode()
        } else {
            handleCommandLineMode(Array(args))
        }
    }
    
    private static func runInteractiveMode() {
        print("Merc1 beaucoup ! A toolbox for the Sony HVR-MRC1")
        print("═══════════════════════════════════════════════════")
        
        // Check dependencies first
        guard DependencyChecker.checkDependencies() else {
            exit(1)
        }
        
        // Initialize configuration
        ConfigurationManager.initializeIfNeeded()
        
        // Start interactive workflow
        InteractiveWorkflow.start()
    }
    
    private static func handleCommandLineMode(_ args: [String]) {
        guard let command = args.first else {
            showHelp()
            return
        }
        
        switch command.lowercased() {
        case "help", "--help", "-h":
            showHelp()
        case "import":
            ImportCommand.run(with: Array(args.dropFirst()))
        case "optimize", "remux", "convert":
            ConvertCommand.run(with: Array(args.dropFirst()))
        case "transcode":
            TranscodeCommand.run(with: Array(args.dropFirst()))
        case "archive":
            ArchiveCommand.run(with: Array(args.dropFirst()))
        case "rename", "timestamp":
            TimestampCommand.run(with: Array(args.dropFirst()))
        case "touchit":
            TouchitCommand.run(with: Array(args.dropFirst()))
        case "autopilot":
            AutopilotCommand.run(with: Array(args.dropFirst()))
        default:
            print("Error: Unknown command: \(command)")
            showHelp()
            exit(1)
        }
    }
    
    private static func showHelp() {
        let help = """
        Merc1 beaucoup ! A toolbox for the Sony HVR-MRC1
        ═══════════════════════════════════════════════════════
        
        DESCRIPTION:
            A tool for processing footage from Sony HVR-MRC1 memory recording units. 
            Optimizes, optionally transcodes, and prepares camera archives for Final Cut Pro.
        
        USAGE:
            mrc1bcp                    # Interactive step-by-step mode
            mrc1bcp [command] [options]
        
        COMMANDS:
            import      Import and merge clips from Sony HVR-MRC1 memory card
            optimize    Optimize media for Final Cut Pro (MOV)
            transcode   Create HEVC proxy files for editing
            archive     Generate Final Cut Pro camera archive (.fcarch)
            rename      Rename files based on metadata timestamps
            touchit     Update file creation dates from filename patterns
            autopilot   Run with previous choices without prompts
        
        INTERACTIVE WORKFLOW:
            When run without arguments, mrc1bcp guides you through:
            1. Import clips from memory card (with duplicate detection)
            2. Optimize for Final Cut Pro (MOV)
            3. Create Final Cut Pro camera archive
        
        EXAMPLES:
            mrc1bcp                                       # Start interactive mode
            mrc1bcp import /Volumes/VIDEO /path/dest      # Import from specific paths
            mrc1bcp optimize /path/to/project             # Optimize media files
            mrc1bcp archive /path/to/project              # Create FCP archive
        
        CONFIGURATION:
            Settings stored in: ~/.config/mrc1bcp/config.json
            Includes HEVC encoding parameters for DV/HDV content, last paths, and autopilot options.
        
        DEPENDENCIES:
            - ffmpeg (install: brew install ffmpeg)
            - mediainfo (optional, install: brew install mediainfo)
        
        For detailed help on specific commands, use:
            mrc1bcp [command] --help
        """
        print(help)
    }
}

// Start the application
MRC1BCP.main()