# variables
# Edit these variables or leave them blank to be prompted during setup

# install arch to this drive ex: /dev/sda or /dev/sdb... etc
DRIVE=''

#
HOST_NAME=''

# not required, root account is now disabled in install script
# ROOT_PASSWD=''

# has to be all lowercase
USERNAME=''

# maybe not the best idea to store your password in plain text but the option is there if you want
USER_PASSWD=''

# examples:
# America/New_York
# Canada/Mountain
TIMEZONE=''

# right now, I default to Canadian English locales
# KEYMAP=''

setup(){
	# connect to wifi
	wifi-menu
	
	if [ -z "$DRIVE" ]
        then
       	   echo 'Enter the drive to install Arch to:'
           read DRIVE
        fi
	echo Installing Arch to: $DRIVE

	if [ -z "$HOST_NAME" ]
        then
       	   echo 'Enter your desired hostname:'
           read HOST_NAME
        fi
	echo Hostname: $HOST_NAME

	#if [ -z "$ROOT_PASSWD" ]
        #then
       	#   echo 'Enter the root password:'
        #   read ROOT_PASSWORD
        #fi

	if [ -z "$USERNAME" ]
        then
       	   echo 'Enter your username:'
           read USERNAME
        fi
	echo Username: $USERNAME

	if [ -z "$USER_PASSWD" ]
        then
       	   echo 'Enter your password:'
           read USER_PASSWORD
        fi
	while true
	do
		echo "Confirm your password: "
		read passwdconfirmation
		
		if [ $USER_PASSWD == $passwdconfirmation ]
        	then
       	   		echo Cool
			break
           	
		else
			echo That wasn\'t correct, try again, or press Ctrl+C to exit the script, change your password, and re-run this script
		fi
	done

	if [ -z "$TIMEZONE" ]
        then
       	   echo 'Enter your timezone'
           read TIMEZONE
        fi

	#if [ -z "$KEYMAP" ]
        #then
       	#   echo 'Enter your keymap'
        #   read KEYMAP
        #fi
}

format(){
	read -p "$(tput bold)$(tput setaf 1)WARNING this will wipe $DRIVE Press ENTER to continue, or Ctrl+C to exit$(tput sgr 0)"
	
	wipefs -af $DRIVE

	
	# use fdisk to partition drives
	(
	echo g     # create GPT partition table
	echo n     # create /boot partision
	echo       # accept default partition number 1
	echo       # accept default first sector
	echo +100M # EFI partition is 100M
	echo t     # change partition type to EFI
	echo 1     #
	echo n     # root partition, 32G
	echo       #
	echo       #
	echo +32G  #
	echo n     # SWAP partition, 24G
	echo       #
	echo       #
	echo +24G  #
	echo n     # /home parition, fill rest of disk
	echo       #
	echo       #
	echo       #
	echo p     # show what's going to be done
	echo w     # write changes
	echo q     # quit fdisk	
	) | fdisk $DRIVE

	
	local bootpart="$DRIVE"1
	local rootpart="$DRIVE"2
	local swappart="$DRIVE"3
	local homepart="$DRIVE"4

	# format partitions
	mkfs.fat $bootpart  # /boot
	mkfs.ext4 $rootpart # /
	mkswap $swappart    # SWAP
	swapon $swappart    #
	mkfs.ext4 $homepart # /home

	#mount the partitions
	mount $rootpart /mnt
	mkdir /mnt/boot
	mkdir /mnt/home
	mount $bootpart /mnt/boot
	mount $homepart /mnt/home

	#echo "Do you want to edit the mirrorlist? y/n"
	#read editmirrorlist
	#if [[ "$choice" == [Yy]* ]]
	#then
	#	vim /etc/pacman.d/mirrorlist
	#fi
	
	# this mirror works fast enough for me
	echo 'Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
}


pacstrap(){
	pacman -Sy
	pacstrap -i /mnt base base-devel \
	vim \
	git \
	intel-ucode \
	pacman-contrib \ # for rankmirrors script
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
	rxvt-unicode

	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si
	cd ..
	rm -rf yay

	yay -S firefox-developer-edition \
	ttf-iosevka \     # cool font
	libinput-gestures # touchpad gestures
}

post_pacstrap(){
	
	# so that linux auto mounts /root /boot /home
	genfstab -U /mnt >> /mnt/etc/fstab 
	
	# post install config
	arch-chroot /mnt

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
	
	# systemd
	echo Setting up systemd...
	cat > boot/loader/loader.conf << EOF
default arch
timeout 1
editor no
auto-entries 0
EOF

	diskuuid=$(blkid -s PARTUUID -o value "$DRIVE"2)
	cat > boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=PARTUUID=$diskuuid rw
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

	# rank mirrors
	echo Ranking mirrors.. This will take a while
	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bakup
	curl https://www.archlinux.org/mirrorlist/all/https/ | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 6 - > /etc/pacman.d/mirrorlist


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
	
	echo Installing vim plugins...
	vim +PlugInstall +qall

	# .xinitrc
	curl -Lo $HOMEDIR/.xinitrc --create-dirs https://raw.githubusercontent.com/Arunscape/arch-install-config/master/configs/home/.xinitrc

}

finish(){
	# exit and reboot
	exit
	echo "$(tput bold)$(tput setaf 2)Done!!!$(tput sgr 0)"
	reboot
}

setup
format
pacstrap
post_pacstrap
copy_configs
finish # apparently done is a reserved word
