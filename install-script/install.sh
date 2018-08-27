# reminder of variables
#DRIVE
#HOST_NAME
#ROOT_PASSWD
#USERNAME
USER_PASSWD
#TIMEZONE='Canada/Mountain'
#KEYMAP


# load variables
. variables

setup(){
	# connect to wifi
	wifi-menu
	
	if [ -z "$DRIVE" ]
        then
       	   echo 'Enter the root password:'
           read DRIVE
        fi

	if [ -z "$HOST_NAME" ]
        then
       	   echo 'Enter the root password:'
           read HOST_NAME
        fi

	if [ -z "$ROOT_PASSWD" ]
        then
       	   echo 'Enter the root password:'
           read ROOT_PASSWORD
        fi

	if [ -z "$USERNAME" ]
        then
       	   echo 'Enter the root password:'
           read USERNAME
        fi

	if [ -z "$USER_PASSWD" ]
        then
       	   echo 'Enter the root password:'
           read USER_PASSWORD
        fi

	if [ -z "$TIMEZONE" ]
        then
       	   echo 'Enter the root password:'
           read TIMEZONE
        fi

	if [ -z "$KEYMAP" ]
        then
       	   echo 'Enter the root password:'
           read KEYMAP
        fi
}

format(){
	read -p "$(tput bold)$(tput setaf 1)WARNING this will wipe $DRIVE Press ENTER to continue, or Ctrl+C to exit$(tput sgr 0)"
	
	wipefs -a $DRIVE

	
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
	swapon $sqappart    #
	mkfs.ext4 $homepart # /home

	#mount the partitions
	mount $rootpart /mnt
	mkdir /mnt/home
	mount $bootpart /mnt/boot
	mount $homepart /mnt/home

	echo "Do you want to edit the mirrorlist? y/n"
	read editmirrorlist
	if [[ "$choice" == [Yy]* ]]
	then
		vim /etc/pacman.d/mirrorlist
	fi

}


pacstrap(){
	pacman -Syyu
	pacstrap -i /mnt base base-devel vim git intel-ucode pacman-contrib
	
	genfstab -U /mnt >> /mnt/etc/fstab # so that linux auto mounts /root /boot /home

}

post_pacstrap(){
	arch-chroot /mnt

	# Timezone
	ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

	# Run hwclock(8) to generate /etc/adjtime:
	hwclock --systohc

	# Hostname
	echo $HOST_NAME > /etc/hostname

	# Set root passwwd
	(
	echo $ROOT_PASSWD
	echo $ROOT_PASSWD
	) | passwd

	# Localization
	echo Uncommenting these lines in /etc/locale.gen:
	cat /etc/locale.gen | grep en_CA
	sed -i '/en_CA/ s/^#//' /etc/locale.gen

	echo LANG=en_US.UTF-8 > /etc/locale.conf
	
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

	diskuuid=$(blkid -s PARTUUID -o value /dev/sda2)
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

	# rank mirrors
	echo Ranking mirrors.. This will take a while
	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bakup
	curl https://www.archlinux.org/mirrorlist/all/https/ | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 6 - > /etc/pacman.d/mirrorlist

}

setup
format
pacstrap
post_pacstrap
