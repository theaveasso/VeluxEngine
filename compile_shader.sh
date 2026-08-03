#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IN=""
OUT=""

usage() {
	echo "Usage: compile_shader.sh -in <shader.slang> -out <shader.spv>"
	exit 1
}

while [ $# -gt 0 ]; do
	case "$1" in
		-in) IN="$2"; shift 2 ;;
		-out) OUT="$2"; shift 2 ;;
		*) echo "Unknown argument: $1"; usage ;;
	esac
done

[ -n "$IN" ] && [ -n "$OUT" ] || usage

if [ -z "${VULKAN_SDK:-}" ] && [ "$(uname -s)" = "Darwin" ]; then
	[ -x /opt/homebrew/bin/slangc ] && export VULKAN_SDK=/opt/homebrew
	[ -x /usr/local/bin/slangc ] && export VULKAN_SDK=/usr/local
fi

SLANGC="slangc"
if [ -n "${VULKAN_SDK:-}" ] && [ -x "$VULKAN_SDK/bin/slangc" ]; then
	SLANGC="$VULKAN_SDK/bin/slangc"
fi

command -v "$SLANGC" >/dev/null 2>&1 || {
	echo "error: slangc not found. Install the Vulkan SDK, or 'brew install shader-slang' on macOS."
	exit 1
}

mkdir -p "$(dirname "$OUT")"

"$SLANGC" "$IN" \
	-I "$(dirname "$IN")" \
	-I "$ROOT/velux/shaders" \
	-target spirv \
	-fvk-use-entrypoint-name \
	-o "$OUT"

echo "Compiled $IN -> $OUT"
