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

# Get real user info (ВАЖЛИВО: не root!)
if [ -n "$SUDO_USER" ]; then
    REAL_USER=$SUDO_USER
    USER_HOME=$(eval echo ~$SUDO_USER)
else
    REAL_USER=$USER
    USER_HOME=$HOME
fi

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
INSTALL_ANDROID_STUDIO=false

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
    
    # Завантажуємо в /tmp щоб уникнути проблем з правами
    VSCODE_DEB="/tmp/vscode.deb"
    
    curl -L -o "$VSCODE_DEB" "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
    apt install -y "$VSCODE_DEB" >> /tmp/configurator.log 2>&1
    rm -f "$VSCODE_DEB"
    
    print_success "VS Code installed"
    
    # Встановлюємо розширення від імені користувача (не root!)
    print_info "Installing VS Code extensions..."
    su - $REAL_USER -c "code --install-extension eamodio.gitlens" >> /tmp/configurator.log 2>&1
    
    print_success "VS Code extensions installed"
}

install_android_studio() {
    print_info "Installing Android Studio..."
    
    # Перевірка залежностей (необхідні 32-бітні бібліотеки для Ubuntu 64-bit)
    print_info "Installing required dependencies..."
    apt-get install -y libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1 libbz2-1.0:i386 >> /tmp/configurator.log 2>&1
    
    # URL для завантаження
    ANDROID_STUDIO_VERSION="2025.2.3.9"
    ANDROID_STUDIO_URL="https://edgedl.me.gvt1.com/android/studio/ide-zips/${ANDROID_STUDIO_VERSION}/android-studio-${ANDROID_STUDIO_VERSION}-linux.tar.gz"
    
    DOWNLOAD_PATH="/tmp/android-studio.tar.gz"
    INSTALL_PATH="/opt/android-studio"
    
    # Завантаження
    print_info "Downloading Android Studio (this may take several minutes)..."
    if wget --progress=bar:force -O "$DOWNLOAD_PATH" "$ANDROID_STUDIO_URL" 2>&1 | tee -a /tmp/configurator.log; then
        print_success "Download completed"
    else
        print_error "Failed to download Android Studio"
        return 1
    fi
    
    # Видалення старої версії якщо існує
    if [ -d "$INSTALL_PATH" ]; then
        print_warning "Removing old Android Studio installation..."
        rm -rf "$INSTALL_PATH"
    fi
    
    # Розпакування
    print_info "Extracting Android Studio..."
    tar -xzf "$DOWNLOAD_PATH" -C /tmp/ >> /tmp/configurator.log 2>&1
    
    # Переміщення до /opt
    print_info "Installing to $INSTALL_PATH..."
    mv /tmp/android-studio "$INSTALL_PATH"
    
    # Створення symbolic link для легкого запуску
    print_info "Creating launcher..."
    ln -sf "$INSTALL_PATH/bin/studio.sh" /usr/local/bin/android-studio
    
    # Створення desktop entry
    cat > /usr/share/applications/android-studio.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Icon=$INSTALL_PATH/bin/studio.png
Exec="$INSTALL_PATH/bin/studio.sh" %f
Comment=The official Android IDE
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-studio
EOF
    
    # Очищення
    rm -f "$DOWNLOAD_PATH"
    
    print_success "Android Studio installed successfully"
    print_info "Launch it with: android-studio"
    print_info "Or find it in your applications menu"
}

# Main script
clear
echo "========================================="
echo "    Ubuntu System Configurator"
echo "========================================="
echo ""

print_info "Installing for user: $REAL_USER"
print_info "Home directory: $USER_HOME"
print_warning "Make sure you have an active internet connection."
echo ""

echo "--- Create Directories ---"
mkdir -p "$USER_HOME/Programs"
mkdir -p "$USER_HOME/SDK"

# Налаштовуємо права для користувача
chown $REAL_USER:$REAL_USER "$USER_HOME/Programs"
chown $REAL_USER:$REAL_USER "$USER_HOME/SDK"

# Ask user for preferences
echo "--- Development Environments ---"
if ask_yes_no "Install Python development tools?"; then
    INSTALL_PYTHON=true
fi

if ask_yes_no "Install C/C++ development tools?"; then
    INSTALL_C=true
fi

if ask_yes_no "Install Android Studio?"; then
    INSTALL_ANDROID_STUDIO=true
fi

echo ""
echo "========================================="
echo "Installation Summary:"
echo "========================================="
$INSTALL_PYTHON && echo "  ✓ Python development tools"
$INSTALL_C && echo "  ✓ C/C++ development tools"
$INSTALL_ANDROID_STUDIO && echo "  ✓ Android Studio"
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
print_info "Installing base packages..."
apt-get install -y flatpak wget curl git vlc ssh >> /tmp/configurator.log 2>&1
print_success "Base packages installed"

# Flatpak
echo ""
echo "--- Installing Flatpak Apps ---"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >> /tmp/configurator.log 2>&1

print_info "Installing Obsidian..."
flatpak install -y flathub md.obsidian.Obsidian >> /tmp/configurator.log 2>&1

print_info "Installing Discord..."
flatpak install -y flathub com.discordapp.Discord >> /tmp/configurator.log 2>&1

print_info "Installing qBittorrent..."
flatpak install -y flathub org.qbittorrent.qBittorrent >> /tmp/configurator.log 2>&1

print_success "Flatpak apps installed"

# Development tools
if $INSTALL_PYTHON; then
    echo ""
    install_packages "Python" "${PYTHON_PACKAGES[@]}"
fi

if $INSTALL_C; then
    echo ""
    install_packages "C/C++" "${C_PACKAGES[@]}"
fi

# VS Code
echo ""
echo "--- Installing Visual Studio Code ---"
install_vscode

# Android Studio
if $INSTALL_ANDROID_STUDIO; then
    echo ""
    echo "--- Installing Android Studio ---"
    install_android_studio
fi

# Signal Messenger
echo ""
echo "--- Installing Signal Desktop ---"
print_info "Adding Signal repository..."

wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > /tmp/signal-desktop-keyring.gpg
cat /tmp/signal-desktop-keyring.gpg | tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null

wget -O /tmp/signal-desktop.sources https://updates.signal.org/static/desktop/apt/signal-desktop.sources
cat /tmp/signal-desktop.sources | tee /etc/apt/sources.list.d/signal-desktop.sources > /dev/null

print_info "Installing Signal Desktop..."
apt-get update >> /tmp/configurator.log 2>&1
apt-get install -y signal-desktop >> /tmp/configurator.log 2>&1

# Очищення тимчасових файлів Signal
rm -f /tmp/signal-desktop-keyring.gpg /tmp/signal-desktop.sources

print_success "Signal Desktop installed"

# Final cleanup
echo ""
print_info "Cleaning up..."
apt-get autoremove -y >> /tmp/configurator.log 2>&1
apt-get autoclean -y >> /tmp/configurator.log 2>&1

# Show installed versions
echo ""
echo "========================================="
echo "--- Installed Versions ---"
echo "========================================="
$INSTALL_PYTHON && echo "Python: $(python3 --version 2>/dev/null)" && echo "pip: $(pip3 --version 2>/dev/null)"
$INSTALL_C && echo "GCC: $(gcc --version 2>/dev/null | head -1)"
echo "========================================="

# Set GRUB timeout to 0 seconds
echo ""
print_info "Configuring GRUB timeout..."
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
update-grub >> /tmp/configurator.log 2>&1
print_success "GRUB configured"

echo ""
echo "========================================="
print_success "Installation Complete!"
echo "========================================="
print_info "Log file saved to: /tmp/configurator.log"
echo ""
print_success "All done! You may need to restart your session for some changes to take effect."