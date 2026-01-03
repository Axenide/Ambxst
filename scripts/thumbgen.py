#!/usr/bin/env python3
"""
Thumbnail Generator for Ambxst Wallpaper System
Generates thumbnails for video files, images, and GIFs using FFmpeg and ImageMagick with multithreading.
"""

import json
import os
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import List, Optional, Tuple

# Supported extensions
VIDEO_EXTENSIONS = {".mp4", ".webm", ".mov", ".avi", ".mkv"}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".tif", ".tiff", ".bmp"}
GIF_EXTENSIONS = {".gif"}

# Default thumbnail size
THUMBNAIL_SIZE = "140x140"


class ThumbnailGenerator:
    def __init__(
        self,
        config_path: str,
        cache_base_path: str,
        fallback_path: Optional[str] = None,
    ):
        self.config_path = Path(config_path)
        self.cache_base_path = Path(cache_base_path)
        self.fallback_path = Path(fallback_path).expanduser() if fallback_path else None
        self.wall_path: Optional[Path] = None
        self.thumbnails_dir: Optional[Path] = None
        self.files_to_process = []
        self.total_files = 0
        self.processed_count = 0
        self.lock = threading.Lock()

    def load_config(self) -> bool:
        """Load wallpaper configuration."""
        try:
            if not self.config_path.exists():
                print(f"ERROR: Config file not found: {self.config_path}")
                return False

            with open(self.config_path, "r") as f:
                config = json.load(f)

            wall_path = config.get("wallPath", "")
            if not wall_path:
                if self.fallback_path:
                    print(
                        f"ℹ️  wallPath not found in config, using fallback: {self.fallback_path}"
                    )
                    wall_path = str(self.fallback_path)
                else:
                    print("ERROR: wallPath not found in config")
                    return False

            self.wall_path = Path(wall_path).expanduser()
            if not self.wall_path.exists():
                print(f"ERROR: Wallpaper directory not found: {self.wall_path}")
                return False

            # Setup thumbnails directory using provided cache base
            self.thumbnails_dir = self.cache_base_path / "thumbnails"
            self.thumbnails_dir.mkdir(parents=True, exist_ok=True)

            print(f"✓ Config loaded: {self.wall_path}")
            print(f"✓ Thumbnails cache: {self.thumbnails_dir}")
            return True

        except Exception as e:
            print(f"ERROR loading config: {e}")
            return False

    def find_files(self) -> List[Path]:
        """Find all media files in wallpaper directory and subdirectories, excluding hidden folders."""
        files = []

        if self.wall_path is None:
            print("ERROR: wall_path not initialized")
            return []

        try:
            # Recursively find all files in wallpaper directory and subdirectories
            for file_path in self.wall_path.rglob("*"):
                if file_path.is_file() and not file_path.name.startswith("."):
                    # Check if any parent directory is hidden
                    if not any(
                        part.startswith(".")
                        for part in file_path.relative_to(self.wall_path).parts[:-1]
                    ):
                        ext = file_path.suffix.lower()
                        if (
                            ext in VIDEO_EXTENSIONS
                            or ext in IMAGE_EXTENSIONS
                            or ext in GIF_EXTENSIONS
                        ):
                            files.append(file_path)

            # Sort for consistent ordering
            files.sort()

            print(f"✓ Found {len(files)} media files")
            return files

        except Exception as e:
            print(f"ERROR scanning directory: {e}")
            return []

    def get_thumbnail_path(self, file_path: Path) -> Path:
        """Get thumbnail path for a media file in the proxy structure."""
        if self.wall_path is None or self.thumbnails_dir is None:
            raise RuntimeError("Paths not initialized")

        # Get relative path from wall_path
        try:
            relative_path = file_path.relative_to(self.wall_path)
        except ValueError:
            raise ValueError(f"File {file_path} is not within {self.wall_path}")

        # Create thumbnail name with .jpg extension
        thumbnail_name = file_path.name + ".jpg"

        # Build the proxy path
        thumbnail_path = self.thumbnails_dir / relative_path.parent / thumbnail_name

        return thumbnail_path

    def needs_thumbnail(self, file_path: Path) -> bool:
        """Check if file needs thumbnail generation."""
        thumbnail_path = self.get_thumbnail_path(file_path)

        # If thumbnail doesn't exist, needs generation
        if not thumbnail_path.exists():
            return True

        # If file is newer than thumbnail, needs regeneration
        try:
            file_mtime = file_path.stat().st_mtime
            thumbnail_mtime = thumbnail_path.stat().st_mtime
            return file_mtime > thumbnail_mtime
        except:
            return True

    def generate_video_thumbnail(self, video_path: Path) -> Tuple[bool, str]:
        """Generate thumbnail for a video file using FFmpeg."""
        thumbnail_path = self.get_thumbnail_path(video_path)

        try:
            # Ensure parent directory exists
            thumbnail_path.parent.mkdir(parents=True, exist_ok=True)

            # FFmpeg command for high-quality thumbnail
            cmd = [
                "ffmpeg",
                "-y",
                "-i",
                str(video_path),
                "-ss",
                "00:00:01",  # Skip first second to avoid black frames
                "-vframes",
                "1",  # Extract only 1 frame
                "-vf",
                f"scale=140:140:force_original_aspect_ratio=increase,crop=140:140",
                "-q:v",
                "2",  # High quality
                "-f",
                "image2",  # Force image format
                str(thumbnail_path),
            ]

            # Run FFmpeg with error suppression
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30,  # 30 second timeout per video
            )

            if result.returncode == 0 and thumbnail_path.exists():
                return True, "Success"
            else:
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                return False, error_msg

        except subprocess.TimeoutExpired:
            return False, "Timeout"
        except Exception as e:
            return False, str(e)

    def generate_image_thumbnail(self, image_path: Path) -> Tuple[bool, str]:
        """Generate thumbnail for an image file using ImageMagick."""
        thumbnail_path = self.get_thumbnail_path(image_path)

        try:
            # Ensure parent directory exists
            thumbnail_path.parent.mkdir(parents=True, exist_ok=True)

            # ImageMagick command for high-quality thumbnail
            cmd = [
                "convert",
                str(image_path),
                "-resize",
                "140x140^",  # Force resize to exact dimensions
                "-gravity",
                "center",  # Center the crop
                "-extent",
                "140x140",  # Crop to exact size
                "-quality",
                "85",  # High quality JPEG
                str(thumbnail_path),
            ]

            # Run ImageMagick
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=15,  # 15 second timeout per image
            )

            if result.returncode == 0 and thumbnail_path.exists():
                return True, "Success"
            else:
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                return False, error_msg

        except subprocess.TimeoutExpired:
            return False, "Timeout"
        except Exception as e:
            return False, str(e)

    def generate_gif_thumbnail(self, gif_path: Path) -> Tuple[bool, str]:
        """Generate thumbnail for a GIF file using FFmpeg (extract first frame)."""
        thumbnail_path = self.get_thumbnail_path(gif_path)

        try:
            # Ensure parent directory exists
            thumbnail_path.parent.mkdir(parents=True, exist_ok=True)

            # FFmpeg command to extract first frame from GIF
            cmd = [
                "ffmpeg",
                "-y",
                "-i",
                str(gif_path),
                "-vframes",
                "1",  # Extract only the first frame
                "-vf",
                f"scale=140:140:force_original_aspect_ratio=increase,crop=140:140",
                "-q:v",
                "2",  # High quality
                "-f",
                "image2",  # Force image format
                str(thumbnail_path),
            ]

            # Run FFmpeg
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=15,  # 15 second timeout per GIF
            )

            if result.returncode == 0 and thumbnail_path.exists():
                return True, "Success"
            else:
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                return False, error_msg

        except subprocess.TimeoutExpired:
            return False, "Timeout"
        except Exception as e:
            return False, str(e)

    def generate_single_thumbnail(self, file_path: Path) -> Tuple[bool, str]:
        """Generate thumbnail for a single file based on its type."""
        try:
            ext = file_path.suffix.lower()
            if ext in VIDEO_EXTENSIONS:
                success, message = self.generate_video_thumbnail(file_path)
            elif ext in IMAGE_EXTENSIONS:
                success, message = self.generate_image_thumbnail(file_path)
            elif ext in GIF_EXTENSIONS:
                success, message = self.generate_gif_thumbnail(file_path)
            else:
                return False, f"Unknown file type: {ext}"

            # Update progress
            with self.lock:
                self.processed_count += 1
                progress = (self.processed_count / self.total_files) * 100
                status = "✓" if success else "✗"
                print(
                    f"[{self.processed_count}/{self.total_files}] {status} {file_path.name} ({progress:.1f}%)"
                )

            return success, message

        except Exception as e:
            return False, str(e)

    def process_files(self, max_workers: int = 4) -> None:
        """Process files with multithreading."""
        all_files = self.files_to_process

        if not all_files:
            print("✓ All thumbnails are up to date")
            return

        print(f"⚡ Processing {len(all_files)} files with {max_workers} workers...")
        start_time = time.time()

        failed_files = []

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all jobs
            future_to_file = {
                executor.submit(self.generate_single_thumbnail, file_path): file_path
                for file_path in all_files
            }

            # Process completed jobs
            for future in as_completed(future_to_file):
                file_path = future_to_file[future]
                try:
                    success, message = future.result()
                    if not success:
                        failed_files.append((file_path, message))

                except Exception as e:
                    failed_files.append((file_path, str(e)))

        elapsed = time.time() - start_time
        success_count = self.total_files - len(failed_files)

        print(f"\n🏁 Processing complete in {elapsed:.1f}s")
        print(f"✅ Success: {success_count}/{self.total_files}")

        if failed_files:
            print(f"❌ Failed: {len(failed_files)}")
            for file_path, error in failed_files[:3]:  # Show first 3 errors
                print(f"   • {file_path.name}: {error}")
            if len(failed_files) > 3:
                print(f"   ... and {len(failed_files) - 3} more")

    def run(self) -> int:
        """Main execution function."""
        print("🖼️  Ambxst Thumbnail Generator")
        print("=" * 40)

        # Load configuration
        if not self.load_config():
            return 1

        # Find all files
        files = self.find_files()
        if not files:
            print("ℹ️  No media files found")
            return 0

        # Filter files that need thumbnails
        for file_path in files:
            if self.needs_thumbnail(file_path):
                self.files_to_process.append(file_path)

        self.total_files = len(self.files_to_process)

        if self.total_files == 0:
            print("✓ All thumbnails are up to date")
            return 0

        print(f"📋 {self.total_files} files need thumbnail generation")

        # Determine optimal worker count
        max_workers = min(4, os.cpu_count() or 1, self.total_files)

        # Process files
        try:
            self.process_files(max_workers)
            print("🎉 Thumbnail generation complete!")
            return 0
        except KeyboardInterrupt:
            print("\n⚠️  Interrupted by user")
            return 130
        except Exception as e:
            print(f"❌ Unexpected error: {e}")
            return 1


def main():
    """Entry point."""
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        print(
            "Usage: python3 generate_thumbnails.py <config_path> <cache_base_path> [fallback_wall_path]"
        )
        return 1

    config_path = sys.argv[1]
    cache_base_path = sys.argv[2]
    fallback_path = sys.argv[3] if len(sys.argv) == 4 else None

    generator = ThumbnailGenerator(config_path, cache_base_path, fallback_path)
    return generator.run()


if __name__ == "__main__":
    sys.exit(main())
