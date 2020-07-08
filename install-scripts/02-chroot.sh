#variables passed in
USERNAME=$1
DRIVE=$2
CPU=$3
GPU=$4
WIFI=$5

set -e
# NTP synchronization
# but systemctl doesn't work in chroot
# timedatectl set-ntp 1
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
echo $HOST_NAME > /etc/hostname
sed -i '/en_CA/ s/^#//' /etc/locale.gen
sed -i '/en_US/ s/^#//' /etc/locale.gen
echo LANG=en_CA.UTF-8 >> /etc/locale.conf
echo LANG=en_US.UTF-8 >> /etc/locale.conf
echo KEYMAP=us >> /etc/vconsole.conf
sed -i '/%wheel ALL=(ALL) ALL/ s/^# //' /etc/sudoers
sed -i "s/^#Color/Color/" /etc/pacman.conf
sed -i "/^Color/a ILoveCandy" /etc/pacman.conf

hwclock --systohc --utc
locale-gen
useradd -m -g wheel -s /usr/bin/fish $USERNAME
usermod -p '!' root

mkdir -p /boot/loader/entries/
    
cat > /boot/loader/loader.conf << EOF
default arch-zen
timeout 1
editor no
auto-entries 0
EOF

diskuuid=$(blkid -s UUID -o value /dev/disk/by-partlabel/cryptsystem)
partuuid=$(blkid -s PARTUUID -o value /dev/disk/by-partlabel/cryptsystem)
cat > boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /$CPU-ucode.img
initrd  /initramfs-linux.img
options rd.luks.name=$partuuid=cryptsystem root=/dev/mapper/system rw rootflags=subvol=@
EOF

cat > boot/loader/entries/arch-lts.conf << EOF
title   Arch Linux LTS
linux   /vmlinuz-linux-lts
initrd  /$CPU-ucode.img
initrd  /initramfs-linux-lts.img
options rd.luks.name=$partuuid=cryptsystem root=/dev/mapper/system rw rootflags=subvol=@
EOF

cat > boot/loader/entries/arch-zen.conf << EOF
title   Arch Linux Zen
linux   /vmlinuz-linux-zen
initrd  /$CPU-ucode.img
initrd  /initramfs-linux-zen.img
options rd.luks.name=$partuuid=cryptsystem root=/dev/mapper/system rw rootflags=subvol=@
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
    iwd \
    connman
fi

# early KMS
if [ "$GPU" == "intel" ]
then
    cat > /etc/mkinitcpio.conf << EOF
MODULES=(i915)
BINARIES=(/usr/bin/btrfs)
FILES=""
HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems btrfs fsck)
EOF
    
else if [ "$GPU" == "amd" ]
then
    cat > /etc/mkinitcpio.conf << EOF
MODULES=(amdgpu)
BINARIES=(/usr/bin/btrfs)
FILES=""
HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems btrfs fsck)
EOF

else
    :
fi

# install yay
cd /tmp
git clone https://aur.archlinux.org/yay.git
chown -R nobody yay
cd yay
sudo -u nobody makepkg --noconfirm -si

clone_configs(){
    cd /home/$USERNAME
    sudo -u $USERNAME git clone https://github.com/Arunscape/dotfiles.git
    cd dotfiles
    sudo -u $USERNAME git remote set-url origin git@github.com:Arunscape/dotfiles.git
}



# uncomment to skip cloning dotfiles
clone_configs
echo "Enter password for $USERNAME"
passwd $USERNAME
exit