# HypXRland legacy configuration transition

This package is intentionally empty except for this notice and its license. It
replaces the Omarchy 3 configuration payload shipped by versions before 4.0.0.
Upgrading the package removes those package-owned classic configuration files
from `/usr/share/omarchy/default/hypr/`.

User configuration is not package-owned and is not removed. During this
transition, HypXRland continues to launch a readable
`~/.config/hypr/hyprland-xr.conf` when no `hyprland-xr.lua` exists. The legacy
configuration is deprecated and should be migrated to the Quattro Lua format.

New installations of `hypxrland-omarchy` do not install this package. It remains
in the repository for one transition period so existing installations can
upgrade cleanly, and can be retired after supported systems have crossed the
4.0.0 transition.
