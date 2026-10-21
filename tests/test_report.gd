class_name TestReport
extends RefCounted
## Collects test results and turns them into a readable text report.

var lines: PackedStringArray = []
var passed: int = 0
var failed: int = 0


## Record one pass/fail check with a short explanation of what was seen.
func check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	var line: String = "%s  %s" % ["PASS" if ok else "FAIL", test_name]
	if not detail.is_empty():
		line += "  (%s)" % detail
	add_line(line)


## Record a line that is information only (not a pass or fail).
func add_line(text: String) -> void:
	lines.append(text)
	print(text)


func heading(text: String) -> void:
	add_line("")
	add_line("== %s ==" % text)


func summary() -> String:
	return "%d passed, %d failed" % [passed, failed]


func full_text() -> String:
	return "\n".join(lines) + "\n\n" + summary() + "\n"
