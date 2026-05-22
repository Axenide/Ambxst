#!/usr/bin/env python3
"""
Lockscreen Wallpaper Frame Extractor for NothingLess
Extracts first frame from video/GIF wallpapers for lockscreen background.
Only processes video and GIF files - skips regular images.
"""

import os
import subprocess
import sys
from pathlib import Path
from typing import Optional, Tuple

# Supported extensions for processing
VIDEO_EXTENSIONS = {".mp4", ".webm", ".mov", ".avi", ".mkv"}
GIF_EXTENSIONS = {".gif"}


class LockscreenWallpaperGenerator:
    def __init__(self, wallpaper_path: str, data_path: str):
        self.current_wallpaper = Path(wallpaper_path).expanduser()
        self.data_path = Path(data_path)
        self.lockscreen_dir: Optional[Path] = None

    def validate_wallpaper(self) -> bool:
        """Validate wallpaper exists."""
        if not self.current_wallpaper.exists():
            print(f"ERROR: Wallpaper not found: {self.current_wallpaper}")
            return False

        # Setup lockscreen directory in QuickShell data path
        self.lockscreen_dir = self.data_path / "lockscreen"
        self.lockscreen_dir.mkdir(parents=True, exist_ok=True)

        print(f"✓ Current wallpaper: {self.current_wallpaper.name}")
        print(f"✓ Lockscreen cache: {self.lockscreen_dir}")
        return True

    def is_video_or_gif(self) -> bool:
        """Check if current wallpaper is a video or GIF."""
        ext = self.current_wallpaper.suffix.lower()
        return ext in VIDEO_EXTENSIONS or ext in GIF_EXTENSIONS

    def get_output_path(self) -> Path:
        """Get output path for lockscreen wallpaper."""
        if self.lockscreen_dir is None:
            raise RuntimeError("Lockscreen directory not initialized")

        # Create output filename: original_name.extension.jpg
        output_name = self.current_wallpaper.name + ".jpg"
        return self.lockscreen_dir / output_name

    def clean_lockscreen_dir(self) -> None:
        """Remove all existing files in lockscreen directory."""
        if self.lockscreen_dir is None:
            return

        try:
            for file in self.lockscreen_dir.glob("*"):
                if file.is_file():
                    file.unlink()
                    print(f"✓ Removed old file: {file.name}")
        except Exception as e:
            print(f"WARNING: Failed to clean directory: {e}")

    def extract_first_frame(self) -> Tuple[bool, str]:
        """Extract first frame from video/GIF using FFmpeg."""
        output_path = self.get_output_path()

        try:
            # FFmpeg command to extract first frame
            cmd = [
                "ffmpeg",
                "-y",
                "-i",
                str(self.current_wallpaper),
                "-vframes",
                "1",  # Extract only first frame
                "-q:v",
                "2",  # High quality
                "-f",
                "image2",  # Force image format
                str(output_path),
            ]

            print(f"⚡ Extracting first frame...")

            # Run FFmpeg
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

            if result.returncode == 0 and output_path.exists():
                print(f"✅ Frame saved: {output_path.name}")
                return True, "Success"
            else:
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                return False, error_msg

        except subprocess.TimeoutExpired:
            return False, "Timeout"
        except Exception as e:
            return False, str(e)

    def run(self) -> int:
        """Main execution function."""
        print("🔒 NothingLess Lockscreen Wallpaper Generator")
        print("=" * 40)

        # Validate wallpaper
        if not self.validate_wallpaper():
            return 1

        # Check if wallpaper is video or GIF
        if not self.is_video_or_gif():
            ext = self.current_wallpaper.suffix.lower()
            print(f"ℹ️  Wallpaper is a regular image ({ext})")
            print("ℹ️  No processing needed - use wallpaper directly")
            return 0

        # Clean existing files
        self.clean_lockscreen_dir()

        # Extract first frame
        success, message = self.extract_first_frame()

        if success:
            print("🎉 Lockscreen wallpaper ready!")
            return 0
        else:
            print(f"❌ Failed to extract frame: {message}")
            return 1


def main():
    """Entry point."""
    if len(sys.argv) != 3:
        print("Usage: python3 lockscreen_wallpaper.py <wallpaper_path> <data_path>")
        print(
            "Example: python3 lockscreen_wallpaper.py /path/to/video.mp4 ~/.local/share/quickshell"
        )
        return 1

    wallpaper_path = sys.argv[1]
    data_path = sys.argv[2]
    generator = LockscreenWallpaperGenerator(wallpaper_path, data_path)
    return generator.run()


if __name__ == "__main__":
    sys.exit(main())
