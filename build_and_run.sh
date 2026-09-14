#!/bin/bash
# ASTHRA - Build and Run Script

cd "$(dirname "$0")"
exec ./run_asthra.sh --build "$@"
