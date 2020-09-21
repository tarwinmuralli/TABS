#!/bin/sh

echo "WARNING: YOU ARE RUNNING TARWIN's {BOO}tstraping script Make sure you are running this as root\nMakes sure you have connected to internet"

main () {
	timedatectl set-ntp true
}

update () {
	echo 'Updating...'
	pacman -Syyuu
	echo 'Cleaning cache'
	pacman -Scc

}

create_user () {
	echo 'Creating User'
	echo 'User name must be lower case and no space'
	read -p 'Enter you user name: ' user_name
	user_name=$(echo "$user_name" | tr 'A-Z' 'a-z') # Changes user name to lowercase
	useradd -mg wheel "$user_name"
	read -p "Enter password for $user_name :" user_password
	echo "$user_password" | passwd --stdin "$user_name"
}

user_nopass () {
	echo "$user_name ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
}

install_packages () {
	pacman -S --needed
	pacman -S reflector
}

install_yay () {
	cd "$HOME"
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si
}

systemctl_enable () {
	systemctl enable fstrim.timer
	systemctl enable NetworkManager
}

microcode_install () {
	cpu_vendor=$(lscpu | grep Vendor | awk -F ': +' '{print $2}')
	if [ "$cpu_vendor" = "GenuineIntel" ]; then
		pacman -S intel-ucode
	else
		pacman -S amd-ucode
	fi
# grub-mkconfig -o /boot/grub/grub.cfg
}

ssd_fstrim () {
	read -p "Are you using SSD [Y/n]" check_ssd
	if [ "${check_ssd}" = "Y" ] || [ -z "${check_ssd}" ]; then
		systemctl enable fstrim.timer
	fi
}

arch_mirror () {
	reflector --verbose --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
cat << END
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

}
