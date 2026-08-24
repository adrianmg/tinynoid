class_name AvatarCacheState
extends Node

signal avatar_updated(handle: String)

const AVATAR_SIZE := 8
const MAX_REMOTE_AVATARS := 20
const MAX_ATTEMPTS := 2
const RETRY_BASE_MS := 1000
const WEB_POLL_INTERVAL := 0.1
const AVATAR_URL := "https://unavatar.io/x/%s?fallback=false"
const REQUEST_TIMEOUT := 8.0
const PALETTE := [
	Color("#050611"),
	Color("#111329"),
	Color("#12345b"),
	Color("#287fc4"),
	Color("#74ddff"),
	Color("#f7f4ff"),
	Color("#ffd84a"),
	Color("#f15b68"),
	Color("#ff8a3d"),
	Color("#56d46f"),
	Color("#6d83f2"),
	Color("#c967e8"),
]

var _textures: Dictionary = {}
var _known_handles: Dictionary = {}
var _queued_handles: Dictionary = {}
var _attempts: Dictionary = {}
var _retry_at: Dictionary = {}
var _queue: Array[String] = []
var _request: HTTPRequest
var _active_handle := ""
var _web_poll_time := 0.0


func _ready() -> void:
	if not OS.has_feature("web"):
		_request = HTTPRequest.new()
		_request.accept_gzip = false
		_request.timeout = REQUEST_TIMEOUT
		_request.request_completed.connect(_on_request_completed)
		add_child(_request)
	set_process(true)


func _process(delta: float) -> void:
	_process_retries()
	if not OS.has_feature("web") or _active_handle.is_empty():
		return

	_web_poll_time += delta
	if _web_poll_time < WEB_POLL_INTERVAL:
		return
	_web_poll_time = 0.0
	_poll_web_request()


func get_avatar(handle: String) -> Texture2D:
	var normalized := PlayerProfileState.normalize_name(handle)
	if _textures.has(normalized):
		return _textures[normalized] as Texture2D
	return null


func request_avatar(handle: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var normalized := PlayerProfileState.normalize_name(handle)
	if (
		normalized.is_empty()
		or normalized == "GUEST"
		or _textures.has(normalized)
		or _known_handles.has(normalized)
		or _queued_handles.has(normalized)
		or _retry_at.has(normalized)
		or normalized == _active_handle
	):
		return
	if _known_handles.size() >= MAX_REMOTE_AVATARS:
		return
	_known_handles[normalized] = true
	_enqueue(normalized)


static func avatar_url(handle: String) -> String:
	return AVATAR_URL % PlayerProfileState.normalize_name(handle).uri_encode()


static func pixelate(image: Image) -> Image:
	var side := mini(image.get_width(), image.get_height())
	var origin := Vector2i(
		floori(float(image.get_width() - side) / 2.0),
		floori(float(image.get_height() - side) / 2.0)
	)
	var square := image.get_region(Rect2i(origin, Vector2i(side, side)))
	square.resize(
		AVATAR_SIZE,
		AVATAR_SIZE,
		Image.INTERPOLATE_LANCZOS
	)
	for y in range(AVATAR_SIZE):
		for x in range(AVATAR_SIZE):
			square.set_pixel(
				x,
				y,
				_nearest_palette_color(square.get_pixel(x, y))
			)
	return square


func _enqueue(handle: String) -> void:
	_queued_handles[handle] = true
	_queue.append(handle)
	_flush_queue()


func _flush_queue() -> void:
	if not _active_handle.is_empty() or _queue.is_empty():
		return

	_active_handle = _queue.pop_front()
	_queued_handles.erase(_active_handle)
	if OS.has_feature("web"):
		_start_web_request(_active_handle)
		return

	var error := _request.request(
		avatar_url(_active_handle),
		PackedStringArray(["Cache-Control: no-cache"])
	)
	if error != OK:
		_finish_failure(true)


func _start_web_request(handle: String) -> void:
	var script := """
(() => {
  globalThis.__tinynoidAvatarResults ||= {};
  const key = %s;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), %d);
  fetch(%s, {
    cache: "no-store",
    credentials: "omit",
    signal: controller.signal,
  })
    .then(async (response) => {
      if (!response.ok) {
        throw new Error(String(response.status));
      }
      const bytes = new Uint8Array(await response.arrayBuffer());
      let binary = "";
      for (let offset = 0; offset < bytes.length; offset += 32768) {
        binary += String.fromCharCode(...bytes.subarray(offset, offset + 32768));
      }
      globalThis.__tinynoidAvatarResults[key] = {
        ok: true,
        data: btoa(binary),
        contentType: response.headers.get("content-type") || "image/jpeg",
      };
    })
    .catch((error) => {
      const status = Number(error.message);
      globalThis.__tinynoidAvatarResults[key] = {
        ok: false,
        retryable: (
          error.name === "AbortError"
          || !Number.isFinite(status)
          || status >= 500
        ),
      };
    })
    .finally(() => clearTimeout(timeout));
})();
""" % [
		JSON.stringify(handle),
		int(REQUEST_TIMEOUT * 1000.0),
		JSON.stringify(avatar_url(handle)),
	]
	JavaScriptBridge.eval(script, true)


func _poll_web_request() -> void:
	var result_json := String(
		JavaScriptBridge.eval(
			"JSON.stringify(globalThis.__tinynoidAvatarResults?.[%s] ?? null)"
			% JSON.stringify(_active_handle),
			true
		)
	)
	if result_json == "null" or result_json.is_empty():
		return

	JavaScriptBridge.eval(
		"delete globalThis.__tinynoidAvatarResults[%s]"
		% JSON.stringify(_active_handle),
		true
	)
	var result: Variant = JSON.parse_string(result_json)
	if not result is Dictionary or not bool(result.get("ok", false)):
		_finish_failure(bool(result.get("retryable", false)))
		return

	_finish_success(
		String(result.get("contentType", "image/jpeg")),
		Marshalls.base64_to_raw(String(result.get("data", "")))
	)


func _on_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_finish_failure(
			response_code >= 500
			or response_code == 0
			or result != HTTPRequest.RESULT_SUCCESS
		)
		return

	_finish_success(_content_type(headers), body)


func _finish_success(content_type: String, body: PackedByteArray) -> void:
	var handle := _active_handle
	var image := Image.new()
	var error := _load_image(image, content_type, body)
	if error != OK or image.is_empty():
		_finish_failure(true)
		return

	var pixelated := pixelate(image)
	_textures[handle] = ImageTexture.create_from_image(pixelated)
	_attempts.erase(handle)
	_active_handle = ""
	avatar_updated.emit(handle)
	_flush_queue()


func _finish_failure(retryable: bool) -> void:
	var handle := _active_handle
	_active_handle = ""
	var attempts := int(_attempts.get(handle, 0)) + 1
	_attempts[handle] = attempts
	if retryable and attempts < MAX_ATTEMPTS:
		_retry_at[handle] = (
			Time.get_ticks_msec()
			+ RETRY_BASE_MS * int(pow(2, attempts - 1))
		)
	else:
		avatar_updated.emit(handle)
	_flush_queue()


func _process_retries() -> void:
	var current_time := Time.get_ticks_msec()
	for handle: String in _retry_at.keys():
		if current_time < int(_retry_at[handle]):
			continue
		_retry_at.erase(handle)
		_enqueue(handle)


static func _load_image(
	image: Image,
	content_type: String,
	body: PackedByteArray
) -> int:
	if "png" in content_type:
		return image.load_png_from_buffer(body)
	if "webp" in content_type:
		return image.load_webp_from_buffer(body)
	return image.load_jpg_from_buffer(body)


static func _content_type(headers: PackedStringArray) -> String:
	for header in headers:
		if header.to_lower().begins_with("content-type:"):
			return header.get_slice(":", 1).strip_edges().to_lower()
	return "image/jpeg"


static func _nearest_palette_color(source: Color) -> Color:
	var nearest: Color = PALETTE[0]
	var nearest_distance := INF
	for candidate: Color in PALETTE:
		var distance := (
			pow(source.r - candidate.r, 2)
			+ pow(source.g - candidate.g, 2)
			+ pow(source.b - candidate.b, 2)
		)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest
