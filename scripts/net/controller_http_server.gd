class_name ControllerHttpServer
extends RefCounted
## A tiny web server that does one job: when a phone's browser asks for "/",
## it sends back the controller page. Anything else gets "404 not found".
## Call poll() every frame.

## How long a browser connection may stay open, in seconds.
const CONNECTION_TIMEOUT: float = 5.0
## After answering, keep the connection a moment so the reply finishes sending.
const CLOSE_AFTER_ANSWER: float = 0.5

## The page to serve. Read fresh for every request, so edits show on reload.
var page_path: String = ""

## Filled into the page wherever it says {{WEBSOCKET_PORT}}, so the page
## always connects to the right port.
var websocket_port: int = 8081

## Filled into the page wherever it says {{TREAD_LEVELS}} (as a JSON list),
## so the phone's lever notches match the keyboard's (see TreadLevels).
var tread_levels: Array[float] = [0.25, 0.5, 1.0]

var _server := TCPServer.new()
# One entry per open browser connection:
# {"peer": StreamPeerTCP, "request": PackedByteArray, "age": float, "answered": bool}
var _clients: Array[Dictionary] = []


func start(port: int, bind_address: String) -> Error:
	return _server.listen(port, bind_address)


func stop() -> void:
	for client: Dictionary in _clients:
		(client.peer as StreamPeerTCP).disconnect_from_host()
	_clients.clear()
	_server.stop()


func is_listening() -> bool:
	return _server.is_listening()


func poll(delta: float) -> void:
	while _server.is_connection_available():
		_clients.append({"peer": _server.take_connection(), "request": PackedByteArray(), "age": 0.0, "answered": false})
	for client: Dictionary in _clients.duplicate():
		var peer: StreamPeerTCP = client.peer
		peer.poll()
		client.age += delta
		if not client.answered and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var available: int = peer.get_available_bytes()
			if available > 0:
				var result: Array = peer.get_data(available)
				if result[0] == OK:
					client.request += result[1]
			# The request is complete once its headers end with a blank line.
			if client.request.get_string_from_utf8().contains("\r\n\r\n"):
				_answer(peer, client.request.get_string_from_utf8())
				client.answered = true
				client.age = 0.0
		var finished: bool = client.answered and client.age > CLOSE_AFTER_ANSWER
		if finished or client.age > CONNECTION_TIMEOUT or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host()
			_clients.erase(client)


func _answer(peer: StreamPeerTCP, request: String) -> void:
	# First line looks like: "GET /some/path?query HTTP/1.1"
	var first_line: PackedStringArray = request.get_slice("\r\n", 0).split(" ")
	var method: String = first_line[0] if first_line.size() > 0 else ""
	var path: String = first_line[1].get_slice("?", 0) if first_line.size() > 1 else ""
	if method == "GET" and (path == "/" or path == "/index.html"):
		var page: String = FileAccess.get_file_as_string(page_path)
		if not page.is_empty():
			page = page.replace("{{WEBSOCKET_PORT}}", str(websocket_port))
			page = page.replace("{{TREAD_LEVELS}}", JSON.stringify(tread_levels))
			_send(peer, "200 OK", "text/html; charset=utf-8", page.to_utf8_buffer())
			return
		push_error("ControllerHttpServer: cannot read %s" % page_path)
		_send(peer, "500 Internal Server Error", "text/plain", "Controller page missing".to_utf8_buffer())
		return
	_send(peer, "404 Not Found", "text/plain", "Not found".to_utf8_buffer())


func _send(peer: StreamPeerTCP, status: String, content_type: String, body: PackedByteArray) -> void:
	var header: String = "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" % [
			status, content_type, body.size()]
	peer.put_data(header.to_utf8_buffer() + body)
