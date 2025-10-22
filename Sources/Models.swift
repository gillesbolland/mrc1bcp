import Foundation

// MARK: - Media Clip Model

struct MediaClip {
    let clipID: String
    var segments: [Segment]
    var isMultiSegment: Bool { segments.count > 1 }
    var firstSegment: Segment { segments.first! }
    var recordingDate: Date?
    var newFileName: String?
    var format: VideoFormat
    
    struct Segment {
        let originalFileName: String
        let filePath: String
        let timestamp: String
        let fileExtension: String
        
        var isVideo: Bool {
            let ext = fileExtension.lowercased()
            return ["m2t", "dv", "avi", "mov", "mp4"].contains(ext)
        }
    }
    
    enum VideoFormat: String {
        case dv = "DV"
        case hdv = "HDV"
        case mpeg2 = "MPEG-2"
        case unknown = "Unknown"
        
        var isHDV: Bool {
            return self == .hdv
        }
    }
}

// MARK: - Import Metadata

struct ImportMetadata: Codable {
    var importDate: Date
    var sourceVolume: String
    var destinationPath: String
    var clips: [ClipMetadata]
    
    struct ClipMetadata: Codable {
        let clipID: String
        let originalFileNames: [String]
        let newFileName: String
        let recordingTime: String
        let format: String
        let wasSegmented: Bool
        let fileSize: Int64
    }
    
    func save(to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(self)
        try data.write(to: URL(fileURLWithPath: path))
    }
    
    static func load(from path: String) -> ImportMetadata? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ImportMetadata.self, from: data)
    }
}

// MARK: - Conversion Report

struct ConversionReport: Codable {
    var conversionDate: Date
    var sourcePath: String
    var conversions: [ConversionRecord]
    
    struct ConversionRecord: Codable {
        let sourceFileName: String
        let outputFileName: String
        let conversionType: String // "remux" or "transcode"
        let success: Bool
        let duration: TimeInterval
        let errorMessage: String?
    }
    
    func save(to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(self)
        try data.write(to: URL(fileURLWithPath: path))
    }
}

// MARK: - FCP Directory Structure

struct FCPDirectoryStructure {
    let rootPath: String
    let originalMedia: String
    let optimizedMedia: String
    let transcodedMedia: String
    
    init(rootPath: String) {
        self.rootPath = rootPath
        self.originalMedia = "\(rootPath)/Original Media"
        self.optimizedMedia = "\(rootPath)/Optimized Media"
        self.transcodedMedia = "\(rootPath)/Transcoded Media"
    }
    
    func createDirectories() throws {
        try FileManager.default.ensureDirectoryExists(atPath: originalMedia)
        try FileManager.default.ensureDirectoryExists(atPath: optimizedMedia)
        try FileManager.default.ensureDirectoryExists(atPath: transcodedMedia)
    }
    
    func validate() -> Bool {
        let fm = FileManager.default
        return fm.directoryExists(atPath: rootPath)
    }
}

// MARK: - Duplicate Detection

struct DuplicateDetector {
    let destinationStructure: FCPDirectoryStructure
    
    func checkForDuplicates(clips: [MediaClip]) -> [String: DuplicateStatus] {
        var results: [String: DuplicateStatus] = [:]
        let fm = FileManager.default
        
        for clip in clips {
            guard let newFileName = clip.newFileName else { continue }
            
            var locations: [String] = []
            
            // Check Original Media
            let originalPath = "\(destinationStructure.originalMedia)/\(newFileName)"
            if fm.fileExists(atPath: originalPath) {
                locations.append("Original Media")
            }
            
            // Check Optimized Media
            let optimizedPath = "\(destinationStructure.optimizedMedia)/\(newFileName)"
            if fm.fileExists(atPath: optimizedPath) {
                locations.append("Optimized Media")
            }
            
            // Check Transcoded Media
            let transcodedPath = "\(destinationStructure.transcodedMedia)/\(newFileName)"
            if fm.fileExists(atPath: transcodedPath) {
                locations.append("Transcoded Media")
            }
            
            if !locations.isEmpty {
                results[clip.clipID] = .duplicate(locations: locations)
            } else {
                results[clip.clipID] = .new
            }
        }
        
        return results
    }
    
    enum DuplicateStatus {
        case new
        case duplicate(locations: [String])
        
        var isDuplicate: Bool {
            if case .duplicate = self {
                return true
            }
            return false
        }
    }
}
