## Individual achievement popup item.
##
## Shows a Steam-style notification with icon, name, and description.
## Auto-dismisses after a few seconds with a fade-out animation.
extends PanelContainer

@onready var icon_rect: TextureRect = $HBox/IconRect
@onready var name_label: Label = $HBox/VBox/NameLabel
@onready var desc_label: Label = $HBox/VBox/DescLabel

const DISPLAY_DURATION := 4.0
const FADE_DURATION := 0.35


## Initialize the popup with achievement data.
func setup(ach_name: String, ach_desc: String, ach_icon: Texture2D = null) -> void:
	if not is_node_ready():
		await ready
	name_label.text = ach_name
	desc_label.text = ach_desc
	if ach_icon != null:
		icon_rect.texture = ach_icon
	else:
		icon_rect.texture = load("res://icon.svg")

	await get_tree().create_timer(DISPLAY_DURATION).timeout
	_fade_out()


## Fade out and remove the popup.
func _fade_out() -> void:
	if is_queued_for_deletion():
		return
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(queue_free)
