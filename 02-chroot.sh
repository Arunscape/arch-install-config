#variables passed in
USERNAME=$1
DRIVE=$2
CPU=$3
GPU=$4
WIFI=$5
DOTFILES=$6
LAPTOP=$7
HOST_NAME=$8

set -e
# NTP synchronization
# but systemctl doesn't work in chroot
# timedatectl set-ntp 1


hwclock --systohc --utc
locale-gen
useradd -m -g wheel -s /usr/bin/fish $USERNAME
usermod -p '!' root

mkdir -p /boot/loader/entries/
    
cat > /boot/loader/loader.conf << EOF
default arch-zen.conf
timeout 1
editor no
auto-entries 0
EOF

diskuuid=$(blkid -s UUID -o value /dev/disk/by-partlabel/cryptsystem)
partuuid=$(blkid -s PARTUUID -o value /dev/disk/by-partlabel/cryptsystem)
cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /$CPU-ucode.img
initrd  /initramfs-linux.img
options root=/dev/mapper/cryptroot rd.luks.name=$diskuuid=cryptroot rw rootflags=subvol=@
EOF

cat > /boot/loader/entries/arch-lts.conf << EOF
title   Arch Linux LTS
linux   /vmlinuz-linux-lts
initrd  /$CPU-ucode.img
initrd  /initramfs-linux-lts.img
options root=/dev/mapper/cryptroot rd.luks.name=$diskuuid=cryptroot rw rootflags=subvol=@
EOF

cat > boot/loader/entries/arch-zen.conf << EOF
title   Arch Linux Zen
linux   /vmlinuz-linux-zen
initrd  /$CPU-ucode.img
initrd  /initramfs-linux-zen.img
options root=/dev/mapper/cryptroot rd.luks.name=$diskuuid=cryptroot rw rootflags=subvol=@
EOF

bootctl install --path=/boot
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

if [ -z "$WIFI" ]
then
    :
else
    pacman -S --noconfirm --needed \
    iwd
fi
# early KMS
if [ "$GPU" == "intel" ]
then
    cat > /etc/mkinitcpio.conf << EOF
MODULES=(i915)
BINARIES=(/usr/bin/btrfs)
FILES=""
HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems btrfs fsck)
COMPRESSION="lz4"
EOF
    
elif [ "$GPU" == "amd" ]
then
    cat > /etc/mkinitcpio.conf << EOF
MODULES=(amdgpu)
BINARIES=(/usr/bin/btrfs)
FILES=""
HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems btrfs fsck)
COMPRESSION="lz4"
EOF

else
    cat > /etc/mkinitcpio.conf << EOF
MODULES=()
BINARIES=(/usr/bin/btrfs)
FILES=""
HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems btrfs fsck)
COMPRESSION="lz4"
EOF
fi

mkinitcpio -P

# install yay
cd /tmp
git clone https://aur.archlinux.org/paru.git
chown -R $USERNAME paru
cd paru

echo "$(tput bold)$(tput setaf 1)Time to set your passwd$(tput sgr 0)"
passwd $USERNAME
sudo -u $USERNAME makepkg -si

if [ -z "$DOTFILES" ]
then
    :
else
    cd /home/$USERNAME
    sudo -u $USERNAME git clone --recurse-submodules https://github.com/Arunscape/dotfiles.git
    cd dotfiles
    git remote set-url origin git@github.com:Arunscape/dotfiles.git
fi


if [ -z "$LAPTOP" ]
then
    :
else
    sudo -u $USERNAME paru -S --needed \
    brillo \
    libinput-gestures

    gpasswd -a $USERNAME input
    gpasswd -a $USERNAME video

    ln -sf /home/$USERNAME/dotfiles/.config/libinput-gestures.conf /home/$USERNAME/.config/libinput-gestures.conf
fi

exit
