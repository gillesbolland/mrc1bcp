import Foundation

// MARK: - Timestamp Command

struct TimestampCommand {
    static func run(with args: [String]) {
        let fileExtension = args.first ?? "mov"
        let currentPath = FileManager.default.currentDirectoryPath
        
print(colorize("Rename files based on metadata dates", color: ConsoleColor.cyan + ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print("")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: currentPath)
            let targetFiles = files.filter { $0.lowercased().hasSuffix(".\(fileExtension.lowercased())") }
            
            if targetFiles.isEmpty {
                print(colorize("No .\(fileExtension) files found in current directory", color: ConsoleColor.yellow))
                return
            }
            
            var fileInfo: [(original: String, date: String, newName: String, touchDate: String)] = []
            
            let config = ConfigurationManager.getConfiguration()
            
            for file in targetFiles {
                let filePath = "\(currentPath)/\(file)"
                
                // Extract date from mediainfo
                let result = runShellCommand(
                    config.paths.mediainfoPath,
                    arguments: ["--Inform=General;%Recorded_Date%\\n%Encoded_Date%", filePath]
                )
                
                var dateString: String? = nil
                
                if result.exitCode == 0 {
                    let lines = result.output.components(separatedBy: "\n")
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            dateString = trimmed
                                .replacingOccurrences(of: "UTC ", with: "")
                                .replacingOccurrences(of: " UTC", with: "")
                            break
                        }
                    }
                }
                
                if let dateStr = dateString, let date = DateFormatter.recordedDate.date(from: dateStr) {
                    let newName = DateFormatter.filename.string(from: date)
                    let touchDate = DateFormatter.touchCommand.string(from: date)
                    let newFileName = "\(newName).\(fileExtension.lowercased())"
                    
                    fileInfo.append((file, dateStr, newFileName, touchDate))
                } else {
                    print(colorize("[WARNING] Could not extract date from: \(file)", color: ConsoleColor.yellow))
                }
            }
            
            if fileInfo.isEmpty {
                print(colorize("No valid dates found in files", color: ConsoleColor.red))
                return
            }
            
            // Display table
            print(colorize("Files to be renamed:", color: ConsoleColor.cyan))
            print("Original Name                | Recorded Date         | New Name")
            print("-----------------------------|-----------------------|-------------------------")
            
            for info in fileInfo {
                let original = info.original.padding(toLength: 28, withPad: " ", startingAt: 0)
                let date = info.date.padding(toLength: 21, withPad: " ", startingAt: 0)
                print("\(original) | \(date) | \(info.newName)")
            }
            
            print("")
            if !promptYesNo("Proceed with renaming and updating file dates?", defaultYes: true) {
                print(colorize("Operation cancelled", color: ConsoleColor.yellow))
                return
            }
            
            // Perform renaming
            for info in fileInfo {
                let oldPath = "\(currentPath)/\(info.original)"
                let newPath = "\(currentPath)/\(info.newName)"
                
                do {
                    try FileManager.default.moveItem(atPath: oldPath, toPath: newPath)
                    let _ = runShellCommand("/usr/bin/touch", arguments: ["-t", info.touchDate, newPath])
                    print(colorize("[OK] \(info.original) -> \(info.newName)", color: ConsoleColor.green))
                } catch {
                    print(colorize("[ERROR] Failed to rename \(info.original): \(error)", color: ConsoleColor.red))
                }
            }
            
            print("")
            print(colorize("Operation completed", color: ConsoleColor.green))
            
        } catch {
            print(colorize("[ERROR] \(error)", color: ConsoleColor.red))
        }
    }
}

// MARK: - Touchit Command

struct TouchitCommand {
    static func run(with args: [String]) {
        print(colorize("Touchit - Update file dates from filename patterns", color: ConsoleColor.cyan + ConsoleColor.bold))
        print(colorize("═══════════════════════════════════════════════════════", color: ConsoleColor.blue))
        print("")
        
        let currentPath = FileManager.default.currentDirectoryPath
        
        // Determine file extension
        var fileExtension = ""
        
        if let extArg = args.first(where: { $0.hasPrefix("-e") }) {
            fileExtension = String(extArg.dropFirst(2))
        } else if args.count > 0 && !args[0].hasPrefix("-") {
            fileExtension = args[0]
        } else {
            // List available file types
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: currentPath)
                let types = Set(files.map { (($0 as NSString).pathExtension) }.filter { !$0.isEmpty })
                
                if !types.isEmpty {
                    print(colorize("File types found in current directory:", color: ConsoleColor.cyan))
                    for type in types.sorted() {
                        print("  .\(type)")
                    }
                    print("")
                }
            } catch {}
            
            fileExtension = promptUser("Enter file extension (e.g., mov, m2t):", defaultValue: "mov")
        }
        
        fileExtension = fileExtension.replacingOccurrences(of: ".", with: "")
        
        // Get list of files
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: currentPath)
            let targetFiles = files.filter { $0.lowercased().hasSuffix(".\(fileExtension.lowercased())") }
            
            if targetFiles.isEmpty {
                print(colorize("No .\(fileExtension) files found", color: ConsoleColor.yellow))
                return
            }
            
            print(colorize("\nDetected files with extension .\(fileExtension):", color: ConsoleColor.cyan))
            for file in targetFiles {
                print("  \(file)")
            }
            
            // Get pattern
            let pattern = promptUser("\nEnter date pattern (e.g., 'YYYY-MM-DD_hhmmss'):", defaultValue: "YYYY-MM-DD_hhmmss")
            
            // Extract dates
            var extractedDates: [(String, Date?)] = []
            
            for file in targetFiles {
                if let date = extractDateFromFilename(file, pattern: pattern) {
                    extractedDates.append((file, date))
                    let dateStr = DateFormatter.recordedDate.string(from: date)
                    print("File: \(file), Date: \(dateStr)")
                } else {
                    print("File: \(file), Date: N/A")
                    extractedDates.append((file, nil))
                }
            }
            
            print("")
            if !promptYesNo("Proceed with updating creation dates?", defaultYes: true) {
                print(colorize("Operation cancelled", color: ConsoleColor.yellow))
                return
            }
            
            // Update dates
            for (file, date) in extractedDates {
                if let date = date {
                    let filePath = "\(currentPath)/\(file)"
                    let touchDateString = DateFormatter.touchCommand.string(from: date)
                    let _ = runShellCommand("/usr/bin/touch", arguments: ["-t", touchDateString, filePath])
                    print(colorize("[OK] Updated: \(file)", color: ConsoleColor.green))
                }
            }
            
            print("")
            print(colorize("Operation completed", color: ConsoleColor.green))
            
        } catch {
            print(colorize("[ERROR] \(error)", color: ConsoleColor.red))
        }
    }
    
    private static func extractDateFromFilename(_ filename: String, pattern: String) -> Date? {
        // Convert pattern placeholders to DateFormatter format
        var dateFormat = pattern
        let replacements = [
            "YYYY": "yyyy",
            "MM": "MM",
            "DD": "dd",
            "hh": "HH",
            "mm": "mm",
            "ss": "ss"
        ]
        
        for (key, value) in replacements {
            dateFormat = dateFormat.replacingOccurrences(of: key, with: value)
        }
        
        // Handle literal characters
        dateFormat = dateFormat.replacingOccurrences(of: "_", with: "'_'")
        dateFormat = dateFormat.replacingOccurrences(of: "-", with: "'-'")
        
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Remove extension
        let filenameWithoutExt = (filename as NSString).deletingPathExtension
        
        return formatter.date(from: filenameWithoutExt)
    }
}
