class_name UsbPhoneLink
extends Node
## Connects an Android phone to the game through a USB cable, so the phone
## can drive without Wi-Fi (and without Windows Firewall, which needs admin
## rights to allow the game onto the network).
##
## It uses adb, from Google's Android "platform-tools" (unzip it next to the
## game, e.g. Documents/platform-tools). Every few seconds it asks adb whether
## a phone is plugged in; if so, it runs "adb reverse" for both of the
## ControllerServer's ports. The phone then opens http://localhost:8080 and
## reaches the game through the cable. Re-plugging the phone is handled too.
## The phone needs USB debugging switched on (see README).
##
## adb runs on a background thread, so a slow adb never makes the game stutter.

## Group the link joins, so the HUD can find it.
const GROUP: StringName = &"usb_phone_link"

## What the link found last time it checked.
enum Status { CHECKING, ADB_NOT_FOUND, NO_PHONE, NEEDS_ALLOW, READY, FAILED }

## Test runs switch this off so the game's own link never runs adb during tests.
static var enabled_in_scenes: bool = true

## The server whose ports to pass through the cable.
@export var server: ControllerServer

## Where adb.exe is. Empty = look in the usual places (see _find_adb()).
@export_global_file("*.exe") var adb_path: String = ""

## How often to check for a phone, in seconds.
@export var check_every_seconds: float = 3.0

var status: Status = Status.CHECKING
## Extra information for the status (the phone's id, or adb's error message).
var status_detail: String = ""

## Runs adb: (adb_path: String, arguments: PackedStringArray) -> {"exit": int, "output": String}.
## Tests replace it with a pretend adb.
var run_adb: Callable

var _thread: Thread
var _seconds_since_check: float = INF


func _init() -> void:
	run_adb = _run_adb_for_real


func _ready() -> void:
	add_to_group(GROUP)


func _process(delta: float) -> void:
	if not enabled_in_scenes or server == null:
		return
	_seconds_since_check += delta
	if _seconds_since_check < check_every_seconds:
		return
	if _thread != null and _thread.is_alive():
		return
	if _thread != null:
		_thread.wait_to_finish()
	_seconds_since_check = 0.0
	var adb: String = _find_adb()
	var ports: Array[int] = [server.http_port, server.websocket_port]
	_thread = Thread.new()
	_thread.start(func() -> void: _apply_result.call_deferred(check_once(adb, ports)))


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()


## One full check: is adb there, is a phone plugged in and allowed, and if so
## pass the ports through the cable. Returns {"status": Status, "detail": String}.
## Safe to run on a background thread (it only calls run_adb).
func check_once(adb: String, ports: Array[int]) -> Dictionary:
	if adb.is_empty():
		return {"status": Status.ADB_NOT_FOUND, "detail": ""}
	var devices: Dictionary = run_adb.call(adb, PackedStringArray(["devices"]))
	if devices.exit != 0:
		return {"status": Status.FAILED, "detail": str(devices.output).strip_edges()}
	var ready: Array[String] = []
	var needs_allow: bool = false
	for line: String in str(devices.output).split("\n"):
		# Lines look like "R58M12ABC\tdevice"; skip the header and adb's own notes.
		var parts: PackedStringArray = line.strip_edges().split("\t")
		if parts.size() != 2:
			continue
		if parts[1] == "device":
			ready.append(parts[0])
		elif parts[1] == "unauthorized":
			needs_allow = true
	if ready.is_empty():
		return {"status": Status.NEEDS_ALLOW if needs_allow else Status.NO_PHONE, "detail": ""}
	var phone: String = ready[0]
	for port: int in ports:
		var spec: String = "tcp:%d" % port
		var result: Dictionary = run_adb.call(adb, PackedStringArray(["-s", phone, "reverse", spec, spec]))
		if result.exit != 0:
			return {"status": Status.FAILED, "detail": str(result.output).strip_edges()}
	return {"status": Status.READY, "detail": phone}


## A line for the screen describing the USB phone link.
func describe() -> String:
	var url: String = server.usb_url() if server != null else "http://localhost:8080"
	match status:
		Status.CHECKING:
			return "USB phone: checking..."
		Status.ADB_NOT_FOUND:
			return "USB phone: adb not found (unzip Android platform-tools into Documents, see README)"
		Status.NO_PHONE:
			return "USB phone: plug in an Android phone with USB debugging on"
		Status.NEEDS_ALLOW:
			return "USB phone: tap \"Allow\" on the phone (Allow USB debugging?)"
		Status.READY:
			return "USB phone: ready - open %s on the phone" % url
	return "USB phone: adb problem: %s" % status_detail


func _apply_result(result: Dictionary) -> void:
	status = result.status
	status_detail = result.detail


## Looks for adb.exe: the adb_path setting, then platform-tools in Documents,
## next to the project folder, or in the Android SDK.
func _find_adb() -> String:
	var candidates: Array[String] = [adb_path]
	var home: String = OS.get_environment("USERPROFILE")
	if not home.is_empty():
		candidates.append(home.path_join("Documents/platform-tools/adb.exe"))
	candidates.append(ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir().path_join("platform-tools/adb.exe"))
	var local_app_data: String = OS.get_environment("LOCALAPPDATA")
	if not local_app_data.is_empty():
		candidates.append(local_app_data.path_join("Android/Sdk/platform-tools/adb.exe"))
	for candidate: String in candidates:
		if not candidate.is_empty() and FileAccess.file_exists(candidate):
			return candidate
	return ""


func _run_adb_for_real(adb: String, arguments: PackedStringArray) -> Dictionary:
	var output: Array = []
	var exit_code: int = OS.execute(adb, arguments, output, true)
	return {"exit": exit_code, "output": "\n".join(PackedStringArray(output))}
