class_name StationRegistry
extends RefCounted
## Which phone (connection id) is at which station of the tank. Each station
## holds one phone; any other phone that asks for a taken station waits as a
## spectator, and gets the station when it frees up (first come, first served).
## Today there is only "driver"; later stations (gunner, engineer) are just
## more names in STATIONS.

const STATIONS: Array[String] = ["driver"]
const SPECTATOR: String = "spectator"

# Station name -> connection id holding it (0 = free).
var _holders: Dictionary = {}
# Phones waiting for a station, in the order they asked: {"id": int, "wanted": String}.
var _waiting: Array[Dictionary] = []


func _init() -> void:
	for station: String in STATIONS:
		_holders[station] = 0


## A phone asks for a station. Returns the station it got, or "spectator".
func join(id: int, wanted: String) -> String:
	if _holders.has(wanted) and _holders[wanted] == 0:
		_holders[wanted] = id
		return wanted
	_waiting.append({"id": id, "wanted": wanted})
	return SPECTATOR


## A phone disconnected. Returns {"station": String, "new_holder": int} when a
## waiting phone took over its station, otherwise an empty dictionary.
func leave(id: int) -> Dictionary:
	for i: int in range(_waiting.size() - 1, -1, -1):
		if _waiting[i].id == id:
			_waiting.remove_at(i)
	var freed: String = station_of(id)
	if freed == SPECTATOR:
		return {}
	_holders[freed] = 0
	for i: int in _waiting.size():
		if _waiting[i].wanted == freed:
			var next_id: int = _waiting[i].id
			_waiting.remove_at(i)
			_holders[freed] = next_id
			return {"station": freed, "new_holder": next_id}
	return {}


## The station a phone holds, or "spectator".
func station_of(id: int) -> String:
	for station: String in _holders:
		if _holders[station] == id and id != 0:
			return station
	return SPECTATOR


## The phone holding a station (0 = nobody).
func holder_of(station: String) -> int:
	return _holders.get(station, 0)
