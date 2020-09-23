#!/bin/sh

echo "WARNING: YOU ARE RUNNING TABS (Tarwin's Auto Bootstraping Script)"
echo "Make sure you are running this as root"
echo "Makes sure you have connected to internet"

update () {
	echo 'Updating...'
	pacman --noconfirm --needed -Syyuu

}

create_user () {
	echo "Creating User..."
	echo "User name must be lower case and no space"
	read -rp 'Enter you user name: ' user_name
	user_name=$(echo "$user_name" | tr 'A-Z' 'a-z') # Changes user name to lowercase
	useradd -mG wheel "$user_name" -s /bin/bash
	}

create_passwd () {
	read -rp "Enter password for $user_name :" user_password
	echo "${user_name}:${user_password}" | chpasswd
	sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

}

pacman_install () {
	sudo pacman --needed --noconfirm -S \
		alsa-utils bspwm dash stow dmenu dunst git htop \
		libnotify libva-utils linux-firmware man-db mlocate mpv neofetch \
		neovim networkmanager newsboat noto-fonts noto-fonts-emoji picom \
		rtorrent sxhkd ttf-inconsolata ttf-inconsolata ttf-joypixels \
		ttf-linux-libertine unclutter wget xclip xorg-server \
		xorg-xev xorg-xinit xorg-xprop xorg-xrandr xwallpaper python-pip \
		youtube-dl zathura zathura-pdf-poppler pandoc base-devel ffmpeg \
		gnome-keyring firefox

}

systemctl_enable () {
	sudo systemctl enable fstrim.timer
	sudo systemctl enable NetworkManager
}

microcode_install () {
	echo "Installing microcode"
	cpu_vendor=$(lscpu | grep Vendor | awk -F ': +' '{print $2}')
	[ "$cpu_vendor" = "GenuineIntel" ] && pacman --needed --noconfirm -S intel-ucode && grub-mkconfig -o /boot/grub/grub.cfg
	[ "$cpu_vendor" = "AuthenticAMD" ] && pacman --needed --noconfirm -S amd-ucode && grub-mkconfig -o /boot/grub/grub.cfg
}

ssd_fstrim () {
	read -rp "Are you using SSD [Y/n]" check_ssd
	check_ssd=$( echo $check_ssd | tr A-Z a-z)
	if [ "${check_ssd}" = "y" ] || [ -z "${check_ssd}" ]; then
		systemctl enable fstrim.timer
	fi
}

arch_mirror () {
	echo "Updating mirrors"
	mkdir /etc/pacman.d/hooks
	pacman --needed -S --noconfirm  reflector
	reflector --verbose --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
}

gpu_driver () {
	read -rp "What gpu are you using A-(AMD) B-(INTEL) C-(ATI) [A/B/C] : " gpu
	gpu=$(echo $gpu | tr A-Z a-z)
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
	makepkg -si
	cd "$HOME"
	rm -rf yay
	# install aur pkg
	yay  --noconfirm -Sy libxft-bgra polybar slock-gruvbox-lowcontrast st-luke-git
	# setup dot files
	cd "$HOME"
	git clone https://github.com/tarwin1/.files.git
	cd .files
	stow --adopt *'
}

main () {
	read -rp "Proceed? [Y/n] " -n 1 continue
	continue=$(echo "$continue" | tr A-Z a-z)
	[ "$continue" = n ] && exit 0
	# Call all function
	timedatectl set-ntp true # sets date and time correctly
	update # full upgrade
	arch_mirror # set mirror to the faster
	create_user
	create_passwd
	microcode_install
	ssd_fstrim
	gpu_driver
	pacman_install
	systemctl_enable
	# Use all cores for compilation
	sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
	user_setup
}
