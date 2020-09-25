#!/bin/sh

echo 'WARNING: YOU ARE RUNNING TABS (Tarwin_s Auto Bootstraping Script)
Make sure you are running this as root
Makes sure you have connected to internet'

create_user () {
	echo "User name must be lower case and no space"
	read -rp 'Enter you user name: ' user_name
	user_name=$(echo "$user_name" | tr 'A-Z' 'a-z') # Changes user name to lowercase
	useradd -mG wheel "$user_name" -s /bin/bash
}

create_passwd () {
	read -rp "Enter password for ${user_name}: " user_password
	echo "${user_name}:${user_password}" | chpasswd
	sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

}

pacman_install () {
	pacman --needed --noconfirm -S \
		alsa-utils bspwm dash stow dmenu dunst git htop \
		libnotify libva-utils linux-firmware man-db mlocate mpv neofetch \
		neovim networkmanager newsboat noto-fonts noto-fonts-emoji  \
		rtorrent sxhkd ttf-inconsolata ttf-inconsolata ttf-joypixels \
		ttf-linux-libertine unclutter wget xclip xorg-server pacman-contrib \
		xorg-xev xorg-xinit xorg-xprop xorg-xrandr xwallpaper python-pip \
		youtube-dl zathura zathura-pdf-poppler pandoc base-devel ffmpeg \
		gnome-keyring firefox go texlive-core pulseaudio imagemagick poppler \
		unzip unrar ntfs-3g xcompmgr gzip bzip2 p7zip adwaita-icon-theme

}

systemctl_enable () {
	# rtorrent service file
	cat << END > /etc/systemd/system/rtorrent@.service
[Unit]
Description=rTorrent for %I
After=network.target

[Service]
Type=simple
User=%I
Group=%I
WorkingDirectory=/home/%I
ExecStartPre=-/bin/rm -f /home/%I/.config/rtorrent/session/rtorrent.lock
ExecStart=/usr/bin/rtorrent -o system.daemon.set=true
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
END

	systemctl enable fstrim.timer
	systemctl enable NetworkManager
	systemctl enable rtorrent@"$user_name"

}

microcode_install () {
	cpu_vendor=$(lscpu | grep Vendor | awk -F ': +' '{print $2}')
	[ "$cpu_vendor" = "GenuineIntel" ] && pacman --needed --noconfirm -S intel-ucode && \
		grub-mkconfig -o /boot/grub/grub.cfg
	[ "$cpu_vendor" = "AuthenticAMD" ] && pacman --needed --noconfirm -S amd-ucode && \
		grub-mkconfig -o /boot/grub/grub.cfg
}

ssd_fstrim () {
	check_ssd=$(($(cat /sys/block/sd*/queue/rotational | paste -sd '+')))
	[ $check_ssd -gt 0 ] && systemctl enable fstrim.timer
}

arch_mirror () {
	pacman --needed -S --noconfirm  reflector
	reflector --verbose --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
}

gpu_driver () {
	read -rp "What gpu are you using A-(INTEL) B-(AMD) C-(ATI) [A/B/C] : " gpu
	gpu=$(echo "$gpu" | tr A-Z a-z)
	if [ "$gpu" = "a" ]; then
		pacman -S xf86-video-intel
	elif [ "$gpu" = "b" ]; then
		pacman -S xf86-video-amdgpu
	elif [ "$gpu" = "c" ]; then
		pacman -S xf86-video-ati
	fi

}

user_setup () {
	su - "$user_name" -c '
	# Install Yay
	cd "$HOME"
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg
	ls | grep .*zst | pacman --noconfirm -U -
	cd "$HOME"
	rm -rf yay

	# install aur pkg
	yay  --noconfirm -Sy libxft-bgra polybar slock-gruvbox-lowcontrast st-luke-git nordic-theme-git lf

	# setup dot files
	cd "$HOME"
	mkdir Repos
	cd Repos
	git clone https://github.com/tarwin1/.files.git
	cd .files
	stow --adopt --dotfiles -t ~ *
	cd "$HOME"

	# setup user home directories
	cd "$HOME"
	mkdir Media Documents Downloads
	cd "$HOME"

	# chmod everything in .local/bin
	cd "$HOME"
	cd .local/bin
	chmod +x *'
}

system_optimization () {
	[ ! -d /etc/sysctl.d ] && mkdir /etc/sysctl.d
	echo 'vm.swappiness = 10
	vm.vfs_cache_pressure = 50
	vm.watermark_scale_factor = 200
	vm.dirty_ratio = 3' >/etc/sysctl.d/99-sysctl.conf
	# Use all cores for compilation
	sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
}

main () {
	read -rp "Proceed? [Y/n] " -n 1 continue
	continue=$(echo "$continue" | tr A-Z a-z)
	[ "$continue" = n ] && exit
	# Call all function
	timedatectl set-ntp true # sets date and time correctly
	echo 'Updating...'
	pacman --noconfirm --needed -Syyuu > log 2>&1
	echo "Updating mirrors..."
	arch_mirror >> log 2>&1
	echo "Creating User..."
	create_user
	create_passwd
	echo "Installing microcode"
	microcode_install >> log 2>&1
	echo "Checkig for ssd..."
	ssd_fstrim >> log 2>&1
	echo "Installing GPU driver"
	gpu_driver
	echo "Installing packages..."
	pacman_install >> log 2>&1
	echo "Enabling services..."
	systemctl_enable >> log 2>&1
	echo "Setting up user..."
	user_setup >> log 2>&1
	echo "Check the log file for more information"
}

main
