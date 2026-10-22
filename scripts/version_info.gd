extends RefCounted
class_name VersionInfo

const MAJOR := 0
const MINOR := 1
const PATCH := 4
const PHASE_CODE := 1
const PHASE_SUFFIX := "prealpha"
const BUILD_NUMBER := 1104
const UPDATE_NAME := "CAMERA & HUMAN OVERHAUL"

static func semantic() -> String:
	return "%d.%d.%d" % [MAJOR, MINOR, PATCH]

static func phase_label() -> String:
	return PHASE_SUFFIX

static func display() -> String:
	return "%s-%s @ %s" % [semantic(), phase_label(), format_build(BUILD_NUMBER)]

static func display_with_name() -> String:
	return "%s  |  %s" % [display(), UPDATE_NAME]

static func release_tag() -> String:
	return "v%s-%s" % [semantic(), phase_label()]

static func file_version() -> String:
	return "%d.%d.%d.%d" % [MAJOR, MINOR, PATCH, BUILD_NUMBER]

static func format_build(build_number: int) -> String:
	var raw := str(build_number)
	var groups: Array[String] = []
	while raw.length() > 3:
		groups.insert(0, raw.substr(raw.length() - 3, 3))
		raw = raw.substr(0, raw.length() - 3)
	groups.insert(0, raw)
	return ".".join(PackedStringArray(groups))

static func numeric_core(version_text: String) -> String:
	var cleaned := version_text.trim_prefix("v")
	if "-" in cleaned:
		cleaned = cleaned.get_slice("-", 0)
	return cleaned

static func is_newer(remote: String, current: String = semantic()) -> bool:
	var new_bits = numeric_core(remote).split(".")
	var old_bits = numeric_core(current).split(".")
	for i in range(3):
		var x = int(new_bits[i]) if i < new_bits.size() else 0
		var y = int(old_bits[i]) if i < old_bits.size() else 0
		if x > y:
			return true
		if x < y:
			return false
	return false
