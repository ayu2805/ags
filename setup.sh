#!/bin/bash

if [ "$(id -u)" = 0 ]; then
    echo "######################################################################"
    echo "This script should NOT be run as root user as it may create unexpected"
    echo " problems and you may have to reinstall Arch. So run this script as a"
    echo "  normal user. You will be asked for a sudo password when necessary"
    echo "######################################################################"
    exit 1
fi

read -p "Enter your Full Name: " fn
if [ -n "$fn" ]; then
    sudo chfn -f "$fn" "$(whoami)"
else
    echo ""
fi

grep -qF "Include = /etc/pacman.d/custom" /etc/pacman.conf || echo "Include = /etc/pacman.d/custom" | sudo tee -a /etc/pacman.conf > /dev/null
echo -e "[options]\nColor\nParallelDownloads = 5\nILoveCandy\n" | sudo tee /etc/pacman.d/custom > /dev/null
sudo mkdir -p /etc/pacman.d/hooks/
sudo cp gutenprint.hook /etc/pacman.d/hooks/

echo ""
read -r -p "Do you want to install Reflector? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm reflector
    echo -e "\nIt will take time to fetch the server/mirrors so please wait"
    sudo reflector --save /etc/pacman.d/mirrorlist -p https -c 'Netherlands,United States, ' -l 10 --sort rate
    #Change location as per your need
fi

echo ""
sudo pacman -Syu --needed --noconfirm pacman-contrib
if [ "$(pactree -r linux)" ]; then
    sudo pacman -S --needed --noconfirm linux-headers
fi

if [ "$(pactree -r linux-zen)" ]; then
    sudo pacman -S --needed --noconfirm linux-zen-headers
fi

if [ "$(pactree -r chaotic-keyring && pactree -r chaotic-mirrorlist)" ]; then
    echo -e "[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" | sudo tee -a /etc/pacman.d/custom > /dev/null
else
    echo ""
    read -r -p "Do you want Chaotic-AUR? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
        sudo pacman-key --lsign-key 3056513887B78AEB
        sudo pacman -U --needed --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        echo -e "[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" | sudo tee -a /etc/pacman.d/custom > /dev/null
        sudo pacman -Syu

        if [ "$(pactree -r yay || pactree -r yay-bin)" ]; then
            true
        else
            sudo pacman -S --needed --noconfirm yay
        fi
    fi
fi

if [ "$(pactree -r yay || pactree -r yay-bin)" ]; then
    true
else
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay-bin.git --depth=1
    cd yay-bin
    yes | makepkg -si
    cd ..
    rm -rf yay-bin
fi

yay -S --answerclean A --answerdiff N --removemake --cleanafter --save

echo ""
read -r -p "Do you want to install Intel drivers? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel #Intel
fi

echo ""
read -r -p "Do you want to install AMD drivers? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm mesa xf86-video-amdgpu libva-mesa-driver vulkan-radeon #AMD/ATI
fi

echo ""
read -r -p "Do you want to install Nvidia drivers(Maxwell+)? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm nvidia-dkms nvidia-utils nvidia-settings nvidia-prime opencl-nvidia switcheroo-control #NVIDIA
    echo -e options "nvidia-drm modeset=1 fbdev=1\noptions nvidia NVreg_UsePageAttributeTable=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
    sudo sed -i 's/MODULES=\(.*\)/MODULES=\(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
    sudo systemctl enable nvidia-persistenced nvidia-hibernate nvidia-powerd nvidia-resume nvidia-suspend switcheroo-control
fi

echo ""
sudo pacman -S --needed --noconfirm - <tpkg
sudo systemctl enable --now ufw
sudo systemctl enable --now cups
sudo systemctl disable systemd-resolved.service
sudo systemctl enable sshd avahi-daemon power-profiles-daemon
echo -e "[global]\nworkgroup = WORKGROUP\nserver string = Samba Server\nnetbios name = $(hostname)\n\n" | sudo tee /etc/samba/smb.conf > /dev/null
echo ""
sudo smbpasswd -a $(whoami)
echo ""
sudo systemctl enable smb nmb
sudo cp gsconnect /etc/ufw/applications.d/
sudo cupsctl
sudo ufw enable
sudo ufw allow IPP
sudo ufw allow CIFS
sudo ufw allow SSH
sudo ufw app update GSConnect
sudo ufw allow GSConnect
sudo cp /usr/share/doc/avahi/ssh.service /etc/avahi/services/
chsh -s /usr/bin/fish
sudo chsh -s /usr/bin/fish
pipx ensurepath
echo -e "127.0.0.1\tlocalhost\n127.0.1.1\t$(hostname)\n\n# The following lines are desirable for IPv6 capable hosts\n::1     localhost ip6-localhost ip6-loopback\nff02::1 ip6-allnodes\nff02::2 ip6-allrouters" | sudo tee /etc/hosts > /dev/null
#register-python-argcomplete --shell fish pipx >~/.config/fish/completions/pipx.fish

echo ""
read -r -p "Do you want to create a Samba Shared folder? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "[global]\nworkgroup = WORKGROUP\nserver string = Samba Server\nnetbios name = $(hostname)\n\n" | sudo tee /etc/samba/smb.conf > /dev/null
    echo -e "[Samba Share]\ncomment = Samba Share\npath = /home/$(whoami)/Samba Share\nwritable = yes\nbrowsable = yes\nguest ok = no" | sudo tee -a /etc/samba/smb.conf > /dev/null
    rm -rf ~/Samba\ Share
    mkdir ~/Samba\ Share
    sudo systemctl restart smb nmb
fi

#sudo sed -i 's/Logo=1/Logo=0/' /etc/libreoffice/sofficerc
echo -e "VISUAL=nvim\nEDITOR=nvim" | sudo tee /etc/environment > /dev/null
grep -qF "set number" /etc/xdg/nvim/sysinit.vim || echo "set number" | sudo tee -a /etc/xdg/nvim/sysinit.vim > /dev/null
grep -qF "set wrap!" /etc/xdg/nvim/sysinit.vim || echo "set wrap!" | sudo tee -a /etc/xdg/nvim/sysinit.vim > /dev/null

echo ""
echo "Installing WhiteSur Icon Theme..."
echo ""
git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git --depth=1
cd WhiteSur-icon-theme/
sudo ./install.sh -a
cd ..
rm -rf WhiteSur-icon-theme/

echo ""
echo "Installing Gnome..."
echo ""
sudo pacman -S --needed --noconfirm - <gnome
pacman -Sgq gnome | grep -vf rpkg | sudo pacman -S --needed --noconfirm -
sudo systemctl enable gdm wsdd touchegg
sudo -u gdm dbus-launch gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click 'true'
sudo -u gdm dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'
sudo -u gdm dbus-launch gsettings set org.gnome.desktop.peripherals.touchpad send-events disabled-on-external-mouse
gsettings set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click 'true'
gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface clock-format '24h'
gsettings set org.gnome.desktop.interface clock-show-seconds true
gsettings set org.gnome.desktop.interface enable-hot-corners false
gsettings set org.gnome.desktop.datetime automatic-timezone true
gsettings set org.gnome.desktop.sound allow-volume-above-100-percent 'true'
gsettings set org.gnome.mutter center-new-windows true
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.desktop.peripherals.touchpad send-events disabled-on-external-mouse
gsettings set org.gnome.desktop.peripherals.touchpad speed 0.2
gsettings set org.gnome.desktop.privacy old-files-age uint32\ 7
gsettings set org.gnome.desktop.privacy remember-recent-files false
gsettings set org.gnome.desktop.privacy remove-old-temp-files true
gsettings set org.gnome.desktop.privacy remove-old-trash-files true
xdg-mime default org.gnome.Nautilus.desktop inode/directory

echo ""
read -r -p "Do you want to install Libadwaita theme for GTK3? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    release=$(git ls-remote --tags https://github.com/lassekongo83/adw-gtk3.git | awk -F"/" '{print $3}' | sort -V | tail -1)
    #release=${tag//./-}
    wget -q -nc --show-progress https://github.com/lassekongo83/adw-gtk3/releases/latest/download/adw-gtk3$release.tar.xz
    sudo tar -xJf adw-gtk3$release.tar.xz -C /usr/share/themes/
    rm adw-gtk3$release.tar.xz
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
fi

echo ""
read -r -p "Do you want to configure git? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    read -p "Enter your Git name: " git_name
    read -p "Enter your Git email: " git_email
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    ssh-keygen -C "$git_email"
    git config --global gpg.format ssh
    git config --global user.signingkey /home/$(whoami)/.ssh/id_ed25519.pub
    git config --global commit.gpgsign true
fi

echo ""
read -r -p "Do you want to install Firefox? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm firefox firefox-ublock-origin
fi

echo ""
read -r -p "Do you want to install Chromium? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm chromium
fi

echo ""
read -r -p "Do you want Bluetooth Service? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm bluez bluez-utils
    sudo systemctl enable bluetooth
fi

echo ""
read -r -p "Do you want to install HPLIP (Driver for HP printers)? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm hplip python-pyqt5 sane
    hp-plugin -i
fi

echo ""
read -r -p "Do you want to install Code-OSS? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm code
    echo ""
    read -r -p "Do you want to install proprietary VSCode marketplace? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        yay -S --needed --noconfirm code-marketplace
    fi
fi

echo ""
read -r -p "Do you want to install Telegram? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm telegram-desktop
fi

echo ""
read -r -p "Do you want to install Cloudflare Warp? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    bash -c "$(curl -Ss https://gist.githubusercontent.com/ayu2805/7ad8100b15699605fbf50291af8df16c/raw/warp-update)"
    warp-cli generate-completions fish | sudo tee /etc/fish/completions/warp-cli.fish > /dev/null
fi

echo ""
read -r -p "Do you want Gaming Stuff? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    bash -c "$(curl -sS https://gist.githubusercontent.com/ayu2805/37d0d1740cd7cc8e1a37b2a1c2ecf7a6/raw/archlinux-gaming-setup)"
fi

cp QtProject.conf ~/.config/

echo ""
read -r -p "Do you want to install some extentions that can be necessary? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    sudo pacman -S --needed --noconfirm gnome-shell-extension-caffeine
    gnome-extensions enable drive-menu@gnome-shell-extensions.gcampax.github.com
    gnome-extensions enable light-style@gnome-shell-extensions.gcampax.github.com
    gnome-extensions enable caffeine@patapon.info
    gnome-extensions enable workspace-indicator@gnome-shell-extensions.gcampax.github.com

    echo ""
    mkdir -p ~/.local/share/gnome-shell/extensions/
    
    wget -q -nc --show-progress https://github.com/stuarthayhurst/alphabetical-grid-extension/releases/latest/download/AlphabeticalAppGrid@stuarthayhurst.shell-extension.zip
    rm -rf ~/.local/share/gnome-shell/extensions/AlphabeticalAppGrid@stuarthayhurst/
    unzip -q AlphabeticalAppGrid@stuarthayhurst.shell-extension.zip -d ~/.local/share/gnome-shell/extensions/AlphabeticalAppGrid@stuarthayhurst/
    rm AlphabeticalAppGrid@stuarthayhurst.shell-extension.zip
    glib-compile-schemas ~/.local/share/gnome-shell/extensions/AlphabeticalAppGrid@stuarthayhurst/schemas/
    gnome-extensions enable AlphabeticalAppGrid@stuarthayhurst
    
    wget -q -nc --show-progress https://github.com/GSConnect/gnome-shell-extension-gsconnect/releases/latest/download/gsconnect@andyholmes.github.io.zip
    rm -rf ~/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/
    unzip -q gsconnect@andyholmes.github.io.zip -d ~/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/
    rm gsconnect@andyholmes.github.io.zip
    gnome-extensions enable gsconnect@andyholmes.github.io
    
    wget -q -nc --show-progress https://github.com/JoseExposito/gnome-shell-extension-x11gestures/releases/latest/download/x11gestures@joseexposito.github.io.zip
    rm -rf ~/.local/share/gnome-shell/extensions/x11gestures@joseexposito.github.io/
    unzip -q x11gestures@joseexposito.github.io.zip -d ~/.local/share/gnome-shell/extensions/x11gestures@joseexposito.github.io/
    rm x11gestures@joseexposito.github.io.zip
    gnome-extensions enable x11gestures@joseexposito.github.io
fi

echo ""
echo "You can now reboot your system"
