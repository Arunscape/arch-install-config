# variables
# Edit these variables or leave them blank to be prompted during setup

# install arch to this drive ex: /dev/sda or /dev/sdb... etc
DRIVE=''

HOST_NAME=''

# has to be all lowercase
USERNAME=''

# maybe not the best idea to store your password in plain text but the option is there if you want
USER_PASSWD=''

# examples:
# America/New_York
TIMEZONE=''

# amd or intel
CPU=''

WIFI=''


# right now, I default to Canadian English locales
# KEYMAP=''

setup(){
    
    [ -z "$DRIVE" ] && (
        echo 'Enter the drive to install Arch to:'
        read DRIVE)
    echo Installing Arch to: $DRIVE
    
    [ -z "$HOST_NAME" ] && (
        echo 'Enter your desired hostname:'
        read HOST_NAME)
    echo Hostname: $HOST_NAME
    
    [ -z "$USERNAME" ] && (
        echo 'Enter your username:'
        read USERNAME)
    echo Username: $USERNAME
    
    while true
    do
        echo 'Enter your password:'
        read USER_PASSWD
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
    
    [ -z "$TIMEZONE" ] && (
        echo 'Enter your timezone'
        read TIMEZONE)
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
    [ -z "$WIFI" ] && (
        echo 'Do you need wifi? If not, just hit enter. If you do, type anything then hit enter'
        read WIFI)
}

format(){
    read -p "$(tput bold)$(tput setaf 1)WARNING this will wipe $DRIVE Press ENTER to continue, or Ctrl+C to exit$(tput sgr 0)"
    
    sgdisk --zap-all $DRIVE
    partprobe

    sgdisk --clear \
         --new=1:0:+512MiB --typecode=1:ef00 --change-name=1:EFI \
         --new=2:0:0       --typecode=2:8300 --change-name=2:cryptsystem \
           $DRIVE

    mkfs.fat -F32 -n EFI /dev/disk/by-partlabel/EFI

    cryptsetup luksFormat --align-payload=8192 -s 256 -c aes-xts-plain64 /dev/disk/by-partlabel/cryptsystem

    cryptsetup open /dev/disk/by-partlabel/cryptsystem system
    
    mkfs.btrfs --force --label system /dev/mapper/system
    o=defaults,x-mount.mkdir
    o_btrfs=$o,compress=lzo,ssd,noatime
    
    mount -t btrfs LABEL=system /mnt
    btrfs subvolume create /mnt/root
    btrfs subvolume create /mnt/home
    btrfs subvolume create /mnt/snapshots
    umount -R /mnt

    mount -t btrfs -o subvol=root,$o_btrfs LABEL=system /mnt
    mount -t btrfs -o subvol=home,$o_btrfs LABEL=system /mnt/home
    mount -t btrfs -o subvol=snapshots,$o_btrfs LABEL=system /mnt/.snapshots

    mkdir /mnt/boot
    mount LABEL=EFI /mnt/boot

}

run_pacstrap(){
    pacman -Syy
    pacstrap /mnt base base-devel
}

post_pacstrap(){
    
    # so that linux auto mounts /root /boot /home
    genfstab -U /mnt >> /mnt/etc/fstab
    
    echo Setting timezone...
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    # NTP synchronization
    # timedatectl set-ntp 1
    
    echo running hwclock...
    hwclock --systohc
    
    echo Setting hostname...
    echo $HOST_NAME > /etc/hostname
    
    # Localization
    echo Uncommenting these lines in /etc/locale.gen:
    cat /etc/locale.gen | grep en_CA
    cat /etc/locale.gen | grep en_US
    sed -i '/en_CA/ s/^#//' /etc/locale.gen
    sed -i '/en_US/ s/^#//' /etc/locale.gen
    
    echo LANG=en_CA.UTF-8 > /etc/locale.conf
    
    echo Generating locale...
    locale-gen
    
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
    
    pacman -S --noconfirm --needed \
    git \
    $CPU-ucode \
    linux \
    linux-headers \
    linux-lts \
    linux-lts-headers \
    linux-zen \
    linux-zen-headers \
    linux-firmware \
    btrfs-progs
    
    echo Installing yay...
    git clone https://aur.archlinux.org/yay.git
    chmod 777 -R yay
    cd yay
    sudo -u $USERNAME makepkg --noconfirm -si
    cd ..
    rm -rf yay
    
    if [ -z "$WIFI"]
    then
        :
    else
        pacman -S --noconfirm --needed \
        networkmanager \
        wpa_supplicant
    fi

    cat > /etc/mkinitcpio.conf << EOF
MODULES=""
BINARIES=""
FILES=""
HOOKS="base systemd sd-vconsole modconf keyboard block filesystems btrfs sd-encrypt fsck"
EOF

    mkinitcpio -p linux
    
    diskuuid=$(blkid -s PARTUUID -o value /dev/disk/by-partlabel/cryptsystem)
    
    cat > boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /$CPU-ucode.img
initrd  /initramfs-linux.img
options cryptdevice=UUID={$diskuuid}:volume root=/dev/disk/by-partlabel/cryptsystem quiet rw
EOF
    
    cat > boot/loader/entries/arch-lts.conf << EOF
title   Arch Linux LTS Kernel
linux   /vmlinuz-linux-lts
initrd  /$CPU-ucode.img
initrd  /initramfs-linux-lts.img
options cryptdevice=UUID={$diskuuid}:volume root=/dev/disk/by-partlabel/cryptsystem quiet rw
EOF

    cat > boot/loader/entries/arch-zen.conf << EOF
title   Arch Linux Zen Kernel
linux   /vmlinuz-linux-zen
initrd  /$CPU-ucode.img
initrd  /initramfs-linux-zen.img
options cryptdevice=UUID={$diskuuid}:volume root=/dev/disk/by-partlabel/cryptsystem quiet rw
EOF
    
    bootctl --path=/boot/ install
    
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
    

}

clone_configs(){
    cd /home/$USERNAME
    sudo -u $USERNAME git clone https://github.com/Arunscape/dotfiles.git
    cd dotfiles
    sudo -u $USERNAME git remote set-url origin git@github.com:Arunscape/dotfiles.git
}

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
post_pacstrap
clone_configs
finish
