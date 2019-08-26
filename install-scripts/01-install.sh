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

# amd or intel
CPU=''

# Partition sizes
BOOTSIZE=100M
ROOTSIZE=30G
SWAPSIZE=24G

WIFI=''


# right now, I default to Canadian English locales
# KEYMAP=''

setup(){
    
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
        read USER_PASSWD
    fi
    while true
    do
        echo "Confirm your password: "
        read passwdconfirmation
        
        if [ "$USER_PASSWD" == "$passwdconfirmation" ]
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
    echo Timezone: $TIMEZONE
    
    #if [ -z "$KEYMAP" ]
    #then
    #   echo 'Enter your keymap'
    #   read KEYMAP
    #fi
    
    if [ -z "$CPU" ]
    then
        while true
        do
            echo "type amd or intel (all lowercase, exactly as you see on the left) "
            read passwdconfirmation
            
            if [ "$CPU" == "amd" ] || [ "$CPU" == "intel"]
            then
                echo Installing for $CPU...
                break
                
            else
                echo Type either amd or intel exactly
            fi
        done
        
    fi
    if [ -z "$WIFI" ]
    then
        echo 'Do you need wifi? If not, just hit enter. If you do, type anything then hit enter'
        read WIFI
    fi
}

format(){
    read -p "$(tput bold)$(tput setaf 1)WARNING this will wipe $DRIVE Press ENTER to continue, or Ctrl+C to exit$(tput sgr 0)"
    
    # for some reason, fdisk still detects filesystem signatures
    # wipefs -af $DRIVE
    
    # for ssd
    blkdiscard $DRIVE
    
    # use fdisk to partition drives
    (
        echo g           # create GPT partition table
        echo n           # create /boot partision
        echo             # accept default partition number 1
        echo             # accept default first sector
        echo +$BOOTSIZE  # EFI partition is 100M
        echo t           # change partition type to EFI
        echo 1           #
        echo n           # root partition, 32G
        echo             #
        echo             #
        echo +$ROOTSIZE   #
        echo n           # SWAP partition, 24G
        echo             #
        echo             #
        echo +$SWAPSIZE  #
        echo n           # /home parition, fill rest of disk
        echo             #
        echo             #
        echo             #
        echo p           # show what's going to be done
        echo w           # write changes
        echo q           # quit fdisk
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
    # echo 'Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
    # turns out that this is the default mirror anyways
}


run_pacstrap(){
    pacman -Syy
    pacstrap /mnt base base-devel
}

chroot_step(){
    
    # so that linux auto mounts /root /boot /home
    genfstab -U /mnt >> /mnt/etc/fstab
    curl -Lo /mnt/install.sh https://raw.githubusercontent.com/Arunscape/arch-install-config/master/install-scripts/02-chroot.sh
    chmod +x /mnt/install.sh
    arch-chroot /mnt bash install.sh $USERNAME $USER_PASSWD $HOST_NAME $TIMEZONE $DRIVE $CPU $WIFI
}

# copy_configs(){

# echo Copying configs...

# local HOMEDIR='/mnt/home/'$USERNAME

# make directories as necessary
# mkdir -p $HOMEDIR/.config/kitty
# mkdir -p $HOMEDIR/.config/sway

# sway config
# curl -Lo $HOMEDIR/.config/sway/config https://raw.githubusercontent.com/Arunscape/arch-install-config/master/configs/home/.config/sway/config

# kitty
# curl -Lo $HOMEDIR/.config/kitty/kitty.conf https://raw.githubusercontent.com/Arunscape/arch-install-config/master/configs/home/.config/kitty/kitty.conf

# libinput gestures
# curl -Lo $HOMEDIR/.config/libinput-gestures.conf https://raw.githubusercontent.com/Arunscape/arch-install-config/master/configs/home/.config/libinput-gestures.conf

# .Xresources
# curl -Lo $HOMEDIR/.Xresources https://raw.githubusercontent.com/Arunscape/arch-install-config/master/configs/home/.Xresources

# .vimrc
# curl -Lo $HOMEDIR/.vimrc https://raw.githubusercontent.com/Arunscape/arch-install-config/master/configs/home/.vimrc

# vim-plug
# just realized I have a section in .vimrc which sets this up if it's missing
#curl -Lo $HOMEDIR/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# doesn't work as nicely, should also be run as user postinstall I think
# echo Installing vim plugins...
# vim +PlugInstall +qall

# .xinitrc
# curl -Lo $HOMEDIR/.xinitrc https://raw.githubusercontent.com/Arunscape/arch-install-config/master/configs/home/.xinitrc

# wallpaper
# curl -Lo $HOMEDIR/Excision_APEX_3840x2160_Wallpaper.jpg https://github.com/Arunscape/arch-install-config/raw/master/configs/home/Excision_APEX_3840x2160_Wallpaper.jpg
# }

finish(){
    # exit and reboot
    rm /mnt/install.sh
    umount -R /mnt
    echo "$(tput bold)$(tput setaf 2)Done!!!$(tput sgr 0)"
    # reboot
}

setup
format
run_pacstrap
chroot_step
# copy_configs
finish
