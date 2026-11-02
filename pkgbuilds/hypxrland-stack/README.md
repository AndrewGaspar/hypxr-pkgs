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

For the life of an Omarchy XR session, `omarchy-xr-session` holds the
`performance` power profile through power-profiles-daemon's hold API, because
6DoF tracking is CPU-bound. The daemon drops the hold when the session ends.
The session starts without it if no daemon grants it (polkit allows the hold
only for an active local session); the reason is logged to
`~/.local/share/sddm/wayland-session.log`. Picking a power profile by hand ends
the hold for that session. To turn it off, export
`HYPXRLAND_PERFORMANCE_HOLD=0` from your login profile (for example
`~/.bash_profile`), which SDDM's login shell reads before the session starts.
There is no battery-level cut-off.
