#!/bin/sh

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
    un=$(whoami)
    sudo chfn -f "$fn" "$un"
else
    echo ""
fi

sudo cp pacman.conf /etc/
sudo rm -rf /etc/pacman.d/hooks/
sudo mkdir /etc/pacman.d/hooks/
sudo cp gutenprint.hook /etc/pacman.d/hooks/

echo ""
read -r -p "Do you want to install Reflector? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm reflector
    echo ""
    echo "It will take time to fetch the server/mirrors so please wait"
    sudo reflector --save /etc/pacman.d/mirrorlist -p https -c 'Netherlands,United States, ' -l 10 --sort rate
    #Change location as per your need
fi

echo ""
sudo pacman -Syu --needed --noconfirm pacman-contrib
if [ "$(pactree -r yay-bin)" ]; then
    echo ""
    echo "Yay is already installed"
else
    git clone https://aur.archlinux.org/yay-bin.git --depth=1
    cd yay-bin
    yes | makepkg -si
    cd ..
    rm -rf yay-bin
fi

echo ""
read -r -p "Do you want to install Intel drivers? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel #Intel
fi

echo ""
read -r -p "Do you want to install AMD/ATI drivers? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm mesa xf86-video-amdgpu xf86-video-ati libva-mesa-driver vulkan-radeon amdvlk #AMD/ATI
fi

echo ""
read -r -p "Do you want to install Nvidia drivers(Maxwell+)? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm nvidia nvidia-utils nvidia-settings nvidia-prime opencl-nvidia #NVIDIA
    sudo systemctl enable nvidia-{suspend,resume,hibernate}

    echo ""
    read -r -p "Do you want to install Envy Control(from AUR)? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        yay -S --needed --noconfirm envycontrol
        sudo envycontrol -s integrated
    fi
fi

echo ""
echo "SKIP THIS IF YOU DO NOT HAVE GRAPHICS CARD FROM KEPLER SERIES"
echo ""
read -r -p "Do you want to install Nvidia drivers(Kepler)? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    yay -Syu --needed --noconfirm nvidia-470xx-dkms nvidia-470xx-utils nvidia-470xx-settings nvidia-prime opencl-nvidia-470xx linux-headers
    sudo systemctl enable nvidia-{suspend,resume,hibernate}

    echo ""
    read -r -p "Do you want to install Envy Control? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        yay -S --needed -noconfirm envycontrol
        sudo envycontrol -s integrated
    fi
fi

echo ""
sudo pacman -Syu --needed --noconfirm - < tpkg
sudo systemctl enable touchegg
sudo systemctl enable --now ufw
sudo ufw enable
sudo systemctl enable --now cups
sudo cp cups /etc/ufw/applications.d/
sudo cupsctl
sudo ufw app update CUPS
sudo ufw allow CUPS
sudo systemctl enable sshd avahi-daemon
sudo cp /usr/share/doc/avahi/ssh.service /etc/avahi/services/
sudo ufw allow SSH
chsh -s /bin/fish
sudo chsh -s /bin/fish
pipx ensurepath

echo ""
read -r -p "Do you want to install Samba? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm samba
    sudo cp smb.conf /etc/samba/
    sudo systemctl enable smb nmb
    echo -e "[Share]\ncomment = Samba Share\npath = /home/"$un"/Share\nwritable = yes\nbrowsable = yes\nguest ok = no" | sudo tee -a /etc/samba/smb.conf > /dev/null
    mkdir ~/Share
    echo ""
    sudo smbpasswd -a $un
    sudo cp samba /etc/ufw/applications.d/
    sudo ufw app update SMB
    sudo ufw allow SMB
    sudo ufw allow CIFS
fi

#sudo sed -i 's/Logo=1/Logo=0/' /etc/libreoffice/sofficerc

echo -e "VISUAL=nvim\nEDITOR=nvim\nQT_QPA_PLATFORMTHEME=qt6ct\n__GL_THREADED_OPTIMIZATIONS=0" | sudo tee /etc/environment > /dev/null
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
sudo pacman -Syu --needed --noconfirm - < gnome
pacman -Sgq gnome | grep -vf rpkg | sudo pacman -S --needed --noconfirm -
if [ "$(pactree -r tlp)" ]; then
    echo ""
else
    sudo pacman -S --needed --noconfirm power-profiles-daemon
    sudo systemctl enable power-profiles-daemon
fi
sudo systemctl enable gdm
sudo -u gdm dbus-launch gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click 'true'
sudo -u gdm dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'
gsettings set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click 'true'
gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.sound allow-volume-above-100-percent 'true'

echo ""
read -r -p "Do you want to install Libadwaita theme for GTK3? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    tag=$(git ls-remote --tags https://github.com/lassekongo83/adw-gtk3.git | awk -F"/" '{print $3}' | tail -n 1)
    release=${tag//./-}
    wget -q -nc --show-progress https://github.com/lassekongo83/adw-gtk3/releases/download/$tag/adw-gtk3$release.tar.xz
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
    echo ""
    read -r -p "Do you want generate SSH keys? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo ""
	ssh-keygen -C "$git_email"
 	git config --global gpg.format ssh
  	git config --global user.signingkey /home/$un/.ssh/id_ed25519.pub
        echo ""
        echo "Make changes accordingly if SSH key is generated again"
    fi
fi

echo ""
read -r -p "Do you want to install TLP (and remove Gnome Power Profiles Daemon)? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    sudo pacman -Rscn --noconfirm power-profiles-daemon
    sudo pacman -Syu --needed --noconfirm tlp tlp-rdw smartmontools ethtool gnome-power-manager
    sudo systemctl enable tlp.service
    sudo systemctl enable NetworkManager-dispatcher.service
    sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
    sudo tlp start
fi

echo ""
read -r -p "Do you want Bluetooth Service? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm bluez bluez-utils blueman
    sudo systemctl enable bluetooth
fi

echo ""
read -r -p "Do you want to install Cloudflare Warp? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    wget -q -nc --show-progress https://github.com/ayu2805/cwi/releases/download/cloudflare-warp-install/cloudflare-warp-install && bash cloudflare-warp-install && rm cloudflare-warp-install
    echo ""
    read -r -p "Do you want to install Gnome Extension Managaer(from Flathub)? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        flatpak install -y flathub com.mattjakeman.ExtensionManager
    fi
fi

echo ""
read -r -p "Do you want to install VS Codium (from AUR)? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    yay -Syu --needed --noconfirm vscodium-bin
fi

echo ""
read -r -p "Do you want to install HPLIP (Driver for HP printers)? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm hplip sane python-pillow rpcbind python-reportlab
    hp-plugin -i
fi

cp QtProject.conf ~/.config/

echo ""
echo "You can now reboot your system"
