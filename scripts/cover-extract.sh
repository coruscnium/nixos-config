#!/bin/bash

find "${1:-.}" -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.m4a" -o -name "*.ogg" \) |
  sort |
  awk -F/ '{OFS="/"; $NF=""; print}' |
  sort -u |
  while IFS= read -r folder; do
    if [[ -f "${folder}cover.jpg" ]]; then
      echo "Skipping (exists): $folder"
      continue
    fi
    # Grab the first audio file in the folder
    first=$(find "$folder" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.m4a" -o -name "*.ogg" \) | sort | head -1)
    if ffmpeg -i "$first" -an -vcodec copy "${folder}cover.jpg" -y 2>/dev/null; then
      echo "Saved: ${folder}cover.jpg"
    else
      echo "No cover found: $folder"
    fi
  done
