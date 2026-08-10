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

BOX3D_DIR="$ROOT/third_party/box3d"
BOX3D_LIB="$ROOT/third_party/box3d-odin/external/box3d_${OS}_${ARCH}.a"
if [ -f "$BOX3D_LIB" ]; then
	echo "==> box3d already built ($(basename "$BOX3D_LIB"))"
else
	need cmake "https://cmake.org"
	echo "==> building box3d -> $(basename "$BOX3D_LIB")"
	cmake -S "$BOX3D_DIR" -B "$BOX3D_DIR/build" \
		-DBOX3D_SAMPLES=OFF -DBOX3D_UNIT_TESTS=OFF -DBOX3D_BENCHMARKS=OFF \
		-DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release
	cmake --build "$BOX3D_DIR/build" --config Release
	mkdir -p "$(dirname "$BOX3D_LIB")"
	cp "$BOX3D_DIR/build/src/libbox3d.a" "$BOX3D_LIB"
fi

echo
echo "setup complete."
echo "  build a sample:  ./build.sh 05_voxel_raycast"
