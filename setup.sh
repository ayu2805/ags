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
sudo pacman -Syu --needed --noconfirm pacman-contrib
echo ""
read -r -p "Do you want to install Reflector? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm reflector
    echo -e "--save /etc/pacman.d/mirrorlist\n-p https\n-c 'Netherlands,United States'\n-l 10\n--sort rate" | sudo tee /etc/xdg/reflector/reflector.conf > /dev/null
    #Change location as per your need
    echo ""
    echo "It will take time to fetch the server/mirrors so please wait"
    echo ""
    if [ "$(pactree -r reflector)" ]; then
        sudo systemctl restart reflector
    else
        sudo systemctl enable --now reflector 
        sudo systemctl enable reflector.timer
    fi
fi

echo ""
if [ "$(pactree -r yay)" ]; then
    echo "Yay is already installed"
else
    git clone https://aur.archlinux.org/yay.git
    cd yay
    yes | makepkg -si
    cd ..
    rm -rf yay
fi

echo ""
sudo pacman -Syu --needed --noconfirm - < tpkg
sudo systemctl enable touchegg
sudo systemctl enable --now ufw
sudo ufw enable
sudo systemctl enable --now cups
sudo cp cups /etc/ufw/applications.d/
sudo cupsctl --share-printers
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
    echo -e "[Share]\ncomment = Samba Share\npath = /home/"$(whoami)"/Share\nwritable = yes\nbrowsable = yes\nguest ok = no" | sudo tee -a /etc/samba/smb.conf > /dev/null
    mkdir ~/Share
    echo ""
    sudo smbpasswd -a $(whoami)
    sudo cp samba /etc/ufw/applications.d/
    sudo ufw app update SMB
    sudo ufw allow SMB
    sudo ufw allow CIFS
fi

sudo sed -i 's/Logo=1/Logo=0/' /etc/libreoffice/sofficerc

echo -e "VISUAL=nvim\nEDITOR=nvim\nQT_QPA_PLATFORMTHEME=qt6ct\n__GL_THREADED_OPTIMIZATIONS=0" | sudo tee /etc/environment > /dev/null
grep -qF "set number" /usr/share/nvim/sysinit.vim || echo "set number" | sudo tee -a /usr/share/nvim/sysinit.vim > /dev/null

echo ""
read -r -p "Do you want to install WhiteSur icon theme? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git --depth=1
    cd WhiteSur-icon-theme/
    sudo ./install.sh -a
    cd ..
    rm -rf WhiteSur-icon-theme/
fi

echo ""
echo "Installing Gnome..."
echo ""
sudo pacman -Syu --needed --noconfirm gnome gnome-tweaks
sudo pacman -Rscn --needed --noconfirm - < rmvpkg
sudo systemctl enable gdm
sudo -u gdm dbus-launch gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click 'true'

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
	    ssh-keygen -t ed25519 -C "$git_email"
        echo ""
        echo "Make changes accordingly if SSH key is generated again"
    fi
fi

echo ""
read -r -p "Do you want TLP and auto-cpufreq? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm tlp tlp-rdw
    sudo systemctl enable tlp.service
    sudo systemctl enable NetworkManager-dispatcher.service
    sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
    sudo tlp start

    echo ""
    git clone https://github.com/AdnanHodzic/auto-cpufreq.git
    cd auto-cpufreq && sudo ./auto-cpufreq-installer
    cd ..
    sudo rm -rf auto-cpufreq/
    sudo auto-cpufreq --install
fi

echo ""
read -r -p "Do you want Bluetooth Service? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm bluez bluez-utils
    sudo systemctl enable bluetooth
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

cp QtProject.conf ~/.config

echo ""
echo "You can now reboot your system"
