
#variables passed in
USERNAME=$1
USER_PASSWD=$2
HOSTNAME=$3
TIMEZONE=$4

setup(){

	# Timezone
	ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

	# Run hwclock(8) to generate /etc/adjtime:
	hwclock --systohc

	# Hostname
	echo $HOST_NAME > /etc/hostname

	# Set root passwwd
	#(
	#echo $ROOT_PASSWD
	#echo $ROOT_PASSWD
	#) | passwd

	# Localization
	echo Uncommenting these lines in /etc/locale.gen:
	cat /etc/locale.gen | grep en_CA
	sed -i '/en_CA/ s/^#//' /etc/locale.gen

	echo LANG=en_CA.UTF-8 > /etc/locale.conf

	echo Generating locale...
	locale-gen

	# making directories if necessary
	mkdir -p boot/loader/entries/

	# systemd
	echo Setting up systemd-boot...
	bootctl install

	cat > boot/loader/loader.conf << EOF
default arch
timeout 1
editor no
auto-entries 0
EOF

	local rootpart="$DRIVE"2
	diskuuid=$(blkid -s PARTUUID -o value $rootpart)
	cat > boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=PARTUUID=$diskuuid rw
EOF

# hook to run bootctl update whenever systemd is updated
	cat > /etc/pacman.d/hooks/systemd-boot.hook << EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update
EOF

	# add user
	echo Creating user $USERNAME
	useradd -m -g wheel $USERNAME
	(
	echo $USER_PASSWD
	echo $USER_PASSWD
	) | passwd $USERNAME

	# edit sudoers file to allow wheel users to run sudo commands
	sed -i '/%wheel ALL=(ALL) ALL/ s/^# //' /etc/sudoers
	echo Here\'s what got uncommented:
	cat /etc/sudoers | grep wheel

	# Disable root account
	usermod -p '!' root

	# makes pacman and yay colourful
	sed -i "s/#Color^/Color/g" /etc/pacman.conf

}

install_stuff(){

	# rank mirrors
	pacman -S --noconfirm pacman-contrib
	echo 'Ranking mirrors.. This will take a while...'
	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bakup
	curl https://www.archlinux.org/mirrorlist/all/https/ | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 6 - > /etc/pacman.d/mirrorlist

	# install things
	echo Installing stuff...
		pacman -S --noconfirm \
		vim \
		git \
		intel-ucode \
		xorg-server \
		xorg-xinit \
		nvidia \
		bbswitch \
		linux-headers \
		xf86-input-libinput \
		networkmanager \
		network-manager-applet \
		i3-gaps \
		i3status \
		rxvt-unicode \
		texlive-most \
		vlc

		systemctl enable NetworkManager

		echo Installing yay...
		git clone https://aur.archlinux.org/yay.git
		cd yay
		sudo -u $USERNAME makepkg --noconfirm -si
		cd ..
		rm -rf yay

		echo Installing stuff from AUR...
		sudo -u $USERNAME yay -S --noconfirm \
		firefox-developer-edition \
		ttf-iosevka \     # cool font
		libinput-gestures # touchpad gestures
}

copy_configs(){

	echo Copying configs...

	local HOMEDIR = /home/$USERNAME

	# i3 config
	curl -Lo $HOMEDIR/.config/i3/config --create-dirs https://raw.githubusercontent.com/Arunscape/arch-install-config/master/configs/home/.config/i3/config

	# libinput gestures
	curl -Lo $HOMEDIR/.config/libinput-gestures.conf --create-dirs https://raw.githubusercontent.com/Arunscape/arch-install-config/master/configs/home/.config/libinput-gestures.conf

	# .Xresources
	curl -Lo $HOMEDIR/.Xresources --create-dirs https://raw.githubusercontent.com/Arunscape/arch-install-config/master/configs/home/.Xresources

	# .vimrc
	curl -Lo $HOMEDIR/.vimrc --create-dirs https://raw.githubusercontent.com/Arunscape/arch-install-config/master/configs/home/.vimrc

	# vim-plug
	# just realized I have a section in .vimrc which sets this up if it's missing
	#curl -Lo $HOMEDIR/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

	# doesn't work as nicely, should also be run as user postinstall I think
	# echo Installing vim plugins...
	# vim +PlugInstall +qall

	# .xinitrc
	curl -Lo $HOMEDIR/.xinitrc --create-dirs https://raw.githubusercontent.com/Arunscape/arch-install-config/master/configs/home/.xinitrc

}

postinstall(){
	echo TODO
}


setup
install_stuff
copy_configs
exit
