## API key entry controller.
## Scene-based panel for entering and validating a Gemini API key.
extends Control

signal api_key_saved(api_key: String)
signal skipped

const FONT = preload("res://Assets/Fonts/Silkscreen-Regular.ttf")
const GEMINI_MODEL := "gemini-1.5-flash"

const COLOR_ERROR = Color(0.749, 0.188, 0.188, 1)
const COLOR_SUCCESS = Color(0.18, 0.616, 0.306, 1)
const COLOR_DEFAULT = Color(0.0, 0.0, 0.0, 1)

@onready var api_key_edit: LineEdit = $Panel/VBoxContainer/ApiKeyEdit
@onready var feedback_label: Label = $Panel/VBoxContainer/FeedbackLabel
@onready var save_button: Button = $Panel/VBoxContainer/HBoxContainer/SaveButton

var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_validation_completed)


func _on_save_pressed() -> void:
	var key := api_key_edit.text.strip_edges()
	if key.is_empty():
		_display_feedback("Please enter an API key.", "error")
		return

	# Disable button while validating
	save_button.disabled = true
	_display_feedback("Validating API key...", "default")
	_validate_api_key(key)


func _validate_api_key(key: String) -> void:
	# Send a minimal request to the Gemini API to check if the key is valid
	var url := "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s" % [GEMINI_MODEL, key]
	var body := {
		"contents": [{
			"parts": [{"text": "ping"}]
		}],
		"generationConfig": {
			"temperature": 0.0,
			"maxOutputTokens": 1
		}
	}
	var headers := ["Content-Type: application/json"]
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		save_button.disabled = false
		_display_feedback("Network error. Please try again.", "error")


func _on_validation_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	save_button.disabled = false

	if response_code >= 200 and response_code < 300:
		# Valid key
		var key := api_key_edit.text.strip_edges()
		_display_feedback("API key is valid!", "success")
		api_key_saved.emit(key)
	else:
		_display_feedback("Invalid API key. Please check and try again.", "error")


func _on_skip_pressed() -> void:
	skipped.emit()


func _display_feedback(message: String, feedback_type: String = "default") -> void:
	feedback_label.text = message
	match feedback_type:
		"error":
			feedback_label.add_theme_color_override("font_color", COLOR_ERROR)
		"success":
			feedback_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		_:
			feedback_label.add_theme_color_override("font_color", COLOR_DEFAULT)