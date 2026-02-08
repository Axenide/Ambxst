#!/usr/bin/env bash
set -e

# === Configuration ===
REPO_URL="https://github.com/Axenide/Ambxst.git"
INSTALL_PATH="$HOME/.local/src/ambxst"
BIN_DIR="/usr/local/bin"
QUICKSHELL_REPO="https://git.outfoxxed.me/outfoxxed/quickshell"

# === Helpers ===
GREEN='\033[0;32m' BLUE='\033[0;34m' YELLOW='\033[1;33m' RED='\033[0;31m' NC='\033[0m'
log_info() { echo -e "${BLUE}ℹ  $1${NC}" >&2; }
log_success() { echo -e "${GREEN}✔  $1${NC}" >&2; }
log_warn() { echo -e "${YELLOW}⚠  $1${NC}" >&2; }
log_error() { echo -e "${RED}✖  $1${NC}" >&2; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }
has_theme() { [[ -d "/usr/share/themes/$1" ]] || [[ -d "$HOME/.themes/$1" ]] || [[ -d "/usr/share/themes/${1}-dark" ]]; }
has_font() { fc-list 2>/dev/null | grep -qi "$1"; }

[[ "$EUID" -eq 0 ]] && {
	log_error "Do not run as root. Use sudo where needed."
	exit 1
}

# === Distro Detection ===
detect_distro() {
	[[ -f /etc/NIXOS ]] && echo "nixos" && return
	has_cmd pacman && echo "arch" && return
	has_cmd dnf && echo "fedora" && return
	has_cmd apt && echo "debian" && return
	echo "unknown"
}

DISTRO=$(detect_distro)
log_info "Detected: $DISTRO"

# === Package Filtering ===
# Maps packages to their binary/check - only for conflict-prone packages
declare -A BINARY_CHECK=(
	["matugen"]="matugen"
	["quickshell-git"]="qs"
	["kitty"]="kitty"
	["tmux"]="tmux"
	["fuzzel"]="fuzzel"
	["brightnessctl"]="brightnessctl"
	["ddcutil"]="ddcutil"
	["grim"]="grim"
	["slurp"]="slurp"
	["jq"]="jq"
	["playerctl"]="playerctl"
	["wtype"]="wtype"
	["mpvpaper"]="mpvpaper"
	["gradia"]="gradia"
	["pipx"]="pipx"
	["python-pipx"]="pipx"
	["zenity"]="zenity"
	["gpu-screen-recorder"]="gpu-screen-recorder"
)

declare -A THEME_CHECK=(
	["adw-gtk-theme"]="adw-gtk3"
	["adw-gtk3-theme"]="adw-gtk3"
)

declare -A FONT_CHECK=(
	["ttf-phosphor-icons"]="Phosphor"
)

filter_packages() {
	local pkgs=("$@")
	local needed=()

	for pkg in "${pkgs[@]}"; do
		local skip=0

		if [[ -n "${BINARY_CHECK[$pkg]}" ]] && has_cmd "${BINARY_CHECK[$pkg]}"; then
			log_info "Skipping $pkg (${BINARY_CHECK[$pkg]} found)"
			skip=1
		elif [[ -n "${THEME_CHECK[$pkg]}" ]] && has_theme "${THEME_CHECK[$pkg]}"; then
			log_info "Skipping $pkg (theme ${THEME_CHECK[$pkg]} found)"
			skip=1
		elif [[ -n "${FONT_CHECK[$pkg]}" ]] && has_font "${FONT_CHECK[$pkg]}"; then
			log_info "Skipping $pkg (font ${FONT_CHECK[$pkg]} found)"
			skip=1
		fi

		[[ $skip -eq 0 ]] && needed+=("$pkg")
	done

	echo "${needed[@]}"
}

# === Dependency Installation ===
install_dependencies() {
	case "$DISTRO" in
	nixos)
		local FLAKE_URI="${1:-github:Axenide/Ambxst}"
		nix profile list | grep -q "ddcutil" && nix profile remove ddcutil 2>/dev/null || true

		if nix profile list | grep -q "Ambxst"; then
			log_info "Updating Ambxst..."
			nix profile upgrade Ambxst --refresh --impure
		else
			log_info "Installing Ambxst..."
			nix profile add "$FLAKE_URI" --impure
		fi
		;;

	fedora)
		log_info "Enabling COPR repositories..."
		sudo dnf install -y dnf-plugins-core
		yes | sudo dnf copr enable errornointernet/quickshell
		yes | sudo dnf copr enable solopasha/hyprland
		yes | sudo dnf copr enable zirconium/packages
		yes | sudo dnf copr enable iucar/cran

		local PKGS=(
			kitty tmux fuzzel network-manager-applet blueman
			pipewire wireplumber easyeffects playerctl
			qt6-qtbase qt6-qtdeclarative qt6-qtwayland qt6-qtsvg qt6-qttools
			qt6-qtimageformats qt6-qtmultimedia qt6-qtshadertools
			kf6-syntax-highlighting kf6-breeze-icons hicolor-icon-theme
			brightnessctl ddcutil fontconfig grim slurp ImageMagick jq sqlite upower
			wl-clipboard wlsunset wtype zbar glib2 pipx zenity power-profiles-daemon
			python3.12 libnotify flatpak
			tesseract tesseract-langpack-eng tesseract-langpack-spa tesseract-langpack-jpn
			tesseract-langpack-chi_sim tesseract-langpack-chi_tra tesseract-langpack-kor tesseract-langpack-lat
			google-roboto-fonts google-roboto-mono-fonts dejavu-sans-fonts liberation-fonts
			google-noto-fonts-common google-noto-cjk-fonts google-noto-emoji-fonts
			mpvpaper matugen R-CRAN-phosphoricons adw-gtk3-theme quickshell-git unzip curl
		)

		log_info "Installing dependencies..."
		# shellcheck disable=SC2046
		sudo dnf install -y $(filter_packages "${PKGS[@]}")

		log_info "Installing Gradia (Flatpak)..."
		flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
		flatpak install -y flathub be.alexandervanhee.gradia 2>/dev/null || true

		install_phosphor_fonts
		;;

	arch)
		if ! has_cmd git || ! has_cmd makepkg; then
			log_info "Installing git and base-devel..."
			sudo pacman -S --needed --noconfirm git base-devel
		fi

		AUR_HELPER=""
		if has_cmd yay; then
			AUR_HELPER="yay"
		elif has_cmd paru; then
			AUR_HELPER="paru"
		else
			log_info "Installing yay-bin..."
			local YAY_TMP
			YAY_TMP="$(mktemp -d)"
			git clone "https://aur.archlinux.org/yay-bin.git" "$YAY_TMP"
			(cd "$YAY_TMP" && makepkg -si --noconfirm)
			rm -rf "$YAY_TMP"
			AUR_HELPER="yay"
		fi

		local PKGS=(
			kitty tmux fuzzel network-manager-applet blueman
			pipewire wireplumber pwvucontrol easyeffects ffmpeg x264 playerctl
			qt6-base qt6-declarative qt6-wayland qt6-svg qt6-tools qt6-imageformats qt6-multimedia qt6-shadertools
			libwebp libavif syntax-highlighting breeze-icons hicolor-icon-theme
			brightnessctl ddcutil fontconfig grim slurp imagemagick jq sqlite upower
			wl-clipboard wlsunset wtype zbar glib2 python-pipx zenity inetutils power-profiles-daemon
			python312 libnotify
			tesseract tesseract-data-eng tesseract-data-spa tesseract-data-jpn
			tesseract-data-chi_sim tesseract-data-chi_tra tesseract-data-kor tesseract-data-lat
			ttf-roboto ttf-roboto-mono ttf-dejavu ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji
			ttf-nerd-fonts-symbols
			matugen gpu-screen-recorder wl-clip-persist mpvpaper gradia
			quickshell-git ttf-phosphor-icons ttf-league-gothic adw-gtk-theme
		)

		log_info "Installing dependencies with $AUR_HELPER..."
		local FILTERED
		# shellcheck disable=SC2207
		FILTERED=($(filter_packages "${PKGS[@]}"))

		if [[ ${#FILTERED[@]} -gt 0 ]]; then
			$AUR_HELPER -S --noconfirm "${FILTERED[@]}"
		else
			log_info "All packages already installed"
		fi
		;;

	*)
		log_error "Unsupported distribution: $DISTRO"
		log_warn "Please install dependencies manually (see nix/packages/)."
		;;
	esac
}

install_phosphor_fonts() {
	has_font "Phosphor" && return

	log_info "Installing Phosphor Icons..."
	local VERSION="2.1.2"
	local TEMP_DIR FONT_DIR
	TEMP_DIR="$(mktemp -d)"
	FONT_DIR="$HOME/.local/share/fonts/phosphor"

	curl -sL "https://github.com/phosphor-icons/web/archive/refs/tags/v${VERSION}.zip" -o "$TEMP_DIR/phosphor.zip"
	unzip -q "$TEMP_DIR/phosphor.zip" -d "$TEMP_DIR"
	mkdir -p "$FONT_DIR"
	find "$TEMP_DIR" -name "*.ttf" -exec cp {} "$FONT_DIR/" \;
	rm -rf "$TEMP_DIR"
	fc-cache -f "$FONT_DIR"
	log_success "Phosphor Icons installed"
}

# === Migration ===
migrate_old_paths() {
	log_info "Checking for old Ambxst paths..."

	# Source migration (PascalCase -> lowercase)
	local OLD_SRC="$HOME/Ambxst"
	if [[ -d "$OLD_SRC" && ! -d "$INSTALL_PATH" ]]; then
		log_info "Migrating source: $OLD_SRC -> $INSTALL_PATH"
		mkdir -p "$(dirname "$INSTALL_PATH")"
		cp -r "$OLD_SRC" "$INSTALL_PATH"
	fi

	# Config migration
	local OLD_CONFIG="$HOME/.config/Ambxst"
	local NEW_CONFIG="$HOME/.config/ambxst"
	if [[ -d "$OLD_CONFIG" && ! -d "$NEW_CONFIG" ]]; then
		log_info "Migrating config: $OLD_CONFIG -> $NEW_CONFIG"
		mv "$OLD_CONFIG" "$NEW_CONFIG"
	fi

	# Share migration
	local OLD_SHARE="$HOME/.local/share/Ambxst"
	local NEW_SHARE="$HOME/.local/share/ambxst"
	if [[ -d "$OLD_SHARE" && ! -d "$NEW_SHARE" ]]; then
		log_info "Migrating share: $OLD_SHARE -> $NEW_SHARE"
		mv "$OLD_SHARE" "$NEW_SHARE"
	fi

	# State migration
	local OLD_STATE="$HOME/.local/state/Ambxst"
	local NEW_STATE="$HOME/.local/state/ambxst"
	if [[ -d "$OLD_STATE" && ! -d "$NEW_STATE" ]]; then
		log_info "Migrating state: $OLD_STATE -> $NEW_STATE"
		mv "$OLD_STATE" "$NEW_STATE"
	fi

	# Cache migration
	local OLD_CACHE_DIR="$HOME/.cache/Ambxst"
	local NEW_CACHE_DIR="$HOME/.cache/ambxst"
	if [[ -d "$OLD_CACHE_DIR" && ! -d "$NEW_CACHE_DIR" ]]; then
		log_info "Migrating cache: $OLD_CACHE_DIR -> $NEW_CACHE_DIR"
		mv "$OLD_CACHE_DIR" "$NEW_CACHE_DIR"
	fi

	# Legacy share -> cache migration (Wallpapers & Thumbnails)
	local NEW_CACHE="$HOME/.cache/ambxst"
	if [[ -d "$NEW_SHARE" ]]; then
		mkdir -p "$NEW_CACHE"

		if [[ -f "$NEW_SHARE/wallpapers.json" && ! -f "$NEW_CACHE/wallpapers.json" ]]; then
			log_info "Migrating wallpapers.json to cache..."
			cp "$NEW_SHARE/wallpapers.json" "$NEW_CACHE/wallpapers.json"
		fi

		if [[ -d "$NEW_SHARE/thumbnails" && ! -d "$NEW_CACHE/thumbnails" ]]; then
			log_info "Migrating thumbnails to cache..."
			cp -r "$NEW_SHARE/thumbnails" "$NEW_CACHE/thumbnails"
		fi
	fi

	# Config structure warning
	if [[ -f "$NEW_CONFIG/config.json" && ! -d "$NEW_CONFIG/config" ]]; then
		log_warn "Old single-file config detected."
		log_info "Ambxst now uses a multi-file configuration in $NEW_CONFIG/config/"
		log_info "Your old config.json remains at $NEW_CONFIG/config.json for reference."
	fi
}

# === Repository Setup ===
setup_repo() {
	[[ "$DISTRO" == "nixos" ]] && return

	if [[ ! -d "$INSTALL_PATH" ]]; then
		log_info "Cloning Ambxst to $INSTALL_PATH..."
		mkdir -p "$(dirname "$INSTALL_PATH")"
		git clone "$REPO_URL" "$INSTALL_PATH"
		return
	fi

	# Check if it's a git repository
	if [[ ! -d "$INSTALL_PATH/.git" ]]; then
		log_warn "$INSTALL_PATH exists but is not a git repository."
		log_info "Re-initializing repository..."
		local TMP_DIR
		TMP_DIR=$(mktemp -d)
		# Move everything to tmp, avoiding . and ..
		find "$INSTALL_PATH" -mindepth 1 -maxdepth 1 -exec mv -t "$TMP_DIR" {} +
		rm -rf "$INSTALL_PATH"
		git clone "$REPO_URL" "$INSTALL_PATH"
		log_info "Restoring files from old directory..."
		cp -rn "$TMP_DIR"/* "$INSTALL_PATH/" 2>/dev/null || true
		rm -rf "$TMP_DIR"
	fi

	log_info "Checking repository status..."
	git -C "$INSTALL_PATH" fetch origin

	local BRANCH
	BRANCH=$(git -C "$INSTALL_PATH" rev-parse --abbrev-ref HEAD)

	if [[ "$BRANCH" != "main" ]]; then
		log_warn "On branch '$BRANCH', not 'main'. Skipping update."
		return
	fi

	local HAS_CHANGES=0
	[[ -n "$(git -C "$INSTALL_PATH" status --porcelain)" ]] && HAS_CHANGES=1
	[[ -n "$(git -C "$INSTALL_PATH" log origin/main..HEAD)" ]] && HAS_CHANGES=1

	if [[ "$HAS_CHANGES" -eq 1 ]]; then
		echo -e "${YELLOW}⚠  Local changes detected on 'main'.${NC}"
		echo -e "${RED}This will DISCARD all local changes.${NC}"
		read -r -p "Continue? [y/N] " response </dev/tty
		[[ ! "$response" =~ ^[Yy]$ ]] && {
			log_warn "Update aborted."
			exit 0
		}
	fi

	log_info "Syncing with remote..."
	git -C "$INSTALL_PATH" reset --hard origin/main
}

# === Quickshell Build ===
install_quickshell() {
	[[ "$DISTRO" == "nixos" || "$DISTRO" == "fedora" ]] && return
	has_cmd qs && {
		log_info "Quickshell already installed"
		return
	}

	log_info "Building Quickshell from source..."
	local BUILD_DIR
	BUILD_DIR="$(mktemp -d)"
	git clone --recursive "$QUICKSHELL_REPO" "$BUILD_DIR"
	(
		cd "$BUILD_DIR"
		cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local"
		cmake --build build
		cmake --install build
	)
	rm -rf "$BUILD_DIR"
	log_success "Quickshell installed to ~/.local/bin/qs"
}

# === Python Tools ===
install_python_tools() {
	[[ "$DISTRO" == "nixos" ]] && return
	has_cmd pipx || {
		log_warn "pipx not found, skipping Python tools"
		return
	}

	log_info "Installing Python tools..."
	pipx install "litellm[proxy]" --python 3.12 2>/dev/null || true
	pipx ensurepath 2>/dev/null || true
}

# === Service Configuration ===
configure_services() {
	[[ "$DISTRO" == "nixos" ]] && return

	if has_cmd systemctl; then
		log_info "Configuring systemd services..."

		if systemctl is-enabled --quiet iwd 2>/dev/null || systemctl is-active --quiet iwd 2>/dev/null; then
			log_warn "Disabling iwd (conflicts with NetworkManager)..."
			sudo systemctl stop iwd
			sudo systemctl disable iwd
		fi

		systemctl is-enabled --quiet NetworkManager 2>/dev/null || {
			log_info "Enabling NetworkManager..."
			sudo systemctl enable --now NetworkManager
		}

		systemctl is-enabled --quiet bluetooth 2>/dev/null || {
			log_info "Enabling Bluetooth..."
			sudo systemctl enable --now bluetooth
		}

	elif has_cmd rc-service; then
		log_info "Configuring OpenRC services..."
		rc-update show | grep -q "iwd" && {
			sudo rc-service iwd stop 2>/dev/null || true
			sudo rc-update del iwd default 2>/dev/null || true
		}
		sudo rc-update add NetworkManager default 2>/dev/null || true
		sudo rc-service NetworkManager start 2>/dev/null || true
		sudo rc-update add bluetooth default 2>/dev/null || true
		sudo rc-service bluetooth start 2>/dev/null || true

	elif has_cmd sv; then
		log_info "Configuring runit services..."
		local SV_DIR="/var/service"
		[[ -L "$SV_DIR/iwd" ]] && sudo rm "$SV_DIR/iwd"
		[[ -d "/etc/sv/NetworkManager" && ! -L "$SV_DIR/NetworkManager" ]] && sudo ln -s /etc/sv/NetworkManager "$SV_DIR/"
		[[ -d "/etc/sv/bluetooth" && ! -L "$SV_DIR/bluetooth" ]] && sudo ln -s /etc/sv/bluetooth "$SV_DIR/"

	else
		log_warn "Unknown init system. Please enable NetworkManager and Bluetooth manually."
	fi
}

# === Launcher Setup ===
setup_launcher() {
	[[ "$DISTRO" == "nixos" ]] && return

	[[ -f "$HOME/.local/bin/ambxst" ]] && rm -f "$HOME/.local/bin/ambxst"

	sudo mkdir -p "$BIN_DIR"
	local LAUNCHER="$BIN_DIR/ambxst"

	log_info "Creating launcher at $LAUNCHER..."
	sudo tee "$LAUNCHER" >/dev/null <<-EOF
		#!/usr/bin/env bash
		export PATH="$HOME/.local/bin:\$PATH"
		export QML2_IMPORT_PATH="$HOME/.local/lib/qml:\$QML2_IMPORT_PATH"
		export QML_IMPORT_PATH="\$QML2_IMPORT_PATH"
		exec "$INSTALL_PATH/cli.sh" "\$@"
	EOF
	sudo chmod +x "$LAUNCHER"
	log_success "Launcher created"
}

# === Main ===
migrate_old_paths
install_dependencies "$1"
setup_repo
install_quickshell
install_python_tools
configure_services
setup_launcher

echo ""
log_success "Installation complete!"
[[ "$DISTRO" != "nixos" ]] && echo -e "Run ${GREEN}ambxst${NC} to start."
