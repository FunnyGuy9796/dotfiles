#!/bin/bash
# ~/dotfiles/setup.sh
# Bootstraps a minimal Fedora install into the full Hyprland + Quickshell rice.

set -e

echo "== Base system check =="

# Ensure NetworkManager is present and running (may be missing on a
# minimal/netinstall base that isn't Server edition).
if ! rpm -q NetworkManager &>/dev/null; then
    echo "Installing NetworkManager..."
    sudo dnf install -y NetworkManager
fi
sudo systemctl enable --now NetworkManager

# Basic tooling used by the rest of this script / general sanity.
sudo dnf install -y git curl unzip

echo "== Enabling COPRs =="
sudo dnf copr enable -y ashbuk/Hyprland-Fedora
sudo dnf copr enable -y errornointernet/quickshell

echo "== Installing Hyprland core =="
# Installed separately from the rest: xdg-desktop-portal-hyprland can pin to
# an exact hyprland version that lags behind the COPR's latest build, which
# causes a same-transaction conflict if bundled with the bulk install below.
sudo dnf install -y hyprland
sudo dnf install -y xdg-desktop-portal-hyprland

echo "== Installing remaining packages =="
sudo dnf install -y \
    swaybg hypridle hyprlock \
    quickshell \
    qt6-qtsvg qt6-qtimageformats qt6-qtmultimedia qt6-qt5compat \
    qt6ct qt5ct kvantum \
    plasma-integration plasma-breeze plasma-breeze-qt6 qqc2-breeze-style breeze-icon-theme breeze-gtk \
    sddm sddm-breeze \
    pipewire-utils \
    NetworkManager-wifi bluez

echo "== Installing JetBrainsMono Nerd Font =="
# Not installed via dnf: nerd-fonts package availability varies between
# Fedora editions (e.g. present on Workstation, absent on this Server repo
# set), so a direct download is the portable path across editions.
if [ ! -d ~/.local/share/fonts/JetBrainsMonoNerd ]; then
    mkdir -p ~/.local/share/fonts
    cd ~/.local/share/fonts
    curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -q JetBrainsMono.zip -d JetBrainsMonoNerd
    rm JetBrainsMono.zip
    fc-cache -f
    cd - > /dev/null
else
    echo "Already installed, skipping."
fi

echo "== Enabling system services =="
sudo systemctl enable sddm
sudo systemctl enable bluetooth

echo "== Setting SDDM theme =="
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/theme.conf > /dev/null <<EOF
[Theme]
Current=breeze
EOF

echo "== Linking configs =="
mkdir -p ~/.config/hypr ~/.config/quickshell
ln -sf ~/dotfiles/hypr/hyprland.conf ~/.config/hypr/hyprland.conf
ln -sf ~/dotfiles/hypr/hyprlock.conf ~/.config/hypr/hyprlock.conf
ln -sf ~/dotfiles/hypr/hypridle.conf ~/.config/hypr/hypridle.conf
ln -sf ~/dotfiles/quickshell/shell.qml ~/.config/quickshell/shell.qml

echo "== Done =="
echo "Reboot now. At the SDDM login screen, select the Hyprland session."
echo ""
echo "Known machine-specific things to check after first boot:"
echo "  - Wifi interface name is auto-detected at runtime, no action needed"
echo "  - Confirm 'wpctl status' shows your audio sink correctly"
echo "  - Confirm Nerd Font glyphs render (fc-list | grep -i \"JetBrainsMono Nerd\")"
