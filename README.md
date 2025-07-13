# ytdl-plus

A unified video downloader script that combines download, streaming, and play-while-downloading capabilities using yt-dlp.

## Features

- **Multiple Operation Modes:**
  - **Download Only** (default): Standard video download
  - **Play While Downloading** (`--play`): Stream video to a player while simultaneously saving to disk
  - **Stream Only** (`--stream`): Stream video directly without saving
  - **Record** (`--record`): Use mpv's built-in stream recording feature

- **Flexible Format Selection:** Interactive format selection or specify custom yt-dlp format codes
- **Resume Support:** Continue interrupted downloads (except in play mode)
- **Customizable Output:** Choose container format and filename
- **Multiple Player Support:** Works with mpv, vlc, and other media players
- **Robust Error Handling:** Proper cleanup of background processes and signal handling
- **Colored Output:** Clear, colored console messages for better user experience

## Requirements

### Essential Dependencies
- **yt-dlp**: Required for downloading videos
- **bash**: The script is written in bash

### Optional Dependencies (mode-dependent)
- **mpv** (default player): Required for `--play`, `--stream`, and `--record` modes
- **vlc** or other media players: Can be specified with `--player` option
- **tee**: Used internally for play-while-downloading (usually pre-installed on Unix systems)

### Installation of Dependencies

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install yt-dlp mpv
```

#### macOS (with Homebrew)
```bash
brew install yt-dlp mpv
```

#### Arch Linux
```bash
sudo pacman -S yt-dlp mpv
```

## Usage

```bash
./ytdl-plus.sh [OPTIONS] <video_url>
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-c, --container FORMAT` | Container format (mkv, mp4, etc.) [default: mkv] |
| `-f, --format FORMAT` | yt-dlp format code (e.g., '136+140', 'best', 'worst') |
| `-o, --output FILENAME` | Output filename (extension added automatically) |
| `-s, --silent` | Silent mode (no interactive prompts) |
| `-r, --resume` | Resume incomplete downloads (not applicable in --play mode) |
| `--player PLAYER` | Player to use (mpv, vlc, etc.) [default: mpv] |
| `--play` | Play video while downloading simultaneously |
| `--stream` | Stream video directly without saving |
| `--record` | Use mpv's built-in stream recording feature |

## Examples

### Basic Download
```bash
# Download with default settings
./ytdl-plus.sh https://youtu.be/dQw4w9WgXcQ

# Download with specific format and filename
./ytdl-plus.sh -f "bestvideo[height<=720]+bestaudio" -o "my_video" https://youtu.be/dQw4w9WgXcQ

# Download in MP4 format
./ytdl-plus.sh -c mp4 -o "video" https://youtu.be/dQw4w9WgXcQ
```

### Streaming and Playing
```bash
# Play while downloading (saves file and plays simultaneously)
./ytdl-plus.sh --play https://youtu.be/dQw4w9WgXcQ

# Stream only (no file saved)
./ytdl-plus.sh --stream https://youtu.be/dQw4w9WgXcQ

# Use VLC instead of mpv
./ytdl-plus.sh --stream --player vlc https://youtu.be/dQw4w9WgXcQ

# Record using mpv's built-in feature
./ytdl-plus.sh --record -o "recorded_stream" https://youtu.be/dQw4w9WgXcQ
```

### Advanced Usage
```bash
# Silent mode with resume capability
./ytdl-plus.sh -s -r -o "my_video" https://youtu.be/dQw4w9WgXcQ

# Specific format with play-while-downloading
./ytdl-plus.sh --play -f "best[height<=1080]" https://youtu.be/dQw4w9WgXcQ
```

## How It Works

### Play-While-Downloading Mode
The script uses a clever pipeline approach:
1. `yt-dlp` downloads the video and pipes it to stdout
2. `tee` receives the stream, saves it to the specified file, and passes it through
3. The media player reads the stream from stdin

This approach is more reliable than watching for temporary files and ensures the download completes even if the player is closed early.

### Interactive Format Selection
When not in silent mode, the script will:
1. Fetch available video formats using `yt-dlp --list-formats`
2. Display the options to the user
3. Allow selection of specific format codes
4. Fall back to 'best' quality if no selection is made

## File Structure

The script creates files in the current directory by default. The `.gitignore` file excludes:
- `/movies` directory
- `*.mkv*` files
- `*.sh.*` files (script backups)
- `*.backup*` files

## Error Handling

The script includes robust error handling:
- **Signal Trapping**: Properly cleans up background processes on interruption
- **Dependency Checking**: Verifies required tools are installed before execution
- **URL Validation**: Ensures provided URLs are properly formatted
- **File Conflict Resolution**: Handles existing files with overwrite/resume options
- **Exit Codes**: Returns appropriate exit codes for different failure scenarios

## Troubleshooting

### Common Issues

1. **"yt-dlp not found"**: Install yt-dlp using your package manager
2. **"mpv not found"**: Install mpv or specify a different player with `--player`
3. **Permission denied**: Make the script executable with `chmod +x ytdl-plus.sh`
4. **Download fails**: Try different format codes or check if the URL is accessible

### Debug Tips

- Use `-s` (silent mode) to avoid interactive prompts in automated scenarios
- Check available formats first: `yt-dlp --list-formats <url>`
- Test with `--stream` mode first to verify the URL works
- Use `--player vlc` if mpv is not available

## License

This script is provided as-is for educational and personal use. Please respect the terms of service of video platforms and content creators' rights when using this tool.
