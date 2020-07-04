# variables
# Edit these variables or leave them blank to be prompted during setup

# install arch to this drive ex: /dev/sda or /dev/sdb... etc
DRIVE='/dev/sda'

HOST_NAME='Arun-Predator-Linux'

# has to be all lowercase
USERNAME='arunscape'

# maybe not the best idea to store your password in plain text but the option is there if you want
USER_PASSWD=''

# examples:
# America/New_York
TIMEZONE='Canada/Mountain'

# amd or intel
CPU='intel'

WIFI='y'


# right now, I default to Canadian English locales
# KEYMAP=''
    
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



read -p "$(tput bold)$(tput setaf 1)WARNING this will wipe $DRIVE Press ENTER to continue, or Ctrl+C to exit$(tput sgr 0)"

sgdisk --zap-all $DRIVE
partprobe

sgdisk --clear \
        --new=1:0:+512MiB --typecode=1:ef00 --change-name=1:EFI \
        --new=2:0:0       --typecode=2:8300 --change-name=2:cryptsystem \
        $DRIVE

mkfs.fat -F32 -n EFI /dev/disk/by-partlabel/EFI

cryptsetup luksFormat -s 256 -c aes-xts-plain64 --type luks1 /dev/disk/by-partlabel/cryptsystem

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
mkdir /mnt/efi
mount LABEL=EFI /mnt/efi


pacman -Syy
pacstrap /mnt base base-devel btrfs-progs

    
# so that linux auto mounts /root /boot /home
genfstab -U /mnt >> /mnt/etc/fstab
curl -Lo /mnt/install.sh https://raw.githubusercontent.com/Arunscape/arch-install-config/master/install-scripts/02-chroot.sh
chmod +x /mnt/install.sh
arch-chroot /mnt bash install.sh $USERNAME $USER_PASSWD $HOST_NAME $TIMEZONE $DRIVE $CPU $WIFI

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

clone_configs
finish
