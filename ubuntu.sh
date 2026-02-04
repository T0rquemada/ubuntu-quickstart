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
INSTALL_OBSIDIAN=false
INSTALL_DISCORD=false
INSTALL_QBITTORRENT=false

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

    if apt-get install -y "${packages[@]}" >> /tmp/configurator.log 2>&1; then
        print_success "$category packages installed"
    else
        print_warning "Bulk install failed, trying individually..."
        for package in "${packages[@]}"; do
            print_info "Installing: $package"
            if apt-get install -y "$package" >> /tmp/configurator.log 2>&1; then
                print_success "$package installed"
            else
                print_warning "Failed to install $package (check /tmp/configurator.log)"
            fi
        done
    fi
}

# Function to install VS Code
install_vscode() {
    if command -v code >/dev/null 2>&1; then
        print_warning "VS Code is already installed. Skipping..."
        return 0
    fi

    print_info "Installing Visual Studio Code..."
    VSCODE_DEB="/tmp/vscode.deb"
    rm -f "$VSCODE_DEB"

    # Try curl first
    if curl -L --fail --progress-bar -o "$VSCODE_DEB" \
        "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" 2>&1 | tee -a /tmp/configurator.log; then
        print_success "Download completed"
    # Fallback to wget
    elif wget --progress=bar:force --tries=3 --timeout=60 \
        -O "$VSCODE_DEB" \
        "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" 2>&1 | tee -a /tmp/configurator.log; then
        print_success "Download completed"
    else
        print_error "Failed to download VS Code"
        return 1
    fi

    if [ ! -s "$VSCODE_DEB" ]; then
        print_error "VS Code .deb file is missing or empty"
        return 1
    fi

    print_info "Installing VS Code package..."
    if apt install -y "$VSCODE_DEB" >> /tmp/configurator.log 2>&1; then
        print_success "VS Code installed"
    else
        print_error "Failed to install VS Code"
        rm -f "$VSCODE_DEB"
        return 1
    fi
    rm -f "$VSCODE_DEB"
}

install_zed() {
    print_info "Installing Zed editor..."
    # Check if already installed to avoid redundant download
    if [ -f "$USER_HOME/.local/bin/zed" ]; then
        print_warning "Zed appears to be installed already."
    else
        su - $REAL_USER -c 'curl -f https://zed.dev/install.sh | sh'
    fi
    
    # Check if PATH is already exported to prevent duplicates
    if ! grep -q "export PATH=\$HOME/.local/bin:\$PATH" "$USER_HOME/.bashrc"; then
        echo 'export PATH=$HOME/.local/bin:$PATH' >> "$USER_HOME/.bashrc"
        print_success "Zed path added to .bashrc"
    else
        print_warning "Zed path already exists in .bashrc"
    fi
    
    print_success "Zed configuration checked"
}

install_flatapk_apps() {
    echo ""
    echo "--- Installing Flatpak Apps ---"
    
    # Ensure flatpak is installed first
    if ! command -v flatpak >/dev/null 2>&1; then
        apt-get install -y flatpak >> /tmp/configurator.log 2>&1
    fi

    if flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >> /tmp/configurator.log 2>&1; then
        print_success "Flathub repository checked"
    fi

    if $INSTALL_OBSIDIAN; then
        print_info "Installing Obsidian..."
        flatpak install -y flathub md.obsidian.Obsidian >> /tmp/configurator.log 2>&1 || print_warning "Obsidian installation failed"
    fi

    if $INSTALL_DISCORD; then
        print_info "Installing Discord..."
        flatpak install -y flathub com.discordapp.Discord >> /tmp/configurator.log 2>&1 || print_warning "Discord installation failed"
    fi

    if $INSTALL_QBITTORRENT; then
        print_info "Installing qBittorrent..."
        flatpak install -y flathub org.qbittorrent.qBittorrent >> /tmp/configurator.log 2>&1 || print_warning "qBittorrent installation failed"
    fi

    if $INSTALL_BITWARDEN; then
        print_info "Installing Bitwarden..."
        flatpak install -y flathub com.bitwarden.desktop >> /tmp/configurator.log 2>&1 || print_warning "Bitwarden installation failed"
    fi

    if $INSTALL_FREECAD; then
        print_info "Installing FreeCad..."
        flatpak install -y flathub org.freecad.FreeCAD >> /tmp/configurator.log 2>&1 || print_warning "FreeCad installation failed"
    fi
    
    print_success "Flatpak apps processing complete"
}

ask_editor_choice() {
    local choice

    echo ""
    echo "========================================="
    echo "    Code Editor Selection"
    echo "========================================="
    echo "  1) Visual Studio Code"
    echo "  2) Zed"
    echo "  3) Both"
    echo "  4) Skip"
    echo "========================================="

    while true; do
        read -p "$(echo -e ${BLUE}Select an option [1-4]:${NC} )" choice
        case $choice in
            1 ) INSTALL_VSCODE=true; return 0 ;;
            2 ) INSTALL_ZED=true; return 0 ;;
            3 ) INSTALL_VSCODE=true; INSTALL_ZED=true; return 0 ;;
            4 ) print_info "Skipping code editors"; return 0 ;;
            * ) echo "Please enter 1, 2, 3 or 4." ;;
        esac
    done
}

install_signal() {
    echo ""
    echo "--- Installing Signal Desktop ---"
    print_info "Adding Signal repository..."

    # Download key only if missing
    if [ ! -f /usr/share/keyrings/signal-desktop-keyring.gpg ]; then
        if wget -O- https://updates.signal.org/desktop/apt/keys.asc 2>/dev/null | gpg --dearmor > /tmp/signal-desktop-keyring.gpg 2>&1; then
            cat /tmp/signal-desktop-keyring.gpg | tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null
            rm -f /tmp/signal-desktop-keyring.gpg
        else
            print_error "Failed to download Signal key"
            return 1
        fi
    fi

    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" | \
        tee /etc/apt/sources.list.d/signal-desktop.sources > /dev/null

    print_info "Updating apt cache for Signal..."
    apt-get update >> /tmp/configurator.log 2>&1

    if apt-get install -y signal-desktop >> /tmp/configurator.log 2>&1; then
        print_success "Signal Desktop installed"
    else
        print_warning "Signal installation failed"
    fi
}

install_gnome_boxes() {
    echo ""
    echo "--- Installing GNOME Boxes ---"
    if apt-get install -y gnome-boxes >> /tmp/configurator.log 2>&1; then
        print_success "GNOME Boxes installed"
    else
        print_error "GNOME Boxes installation failed"
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
    
    # Check internet
    if ! ping -c 1 google.com &> /dev/null; then
        print_error "No internet connection detected!"
        exit 1
    fi

    echo ""
    echo "--- Create Directories ---"
    # Only create if they don't exist
    [ ! -d "$USER_HOME/Programs" ] && mkdir -p "$USER_HOME/Programs"
    [ ! -d "$USER_HOME/SDK" ] && mkdir -p "$USER_HOME/SDK"

    chown $REAL_USER:$REAL_USER "$USER_HOME/Programs"
    chown $REAL_USER:$REAL_USER "$USER_HOME/SDK"

    # Ask user for preferences
    echo "--- Development Environments ---"
    ask_yes_no "Install Python development tools?" && INSTALL_PYTHON=true
    ask_yes_no "Install C/C++ development tools?" && INSTALL_C=true

    ask_editor_choice

    echo ""
    echo "--- Applications ---"
    ask_yes_no "Install Signal desktop?" && INSTALL_SIGNAL=true
    ask_yes_no "Install Bitwarden?" && INSTALL_BITWARDEN=true
    ask_yes_no "Install FreeCad?" && INSTALL_FREECAD=true
    ask_yes_no "Install Obsidian?" && INSTALL_OBSIDIAN=true
    ask_yes_no "Install Discord?" && INSTALL_DISCORD=true
    ask_yes_no "Install qBittorrent?" && INSTALL_QBITTORRENT=true
    ask_yes_no "Install GNOME Boxes?" && INSTALL_GNOME_BOXES=true
    ask_yes_no "Install LibreOffice?" && INSTALL_LIBREOFFICE=true

    echo ""
    echo "========================================="
    echo "Installation Summary:"
    echo "========================================="
    $INSTALL_PYTHON && echo "  ✓ Python tools"
    $INSTALL_C && echo "  ✓ C/C++ tools"
    $INSTALL_VSCODE && echo "  ✓ Visual Studio Code"
    $INSTALL_ZED && echo "  ✓ Zed editor"
    $INSTALL_SIGNAL && echo "  ✓ Signal"
    $INSTALL_BITWARDEN && echo "  ✓ Bitwarden"
    $INSTALL_FREECAD && echo "  ✓ FreeCad"
    $INSTALL_OBSIDIAN && echo "  ✓ Obsidian"
    $INSTALL_DISCORD && echo "  ✓ Discord"
    $INSTALL_QBITTORRENT && echo "  ✓ qBittorrent"
    $INSTALL_GNOME_BOXES && echo "  ✓ GNOME Boxes"
    $INSTALL_LIBREOFFICE && echo "  ✓ LibreOffice"
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
        print_warning "apt-get update had issues (check log)"
    fi

    # Install base packages
    echo ""
    echo "--- Starting Installation ---"
    print_info "Installing base packages..."
    # Installed all in one go for efficiency
    if apt-get install -y flatpak wget curl git vlc openssh-client >> /tmp/configurator.log 2>&1; then
        print_success "Base packages installed"
    else
        print_warning "Base packages installation had issues"
    fi

    # Run installation groups
    install_flatapk_apps

    if $INSTALL_PYTHON; then echo ""; install_packages "Python" "${PYTHON_PACKAGES[@]}"; fi
    if $INSTALL_C; then echo ""; install_packages "C/C++" "${C_PACKAGES[@]}"; fi
    
    if $INSTALL_VSCODE; then echo ""; install_vscode; fi
    if $INSTALL_ZED; then echo ""; install_zed; fi
    if $INSTALL_SIGNAL; then echo ""; install_signal; fi
    if $INSTALL_GNOME_BOXES; then echo ""; install_gnome_boxes; fi
    if $INSTALL_LIBREOFFICE; then echo ""; install_packages "LibreOffice" "${LIBREOFFICE_PACKAGES[@]}"; fi

    # Final cleanup
    echo ""
    print_info "Cleaning up..."
    apt-get autoremove -y >> /tmp/configurator.log 2>&1
    apt-get autoclean -y >> /tmp/configurator.log 2>&1

    # Show installed versions
    echo ""
    echo "========================================="
    echo "--- Status Check ---"
    echo "========================================="
    $INSTALL_PYTHON && echo "Python: $(python3 --version 2>/dev/null)"
    $INSTALL_C && echo "GCC: $(gcc --version 2>/dev/null | head -1 | awk '{print $4}')"
    echo "========================================="

    # GRUB Config
    echo ""
    print_info "Configuring GRUB timeout..."
    # Use 1 instead of 0 to allow emergency recovery if needed
    sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
    update-grub >> /tmp/configurator.log 2>&1
    print_success "GRUB timeout set to 1s"

    echo ""
    print_success "All done! Log file: /tmp/configurator.log"
    echo "Please restart your session."
}

main