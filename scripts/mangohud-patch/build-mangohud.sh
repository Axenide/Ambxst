#!/usr/bin/env bash
# Build MangoHud modificado con output SHM para NothingLess
set -euo pipefail

MANGOHUD_VERSION="v0.8.3"
MANGOHUD_DIR="/tmp/mangohud-build"
INSTALL_DIR="$HOME/.local/lib"

echo "=== Building MangoHud $MANGOHUD_VERSION with NothingLess FPS output ==="

# Clone MangoHud source
if [ ! -d "$MANGOHUD_DIR/MangoHud" ]; then
    mkdir -p "$MANGOHUD_DIR"
    git clone --depth 1 --branch "$MANGOHUD_VERSION" https://github.com/flightlessmango/MangoHud.git "$MANGOHUD_DIR/MangoHud"
fi

# Apply the FPS output patch
cd "$MANGOHUD_DIR/MangoHud"
if ! grep -q "nothingless_fps" src/overlay.cpp 2>/dev/null; then
    echo "Applying FPS output patch..."
    # Find the line where fps is calculated
    LINE=$(grep -n "sw_stats.fps = " src/overlay.cpp | head -1 | cut -d: -f1)
    if [ -n "$LINE" ]; then
        sed -i "${LINE}a\\
        // Write FPS to /dev/shm/nothingless_fps for NothingLess notch\\
        FILE *nfps = fopen(\"/dev/shm/nothingless_fps\", \"w\");\\
        if (nfps) {\
            fprintf(nfps, \"fps=%.1f\\npid=%d\\nframes=%lu\\nsource=mangohud\\n\",\\
                    sw_stats.fps, getpid(), (unsigned long)sw_stats.n_frames_since_update);\\
            fclose(nfps);\\
        }" src/overlay.cpp
        echo "Patch applied."
    fi
fi

# Build
echo "Building..."
pip3 install --user mako --break-system-packages 2>/dev/null || true
meson setup build --buildtype=release
ninja -C build

# Install
echo "Installing to $INSTALL_DIR..."
cp build/src/libMangoHud.so "$INSTALL_DIR/"
cp build/src/libMangoHud_shim.so "$INSTALL_DIR/"
cp build/src/libMangoHud_opengl.so "$INSTALL_DIR/"
cp build/src/mangohud "$INSTALL_DIR/../bin/mangohud-nothingless" 2>/dev/null || true

echo "✓ Done. MangoHud modificado instalado en $INSTALL_DIR"
