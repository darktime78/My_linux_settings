#!/bin/bash
## VLC
PCKGS="vlc"

## Image view
PCKGS+=" feh"

## File manager
PCKGS+=" pcmanfm"

## Music player
PCKGS+=" qmmp"

## Emacs
PCKGS+=" emacs"

## Gimp
PCKGS+=" gimp"

## Keepass
PCKGS+=" keepass"

## Printer
PCKGS+=" cups"
PCKGS+=" system-config-printer"
PCKGS+=" brother-hl1118"
echo "For enable printer daemon"
echo "exec: systemctl enable --now cups.service"

yay -S $PCKGS
