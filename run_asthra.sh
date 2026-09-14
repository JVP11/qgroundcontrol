#!/bin/bash
# ASTHRA - Run Script
# Advanced Strategic Tactical Humanitarian Response Analyser

set -e
cd "$(dirname "$0")"

APP_NAME="ASTHRA"
BIN="build/Release/${APP_NAME}"
BUILD_DIR="build"

do_build() {
    echo "=== Building ${APP_NAME} ==="
    if [ ! -f "${BUILD_DIR}/CMakeCache.txt" ]; then
        cmake -B "${BUILD_DIR}" -DQGC_APP_NAME="${APP_NAME}" -DCMAKE_BUILD_TYPE=Release
    fi
    cmake --build "${BUILD_DIR}" --config Release --parallel "$(nproc)"
}

echo "=== ${APP_NAME} ==="
echo ""

if [ "$1" = "--build" ] || [ "$1" = "-b" ]; then
    shift
    do_build
fi

if [ ! -x "$BIN" ]; then
    if [ -f "build/Release/QGroundControl" ]; then
        BIN="build/Release/QGroundControl"
        echo "Note: using QGroundControl binary (rebuild with -DQGC_APP_NAME=ASTHRA for branded build)."
    else
        echo "Binary not found. Building..."
        do_build
    fi
fi

if [ ! -x "$BIN" ]; then
    echo "Error: could not find executable at $BIN"
    exit 1
fi

pkill -f 'build/Release/ASTHRA' 2>/dev/null || true
pkill -f 'build/Release/QGroundControl' 2>/dev/null || true
sleep 0.5

echo "Launching ${APP_NAME}..."
echo "  FLY   = world map (needs network for map tiles)"
echo "  SWARM = indoor mission planner (connect drones via DUAL first)"
echo ""
exec "./$BIN" "$@"
