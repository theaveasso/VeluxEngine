package main

import "core:log"

import "vlx:velux"

MARKER_FIRST :: 251

Marker_Kind :: enum {
	Light,
	Spawn,
	Trigger,
	Sound,
}

@(require_results)
marker_kind :: proc(marker: velux.Marker) -> (kind: Marker_Kind, ok: bool) {
	switch marker.palette_index {
	case MARKER_FIRST:
		return .Light, true
	case MARKER_FIRST + 1:
		return .Spawn, true
	case MARKER_FIRST + 2:
		return .Trigger, true
	case MARKER_FIRST + 3:
		return .Sound, true
	}
	return {}, false
}

report_markers :: proc(markers: []velux.Marker) {
	counts: [Marker_Kind]int
	for marker in markers {
		kind, is_known := marker_kind(marker)
		if !is_known {
			log.warnf(
				"unknown reserved palette index %v at vox %v",
				marker.palette_index,
				velux.marker_vox_position(marker),
			)
			continue
		}
		counts[kind] += 1
	}
	log.infof("markers %v of %v", counts, len(markers))
}
