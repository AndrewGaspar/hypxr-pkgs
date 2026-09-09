# voxtype-hypxr Arch package notes

This is a source build of the HypXR fork of voxtype: upstream 1.0.1 plus the
Muse Voice Transcribe streaming engine. It replaces Omarchy's prebuilt
`voxtype-bin`; pacman offers the swap when you install it.

## What is built

- `/usr/bin/voxtype` points at `/usr/lib/voxtype/voxtype-native`, a CPU
  Whisper build with an AVX2 baseline, plus the Muse, Soniox, and remote
  engines. No Vulkan or ONNX variants are shipped, so `voxtype setup gpu` and
  the ONNX engines are unavailable. Whisper runs on the CPU.
- The OSD launcher, the GTK4 and Quickshell frontends, and the audio bridge,
  all built from the same fork so the streaming states line up with the daemon.

Models are not packaged. Download one with `voxtype setup model`.

## Muse

Set `engine = "muse"` in `~/.config/voxtype/config.toml` and configure the
`[muse]` table. The packaged `/etc/voxtype/config.toml` is upstream's default
and does not document Muse; the keys are described under "Muse" in
`/usr/share/doc/voxtype-hypxr/CONFIGURATION.md`. Prefer the
`VOXTYPE_MUSE_API_KEY` environment variable over `api_key` in the config file.

## First run

```bash
sudo usermod -aG input "$USER"          # evdev hotkey access, then re-login
voxtype setup model
systemctl --user enable --now voxtype.service
```

## Replacing a hand-installed copy

If you previously copied `voxtype` or `voxtype-osd-quickshell` into a
directory that precedes `/usr/bin` on `PATH`, such as the local prefix's bin
directory, they shadow the packaged binaries; remove them. A hand-edited
`~/.config/systemd/user/voxtype.service` shadows the packaged user unit:

```bash
systemctl --user disable --now voxtype.service
rm ~/.config/systemd/user/voxtype.service
systemctl --user daemon-reload
systemctl --user enable --now voxtype.service
```
