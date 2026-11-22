#!/bin/bash
#
# Put your docker apps (and Neovim) into the normal rofi app launcher
# ($mod+d / Alt+F2) with icons. Run once; run again after changes.
# Writes .desktop files to ~/.local/share/applications.

APPS="$HOME/.local/share/applications"
RUN="$HOME/.my_scripts/.data/docker_app.sh"
mkdir -p "$APPS"

entry() { # file name icon exec [categories]
	cat >"$APPS/$1.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$2
Icon=$3
Exec=$4
Terminal=false
Categories=${5:-Utility;}
DESKTOP
	echo "  $2"
}

echo "Docker apps:"
entry docker-firefox  "Firefox (Docker)"  firefox  "$RUN firefox"  "Network;WebBrowser;"
entry docker-chromium "Chromium (Docker)" chromium "$RUN chromium" "Network;WebBrowser;"
entry docker-steam    "Steam (Docker)"    steam    "$RUN steam"    "Game;"
entry docker-telegram "Telegram (Docker)" telegram "$RUN telegram" "Network;Chat;"
entry docker-discord  "Discord (Docker)"  discord  "$RUN discord"  "Network;Chat;"
entry docker-claude   "Claude AI (Docker)" web-browser "$RUN claude"   "Network;Office;"
entry docker-nvimcpp "Neovim C++ + LocalAI (Docker)" nvim "$RUN nvimcpp" "Development;TextEditor;"

# Same file name as the system nvim.desktop, so this one wins: opens Neovim
# in its own alacritty window (app_id "nvim") that goes to workspace 3.
echo "Editors:"
entry nvim "Neovim" nvim "alacritty --class nvim -e nvim %F" "Utility;TextEditor;"
echo 'MimeType=text/plain;text/x-makefile;text/x-c;text/x-c++;text/x-python;text/x-shellscript;' >>"$APPS/nvim.desktop"

update-desktop-database "$APPS" 2>/dev/null
echo 'Done. The apps show up in rofi ($mod+d).'
