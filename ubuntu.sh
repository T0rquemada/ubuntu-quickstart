#!/bin/bash

# Ubuntu System Configurator
# Must be run with sudo privileges

# Source installation functions
source "$(dirname "$0")/install_functions.sh"

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

PHP_PACKAGES=(
    "php"
    "composer"
    "php-curl"
    "php-xml"
)

LIBREOFFICE_PACKAGES=(
    "libreoffice-calc"
    "libreoffice-writer"
)

# User choices
INSTALL_PYTHON=false
INSTALL_C=false
INSTALL_PHP=false
INSTALL_VSCODE=false
INSTALL_ZED=false
INSTALL_WINDSURF=false
INSTALL_SIGNAL=false
INSTALL_BITWARDEN=false
INSTALL_FREECAD=false
INSTALL_GNOME_BOXES=false
INSTALL_LIBREOFFICE=false
INSTALL_OBSIDIAN=false
INSTALL_DISCORD=false
INSTALL_QBITTORRENT=false
INSTALL_ANDROID_STUDIO=false
INSTALL_BRAVE=false
INSTALL_MULLVAD_BROWSER=false

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

ask_browser_choice() {
    local choice

    echo ""
    echo "========================================="
    echo "    Web Browser"
    echo "========================================="
    echo "  1) Keep Firefox (default Ubuntu browser)"
    echo "  2) Install Brave (Firefox will be removed after install)"
    echo "  3) Install Mullvad Browser stable (Firefox will be removed after install)"
    echo "========================================="

    while true; do
        read -p "$(echo -e ${BLUE}Select an option [1-3]:${NC} )" choice
        case $choice in
            1 ) print_info "Keeping Firefox"; return 0 ;;
            2 ) INSTALL_BRAVE=true; return 0 ;;
            3 ) INSTALL_MULLVAD_BROWSER=true; return 0 ;;
            * ) echo "Please enter 1, 2, or 3." ;;
        esac
    done
}

ask_editor_choice() {
    local choice

    echo ""
    echo "========================================="
    echo "    Code Editor Selection"
    echo "========================================="
    echo "  1) Visual Studio Code"
    echo "  2) Zed"
    echo "  3) Windsurf"
    echo "  4) Skip"
    echo "========================================="

    while true; do
        read -p "$(echo -e ${BLUE}Select an option [1-4]:${NC} )" choice
        case $choice in
            1 ) INSTALL_VSCODE=true; return 0 ;;
            2 ) INSTALL_ZED=true; return 0 ;;
            3 ) INSTALL_WINDSURF=true; return 0 ;;
            4 ) print_info "Skipping code editors"; return 0 ;;
            * ) echo "Please enter 1, 2, 3 or 4." ;;
        esac
    done
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

    chown $REAL_USER:$REAL_USER "$USER_HOME/Programs"
    chown $REAL_USER:$REAL_USER "$USER_HOME/SDK"

    # Ask user for preferences
    echo "--- Development Environments ---"
    ask_yes_no "Install Python development tools?" && INSTALL_PYTHON=true
    ask_yes_no "Install C/C++ development tools?" && INSTALL_C=true
    ask_yes_no "Install PHP development tools?" && INSTALL_PHP=true

    ask_editor_choice
    ask_yes_no "Install Android Studio?" && INSTALL_ANDROID_STUDIO=true

    echo ""
    echo "--- Applications ---"
    ask_browser_choice
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
    $INSTALL_PHP && echo "  ✓ PHP tools"
    $INSTALL_VSCODE && echo "  ✓ Visual Studio Code"
    $INSTALL_ZED && echo "  ✓ Zed editor"
    $INSTALL_WINDSURF && echo "  ✓ Windsurf"
    $INSTALL_SIGNAL && echo "  ✓ Signal"
    $INSTALL_BITWARDEN && echo "  ✓ Bitwarden"
    $INSTALL_FREECAD && echo "  ✓ FreeCad"
    $INSTALL_OBSIDIAN && echo "  ✓ Obsidian"
    $INSTALL_DISCORD && echo "  ✓ Discord"
    $INSTALL_QBITTORRENT && echo "  ✓ qBittorrent"
    $INSTALL_GNOME_BOXES && echo "  ✓ GNOME Boxes"
    $INSTALL_LIBREOFFICE && echo "  ✓ LibreOffice"
    $INSTALL_ANDROID_STUDIO && echo "  ✓ Android Studio"
    $INSTALL_BRAVE && echo "  ✓ Brave Browser (Firefox removed)"
    $INSTALL_MULLVAD_BROWSER && echo "  ✓ Mullvad Browser (Firefox removed)"
    ! $INSTALL_BRAVE && ! $INSTALL_MULLVAD_BROWSER && echo "  ✓ Web browser: Firefox (unchanged)"
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
    install_flatpak_apps

    if $INSTALL_PYTHON; then echo ""; install_packages "Python" "${PYTHON_PACKAGES[@]}"; fi
    if $INSTALL_C; then echo ""; install_packages "C/C++" "${C_PACKAGES[@]}"; fi
    if $INSTALL_PHP; then echo ""; install_packages "PHP" "${PHP_PACKAGES[@]}"; fi

    if $INSTALL_VSCODE; then echo ""; install_vscode; fi
    if $INSTALL_ZED; then echo ""; install_zed; fi
    if $INSTALL_WINDSURF; then echo ""; install_windsurf; fi
    if $INSTALL_SIGNAL; then echo ""; install_signal; fi
    if $INSTALL_GNOME_BOXES; then echo ""; install_gnome_boxes; fi
    if $INSTALL_LIBREOFFICE; then echo ""; install_packages "LibreOffice" "${LIBREOFFICE_PACKAGES[@]}"; fi
    if $INSTALL_ANDROID_STUDIO; then echo ""; install_android_studio; fi

    if $INSTALL_BRAVE; then
        echo ""
        if install_brave; then remove_firefox; fi
    fi
    if $INSTALL_MULLVAD_BROWSER; then
        echo ""
        if install_mullvad_browser; then remove_firefox; fi
    fi

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
