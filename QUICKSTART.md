# MRC1BCP Quick Start Guide

## 5-Minute Setup

### 1. Install Dependencies

```bash
brew install ffmpeg mediainfo
```

### 2. Build the Application

```bash
cd /Volumes/alpha/Projects/Developpement/mrc1bcp
./build.sh
```

### 3. (Optional) Install Globally

```bash
sudo cp build/mrc1bcp /usr/local/bin/
```

## First Import

### Step 1: Connect Your Sony HVR-MRC1 Memory Card

Plug in your Sony HVR-MRC1 memory card. It should mount as `/Volumes/VIDEO`.

### Step 2: Create a Destination Folder

```bash
mkdir ~/Desktop/my_vintage_footage
cd ~/Desktop/my_vintage_footage
```

### Step 3: Run mrc1bcp

```bash
mrc1bcp
```

Or if not installed globally:

```bash
/Volumes/alpha/Projects/Developpement/mrc1bcp/build/mrc1bcp
```

### Step 4: Follow the Prompts

The app will guide you through:

1. **Import**: Verify the source (memory card) and destination
2. **Convert**: Choose to remux files (recommended for FCP)
3. **Archive**: Create a .fcarch file for Final Cut Pro

### Step 5: Import into Final Cut Pro

1. Open Final Cut Pro
2. File → Import → Files/Media
3. Navigate to your destination folder
4. Select the `.fcarch` archive
5. Done! Your vintage footage is ready to edit

## Common Workflows

### Just Import (No Conversion)

```bash
mrc1bcp import /Volumes/VIDEO ~/Desktop/my_footage
```

This copies files to `~/Desktop/my_footage/Original Media/` with proper naming.

### Import + Convert

```bash
cd ~/Desktop/my_footage
mrc1bcp import /Volumes/VIDEO .
mrc1bcp optimize .
```

### Full Workflow (Import + Convert + Archive)

Run in interactive mode and follow all steps:

```bash
cd ~/Desktop/my_footage
mrc1bcp
```

### Rename Existing Files Based on Metadata

If you have files that need to be renamed:

```bash
cd /path/to/files
mrc1bcp rename mov  # or dv, avi, m2t, etc.
```

### Update File Creation Dates from Filenames

If filenames contain dates but file timestamps are wrong:

```bash
cd /path/to/files
mrc1bcp touchit
```

## Understanding the Output

After import, you'll have:

```
your_project/
├── Original Media/          # Your imported clips (renamed)
├── Optimized Media/         # Remuxed files (if you converted)
├── Transcoded Media/        # HEVC proxies (if you transcoded)
├── import_metadata.json     # Import tracking
├── conversion_report.json   # Conversion results (if converted)
└── mrc1bcp.log             # Detailed log
```

After creating FCP archive:

```
your_project.fcarch/         # Ready for Final Cut Pro!
├── FCArchMetadata.plist    # Archive metadata
├── Original Media/         # Original files
├── Optimized Media/        # Converted files
└── Transcoded Media/       # Proxies (if any)
```

## Tips

### Duplicate Detection

mrc1bcp automatically detects if clips have already been imported. Clips are marked as:
- **[NEW]** - Not yet imported
- **[DUPLICATE]** - Already exists in destination

### Segmented Clips

Multi-segment clips (when recording spans multiple files) are automatically detected and merged during import.

### Selective Import

When prompted, you can:
- Press **Enter** to import all NEW clips
- Type **1,3,5** to import only clips 1, 3, and 5
- Type **all** to import everything (including duplicates)

### Configuration

Edit `~/.config/mrc1bcp/config.json` to customize:
- HEVC encoding parameters for DV vs HDV
- Default source volume path
- ffmpeg and mediainfo paths

## Troubleshooting

### "mediainfo not found" or "ffmpeg not found"

Install them:
```bash
brew install ffmpeg mediainfo
```

### "HVR directory not found"

Make sure your memory card is properly mounted. Check:
```bash
ls /Volumes/
```

### Permissions Errors

Ensure you have write access to the destination folder:
```bash
chmod -R u+w /path/to/destination
```

### Import Worked But FCP Won't Read Files

Try optimizing the files:
```bash
cd /path/to/your/project
mrc1bcp optimize .
```

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Check the logs in `mrc1bcp.log` if something goes wrong
- Review `import_metadata.json` to see what was imported

---

**Happy archiving!**
