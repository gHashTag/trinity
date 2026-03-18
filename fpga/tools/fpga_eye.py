#!/usr/bin/env python3
"""
FPGA Eye — Vision Node for Automated FPGA Verification
=======================================================
Detects LED states on QMTECH XC7A100T FPGA board using OpenCV.

Features:
  - HSV red channel filtering for precise LED detection
  - Multi-LED tracking (D1 power, D5/D6 user LEDs)
  - Blink pattern analysis (SOLID / SLOW / MEDIUM / FAST)
  - JSON output for pipeline integration
  - High-res capture (1920x1080)

Usage:
  python3 fpga_eye.py snap              # Single snapshot + LED analysis
  python3 fpga_eye.py blink [duration]  # Video blink analysis (default 5s)
  python3 fpga_eye.py watch             # Continuous monitoring (1 fps)
  python3 fpga_eye.py --help            # Show help

Output: JSON to stdout (for pipeline), human-readable to stderr
"""

import cv2
import numpy as np
import subprocess
import json
import sys
import os
import time
from pathlib import Path
from datetime import datetime

# =============================================================================
# Configuration
# =============================================================================
CAMERA_DEVICE = os.environ.get("FPGA_EYE_CAMERA", "2")
RESOLUTION = (1920, 1080)
AUTOFOCUS_DELAY = 3  # seconds for camera to autofocus
SNAP_DIR = Path("/tmp/fpga_eye")

# HSV ranges for red LED detection (red wraps around H=0/180)
# Strict: high saturation + value to filter out reflections/wood/SMD
RED_LOW1 = np.array([0, 150, 150])
RED_HIGH1 = np.array([10, 255, 255])
RED_LOW2 = np.array([165, 150, 150])
RED_HIGH2 = np.array([180, 255, 255])

# LED detection parameters
MIN_LED_AREA = 200       # minimum contour area (pixels) — real LEDs are 300-1000+
MAX_LED_AREA = 5000      # maximum contour area (pixels)
MIN_CIRCULARITY = 0.15   # LEDs are roughly circular (but can be smeared by glow)
MIN_PEAK_BRIGHTNESS = 220  # minimum peak red channel value for a real LED
MIN_MEAN_BRIGHTNESS = 150  # minimum mean brightness in ROI for a real LED

# ROI (Region of Interest) — restrict detection to core board area only
# The QMTECH board LEDs are in a vertical column at ~25-40% of frame width
# Right side has daughter board connectors that cause reflections.
# Values are fractions of frame dimensions: (x_start, y_start, x_end, y_end)
ROI_FRACTION = (0.0, 0.3, 0.45, 1.0)  # left 45%, bottom 70%

# Clustering: merge nearby detections (same LED fragmented)
LED_MERGE_DISTANCE = 80  # pixels — merge detections closer than this

# =============================================================================
# Capture
# =============================================================================

def capture_snapshot(camera=CAMERA_DEVICE, duration=AUTOFOCUS_DELAY):
    """Capture a snapshot via ffmpeg. Records video for autofocus, takes last frame."""
    SNAP_DIR.mkdir(parents=True, exist_ok=True)
    video_path = SNAP_DIR / "capture.mp4"
    snap_path = SNAP_DIR / "snapshot.jpg"

    log("Capturing %ds video for autofocus (camera %s, %dx%d)..." % (
        duration, camera, RESOLUTION[0], RESOLUTION[1]))

    # Step 1: Record video (camera autofocuses during this)
    cmd = [
        "ffmpeg", "-f", "avfoundation",
        "-framerate", "30",
        "-video_size", "%dx%d" % RESOLUTION,
        "-i", "%s:none" % camera,
        "-t", str(duration),
        "-y", str(video_path)
    ]
    subprocess.run(cmd, capture_output=True, timeout=duration + 10)

    # Step 2: Extract last frame (best focus)
    cmd2 = [
        "ffmpeg", "-sseof", "-0.3",
        "-i", str(video_path),
        "-frames:v", "1",
        "-update", "1",
        "-y", str(snap_path)
    ]
    subprocess.run(cmd2, capture_output=True, timeout=10)

    if not snap_path.exists():
        raise RuntimeError("Failed to capture snapshot")

    frame = cv2.imread(str(snap_path))
    if frame is None:
        raise RuntimeError("Failed to read snapshot image")

    log("Captured: %dx%d" % (frame.shape[1], frame.shape[0]))
    return frame, snap_path


def capture_video(camera=CAMERA_DEVICE, duration=5):
    """Capture video for blink analysis."""
    SNAP_DIR.mkdir(parents=True, exist_ok=True)
    video_path = SNAP_DIR / "blink_video.mp4"

    log("Recording %ds video for blink analysis..." % duration)

    cmd = [
        "ffmpeg", "-f", "avfoundation",
        "-framerate", "30",
        "-video_size", "%dx%d" % RESOLUTION,
        "-i", "%s:none" % camera,
        "-t", str(duration),
        "-y", str(video_path)
    ]
    subprocess.run(cmd, capture_output=True, timeout=duration + 10)

    if not video_path.exists():
        raise RuntimeError("Failed to capture video")

    return video_path


# =============================================================================
# LED Detection (HSV-based)
# =============================================================================

def detect_leds(frame, apply_roi=True):
    """Detect red LEDs in a frame using HSV color filtering.

    Returns list of dicts with position, area, brightness, bbox.
    Uses ROI restriction to filter out reflections from daughter board connectors.
    """
    h_frame, w_frame = frame.shape[:2]

    # Apply ROI restriction (only analyze the core board area)
    if apply_roi:
        x0 = int(w_frame * ROI_FRACTION[0])
        y0 = int(h_frame * ROI_FRACTION[1])
        x1 = int(w_frame * ROI_FRACTION[2])
        y1 = int(h_frame * ROI_FRACTION[3])
        roi_frame = frame[y0:y1, x0:x1]
        roi_offset = (x0, y0)
    else:
        roi_frame = frame
        roi_offset = (0, 0)

    hsv = cv2.cvtColor(roi_frame, cv2.COLOR_BGR2HSV)

    # Red wraps around H=0/180 in OpenCV HSV
    mask1 = cv2.inRange(hsv, RED_LOW1, RED_HIGH1)
    mask2 = cv2.inRange(hsv, RED_LOW2, RED_HIGH2)
    red_mask = mask1 | mask2

    # Morphological cleanup — stronger dilation to merge nearby fragments
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    red_mask = cv2.morphologyEx(red_mask, cv2.MORPH_CLOSE, kernel)
    red_mask = cv2.morphologyEx(red_mask, cv2.MORPH_OPEN, kernel)

    # Find contours
    contours, _ = cv2.findContours(red_mask, cv2.RETR_EXTERNAL,
                                    cv2.CHAIN_APPROX_SIMPLE)

    candidates = []
    for c in contours:
        area = cv2.contourArea(c)
        if area < MIN_LED_AREA or area > MAX_LED_AREA:
            continue

        # Circularity check
        perimeter = cv2.arcLength(c, True)
        if perimeter == 0:
            continue
        circularity = 4 * np.pi * area / (perimeter * perimeter)
        if circularity < MIN_CIRCULARITY:
            continue

        # Centroid (in ROI coords)
        M = cv2.moments(c)
        if M['m00'] == 0:
            continue
        cx_roi = int(M['m10'] / M['m00'])
        cy_roi = int(M['m01'] / M['m00'])

        # Convert to full frame coords
        cx = cx_roi + roi_offset[0]
        cy = cy_roi + roi_offset[1]

        # Brightness in bounding box (use ROI frame)
        x, y, w, h = cv2.boundingRect(c)
        roi = roi_frame[y:y+h, x:x+w]
        brightness = float(np.mean(roi[:, :, 2]))  # Red channel mean
        peak = float(np.max(roi[:, :, 2]))          # Red channel peak

        # Filter: real LEDs have high peak AND mean brightness
        if peak < MIN_PEAK_BRIGHTNESS:
            continue
        if brightness < MIN_MEAN_BRIGHTNESS:
            continue

        # Adjust bbox to full frame coords
        bbox_x = x + roi_offset[0]
        bbox_y = y + roi_offset[1]

        candidates.append({
            'position': [cx, cy],
            'area': int(area),
            'brightness': round(brightness, 1),
            'peak': round(peak, 1),
            'circularity': round(circularity, 3),
            'bbox': [bbox_x, bbox_y, w, h]
        })

    # Cluster nearby detections (merge fragments of same LED)
    leds = _merge_nearby_leds(candidates, LED_MERGE_DISTANCE)

    # Sort by Y position (top to bottom)
    leds.sort(key=lambda l: l['position'][1])
    return leds


def _merge_nearby_leds(candidates, merge_dist):
    """Merge LED candidates that are within merge_dist pixels of each other.

    Keeps the brightest candidate from each cluster.
    """
    if not candidates:
        return []

    used = [False] * len(candidates)
    merged = []

    for i in range(len(candidates)):
        if used[i]:
            continue

        cluster = [candidates[i]]
        used[i] = True

        # Find all candidates close to this one
        for j in range(i + 1, len(candidates)):
            if used[j]:
                continue
            dx = candidates[i]['position'][0] - candidates[j]['position'][0]
            dy = candidates[i]['position'][1] - candidates[j]['position'][1]
            dist = (dx * dx + dy * dy) ** 0.5
            if dist < merge_dist:
                cluster.append(candidates[j])
                used[j] = True

        # Keep the brightest in the cluster
        best = max(cluster, key=lambda c: c['peak'])
        # Sum areas (LED might be fragmented)
        total_area = sum(c['area'] for c in cluster)
        best['area'] = total_area
        merged.append(best)

    return merged


def label_leds(leds):
    """Assign LED names (D1, D5, D6) based on position.

    QMTECH board: LEDs are vertically arranged near bottom edge.
    D1 (power) is typically uppermost, D6 is lower.
    """
    names = ["D1", "D5", "D6"]  # top to bottom order
    for i, led in enumerate(leds):
        if i < len(names):
            led['id'] = names[i]
        else:
            led['id'] = "LED%d" % (i + 1)

    return leds


# =============================================================================
# Blink Analysis
# =============================================================================

def analyze_blink(video_path, expected_leds=3):
    """Analyze LED blink patterns from video.

    Returns dict with per-LED analysis.
    """
    cap = cv2.VideoCapture(str(video_path))
    fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = total_frames / fps if fps > 0 else 0

    log("Analyzing video: %.1fs, %d frames @ %.0f fps" % (duration, total_frames, fps))

    # Track LED brightness per frame
    # Use position-based matching across frames
    all_led_data = []  # list of (frame_idx, leds_list)

    frame_idx = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break

        leds = detect_leds(frame)
        all_led_data.append((frame_idx, leds))

        frame_idx += 1
        if frame_idx % 30 == 0:
            log("  Processed %d/%d frames" % (frame_idx, total_frames))

    cap.release()

    if not all_led_data:
        return {"error": "No frames processed"}

    # Find stable LED positions (most common LED count)
    led_counts = [len(ld) for _, ld in all_led_data]
    if not led_counts:
        return {"error": "No LEDs detected"}

    # Use the most common LED count as reference
    from collections import Counter
    typical_count = Counter(led_counts).most_common(1)[0][0]
    log("  Typical LED count: %d" % typical_count)

    # Build brightness timelines for each LED slot
    timelines = {i: [] for i in range(typical_count)}

    for fidx, leds in all_led_data:
        # If frame has the expected number of LEDs, track them
        if len(leds) == typical_count:
            for i, led in enumerate(leds):
                timelines[i].append(led['brightness'])
        elif len(leds) > 0:
            # Partial detection - try to match by position
            for i in range(min(len(leds), typical_count)):
                timelines[i].append(leds[i]['brightness'])

    # Analyze each LED timeline
    results = {}
    led_names = ["D1", "D5", "D6"]

    for slot_id, timeline in timelines.items():
        if len(timeline) < 10:
            continue

        arr = np.array(timeline)
        name = led_names[slot_id] if slot_id < len(led_names) else "LED%d" % slot_id

        # Adaptive threshold: midpoint between min and max
        threshold = (np.max(arr) + np.min(arr)) / 2.0

        # Dynamic range check
        # Camera auto-exposure + sensor noise can cause ±20-40 variation
        # even on a solid LED. Real blinking has dynamic_range > 80.
        dynamic_range = np.max(arr) - np.min(arr)
        if dynamic_range < 60:
            # Small variation = SOLID (camera noise, not real blinking)
            pattern = "SOLID"
            transitions = 0
            freq = 0.0
        else:
            binary = arr > threshold
            diffs = np.diff(binary.astype(int))
            transitions = int(np.sum(diffs != 0))
            blinks = transitions // 2
            freq = blinks / duration if duration > 0 else 0.0

            if transitions <= 1:
                pattern = "SOLID"
            elif freq < 1.0:
                pattern = "SLOW"
            elif freq < 5.0:
                pattern = "MEDIUM"
            else:
                pattern = "FAST"

        # Determine if LED is ON or OFF (for SOLID pattern)
        state = "on" if np.mean(arr) > 100 else "off"
        if pattern != "SOLID":
            state = "blinking"

        results[name] = {
            'state': state,
            'pattern': pattern,
            'frequency_hz': round(freq, 2),
            'transitions': transitions,
            'mean_brightness': round(float(np.mean(arr)), 1),
            'min_brightness': round(float(np.min(arr)), 1),
            'max_brightness': round(float(np.max(arr)), 1),
            'dynamic_range': round(float(dynamic_range), 1),
            'frames_analyzed': len(timeline),
            'confidence': round(min(1.0, len(timeline) / total_frames), 2)
        }

    return {
        'duration_s': round(duration, 2),
        'fps': round(fps, 1),
        'total_frames': total_frames,
        'led_analysis': results
    }


# =============================================================================
# Snapshot Analysis
# =============================================================================

def analyze_snapshot(frame):
    """Analyze a single frame for LED states."""
    leds = detect_leds(frame)
    leds = label_leds(leds)

    led_results = []
    for led in leds:
        state = "on" if led['brightness'] > 100 else "off"
        led_results.append({
            'id': led['id'],
            'position': led['position'],
            'state': state,
            'brightness': led['brightness'],
            'peak': led['peak'],
            'area': led['area'],
            'confidence': round(min(1.0, led['area'] / 200.0), 2)
        })

    return led_results


# =============================================================================
# Verdict Logic
# =============================================================================

def determine_verdict(led_results, blink_data=None):
    """Determine overall FPGA test verdict based on LED states.

    QMTECH XC7A100T convention:
      - User LED solid ON = self-test PASS
      - User LED OFF = self-test FAIL
      - User LED blinking = computation in progress

    The user LED is the bottom-most detected LED (D6 if 3 LEDs, D5 if 2).
    """
    verdict = "UNKNOWN"
    details = ""

    # Find the user LED (bottom-most = last in sorted list)
    user_led = None
    user_led_name = "user_led"

    if blink_data and 'led_analysis' in blink_data:
        analysis = blink_data['led_analysis']
        # Try D6 first, then fall back to last LED
        if 'D6' in analysis:
            user_led = analysis['D6']
            user_led_name = "D6"
        elif analysis:
            # Use the last LED (bottom-most on board)
            last_key = list(analysis.keys())[-1]
            user_led = analysis[last_key]
            user_led_name = last_key
    else:
        for led in (led_results or []):
            if led.get('id') == 'D6':
                user_led = led
                user_led_name = "D6"
                break
        if user_led is None and led_results and len(led_results) > 0:
            # Use the last LED (bottom-most = most likely user LED)
            user_led = led_results[-1]
            user_led_name = user_led.get('id', 'last_led')

    if user_led is None:
        verdict = "NO_LED_DETECTED"
        details = "No LED detected on board"
    elif user_led.get('state') == 'on' or user_led.get('pattern') == 'SOLID':
        if user_led.get('brightness', 0) > 100 or user_led.get('mean_brightness', 0) > 100:
            verdict = "SELF_TEST_PASS"
            details = "%s solid ON = self-test passed" % user_led_name
        else:
            verdict = "SELF_TEST_FAIL"
            details = "%s solid OFF = self-test failed" % user_led_name
    elif user_led.get('state') == 'blinking':
        verdict = "COMPUTING"
        details = "%s blinking @ %.1f Hz = computation in progress" % (
            user_led_name, user_led.get('frequency_hz', 0))
    elif user_led.get('state') == 'off':
        verdict = "SELF_TEST_FAIL"
        details = "%s OFF = self-test failed" % user_led_name

    return verdict, details


# =============================================================================
# Output
# =============================================================================

def build_result(leds=None, blink_data=None, snap_path=None):
    """Build complete JSON result."""
    verdict, details = determine_verdict(leds, blink_data)

    result = {
        'timestamp': datetime.now().isoformat(),
        'camera': 'neuro_coder (device %s)' % CAMERA_DEVICE,
        'resolution': '%dx%d' % RESOLUTION,
        'verdict': verdict,
        'verdict_details': details,
    }

    if leds:
        result['leds'] = leds

    if blink_data:
        result['blink_analysis'] = blink_data

    if snap_path:
        result['snapshot_path'] = str(snap_path)

    return result


def log(msg):
    """Print to stderr (human-readable output)."""
    print(msg, file=sys.stderr)


# =============================================================================
# Commands
# =============================================================================

def cmd_snap():
    """Snapshot + LED analysis."""
    frame, snap_path = capture_snapshot()
    leds = analyze_snapshot(frame)

    # Save annotated image
    annotated = frame.copy()
    for led in leds:
        x, y = led['position']
        color = (0, 255, 0) if led['state'] == 'on' else (0, 0, 255)
        cv2.circle(annotated, (x, y), 20, color, 2)
        cv2.putText(annotated, "%s: %s" % (led['id'], led['state']),
                    (x + 25, y + 5), cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)

    annotated_path = SNAP_DIR / "annotated.jpg"
    cv2.imwrite(str(annotated_path), annotated)
    log("Annotated image: %s" % annotated_path)

    result = build_result(leds=leds, snap_path=snap_path)

    log("")
    log("=" * 50)
    log("  FPGA Eye: %d LED(s) detected" % len(leds))
    for led in leds:
        log("  %s: %s (brightness=%.0f)" % (led['id'], led['state'], led['brightness']))
    log("  Verdict: %s" % result['verdict'])
    log("=" * 50)

    return result


def cmd_blink(duration=5):
    """Video blink analysis."""
    video_path = capture_video(duration=duration)
    blink_data = analyze_blink(video_path)
    result = build_result(blink_data=blink_data)

    log("")
    log("=" * 50)
    log("  FPGA Eye — Blink Analysis (%.1fs)" % duration)
    if 'led_analysis' in blink_data:
        for name, data in blink_data['led_analysis'].items():
            log("  %s: %s (%s, %.1f Hz)" % (name, data['state'], data['pattern'],
                                              data['frequency_hz']))
    log("  Verdict: %s" % result['verdict'])
    log("=" * 50)

    return result


def cmd_watch():
    """Continuous monitoring (one frame per second)."""
    log("FPGA Eye — Continuous monitoring (Ctrl+C to stop)")
    log("")

    iteration = 0
    try:
        while True:
            frame, _ = capture_snapshot(duration=1)
            leds = analyze_snapshot(frame)

            timestamp = datetime.now().strftime("%H:%M:%S")
            led_str = " | ".join(
                "%s=%s(%.0f)" % (l['id'], l['state'], l['brightness'])
                for l in leds
            )
            verdict, _ = determine_verdict(leds)

            log("[%s] %s → %s" % (timestamp, led_str, verdict))

            result = build_result(leds=leds)
            # Output JSON on each iteration for pipeline consumption
            print(json.dumps(result))
            sys.stdout.flush()

            iteration += 1
            time.sleep(1)

    except KeyboardInterrupt:
        log("\nMonitoring stopped after %d iterations." % iteration)


# =============================================================================
# Main
# =============================================================================

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ('-h', '--help'):
        print(__doc__)
        sys.exit(0)

    command = sys.argv[1]

    if command == 'snap':
        result = cmd_snap()
    elif command == 'blink':
        duration = float(sys.argv[2]) if len(sys.argv) > 2 else 5.0
        result = cmd_blink(duration)
    elif command == 'watch':
        cmd_watch()
        return
    else:
        print("Unknown command: %s" % command, file=sys.stderr)
        print("Use: snap | blink | watch", file=sys.stderr)
        sys.exit(1)

    # JSON output to stdout
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
