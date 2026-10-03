#!/bin/bash
PAT='[p]ipewire-control-center'

if pgrep -f "$PAT" > /dev/null; then
    pkill -TERM -f "$PAT"
else
    pipewire-control-center > /dev/null 2>&1 &
fi
