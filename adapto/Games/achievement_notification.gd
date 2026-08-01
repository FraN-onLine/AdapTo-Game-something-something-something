## Achievement notification manager.
##
## Listens to GameInfo.achievement_unlocked signal and shows Steam-style
## popups in the bottom right corner. Stacks multiple achievements vertically.
## Plays one instance of success.wav when at least one achievement is unlocked.
extends CanvasLayer

@onready var popup_vbox: VBoxContainer = $PopupVBox

const POPUP_SCENE = preload("res://Games/achievement_popup.tscn")

# Track if we've already played the sound for this batch of achievements.
var _sound_played_this_batch := false


func _ready() -> void:
	if GameInfo == null:
		return
	if not GameInfo.achievement_unlocked.is_connected(_on_achievement_unlocked):
		GameInfo.achievement_unlocked.connect(_on_achievement_unlocked)


## Called when an achievement is unlocked.
func _on_achievement_unlocked(ach_id: String, ach_name: String, ach_desc: String) -> void:
	if not _sound_played_this_batch:
		_play_success_sound_once()
		_sound_played_this_batch = true
		await get_tree().create_timer(0.35).timeout
		_sound_played_this_batch = false

	var popup = POPUP_SCENE.instantiate()
	popup_vbox.add_child(popup)
	popup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup.custom_minimum_size.x = 340
	popup.modulate.a = 0.0

	await get_tree().process_frame

	var ach = GameInfo.get_achievement(ach_id) if GameInfo != null else null
	var icon = ach.icon if ach != null and ach.icon != null else null
	popup.setup(ach_name, ach_desc, icon)

	var tween := popup.create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.15)


func _play_success_sound_once() -> void:
	if SFXManager != null:
		SFXManager.play_success(0)