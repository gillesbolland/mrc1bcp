# MRC1BCP - Vintage Camcorder Processing Tool

**"Mrc1 beaucoup!"** - A comprehensive Swift CLI application for processing vintage camcorder footage from Sony HVR-MRC1 memory recording units.

## Purpose

Designed to streamline the workflow of importing, optimizing, and archiving DV/HDV footage from Sony HVR-MRC1 for use in Final Cut Pro.

## Features

- **Smart Import**: Automatically detects and merges segmented clips from Sony HVR-MRC1
- **Duplicate Detection**: Checks existing files to avoid re-importing
- **Optimization**: Optimize media to Final Cut Pro compatible MOV
- **HEVC Transcoding**: Optional proxy creation with configurable parameters
- **FCP Archive Creation**: Generates proper `.fcarch` camera archives
- **Metadata Preservation**: Maintains recording dates and timestamps
- **Interactive Workflow**: Step-by-step guidance through the entire process
- **Modular Design**: Each function available as standalone command

## Requirements

- **macOS** (tested on macOS 10.15+)
- **Swift** 5.0 or later
- **ffmpeg** - `brew install ffmpeg`
- **mediainfo** - `brew install mediainfo`

## Installation

### Build from Source

```bash
cd /Volumes/alpha/Projects/Developpement/mrc1bcp
./build.sh
```

### Install Globally

```bash
sudo cp build/mrc1bcp /usr/local/bin/
```

## Usage

### Interactive Mode (Recommended for First-Time Users)

Simply run the command without arguments for a guided step-by-step workflow:

```bash
mrc1bcp
```

The interactive mode will guide you through:
1. **Import** - Copy and merge clips from memory card
2. **Convert** - Remux to Final Cut Pro format
3. **Archive** - Create FCP camera archive

### Command-Line Mode

For advanced users or automation, use specific subcommands:

```bash
# Import clips from memory card
mrc1bcp import /Volumes/VIDEO /path/to/destination

# Convert/remux files
mrc1bcp optimize /path/to/destination

# Create HEVC proxies
mrc1bcp transcode /path/to/destination

# Create FCP archive
mrc1bcp archive /path/to/destination

# Rename files based on metadata
mrc1bcp rename mov

# Update file dates from filename patterns
mrc1bcp touchit m2t
```

## Configuration

The configuration file is stored at `~/.config/mrc1bcp/config.json`.

Fields:
- `hevcTranscoding`:
  - `enabled` (bool): default false
  - `dvBitrate` (string): bitrate for DV when transcoding proxies (e.g., "13M")
  - `hdvBitrate` (string): bitrate for HDV when transcoding proxies (e.g., "26M")
  - `dvParameters`/`hdvParameters` (array): extra ffmpeg arguments (optional)
- `paths`:
  - `ffmpegPath` (string): path to ffmpeg
  - `mediainfoPath` (string): path to mediainfo (optional)
  - `defaultSourceVolume` (string): default source volume
- `preferences`:
  - `autoEjectAfterImport` (bool)
  - `createBackupBeforeConversion` (bool)
  - `verboseLogging` (bool)
  - `rememberLastPaths` (bool): remember last source/destination used
  - `lastSourcePath` (string|null): last used source path
  - `lastDestinationPath` (string|null): last used destination path
  - `lastRun` (object|null): autopilot options remembered from last interactive run
    - `optimize` (bool)
    - `createProxies` (bool)
    - `createArchive` (bool)
    - `ejectAfterImport` (bool)

You can enable `rememberLastPaths` to have the app suggest the last used source and destination.

Settings are stored in `~/.config/mrc1bcp/config.json`

Example configuration:

```json
{
  "hevcTranscoding": {
    "enabled": false,
    "dvBitrate": "13M",
    "hdvBitrate": "26M",
    "dvParameters": ["-c:v", "hevc_videotoolbox", ...],
    "hdvParameters": ["-c:v", "hevc_videotoolbox", ...]
  },
  "paths": {
    "ffmpegPath": "/opt/homebrew/bin/ffmpeg",
    "mediainfoPath": "/opt/homebrew/bin/mediainfo",
    "defaultSourceVolume": "/Volumes/VIDEO"
  },
  "preferences": {
    "autoEjectAfterImport": false,
    "verboseLogging": true
  }
}
```

## Project Structure

```
mrc1bcp/
├── Sources/
│   ├── main.swift                  # Entry point and CLI routing
│   ├── Utils.swift                 # Utilities and helpers
│   ├── Configuration.swift         # Configuration management
│   ├── Models.swift                # Data models
│   ├── FileOperations.swift        # File copying and merging
│   ├── ImportModule.swift          # Import functionality
│   ├── ConversionModule.swift      # Remux and transcode
│   ├── ArchiveModule.swift         # FCP archive creation
│   ├── TimestampUtilities.swift    # Timestamp tools
│   └── InteractiveWorkflow.swift   # Interactive mode
├── build.sh                        # Build script
└── README.md                       # This file
```

## Workflow Example

### Typical Use Case:

1. **Connect Sony HVR-MRC1** memory card to your Mac
2. **Run mrc1bcp** in interactive mode
3. **Select clips** to import (or import all new clips)
4. **Remux** files for Final Cut Pro compatibility
5. **Create archive** with proper metadata
6. **Import** the `.fcarch` into Final Cut Pro

### Directory Structure Created:

```
YourProject.fcarch/
├── FCArchMetadata.plist
├── Original Media/
│   ├── 2024-12-26_010005.avi
│   └── 2024-12-26_010114.m2t
├── Optimized Media/
│   ├── 2024-12-26_010005.mov
│   └── 2024-12-26_010114.mov
└── Transcoded Media/
    └── (optional HEVC proxies)
```

## Logging

Logs are automatically created in the destination folder:
- `mrc1bcp.log` - Detailed operation log
- `import_metadata.json` - Import tracking
- `conversion_report.json` - Conversion results

## Troubleshooting

### Dependencies Not Found

If you see errors about missing ffmpeg or mediainfo:

```bash
brew install ffmpeg mediainfo
```

### Memory Card Not Detected

Ensure the Sony HVR-MRC1 card is properly mounted at `/Volumes/VIDEO`. You can check with:

```bash
ls -la /Volumes/
```

### Permission Issues

If you encounter permission errors when creating directories:

```bash
chmod -R u+w /path/to/destination
```

## Future Enhancements

- GUI application for even easier use
- Batch processing of multiple memory cards
- Custom naming templates
- Audio-only import options
- Integration with other NLE software

## Target Audience

- Vintage camcorder enthusiasts
- Video archivists
- Filmmakers working with legacy DV/HDV equipment
- Professional editors managing archival footage

## License

This project is provided as-is for personal and professional use.

## Acknowledgments

Built with love for the vintage video community.

---

**"Mrc1 beaucoup!"** - Because your vintage footage deserves modern workflows.
