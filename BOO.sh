#!/bin/sh

echo "WARNING: YOU ARE RUNNING TARWIN's {BOO}tstraping script Make sure you are running this as root"
echo "For better performance install dash and setup it up"
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
	useradd -mG wheel "$user_name"
	}

create_passwd () {
	read -rp "Enter password for $user_name :" user_password
	echo "${user_name}:${user_password}" | chpasswd
	sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

}

install_packages () {
	sudo pacman --needed --noconfirm -S \
		alsa-utils bspwm dash stow dmenu dunst git htop iwd lf \
		libnotify libva-utils linux-firmware man-db mlocate mpv neofetch \
		neovim networkmanager newsboat noto-fonts noto-fonts-emoji picom \
		rtorrent sxhkd ttf-inconsolata ttf-inconsolata ttf-joypixels \
		ttf-linux-libertine ttf-symbola uclutter wget xclip xorg-server \
		xorg-xev xorg-xinit xorg-xprop xorg-xrandr xwallpaper \
		youtube-dl zathura zathura-pdf-poppler pandoc base-devel ffmpeg

	yay  --noconfirm -S networkmanager-iwd libxft-bgra polybar \
		slock-gruvbox-lowcontrast st-luke-git
}

install_yay () {
	cd "$HOME"
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si
	cd "$HOME"
	rm -rf yay
}

systemctl_enable () {
	sudo systemctl enable fstrim.timer
	sudo systemctl enable NetworkManager
	sudo systemctl enable iwd
}

microcode_install () {
	echo "Installing microcode"
	cpu_vendor=$(lscpu | grep Vendor | awk -F ': +' '{print $2}')
	[ "$cpu_vendor" = "GenuineIntel" ] && pacman -S intel-ucode
}

ssd_fstrim () {
	read -rp "Are you using SSD [Y/n]" check_ssd
	if [ "${check_ssd}" = "Y" ] || [ "${check_ssd}" = "y" ] || \
		[ -z "${check_ssd}" ]; then
		systemctl enable fstrim.timer
	fi
}

arch_mirror () {
	echo "Updating mirrors"
	mkdir /etc/pacman.d/hooks
	pacman --noconfirm --needed -S  reflector
	reflector --verbose --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
}

gpu_driver () {
	read -rp "What gpu are you using A-(AMD) B-(INTEL) C-(ATI) [A/B/C] : " gpu
	if [ "$gpu" = "A" ]; then
		pacman -S xf86-video-intel
	elif [ "$gpu" = "B" ]; then
		pacman -S xf86-video-amdgpu
	elif [ "$gpu" = "C" ]; then
		pacman -S xf86-video-ati
	fi

}

setup_dotfiles () {
	git clone https://github.com/tarwin1/.files.git
	cd '.files'
	stow -adopt *
}

# Call all function
timedatectl set-ntp true # sets date and time correctly
update
arch_mirror
create_user
create_passwd
microcode_install
ssd_fstrim
gpu_driver
runuser -l $user_name -c 'install_yay install_packages setup_dotfiles systemctl_enable \
	grub-mkconfig -o /boot/grub/grub.cfg'
