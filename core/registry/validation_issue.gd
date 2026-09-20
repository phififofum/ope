class_name ValidationIssue
extends RefCounted

## One thing wrong with one definition, named precisely enough to fix without reading
## engine source: the file, the JSON path inside it, and the constraint it violated.
##
## This is a gameplay-facing class, not a debug convenience. Most people who ever see
## these messages will be modders with a text editor and no debugger.

enum Severity { WARNING, ERROR }

var file_path: String
var json_path: String
var constraint: String
var message: String
var severity: Severity


static func error(
	p_file: String, p_path: String, p_constraint: String, p_message: String
) -> ValidationIssue:
	return _make(p_file, p_path, p_constraint, p_message, Severity.ERROR)


static func warning(
	p_file: String, p_path: String, p_constraint: String, p_message: String
) -> ValidationIssue:
	return _make(p_file, p_path, p_constraint, p_message, Severity.WARNING)


static func _make(
	p_file: String, p_path: String, p_constraint: String, p_message: String, p_severity: Severity
) -> ValidationIssue:
	var issue := ValidationIssue.new()
	issue.file_path = p_file
	issue.json_path = p_path
	issue.constraint = p_constraint
	issue.message = p_message
	issue.severity = p_severity
	return issue


func is_error() -> bool:
	return severity == Severity.ERROR


func to_text() -> String:
	var label: String = "ERROR" if is_error() else "warning"
	return "%s  %s  %s  [%s] %s" % [label, file_path, json_path, constraint, message]
