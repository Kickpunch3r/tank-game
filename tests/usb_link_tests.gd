class_name UsbLinkTests
extends RefCounted
## Checks the USB phone link's decisions with a pretend adb (no real adb or
## phone is needed): what it does for each thing adb can report.

var runner: TestRunner
var report: TestReport
# Every pretend-adb command, as text, in order.
var calls: PackedStringArray = []


func _init(test_runner: TestRunner) -> void:
	runner = test_runner
	report = runner.report


func run() -> void:
	report.heading("USB phone link (pretend adb)")
	var link := UsbPhoneLink.new()
	var ports: Array[int] = [8080, 8081]

	var result: Dictionary = link.check_once("", ports)
	report.check("No adb found -> says so", result.status == UsbPhoneLink.Status.ADB_NOT_FOUND)

	_pretend(link, "* daemon not running; starting now at tcp:5037\n* daemon started successfully\nList of devices attached\n\n")
	result = link.check_once("adb.exe", ports)
	report.check("No phone plugged in -> says so", result.status == UsbPhoneLink.Status.NO_PHONE)

	_pretend(link, "List of devices attached\nR58M12ABC\tunauthorized\n\n")
	result = link.check_once("adb.exe", ports)
	report.check("Phone not allowed yet -> asks to tap Allow on the phone",
			result.status == UsbPhoneLink.Status.NEEDS_ALLOW and not _ran_reverse())

	_pretend(link, "List of devices attached\nR58M12ABC\tdevice\r\n\n")
	result = link.check_once("adb.exe", ports)
	report.check("Phone ready -> passes both ports through the cable",
			result.status == UsbPhoneLink.Status.READY and result.detail == "R58M12ABC"
			and calls.has("-s R58M12ABC reverse tcp:8080 tcp:8080")
			and calls.has("-s R58M12ABC reverse tcp:8081 tcp:8081"), " | ".join(calls))

	_pretend(link, "List of devices attached\nOLDPHONE\tunauthorized\nNEWPHONE\tdevice\n")
	result = link.check_once("adb.exe", ports)
	report.check("Two phones, one allowed -> uses the allowed one", result.detail == "NEWPHONE")

	_pretend(link, "List of devices attached\nR58M12ABC\tdevice\n", 1, "error: more than one device")
	result = link.check_once("adb.exe", ports)
	report.check("adb reverse fails -> shows adb's message",
			result.status == UsbPhoneLink.Status.FAILED and result.detail.contains("more than one device"), result.detail)

	link.free()

	var server: ControllerServer = runner.course.get_node(^"PlayerRig/ControllerServer")
	report.check("Wi-Fi phones are off by default (this computer only, no firewall question)",
			not server.allow_wifi_phones and server.controller_urls().is_empty())
	report.check("USB phones open http://localhost:<port>", server.usb_url() == "http://localhost:%d" % server.http_port)


## Make the link use a pretend adb: "devices" prints `devices_output`; every
## other command exits with `other_exit` and prints `other_output`.
func _pretend(link: UsbPhoneLink, devices_output: String, other_exit: int = 0, other_output: String = "") -> void:
	calls.clear()
	link.run_adb = func(_adb: String, arguments: PackedStringArray) -> Dictionary:
		calls.append(" ".join(arguments))
		if arguments == PackedStringArray(["devices"]):
			return {"exit": 0, "output": devices_output}
		return {"exit": other_exit, "output": other_output}


func _ran_reverse() -> bool:
	for call: String in calls:
		if call.contains("reverse"):
			return true
	return false
