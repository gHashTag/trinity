#!/usr/bin/env python3
"""
LED Pattern Analyzer for TRINITY FPGA Testing
Analyzes video to detect LED blinking patterns
"""

import cv2
import numpy as np
import json
import sys
from pathlib import Path
from datetime import datetime

class LEDPatternAnalyzer:
    def __init__(self, video_path, led_region=None):
        """
        Args:
            video_path: Path to video file
            led_region: (x, y, w, h) tuple for LED ROI, None = auto-detect
        """
        self.video_path = Path(video_path)
        self.led_region = led_region
        self.cap = cv2.VideoCapture(str(video_path))
        self.fps = self.cap.get(cv2.CAP_PROP_FPS)
        self.frame_count = int(self.cap.get(cv2.CAP_PROP_FRAME_COUNT))

    def detect_led_region(self, sample_frames=10):
        """Auto-detect LED region by finding brightest spots"""
        print("🔍 Detecting LED region...")
        frames = []
        for i in range(min(sample_frames, self.frame_count)):
            self.cap.set(cv2.CAP_PROP_POS_FRAMES, i * (self.frame_count // sample_frames))
            ret, frame = self.cap.read()
            if ret:
                frames.append(frame)

        if not frames:
            raise ValueError("No frames captured")

        # Average all frames
        avg_frame = np.mean(frames, axis=0).astype(np.uint8)

        # Convert to grayscale
        gray = cv2.cvtColor(avg_frame, cv2.COLOR_BGR2GRAY)

        # Find brightest spot (LED)
        min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(gray)

        # Define ROI around brightest spot
        roi_size = 30
        h, w = gray.shape
        x = max(0, max_loc[0] - roi_size)
        y = max(0, max_loc[1] - roi_size)
        x2 = min(w, max_loc[0] + roi_size)
        y2 = min(h, max_loc[1] + roi_size)

        self.led_region = (x, y, x2 - x, y2 - y)
        print(f"   LED region: {self.led_region}")
        print(f"   Max brightness: {max_val} at {max_loc}")

        return self.led_region

    def analyze_brightness(self):
        """Extract brightness timeline from video"""
        print("📊 Analyzing brightness...")
        if not self.led_region:
            self.detect_led_region()

        x, y, w, h = self.led_region
        brightness = []
        timestamps = []

        self.cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
        frame_idx = 0

        while True:
            ret, frame = self.cap.read()
            if not ret:
                break

            # Extract ROI
            roi = frame[y:y+h, x:x+w]

            # Calculate average brightness
            # Convert to grayscale first
            gray_roi = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
            bright = np.mean(gray_roi)
            brightness.append(bright)
            timestamps.append(frame_idx / self.fps)

            frame_idx += 1

            # Show progress
            if frame_idx % 30 == 0:
                print(f"   Processed {frame_idx}/{self.frame_count} frames")

        return np.array(brightness), np.array(timestamps)

    def classify_pattern(self, brightness, timestamps):
        """Classify the LED blinking pattern"""
        print("🔬 Classifying pattern...")

        # Normalize brightness
        bright_norm = (brightness - np.min(brightness)) / (np.max(brightness) - np.min(brightness) + 1e-6)

        # Threshold for ON state
        threshold = 0.5
        on_states = bright_norm > threshold

        # Count transitions
        transitions = 0
        for i in range(1, len(on_states)):
            if on_states[i] != on_states[i-1]:
                transitions += 1

        # Calculate frequency
        # Each blink has 2 transitions (ON→OFF, OFF→ON)
        blinks = transitions // 2
        duration = timestamps[-1] - timestamps[0]
        frequency = blinks / duration if duration > 0 else 0

        # Calculate variability (for chaos detection)
        on_periods = []
        off_periods = []
        current_on = on_states[0]
        period_length = 0

        for state in on_states:
            if state == current_on:
                period_length += 1
            else:
                if current_on:
                    on_periods.append(period_length)
                else:
                    off_periods.append(period_length)
                current_on = state
                period_length = 1

        # Calculate coefficient of variation
        all_periods = on_periods + off_periods
        if all_periods:
            cv_period = np.std(all_periods) / (np.mean(all_periods) + 1e-6)
        else:
            cv_period = 0

        # Classify pattern
        if blinks == 0:
            pattern = "SOLID"
            desc = "LED is steady (always ON or always OFF)"
        elif cv_period > 0.5:
            pattern = "CHAOTIC"
            desc = f"Irregular blinking (high variability, CV={cv_period:.2f})"
        elif frequency < 1:
            pattern = "SLOW"
            desc = f"Slow blink (~{frequency:.1f} Hz)"
        elif frequency < 5:
            pattern = "MEDIUM"
            desc = f"Medium blink (~{frequency:.1f} Hz)"
        else:
            pattern = "FAST"
            desc = f"Fast blink (~{frequency:.1f} Hz)"

        result = {
            "pattern": pattern,
            "description": desc,
            "frequency_hz": round(frequency, 2),
            "transitions": int(transitions),
            "blinks": int(blinks),
            "duration_sec": round(duration, 2),
            "variability_cv": round(cv_period, 3),
            "mean_brightness": round(float(np.mean(brightness)), 2),
            "std_brightness": round(float(np.std(brightness)), 2)
        }

        print(f"   Pattern: {pattern}")
        print(f"   {desc}")
        print(f"   Frequency: {frequency:.2f} Hz")
        print(f"   Variability CV: {cv_period:.3f}")

        return result

    def analyze(self):
        """Run full analysis"""
        print(f"🎬 Analyzing: {self.video_path.name}")
        print(f"   FPS: {self.fps}, Frames: {self.frame_count}")
        print(f"   Duration: {self.frame_count/self.fps:.1f}s")
        print()

        brightness, timestamps = self.analyze_brightness()
        result = self.classify_pattern(brightness, timestamps)

        # Add metadata
        result["video_file"] = str(self.video_path)
        result["timestamp"] = datetime.now().isoformat()
        result["fps"] = self.fps
        result["total_frames"] = self.frame_count

        self.cap.release()
        return result

    def save_result(self, result, output_path=None):
        """Save analysis result"""
        if output_path is None:
            output_path = self.video_path.with_suffix('.json')

        with open(output_path, 'w') as f:
            json.dump(result, f, indent=2)

        print(f"💾 Saved: {output_path}")
        return output_path


def main():
    if len(sys.argv) < 2:
        print("Usage: led_pattern_analyzer.py <video.mp4> [output.json]")
        print()
        print("Example:")
        print("  python3 led_pattern_analyzer.py test_video.mp4")
        print("  python3 led_pattern_analyzer.py test_video.mp4 result.json")
        sys.exit(1)

    video_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None

    analyzer = LEDPatternAnalyzer(video_path)
    result = analyzer.analyze()
    analyzer.save_result(result, output_path)

    print()
    print("=" * 50)
    print("RESULT:", result["pattern"])
    print("=" * 50)


if __name__ == "__main__":
    main()
