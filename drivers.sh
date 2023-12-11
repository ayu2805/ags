#!/bin/sh

sudo cp pacman.conf /etc/
read -r -p "Do you want to install Intel drivers? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel #Intel
fi

echo ""
read -r -p "Do you want to install AMD/ATI drivers? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm mesa xf86-video-amdgpu xf86-video-ati libva-mesa-driver vulkan-radeon #AMD/ATI
fi

echo ""
read -r -p "Do you want to install Nvidia drivers? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm nvidia nvidia-utils nvidia-settings nvidia-prime opencl-nvidia #NVIDIA
    sudo systemctl enable nvidia-{suspend,resume,hibernate}

    echo ""
    read -r -p "Do you want to install Envy Control? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo ""
        if [ "$(pactree -r yay-bin)" ]; then
            yay -S --needed --noconfirm envycontrol
            sudo envycontrol -s integrated
        else
            git clone https://aur.archlinux.org/yay-bin.git --depth=1
            cd yay-bin
            yes | makepkg -si
            cd ..
            rm -rf yay-bin
            yay -S --needed --noconfirm envycontrol
            sudo envycontrol -s integrated
        fi

    fi

fi
