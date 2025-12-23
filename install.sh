#!/usr/bin/env sh
set -e

FLAKE_URI="${1:-github:Axenide/Ambxst}"

echo "🚀 Ambxst installer/updater"

# === Helper: check if a profile already includes Ambxst ===
profile_has_ambxst() {
  nix profile list | grep -q "Ambxst"
}

# === Helper: ensure a nixpkgs package is available (install or skip) ===
ensure_pkg() {
  local pkg="$1"
  local cmd="$2"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "📦 Installing $pkg..."
    nix profile install "nixpkgs#$pkg"
  else
    echo "✔ $pkg already installed"
  fi
}

# === Detect NixOS ===
if [ -f /etc/NIXOS ]; then
  echo "🟦 NixOS detected"

  echo "🔁 Checking if Ambxst is already in the Nix profile..."
  if profile_has_ambxst; then
    echo "🔼 Updating Ambxst..."
    nix profile upgrade Ambxst
  else
    echo "✨ Installing Ambxst..."
    nix profile add "$FLAKE_URI"
  fi

  echo "🎉 Done!"
  exit 0
fi

echo "🟢 Non-NixOS detected"

# === Install Nix if missing ===
if ! command -v nix >/dev/null 2>&1; then
  echo "📥 Installing Nix..."
  curl -fsSL https://install.determinate.systems/nix |
    sh -s -- install --determinate
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
else
  echo "✔ Nix already installed"
fi

# === Enable allowUnfree ===
mkdir -p ~/.config/nixpkgs
if ! grep -q "allowUnfree" ~/.config/nixpkgs/config.nix 2>/dev/null; then
  echo "🔑 Enabling allowUnfree"
  cat >~/.config/nixpkgs/config.nix <<EOF
{
  allowUnfree = true;
}
EOF
else
  echo "✔ allowUnfree already enabled"
fi

# === Ensure system-level tools via Nix profile ===
ensure_pkg ddcutil ddcutil
ensure_pkg power-profiles-daemon powerprofilesctl
ensure_pkg networkmanager nmcli

# === Warn about daemons ===
if command -v systemctl >/dev/null 2>&1; then
  for svc in NetworkManager power-profiles-daemon; do
    if systemctl is-active --quiet "$svc"; then
      echo "✔ $svc daemon running"
    else
      echo "⚠ $svc daemon NOT running. Start it with:"
      echo "   sudo systemctl enable --now $svc"
    fi
  done
fi

echo "ℹ ddcutil requires i2c group + udev rules if not already set."

# === Configure fontconfig to recognize Nix fonts ===
echo "🔤 Setting up fontconfig for Nix fonts..."

mkdir -p ~/.config/fontconfig/conf.d

if [ ! -f ~/.config/fontconfig/conf.d/10-nix-fonts.conf ]; then
  echo "📝 Creating user fontconfig..."
  cat >~/.config/fontconfig/conf.d/10-nix-fonts.conf <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>~/.nix-profile/share/fonts</dir>
</fontconfig>
EOF
else
  echo "✔ User fontconfig already exists"
fi

if [ ! -f /etc/fonts/conf.d/90-nix-fonts.conf ]; then
  echo "📝 Creating system fontconfig (requires sudo)..."
  sudo mkdir -p /etc/fonts/conf.d
  sudo tee /etc/fonts/conf.d/90-nix-fonts.conf >/dev/null <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>/nix/var/nix/profiles/default/share/fonts</dir>
</fontconfig>
EOF
  echo "✔ System fontconfig created"
else
  echo "✔ System fontconfig already exists"
fi

echo "🔄 Rebuilding font cache..."
fc-cache -fv >/dev/null 2>&1
if command -v sudo >/dev/null 2>&1; then
  sudo fc-cache -fv >/dev/null 2>&1
fi
echo "✔ Font cache updated"

# === Configure icon theme paths for Nix ===
echo "🎨 Setting up icon theme paths for Nix..."

mkdir -p ~/.config/environment.d

if [ ! -f ~/.config/environment.d/nix-icons.conf ]; then
  echo "📝 Creating environment.d config for Nix icons..."
  cat >~/.config/environment.d/nix-icons.conf <<EOF
XDG_DATA_DIRS=$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share:\$XDG_DATA_DIRS
EOF
  echo "✔ Icon paths configured in environment.d"
  echo "⚠ Logout and login again to apply XDG_DATA_DIRS changes"
else
  echo "✔ Icon paths already configured"
fi

# Also set for current session
export XDG_DATA_DIRS="$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# Update icon cache if gtk-update-icon-cache is available
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  echo "🔄 Updating icon cache..."
  for icon_dir in "$HOME/.nix-profile/share/icons"/* "/nix/var/nix/profiles/default/share/icons"/*; do
    if [ -d "$icon_dir" ]; then
      gtk-update-icon-cache -f -t "$icon_dir" 2>/dev/null || true
    fi
  done
  echo "✔ Icon cache updated"
else
  echo "ℹ gtk-update-icon-cache not found, skipping icon cache update"
fi

# === Compile ambxst-auth if missing OR if source updated ===
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

if [ ! -f "$INSTALL_DIR/ambxst-auth" ]; then
  echo "🔨 ambxst-auth missing — compiling..."
  NEED_COMPILE=1
else
  echo "✔ ambxst-auth already exists"
fi

TEMP_DIR="$(mktemp -d)"
echo "📥 Fetching Ambxst repo to extract auth..."
git clone --depth 1 https://github.com/Axenide/Ambxst.git "$TEMP_DIR"
AUTH_SRC="$TEMP_DIR/modules/lockscreen"

if [ -n "$NEED_COMPILE" ]; then
  echo "🔨 Building ambxst-auth..."
  cd "$AUTH_SRC"
  gcc -o ambxst-auth auth.c -lpam -Wall -Wextra -O2
  cp ambxst-auth "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/ambxst-auth"
  echo "✔ ambxst-auth installed"
fi

rm -rf "$TEMP_DIR"

# === Install/update Ambxst flake ===
echo "🔁 Checking Ambxst in Nix profile..."
if profile_has_ambxst; then
  echo "🔼 Updating Ambxst..."
  nix profile upgrade Ambxst --impure
else
  echo "✨ Installing Ambxst..."
  nix profile add "$FLAKE_URI" --impure
fi

echo "🎉 Ambxst installed/updated successfully!"
echo "👉 Run 'ambxst' to start."
