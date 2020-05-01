
#variables passed in
USERNAME=$1
USER_PASSWD=$2
HOST_NAME=$3
TIMEZONE=$4
DRIVE=$5
CPU=$6
WIFI=$7

setup(){
    
    echo Setting timezone...
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    # NTP synchronization
    timedatectl set-ntp 1
    
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
    btrfs-progs \
    refind-efi \
    nvim
    
    
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
    refind-install

    cat > /etc/mkinitcpio.conf << EOF
timeout          5                # Timeout how long ReFind wait for user input
#include         themes/rEFInd-   # For theming ReFind uncomment this and fill in the right location of your theme
use_graphics_for windows          # Specify the simpler "mac-style" behaviour
also_scan_dirs   +,@/             # Search for boot loaders in the specified directory  
EOF

    nvim /boot/refind_linux.conf
}

clone_configs(){
    cd /home/$USERNAME
    sudo -u $USERNAME git clone https://github.com/Arunscape/dotfiles.git
    cd dotfiles
    sudo -u $USERNAME git remote set-url origin git@github.com:Arunscape/dotfiles.git
}

setup
install_stuff
clone_configs
exit
