# Настройки окна установщика для dmgbuild (вызывает build.sh).
# Координаты иконок совпадают со стрелкой на фоне, см. tools/make_dmg_background.py.

files = ["build/DOBROANDPOZITIV.app"]
symlinks = {"Applications": "/Applications"}
icon = "build/DOBROANDPOZITIV.app/Contents/Resources/AppIcon.icns"
background = "build/dmg-background.tiff"

window_rect = ((200, 120), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 128
text_size = 13
icon_locations = {
    "DOBROANDPOZITIV.app": (160, 200),
    "Applications": (480, 200),
}

format = "UDZO"
