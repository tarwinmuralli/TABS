#!/bin/sh
set -e

main () {
	# check for root if not exit
	[ "$(id -u)" != "0" ] && \
		{ echo "Make sure you are running this as root"; exit; }

	echo "WARNING: YOU ARE RUNNING TABS (Tarwin's Auto Bootstraping Script)
	Makes sure you have connected to internet"
	read -rp "Proceed? [Y/n] " -n 1 continue
	continue=$(echo "$continue" | tr A-Z a-z)
	[ "$continue" = n ] && exit

	timedatectl set-ntp true # sets date and time correctly
	# Call all function

	echo "Updating mirrors..."
	arch_mirror > log 2>&1
	echo 'Updating...'
	pacman --noconfirm --needed -Syu >> log 2>&1
	echo "Creating User..."
	create_user
	create_passwd
	echo "Installing GPU driver"
	gpu_driver
	echo "Installing microcode"
	microcode_install >> log 2>&1
	echo "Checkig for ssd..."
	ssd_fstrim >> log 2>&1
	echo "Optimizing System..."
	system_optimization >> log 2>&1
	echo "Installing packages..."
	pacman --needed --noconfirm -S - < pkg.txt >> log 2>&1
	echo "Enabling services..."
	systemctl_enable >> log 2>&1
	echo "Creating user directories..."
	user_directory >> log 2>&1
	echo "Installing yay..."
	install_yay >> log 2>&1
	echo "Installing aur packages..."
	install_aur_pkg >> log 2>&1
	echo "Setting up dot files..."
	setup_dotfiles >> log 2>&1
	echo "Check the log file for more information"
}

create_user () {
	echo "User name must be lower case and no space"
	read -rp 'Enter user name: ' user_name
	user_name=$(echo "$user_name" | tr 'A-Z' 'a-z') # Changes user name to lowercase
	useradd -mG wheel "$user_name" -s /bin/bash
}

create_passwd () {
	read -rp "Enter password for ${user_name}: " user_password
	echo "${user_name}:${user_password}" | chpasswd
	sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

}

systemctl_enable () {
	# rtorrent service file
	cp rtorrent@.service /etc/systemd/system/rtorrent@.service
	systemctl enable NetworkManager
	systemctl enable rtorrent@"$user_name"
}

microcode_install () {
	cpu_vendor=$(lscpu | grep Vendor | awk -F ': +' '{print $2}')
	[ "$cpu_vendor" = "GenuineIntel" ] && pacman --needed --noconfirm -S intel-ucode
	[ "$cpu_vendor" = "AuthenticAMD" ] && pacman --needed --noconfirm -S amd-ucode
	grub-mkconfig -o /boot/grub/grub.cfg

}

ssd_fstrim () {
	check_ssd=$(cat /sys/block/sd*/queue/rotational | paste -sd '+')
	check_ssd=$((check_ssd))
	[ $check_ssd -gt 0 ] && systemctl enable fstrim.timer
}

arch_mirror () {
	pacman --needed -S --noconfirm  reflector
	reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
}

gpu_driver () {
	read -rp "What gpu are you using A-(INTEL) B-(AMD) C-(ATI) [A/B/C] : " -n 1 gpu
	gpu=$(echo "$gpu" | tr A-Z a-z)
	if [ "$gpu" = "a" ]; then
		pacman -S xf86-video-intel
	elif [ "$gpu" = "b" ]; then
		pacman -S xf86-video-amdgpu
	elif [ "$gpu" = "c" ]; then
		pacman -S xf86-video-ati
	fi

}

user_directory () {
	su - "$user_name" -c '
	cd "$HOME"
	mkdir -v dox dl pix vids
	mkdir -v -p "$HOME"/.local/src'
}

install_yay () {
	su - "$user_name" -c '
	cd "$HOME"/.local/src
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg --noconfirm -si'
}

install_aur_pkg () {
	cd "$HOME"
	cp aur_pkg.txt /home/"$user_name"
	su - "$user_name" -c '
	yay  --noconfirm -S - < aur_pkg.txt
	rm -rf aur_pkg.txt'
}

setup_dotfiles () {
	su - "$user_name" -c '
	cd "$HOME"
	cd "$HOME"/.local/src
	git clone https://github.com/tarwin1/.files.git
	cd .files
	stow --adopt -t ~ *
	# chmod everything in .local/bin
	cd "$HOME"/.local/bin
	chmod +x *'

}

system_optimization () {
	[ ! -d /etc/sysctl.d ] && mkdir -v /etc/sysctl.d
	cp 99-sysctl.conf /etc/sysctl.d/99-sysctl.conf
	# Use all cores for compilation
	sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
}

main
