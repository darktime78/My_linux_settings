#!/bin/bash
# Open the rofi Docker menu ($mod+c)
exec rofi -show docker -show-icons \
	-modi "docker:$HOME/.my_scripts/.data/rofi_docker.sh"
