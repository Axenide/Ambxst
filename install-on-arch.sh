#!/usr/bin/sh
INSTALL_DIR="$HOME/Documents/Ambxst"

cd "$HOME/Documents/"
echo 'Fetching Repo..'
git clone --recurse-submodules https://github.com/brys0/Ambxst.git
cd "$INSTALL_DIR"
echo '✔ Downloaded repo'

echo 'Installing deps for quickshell..'
sudo pacman -Su --needed --noconfirm gcc-libs glibc hicolor-icon-theme jemalloc libdrm libglvnd libpipewire libxcb mesa pam qt6-base qt6-declarative qt6-svg qt6-wayland cli11 cmake ninja
echo '✔ Installed.'

echo 'Building quickshell..'
    cd "$INSTALL_DIR/quickshell"
    cmake -GNinja -B build
    cmake --build build
echo '✔ Built quickshell.'

echo 'Installing quickshell..'
   sudo cmake --install build
echo '✔ Installed quickshell.'

# === Compile ambxst-auth if missing OR if source updated ===
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

if [ ! -f "$BIN_DIR/ambxst-auth" ]; then
  echo "🔨 ambxst-auth missing — compiling..."
  NEED_COMPILE=1
else
  echo "✔ ambxst-auth already exists"
fi


AUTH_SRC="$INSTALL_DIR/modules/lockscreen"

if [ -n "$NEED_COMPILE" ]; then
  echo "🔨 Building ambxst-auth..."
  cd "$AUTH_SRC"
  gcc -o ambxst-auth auth.c -lpam -Wall -Wextra -O2
  cp ambxst-auth "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/ambxst-auth"
  echo "✔ ambxst-auth installed"
fi
