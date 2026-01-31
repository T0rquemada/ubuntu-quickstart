#!/bin/bash

# Ubuntu System Configurator
# Must be run with sudo privileges

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo)${NC}" 
   exit 1
fi

USER_HOME="/home/$(whoami)"

# Print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Package arrays
PYTHON_PACKAGES=(
    "python3"
    "python3-pip"
    "python3-venv"
    "python3-dev"
)

C_PACKAGES=(
    "build-essential"
    "gcc"
    "g++"
    "make"
    "cmake"
)

# User choices
INSTALL_PYTHON=false
INSTALL_C=false
INSTALL_VSCODE=false

# Function to ask yes/no question
ask_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "$(echo -e ${BLUE}${prompt}${NC} [y/n]: )" response
        case $response in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Function to install packages from array
install_packages() {
    local category="$1"
    shift
    local packages=("$@")
    
    print_info "Installing $category packages..."
    
    for package in "${packages[@]}"; do
        print_info "Installing: $package"
        if apt-get install -y "$package" >> /tmp/configurator.log 2>&1; then
            print_success "$package installed"
        else
            print_warning "Failed to install $package (check /tmp/configurator.log)"
        fi
    done
}


# Function to install VS Code
install_vscode() {
    print_info "Installing Visual Studio Code..."
    
    curl -L -o vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
    sudo apt install ./vscode.deb -y
    rm vscode.deb
}

# Main script
clear
echo "========================================="
echo "    Ubuntu System Configurator"
echo "========================================="
echo ""

print_info "This script will set up ubuntu system."
print_warning "Make sure you have an active internet connection."
echo ""

echo "--- Create Directories ---"
mkdir -p "$USER_HOME/Programs"

# Ask user for preferences
echo "--- Development Environments ---"
if ask_yes_no "Install Python development tools?"; then
    INSTALL_PYTHON=true
fi

if ask_yes_no "Install C/C++ development tools?"; then
    INSTALL_C=true
fi

echo ""
echo "--- Development Tools ---"
if ask_yes_no "Install Visual Studio Code?"; then
    INSTALL_VSCODE=true
fi

echo ""
echo "========================================="
echo "Installation Summary:"
echo "========================================="
$INSTALL_PYTHON && echo "  ✓ Python development tools"
$INSTALL_C && echo "  ✓ C/C++ development tools"
$INSTALL_VSCODE && echo "  ✓ Visual Studio Code"
echo "========================================="
echo ""

if ! ask_yes_no "Proceed with installation?"; then
    print_warning "Installation cancelled by user"
    exit 0
fi

# Clear log file
> /tmp/configurator.log

# Update package list
print_info "Updating package list..."
apt-get update >> /tmp/configurator.log 2>&1
print_success "Package list updated"

# Install selected packages
echo ""
echo "--- Starting Installation ---"

# Default packages
apt-get install -y flatpak wget curl git vlc ssh

# Flatpak
echo "--- Installing flatpak apps ---"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub md.obsidian.Obsidian
flatpak install flathub com.discordapp.Discord
flatpak install flathub org.qbittorrent.qBittorrent

if $INSTALL_PYTHON; then
    install_packages "Python" "${PYTHON_PACKAGES[@]}"
    echo ""
fi

if $INSTALL_PYTHON; then
    install_packages "C/C++" "${C_PACKAGES[@]}"
    echo ""
fi

if $INSTALL_VSCODE; then
    install_vscode
    echo ""
fi

# Signal Messanger
echo "--- Install Signal ----"
wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-desktop-keyring.gpg;
cat signal-desktop-keyring.gpg | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null

wget -O signal-desktop.sources https://updates.signal.org/static/desktop/apt/signal-desktop.sources;
cat signal-desktop.sources | sudo tee /etc/apt/sources.list.d/signal-desktop.sources > /dev/null

apt update && sudo apt install signal-desktop

# Final cleanup
print_info "Cleaning up..."
apt-get autoremove -y >> /tmp/configurator.log 2>&1
apt-get autoclean -y >> /tmp/configurator.log 2>&1

echo ""
echo "========================================="
print_success "Installation Complete!"
echo "========================================="
print_info "Log file saved to: /tmp/configurator.log"

# Show installed versions
echo ""
echo "--- Installed Versions ---"
$INSTALL_PYTHON && python3 --version 2>/dev/null && pip3 --version 2>/dev/null
$INSTALL_C && gcc --version | head -1 2>/dev/null
$INSTALL_VSCODE && code --version | head -1 2>/dev/null

# Set GRUB timeout to 0 seconds
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
update-grub

echo ""
print_success "All done! You may need to restart your session for some changes to take effect."