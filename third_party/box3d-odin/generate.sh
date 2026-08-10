#!/usr/bin/env bash
set -euo pipefail

BINDGEN="${1:?usage: generate.sh /path/to/odin-c-bindgen/bindgen.exe}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rm -rf "$HERE/input" "$HERE/box3d-odin"
mkdir -p "$HERE/input"
cp "$HERE/../box3d/include/box3d/"*.h "$HERE/input/"

(cd "$HERE/.." && "$BINDGEN" box3d-odin)

sed -i '/^COMPOUND_VERSION ::/ s/\^/~/g' "$HERE/box3d-odin/types.odin"

sed -i \
	-e '/^HUGE ::/d' \
	-e '/^LINEAR_SLOP ::/d' \
	-e '/^MIN_CAPSULE_LENGTH ::/d' \
	-e '/^OVERLAP_SLOP ::/d' \
	-e '/^SPECULATIVE_DISTANCE ::/d' \
	-e '/^MESH_REST_OFFSET ::/d' \
	-e '/^CONTACT_RECYCLE_DISTANCE ::/d' \
	-e '/^MAX_AABB_MARGIN ::/d' \
	"$HERE/box3d-odin/constants.odin"

mv "$HERE/box3d-odin/"*.odin "$HERE/"
rm -rf "$HERE/input" "$HERE/box3d-odin"

echo "regenerated bindings in $HERE"
