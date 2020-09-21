#!/bin/sh
# shellcheck disable=SC2034

echo "WARNING: YOU ARE RUNNING TARWIN's {BOO}tstraping script Make sure you are running this as root\nMakes sure you have connected to internet"

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
	useradd -m -g wheel "$user_name"
	read -p "Enter password for $user_name :" user_password
	echo "$user_password" | passwd --stdin "$user_name"
}

user_nopass () {
	echo "$user_name ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
}

install_packages () {
	pacman -S --needed
}

install_yay () {
	cd $HOME
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si
}

systemctl_enable () {
	systemctl enable fstrim.timer
	systemctl enable NetworkManager
}
