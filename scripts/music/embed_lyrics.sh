#!/bin/bash
# --- This script embeds both SYNCHRONIZED (.lrc) and UNSYNCHRONIZED (.txt) lyrics ---

# Function to process files for a given audio extension
process_files() {
  local extension="$1"
  find . -type f -name "*.$extension" | while read -r audiofile; do
    # Define potential lyric file names
    lrcfile="${audiofile%.$extension}.lrc"
    txtfile="${audiofile%.$extension}.txt"

    # PRIORITIZE .lrc: Check for the synchronized lyric file first
    if [ -f "$lrcfile" ]; then
      echo "SYNCED: Embedding '$lrcfile' into '$audiofile'"
      kid3-cli -c "import lrc:'$lrcfile'" "$audiofile"
      
      # Optional: uncomment to delete the .lrc file after embedding
      # rm "$lrcfile"
      
    # FALLBACK to .txt: If no .lrc, check for an unsynchronized text file
    elif [ -f "$txtfile" ]; then
      echo "UNSYNCED: Embedding '$txtfile' into '$audiofile'"
      # The 'set lyrics' command correctly creates an unsynchronized USLT tag
      kid3-cli -c "set lyrics \"$(cat "$txtfile")\"" "$audiofile"

      # Optional: uncomment to delete the .txt file after embedding
      # rm "$txtfile"
    fi
  done
}

echo "Starting lyrics embedding for MP3 files..."
process_files "mp3"

echo "Starting lyrics embedding for FLAC files..."
process_files "flac"

# Add more lines here for other formats like .m4a or .ogg if you have them
# process_files "m4a"

echo "Script finished!"
