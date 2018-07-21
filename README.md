# [wip] Arch Install Cheatsheet for UEFI systemd-boot and GNOME / i3

# Download [wip]
```bash
export archiso_latest=$(curl -s https://www.archlinux.org/download/ | grep "Current Release" | awk '{print $3}' | sed -e 's/<.*//')
export archiso_link=http://mirrors.kernel.org/archlinux/iso/$archiso_latest/archlinux-$archiso_latest-x86_64.iso
wget "$archiso_link"
dd bs=4M if=/path/to/archlinux.iso of=/dev/sdx status=progress oflag=sync
```

### Connect to wifi
```bash
wifi-menu
```

# Pre-install

## Partitioning

```bash
wipefs -a /dev/sda
fdisk /dev/sda
```
|           | size | mount point |
|-----------|------|-------------|
| /dev/sda1 | 256M | /boot       |
| /dev/sda2 | 32G  | /           |
| /dev/sda3 | 24G  | SWAP        |
| /dev/sda4 |      | /home       |

### fdisk:
```
g - create GPT disklabel
n - new partition
t - change partition type (1=EFI)
d - delete partition
p - print status
w - write
q - quit
```

## Formatting
```bash
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mkswap /dev/sda3
swapon /dev/sda3
mkfs.ext4 /dev/sda4
```

## Mount
```bash
mount /dev/sda2 /mnt
mkdir /mnt/home
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
mount /dev/sda4 /mnt/home
# lsblk to make sure
```

# Pacstrap
#### Optional - Edit the Mirrorlist
```bash
vim /etc/pacman.d/mirrorlist
```
---
```bash
pacstrap -i /mnt base base-devel vim git intel-ucode
genfstab -U /mnt >> /mnt/etc/fstab # so that linux auto mounts /root /boot /home
```

# Post Pacstrap
```bash
arch-chroot /mnt

# Timezone
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
# Run hwclock(8) to generate /etc/adjtime: 
hwclock --systohc

# Hostname
echo Arun-Predator-Linux > /etc/hostname

# Set root passwwd
passwd

```
### Localization

```bash
# Uncomment en_CA.UTF-8 UTF-8
vim /etc/locale.gen 

echo LANG=en_US.UTF-8 > /etc/locale.conf
locale-gen
```


## systemd
```bash
bootctl install
```
```bash
vim boot/loader/loader.conf
# should look like this

default arch
timeout 1
editor no
auto-entries 0
```
```bash
vim boot/loader/entries/arch.conf
# should look like this
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=XXXXXXXXXXXXXXXXXXXX rw

# do this where XXXXXXXXXXXXXX is
:r !blkid -s PARTUUID -o value /dev/sda2
```


## add user
```bash
useradd -m -g wheel username
passwd username
#edit wheel file
visudo
```

# Reboot, unplug USB
```bash
# exit chroot
exit
reboot
```

# stuff i install
```bash
sudo pacman -Syyu
sudo pacman -S xorg-server xorg-xinit
sudo pacman -S gnome
sudo pacman -S i3
sudo pacman -S nvidia bbswitch linux-headers
```

# Rank Mirrors
```bash
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
rankmirrors -n 6 /etc/pacman.d/mirrorlist.bak > /etc/pacman.d/mirrorlist
```

```bash
pacman -S networkmanager gnome i3 i3-gaps i3status network-manager-applet nvidia bbswitch
```
