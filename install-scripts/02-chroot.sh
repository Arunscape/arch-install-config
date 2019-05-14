
#variables passed in
USERNAME=$1
USER_PASSWD=$2
HOST_NAME=$3
TIMEZONE=$4
DRIVE=$5

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

	cat > boot/loader/entries/arch-lts.conf << EOF
title   Arch Linux LTS Kernel
linux   /vmlinuz-linux-lts
initrd  /intel-ucode.img
initrd  /initramfs-linux-lts.img
options root=PARTUUID=$diskuuid rw
EOF

	bootctl install

# hook to run bootctl update whenever systemd is updated
	mkdir -p /etc/pacman.d/hooks
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
	sed -i "s/^#Color/Color/" /etc/pacman.conf
	sed -i "/^Color/a ILoveCandy" /etc/pacman.conf

}

install_stuff(){

	# rank mirrors
	#pacman -S --noconfirm pacman-contrib
	#echo 'Ranking mirrors.. This will take a while...'
	#cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bakup
	#curl https://www.archlinux.org/mirrorlist/all/https/ | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 6 - > /etc/pacman.d/mirrorlist

	# install things
	echo Installing stuff...
		pacman -S --noconfirm --needed\
		vim \
		git \
		intel-ucode \
		linux-headers \
		linux-lts \
		ntfs-3g \
		kitty \
		connman \
		wpa_supplicant \
		pulseaudio \
		gnome-keyring \
		libsecret \
		wl-clipboard \
		slurp \
		grim \
		noto-fonts-emoji \
		# firefox-developer-edition

		echo Installing sway and wlroots because somehow the order matters
		pacman -S --noconfirm --needed wlroots
		pacman -S --noconfirm --needed sway


		systemctl enable connman

		echo Installing yay...
		git clone https://aur.archlinux.org/yay.git
		chmod 777 -R yay
		cd yay
		sudo -u $USERNAME makepkg --noconfirm -si
		cd ..
		rm -rf yay

		echo Installing stuff from AUR...
		sudo -u $USERNAME yay -S --noconfirm --needed \
		libinput-gestures \
		brillo \
		otf-nerd-fonts-fira-code
		# flat-remix-git \
		# universal-ctags-git \
		
		gpasswd -a $USERNAME input
		sudo -u $USERNAME libinput-gestures-setup autostart
		sudo -u $USERNAME libinput-gestures-setup start

		sudo -u $USERNAME git config --global credential.helper /usr/lib/git-core/git-credential-libsecret
}

postinstall(){
	echo TODO
}


setup
install_stuff
#exit
