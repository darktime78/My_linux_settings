# How to install
If the line starts with #, you must execute this command as root, if with $, then as the created user.
## Arch linux installation
1) Format the partitions
2) Install basic system
3) Chroot to installed linux
4) Create a user
5) Clone the repository to the created user's home directory (*you can use any other path and folder name, but in the example we will use the default name and home directory*)
```bash
$ git clone https://github.com/HardDie/My_linux_settings ~/My_linux_settings --recursive
```
6) Install **stow**
## How to run scripts
Change directory to ~/My_linux_settings
```bash
$ cd ~/My_linux_settings
```
### Create links
Creating symbolic links for all configuration files. After running this command you should see many symbolic links in the home directory and in the .config directory
```
$ ./makelinks.sh
```
### Initial system setup
Change directory to ~/.my_scripts
```bash
$ cd ~/.my_scripts
```
To configure your newly installed linux, run the first_setup.sh script. It will do the setup:
- locale
- timezone
- hostname
- multilibs for pacman
- switch pacman to color mode
- font for the vconsole
```
# ./first_setup.sh
```
### yay
Install the **yay** app
```bash
$ ./install_yay.sh
```
### sway
Install the necessary applications for the **sway** environment
```bash
$ ./check_sway.sh
```
### Battery and power saving (laptop)
Enable power-profiles-daemon and a few safe power saving tweaks. Every step asks first.
```bash
# ./setup_power.sh
```
### Status bar setup
The bar is waybar with native modules only (no polling scripts), so nothing needs to be compiled for it.
To build the application that keeps an independent keyboard layout for each window ( go ):
```bash
$ cd ~/.my_scripts/.data/binary
$ make independent_layout
```
(`make` without arguments also builds the old C helper used by the i3 status bar.)
## Additional configuration
### Wallpaper
If you don't have your own image for the wallpaper, you can use the default wallpaper.
```bash
$ mkdir ~/.wallpapers
$ cp /usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png ~/.wallpapers/wallpaper.png
```
Or if you have a different screen size, you can see a list of all available wallpapers
```bash
$ yay -Ql sway | grep '.png'
```
### Status bar
* Config: `~/.config/sway/waybar.conf`, style: `~/.config/sway/style.css` (style changes are picked up automatically).
* Restart the bar after editing the config: `$mod+Shift+b`. Log: `$XDG_RUNTIME_DIR/waybar.log`.
* Clickable: volume (click = mute, right click = mixer, scroll = volume), brightness (scroll),
  network (click = show traffic), power profile (click = next profile), clock (hover = calendar),
  eye icon = keep the screen on (disables auto lock).

### Idle and sleep
| Idle time | Action |
|---|---|
| 4 min | dim the screen |
| 5 min | lock |
| 5.5 min | screen off |
| 15 min | suspend, **only on battery** |

The screen is always locked before suspend. Fullscreen windows (video, games) and the eye icon in the bar prevent all of it.
Timeouts are in the `swayidle` block of `~/.config/sway/config`.

### Useful shortcuts
| Keys | Action |
|---|---|
| `$mod+d` / `Alt+F2` | application launcher |
| `$mod+Shift+d` | run a command |
| `Alt+Tab` | window switcher |
| `$mod+Shift+e` | power menu (lock / suspend / log out / reboot / power off) |
| `Ctrl+Alt+Shift+l` | lock |
| `Ctrl+Alt+Shift+s` | suspend |
| `$mod+m` | show / hide the bar |
| `$mod+Shift+b` | restart the bar |
| `$mod+n` | do not disturb on / off |
| `Ctrl+Shift+Space` / `$mod+Shift+n` | dismiss all / restore last notification |
| `F12` / `Shift+F12` / `Ctrl+F12` | screenshot: screen / window / area (saved to ~/Screenshots and copied) |
