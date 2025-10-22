import Foundation

// MARK: - Conversion Module

class ConversionModule {
    let config: Configuration
    let logger: Logger
    let structure: FCPDirectoryStructure
    
    init(destinationPath: String) {
        self.config = ConfigurationManager.getConfiguration()
        self.logger = Logger(destinationPath: destinationPath)
        self.structure = FCPDirectoryStructure(rootPath: destinationPath)
    }
    
    /// Remux files to ProRes/MOV format
    func remuxFiles(sourceDir: String? = nil) throws {
        let sourceDirectory = sourceDir ?? structure.originalMedia
        
        guard FileManager.default.directoryExists(atPath: sourceDirectory) else {
            throw ConversionError.sourceDirectoryNotFound(sourceDirectory)
        }
        
        // Get list of files to convert
        let files = try FileManager.default.contentsOfDirectory(atPath: sourceDirectory)
        let mediaFiles = files.filter { file in
            let ext = (file as NSString).pathExtension.lowercased()
            return ["m2t", "dv", "avi", "mov", "mp4"].contains(ext)
        }
        
        if mediaFiles.isEmpty {
            logger.log("No media files found to remux", level: .warning)
            return
        }
        
        print("\n" + colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print(colorize("  Optimizing for Final Cut Pro (MOV)", color: ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print(colorize("  Found \(mediaFiles.count) file(s) to process", color: ConsoleColor.cyan))
        print("")
        
        var conversions: [ConversionReport.ConversionRecord] = []
        
        for (index, file) in mediaFiles.enumerated() {
            let sourcePath = "\(sourceDirectory)/\(file)"
            let outputFileName = ((file as NSString).deletingPathExtension as NSString).appendingPathExtension("mov")!
            let outputPath = "\(structure.optimizedMedia)/\(outputFileName)"
            
            print(colorize("[\(index + 1)/\(mediaFiles.count)] Optimizing \(file)...", color: ConsoleColor.cyan))
            
            // Check for duplicate
            if FileManager.default.fileExists(atPath: outputPath) {
                logger.log("File already exists: \(outputFileName), skipping", level: .warning)
                print(colorize("  [WARNING] Already exists, skipping", color: ConsoleColor.yellow))
                print("")
                continue
            }
            
            let startTime = Date()
            let success = remuxFile(sourcePath: sourcePath, outputPath: outputPath)
            let duration = Date().timeIntervalSince(startTime)
            
            let record = ConversionReport.ConversionRecord(
                sourceFileName: file,
                outputFileName: outputFileName,
                conversionType: "optimize",
                success: success,
                duration: duration,
                errorMessage: success ? nil : "Optimization failed"
            )
            conversions.append(record)
            
            if success {
                print(colorize("  [OK] Success (\(String(format: "%.1f", duration))s)", color: ConsoleColor.green))
            } else {
                print(colorize("  [FAILED]", color: ConsoleColor.red))
            }
            print("")
        }
        
        // Save conversion report
        let report = ConversionReport(
            conversionDate: Date(),
            sourcePath: sourceDirectory,
            conversions: conversions
        )
        
        let reportPath = "\(structure.rootPath)/conversion_report.json"
        try report.save(to: reportPath)
        logger.log("Saved conversion report to \(reportPath)", level: .success)
        
        // Summary
        let successCount = conversions.filter { $0.success }.count
        let failCount = conversions.count - successCount
        
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print(colorize("  Conversion Summary", color: ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print(colorize("  Successful: \(successCount)", color: ConsoleColor.green))
        if failCount > 0 {
            print(colorize("  Failed: \(failCount)", color: ConsoleColor.red))
        }
        print("")
    }
    
    /// Optimize (remux) a single file using ffmpeg
    private func remuxFile(sourcePath: String, outputPath: String) -> Bool {
        // Extract metadata date
        let metadataDate = extractCreationDate(from: sourcePath)
        
        // Build ffmpeg command
        var args = [
            "-copy_unknown",
            "-hide_banner",
            "-loglevel", "error",
            "-y",
            "-i", sourcePath,
            "-r", "25",
            "-c", "copy",
            "-map", "0",
            "-movflags", "+faststart"
        ]
        
        if let date = metadataDate {
            args += ["-metadata", "creation_time=\(date)"]
        }
        
        args.append(outputPath)
        
        let result = runShellCommand(config.paths.ffmpegPath, arguments: args)
        
        if result.exitCode == 0 {
            // Update file timestamp
            if let date = metadataDate, let parsedDate = parseCreationDate(date) {
                updateFileTimestamp(path: outputPath, date: parsedDate)
            }
            logger.log("Optimized to \(outputPath)", level: .success)
            return true
        } else {
            logger.log("Failed to optimize \(sourcePath): \(result.output)", level: .error)
            return false
        }
    }
    
    /// Transcode files to HEVC
    func transcodeFiles(sourceDir: String? = nil) throws {
        let sourceDirectory = sourceDir ?? structure.originalMedia
        
        guard FileManager.default.directoryExists(atPath: sourceDirectory) else {
            throw ConversionError.sourceDirectoryNotFound(sourceDirectory)
        }
        
        let files = try FileManager.default.contentsOfDirectory(atPath: sourceDirectory)
        let mediaFiles = files.filter { file in
            let ext = (file as NSString).pathExtension.lowercased()
            return ["m2t", "dv", "avi", "mov", "mp4"].contains(ext)
        }
        
        if mediaFiles.isEmpty {
            logger.log("No media files found to transcode", level: .warning)
            return
        }
        
        print("\n" + colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print(colorize("  Transcoding to HEVC", color: ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print(colorize("  Found \(mediaFiles.count) file(s) to process", color: ConsoleColor.cyan))
        print("")
        
        for (index, file) in mediaFiles.enumerated() {
            let sourcePath = "\(sourceDirectory)/\(file)"
            let outputFileName = ((file as NSString).deletingPathExtension as NSString).appendingPathExtension("mov")!
            let outputPath = "\(structure.transcodedMedia)/\(outputFileName)"
            
            print(colorize("[\(index + 1)/\(mediaFiles.count)] Transcoding \(file)...", color: ConsoleColor.cyan))
            
            if FileManager.default.fileExists(atPath: outputPath) {
                print(colorize("  [WARNING] Already exists, skipping", color: ConsoleColor.yellow))
                print("")
                continue
            }
            
            // Detect format
            let format = detectVideoFormat(filePath: sourcePath)
            
            let startTime = Date()
            let success = transcodeFile(sourcePath: sourcePath, outputPath: outputPath, format: format)
            let duration = Date().timeIntervalSince(startTime)
            
            if success {
                print(colorize("  [OK] Success (\(String(format: "%.1f", duration))s)", color: ConsoleColor.green))
            } else {
                print(colorize("  [FAILED]", color: ConsoleColor.red))
            }
            print("")
        }
    }
    
    /// Transcode a single file to HEVC
    private func transcodeFile(sourcePath: String, outputPath: String, format: MediaClip.VideoFormat) -> Bool {
        let metadataDate = extractCreationDate(from: sourcePath)
        
        // Determine bitrate and scan type
        let bitrate = format.isHDV ? config.hevcTranscoding.hdvBitrate : config.hevcTranscoding.dvBitrate
        let scanInfo = detectScanType(filePath: sourcePath)
        
        // Build ffmpeg command
        var args = [
            "-hide_banner",
            "-loglevel", "error",
            "-y",
            "-i", sourcePath
        ]
        
        // Add deinterlacing if needed
        if scanInfo.isInterlaced {
            let parity = scanInfo.order.lowercased()
            args += ["-vf", "bwdif=mode=send_field:parity=\(parity)"]
        }
        
        // Add encoding parameters
        args += [
            "-c:v", "hevc_videotoolbox",
            "-b:v", bitrate,
            "-tag:v", "hvc1",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-b:a", "256k",
            "-ar", "48000",
            "-ac", "2",
            "-movflags", "+faststart",
            "-write_tmcd", "0"
        ]
        
        if let date = metadataDate {
            args += ["-metadata", "creation_time=\(date)"]
        }
        
        args.append(outputPath)
        
        let result = runShellCommand(config.paths.ffmpegPath, arguments: args)
        
        if result.exitCode == 0 {
            if let date = metadataDate, let parsedDate = parseCreationDate(date) {
                updateFileTimestamp(path: outputPath, date: parsedDate)
            }
            logger.log("Successfully transcoded to \(outputPath)", level: .success)
            return true
        } else {
            logger.log("Failed to transcode \(sourcePath): \(result.output)", level: .error)
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractCreationDate(from filePath: String) -> String? {
        // First, try to extract from filename
        // Two possible formats:
        // 1. Sony format: 00_0000_YYYY-MM-DD_HHMMSS.ext
        // 2. Renamed format: YYYY-MM-DD_HHMMSS.ext
        let filename = (filePath as NSString).lastPathComponent
        let components = filename.split(separator: "_")
        
        var datePart: String?
        var timePart: String?
        
        if components.count >= 4 {
            // Sony format: 00_0000_YYYY-MM-DD_HHMMSS.ext
            datePart = String(components[2])
            timePart = String(components[3].split(separator: ".")[0])
        } else if components.count >= 2 {
            // Renamed format: YYYY-MM-DD_HHMMSS.ext
            datePart = String(components[0])
            timePart = String(components[1].split(separator: ".")[0])
        }
        
        if let date = datePart, let time = timePart, date.count == 10, time.count == 6 {
            // Format as ISO8601
            let isoDate = "\(date)T\(time.prefix(2)):\(time.dropFirst(2).prefix(2)):\(time.dropFirst(4))Z"
            return isoDate
        }
        
        // Second, try mediainfo (if available)
        if FileManager.default.fileExists(atPath: config.paths.mediainfoPath) {
            let result = runShellCommand(
                config.paths.mediainfoPath,
                arguments: ["--Inform=General;%Recorded_Date%", filePath]
            )
            
            if result.exitCode == 0 && !result.output.isEmpty {
            var dateString = result.output
                .replacingOccurrences(of: "UTC ", with: "")
                .replacingOccurrences(of: " UTC", with: "")
                .replacingOccurrences(of: " ", with: "T")
            
            if !dateString.hasSuffix("Z") {
                dateString += "Z"
            }
            
                return dateString
            }
        }
        
        return nil
    }
    
    private func parseCreationDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    private func updateFileTimestamp(path: String, date: Date) {
        let touchDateString = DateFormatter.touchCommand.string(from: date)
        let _ = runShellCommand("/usr/bin/touch", arguments: ["-t", touchDateString, path])
    }
    
    private func detectVideoFormat(filePath: String) -> MediaClip.VideoFormat {
        // If mediainfo is not available, return unknown
        guard FileManager.default.fileExists(atPath: config.paths.mediainfoPath) else {
            return .unknown
        }
        
        let result = runShellCommand(
            config.paths.mediainfoPath,
            arguments: ["--Inform=General;%Format%\\n%CommercialName%", filePath]
        )
        
        let output = result.output.lowercased()
        
        if output.contains("hdv") {
            return .hdv
        } else if output.contains("dv") {
            return .dv
        }
        
        return .unknown
    }
    
    private func detectScanType(filePath: String) -> (isInterlaced: Bool, order: String) {
        // If mediainfo is not available, assume progressive
        guard FileManager.default.fileExists(atPath: config.paths.mediainfoPath) else {
            return (false, "tff")
        }
        
        let result = runShellCommand(
            config.paths.mediainfoPath,
            arguments: ["--Inform=Video;%ScanType%\\n%ScanOrder%", filePath]
        )
        
        let lines = result.output.components(separatedBy: "\n")
        let scanType = lines.first ?? ""
        let scanOrder = lines.count > 1 ? lines[1] : "tff"
        
        return (scanType.lowercased() == "interlaced", scanOrder.isEmpty ? "tff" : scanOrder)
    }
    
    enum ConversionError: Error {
        case sourceDirectoryNotFound(String)
        case ffmpegNotFound
    }
}

// MARK: - Convert Command

struct ConvertCommand {
    static func run(with args: [String]) {
        let destinationPath = args.first ?? FileManager.default.currentDirectoryPath
        
        do {
            let module = ConversionModule(destinationPath: destinationPath)
            try module.remuxFiles()
        } catch {
            print(colorize("[ERROR] Conversion failed: \(error)", color: ConsoleColor.red))
            exit(1)
        }
    }
}

// MARK: - Transcode Command

struct TranscodeCommand {
    static func run(with args: [String]) {
        let destinationPath = args.first ?? FileManager.default.currentDirectoryPath
        
        do {
            let module = ConversionModule(destinationPath: destinationPath)
            try module.transcodeFiles()
        } catch {
            print(colorize("[ERROR] Transcoding failed: \(error)", color: ConsoleColor.red))
            exit(1)
        }
    }
}
