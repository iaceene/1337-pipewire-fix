#!/usr/bin/env bash
#
# install-audio.sh
#
# Sets up a user-level PipeWire config, installs a hidden
# ~/.start-audio.sh helper script, and wires up a `start-audio`
# alias in zsh (offering to make zsh the default shell if it isn't).
#
# Usage:
#   ./install-audio.sh


set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONFIG_DIR="$HOME/.config/pipewire"
START_AUDIO_SRC="$SCRIPT_DIR/start-audio.sh"
START_AUDIO_DEST="$HOME/.start-audio.sh"
AUTOSTART_DIR="$HOME/.config/autostart"
DESKTOP_SRC="$SCRIPT_DIR/audio.desktop"
DESKTOP_DEST="$AUTOSTART_DIR/audio.desktop"
ZSHRC="$HOME/.zshrc"
ALIAS_LINE="alias start-audio=\"$HOME/.start-audio.sh\""

log()  { printf '\033[1;34m[install-audio]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[install-audio][warn]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[install-audio][error]\033[0m %s\n' "$1" >&2; }

log "Creating $CONFIG_DIR"
mkdir -p "$CONFIG_DIR"

PIPEWIRE_CANDIDATES=(
    "/usr/share/pipewire/pipewire.conf"
    "/etc/pipewire/pipewire.conf"
    "/usr/local/share/pipewire/pipewire.conf"
)

PIPEWIRE_SRC=""
for candidate in "${PIPEWIRE_CANDIDATES[@]}"; do
    if [[ -f "$candidate" ]]; then
        PIPEWIRE_SRC="$candidate"
        break
    fi
done

if [[ -n "$PIPEWIRE_SRC" ]]; then
    log "Found pipewire.conf at $PIPEWIRE_SRC"
    if [[ -f "$CONFIG_DIR/pipewire.conf" ]]; then
        warn "$CONFIG_DIR/pipewire.conf already exists — backing it up to pipewire.conf.bak"
        cp "$CONFIG_DIR/pipewire.conf" "$CONFIG_DIR/pipewire.conf.bak"
    fi
    cp "$PIPEWIRE_SRC" "$CONFIG_DIR/pipewire.conf"
    log "Copied pipewire.conf -> $CONFIG_DIR/pipewire.conf"
else
    err "pipewire.conf not found in any known location:"
    for candidate in "${PIPEWIRE_CANDIDATES[@]}"; do
        err "  - $candidate"
    done
    warn "Is pipewire installed? (e.g. 'sudo apt install pipewire' or 'sudo pacman -S pipewire')"
    warn "Skipping pipewire.conf copy — continuing with the rest of the setup."
fi

if [[ -f "$START_AUDIO_SRC" ]]; then
    cp "$START_AUDIO_SRC" "$START_AUDIO_DEST"
    chmod +x "$START_AUDIO_DEST"
    log "Installed $START_AUDIO_DEST"
else
    err "start-audio.sh not found next to this script ($SCRIPT_DIR)."
    err "Place start-audio.sh alongside install-audio.sh and re-run."
    exit 1
fi

if [[ -f "$DESKTOP_SRC" ]]; then
    mkdir -p "$AUTOSTART_DIR"
    if [[ -f "$DESKTOP_DEST" ]]; then
        warn "$DESKTOP_DEST already exists — backing it up to audio.desktop.bak"
        cp "$DESKTOP_DEST" "$AUTOSTART_DIR/audio.desktop.bak"
    fi
    cp "$DESKTOP_SRC" "$DESKTOP_DEST"
    chmod +x "$DESKTOP_DEST"
    log "Installed $DESKTOP_DEST"
else
    warn "audio.desktop not found next to this script ($SCRIPT_DIR) — skipping autostart entry."
fi

CURRENT_SHELL="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || echo "${SHELL:-}")"
ZSH_PATH="$(command -v zsh || true)"

if [[ -z "$ZSH_PATH" ]]; then
    warn "zsh is not installed — skipping default-shell check and alias setup."
    warn "Install zsh, then re-run this script to configure the alias."
else
    if [[ "$CURRENT_SHELL" != "$ZSH_PATH" && "$CURRENT_SHELL" != *"/zsh" ]]; then
        log "Current default shell is '$CURRENT_SHELL', not zsh."
        read -r -p "Set zsh ($ZSH_PATH) as your default shell? [y/N] " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            chsh -s "$ZSH_PATH" "$USER"
            log "Default shell changed to $ZSH_PATH (takes effect on next login)."
        else
            log "Leaving default shell as-is."
        fi
    else
        log "zsh is already the default shell."
    fi

    touch "$ZSHRC"
    if grep -qF "$ALIAS_LINE" "$ZSHRC"; then
        log "Alias already present in $ZSHRC"
    elif grep -q '^alias start-audio=' "$ZSHRC"; then
        warn "An existing 'start-audio' alias was found in $ZSHRC — updating it."
        tmp_file="$(mktemp)"
        sed "s|^alias start-audio=.*|$ALIAS_LINE|" "$ZSHRC" > "$tmp_file"
        mv "$tmp_file" "$ZSHRC"
    else
        {
            echo ""
            echo "# Added by install-audio.sh"
            echo "$ALIAS_LINE"
        } >> "$ZSHRC"
        log "Added alias to $ZSHRC"
    fi
fi

if [[ -x "$START_AUDIO_DEST" ]]; then
    log "Starting audio (logs suppressed) — process detached from this shell."
    nohup "$START_AUDIO_DEST" >/dev/null 2>&1 &
    disown
else
    warn "$START_AUDIO_DEST not found or not executable — skipping auto-start."
fi


xdg-open "https://github.com/iaceene"
log "Done. If audio still not working for you run 'source ~/.zshrc' (or open a new terminal) to pick up the 'start-audio' alias."
log "Follow me on github <3"
