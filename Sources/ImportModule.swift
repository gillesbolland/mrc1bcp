import Foundation

// MARK: - Import Module

class ImportModule {
    let config: Configuration
    let logger: Logger
    
    init(destinationPath: String) {
        self.config = ConfigurationManager.getConfiguration()
        self.logger = Logger(destinationPath: destinationPath)
    }
    
    /// Scan the Sony HVR-MRC1 memory card and organize clips
    func scanMemoryCard(sourcePath: String) -> [MediaClip]? {
        let hvrPath = "\(sourcePath)/VIDEO/HVR"
        
        guard FileManager.default.directoryExists(atPath: hvrPath) else {
            logger.log("HVR directory not found at \(hvrPath)", level: .error)
            return nil
        }
        
        logger.log("Scanning memory card at \(hvrPath)", level: .info)
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: hvrPath) else {
            logger.log("Failed to read directory contents", level: .error)
            return nil
        }
        
        // Parse and organize clips
        var clipDict: [String: [URL]] = [:]
        
        for file in files {
            let filePath = "\(hvrPath)/\(file)"
            let fileName = file.lowercased()
            
            // Check for valid video extensions
            guard fileName.hasSuffix(".m2t") || fileName.hasSuffix(".dv") || fileName.hasSuffix(".avi") else {
                continue
            }
            
            // Parse filename: format is typically XX_XXXX_YYYY-MM-DD_HHMMSS.ext
            let components = fileName.split(separator: "_")
            guard components.count >= 4 else {
                logger.log("Skipping file with unexpected format: \(fileName)", level: .warning)
                continue
            }
            
            let clipID = String(components[1])
            let url = URL(fileURLWithPath: filePath)
            clipDict[clipID, default: []].append(url)
        }
        
        // Convert to MediaClip objects
        var clips: [MediaClip] = []
        
        for (clipID, fileURLs) in clipDict {
            let sortedFiles = fileURLs.sorted { $0.lastPathComponent < $1.lastPathComponent }
            let segments = sortedFiles.map { fileURL -> MediaClip.Segment in
                let filename = fileURL.lastPathComponent
                let components = filename.split(separator: "_")
                let timestamp = components.count >= 4 ? String(components[2] + "_" + components[3].split(separator: ".")[0]) : ""
                let ext = fileURL.pathExtension
                
                return MediaClip.Segment(
                    originalFileName: filename,
                    filePath: fileURL.path,
                    timestamp: timestamp,
                    fileExtension: ext
                )
            }
            
            // Detect format using mediainfo on first segment
            let format = detectVideoFormat(filePath: segments[0].filePath)
            
            var clip = MediaClip(
                clipID: clipID,
                segments: segments,
                format: format
            )
            
            // Extract recording date from first segment
            if let date = extractRecordingDate(from: segments[0].filePath) {
                clip.recordingDate = date
                clip.newFileName = generateNewFileName(from: date, extension: segments[0].fileExtension)
            }
            
            clips.append(clip)
        }
        
        // Sort clips by clipID
        clips.sort { $0.clipID < $1.clipID }
        
        logger.log("Found \(clips.count) clip(s)", level: .success)
        return clips
    }
    
    /// Extract recording date from media file using mediainfo
    private func extractRecordingDate(from filePath: String) -> Date? {
        // First, try to extract from filename (format: 00_0000_YYYY-MM-DD_HHMMSS.ext)
        let filename = (filePath as NSString).lastPathComponent
        let components = filename.split(separator: "_")
        
        if components.count >= 4 {
            // Extract date and time parts from filename
            // components[0] = unit number (00)
            // components[1] = clip number (0000)
            // components[2] = date (YYYY-MM-DD)
            // components[3] = time (HHMMSS.ext)
            let datePart = String(components[2])  // YYYY-MM-DD
            let timePart = String(components[3].split(separator: ".")[0])  // HHMMSS
            
            // Construct a parseable date string
            let dateTimeString = "\(datePart) \(timePart.prefix(2)):\(timePart.dropFirst(2).prefix(2)):\(timePart.dropFirst(4))"
            
            if let date = DateFormatter.recordedDate.date(from: dateTimeString) {
                return date
            }
        }
        
        // Second, try mediainfo (if available)
        if FileManager.default.fileExists(atPath: config.paths.mediainfoPath) {
            let attributes = ["Recorded_Date", "Encoded_Date"]
            
            for attribute in attributes {
                let result = runShellCommand(
                    config.paths.mediainfoPath,
                    arguments: ["--Inform=General;%\(attribute)%", filePath]
                )
                
                if result.exitCode == 0 && !result.output.isEmpty {
                // Clean up the date string
                let dateString = result.output
                    .replacingOccurrences(of: "UTC ", with: "")
                    .replacingOccurrences(of: " UTC", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Try to parse the date
                if let date = DateFormatter.recordedDate.date(from: dateString) {
                    return date
                }
            }
        }
        }
        
        logger.log("Could not extract date from filename or metadata for \(filePath), using file modification date", level: .warning)
        
        // Fallback to file modification date
        if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
           let modDate = attributes[.modificationDate] as? Date {
            return modDate
        }
        
        return nil
    }
    
    /// Detect video format using mediainfo
    private func detectVideoFormat(filePath: String) -> MediaClip.VideoFormat {
        // If mediainfo is not available, return unknown
        guard FileManager.default.fileExists(atPath: config.paths.mediainfoPath) else {
            return .unknown
        }
        
        let result = runShellCommand(
            config.paths.mediainfoPath,
            arguments: ["--Inform=General;%Format%\\n%CommercialName%", filePath]
        )
        
        guard result.exitCode == 0 else {
            return .unknown
        }
        
        let output = result.output.lowercased()
        
        if output.contains("hdv") {
            return .hdv
        } else if output.contains("dv") {
            return .dv
        } else if output.contains("mpeg") {
            return .mpeg2
        }
        
        return .unknown
    }
    
    /// Generate new filename from date
    private func generateNewFileName(from date: Date, extension ext: String) -> String {
        let dateString = DateFormatter.filename.string(from: date)
        return "\(dateString).\(ext.lowercased())"
    }
    
    /// Display clips to user
    func displayClips(_ clips: [MediaClip], duplicateStatus: [String: DuplicateDetector.DuplicateStatus]) {
        print("\n" + colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print(colorize("  Found Clips", color: ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        
        var multiSegmentClips: [MediaClip] = []
        var singleFileClips: [MediaClip] = []
        
        for clip in clips {
            if clip.isMultiSegment {
                multiSegmentClips.append(clip)
            } else {
                singleFileClips.append(clip)
            }
        }
        
        // Display multi-segment clips first
        if !multiSegmentClips.isEmpty {
            print("\n" + colorize("Multi-segment clips:", color: ConsoleColor.yellow))
            for clip in multiSegmentClips {
                displayClip(clip, status: duplicateStatus[clip.clipID])
            }
        }
        
        // Display single file clips
        if !singleFileClips.isEmpty {
            print("\n" + colorize("Single file clips:", color: ConsoleColor.green))
            for clip in singleFileClips {
                displayClip(clip, status: duplicateStatus[clip.clipID])
            }
        }
        
        print("")
    }
    
    private func displayClip(_ clip: MediaClip, status: DuplicateDetector.DuplicateStatus?) {
        let isDuplicate = status?.isDuplicate ?? false
        let clipColor = isDuplicate ? ConsoleColor.red : ConsoleColor.reset
        
        print(colorize("  Clip \(clip.clipID):", color: clipColor), terminator: "")
        
        if isDuplicate, case .duplicate(let locations) = status {
            print(colorize(" [DUPLICATE in: \(locations.joined(separator: ", "))]", color: ConsoleColor.red))
        } else {
            print(colorize(" [NEW]", color: ConsoleColor.green))
        }
        
        for segment in clip.segments {
            let segmentColor = isDuplicate ? ConsoleColor.red : ConsoleColor.cyan
            print("    " + colorize("→ \(segment.originalFileName)", color: segmentColor))
        }
        
        if let newName = clip.newFileName {
            print("    " + colorize("  Will be saved as: \(newName)", color: ConsoleColor.blue))
        }
    }
    
    /// Parse user selection input (e.g., "1,3,5" or "all")
    func parseSelection(_ input: String, totalClips: Int) -> [Int] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if trimmed.isEmpty || trimmed == "all" {
            return Array(0..<totalClips)
        }
        
        let parts = trimmed.split(separator: ",")
        var indices: [Int] = []
        
        for part in parts {
            if let index = Int(part.trimmingCharacters(in: .whitespaces)), index > 0, index <= totalClips {
                indices.append(index - 1) // Convert to 0-based index
            }
        }
        
        return indices
    }
}

// MARK: - Import Command

struct ImportCommand {
    static func run(with args: [String]) {
        let config = ConfigurationManager.getConfiguration()
        
        // Parse arguments
        var sourcePath = config.paths.defaultSourceVolume
        var destinationPath = FileManager.default.currentDirectoryPath
        
        if args.count >= 1 {
            sourcePath = args[0]
        }
        if args.count >= 2 {
            destinationPath = args[1]
        }
        
        // Run import
        do {
            try performImport(sourcePath: sourcePath, destinationPath: destinationPath)
        } catch {
            print(colorize("[ERROR] Import failed: \(error)", color: ConsoleColor.red))
            exit(1)
        }
    }
    
    static func performImport(sourcePath: String, destinationPath: String, interactive: Bool = true) throws {
        let importModule = ImportModule(destinationPath: destinationPath)
        
        // Scan memory card
        guard let clips = importModule.scanMemoryCard(sourcePath: sourcePath) else {
            throw ImportError.scanFailed
        }
        
        if clips.isEmpty {
            importModule.logger.log("No clips found on memory card", level: .warning)
            return
        }
        
        // Create FCP directory structure
        let fcpStructure = FCPDirectoryStructure(rootPath: destinationPath)
        try fcpStructure.createDirectories()
        
        // Check for duplicates
        let duplicateDetector = DuplicateDetector(destinationStructure: fcpStructure)
        let duplicateStatus = duplicateDetector.checkForDuplicates(clips: clips)
        
        // Display clips
        importModule.displayClips(clips, duplicateStatus: duplicateStatus)
        
        // Get user selection
        var selectedIndices: [Int]
        if interactive {
            print(colorize("Press Enter to import all NEW clips, or enter clip numbers (e.g., 1,3,5):", color: ConsoleColor.yellow))
            let input = readLine() ?? ""
            selectedIndices = importModule.parseSelection(input, totalClips: clips.count)
        } else {
            // Non-interactive: import only new clips
            selectedIndices = clips.enumerated().compactMap { index, clip in
                if duplicateStatus[clip.clipID]?.isDuplicate == false {
                    return index
                }
                return nil
            }
        }
        
        if selectedIndices.isEmpty {
            importModule.logger.log("No clips selected for import", level: .info)
            return
        }
        
        // Import selected clips
        let selectedClips = selectedIndices.map { clips[$0] }
        let fileOps = FileOperations(logger: importModule.logger)
        try fileOps.importClips(selectedClips, to: fcpStructure, from: sourcePath)
    }
    
    enum ImportError: Error {
        case scanFailed
        case invalidPath
    }
}
