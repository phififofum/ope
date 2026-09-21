class_name Semver
extends RefCounted

## Semantic versions and the range expressions a mod manifest uses.
##
## Supported: ">=1.2.0", "<2.0.0", "=1.0.0", "^1.2.0", "~1.2.0", "*", and any
## space-separated conjunction of those (">=1.0.0 <2.0.0"). Pre-release tags parse and
## compare lower than the release, which is the usual reading of "0.4.0-beta".

var major: int = 0
var minor: int = 0
var patch: int = 0
var prerelease: String = ""
var valid: bool = false


static func parse(text: String) -> Semver:
	var version := Semver.new()
	var body: String = text.strip_edges()
	var dash: int = body.find("-")
	if dash >= 0:
		version.prerelease = body.substr(dash + 1)
		body = body.substr(0, dash)
	var parts: PackedStringArray = body.split(".")
	if parts.size() < 1 or parts.size() > 3:
		return version
	for part: String in parts:
		if not part.is_valid_int():
			return version
	version.major = int(parts[0])
	version.minor = int(parts[1]) if parts.size() > 1 else 0
	version.patch = int(parts[2]) if parts.size() > 2 else 0
	version.valid = true
	return version


func to_text() -> String:
	var base: String = "%d.%d.%d" % [major, minor, patch]
	return base if prerelease.is_empty() else "%s-%s" % [base, prerelease]


## -1, 0 or 1. A pre-release sorts below the same version without one.
func compare(other: Semver) -> int:
	for pair: Array in [[major, other.major], [minor, other.minor], [patch, other.patch]]:
		if pair[0] != pair[1]:
			return -1 if pair[0] < pair[1] else 1
	if prerelease == other.prerelease:
		return 0
	if prerelease.is_empty():
		return 1
	if other.prerelease.is_empty():
		return -1
	return -1 if prerelease < other.prerelease else 1


## Does this version satisfy [param range_text]? An unparseable range is reported as
## unsatisfied rather than as "anything goes" — a typo must not silently widen a bound.
static func satisfies(version_text: String, range_text: String) -> bool:
	var version: Semver = Semver.parse(version_text)
	if not version.valid:
		return false
	var spec: String = range_text.strip_edges()
	if spec.is_empty() or spec == "*":
		return true
	for clause: String in spec.split(" ", false):
		if not _satisfies_clause(version, clause.strip_edges()):
			return false
	return true


static func _satisfies_clause(version: Semver, clause: String) -> bool:
	if clause.is_empty():
		return true
	var operator: String = ""
	var body: String = clause
	for candidate: String in [">=", "<=", ">", "<", "=", "^", "~"]:
		if clause.begins_with(candidate):
			operator = candidate
			body = clause.substr(candidate.length())
			break
	var bound: Semver = Semver.parse(body)
	if not bound.valid:
		return false
	var comparison: int = version.compare(bound)
	match operator:
		">=":
			return comparison >= 0
		"<=":
			return comparison <= 0
		">":
			return comparison > 0
		"<":
			return comparison < 0
		"^":
			# Compatible within the same major, or the same minor while major is 0,
			# where the usual convention is that anything may still break.
			if comparison < 0:
				return false
			if bound.major > 0:
				return version.major == bound.major
			return version.major == 0 and version.minor == bound.minor
		"~":
			return comparison >= 0 and version.major == bound.major and version.minor == bound.minor
		_:
			return comparison == 0
