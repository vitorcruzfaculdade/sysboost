#!/bin/bash
#
# sysboosth.sh
# Vitor Cruz's General Purpose System Boost Script
# License: GPL v3.0

VERSION="1.7.52"
set -e

### Helper Functions ###
is_dryrun=false
dryrun() {
  $is_dryrun && echo "[dryrun] $*"
  ! $is_dryrun && eval "$@"
}

print_banner() {
  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│ 🛠️  sysboost.sh v$VERSION                                    "
  echo "│ 🚀 The Ultimate Ubuntu Booster for 24.04+                     "
  echo "│ 🔧 By Vitor Cruz · License: GPL v3.0                          "
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""
}

detect_machine_type() {
  if grep -iq "battery" /sys/class/power_supply/*/type 2>/dev/null; then
    echo "laptop"
  else
    echo "desktop"
  fi
}

confirm() {
  read -rp "$1 [y/N]: " response
  [[ "$response" =~ ^[Yy]$ ]]
}

### Core Functions ###
full_cleanup() {
  echo ""
  echo "🗑️ Cleaning temp files..."
  echo ""
  echo "🌐 Updating installation cache..."
  dryrun sudo apt update
  echo ""
  echo "🧽 Installing Bleachbit Cleaner..."
  dryrun sudo apt install bleachbit -y
  echo ""
  echo "🌐 Checking for broken dependencies..."
  dryrun sudo apt-get check
  echo ""
  echo "🛠️ Fixing broken dependencies (if any)..."
  dryrun sudo apt-get -f install -y
  echo ""
  echo "🧹 Cleaning useless packages"
  dryrun sudo apt-get --purge autoremove -y
  echo ""
  echo "🧹 Cleaning apt-get cache ..."
  dryrun sudo apt-get autoclean
  dryrun sudo apt-get clean
  echo ""
  echo "🗑️ Cleaning temporary files..."
  dryrun sudo rm -rf /tmp/*
  dryrun rm -rf ~/.cache/*
  echo ""
  echo "✅ Package and temporary files clean!🗑️"
}

update_system() {
  echo ""
  echo "🔄 Updating APT packages..."
  if [[ "$dryrun" == true ]]; then
    echo "[dryrun] sudo apt update && sudo apt full-upgrade -y"
  else
    sudo apt update && sudo apt full-upgrade -y
    echo ""
    echo "✅ APT packages updated."
  fi

  echo ""
  echo "📦 Cleaning up unused packages..."
  if [[ "$dryrun" == true ]]; then
    echo "[dryrun] sudo apt autoremove --purge -y && sudo apt autoclean -y"
  else
    sudo apt autoremove --purge -y && sudo apt autoclean -y
    echo ""
    echo "🧹 Package cleanup complete."
  fi

  # Flatpak update
  if ! command -v flatpak &> /dev/null; then
    echo ""
    echo "📦 Flatpak is not installed. Needed for updating Flatpak apps."

    if confirm "🛍️ Store (Flatpak, Snap, GNOME Software) is not installed. Would you like to install it now?" "y"; then
      echo ""
      echo "🛍️ Installing Store module..."
      install_flatpak_snap_store
    else
      echo ""
      echo "⚠️ Skipping Flatpak updates. You can install the store later with '--store'."
    fi
  fi

  if command -v flatpak &> /dev/null; then
    echo ""
    echo "📦 Updating Flatpak apps..."
    if [[ "$dryrun" == true ]]; then
      echo "[dryrun] flatpak update -y"
    else
      flatpak update -y
      echo ""
      echo "✅ Flatpak apps updated."
    fi
  fi

  # Snap update
  if command -v snap &> /dev/null; then
    echo ""
    echo "📦 Updating Snap packages..."
    if [[ "$dryrun" == true ]]; then
      echo "[dryrun] sudo snap refresh"
    else
      sudo snap refresh
      echo ""
      echo "✅ Snap packages updated."
    fi
  fi
}

install_restricted_packages() {
  if confirm "🎵 Do you want to install multimedia support (ubuntu-restricted-extras & addons)?"; then
    echo ""
    echo "🎶 Installing ubuntu-restricted-extras, ubuntu-restricted-addons and extended GStreamer plugins..."
    dryrun sudo apt install ubuntu-restricted-extras ubuntu-restricted-addons gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav -y

    if confirm "📽️ Do you also want to install GNOME Videos (Totem)?"; then
      echo ""
      echo "🎞️ Installing GNOME Videos (Totem)..."
      dryrun sudo apt install totem totem-common totem-plugins -y

      if confirm "🎯 Set Totem as the default video player?"; then
        echo ""
        echo "🔧 Setting Totem as the default video player for common formats..."
        formats=("video/mp4" "video/x-matroska" "video/x-msvideo" "video/x-flv" "video/webm" "video/ogg")
          for format in "${formats[@]}"; do
            dryrun xdg-mime default org.gnome.Totem.desktop "$format"
          done
      fi
    fi
# Offer to install Spotify via Snap
if confirm "🎧 Do you want to install Spotify (Snap version)? Spotify is a popular music streaming service. This installs the official Snap version."; then
    echo ""
    echo "🎶 Installing Spotify (official Snap version)..."
    dryrun sudo snap install spotify
    echo "✅ Spotify (official Snap version) installed."
  fi
fi    
}

disable_telemetry() {
  echo ""
  echo "🚫 Disabling telemetry and background reporting..."
  for service in apport whoopsie motd-news.timer; do
    if systemctl list-unit-files | grep -q "${service}"; then
      dryrun sudo systemctl disable "$service" --now || true
    fi
  done
  dryrun sudo sed -i 's/ENABLED=1/ENABLED=0/' /etc/default/motd-news || true
  dryrun sudo sed -i 's/ubuntu\.com/#ubuntu.com/' /etc/update-motd.d/90-updates-available || true

  {
    grep -q "metrics.ubuntu.com" /etc/hosts || echo "127.0.0.1 metrics.ubuntu.com" | sudo tee -a /etc/hosts
    grep -q "popcon.ubuntu.com" /etc/hosts || echo "127.0.0.1 popcon.ubuntu.com" | sudo tee -a /etc/hosts
  } || true

  for pkg in ubuntu-report popularity-contest apport whoopsie apport-symptoms kerneloops ubuntu-advantage-tools; do
    if dpkg -l | grep -q "^ii\s*$pkg"; then
      dryrun sudo apt purge -y "$pkg"
      dryrun sudo apt-mark hold "$pkg"
    fi
  done
  echo ""
  echo "🚫 Telemetry and background reporting fully disabled ✅"
  
  # Optional extra hardening
  echo ""
  if confirm "🔐 Do you want to disable Avahi (zeroconf/Bonjour/SSDP broadcasting)?"; then
    dryrun sudo systemctl disable avahi-daemon.socket avahi-daemon.service --now
    echo "📡 Avahi broadcasting disabled."
  fi

  # 1. GDM3 block
  echo ""
  if confirm "🔐 Do you want to disable guest login in GDM (login screen)?"; then
    dryrun 'echo "[Seat:*]" | sudo tee /etc/gdm3/custom.conf > /dev/null'
    dryrun 'echo "AllowGuest=false" | sudo tee -a /etc/gdm3/custom.conf > /dev/null'
    echo ""
    echo "🚷 Guest login disabled in GDM."
  fi

  # 2. LightDM block (only if installed)
  if [ -d /etc/lightdm ] || [ -f /etc/lightdm/lightdm.conf ]; then
    echo ""
    confirm "🔐 LightDM detected. Disable guest login for LightDM?" && {
    dryrun 'sudo mkdir -p /etc/lightdm/lightdm.conf.d'
    dryrun 'echo "[SeatDefaults]" | sudo tee /etc/lightdm/lightdm.conf.d/50-no-guest.conf > /dev/null'
    dryrun 'echo "allow-guest=false" | sudo tee -a /etc/lightdm/lightdm.conf.d/50-no-guest.conf > /dev/null'
    echo ""
    echo "🚷 Guest login disabled for LightDM."
  }
fi

  echo ""
  if confirm "🔒 Do you want to disable core dumps (security and privacy improvement)?"; then
    dryrun sudo sysctl -w fs.suid_dumpable=0
    dryrun 'echo "fs.suid_dumpable=0" | sudo tee /etc/sysctl.d/99-disable-coredump.conf > /dev/null'
    echo ""
    echo "🧠 Core dumps disabled."
  fi

  echo ""
  if confirm "🛡️ Do you want to check AppArmor status?"; then
    echo ""
    dryrun sudo aa-status
  fi

  echo ""
  echo "✅ Additional optional hardening steps completed."
}

# Added code for checking and removing remote access servers
remove_remote_access_servers() {
  echo ""
  echo "🔐 Checking for remote access servers..."
  # List of common remote access servers
  remote_servers=("sshd" "xrdp" "vnc4server" "tightvncserver" "x11vnc")

  for server in "${remote_servers[@]}"; do
    if dpkg -l | grep -q "^ii\s*$server"; then
      echo ""
      echo "⚠️ Found $server installed."
      if confirm "Do you want to remove $server?"; then
        dryrun sudo apt purge -y "$server"
        dryrun sudo apt autoremove -y
        echo ""
        echo "$server has been removed."
      fi
    else
      echo ""
      echo "✔️ $server is not installed."
    fi
  done
}

setup_firewall() {
  echo ""
  echo "🛡️ Setting up UFW firewall rules..."

  if sudo ufw status | grep -q "Status: active"; then
    echo ""
    echo "🔒 UFW is already active."
    if ! confirm "🔁 Do you want to reconfigure the firewall?"; then
      echo ""
      echo "❌ Skipping firewall configuration."
      return
    fi
  else
    if ! confirm "🚫 Firewall is inactive. Do you want to enable and configure it now?"; then
      echo ""
      echo "❌ Skipping firewall setup."
      return
    fi
  fi

  echo ""
  echo "🌐 Updating installation cache..."
  dryrun sudo apt update
  echo ""
  echo "🌐 Installing 🧱🔥 UFW/GUFW..."
  dryrun sudo apt install ufw gufw -y
  echo ""
  echo "🔧 Enabling 🧱🔥 UFW/GUFW..."
  dryrun sudo systemctl enable ufw
  echo ""
  echo "🔧 Restarting/Reseting 🧱🔥 UFW/GUFW..."
  dryrun sudo systemctl restart ufw
  echo ""
  dryrun sudo ufw --force reset
  echo ""
  echo "🔧 Setting pretty sick block rule from outside 🧱🔥 UFW/GUFW..."
  dryrun sudo ufw default deny incoming
  echo ""
  echo "✅ Denied incomming traffic (from outside) 🧱🔥 UFW/GUFW."
  echo ""
  echo "🔧 Allowing conections started from this system to outside..."
  dryrun sudo ufw default allow outgoing
  echo ""
  echo "✅ Allowed outgoing traffic 🧱🔥 UFW/GUFW."
  echo ""
  echo "🔧 Enabling and applying settings to 🧱🔥 UFW/GUFW..."
  dryrun sudo ufw enable
  echo ""
  echo "✅ Enabled 🧱🔥 UFW/GUFW."
  echo ""
  echo "⚙️ Reloading 🧱🔥 UFW/GUFW..."
  dryrun sudo ufw reload
  echo ""
  echo "✅ Reloaded 🧱🔥 UFW/GUFW."
  
  if confirm "📝 Do you want to enable UFW logging?"; then
    dryrun sudo ufw logging on
    log_status="enabled"
    echo ""
    echo "✅ UFW logging on 📝"
  else
    dryrun sudo ufw logging off
    log_status="disabled"
    echo ""
    echo "✅ UFW logging off 📝"
  fi

  dryrun sudo ufw reload
  echo ""
  echo "🧱 G/UFW Firewall🔥 configured and enabled ✅ — logging $log_status, incoming connections denied 🚫."
}

replace_firefox_with_librewolf() {
  if confirm "🌐 Replace Firefox Snap with LibreWolf its from official repo?"; then
    dryrun sudo snap remove firefox || true
    echo ""
    echo "🌐 Adding LibreWolf repo..."
    dryrun sudo apt update
    dryrun sudo apt install extrepo -y
    dryrun sudo extrepo enable librewolf
    echo ""
    echo "🌐 Updating installation cache..."
    dryrun sudo apt update
    echo ""
    echo "🌐 Installing LibreWolf..."
    dryrun sudo apt install librewolf -y
    echo ""
    echo "✅ Librewolf installed."
  fi
}

install_chrome() {
        echo ""
    if confirm "🧭 Do you want to install Google Chrome (Stable) using the official repository?"; then
        echo ""
        echo "🌐 Downloading and saving Google Chrome repository key..."
        dryrun wget -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
        echo ""
        echo "🌐 Downloading and saving Google Chrome repository..."
        dryrun sudo echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main' | sudo tee /etc/apt/sources.list.d/google-chrome.list
        echo ""
        echo "🌐 Updating installation cache..."
        dryrun sudo apt update
        echo ""
        echo "🧭 Installing Google Chrome..."
        dryrun sudo apt install google-chrome-stable -y

        echo ""
        if confirm "🧭 Set Chrome as default browser?" "Do you want to make Google Chrome your default browser?"; then
            dryrun xdg-settings set default-web-browser google-chrome.desktop
        fi
        echo ""
        echo "✅ Google Chrome installed and configured."
    else
        echo ""
        echo "❎ Skipped Google Chrome installation."
    fi
}

install_flatpak_snap_store() {
    echo ""
  if confirm "📦 Do you want full Flatpak, Snap and GNOME Software support?"; then
    echo ""
    echo "🛍️ Installing Snap/Flatpak support with GNOME Software..."
    dryrun sudo apt install gnome-software gnome-software-plugin-flatpak gnome-software-plugin-snap flatpak -y
    dryrun sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}

enable_trim() {
    echo ""
  if confirm "✂️ Enable periodic TRIM for SSDs (recommended)?"; then
    dryrun sudo systemctl enable fstrim.timer
    echo ""
    echo "✅ Timer service for TRIM enabled."
  fi
}

enable_cpu_performance_mode() {
    echo ""
  if confirm "⚙️ Set CPU governor to 'performance'?"; then
    dryrun sudo apt install cpufrequtils -y
    echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
    dryrun sudo systemctl disable ondemand || true
    dryrun sudo systemctl enable cpufrequtils
  fi
}

install_gaming_tools() {
  # 🎮 Gaming Utilities
    echo ""
  if confirm "🎮 Enable gaming mode (GameMode, MangoHUD)?"; then
    dryrun sudo apt install gamemode mangohud -y
    echo ""
    echo "🧪 Checking if gamemoded is running..."
    if systemctl is-active --quiet gamemoded; then
      echo ""
      echo "✅ GameMode is active and running."
    else
      echo ""
      echo "⚠️ GameMode is installed but not running. You may need to restart or check systemd services."
    fi
  fi

  # 🧠 GPU Detection
  gpu_info=$(lspci | grep -E "VGA|3D")
    echo ""
  if echo "$gpu_info" | grep -qi nvidia; then
    echo ""
    echo "🟢 NVIDIA GPU detected."
    if confirm "Install NVIDIA proprietary drivers?"; then
      echo ""
      echo "🌐 Updating installation cache..."
      dryrun sudo apt update
      echo ""
      echo "🌐 Updating system..."
      dryrun sudo apt upgrade -y
      echo ""
      echo "🌐 Adding some packages to improve GPU compatibility"
      dryrun sudo apt install mesa-vulkan-drivers mesa-utils vulkan-tools -y
      echo ""
      echo "🌐 Installing NVIDIA drivers using Ubuntu-Drivers..."
      dryrun sudo ubuntu-drivers autoinstall
      echo ""
      echo "✅ NVIDIA drivers installation triggered."
    fi
  elif echo "$gpu_info" | grep -qi amd; then
    echo ""
    echo "🔴 AMD GPU detected."
    if confirm "Install AMD Mesa graphics drivers?"; then
      dryrun sudo apt install mesa-vulkan-drivers mesa-utils vulkan-tools -y
      echo ""
      echo "✅ AMD Mesa drivers installed."
    fi
  elif echo "$gpu_info" | grep -qi intel; then
    echo ""
    echo "🔵 Intel GPU detected."
    if confirm "Install Intel Mesa graphics drivers?"; then
      dryrun sudo apt install mesa-vulkan-drivers mesa-utils vulkan-tools -y
      echo ""
      echo "✅ Intel Mesa drivers installed."
    fi
  elif echo "$gpu_info" | grep -qi vmware; then
    echo ""
    echo "🟠 VMware or VirtualBox GPU detected."
    if confirm "Install Virtual Machine GPU drivers?"; then
      echo ""
      echo "🌐 Updating installation cache..."    
      dryrun sudo apt update
      echo ""
      echo "🌐 Updating system..."
      dryrun sudo apt upgrade -y
      echo ""
      echo "🌐 Adding some packages to improve GPU compatibility and Open-VM-Tools..."
      dryrun sudo apt install mesa-vulkan-drivers mesa-utils vulkan-tools open-vm-tools open-vm-tools-desktop -y
      echo ""
      echo "🌐 Installing VM additional drivers using Ubuntu-Drivers (if any)..."
      dryrun sudo ubuntu-drivers autoinstall
      echo ""
      echo "✅ VM GPU drivers installed."
    fi
  else
    echo ""
    echo "❓ GPU vendor not recognized: $gpu_info"
  fi

  # 🔌 Vulkan + Proton/DXVK
  echo ""
  if confirm "🧱 Install Vulkan packages for Proton/DXVK support?"; then
    dryrun sudo apt install mesa-vulkan-drivers mesa-utils vulkan-tools -y
    echo ""
    echo "✅ Vulkan support installed."
  fi
  
  # 🎮 Steam + 32-bit lib support
  echo ""
  if confirm "🎮 Install Steam (official .deb release)?"; then
    tmp_deb="/tmp/steam_latest.deb"
    dryrun sudo dpkg --add-architecture i386
    echo ""
    echo "🌐 Downloading Steam .deb from official servers..."
    dryrun wget --show-progress --progress=bar:force:noscroll -O "$tmp_deb" https://cdn.fastly.steamstatic.com/client/installer/steam.deb
    dryrun sudo apt install "$tmp_deb" -y
    echo ""
    echo "🌐 Updating installation cache..." 
    dryrun sudo apt update
    echo ""
    echo "🛠️ Fixing dependencies (always happen with Steam deb)..." 
    dryrun sudo apt -f install -y
    echo ""
    echo "🧹 Cleaning temp..." 
    dryrun rm -f "$tmp_deb"
    echo ""
    echo "✅ Steam installed from official .deb package (dependencies resolved)."
  fi
}

install_vm_tools() {
  echo ""
  if confirm "📦 Install latest VirtualBox from Oracle's official repo?"; then
    echo ""
    echo "🌐 Obtaining key from Oracle..." 
    dryrun wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo gpg --dearmor -o /usr/share/keyrings/oracle-virtualbox.gpg
    codename=$(lsb_release -cs)
    echo ""
    echo "🌐 Adding key and repository information..." 
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox.gpg] https://download.virtualbox.org/virtualbox/debian $codename contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
    echo ""
    echo "🌐 Updating installation cache..." 
    dryrun sudo apt update
    echo ""
    echo "🌐 Installing Virtualbox..."
    dryrun sudo apt install -y virtualbox-7.1
    echo ""
    echo "✅ Virtualbox installed."
  fi
}

install_compression_tools() {
  echo ""
  if confirm "🗜️ Install support for compressed file formats (zip, rar, 7z, xz, bz2, etc)?"; then
    dryrun sudo apt install zip unzip rar unrar p7zip-full xz-utils bzip2 lzma 7zip-rar -y 
  fi
}

install_sysadmin_tools() {
  echo ""
  echo "🛠️ Preparing sysadmin tools setup..."
  if confirm "📡 Install Remmina (GUI 🪟 - remote desktop client with full plugin support)?"; then
    echo ""
    echo "📡 Installing Remmina..."
    dryrun sudo apt install remmina remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-secret remmina-plugin-spice remmina-plugin-exec -y || echo "⚠️ Remmina installation failed."
  fi

  echo ""
  if confirm "📊 Install htop (CLI 🖥️ - interactive process viewer)?"; then
    dryrun sudo apt install htop -y
  fi

  echo ""
  if confirm "📷 Install screenfetch (CLI 🖥️ - display system info with ASCII logo)?"; then
    dryrun sudo apt install screenfetch -y
  fi

  echo ""
  if confirm "🖥️ Install guake (GUI 🪟 - dropdown terminal for GNOME)?"; then
    dryrun sudo apt install guake -y
  fi

  echo ""
  if confirm "🔐 Install OpenSSH Client (CLI 🖥️ - secure remote terminal access)?"; then
    dryrun sudo apt install openssh-client -y
  fi
  
  echo ""
  if confirm "🔁 Install lftp (CLI 🖥️ - advanced FTP/HTTP client with scripting support)?"; then
    dryrun sudo apt install lftp -y
  fi

  echo ""
  if confirm "📡 Install telnet (CLI 🖥️ - basic network protocol testing tool)?"; then
    dryrun sudo apt install telnet -y
  fi

  echo ""
  if confirm "🛰️ Install traceroute (CLI 🖥️ - trace path to a network host)?"; then
    dryrun sudo apt install traceroute -y
  fi

  echo ""
  if confirm "📍 Install mtr (CLI 🖥️ - real-time network diagnostic tool)?"; then
    dryrun sudo apt install mtr -y
  fi

  echo ""
  if confirm "🌐 Install whois (CLI 🖥️ - domain and IP ownership lookup)?"; then
    dryrun sudo apt install whois -y
  fi

  echo ""
  if confirm "🧠 Install dnsutils (CLI 🖥️ - includes dig, nslookup, etc.)?"; then
    dryrun sudo apt install dnsutils -y
  fi

  echo ""
  if confirm "🧪 Install nmap (CLI 🖥️ - network scanner and discovery tool)?"; then
    dryrun sudo apt install nmap -y
  fi

  echo ""
  if confirm "🔬 Install Wireshark (GUI 🪟 - network packet analyzer)?"; then
    dryrun sudo apt install wireshark -y
    echo ""
    echo "⚠️ Note: You may need to add your user to the 'wireshark' group to capture packets without sudo."
  fi
  echo ""
  echo "✅ Sysadmin tool installation process completed."
}

install_remmina() {
  echo ""
  if confirm "🖥️ Install Remmina (remote desktop client with full plugin support)?"; then
    echo ""
    echo "🌐 Updating installation cache..."
    dryrun sudo apt update
    echo ""
    echo "📦 Installing Remmina and plugins..."
    dryrun sudo apt install remmina remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-secret remmina-plugin-spice remmina-plugin-exec -y
    echo ""
    echo "✅ Remmina installed with full client support — no server components."
  fi
}

install_office() {
    echo ""
    echo "📝 Office suite setup selected."

    # Detect existing installs using booleans
    echo "📝 Detecting installed Office..."
    local libre_installed=0
    local only_installed=0

    dpkg -l | grep -iq libreoffice && libre_installed=1
    dpkg -l | grep -iq onlyoffice && only_installed=1

    if [ "$libre_installed" -eq 1 ] || [ "$only_installed" -eq 1 ]; then
        echo ""
        echo "📦 Existing installation detected:"
        [ "$libre_installed" -eq 1 ] && echo "   - 📝 LibreOffice"
        [ "$only_installed" -eq 1 ] && echo "   - 📝 OnlyOffice"

        if confirm "↪️ Do you want to skip Office installation?"; then
            echo ""
            echo "⏭️ Skipped Office installation."
            return
        fi
    fi

    # Always fall through to the menu
    echo ""
    echo "❓ Which office suite do you want to install?"
    echo "   1) 📝  LibreOffice (default)"
    echo "   2) 📝  OnlyOffice"
    echo ""
    echo "   3) ⏭️  Skip"
    echo ""
    read -rp "➡️  Enter your choice [1-3]: " office_choice
    office_choice=${office_choice:-1}

    case $office_choice in
        1)
            echo ""
            echo "📦 Installing LibreOffice..."
            dryrun "sudo apt install libreoffice -y"
            # Language pack suggestion based on locale
            echo ""
            echo "📦 Installing LibreOffice Language Pack..."
            LOCALE_LANG=$(echo "$LANG" | cut -d_ -f1)
            LOCALE_REGION=$(echo "$LANG" | cut -d_ -f2 | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
            if [[ "$LOCALE_LANG" == "pt" && "$LOCALE_REGION" == "br" ]]; then
              PACK="libreoffice-l10n-pt-br libreoffice-help-pt-br"
            else
              case $LOCALE_LANG in
                pt) PACK="libreoffice-l10n-pt libreoffice-help-pt" ;;
                es) PACK="libreoffice-l10n-es libreoffice-help-es" ;;
                fr) PACK="libreoffice-l10n-fr libreoffice-help-fr" ;;
                de) PACK="libreoffice-l10n-de libreoffice-help-de" ;;
                *) PACK="" ;;
              esac
            fi

            if [ -n "$PACK" ]; then
                confirm "🌍 Do you want to install language support for LibreOffice ($LOCALE_LANG)?" && {
                    echo ""
                    echo "🌍 Installing language pack for LibreOffice: $PACK"
                    dryrun "sudo apt install $PACK -y"
                }
            fi

            confirm "📝 Do you want to set LibreOffice as default for office files?" && {
                dryrun "xdg-mime default libreoffice-writer.desktop application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                dryrun "xdg-mime default libreoffice-calc.desktop application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                echo ""
                echo "🗂️ LibreOffice set as default office app."
            }
            ;;
        2)
            echo ""
            echo "📦 Installing OnlyOffice Desktop Editors..."
            dryrun ""
            echo "🌐 Updating installation cache and Snap Packages..."
            dryrun "sudo snap refresh"
            dryrun ""
            dryrun "sudo snap install onlyoffice-desktopeditors"
            echo ""
            echo "✅ OnlyOffice installed from 🛍️ SnapStore."

            confirm "📝 Do you want to set OnlyOffice as default for office files?" && {
                dryrun "xdg-mime default onlyoffice-desktopeditors.desktop application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                dryrun "xdg-mime default onlyoffice-desktopeditors.desktop application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                echo ""
                echo "🗂️ OnlyOffice set as default office app."
            }
            ;;
        3)
            echo ""
            echo "⏭️ Skipped office installation."
            ;;
        *)
            echo ""
            echo "❌ Invalid option. ⏭️ Skipping office installation."
            ;;
    esac
}

suggest_preload_and_zram() {
  # Get system locale
  locale_lang=$(locale | grep LANG | cut -d= -f2)

  # Check for the system's RAM based on locale
  if [[ "$locale_lang" =~ "pt_BR" ]]; then
    # Adjust for pt-br (Mem.)
    total_ram_gb=$(free -g | awk '/^Mem\./{print $2}')
  else
    # Default for other languages (Mem)
    total_ram_gb=$(free -g | awk '/^Mem:/{print $2}')
  fi

  # Detect machine type:
  machine_type=$(detect_machine_type)
  
  # Output information
  echo ""
  echo "🧠 Detected RAM: ${total_ram_gb} GB"
  echo ""
  echo "💻 Machine type: $machine_type"

  case $total_ram_gb in
    [0-2])
      echo ""
      echo "🟥 Low RAM detected (≤2GB): ZRAM is recommended. Preload is not advised."
      if confirm "💾 Enable ZRAM (compressed RAM swap)?"; then
        dryrun sudo apt install zram-tools -y
        echo "ALGO=zstd" | sudo tee /etc/default/zramswap
        echo ""
        echo "✅ ZRAM enabled. Reboot to apply."
      fi
      ;;
    [3-4])
      echo ""
      echo "🟧 Low RAM (3–4GB): ZRAM strongly recommended. Preload not advised."
      if confirm "💾 Enable ZRAM (compressed RAM swap)?"; then
        dryrun sudo apt install zram-tools -y
        echo "ALGO=zstd" | sudo tee /etc/default/zramswap
        echo ""
        echo "✅ ZRAM enabled. Reboot to apply."
      fi
      ;;
    [5-8])
      echo ""
      echo "🟨 Moderate RAM (5–8GB): Preload and ZRAM can both improve performance."
      if confirm "📦 Install preload to speed up app launches?"; then
        dryrun sudo apt install preload -y
      fi
      if confirm "💾 Enable ZRAM (compressed RAM swap)?"; then
        dryrun sudo apt install zram-tools -y
        echo "ALGO=zstd" | sudo tee /etc/default/zramswap
        echo ""
        echo "✅ ZRAM enabled. Reboot to apply."
      fi
      ;;
    [9-9]|1[0-6])
      echo ""
      echo "🟩 High RAM (9–16GB): Preload may help, ZRAM is optional."
      if confirm "📦 Install preload to speed up app launches?"; then
        dryrun sudo apt install preload -y
      fi
      if confirm "💾 Enable ZRAM (optional)?"; then
        dryrun sudo apt install zram-tools -y
        echo "ALGO=zstd" | sudo tee /etc/default/zramswap
        echo ""
        echo "✅ ZRAM enabled. Reboot to apply."
      fi
      ;;
    *)
      echo ""
      echo "🟦 Plenty of RAM (>16GB): Preload and ZRAM likely unnecessary, but optional."
      if confirm "📦 Install preload anyway?"; then
        dryrun sudo apt install preload -y
      fi
      if confirm "💾 Enable ZRAM anyway?"; then
        dryrun sudo apt install zram-tools -y
        echo "ALGO=zstd" | sudo tee /etc/default/zramswap
        echo ""
        echo "✅ ZRAM enabled. Reboot to apply."
      fi
      ;;
  esac
}

show_donation_info() {
  pulse_heart() {
    echo ""
    for i in {1..3}; do
      echo -ne "   💖  Thanks for using sysboost.sh!  \r"
      sleep 0.3
      echo -ne "   ❤️  Thanks for using sysboost.sh!  \r"
      sleep 0.3
    done
    echo -ne "   💖  Thanks for using sysboost.sh!  \n"
  }

  pulse_heart

  echo "     .-. .-.   "
  echo "    (   |   )   If you'd like to support this project,"
  echo "     \\     /   visit my Linktree below:"
  echo "      \\   /"
  echo "       \`-’     "
  echo ""
  echo "🔗 https://linktr.ee/vitorcruzcode"
  echo ""

  if ! $is_dryrun; then
    xdg-open "https://linktr.ee/vitorcruzcode" >/dev/null 2>&1 &
  else
    echo "[dryrun] xdg-open https://linktr.ee/vitorcruzcode"
  fi
}

show_version() {
  echo "sysboost.sh version $VERSION"
}

print_help() {
  echo "Usage: ./sysboost.sh [options]"
  echo ""
  echo "  Options:"
  echo "  --clean          🧹  Full cleanup and temp file clearing"
  echo "  --update         🔄  Run update only (no cleanup)"
  echo "  --harden         🔐  Apply security tweaks, disable telemetry, enable firewall, disable some services"
  echo "  --vm             🖥️  Install VirtualBox tools"
  echo "  --gaming         🎮  Gaming tools, Vulkan, drivers, Steam & FPS tweaks"
  echo "  --trim           ✂️  Enable SSD TRIM"
  echo "  --performance    ⚡   Set CPU governor to 'performance'"
  echo "  --media          🎵  Install multimedia codecs (restricted-extras)"
  echo "  --store          🛍️  Add Flatpak, Snap, and GNOME Software support"
  echo "  --librewolf      🦊  Replace Snap Firefox with LibreWolf"
  echo "  --chrome         🧭  Install Google Chrome from the official repository"
  echo "  --compression    📦  Install archive format support (zip, rar, 7z, etc)"
  echo "  --sysadmin       🧰  Install Remmina and useful system/network tools for sysadmins"
  echo "  --remmina        🖧  Install Remmina client with full plugin support (RDP, VNC, etc)"
  echo "  --office         📝  Install LibreOffice or OnlyOffice with language & default options"
  echo "  --preload        🧠  Suggest and optionally install preload & ZRAM"
  echo "  --donate         ❤️  Show donation info and open Linktree in browser"
  echo "  --dryrun         🧪  Show commands without executing"
  echo "  --all            🚀  Run all modules"
  echo "  -v, --version    ℹ️  Show script version"
  echo "  -h, --help       📖  Show help"
}

### Main Entry Point ###
main() {
  print_banner
  echo "💻 Detected machine type: $(detect_machine_type)"

  if [[ $# -eq 0 ]]; then
    print_help
    exit 0
  fi

    while [[ $# -gt 0 ]]; do
    case "$1" in
      --clean) full_cleanup ;;
      --update) update_system ;;
      --harden) disable_telemetry; remove_remote_access_servers; setup_firewall ;;
      --vm) install_vm_tools ;;
      --gaming) install_gaming_tools ;;
      --trim) enable_trim ;;
      --performance) enable_cpu_performance_mode ;;
      --media) install_restricted_packages ;;
      --store) install_flatpak_snap_store ;;
      --librewolf) replace_firefox_with_librewolf ;;
      --chrome) install_chrome ;;
      --compression) install_compression_tools ;;
      --sysadmin) setup_sysadmin_tools ;;
      --remmina) install_remmina ;;
      --office) install_office;;
      --preload) suggest_preload_and_zram ;;
      --donate) show_donation_info ;;
      --dryrun) is_dryrun=true ;;
      --all)
        full_cleanup
        update_system
        disable_telemetry
        remove_remote_access_servers
        setup_firewall
        install_flatpak_snap_store
        install_vm_tools
        install_gaming_tools
        install_sysadmin_tools
        install_office
        enable_trim
        enable_cpu_performance_mode
        install_restricted_packages
        install_compression_tools
        replace_firefox_with_librewolf
        install_chrome
        suggest_preload_and_zram
        show_donation_info
        ;;
      -v|--version) show_version; exit 0 ;;
      -h|--help) print_help; exit 0 ;;
      *) echo "❌ Unknown option: $1"; print_help; exit 1 ;;
    esac
    shift
  done
  echo ""
  echo "✅ Done. Don't forget to reboot if major updates or kernel upgrades were installed."
}

# Run main function
main "$@"
