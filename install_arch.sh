#!/bin/bash
#
# Install everything after the base system, in one go.
#
# On the Arch ISO, after partitioning, mounting (root on /mnt, the EFI partition on
# /mnt/boot) and
#     pacstrap -K /mnt base linux linux-firmware
# run:
#     curl -LO https://raw.githubusercontent.com/darktime78/My_linux_settings/master/install_arch.sh
#     bash install_arch.sh
#
# It asks all questions first (names, passwords, timezone, what to install), then runs
# without stopping:
#   fstab · pacman (color, parallel downloads, multilib) · locale, keymap, timezone, hostname
#   microcode and GPU drivers (Intel / AMD / NVIDIA, the MX350 gets the 580xx driver)
#   bootloader: systemd-boot (UEFI, ESP on /boot) or GRUB (BIOS, or ESP on /efi),
#               with LUKS, LVM and btrfs detected automatically
#   user with sudo · NetworkManager, bluetooth, docker, printing, power profiles
#   sway desktop, apps, fonts · yay + AUR packages
#   these dotfiles (cloned, linked with makelinks.sh), layout helper, rofi Docker launchers,
#   weekly Docker image updates
#
# Safe to run again: it skips what is already done.
# Log: /mnt/var/log/install_arch.log (also kept on the installed system).

set -euo pipefail

REPO_URL="https://github.com/darktime78/My_linux_settings.git"
TARGET=/mnt
CONF=/root/install_arch.conf # inside the target, passwords included; deleted at the end
LOG=/var/log/install_arch.log

c_b=$'\e[1;34m' c_y=$'\e[1;33m' c_r=$'\e[1;31m' c_g=$'\e[1;32m' c_0=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$c_b" "$*" "$c_0"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '%swarning:%s %s\n' "$c_y" "$c_0" "$*" >&2; }
die() { printf '%serror:%s %s\n' "$c_r" "$c_0" "$*" >&2; exit 1; }

# ask VAR "question" default
ask() {
	local __v=$1 q=$2 d=${3:-} a
	read -r -p "$q${d:+ [$d]}: " a
	printf -v "$__v" '%s' "${a:-$d}"
}
# yesno VAR "question" Y|N
yesno() {
	local __v=$1 q=$2 d=$3 a
	read -r -p "$q [$([[ $d == Y ]] && echo Y/n || echo y/N)]: " a
	a=${a:-$d}
	[[ $a == [yY]* ]] && printf -v "$__v" 1 || printf -v "$__v" 0
}
# password VAR "for whom"
password() {
	local __v=$1 who=$2 p1 p2
	while :; do
		read -r -s -p "Password for $who: " p1; echo
		read -r -s -p "Repeat: " p2; echo
		[[ -n $p1 && $p1 == "$p2" ]] && break
		warn "empty or not the same, again"
	done
	printf -v "$__v" '%s' "$p1"
}

# ============================================================================
#  Stage 1: on the live ISO
# ============================================================================
detect_disk_layout() {
	# root device, without a btrfs [/subvol] suffix
	ROOT_SRC=$(findmnt -no SOURCE "$TARGET" | sed 's/\[.*\]$//')
	ROOT_FS=$(findmnt -no FSTYPE "$TARGET")
	ROOT_UUID=$(blkid -s UUID -o value "$ROOT_SRC" || true)
	ROOT_FLAGS=""
	if [[ $ROOT_FS == btrfs ]]; then
		local sv
		sv=$(findmnt -no OPTIONS "$TARGET" | tr ',' '\n' | sed -n 's/^subvol=//p')
		[[ -n $sv && $sv != / ]] && ROOT_FLAGS="subvol=${sv#/}"
	fi

	# LUKS / LVM under root: walk the devices below it
	LUKS_UUID="" LUKS_NAME="" USE_LVM=0
	local path type
	while read -r path type; do
		[[ $type == lvm ]] && USE_LVM=1
		[[ $type == crypt ]] && LUKS_NAME=$(basename "$path")
		if [[ $(blkid -s TYPE -o value "$path" 2>/dev/null) == crypto_LUKS ]]; then
			LUKS_UUID=$(blkid -s UUID -o value "$path")
		fi
	done < <(lsblk -snro PATH,TYPE "$ROOT_SRC")
	[[ -n $LUKS_UUID ]] || LUKS_NAME=""

	# boot: UEFI with the ESP on /boot (systemd-boot) or /efi (GRUB), else BIOS GRUB
	if [[ -d /sys/firmware/efi/efivars ]]; then
		if [[ $(findmnt -no FSTYPE "$TARGET/boot" 2>/dev/null) == vfat ]]; then
			BOOT=systemd-boot ESP=/boot
		elif [[ $(findmnt -no FSTYPE "$TARGET/efi" 2>/dev/null) == vfat ]]; then
			BOOT=grub-efi ESP=/efi
		else
			die "UEFI system, but no EFI partition mounted on $TARGET/boot (or $TARGET/efi)"
		fi
	else
		BOOT=grub-bios ESP=""
		BIOS_DISK=/dev/$(lsblk -snro NAME,TYPE "$ROOT_SRC" | awk '$2=="disk"{print $1; exit}')
		[[ -b $BIOS_DISK ]] || die "BIOS boot: can't find the disk under $ROOT_SRC for GRUB"
	fi
}

detect_hardware() {
	CPU=other
	grep -q GenuineIntel /proc/cpuinfo && CPU=intel
	grep -q AuthenticAMD /proc/cpuinfo && CPU=amd

	local vga
	vga=$(lspci -mm 2>/dev/null | grep -Ei '"(VGA compatible|3D|Display) controller"' || true)
	GPU_INTEL=0 GPU_AMD=0 NVIDIA=none
	grep -qi '"Intel' <<<"$vga" && GPU_INTEL=1
	grep -qiE '"(Advanced Micro Devices|AMD|ATI)' <<<"$vga" && GPU_AMD=1
	if grep -qi '"NVIDIA' <<<"$vga"; then
		# Maxwell (GM) / Pascal (GP): Arch's current driver dropped them -> 580xx from the AUR
		if grep -i '"NVIDIA' <<<"$vga" | grep -qE '\b(GM|GP)[0-9]{3}'; then
			NVIDIA=580xx
		else
			NVIDIA=open
		fi
		NVIDIA_NAME=$(grep -i '"NVIDIA' <<<"$vga" | sed -E 's/.*"NVIDIA Corporation" "([^"]*)".*/\1/' | head -1)
	fi

	LAPTOP=0
	if compgen -G '/sys/class/power_supply/BAT*' >/dev/null; then LAPTOP=1; fi
}

stage_live() {
	[[ $EUID -eq 0 ]] || die "run as root on the Arch ISO"
	mountpoint -q "$TARGET" || die "nothing mounted on $TARGET"
	[[ -f $TARGET/etc/arch-release ]] || die "run first: pacstrap -K $TARGET base linux linux-firmware"
	curl -fsS -m 10 -o /dev/null https://archlinux.org || die "no internet connection"

	detect_disk_layout
	detect_hardware

	step "Detected"
	info "root:   $ROOT_SRC ($ROOT_FS${ROOT_FLAGS:+, $ROOT_FLAGS}${LUKS_UUID:+, LUKS}$( ((USE_LVM)) && echo ', LVM'))"
	info "boot:   $BOOT${ESP:+ (EFI partition on $ESP)}${BIOS_DISK:+ on $BIOS_DISK}"
	info "CPU:    $CPU    GPU: $( ((GPU_INTEL)) && echo 'Intel ')$( ((GPU_AMD)) && echo 'AMD ')${NVIDIA_NAME:+NVIDIA $NVIDIA_NAME ($NVIDIA driver)}"
	info "laptop: $( ((LAPTOP)) && echo yes || echo no)"

	step "Questions (Enter = default)"
	local tz_guess
	tz_guess=$(curl -fsS -m 5 https://ipapi.co/timezone 2>/dev/null || true)
	[[ -f /usr/share/zoneinfo/$tz_guess ]] || tz_guess="Asia/Novosibirsk"

	ask HOST "Hostname" "ICONIA"
	ask USERNAME "User name" "student"
	[[ $USERNAME =~ ^[a-z_][a-z0-9_-]*$ ]] || die "user name: lower case letters, digits, - and _"
	password USER_PASS "$USERNAME"
	yesno SAME_ROOT "Same password for root" Y
	if ((SAME_ROOT)); then ROOT_PASS=$USER_PASS; else password ROOT_PASS root; fi
	ask TIMEZONE "Timezone" "$tz_guess"
	[[ -f /usr/share/zoneinfo/$TIMEZONE ]] || die "unknown timezone $TIMEZONE"
	ask KEYMAP "Console keymap" "ru"

	echo
	yesno WANT_DESKTOP "Sway desktop (waybar, rofi, sound, bluetooth, fonts)" Y
	yesno WANT_APPS "Apps (vlc, gimp, emacs, keepass, thunderbird, kdenlive, printing)" Y
	yesno WANT_DOCKER "Docker" Y
	yesno WANT_DOTFILES "These dotfiles in ~/My_linux_settings (+ makelinks.sh)" Y
	WANT_NVIDIA=0
	[[ $NVIDIA != none ]] && yesno WANT_NVIDIA "NVIDIA driver for $NVIDIA_NAME ($NVIDIA)" Y
	WANT_POWER=0
	((LAPTOP)) && yesno WANT_POWER "Laptop power saving (power profiles, sound card sleep)" Y

	step "Summary"
	info "$HOST, user $USERNAME, $TIMEZONE, keymap $KEYMAP, boot $BOOT"
	info "desktop=$WANT_DESKTOP apps=$WANT_APPS docker=$WANT_DOCKER dotfiles=$WANT_DOTFILES nvidia=$WANT_NVIDIA power=$WANT_POWER"
	yesno GO "Start the installation" Y
	((GO)) || exit 0

	step "fstab"
	if grep -qE '^[^#].*[[:space:]]/[[:space:]]' "$TARGET/etc/fstab" 2>/dev/null; then
		info "already has a root entry, left as it is"
	else
		genfstab -U "$TARGET" >>"$TARGET/etc/fstab"
		info "written"
	fi

	# answers for stage 2 (inside the target, root only)
	umask 077
	{
		for v in HOST USERNAME TIMEZONE KEYMAP BOOT ESP BIOS_DISK ROOT_UUID ROOT_FS ROOT_FLAGS \
			LUKS_UUID LUKS_NAME USE_LVM CPU GPU_INTEL GPU_AMD NVIDIA LAPTOP WANT_DESKTOP WANT_APPS \
			WANT_DOCKER WANT_DOTFILES WANT_NVIDIA WANT_POWER REPO_URL; do
			printf '%s=%q\n' "$v" "${!v:-}"
		done
		printf 'USER_PASS=%q\nROOT_PASS=%q\n' "$USER_PASS" "$ROOT_PASS"
	} >"$TARGET$CONF"
	umask 022
	trap 'rm -f "$TARGET$CONF" "$TARGET/root/install_arch.sh"' EXIT
	install -m 755 "$(readlink -f "$0")" "$TARGET/root/install_arch.sh"

	step "Installing inside the new system (log: $TARGET$LOG)"
	set +e
	arch-chroot "$TARGET" /root/install_arch.sh --chroot 2>&1 | tee -a "$TARGET$LOG"
	local rc=${PIPESTATUS[0]}
	set -e
	rm -f "$TARGET$CONF" "$TARGET/root/install_arch.sh"
	((rc == 0)) || die "installation stopped, see $TARGET$LOG (you can run this script again)"

	printf '\n%sDone.%s Next:\n' "$c_g" "$c_0"
	cat <<EOF
    umount -R $TARGET && reboot
    log in as $USERNAME on tty1: sway starts by itself (zsh)
    Wi-Fi: nmtui
EOF
	((WANT_DOCKER)) && cat <<EOF
    Docker images (once, ~1 h): cd ~/.my_scripts/docker_images && ./update.sh base firefox chromium telegram
      (then ./update.sh --list; the weekly timer keeps them up to date)
    Neovim C++ container: ./update.sh nvim-cpp
EOF
	cat <<EOF
    Local AI (arch-local-ai): unzip the archive, ./install.sh
EOF
}

# ============================================================================
#  Stage 2: inside the new system (arch-chroot)
# ============================================================================
pac() { pacman -S --needed --noconfirm "$@"; }

# install what the repos have, return the rest in MISSING (tried with yay later)
MISSING=()
pac_available() {
	local p have=()
	for p in "$@"; do
		if pacman -Si "$p" >/dev/null 2>&1 || pacman -Sg "$p" >/dev/null 2>&1; then have+=("$p"); else MISSING+=("$p"); fi
	done
	((${#have[@]})) && pac "${have[@]}"
	return 0
}

set_line() { # set_line FILE REGEX LINE: replace the matching line, or append
	if grep -qE "$2" "$1"; then sed -i -E "s|$2.*|$3|" "$1"; else echo "$3" >>"$1"; fi
}

# mkinitcpio HOOKS for LUKS / LVM (systemd or busybox style, whatever the config uses)
fix_hooks() {
	local f=/etc/mkinitcpio.conf hooks systemd=0 add=()
	hooks=$(sed -n -E 's/^HOOKS=\((.*)\)/\1/p' "$f")
	[[ " $hooks " == *" systemd "* ]] && systemd=1
	if [[ -n $LUKS_UUID ]]; then
		if ((systemd)); then add+=(sd-encrypt); else add+=(encrypt); fi
	fi
	((USE_LVM)) && add+=(lvm2)
	# microcode inside the initramfs (the boot entries don't load it separately)
	[[ " $hooks " == *" microcode "* ]] || hooks=$(sed -E 's/\bautodetect\b/autodetect microcode/' <<<"$hooks")
	# NVIDIA: the kms hook would load nouveau early and fight the NVIDIA driver
	[[ $WANT_NVIDIA == 1 ]] && hooks=$(sed -E 's/(^| )kms( |$)/ /' <<<"$hooks" | xargs)
	local h a new=""
	for h in $hooks; do
		if [[ $h == filesystems ]]; then
			for a in "${add[@]}"; do [[ " $hooks " == *" $a "* ]] || new+="$a "; done
		fi
		new+="$h "
	done
	sed -i -E "s/^HOOKS=\(.*\)/HOOKS=(${new% })/" "$f"
	KERNEL_SYSTEMD_HOOKS=$systemd
}

luks_option() {
	[[ -n $LUKS_UUID ]] || return 0
	if ((KERNEL_SYSTEMD_HOOKS)); then
		echo "rd.luks.name=$LUKS_UUID=${LUKS_NAME:-cryptroot}"
	else
		echo "cryptdevice=UUID=$LUKS_UUID:${LUKS_NAME:-cryptroot}"
	fi
}

kernel_options() {
	local o=""
	[[ -n $LUKS_UUID ]] && o+="$(luks_option) "
	if [[ -n $LUKS_UUID || $USE_LVM == 1 ]]; then
		o+="root=$(findmnt -no SOURCE / | sed 's/\[.*\]$//') "
	else
		o+="root=UUID=$ROOT_UUID "
	fi
	o+="rw${ROOT_FLAGS:+ rootflags=$ROOT_FLAGS} quiet"
	echo "$o"
}

install_bootloader() {
	local opts
	opts=$(kernel_options)
	case $BOOT in
	systemd-boot)
		bootctl --esp-path="$ESP" install
		cat >"$ESP/loader/loader.conf" <<EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF
		# microcode is inside the initramfs (mkinitcpio "microcode" hook)
		cat >"$ESP/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options $opts
EOF
		cat >"$ESP/loader/entries/arch-fallback.conf" <<EOF
title   Arch Linux (fallback)
linux   /vmlinuz-linux
initrd  /initramfs-linux-fallback.img
options $opts
EOF
		systemctl enable systemd-boot-update.service
		;;
	grub-efi | grub-bios)
		pac grub
		[[ $BOOT == grub-efi ]] && pac efibootmgr
		set_line /etc/default/grub '^GRUB_CMDLINE_LINUX=' "GRUB_CMDLINE_LINUX=\"$(luks_option)\""
		if [[ -n $LUKS_UUID ]]; then
			# only matters when /boot is on the encrypted root (GRUB can't open LUKS2 argon2)
			set_line /etc/default/grub '^#?GRUB_ENABLE_CRYPTODISK=' 'GRUB_ENABLE_CRYPTODISK=y'
		fi
		if [[ $BOOT == grub-efi ]]; then
			grub-install --target=x86_64-efi --efi-directory="$ESP" --bootloader-id=GRUB
		else
			grub-install --target=i386-pc "$BIOS_DISK"
		fi
		grub-mkconfig -o /boot/grub/grub.cfg
		;;
	esac
}

as_user() { runuser -u "$USERNAME" -- env HOME="/home/$USERNAME" bash -c "$1"; }

stage_chroot() {
	# shellcheck source=/dev/null
	source "$CONF"
	echo "### install_arch.sh $(date '+%F %T')"

	step "pacman: color, parallel downloads, multilib"
	sed -i -E 's/^#Color$/Color/' /etc/pacman.conf
	grep -q '^ILoveCandy' /etc/pacman.conf || sed -i -E 's/^Color$/Color\nILoveCandy/' /etc/pacman.conf
	sed -i -E 's/^#?ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
	if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
		sed -i -E '/^#\[multilib\]/{N;s/^#\[multilib\]\n#Include/[multilib]\nInclude/}' /etc/pacman.conf
	fi
	pacman -Syu --noconfirm

	step "Locale, keymap, timezone, hostname"
	sed -i -E 's/^#(en_US.UTF-8 UTF-8)/\1/; s/^#(ru_RU.UTF-8 UTF-8)/\1/' /etc/locale.gen
	locale-gen >/dev/null
	echo LANG=en_US.UTF-8 >/etc/locale.conf
	pac terminus-font
	printf 'KEYMAP=%s\nFONT=ter-v32n\n' "$KEYMAP" >/etc/vconsole.conf
	ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
	hwclock --systohc 2>/dev/null || true
	echo "$HOST" >/etc/hostname
	grep -q "$HOST" /etc/hosts || cat >>/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOST.localdomain $HOST
EOF

	step "Packages"
	local base=(base-devel linux-headers git sudo networkmanager openssh man-db man-pages
		zsh stow tmux vim neovim htop curl wget unzip zip p7zip rsync bash-completion
		jq go socat aria2 yt-dlp mesa vulkan-icd-loader vulkan-tools)
	[[ $CPU == intel ]] && base+=(intel-ucode)
	[[ $CPU == amd ]] && base+=(amd-ucode)
	((GPU_INTEL)) && base+=(vulkan-intel intel-media-driver)
	((GPU_AMD)) && base+=(vulkan-radeon)
	[[ $ROOT_FS == btrfs ]] && base+=(btrfs-progs)
	((USE_LVM)) && base+=(lvm2)
	[[ $WANT_NVIDIA == 1 && $NVIDIA == open ]] && base+=(nvidia-open-dkms nvidia-utils nvidia-settings)

	local desktop=(sway swaybg swayidle swaylock waybar rofi rofi-emoji rofi-calc mako grim slurp
		wl-clipboard xorg-xwayland xdg-desktop-portal-wlr xdg-desktop-portal-gtk polkit alacritty
		brightnessctl libnotify pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol pamixer
		alsa-utils mpc bluez bluez-utils network-manager-applet
		ttf-hack ttf-hack-nerd noto-fonts noto-fonts-emoji cantarell-fonts)
	local apps=(vlc feh pcmanfm-gtk3 qmmp emacs gimp keepass thunderbird kdenlive
		cups system-config-printer)
	local docker=(docker docker-buildx)
	local power=(power-profiles-daemon powertop)

	local all=("${base[@]}")
	((WANT_DESKTOP)) && all+=("${desktop[@]}")
	((WANT_APPS)) && all+=("${apps[@]}")
	((WANT_DOCKER)) && all+=("${docker[@]}")
	((WANT_POWER)) && all+=("${power[@]}")
	pac_available "${all[@]}"

	step "User $USERNAME"
	local groups=wheel,video,audio,input
	((WANT_DOCKER)) && groups+=,docker
	if id "$USERNAME" >/dev/null 2>&1; then
		usermod -aG "$groups" -s /bin/zsh "$USERNAME"
	else
		useradd -m -G "$groups" -s /bin/zsh "$USERNAME"
	fi
	printf '%s:%s\n' "$USERNAME" "$USER_PASS" | chpasswd
	printf 'root:%s\n' "$ROOT_PASS" | chpasswd
	echo '%wheel ALL=(ALL:ALL) ALL' >/etc/sudoers.d/10-wheel
	chmod 440 /etc/sudoers.d/10-wheel
	# only while installing (yay needs sudo without a terminal); removed at the end
	echo "$USERNAME ALL=(ALL:ALL) NOPASSWD: ALL" >/etc/sudoers.d/99-install-temp
	chmod 440 /etc/sudoers.d/99-install-temp
	trap 'rm -f /etc/sudoers.d/99-install-temp' EXIT

	step "AUR: yay"
	if ! command -v yay >/dev/null; then
		as_user 'set -e; d=$(mktemp -d); git clone -q https://aur.archlinux.org/yay-bin.git "$d/yay-bin"
			cd "$d/yay-bin" && makepkg -si --noconfirm --needed && rm -rf "$d"'
	fi
	local aur=()
	((WANT_DESKTOP)) && aur+=(powerline-fonts-git)
	((WANT_APPS)) && aur+=(brother-hl1118)
	if [[ $WANT_NVIDIA == 1 && $NVIDIA == 580xx ]]; then
		# Pascal / Maxwell (MX350): the 590+ driver doesn't support it any more
		pacman -Rdd --noconfirm nvidia nvidia-open nvidia-dkms nvidia-open-dkms nvidia-utils 2>/dev/null || true
		aur+=(nvidia-580xx-dkms nvidia-580xx-utils)
	fi
	aur+=("${MISSING[@]}")
	local failed=()
	for p in "${aur[@]}"; do
		as_user "yay -S --needed --noconfirm --answerdiff None --answerclean None $p" || failed+=("$p")
	done
	((${#failed[@]})) && warn "not installed (install later with yay): ${failed[*]}"

	if ((WANT_DOTFILES)); then
		step "Dotfiles: ~/My_linux_settings"
		as_user "set -e; cd ~
			[[ -d My_linux_settings/.git ]] || git clone -q --recursive '$REPO_URL' My_linux_settings
			# real folder, so stow links the unit files and enabling them writes here, not into the repo
			mkdir -p ~/.config/systemd/user
			cd My_linux_settings && git submodule update --init --recursive -q
			./makelinks.sh"
		if ((WANT_DESKTOP)); then
			info "keyboard layout per window (sway_independent_layouts)"
			as_user 'make -s -C ~/.my_scripts/.data/binary independent_layout' ||
				warn "layout helper did not build (cd ~/.my_scripts/.data/binary && make independent_layout)"
			mkdir -p "/home/$USERNAME/.wallpapers"
			[[ -f /usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png && ! -e /home/$USERNAME/.wallpapers/wallpaper.png ]] &&
				cp /usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png "/home/$USERNAME/.wallpapers/wallpaper.png"
			chown -R "$USERNAME:" "/home/$USERNAME/.wallpapers"
			((WANT_DOCKER)) && as_user '~/.my_scripts/.data/install_launchers.sh >/dev/null' || true
		fi
		if ((WANT_DOCKER)) && [[ -f /home/$USERNAME/.config/systemd/user/docker-update.timer ]]; then
			info "weekly Docker image updates (docker-update.timer)"
			as_user 'mkdir -p ~/.config/systemd/user/timers.target.wants &&
				ln -sf ../docker-update.timer ~/.config/systemd/user/timers.target.wants/docker-update.timer'
		fi
	fi

	if ((WANT_POWER)); then
		step "Laptop power saving"
		echo "options snd_hda_intel power_save=1" >/etc/modprobe.d/audio_powersave.conf
		echo "vm.dirty_writeback_centisecs = 1500" >/etc/sysctl.d/90-laptop-writeback.conf
	fi

	step "Initramfs and bootloader ($BOOT)"
	fix_hooks
	mkinitcpio -P
	install_bootloader

	step "Services"
	local svc=(NetworkManager systemd-timesyncd fstrim.timer)
	((WANT_DESKTOP)) && svc+=(bluetooth)
	((WANT_DOCKER)) && svc+=(docker)
	((WANT_APPS)) && svc+=(cups)
	((WANT_POWER)) && svc+=(power-profiles-daemon)
	for s in "${svc[@]}"; do
		systemctl enable "$s" 2>/dev/null && info "enabled $s" || warn "could not enable $s"
	done

	rm -f /etc/sudoers.d/99-install-temp
	step "Finished"
}

# ============================================================================
if [[ ${1:-} == --chroot ]]; then
	stage_chroot
else
	stage_live "$@"
fi
