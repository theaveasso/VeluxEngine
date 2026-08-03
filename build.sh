#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SAMPLE="${1:-sponza}"
SAMPLE_DIR="$ROOT/samples/$SAMPLE"

if [ ! -d "$SAMPLE_DIR" ]; then
	echo "No such sample: samples/$SAMPLE"
	exit 1
fi

for shader in "$SAMPLE_DIR"/assets/*.slang; do
	[ -e "$shader" ] || continue
	if ! grep -q '\[shader(' "$shader"; then
		echo "Skipping module $(basename "$shader")"
		continue
	fi
	"$ROOT/compile_shader.sh" -in "$shader" -out "${shader%.slang}.spv"
done

odin build "$SAMPLE_DIR" -debug -o:none \
	-collection:vlx="$ROOT" \
	-collection:third_party="$ROOT/third_party" \
	-out:"$SAMPLE_DIR/$SAMPLE"

echo
echo "Built samples/$SAMPLE/$SAMPLE"
echo "Run it from its own folder so relative assets resolve:  (cd samples/$SAMPLE && ./$SAMPLE)"
