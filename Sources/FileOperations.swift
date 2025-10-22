import Foundation

// MARK: - File Operations

class FileOperations {
    let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    /// Import clips by copying/merging to destination
    func importClips(_ clips: [MediaClip], to structure: FCPDirectoryStructure, from sourcePath: String) throws {
        var importedClips: [ImportMetadata.ClipMetadata] = []
        var successCount = 0
        var failCount = 0
        
        print("\n" + colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print(colorize("  Starting Import", color: ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print("")
        
        for (index, clip) in clips.enumerated() {
            guard let newFileName = clip.newFileName else {
                logger.log("Skipping clip \(clip.clipID) - no filename generated", level: .warning)
                failCount += 1
                continue
            }
            
            let destinationPath = "\(structure.originalMedia)/\(newFileName)"
            
            print(colorize("[\(index + 1)/\(clips.count)] Processing Clip \(clip.clipID)...", color: ConsoleColor.cyan))
            
            do {
                if clip.isMultiSegment {
                    // Merge segments
                    try mergeSegments(clip.segments, to: destinationPath)
                    logger.log("Merged \(clip.segments.count) segments into \(newFileName)", level: .success)
                } else {
                    // Single file copy
                    try copySingleFile(from: clip.segments[0].filePath, to: destinationPath)
                    logger.log("Copied \(clip.segments[0].originalFileName) to \(newFileName)", level: .success)
                }
                
                // Update file timestamp to match recording date
                if let recordingDate = clip.recordingDate {
                    updateFileTimestamp(path: destinationPath, date: recordingDate)
                }
                
                // Calculate file size
                let fileSize = try FileManager.default.attributesOfItem(atPath: destinationPath)[.size] as? Int64 ?? 0
                
                // Create metadata entry
                let clipMetadata = ImportMetadata.ClipMetadata(
                    clipID: clip.clipID,
                    originalFileNames: clip.segments.map { $0.originalFileName },
                    newFileName: newFileName,
                    recordingTime: clip.recordingDate?.description ?? "Unknown",
                    format: clip.format.rawValue,
                    wasSegmented: clip.isMultiSegment,
                    fileSize: fileSize
                )
                importedClips.append(clipMetadata)
                
                successCount += 1
                print(colorize("  [OK] Success: \(newFileName)", color: ConsoleColor.green))
                
            } catch {
                logger.log("Failed to import clip \(clip.clipID): \(error)", level: .error)
                print(colorize("  [FAILED] \(error)", color: ConsoleColor.red))
                failCount += 1
            }
            
            print("")
        }
        
        // Save import metadata
        let metadata = ImportMetadata(
            importDate: Date(),
            sourceVolume: sourcePath,
            destinationPath: structure.rootPath,
            clips: importedClips
        )
        
        let metadataPath = "\(structure.rootPath)/import_metadata.json"
        try metadata.save(to: metadataPath)
        logger.log("Saved import metadata to \(metadataPath)", level: .success)
        
        // Remember last paths in config if enabled
        var config = ConfigurationManager.getConfiguration()
        if config.preferences.rememberLastPaths {
            config.preferences.lastSourcePath = sourcePath
            config.preferences.lastDestinationPath = structure.rootPath
            try? ConfigurationManager.updateConfiguration(config)
        }
        
        // Summary
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print(colorize("  Import Summary", color: ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print(colorize("  Successful: \(successCount)", color: ConsoleColor.green))
        if failCount > 0 {
            print(colorize("  Failed: \(failCount)", color: ConsoleColor.red))
        }
        print("")
    }
    
    /// Merge multiple segment files into one
    private func mergeSegments(_ segments: [MediaClip.Segment], to destinationPath: String) throws {
        // Create the destination file
        FileManager.default.createFile(atPath: destinationPath, contents: nil, attributes: nil)
        
        guard let fileHandle = FileHandle(forWritingAtPath: destinationPath) else {
            throw FileOperationError.cannotOpenFile(destinationPath)
        }
        
        defer { fileHandle.closeFile() }
        
        // Append each segment
        for segment in segments {
            guard let segmentData = try? Data(contentsOf: URL(fileURLWithPath: segment.filePath)) else {
                throw FileOperationError.cannotReadSegment(segment.filePath)
            }
            fileHandle.write(segmentData)
        }
    }
    
    /// Copy a single file
    private func copySingleFile(from sourcePath: String, to destinationPath: String) throws {
        // Remove destination if it exists
        if FileManager.default.fileExists(atPath: destinationPath) {
            try FileManager.default.removeItem(atPath: destinationPath)
        }
        
        try FileManager.default.copyItem(atPath: sourcePath, toPath: destinationPath)
    }
    
    /// Update file modification and creation timestamps
    private func updateFileTimestamp(path: String, date: Date) {
        // Use touch command for more reliable timestamp setting
        let touchDateString = DateFormatter.touchCommand.string(from: date)
        let _ = runShellCommand("/usr/bin/touch", arguments: ["-t", touchDateString, path])
    }
    
    enum FileOperationError: Error {
        case cannotOpenFile(String)
        case cannotReadSegment(String)
        case copyFailed(String)
    }
}
