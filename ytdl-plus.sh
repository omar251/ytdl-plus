#!/bin/bash

# Unified Video Downloader Script using yt-dlp
# Combines download, streaming, and play-while-downloading capabilities.
# This enhanced version simplifies the play-while-downloading logic for greater reliability.

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# --- Configuration ---

# Colors for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
DEFAULT_CONTAINER="mkv"
DEFAULT_PLAYER="mpv"

# Initialize variables
container_format="$DEFAULT_CONTAINER"
output_filename=""
silent_mode=false
resume_mode=false
url=""
format_flag=""
play_mode="" # Modes: play, stream, record, "" (download only)
player="$DEFAULT_PLAYER"

# --- Helper Functions ---

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    # Send error messages to stderr
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Cleanup function to be called on script exit/interruption
cleanup() {
    # Kill any background processes started by this script
    # This prevents orphaned yt-dlp processes if the script is interrupted.
    if (jobs -p | grep -q .); then
        print_info "\nCaught exit signal. Stopping background jobs..."
        kill $(jobs -p) 2>/dev/null
    fi
    exit 1
}

# Trap signals to ensure cleanup runs
trap cleanup INT TERM

# Function to show help message
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] <video_url>

Unified video downloader with streaming and play-while-downloading capabilities using yt-dlp.

MODES:
  Default: Download only.
  --play:   Play video with '$player' while downloading it simultaneously.
  --stream: Stream video directly to '$player' without saving to a file.
  --record: Use mpv's built-in stream recording feature.

OPTIONS:
  -h, --help               Show this help message.
  -c, --container FORMAT   Container format (mkv, mp4, etc.) [default: $DEFAULT_CONTAINER].
  -f, --format FORMAT      yt-dlp format code (e.g., '136+140', 'best', 'worst').
  -o, --output FILENAME    Output filename (extension is added automatically).
  -s, --silent             Silent mode (no interactive prompts).
  -r, --resume             Resume incomplete downloads (not applicable in --play mode).
  --player PLAYER          Player to use (mpv, vlc, etc.) [default: $DEFAULT_PLAYER].

EXAMPLES:
  # Basic download
  $0 https://youtu.be/dQw4w9WgXcQ

  # Download a specific format
  $0 -f "bestvideo[height<=720]+bestaudio" -o "my_video" https://youtu.be/dQw4w9WgXcQ

  # Play while downloading
  $0 --play https://youtu.be/dQw4w9WgXcQ

  # Stream only (no download)
  $0 --stream https://youtu.be/dQw4w9WgXcQ
EOF
}

# --- Core Logic ---

# Check for required command-line tools
check_dependencies() {
    # Check for a video player if a mode requiring one is selected
    if [[ "$play_mode" == "stream" || "$play_mode" == "play" || "$play_mode" == "record" ]]; then
        if ! command -v "$player" &> /dev/null; then
            print_error "'$player' is not installed but is required for this mode."
            exit 1
        fi
    fi

    # Check for yt-dlp for any mode except pure streaming
    if [[ "$play_mode" != "stream" ]] && ! command -v yt-dlp &> /dev/null; then
        print_error "'yt-dlp' is not installed but is required for downloading."
        exit 1
    fi

    # fzf is optional, only recommend if in interactive mode
    if [[ "$silent_mode" == false ]] && ! command -v fzf &> /dev/null; then
        print_warning "Optional: 'fzf' is not installed. Falling back to basic prompt."
        print_info "Install 'fzf' for a better interactive format selection experience."
    fi
}

# Validate that the provided URL looks like a URL
validate_url() {
    if [[ ! "$1" =~ ^https?:// ]]; then
        print_error "Invalid URL format. Must start with http:// or https://"
        exit 1
    fi
}

# --- Argument Parsing ---

# Loop through command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--container)
            container_format="$2"
            shift
            ;;
        -f|--format)
            format_flag="$2"
            shift
            ;;
        -o|--output)
            output_filename="$2"
            shift
            ;;
        -s|--silent)
            silent_mode=true
            ;;
        -r|--resume)
            resume_mode=true
            ;;
        --play)
            play_mode="play"
            ;;
        --stream)
            play_mode="stream"
            ;;
        --record)
            play_mode="record"
            ;;
        --player)
            player="$2"
            shift
            ;;
        --) # End of options
            shift
            break
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "${url:-}" ]]; then
                url="$1"
            else
                print_error "Multiple URLs provided. This script only supports one URL at a time."
                exit 1
            fi
            ;;
    esac
    shift
done

# --- Pre-flight Checks ---

# Ensure a URL was provided
if [[ -z "${url:-}" ]]; then
    print_error "No video URL provided."
    show_help
    exit 1
fi

validate_url "$url"
check_dependencies

# --- Interactive Setup ---

# Interactively ask for video/audio format if not specified
get_streams() {
    # Skip if format is already set, or in silent/stream mode
    if [[ -n "$format_flag" || "$silent_mode" == true || "$play_mode" == "stream" ]]; then
        return
    fi

    print_info "Fetching available streams..."
    local streams
    streams=$(yt-dlp --list-formats "$url" 2>/dev/null)

    if [[ -z "$streams" ]]; then
        print_warning "Could not fetch streams. Using default quality."
        return
    fi

    # Use fzf for interactive selection if available
    if command -v fzf &> /dev/null; then
        print_info "Use TAB to select multiple formats (e.g., video + audio), Enter to confirm."
        
        # fzf command with a preview window, defined as a bash array
        local -a fzf_cmd=(
            fzf --multi --prompt="Select format(s): " \
            --header="Press TAB to select multiple, Enter to confirm" \
            --preview="echo {}" --preview-window=up:3:wrap
        )
        
        # Get the list of formats, dynamically finding the header
        local header_line=$(echo "$streams" | grep -n -m 1 "^ID" | cut -d: -f1)
        local format_list=$(echo "$streams" | tail -n +$((header_line + 1)))
        
        # Show the fzf menu and get the selected formats
        local selection=$(echo "$format_list" | "${fzf_cmd[@]}")

        if [[ -n "$selection" ]]; then
            # Combine selected format IDs with a '+'
            format_flag=$(echo "$selection" | awk '{print $1}' | tr '\n' '+' | sed 's/+$//')
            print_info "Selected format: $format_flag"
        else
            print_info "No format selected. Defaulting to 'best'."
            format_flag="best"
        fi
    else
        # Fallback to the original text-based prompt
        echo -e "Available streams:\n$streams"
        print_info "You can specify a format with '-f'. Examples:"
        echo "  - 'best':           Best quality with combined video and audio."
        echo "  - '136+140':        Separate 720p video + high quality audio (requires merge)."
        echo "  - 'bestvideo+bestaudio/best': Best separate streams, fallback to best combined."
        echo
        read -p "Enter format ID (or press Enter for 'best'): " format_choice

        if [[ -n "$format_choice" ]]; then
            format_flag="$format_choice"
        else
            format_flag="best"
        fi
    fi
}

get_streams

# Get a filename if one is needed and not provided
get_filename() {
    # Skip if streaming (no file saved)
    if [[ "$play_mode" == "stream" ]]; then
        return
    fi

    # If no output filename is set, generate or ask for one
    if [[ -z "${output_filename:-}" ]]; then
        local suggested_name
        # Try to get the video title for a better default filename
        print_info "Fetching video title for filename suggestion..."
        suggested_name=$(yt-dlp --get-title "$url" 2>/dev/null | sed 's/[^a-zA-Z0-9._-]/_/g')

        # Fallback to timestamp if title fetch fails
        if [[ -z "$suggested_name" ]]; then
            suggested_name=$(date +"%Y-%m-%d_%H%M%S")
        fi

        if [[ "$silent_mode" == false ]]; then
            read -p "Enter filename (suggestion: $suggested_name): " output_filename
            # Use suggestion if input is empty
            output_filename=${output_filename:-$suggested_name}
        else
            output_filename=$suggested_name
        fi
    fi

    # Append the container extension if it's not already there
    if [[ ! "$output_filename" == *."$container_format" ]]; then
        output_filename+=".$container_format"
    fi
}

get_filename

# Check if the output file already exists
check_file_exists() {
    # Not relevant for stream mode or if the file doesn't exist yet
    if [[ "$play_mode" == "stream" || ! -f "$output_filename" ]]; then
        return
    fi

    if [[ "$resume_mode" == true ]]; then
        print_info "File '$output_filename' exists. Resume mode is enabled."
    else
        print_warning "File '$output_filename' already exists."
        if [[ "$silent_mode" == false ]]; then
            read -p "Overwrite? (y/N): " overwrite
            if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                print_info "Operation cancelled."
                exit 0
            fi
        else
            print_error "File exists. Use -r to resume or choose a different filename."
            exit 1
        fi
    fi
}

# --- Main Execution ---

execute_operation() {
    local ytdlp_args=()

    case "$play_mode" in
        "stream")
            print_info "Streaming with '$player' (no download)..."
            "$player" "$url"
            ;;

        "play")
            print_info "Playing with '$player' while downloading..."
            print_info "Saving video as: $output_filename"
            check_file_exists # Check for overwrite before starting

            if [[ "$resume_mode" == true ]]; then
                print_warning "Resume mode (-r) is not applicable with --play mode."
            fi

            # This is the core of the play-while-downloading feature.
            # 1. yt-dlp downloads the video and pipes it to standard output (-o -).
            # 2. tee receives the stream, saves it to '$output_filename', and also passes it to its standard output.
            # 3. The player reads the stream from its standard input (-).
            # This pipeline is more robust than trying to watch for a temporary file.
            ytdlp_args=("yt-dlp" "$url" "--output" "-")
            [[ -n "$format_flag" ]] && ytdlp_args+=("--format" "$format_flag")

            if ! "${ytdlp_args[@]}" | tee "$output_filename" | "$player" - ; then
                # This message usually appears when the user closes the player.
                print_warning "Player exited (Code: $?). The 'tee' command will ensure the download completes."
            fi
            ;;

        "record")
            print_info "Recording with '$player' built-in feature..."
            print_info "Saving video as: $output_filename"
            check_file_exists

            if [[ "$player" != "mpv" ]]; then
                print_error "Built-in recording is only supported with mpv."
                exit 1
            fi
            mpv --stream-record="$output_filename" "$url"
            ;;

        *) # Default: Download only
            print_info "Downloading with yt-dlp..."
            print_info "Saving video as: $output_filename"
            check_file_exists

            ytdlp_args=("yt-dlp" "$url" "--output" "$output_filename")
            [[ -n "$format_flag" ]] && ytdlp_args+=("--format" "$format_flag")
            [[ "$resume_mode" == true ]] && ytdlp_args+=("--continue")

            # Add merge format if not specified in filename
            if [[ ! "$output_filename" == *."$container_format" ]]; then
                 ytdlp_args+=("--merge-output-format" "$container_format")
            fi

            # Execute the download
            "${ytdlp_args[@]}"
            ;;
    esac
}

# --- Run ---

execute_operation

# --- Final Report ---

# Check the outcome of the operation
if [[ "$play_mode" != "stream" ]] && [[ -f "$output_filename" ]]; then
    print_success "Operation completed successfully."
    file_size=$(du -h "$output_filename" | cut -f1)
    print_info "Output file: $output_filename ($file_size)"
elif [[ "$play_mode" == "stream" ]]; then
    print_success "Streaming finished."
else
    # If we get here, it means a download was expected but the file doesn't exist.
    print_error "Operation may have failed. Output file not found."
    exit 1
fi
