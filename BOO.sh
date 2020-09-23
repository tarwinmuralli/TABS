#!/bin/sh

echo "WARNING: YOU ARE RUNNING TARWIN's {BOO}tstraping script Make sure you are running this as root\nMakes sure you have connected to internet\nFor better performance install dash and setup it up"

update () {
	echo 'Updating...'
	pacman -Syyuu -y
	echo 'Cleaning cache'
	pacman -Scc -y

}

create_user () {
	echo "Creating User\nUser name must be lower case and no space"
	read -rp 'Enter you user name: ' user_name
	user_name=$(echo "$user_name" | tr 'A-Z' 'a-z') # Changes user name to lowercase
	useradd -mG wheel "$user_name"
	}

create_passwd () {
	read -rp "Enter password for $user_name :" user_password
	echo "$user_password" | passwd --stdin "$user_name"
	sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

}

install_packages () {
	sudo pacman ---needed -S \
		alsa-utils bspwm dash stow dmenu dunst git htop iwd lf \
		libnotify libva-utils linux-firmware man-db mlocate mpv neofetch \
		neovim networkmanager newsboat noto-fonts noto-fonts-emoji picom \
		rtorrent sxhkd ttf-inconsolata ttf-inconsolata ttf-joypixels \
		ttf-linux-libertine ttf-symbola uclutter wget xclip xorg-server \
		xorg-xev xorg-xinit xorg-xprop xorg-xrandr xwallpaper \
		youtube-dl zathura zathura-pdf-poppler pandoc base-devel -y

	yay -S networkmanager-iwd libxft-bgra polybar slock-gruvbox-lowcontrast \
		st-luke-git
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
	if [ "$cpu_vendor" = "GenuineIntel" ]; then
		pacman -S intel-ucode -y
	else
		pacman -S amd-ucode -y
	fi
# grub-mkconfig -o /boot/grub/grub.cfg
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
	pacman -S reflector -y
	reflector --verbose --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
cat << END > /etc/pacman.d/hooks/mirrorupgrade.hook
[Trigger]
Operation = Upgrade
Type = Package
Target = pacman-mirrorlist

[Action]
Description = Updating pacman-mirrorlist with reflector and removing pacnew...
When = PostTransaction
Depends = reflector
Exec = /bin/sh -c 'systemctl start reflector.service; if [ -f /etc/pacman.d/mirrorlist.pacnew ]; then rm /etc/pacman.d/mirrorlist.pacnew; fi'
EOF
[Trigger]
Operation = Upgrade
Type = Package
Target = pacman-mirrorlist

[Action]
Description = Updating pacman-mirrorlist with reflector and removing pacnew...
When = PostTransaction
Depends = reflector
Exec = /bin/sh -c 'systemctl start reflector.service; if [ -f /etc/pacman.d/mirrorlist.pacnew ]; then rm /etc/pacman.d/mirrorlist.pacnew; fi'
END
}

gpu_driver () {
	read -rp "What gpu are you using A-(AMD) B-(INTEL) C-(ATI) [A/B/C] : " gpu
	if [ "$gpu" = "A" ]; then
		pacman -S xf86-video-intel -y
	elif [ "$gpu" = "B" ]; then
		pacman -S xf86-video-amdgpu -y
	elif [ "$gpu" = "C" ]; then
		pacman -S xf86-video-ati -y
	else
		echo "Invalid Answer"
		gpu_driver
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
su $user_name
install_yay
install_packages
setup_dotfiles
systemctl_enable
