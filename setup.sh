#!/bin/bash
# ~/dotfiles/setup.sh
# Bootstraps a minimal Fedora install into a bare Hyprland + Quickshell setup.
# No display manager: Hyprland is launched from a TTY login shell.

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

echo "== Installing seat management =="
# Without a display manager, Hyprland needs seatd to get device/session
# access when launched directly from a TTY login shell.
sudo dnf install -y seatd
sudo systemctl enable --now seatd
sudo usermod -aG seat "$USER" || true

echo "== Installing core packages =="
sudo dnf install -y \
    swaybg hypridle hyprlock \
    quickshell \
    qt6-qtsvg qt6-qtimageformats qt6-qtmultimedia qt6-qt5compat \
    pipewire-utils \
    NetworkManager-wifi bluez \
    lm_sensors \
    grim slurp wl-clipboard cliphist glib2 \
    nano kitty firefox

echo "== Installing JetBrainsMono Nerd Font =="
# Not installed via dnf: nerd-fonts package availability varies between
# Fedora editions, so a direct download is the portable path across editions.
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
sudo systemctl enable bluetooth

# No display manager: boot straight to a text login (skip if already set).
sudo systemctl set-default multi-user.target

echo "== Linking configs =="
mkdir -p ~/.config/hypr ~/.config/quickshell
ln -sf ~/dotfiles/hypr/hyprland.conf ~/.config/hypr/hyprland.conf
ln -sf ~/dotfiles/hypr/hyprlock.conf ~/.config/hypr/hyprlock.conf
ln -sf ~/dotfiles/hypr/hypridle.conf ~/.config/hypr/hypridle.conf
ln -sf ~/dotfiles/hypr/wallpaper.jpg ~/.config/hypr/wallpaper.jpg
ln -sf ~/dotfiles/quickshell/shell.qml ~/.config/quickshell/shell.qml

echo "== Setting dark theme defaults =="
# GTK env var covers most GTK3/GTK4 apps immediately.
if ! grep -q "GTK_THEME" ~/dotfiles/hypr/hyprland.conf 2>/dev/null; then
    echo "NOTE: add 'env = GTK_THEME,Adwaita:dark' to hyprland.conf manually if not already present."
fi

# Freedesktop color-scheme preference, checked by many GTK4/Flatpak apps
# via the desktop portal rather than the env var.
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true

# Explicit GTK settings files as a fallback for apps that check these
# directly instead of the env var or portal setting.
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0
cat > ~/.config/gtk-3.0/settings.ini << 'GTKEOF'
[Settings]
gtk-application-prefer-dark-theme=true
GTKEOF
cp ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini


echo "== Setting up TTY auto-start =="
# Launch Hyprland automatically on login at tty1, but only if not already
# in a graphical session (avoids relaunching if you nest shells, ssh in, etc).
PROFILE_SNIPPET='
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec start-hyprland
fi
'
if ! grep -q "exec start-hyprland" ~/.bash_profile 2>/dev/null; then
    echo "$PROFILE_SNIPPET" >> ~/.bash_profile
    echo "Added Hyprland auto-start to ~/.bash_profile"
else
    echo "~/.bash_profile already configured, skipping."
fi

echo "== Done =="
echo "Reboot now. Log in at the TTY1 text prompt and Hyprland will start automatically."
echo ""
echo "Known machine-specific things to check after first boot:"
echo "  - Wifi interface name is auto-detected at runtime, no action needed"
echo "  - Confirm 'wpctl status' shows your audio sink correctly"
echo "  - Confirm Nerd Font glyphs render (fc-list | grep -i \"JetBrainsMono Nerd\")"
echo "  - You were added to the 'seat' group; if permissions errors occur on first"
echo "    launch, log out fully and back in (group membership needs a fresh session)"
echo "  - Confirm hyprland.conf has: env = GTK_THEME,Adwaita:dark"
