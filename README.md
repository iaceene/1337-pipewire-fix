# 1337-pipewire-fix — PipeWire Audio Fix for Apple T2 Mac (Ubuntu 22.04)

This repo contains a workaround for a PipeWire startup failure on T2-equipped
Macs running Ubuntu 22.04. It sets up a **user-level** PipeWire config that
bypasses the broken system config, plus an autostart entry and a `zsh` alias
to launch it easily.

![POC](/assets/img.gif)

## Files

| File               | Purpose                                                              |
|--------------------|-----------------------------------------------------------------------|
| `install-audio.sh` | One-time setup script (run this first)                              |
| `start-audio.sh`   | Starts PipeWire/WirePlumber using the user config (installed as `~/.start-audio.sh`) |
| `audio.desktop`    | Autostart entry so the fix runs automatically on login (installed to `~/.config/autostart/`) |

## The problem

Audio doesn't work at all: no output devices show up in GNOME Settings, and
there's no sound through speakers, headphones, or USB audio.

This is **not** a hardware or USB device problem — ALSA correctly detects
every device:

- Apple T2 Audio
- AB13X USB Audio
- HDMI Audio

The real cause is that **PipeWire itself fails to start**, which in turn
takes WirePlumber down with it.

### Root cause

Two system-wide config drop-ins reference a LADSPA plugin that isn't
installed on the system:

```text
/etc/pipewire/pipewire.conf.d/10-t2_mic.conf
/etc/pipewire/pipewire.conf.d/10-t2_headset_mic.conf
```

Both load PipeWire's `filter-chain` module with:

```text
plugin = amp_1181
```

Since `amp_1181` isn't available, PipeWire fails on startup with errors like:

```text
failed to load plugin 'amp_1181': No such file or directory
mod.filter-chain: can't load graph
could not load mandatory module "libpipewire-module-filter-chain"
failed to create context
```

Because PipeWire can't start, WirePlumber can't start either, and GNOME shows
no audio devices at all — even though the underlying hardware is fine.

### Confirmed workaround

Starting PipeWire with a **custom user config** that bypasses the
`/etc/pipewire/pipewire.conf.d/*.conf` drop-ins lets PipeWire and WirePlumber
start normally, and all audio devices (speakers, headphones, USB audio)
appear and work correctly.

## What this fix does

`install-audio.sh` automates the workaround:

1. Creates `~/.config/pipewire/`.
2. Copies the base `pipewire.conf` (from `/usr/share/pipewire/`,
   `/etc/pipewire/`, or `/usr/local/share/pipewire/`, whichever is found)
   into `~/.config/pipewire/pipewire.conf` — this is the user config PipeWire
   loads instead of the broken system drop-ins.
3. Installs `start-audio.sh` as a hidden, executable script at
   `~/.start-audio.sh`, which starts PipeWire/WirePlumber using that user
   config.
4. Installs `audio.desktop` to `~/.config/autostart/audio.desktop`, so the
   fix is applied automatically on every login.
5. Checks whether `zsh` is your default shell and offers to switch it if
   it isn't (skipped if `zsh` isn't installed).
6. Adds a `start-audio` alias to `~/.zshrc`:
   ```bash
   alias start-audio="$HOME/.start-audio.sh"
   ```
   This **only defines the alias** — it does not run `start-audio.sh`
   automatically. Nothing executes just from opening a new shell; you have
   to type `start-audio` yourself (or rely on the autostart entry from step 4).

Re-running the script is safe: existing config/desktop files are backed up
(`*.bak`) before being overwritten, and the alias/autostart steps won't
create duplicates.

## Usage

```bash
# Make sure start-audio.sh and audio.desktop are next to install-audio.sh
chmod +x install-audio.sh
./install-audio.sh

# Then either:
source ~/.zshrc      # to pick up the new alias in this session
start-audio           # to start audio manually
# ...or just log out and back in — audio.desktop starts it for you
```

## Recommended permanent fix (for IT/system admins)

The steps above are a **user-level workaround**. The permanent, system-wide
fix is one of:

- Install the missing LADSPA plugin that provides `amp_1181`, **or**
- Remove, disable, or correct the two broken drop-in files:
  - `/etc/pipewire/pipewire.conf.d/10-t2_mic.conf`
  - `/etc/pipewire/pipewire.conf.d/10-t2_headset_mic.conf`

This is a system-wide PipeWire configuration issue tied to the T2 audio
setup — not a hardware fault or a user-account problem — so it should be
fixed once at the system level rather than per-user.

## Report for IT/Admin team

> **Subject:** PipeWire audio configuration issue on T2 Mac (Ubuntu 22.04)
>
> The audio issue is not caused by the hardware or USB audio devices. ALSA
> correctly detects all audio devices, including Apple T2 Audio, AB13X USB
> Audio, and HDMI Audio.
>
> The problem is that PipeWire fails to start because of two system
> configuration files (`/etc/pipewire/pipewire.conf.d/10-t2_mic.conf` and
> `/etc/pipewire/pipewire.conf.d/10-t2_headset_mic.conf`) that load the
> `filter-chain` module with `plugin = amp_1181`, a LADSPA plugin that isn't
> available on the system. This causes PipeWire — and consequently
> WirePlumber — to fail to start, so no audio devices appear in GNOME
> Settings and there's no sound from any output.
>
> As a temporary test, starting PipeWire with a custom user configuration
> that bypasses the `/etc/pipewire` drop-ins allows PipeWire and WirePlumber
> to run normally, with all audio devices appearing correctly.
>
> **Recommended fix:** install the missing `amp_1181` LADSPA plugin, or
> remove/disable/correct the two config files listed above. This is a
> system-wide configuration issue, not a hardware or account problem.
