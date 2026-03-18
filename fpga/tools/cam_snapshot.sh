#!/bin/bash
# cam_snapshot.sh — Capture a focused frame from iPhone Continuity Camera
# Records 3 seconds of video to allow autofocus, then extracts the last frame.
#
# Usage: ./cam_snapshot.sh [output.jpg] [device_id] [duration]
#
# Devices (run: ffmpeg -f avfoundation -list_devices true -i "" 2>&1):
#   0 = FaceTime HD Camera (MacBook)
#   2 = neuro_coder Camera (iPhone main)
#   3 = neuro_coder Desk View Camera (iPhone top-down)
#
# Examples:
#   ./cam_snapshot.sh                              # iPhone → /tmp/fpga_snapshot.jpg
#   ./cam_snapshot.sh /tmp/photo.jpg 3             # Desk View camera
#   ./cam_snapshot.sh /tmp/photo.jpg 2 5           # 5 sec recording for better focus

OUTPUT="${1:-/tmp/fpga_snapshot.jpg}"
DEVICE="${2:-2}"
DURATION="${3:-3}"
TMPVIDEO="/tmp/_cam_snapshot_tmp.mp4"

echo "Capturing from device [$DEVICE] (${DURATION}s for autofocus)..."
ffmpeg -f avfoundation -framerate 30 -video_size 1920x1080 \
    -i "${DEVICE}:none" -t "$DURATION" -y "$TMPVIDEO" 2>/dev/null

if [ ! -f "$TMPVIDEO" ]; then
    echo "FAIL: video capture failed"
    exit 1
fi

ffmpeg -sseof -0.1 -i "$TMPVIDEO" -frames:v 1 -update 1 -q:v 1 \
    -y "$OUTPUT" 2>/dev/null
rm -f "$TMPVIDEO"

if [ -f "$OUTPUT" ]; then
    SIZE=$(ls -lh "$OUTPUT" | awk '{print $5}')
    echo "OK: $OUTPUT ($SIZE)"
else
    echo "FAIL: frame extraction failed"
    exit 1
fi
