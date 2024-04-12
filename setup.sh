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
if [ "$(pactree -r linux)" ]; then
    sudo pacman -S --needed --noconfirm linux-headers
fi

if [ "$(pactree -r linux-zen)" ]; then
    sudo pacman -S --needed --noconfirm linux-zen-headers
fi

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

yay -S --answerclean A --answerdiff N --removemake --cleanafter --save

echo ""
read -r -p "Do you want to install Intel drivers? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel #Intel
fi

echo ""
read -r -p "Do you want to install AMD/ATI drivers? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm mesa xf86-video-amdgpu xf86-video-ati libva-mesa-driver vulkan-radeon amdvlk #AMD/ATI
fi

echo ""
read -r -p "Do you want to install Nvidia drivers(Maxwell+)? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm nvidia-dkms nvidia-utils nvidia-settings nvidia-prime opencl-nvidia switcheroo-control #NVIDIA
    #sudo sed -i 's/MODULES=\(.*\)/MODULES=\(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    #sudo mkinitcpio -P
    sudo systemctl enable nvidia-persistenced switcheroo-control

    echo ""
    read -r -p "Do you want to install Envy Control(from AUR)? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        yay -S --needed --noconfirm envycontrol
	sudo envycontrol --cache-create
	sudo envycontrol --cache-query
        #sudo envycontrol -s integrated
    fi
fi

echo ""
sudo pacman -S --needed --noconfirm - <tpkg
sudo systemctl enable touchegg
sudo systemctl enable --now ufw
sudo systemctl enable --now cups
sudo cp smb.conf /etc/samba/
hn=$(hostname)
echo -e "netbios name = $hn\n" | sudo tee -a /etc/samba/smb.conf > /dev/null
echo ""
sudo smbpasswd -a $un
echo ""
sudo systemctl enable smb nmb
sudo cp cups /etc/ufw/applications.d/
sudo cp gsconnect /etc/ufw/applications.d/
sudo cp samba /etc/ufw/applications.d/
sudo cupsctl
sudo ufw enable
sudo ufw app update CUPS
sudo ufw allow CUPS
sudo ufw app update GSConnect
sudo ufw allow GSConnect
sudo ufw app update SMB
sudo ufw allow SMB
sudo ufw allow CIFS
sudo systemctl enable sshd avahi-daemon
sudo cp /usr/share/doc/avahi/ssh.service /etc/avahi/services/
sudo ufw allow SSH
chsh -s /bin/fish
sudo chsh -s /bin/fish
pipx ensurepath
#register-python-argcomplete --shell fish pipx >~/.config/fish/completions/pipx.fish

echo ""
read -r -p "Do you want to create a Samba Shared folder? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    un=$(whoami)
    hn=$(hostname)
    sudo cp smb.conf /etc/samba/
    echo -e "netbios name = $hn\n" | sudo tee -a /etc/samba/smb.conf > /dev/null
    echo -e "[Samba Share]\ncomment = Samba Share\npath = /home/$un/Samba Share\nwritable = yes\nbrowsable = yes\nguest ok = no" | sudo tee -a /etc/samba/smb.conf > /dev/null
    rm -rf ~/Samba\ Share
    mkdir ~/Samba\ Share
    sudo systemctl restart smb nmb
fi

#sudo sed -i 's/Logo=1/Logo=0/' /etc/libreoffice/sofficerc
echo -e "VISUAL=nvim\nEDITOR=nvim" | sudo tee /etc/environment > /dev/null
grep -qF "set number" /etc/xdg/nvim/sysinit.vim || echo "set number" | sudo tee -a /etc/xdg/nvim/sysinit.vim > /dev/null
grep -qF "set wrap!" /etc/xdg/nvim/sysinit.vim || echo "set wrap!" | sudo tee -a /etc/xdg/nvim/sysinit.vim > /dev/null

echo ""
echo "Installing Gnome..."
echo ""
sudo pacman -S --needed --noconfirm - < gnome
pacman -Sgq gnome | grep -vf rpkg | sudo pacman -S --needed --noconfirm -
if [ "$(pactree -r tlp)" ]; then
    echo ""
else
    sudo pacman -S --needed --noconfirm power-profiles-daemon
    sudo systemctl enable power-profiles-daemon
fi
sudo systemctl enable gdm
sudo -u gdm dbus-launch gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click 'true'
sudo -u gdm dbus-launch gsettings set org.gnome.desktop.peripherals.touchpad send-events disabled-on-external-mouse
gsettings set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click 'true'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
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
read -r -p "Do you want to install Firefox? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm firefox
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
    sudo pacman -S --needed --noconfirm hplip sane python-pillow rpcbind python-reportlab
    hp-plugin -i
fi

echo ""
read -r -p "Do you want to install Code-OSS? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm code
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
    wget -q -nc --show-progress https://github.com/ayu2805/cwi/releases/download/cloudflare-warp-install/cloudflare-warp-install && bash cloudflare-warp-install && rm cloudflare-warp-install
    echo ""
    echo "Waiting for 5 seconds..."
    sleep 5
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
    gnome-extensions enable apps-menu@gnome-shell-extensions.gcampax.github.com
    gnome-extensions enable system-monitor@gnome-shell-extensions.gcampax.github.com
    gnome-extensions enable workspace-indicator@gnome-shell-extensions.gcampax.github.com

    echo ""
    mkdir -p ~/.local/share/gnome-shell/extensions/
    
    wget -q -nc --show-progress https://github.com/stuarthayhurst/alphabetical-grid-extension/releases/latest/download/AlphabeticalAppGrid@stuarthayhurst.shell-extension.zip
    rm -rf ~/.local/share/gnome-shell/extensions/AlphabeticalAppGrid@stuarthayhurst/
    unzip -q AlphabeticalAppGrid@stuarthayhurst.shell-extension.zip -d ~/.local/share/gnome-shell/extensions/AlphabeticalAppGrid@stuarthayhurst/
    rm AlphabeticalAppGrid@stuarthayhurst.shell-extension.zip
    gnome-extensions enable AlphabeticalAppGrid@stuarthayhurst
    
    wget -q -nc --show-progress https://github.com/micheleg/dash-to-dock/releases/latest/download/dash-to-dock@micxgx.gmail.com.zip
    rm -rf ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/
    unzip -q dash-to-dock@micxgx.gmail.com.zip -d ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/
    rm dash-to-dock@micxgx.gmail.com.zip
    gnome-extensions enable dash-to-dock@micxgx.gmail.com
    gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas/ set org.gnome.shell.extensions.dash-to-dock show-trash false
    gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas/ set org.gnome.shell.extensions.dash-to-dock show-icons-emblems false
    gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas/ set org.gnome.shell.extensions.dash-to-dock apply-custom-theme true
    gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas set org.gnome.shell.extensions.dash-to-dock dance-urgent-applications false
    gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas/ set org.gnome.shell.extensions.dash-to-dock intellihide-mode \'ALL_WINDOWS\'
    gsettings --schemadir ~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas/ set org.gnome.shell.extensions.dash-to-dock click-action \'minimize\'
    
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
