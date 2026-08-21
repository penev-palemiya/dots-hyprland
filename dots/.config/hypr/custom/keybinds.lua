hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

hl.bind("ALT + Tab", hl.dsp.focus({ workspace = "previous" }), { description = "Workspace: Switch to previous" })
