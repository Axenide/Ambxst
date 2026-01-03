#!/usr/bin/env bash
set -e

# === Configuration ===
REPO_URL="https://github.com/Axenide/Ambxst.git"
INSTALL_PATH="$HOME/Ambxst"
BIN_DIR="/usr/local/bin"
QUICKSHELL_REPO="https://git.outfoxxed.me/outfoxxed/quickshell"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check for root
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}✖  Please do not run this script as root.${NC}"
  echo -e "${YELLOW}   Use a normal user account. The script will use sudo where needed.${NC}"
  exit 1
fi

log_info() { echo -e "${BLUE}ℹ  $1${NC}"; }
log_success() { echo -e "${GREEN}✔  $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠  $1${NC}"; }
log_error() { echo -e "${RED}✖  $1${NC}"; }

# === Distro Detection ===
detect_distro() {
  if [ -f /etc/NIXOS ]; then
    echo "nixos"
  elif command -v pacman >/dev/null 2>&1; then
    echo "arch"
  elif [ -f /etc/fedora-release ]; then
    echo "fedora"
  elif [ -f /etc/debian_version ]; then
    echo "debian"
  else
    echo "unknown"
  fi
}

DISTRO=$(detect_distro)
log_info "Detected System: $DISTRO"

# === Dependency Definitions ===

# Common packages (Names might vary slightly, mapped below)
# Core: kitty, tmux, fuzzel, networkmanager, blueman, pulseaudio/pipewire tools
# Qt6: qt6-base, qt6-declarative, qt6-wayland, qt6-svg, qt6-tools
# Media: ffmpeg, playerctl, pipewire, wireplumber
# Tools: brightnessctl, ddcutil, jq, imagemagick, wl-clipboard, etc.

install_dependencies() {
  case "$DISTRO" in
  nixos)
    # Existing NixOS/Nix Logic (via flake)
    log_info "Using Nix profile install..."
    FLAKE_URI="${1:-github:Axenide/Ambxst}"

    # Conflict cleanup logic from original script
    if nix profile list | grep -q "ddcutil"; then
      nix profile remove ddcutil 2>/dev/null || true
    fi
    if nix profile list | grep -q "Ambxst"; then
      nix profile remove Ambxst 2>/dev/null || true
    fi

    nix profile install "$FLAKE_URI" --impure
    ;;

  arch)
    log_info "Preparing installation..."

    # Ensure git and base-devel are installed for AUR helper compilation
    if ! command -v git >/dev/null || ! command -v makepkg >/dev/null; then
      log_info "Installing git and base-devel (required for AUR helper)..."
      sudo pacman -S --needed --noconfirm git base-devel
    fi

    # Check for AUR helpers
    AUR_HELPER=""
    if command -v yay >/dev/null; then
      AUR_HELPER="yay"
    elif command -v paru >/dev/null; then
      AUR_HELPER="paru"
    else
      log_info "No AUR helper found. Installing yay-bin..."
      YAY_TMP="$(mktemp -d)"
      git clone "https://aur.archlinux.org/yay-bin.git" "$YAY_TMP"
      pushd "$YAY_TMP"
      makepkg -si --noconfirm
      popd
      rm -rf "$YAY_TMP"
      AUR_HELPER="yay"
    fi

    log_info "Installing dependencies with $AUR_HELPER..."

    PKGS=(
      # Apps
      kitty tmux fuzzel network-manager-applet blueman

      # Audio/Video
      pipewire wireplumber pwvucontrol easyeffects ffmpeg x264 playerctl

      # Qt6 & KDE deps
      qt6-base qt6-declarative qt6-wayland qt6-svg qt6-tools qt6-imageformats qt6-multimedia qt6-shadertools
      libwebp libavif # Image formats support
      syntax-highlighting breeze-icons hicolor-icon-theme

      # Tools
      brightnessctl ddcutil fontconfig grim slurp imagemagick jq sqlite upower
      wl-clipboard wlsunset wtype zbar glib2 python-pipx zenity inetutils power-profiles-daemon

      # Tesseract
      tesseract tesseract-data-eng tesseract-data-spa tesseract-data-jpn tesseract-data-chi_sim tesseract-data-chi_tra tesseract-data-kor tesseract-data-lat

      # Fonts
      ttf-roboto ttf-roboto-mono ttf-dejavu ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji
      ttf-nerd-fonts-symbols

      # Special Packages
      matugen-bin gpu-screen-recorder wl-clip-persist mpvpaper
      quickshell-git ttf-phosphor-icons ttf-league-gothic
    )

    $AUR_HELPER -S --needed --noconfirm "${PKGS[@]}"
    ;;

  *)
    log_error "Unsupported distribution for automatic dependency installation: $DISTRO"
    log_warn "Please ensure you have all dependencies listed in nix/packages/ installed."
    ;;
  esac
}

# === Ambxst Clone ===
setup_repo() {
  if [ "$DISTRO" != "nixos" ]; then
    if [ ! -d "$INSTALL_PATH" ]; then
      log_info "Cloning Ambxst to $INSTALL_PATH..."
      git clone "$REPO_URL" "$INSTALL_PATH"
    else
      log_info "Ambxst directory exists at $INSTALL_PATH. Pulling latest..."
      git -C "$INSTALL_PATH" pull
    fi
  fi
}

# === Quickshell Build (Git) ===
install_quickshell() {
  if [ "$DISTRO" == "nixos" ]; then return; fi # NixOS installs via flake

  if ! command -v qs >/dev/null; then
    log_info "Building Quickshell from source..."

    QS_BUILD_DIR="$(mktemp -d)"
    git clone --recursive "$QUICKSHELL_REPO" "$QS_BUILD_DIR"

    pushd "$QS_BUILD_DIR"
    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local"
    cmake --build build
    cmake --install build
    popd
    rm -rf "$QS_BUILD_DIR"

    log_success "Quickshell installed to ~/.local/bin/qs"
  else
    log_info "Quickshell (qs) is already installed."
  fi
}

# === Python Tools ===
install_python_tools() {
  if [ "$DISTRO" == "nixos" ]; then return; fi

  log_info "Installing Python tools..."
  if command -v pipx >/dev/null; then
    pipx install "litellm[proxy]"
    pipx ensurepath
  else
    log_warn "pipx not found. Skipping litellm[proxy] installation."
  fi
}

# === Service Configuration ===
configure_services() {
  if [ "$DISTRO" == "nixos" ]; then return; fi

  log_info "Configuring system services..."

  if command -v systemctl >/dev/null; then
    log_info "Detected Init System: systemd"

    # Disable iwd if active/enabled to prevent conflicts
    if systemctl is-enabled --quiet iwd 2>/dev/null || systemctl is-active --quiet iwd 2>/dev/null; then
      log_warn "Disabling iwd to prevent conflicts with NetworkManager..."
      sudo systemctl stop iwd
      sudo systemctl disable iwd
    fi

    # Enable NetworkManager
    if ! systemctl is-enabled --quiet NetworkManager 2>/dev/null; then
      log_info "Enabling and starting NetworkManager..."
      sudo systemctl enable --now NetworkManager
      log_success "NetworkManager enabled."
    else
      log_info "NetworkManager is already enabled."
    fi

    # Enable Bluetooth
    if ! systemctl is-enabled --quiet bluetooth 2>/dev/null; then
      log_info "Enabling and starting Bluetooth..."
      sudo systemctl enable --now bluetooth
      log_success "Bluetooth enabled."
    else
      log_info "Bluetooth is already enabled."
    fi

  elif command -v rc-service >/dev/null; then
    log_info "Detected Init System: OpenRC"

    # Disable iwd
    if rc-update show | grep -q "iwd"; then
      log_warn "Disabling iwd..."
      sudo rc-service iwd stop 2>/dev/null || true
      sudo rc-update del iwd default 2>/dev/null || true
    fi

    # Enable NetworkManager
    log_info "Enabling NetworkManager..."
    sudo rc-update add NetworkManager default 2>/dev/null || true
    sudo rc-service NetworkManager start 2>/dev/null || true

    # Enable Bluetooth
    log_info "Enabling Bluetooth..."
    sudo rc-update add bluetooth default 2>/dev/null || true
    sudo rc-service bluetooth start 2>/dev/null || true

  elif command -v sv >/dev/null; then
    log_info "Detected Init System: Runit"
    SERVICE_DIR="/var/service"

    # Disable iwd
    if [ -L "$SERVICE_DIR/iwd" ]; then
      log_warn "Disabling iwd..."
      sudo rm "$SERVICE_DIR/iwd"
    fi

    # Enable NetworkManager
    if [ -d "/etc/sv/NetworkManager" ] && [ ! -L "$SERVICE_DIR/NetworkManager" ]; then
      log_info "Enabling NetworkManager..."
      sudo ln -s /etc/sv/NetworkManager "$SERVICE_DIR/"
    fi

    # Enable Bluetooth
    if [ -d "/etc/sv/bluetooth" ] && [ ! -L "$SERVICE_DIR/bluetooth" ]; then
      log_info "Enabling Bluetooth..."
      sudo ln -s /etc/sv/bluetooth "$SERVICE_DIR/"
    fi

  else
    log_warn "Could not detect a supported init system (systemd, openrc, runit)."
    log_warn "Please manually enable NetworkManager and Bluetooth."
  fi
}

# === Launcher Setup ===
setup_launcher() {
  if [ "$DISTRO" == "nixos" ]; then return; fi

  # Clean up old launcher location
  OLD_LAUNCHER="$HOME/.local/bin/ambxst"
  if [ -f "$OLD_LAUNCHER" ]; then
    log_info "Removing old launcher at $OLD_LAUNCHER..."
    rm -f "$OLD_LAUNCHER"
  fi

  mkdir -p "$BIN_DIR" # Ensure bin dir exists
  LAUNCHER="$BIN_DIR/ambxst"

  log_info "Creating launcher at $LAUNCHER..."

  sudo tee "$LAUNCHER" >/dev/null <<EOF
#!/usr/bin/env bash
export PATH="$HOME/.local/bin:\$PATH"
export QML2_IMPORT_PATH="$HOME/.local/lib/qml:\$QML2_IMPORT_PATH"
export QML_IMPORT_PATH="\$QML2_IMPORT_PATH"

# Execute the CLI script from the repo
exec "$INSTALL_PATH/cli.sh" "\$@"
EOF

  sudo chmod +x "$LAUNCHER"
  log_success "Launcher created."
}

# === Main Execution ===

# 1. Install Dependencies
install_dependencies "$1"

# 2. Setup Repo (Non-NixOS)
setup_repo

# 3. Install Quickshell (Non-NixOS)
install_quickshell

# 4. Install Python Tools
install_python_tools

# 5. Compile Auth
# (Auth removed - using Quickshell internal PAM)

# 6. Configure Services
configure_services

# 7. Setup Launcher
setup_launcher

echo ""
log_success "Installation steps completed!"
if [ "$DISTRO" != "nixos" ]; then
  echo -e "Run ${GREEN}ambxst${NC} to start."
fi
