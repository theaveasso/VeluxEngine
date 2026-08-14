#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

need() {
	command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' not found in PATH ($2)"; exit 1; }
}

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
	arm64 | aarch64) ARCH="arm64" ;;
	*) ARCH="x64" ;;
esac

if [ "$OS" = "darwin" ] && [ -z "${VULKAN_SDK:-}" ]; then
	if [ -d /opt/homebrew/include/vulkan ]; then
		export VULKAN_SDK=/opt/homebrew
	elif [ -d /usr/local/include/vulkan ]; then
		export VULKAN_SDK=/usr/local
	fi
	[ -n "${VULKAN_SDK:-}" ] && echo "==> VULKAN_SDK not set, using $VULKAN_SDK"
fi

if [ -z "${VULKAN_SDK:-}" ]; then
	echo "error: VULKAN_SDK is not set and no Vulkan headers were found."
	echo "  macOS:  brew install vulkan-headers vulkan-loader molten-vk shader-slang"
	echo "  Linux:  install your distro's vulkan-headers + vulkan-loader, or the LunarG SDK"
	exit 1
fi

need git "install git"
need odin "https://odin-lang.org"

echo "==> submodules"
git submodule update --init --recursive

VMA_DIR="$ROOT/third_party/odin-vma"
VMA_LIB="$VMA_DIR/external/vma_${OS}_${ARCH}.a"
if [ -f "$VMA_LIB" ]; then
	echo "==> VMA already built ($(basename "$VMA_LIB"))"
else
	need g++ "install Xcode command line tools, or your distro's g++"
	need ar "install binutils"
	echo "==> building VMA -> $(basename "$VMA_LIB")"
	(cd "$VMA_DIR" && ./build.sh)
fi

IMGUI_DIR="$ROOT/third_party/odin-imgui"
IMGUI_LIB="$IMGUI_DIR/imgui_${OS}_${ARCH}.a"
if [ -f "$IMGUI_LIB" ]; then
	echo "==> imgui already built ($(basename "$IMGUI_LIB"))"
else
	need python3 "install python 3"
	need clang "install Xcode command line tools, or your distro's clang"
	need ar "install binutils"
	echo "==> building imgui -> $(basename "$IMGUI_LIB")"
	echo "    first run clones dear imgui, glfw, SDL2, SDL3 and Vulkan-Headers; it takes a few minutes"
	(cd "$IMGUI_DIR" && python3 build.py)
fi

echo
echo "setup complete."
echo "  velux is a library - there is no executable to build here."
echo "  build your game repo, or clone https://github.com/theaveasso/velux-starter"
