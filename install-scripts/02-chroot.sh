#variables passed in
USERNAME=$1
USER_PASSWD=$2
HOST_NAME=$3
TIMEZONE=$4
DRIVE=$5
CPU=$6
WIFI=$7

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
    

pacman -S --noconfirm --needed \
git \
linux \
linux-headers \
linux-lts \
linux-lts-headers \
linux-zen \
linux-zen-headers \
linux-firmware


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
    iwd \
    connmanctl
fi

# early KMS
# intel iGPU
# MODULES=(i915)
# amd gpu
# MODULES=(amdgpu)
cat > /etc/mkinitcpio.conf << EOF
MODULES=(i915)
BINARIES=(/usr/bin/btrfs)
FILES=""
HOOKS=(base udev systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems btrfs fsck)
EOF

echo KEYMAP=us >> /etc/vconsole.conf

mkinitcpio -p linux
    
diskuuid=$(blkid -s PARTUUID -o value /dev/disk/by-partlabel/cryptsystem)

# TODO change
uuid=$(blkid /dev/sda)

echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
echo "GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$uuid:root\""

# GRUB_CMDLINE_LINUX="... rd.luks.name=device-UUID=cryptlvm ..."
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB --recheck
exit