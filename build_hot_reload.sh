#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$ROOT/build"

# Hot reload needs ONE shared glfw: the host and the game DLL each carry their
# own copy of a statically linked glfw, and only the host's would be initialised.
if ! odin build "$ROOT/hot_reload" -debug -o:none \
	-define:GLFW_SHARED=true \
	-collection:vlx="$ROOT" \
	-collection:third_party="$ROOT/third_party" \
	-out:"$ROOT/build/velux_hot_reload"; then
	echo
	echo "If the link failed on glfw, install the shared library:"
	echo "  macOS:  brew install glfw"
	echo "  Linux:  your distro's libglfw3-dev / glfw-devel"
	exit 1
fi

echo
echo "Built build/velux_hot_reload"
echo "Run from the repo root:  ./build/velux_hot_reload game/her_body_waits"
