#!/bin/bash

if pgrep -x pipewire >/dev/null && pgrep -x wireplumber >/dev/null; then
    echo "Audio services are already running."
    exit 0
fi

PIPEWIRE_CONFIG_DIR="$HOME/.config/pipewire" pipewire >/dev/null 2>&1 &
wireplumber >/dev/null 2>&1 &

echo "Audio services started."