# HypXRland runtime stack

This meta-package installs the parallel HypXRland compositor, its matching
control client, patched WiVRn server, voice daemon and base English model, HUD,
VA-API decode gate, background renderer, and the `hypxrcompose` offline
compositor for recorded `.hypxrtake` bundles. It does not replace Arch's stock
Hyprland compositor or the normal Omarchy session.

Install `hypxrland-omarchy` for the complete Omarchy integration and the
**Omarchy XR** display-manager session. Then run:

```bash
omarchy-setup-hypxrland
```

The command creates `~/.config/hypr/hyprland-xr.lua` only when it is absent.
The session refuses to start without a readable config and never falls through
to the normal Omarchy configuration.

WiVRn pairing, GPU/render-node selection, and device-specific runtime settings
remain per-user state. `hypxrland-omarchy` also installs `monado-xreal`, the
XREAL Air runtime, and `xreal-ctl`, which switches the glasses between 2D and
3D side-by-side for the desktop. The stack alone only suggests `monado-xreal`.

While the XREAL runtime runs, `monado-xreal` holds the `performance` power
profile through power-profiles-daemon's hold API, because 6DoF tracking is
CPU-bound. `monado-xreal.service` pulls in
`monado-xreal-performance-hold.service`, which is bound to it: stopping,
crashing or killing the runtime stops the hold, and the daemon then drops it.
The hold is a stopgap until Monado performs well without turbo. It never blocks
the runtime: with no daemon, no polkit grant or no performance profile, the
helper logs why (`journalctl --user -u monado-xreal-performance-hold.service`)
and exits. Picking a power profile by hand ends the hold until the runtime next
starts. To turn it off, run
`systemctl --user mask monado-xreal-performance-hold.service`. There is no
battery-level cut-off.
