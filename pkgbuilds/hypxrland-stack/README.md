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

While the XREAL runtime runs, `monado-xreal` keeps it off the `power-saver`
power profile, which turns turbo off, because 6DoF tracking needs turbo.
`monado-xreal.service` pulls in `monado-xreal-avoid-power-saver.service`: if the
active profile is `power-saver`, it switches to `balanced`, and when the runtime
stops, crashes or is killed it switches back, unless the profile was changed in
the meantime. `balanced`, `performance` and a `power-saver` another application
holds are left alone, and it checks only when the runtime starts. It does not
ask for `performance`: on a laptop whose CPU and GPU share one power limit,
`performance` keeps every core at full clock and the GPU throttles to its
minimum, while `balanced` keeps turbo and leaves power for the GPU. Whether
`performance` helps on AC power or with a discrete GPU is untested. This is a
stopgap until Monado performs well without turbo. It never blocks the runtime:
with no daemon or no polkit grant, the helper logs why (`journalctl --user -u
monado-xreal-avoid-power-saver.service`) and exits. To turn it off, run
`systemctl --user mask monado-xreal-avoid-power-saver.service`.
