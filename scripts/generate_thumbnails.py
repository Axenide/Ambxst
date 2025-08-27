#!/usr/bin/env python3
"""
Video Thumbnail Generator for Ambyst Wallpaper System
Generates thumbnails for video files using FFmpeg with multithreading.
"""

import os
import sys
import json
import threading
import subprocess
import time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Tuple, Optional

# Supported video extensions
VIDEO_EXTENSIONS = {'.mp4', '.webm', '.mov', '.avi', '.mkv'}

# Default thumbnail size
THUMBNAIL_SIZE = "320x240"

class ThumbnailGenerator:
    def __init__(self, config_path: str):
        self.config_path = Path(config_path)
        self.wall_path: Optional[Path] = None
        self.cache_dir: Optional[Path] = None
        self.videos_to_process = []
        self.total_videos = 0
        self.processed_count = 0
        self.lock = threading.Lock()
        
    def load_config(self) -> bool:
        """Load wallpaper configuration."""
        try:
            if not self.config_path.exists():
                print(f"ERROR: Config file not found: {self.config_path}")
                return False
                
            with open(self.config_path, 'r') as f:
                config = json.load(f)
                
            wall_path = config.get('wallPath', '')
            if not wall_path:
                print("ERROR: wallPath not found in config")
                return False
                
            self.wall_path = Path(wall_path).expanduser()
            if not self.wall_path.exists():
                print(f"ERROR: Wallpaper directory not found: {self.wall_path}")
                return False
                
            # Setup cache directory
            home = Path.home()
            self.cache_dir = home / '.cache' / 'quickshell' / 'video_thumbnails'
            self.cache_dir.mkdir(parents=True, exist_ok=True)
            
            print(f"✓ Config loaded: {self.wall_path}")
            print(f"✓ Cache directory: {self.cache_dir}")
            return True
            
        except Exception as e:
            print(f"ERROR loading config: {e}")
            return False
    
    def find_videos(self) -> List[Path]:
        """Find all video files in wallpaper directory."""
        videos = []
        
        if self.wall_path is None:
            print("ERROR: wall_path not initialized")
            return []
        
        try:
            for file_path in self.wall_path.iterdir():
                if file_path.is_file() and file_path.suffix.lower() in VIDEO_EXTENSIONS:
                    videos.append(file_path)
                    
            videos.sort()  # Consistent ordering
            print(f"✓ Found {len(videos)} video files")
            return videos
            
        except Exception as e:
            print(f"ERROR scanning directory: {e}")
            return []
    
    def get_thumbnail_path(self, video_path: Path) -> Path:
        """Get thumbnail path for a video file."""
        if self.cache_dir is None:
            raise RuntimeError("cache_dir not initialized")
        
        thumbnail_name = video_path.stem + '.jpg'
        return self.cache_dir / thumbnail_name
    
    def needs_thumbnail(self, video_path: Path) -> bool:
        """Check if video needs thumbnail generation."""
        thumbnail_path = self.get_thumbnail_path(video_path)
        
        # If thumbnail doesn't exist, needs generation
        if not thumbnail_path.exists():
            return True
            
        # If video is newer than thumbnail, needs regeneration
        try:
            video_mtime = video_path.stat().st_mtime
            thumbnail_mtime = thumbnail_path.stat().st_mtime
            return video_mtime > thumbnail_mtime
        except:
            return True
    
    def generate_single_thumbnail(self, video_path: Path) -> Tuple[bool, str]:
        """Generate thumbnail for a single video."""
        thumbnail_path = self.get_thumbnail_path(video_path)
        
        try:
            # FFmpeg command for high-quality thumbnail
            cmd = [
                'ffmpeg', '-y',
                '-i', str(video_path),
                '-ss', '00:00:01',  # Skip first second to avoid black frames
                '-vframes', '1',    # Extract only 1 frame
                '-vf', f'scale=320:240:force_original_aspect_ratio=increase,crop=320:240',
                '-q:v', '2',        # High quality
                '-f', 'image2',     # Force image format
                str(thumbnail_path)
            ]
            
            # Run FFmpeg with error suppression
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30  # 30 second timeout per video
            )
            
            if result.returncode == 0 and thumbnail_path.exists():
                with self.lock:
                    self.processed_count += 1
                    progress = (self.processed_count / self.total_videos) * 100
                    print(f"[{self.processed_count}/{self.total_videos}] ✓ {video_path.name} ({progress:.1f}%)")
                
                return True, "Success"
            else:
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                return False, error_msg
                
        except subprocess.TimeoutExpired:
            return False, "Timeout"
        except Exception as e:
            return False, str(e)
    
    def process_videos(self, max_workers: int = 4) -> None:
        """Process videos with multithreading."""
        if not self.videos_to_process:
            print("✓ All videos already have thumbnails")
            return
            
        print(f"⚡ Processing {len(self.videos_to_process)} videos with {max_workers} workers...")
        start_time = time.time()
        
        failed_videos = []
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all jobs
            future_to_video = {
                executor.submit(self.generate_single_thumbnail, video): video 
                for video in self.videos_to_process
            }
            
            # Process completed jobs
            for future in as_completed(future_to_video):
                video = future_to_video[future]
                try:
                    success, message = future.result()
                    if not success:
                        failed_videos.append((video, message))
                        with self.lock:
                            self.processed_count += 1
                            progress = (self.processed_count / self.total_videos) * 100
                            print(f"[{self.processed_count}/{self.total_videos}] ✗ {video.name} - {message} ({progress:.1f}%)")
                            
                except Exception as e:
                    failed_videos.append((video, str(e)))
                    with self.lock:
                        self.processed_count += 1
                        progress = (self.processed_count / self.total_videos) * 100
                        print(f"[{self.processed_count}/{self.total_videos}] ✗ {video.name} - Exception: {e} ({progress:.1f}%)")
        
        elapsed = time.time() - start_time
        success_count = self.total_videos - len(failed_videos)
        
        print(f"\n🏁 Processing complete in {elapsed:.1f}s")
        print(f"✅ Success: {success_count}/{self.total_videos}")
        
        if failed_videos:
            print(f"❌ Failed: {len(failed_videos)}")
            for video, error in failed_videos[:3]:  # Show first 3 errors
                print(f"   • {video.name}: {error}")
            if len(failed_videos) > 3:
                print(f"   ... and {len(failed_videos) - 3} more")
    
    def run(self) -> int:
        """Main execution function."""
        print("🎬 Ambyst Video Thumbnail Generator")
        print("=" * 40)
        
        # Load configuration
        if not self.load_config():
            return 1
        
        # Find all videos
        all_videos = self.find_videos()
        if not all_videos:
            print("ℹ️  No video files found")
            return 0
        
        # Filter videos that need thumbnails
        self.videos_to_process = [
            video for video in all_videos 
            if self.needs_thumbnail(video)
        ]
        
        self.total_videos = len(self.videos_to_process)
        
        if self.total_videos == 0:
            print("✓ All thumbnails are up to date")
            return 0
        
        print(f"📋 {self.total_videos} videos need thumbnail generation")
        
        # Determine optimal worker count
        max_workers = min(4, os.cpu_count() or 1, self.total_videos)
        
        # Process videos
        try:
            self.process_videos(max_workers)
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
    if len(sys.argv) != 2:
        print("Usage: python3 generate_thumbnails.py <config_path>")
        print("Example: python3 generate_thumbnails.py modules/widgets/wallpapers/wallpaper_config.json")
        return 1
    
    config_path = sys.argv[1]
    generator = ThumbnailGenerator(config_path)
    return generator.run()

if __name__ == '__main__':
    sys.exit(main())