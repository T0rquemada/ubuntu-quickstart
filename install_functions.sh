#!/bin/bash

# Installation Functions for Ubuntu System Configurator
# This file contains all installation functions

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

install_windsurf() {
    echo ""
    echo "--- Installing Windsurf ---"
    print_info "Adding Windsurf repository..."

    # Install required packages
    if apt-get install -y wget gpg >> /tmp/configurator.log 2>&1; then
        print_success "Required packages installed"
    else
        print_warning "Failed to install required packages"
        return 1
    fi

    # Download and add GPG key
    if wget -qO- "https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/windsurf.gpg" | gpg --dearmor > windsurf-stable.gpg 2>&1; then
        print_success "GPG key downloaded"
    else
        print_error "Failed to download Windsurf GPG key"
        return 1
    fi

    # Install GPG key
    if sudo install -D -o root -g root -m 644 windsurf-stable.gpg /etc/apt/keyrings/windsurf-stable.gpg >> /tmp/configurator.log 2>&1; then
        print_success "GPG key installed"
    else
        print_error "Failed to install GPG key"
        rm -f windsurf-stable.gpg
        return 1
    fi

    # Add repository
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/windsurf-stable.gpg] https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt stable main" | tee /etc/apt/sources.list.d/windsurf.list > /dev/null

    # Cleanup
    rm -f windsurf-stable.gpg

    # Install apt-transport-https and update
    print_info "Installing apt-transport-https and updating package list..."
    if apt-get install -y apt-transport-https >> /tmp/configurator.log 2>&1; then
        print_success "apt-transport-https installed"
    else
        print_warning "Failed to install apt-transport-https"
    fi

    if apt-get update >> /tmp/configurator.log 2>&1; then
        print_success "Package list updated"
    else
        print_warning "apt-get update had issues"
    fi

    # Install Windsurf
    if apt-get install -y windsurf >> /tmp/configurator.log 2>&1; then
        print_success "Windsurf installed"
    else
        print_error "Failed to install Windsurf"
        return 1
    fi
}

install_android_studio() {
    echo "--- Installing Android Studio (Native) ---"

    # 1. Latest stable version link (Ladybug | 2024.2.2 Patch 1 as of current)
    local DOWNLOAD_URL="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2024.2.2.13/android-studio-2024.2.2.13-linux.tar.gz"
    local TEMP_FILE="/tmp/android-studio.tar.gz"
    local INSTALL_DIR="/opt/android-studio"
    local DESKTOP_FILE="/usr/share/applications/android-studio.desktop"

    # 2. Install required 32-bit dependencies (Recommended by Google for Linux)
    echo "Installing required dependencies..."
    apt-get update > /dev/null
    apt-get install -y libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1 libbz2-1.0 > /dev/null 2>&1 || echo "Notice: Some 32-bit libraries were skipped (common on newer OS versions)"

    # 3. Downloading the archive
    echo "Downloading Android Studio..."
    if wget --show-progress -O "$TEMP_FILE" "$DOWNLOAD_URL"; then
        echo "Download completed."
    else
        echo "Error: Failed to download Android Studio!"
        return 1
    fi

    # 4. Remove previous installation if exists and extract
    if [ -d "$INSTALL_DIR" ]; then
        echo "Removing old version from $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
    fi

    echo "Extracting to /opt..."
    # The archive contains a folder named 'android-studio', so we extract directly to /opt
    tar -xzf "$TEMP_FILE" -C /opt

    # 5. Create the .desktop file (Application Menu Icon)
    echo "Creating desktop shortcut..."
    cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Comment=Android Development Environment
Exec="/opt/android-studio/bin/studio.sh" %f
Icon=/opt/android-studio/bin/studio.png
Categories=Development;IDE;
Terminal=false
StartupNotify=true
StartupWMClass=jetbrains-studio
EOF

    # 6. Set ownership to the real user so the IDE can update itself
    if [ -n "$SUDO_USER" ]; then
        chown -R "$SUDO_USER":"$SUDO_USER" "$INSTALL_DIR"
    fi

    # Cleanup
    rm -f "$TEMP_FILE"

    echo "Installation complete! Android Studio should now appear in your application menu."
}

install_flatpak_apps() {
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

remove_firefox() {
    echo ""
    print_info "Removing Firefox..."
    if command -v snap >/dev/null 2>&1; then
        snap remove firefox >> /tmp/configurator.log 2>&1 || true
    fi
    local firefox_pkgs
    firefox_pkgs=$(dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -E '^firefox' || true)
    if [ -n "$firefox_pkgs" ]; then
        apt-get purge -y $firefox_pkgs >> /tmp/configurator.log 2>&1 || print_warning "Some Firefox .deb packages could not be purged"
    fi
    apt-get autoremove -y >> /tmp/configurator.log 2>&1 || true
    print_success "Firefox removal finished"
}

install_brave() {
    echo ""
    echo "--- Installing Brave Browser ---"
    print_info "Running Brave install script..."
    if ( set -o pipefail; curl -fsS https://dl.brave.com/install.sh | sh ) >> /tmp/configurator.log 2>&1; then
        print_success "Brave Browser installed"
        return 0
    else
        print_error "Brave Browser installation failed"
        return 1
    fi
}

install_mullvad_browser() {
    echo ""
    echo "--- Installing Mullvad Browser ---"
    print_info "Adding Mullvad apt repository..."

    if ! curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc \
        "https://repository.mullvad.net/deb/mullvad-keyring.asc" >> /tmp/configurator.log 2>&1; then
        print_error "Failed to download Mullvad keyring"
        return 1
    fi

    echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$(dpkg --print-architecture)] https://repository.mullvad.net/deb/stable stable main" | \
        tee /etc/apt/sources.list.d/mullvad.list > /dev/null

    if apt-get update >> /tmp/configurator.log 2>&1; then
        print_success "Package list updated (Mullvad)"
    else
        print_warning "apt-get update had issues after adding Mullvad repo"
    fi

    if apt-get install -y mullvad-browser >> /tmp/configurator.log 2>&1; then
        print_success "Mullvad Browser installed (stable)"
        return 0
    else
        print_error "Mullvad Browser installation failed"
        return 1
    fi
}
