import Foundation

// MARK: - Archive Module

class ArchiveModule {
    let logger: Logger
    let structure: FCPDirectoryStructure
    
    init(destinationPath: String) {
        self.logger = Logger(destinationPath: destinationPath)
        self.structure = FCPDirectoryStructure(rootPath: destinationPath)
    }
    
    /// Create Final Cut Pro Camera Archive
    func createArchive() throws {
        print("\n" + colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print(colorize("  Creating Final Cut Pro Camera Archive", color: ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print("")
        
        // Scan directories for media files
        let mediaFiles = try scanMediaFiles()
        
        if mediaFiles.isEmpty {
            logger.log("No media files found to include in archive", level: .warning)
            return
        }
        
        logger.log("Found \(mediaFiles.count) media file(s) for archive", level: .info)
        
        // Find oldest date among all files
        let oldestDate = findOldestDate(from: mediaFiles)
        
        // Generate clip IDs for each file
        let clipIDs = mediaFiles.map { _ in ["clipID": UUID().uuidString] }
        
        // Create plist data
        let plistData: [String: Any] = [
            "UUID": UUID().uuidString,
            "archiveDate": oldestDate,
            "archiveVersion": 1.0,
            "clipIDs": clipIDs,
            "deviceName": "Sony HVR-MRC1",
            "isCapture": true
        ]
        
        // Write plist file
        let plistPath = "\(structure.rootPath)/FCArchMetadata.plist"
        let plistDict = plistData as NSDictionary
        
        guard plistDict.write(toFile: plistPath, atomically: true) else {
            throw ArchiveError.plistCreationFailed
        }
        
        logger.log("Created FCArchMetadata.plist", level: .success)
        print(colorize("  [OK] Created FCArchMetadata.plist", color: ConsoleColor.green))
        
        // Rename directory to .fcarch
        let newArchivePath = "\(structure.rootPath).fcarch"
        
        // Check if .fcarch already exists
        if FileManager.default.fileExists(atPath: newArchivePath) {
            print(colorize("  [WARNING] \(newArchivePath) already exists", color: ConsoleColor.yellow))
            print(colorize("  Archive metadata created, but directory not renamed", color: ConsoleColor.yellow))
            return
        }
        
        try FileManager.default.moveItem(atPath: structure.rootPath, toPath: newArchivePath)
        logger.log("Renamed to .fcarch extension", level: .success)
        print(colorize("  [OK] Renamed to .fcarch extension", color: ConsoleColor.green))
        
        // Hide .fcarch extension
        try hideExtension(path: newArchivePath)
        logger.log("Hidden .fcarch extension", level: .success)
        print(colorize("  [OK] Hidden .fcarch extension", color: ConsoleColor.green))
        
        print("")
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print(colorize("  Final Cut Pro Archive Created Successfully!", color: ConsoleColor.green + ConsoleColor.bold))
        print(colorize("  Location: \(newArchivePath)", color: ConsoleColor.cyan))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print("")
    }
    
    /// Scan directories for media files
    private func scanMediaFiles() throws -> [URL] {
        var mediaFiles: [URL] = []
        let mediaExtensions = ["mov", "mp4", "avi", "m4v", "mxf", "mts", "m2t"]
        
        let directories = [
            structure.originalMedia,
            structure.optimizedMedia,
            structure.transcodedMedia
        ]
        
        for directory in directories {
            guard FileManager.default.directoryExists(atPath: directory) else {
                continue
            }
            
            let files = try FileManager.default.contentsOfDirectory(atPath: directory)
            
            for file in files {
                let ext = (file as NSString).pathExtension.lowercased()
                if mediaExtensions.contains(ext) {
                    let filePath = "\(directory)/\(file)"
                    mediaFiles.append(URL(fileURLWithPath: filePath))
                }
            }
        }
        
        return mediaFiles
    }
    
    /// Find the oldest recording date among files
    private func findOldestDate(from files: [URL]) -> String {
        let config = ConfigurationManager.getConfiguration()
        var dates: [Date] = []
        
        for file in files {
            // Try to extract date from mediainfo
            let result = runShellCommand(
                config.paths.mediainfoPath,
                arguments: ["--Inform=General;%Recorded_Date%", file.path]
            )
            
            if result.exitCode == 0 && !result.output.isEmpty {
                let dateString = result.output
                    .replacingOccurrences(of: "UTC ", with: "")
                    .replacingOccurrences(of: " UTC", with: "")
                
                if let date = DateFormatter.recordedDate.date(from: dateString) {
                    dates.append(date)
                }
            }
            
            // Fallback to file modification date
            if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
               let modDate = attributes[.modificationDate] as? Date {
                dates.append(modDate)
            }
        }
        
        // Find oldest date or use current date
        let oldestDate = dates.min() ?? Date()
        
        // Format as "YYYY-MM-DD_HH_MM_SS"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH_mm_ss"
        return formatter.string(from: oldestDate)
    }
    
    /// Hide file extension using xattr
    private func hideExtension(path: String) throws {
        // Use xattr to hide extension
        let result = runShellCommand(
            "/usr/bin/xattr",
            arguments: ["-wx", "com.apple.FinderInfo", "0000000000000000001000000000000000000000000000000000000000000000", path]
        )
        
        if result.exitCode != 0 {
            throw ArchiveError.extensionHideFailed
        }
    }
    
    enum ArchiveError: Error {
        case plistCreationFailed
        case extensionHideFailed
        case noMediaFiles
    }
}

// MARK: - Archive Command

struct ArchiveCommand {
    static func run(with args: [String]) {
        let destinationPath = args.first ?? FileManager.default.currentDirectoryPath
        
        do {
            let module = ArchiveModule(destinationPath: destinationPath)
            try module.createArchive()
        } catch {
            print(colorize("[ERROR] Archive creation failed: \(error)", color: ConsoleColor.red))
            exit(1)
        }
    }
}
