#!/bin/bash

# Ubuntu System Configurator
# Must be run with sudo privileges

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get real user info
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

LIBREOFFICE_PACKAGES=(
    "libreoffice-calc"
    "libreoffice-writer"
)

# User choices
INSTALL_PYTHON=false
INSTALL_C=false
INSTALL_VSCODE=false
INSTALL_ZED=false
INSTALL_SIGNAL=false
INSTALL_BITWARDEN=false
INSTALL_FREECAD=false
INSTALL_GNOME_BOXES=false
INSTALL_LIBREOFFICE=false

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

    VSCODE_DEB="/tmp/vscode.deb"

    # Видаляємо старий файл якщо існує
    rm -f "$VSCODE_DEB"

    # Спроба 1: curl з прогрес-баром
    if curl -L --fail --progress-bar -o "$VSCODE_DEB" \
        "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" 2>&1 | tee -a /tmp/configurator.log; then
        print_success "Download completed"
    else
        print_warning "curl failed, trying wget..."


        # Спроба 2: wget з прогрес-баром
        if wget --progress=bar:force --tries=3 --timeout=60 \
            -O "$VSCODE_DEB" \
            "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" 2>&1 | tee -a /tmp/configurator.log; then
            print_success "Download completed"
        else
            print_error "Failed to download VS Code"
            return 1
        fi
    fi

    # Перевірка чи файл завантажився
    if [ ! -f "$VSCODE_DEB" ] || [ ! -s "$VSCODE_DEB" ]; then
        print_error "VS Code .deb file is missing or empty"
        return 1
    fi

    # Встановлення
    print_info "Installing VS Code package..."
    if apt install -y "$VSCODE_DEB" >> /tmp/configurator.log 2>&1; then
        print_success "VS Code installed"
    else
        print_error "Failed to install VS Code (check /tmp/configurator.log)"
        rm -f "$VSCODE_DEB"
        return 1
    fi

    rm -f "$VSCODE_DEB"
}

install_zed() {
    print_info "Installing Zed editor..."
    su - $REAL_USER -c 'curl -f https://zed.dev/install.sh | sh'
    echo 'export PATH=$HOME/.local/bin:$PATH' >> "$USER_HOME/.bashrc"
    print_success "Zed installed"
}

install_flatapk_apps() {
    echo ""
    echo "--- Installing Flatpak Apps ---"
    if flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >> /tmp/configurator.log 2>&1; then
        print_success "Flathub repository added"
    else
        print_warning "Flathub repository may already exist"
    fi

    print_info "Installing Obsidian..."
    flatpak install -y flathub md.obsidian.Obsidian >> /tmp/configurator.log 2>&1 || print_warning "Obsidian installation failed"

    print_info "Installing Discord..."
    flatpak install -y flathub com.discordapp.Discord >> /tmp/configurator.log 2>&1 || print_warning "Discord installation failed"

    print_info "Installing qBittorrent..."
    flatpak install -y flathub org.qbittorrent.qBittorrent >> /tmp/configurator.log 2>&1 || print_warning "qBittorrent installation failed"

    if $INSTALL_BITWARDEN; then
        print_info "Installing Bitwarden..."
        flatpak install -y flathub com.bitwarden.desktop >> /tmp/configurator.log 2>&1 || print_warning "Bitwarden installation failed"
    fi

    if $INSTALL_FREECAD; then
        print_info "Installing FreeCad..."
        flatpak install -y flathub org.freecad.FreeCAD >> /tmp/configurator.log 2>&1 || print_warning "FreeCad installation failed"
    fi

    print_success "Flatpak apps installed"
}

ask_editor_choice() {
    local choice

    echo ""
    echo "========================================="
    echo "    Code Editor Selection"
    echo "========================================="
    echo "  1) Visual Studio Code"
    echo "  2) Zed"
    echo "  3) Skip (don't install any editor)"
    echo "========================================="

    while true; do
        read -p "$(echo -e ${BLUE}Select an option [1-3]:${NC} )" choice
        case $choice in
            1 )
                INSTALL_VSCODE=true
                print_success "Visual Studio Code selected"
                return 0
                ;;
            2 )
                INSTALL_ZED=true
                print_success "Zed selected"
                return 0
                ;;
            3 )
                print_info "Skipping code editor installation"
                return 0
                ;;
            * )
                echo "Please enter 1, 2, or 3."
                ;;
        esac
    done
}

install_signal() {
    echo ""
    echo "--- Installing Signal Desktop ---"
    print_info "Adding Signal repository..."

    if wget -O- https://updates.signal.org/desktop/apt/keys.asc 2>/dev/null | gpg --dearmor > /tmp/signal-desktop-keyring.gpg 2>&1; then
        cat /tmp/signal-desktop-keyring.gpg | tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null

        wget -O /tmp/signal-desktop.sources https://updates.signal.org/static/desktop/apt/signal-desktop.sources 2>/dev/null
        cat /tmp/signal-desktop.sources | tee /etc/apt/sources.list.d/signal-desktop.sources > /dev/null

        print_info "Installing Signal Desktop..."
        apt-get update >> /tmp/configurator.log 2>&1

        if apt-get install -y signal-desktop >> /tmp/configurator.log 2>&1; then
            print_success "Signal Desktop installed"
        else
            print_warning "Signal installation failed"
        fi

        rm -f /tmp/signal-desktop-keyring.gpg /tmp/signal-desktop.sources
    else
        print_warning "Failed to add Signal repository"
    fi
}

install_gnome_boxes() {
    echo ""
    echo "--- Installing GNOME Boxes ---"
    print_info "Installing GNOME Boxes (Virtual Machine Manager)..."

    if apt-get install -y gnome-boxes >> /tmp/configurator.log 2>&1; then
        print_success "GNOME Boxes installed"
    else
        print_error "GNOME Boxes installation failed"
        return 1
    fi
}

main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
       echo -e "${RED}This script must be run as root (use sudo)${NC}"
       exit 1
    fi

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

    #Ask for code editor choice FIRST
    ask_editor_choice

    if ask_yes_no "Install Signal desktop?"; then
        INSTALL_SIGNAL=true
    fi

    if ask_yes_no "Install Bitwarden?"; then
        INSTALL_BITWARDEN=true
    fi

    if ask_yes_no "Install FreeCad?"; then
        INSTALL_FREECAD=true
    fi

     if ask_yes_no "Install GNOME Boxes (Virtual Machines)?"; then
         INSTALL_GNOME_BOXES=true
     fi

     if ask_yes_no "Install LibreOffice Calc and Writer?"; then
         INSTALL_LIBREOFFICE=true
     fi

    echo ""
    echo "========================================="
    echo "Installation Summary:"
    echo "========================================="
    $INSTALL_PYTHON && echo "  ✓ Python development tools"
    $INSTALL_C && echo "  ✓ C/C++ development tools"
    $INSTALL_VSCODE && echo "  ✓ Visual Studio Code"
    $INSTALL_ZED && echo "  ✓ Zed editor"
    $INSTALL_SIGNAL && echo "  ✓ Signal"
    $INSTALL_BITWARDEN && echo "  ✓ Bitwarden"
    $INSTALL_FREECAD && echo "  ✓ FreeCad"
    $INSTALL_GNOME_BOXES && echo "  ✓ GNOME Boxes"
    $INSTALL_LIBREOFFICE && echo "  ✓ LibreOffice Calc and Writer"
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
    if apt-get update >> /tmp/configurator.log 2>&1; then
        print_success "Package list updated"
    else
        print_warning "apt-get update had some issues, continuing anyway..."
    fi

    # Install selected packages
    echo ""
    echo "--- Starting Installation ---"

    # Default packages
    print_info "Installing base packages..."
    for pkg in flatpak wget curl git vlc openssh-client; do
        if apt-get install -y "$pkg" >> /tmp/configurator.log 2>&1; then
            print_success "$pkg installed"
        else
            print_warning "$pkg failed to install (may already be installed)"
        fi
    done

    # Flatpak
    install_flatapk_apps

    # Development tools
    if $INSTALL_PYTHON; then
        echo ""
        install_packages "Python" "${PYTHON_PACKAGES[@]}"
    fi

    if $INSTALL_C; then
        echo ""
        install_packages "C/C++" "${C_PACKAGES[@]}"
    fi

    if $INSTALL_VSCODE; then
        echo ""
        echo "--- Installing Visual Studio Code ---"
        install_vscode || print_error "VS Code installation failed, continuing..."
    fi

    if $INSTALL_ZED; then
        echo ""
        echo "--- Installing Zed Editor ---"
        install_zed || print_error "Zed installation failed, continuing..."
    fi

    # Signal Messenger
    if $INSTALL_SIGNAL; then
        echo ""
        install_signal
    fi

    # GNOME Boxes
    if $INSTALL_GNOME_BOXES; then
        echo ""
        install_gnome_boxes
    fi

    # LibreOffice
    if $INSTALL_LIBREOFFICE; then
        echo ""
        install_packages "LibreOffice" "${LIBREOFFICE_PACKAGES[@]}"
    fi

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
    $INSTALL_PYTHON && python3 --version 2>/dev/null && pip3 --version 2>/dev/null
    $INSTALL_C && gcc --version 2>/dev/null | head -1
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
}

main
