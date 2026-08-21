-- Omarchy Quattro XR configuration
--
-- This file is loaded as the main config for the parallel HypXRland session.
-- It imports the user's normal Quattro config, then adds only XR behavior.

require("hyprland")

hl.config({
  openxr = {
    enabled = true,
    overlay = true,
    hand_input = "off",
    depth_desktop = true,

    -- The OpenXR runtime and compositor must render on the same GPU. Set this
    -- after identifying the runtime's render node on a multi-GPU machine.
    -- gpu = "/dev/dri/renderD128",
  },
})

hl.xr_monitor({
  name = "XR-main",
  mode = "2560x1440@90",
  anchor = "local",
  pos = { 0, 1.4, -1.5 },
  adaptive = true,
  roam = "body",
  size = 2.2,
})
hl.monitor({ output = "XR-main", mode = "2560x1440@90", position = "auto", scale = "1.25" })

hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user start wivrn.service")
  hl.exec_cmd("hypxrva-watcher")
end)

hl.bind("SUPER + SHIFT + G", hl.dsp.xrmonitor("gazegrab"))
hl.bind("SUPER + ALT + equal", hl.dsp.xrmonitor("gazepush 0.1"), { repeating = true })
hl.bind("SUPER + ALT + minus", hl.dsp.xrmonitor("gazepush -0.1"), { repeating = true })
hl.bind("SUPER + ALT + H", hl.dsp.xrmonitor("handinput toggle"))
hl.bind("SUPER + ALT + M", hl.dsp.xrmonitor("view toggle"), { description = "Toggle XR monitor view" })
hl.bind("SUPER + Home", hl.dsp.xrmonitor("center"))
hl.bind("SUPER + SHIFT + X", hl.dsp.exec_cmd("wivrnctl disconnect"))
