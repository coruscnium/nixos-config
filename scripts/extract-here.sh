#!/bin/bash
for filepath in "$@"; do
    dir=$(dirname "$filepath")
    filename=$(basename "$filepath")

    case "$filename" in
      *.tar.*|*.tgz|*.tbz2|*.txz) base="${filename%%.*}" ;;
      *) base="${filename%.*}" ;;
    esac

    mkdir -p "$dir/$base"

    case "$filename" in
      *.tar.gz|*.tgz)    tar -xzf "$filepath"       -C "$dir/$base" ;;
      *.tar.bz2|*.tbz2)  tar -xjf "$filepath"       -C "$dir/$base" ;;
      *.tar.xz|*.txz)    tar -xJf "$filepath"       -C "$dir/$base" ;;
      *.tar.zst)         tar --zstd -xf "$filepath" -C "$dir/$base" ;;
      *.tar)             tar -xf "$filepath"         -C "$dir/$base" ;;
      *.zip)             unzip "$filepath"         -d "$dir/$base"   ;;
      *.7z)              7z x "$filepath"         -o"$dir/$base"     ;;
      *.rar)             unrar x "$filepath"         "$dir/$base/"   ;;
      *.gz)              gunzip -c "$filepath" >     "$dir/$base"    ;;
      *.bz2)             bunzip2 -c "$filepath" >    "$dir/$base"    ;;
    esac
done
