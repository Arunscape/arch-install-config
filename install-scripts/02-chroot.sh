#variables passed in
USERNAME=$1
DRIVE=$2
CPU=$3
GPU=$4
WIFI=$5
DOTFILES=$6
LAPTOP=$7

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
    iwd \
    connman

    cat > /etc/systemd/system/iwd.service << EOF
[Unit]
Description=Internet Wireless Daemon (IWD)
Before=network.target
Wants=network.target

[Service]
ExecStart=/usr/lib/iwd/iwd

[Install]
Alias=multi-user.target.wants/iwd.service
EOF

    cat > /etc/systemd/system/connman_iwd.service << EOF
[Unit]
Description=Connection service
DefaultDependencies=false
Conflicts=shutdown.target
RequiresMountsFor=/var/lib/connman
After=dbus.service network-pre.target systemd-sysusers.service iwd.service
Before=network.target multi-user.target shutdown.target
Wants=network.target
Requires=iwd.service

[Service]
Type=dbus
BusName=net.connman
Restart=on-failure
ExecStart=/usr/bin/connmand --wifi=iwd_agent -n 
StandardOutput=null
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_TIME CAP_SYS_MODULE
ProtectHome=true
ProtectSystem=true

[Install]
WantedBy=multi-user.target
EOF

    echo 'PreferredTechnologies=ethernet,wifi' >> /etc/connman/main.conf

    cat > /var/lib/connman/eduroam.config << EOF
[service_eduroam]
Type=wifi
Name=eduroam
EAP=peap
CACertFile=/etc/ssl/certs/GlobalSign_Root_CA.pem
Phase2=MSCHAPV2
Identity=user@foo.edu
AnonymousIdentity=
Passphrase=password
EOF

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
git clone https://aur.archlinux.org/yay.git
chown -R $USERNAME yay
cd yay

"$(tput bold)$(tput setaf 1)Time to set your passwd(tput sgr 0)"
passwd $USERNAME
sudo -u $USERNAME makepkg --noconfirm -si

if [ -z "$DOTFILES" ]
then
    :
else
    cd /home/$USERNAME
    git clone https://github.com/Arunscape/dotfiles.git
    cd dotfiles
    git remote set-url origin git@github.com:Arunscape/dotfiles.git
    sudo -u $USERNAME bash -c "bash installapps.sh"
    HOME=/home/$USERNAME bash symlinks.sh
fi


if [ -z "$LAPTOP" ]
then
    :
else
    sudo -u $USERNAME yay -S --noconfirm --needed \
    brillo \
    libinput-gestures

    gpasswd -a $USERNAME input
    gpasswd -a $USERNAME video
    libinput-gestures-setup autostart

    ln -sf /home/$USERNAME/dotfiles/.config/libinput-gestures.conf /home/$USERNAME/.config/libinput-gestures.conf
fi

exit