# dmgbuild settings for the Swip installer window.
# Usage (from build.sh):
#   dmgbuild -s scripts/dmg-settings.py -D app=dist/Swip.app -D background=.build/dmg-bg/background.png "Swip" dist/Swip.dmg
#
# Layout contract with scripts/make-dmg-background.swift: a 660x420 content area,
# 128 pt icons, the app at (170, 212) and Applications at (490, 212).
import os.path

app = defines["app"]  # noqa: F821 (injected by dmgbuild)
app_name = os.path.basename(app)

format = "UDZO"
filesystem = "HFS+"
size = None

files = [app]
symlinks = {"Applications": "/Applications"}
hide_extension = [app_name]

icon = os.path.join(app, "Contents", "Resources", "AppIcon.icns")
background = defines["background"]  # noqa: F821 (the @2x file next to it is picked up automatically)

# Finder counts the ~32 pt title bar in the window height, so add it on top
# of the 420 pt background.
window_rect = ((200, 140), (660, 452))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

arrange_by = None
icon_size = 128
text_size = 13
label_pos = "bottom"
icon_locations = {
    app_name: (170, 212),
    "Applications": (490, 212),
}
