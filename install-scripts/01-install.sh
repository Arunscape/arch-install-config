# variables
# Edit these variables or leave them blank to be prompted during setup

# install arch to this drive ex: /dev/sda or /dev/sdb... etc
DRIVE='/dev/sda'

HOST_NAME='Arun-Predator-Linux'

# has to be all lowercase
USERNAME='arunscape'

# examples:
# America/New_York
# America/Toronto
TIMEZONE='Canada/Mountain'

# amd
# intel
CPU='intel'

# anything for yes, empty for no
WIFI='y'

# amd
# nvidia
# intel 
GPU='intel'

set -e 
setfont sun12x22
lsblk
read -p "$(tput bold)$(tput setaf 1)WARNING this will wipe $DRIVE Press ENTER to continue, or Ctrl+C to exit$(tput sgr 0)"

sgdisk --zap-all $DRIVE

partprobe $DRIVE
sgdisk --clear \
        --new=1:0:+512MiB --typecode=1:ef00 --change-name=1:EFI \
        --new=2:0:0       --typecode=2:8300 --change-name=2:cryptsystem \
        $DRIVE

partprobe $DRIVE
mkfs.fat -F32 -n EFI /dev/disk/by-partlabel/EFI

cryptsetup luksFormat \
        --pbkdf argon2id \
        --key-size 512 \
        --hash sha512 \
        --cipher aes-xts-plain64 \
        --type luks2 \
        --use-random \
        --iter-time 5000 \
        /dev/disk/by-partlabel/cryptsystem

cryptsetup open /dev/disk/by-partlabel/cryptsystem system

mkfs.btrfs --force --label system /dev/mapper/system
o=defaults,x-mount.mkdir
o_btrfs=$o,compress=lzo,ssd,noatime,nodiratime

# when doing snapshots, also include pacman cache under /var
mount -t btrfs LABEL=system /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@srv
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@snapshots
umount -R /mnt

mount -t btrfs -o subvol=@,$o_btrfs LABEL=system /mnt
mkdir -p /mnt/{home,srv,var/{log,cache/pacman/pkg},tmp}

mount -t btrfs -o subvol=@home,$o_btrfs LABEL=system /mnt/home
mount -t btrfs -o subvol=@log,$o_btrfs LABEL=system /mnt/var/log
mount -t btrfs -o subvol=@pkg,$o_btrfs LABEL=system /mnt/var/cache/pacman/pkg
mount -t btrfs -o subvol=@srv,$o_btrfs LABEL=system /mnt/srv
mount -t btrfs -o subvol=@tmp,$o_btrfs LABEL=system /mnt/tmp
mount -t btrfs -o subvol=@snapshots,$o_btrfs LABEL=system /mnt/.snapshots

mkdir /mnt/boot
mount LABEL=EFI /mnt/boot

sed -i "s/^#Color/Color/" /etc/pacman.conf
sed -i "/^Color/a ILoveCandy" /etc/pacman.conf

pacman -Syy
pacstrap /mnt base base-devel \
                    btrfs-progs \
                    $CPU-ucode \
                    linux \
                    linux-headers \
                    linux-lts \
                    linux-lts-headers \
                    linux-zen \
                    linux-zen-headers \
                    linux-firmware \
                    openssh \
                    git \
                    neovim \
                    fish \
                    dash \
                    sway \
                    kitty \
                    grim \
                    slurp \
                    p7zip \
                    noto-fonts \
                    ttf-fira-code \
                    firefox-developer-edition \
                    vlc \
                    thefuck \
                    lsd \
                    sl \
                    zathura \
                    zathura-pdf-poppler



genfstab -U /mnt >> /mnt/etc/fstab
curl -Lo /mnt/install.sh https://raw.githubusercontent.com/Arunscape/arch-install-config/master/install-scripts/02-chroot.sh
chmod +x /mnt/install.sh
arch-chroot /mnt bash install.sh $USERNAME $DRIVE $CPU $GPU $WIFI

# exit and reboot
rm /mnt/install.sh
# umount -R /mnt
echo "$(tput bold)$(tput setaf 2)Done!!!$(tput sgr 0)"
echo remember to umount -R /mnt
# reboot