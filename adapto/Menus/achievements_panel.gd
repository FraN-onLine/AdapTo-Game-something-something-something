## Achievements panel controller.
##
## Displays all achievements in a scrollable list with the white/pixel style.
## Unlocked achievements are shown in color, locked ones are grayed out.
extends Control

@onready var title_label: Label = $PanelBox/VBox/TitleLabel
@onready var count_label: Label = $PanelBox/VBox/CountLabel
@onready var achievement_list: VBoxContainer = $PanelBox/VBox/Scroll/AchievementList
@onready var close_btn: Button = $PanelBox/VBox/CloseBtn

const FONT = preload("res://Assets/Fonts/Silkscreen-Regular.ttf")


func _ready() -> void:
	close_btn.pressed.connect(_on_close_btn_pressed)


## Populate the achievements list with all achievements.
func populate_achievements() -> void:
	# Clear existing entries
	for child in achievement_list.get_children():
		child.queue_free()
	
	var achievements = GameInfo.get_all_achievements()
	var unlocked_count = GameInfo.get_unlocked_count()
	var total_count = GameInfo.get_total_count()
	
	count_label.text = "%d/%d unlocked" % [unlocked_count, total_count]
	
	# Sort: unlocked first, then by name
	achievements.sort_custom(func(a, b):
		if a["unlocked"] != b["unlocked"]:
			return a["unlocked"]
		return a["name"] < b["name"]
	)
	
	for ach in achievements:
		var entry = _create_achievement_entry(ach)
		achievement_list.add_child(entry)


## Creates a single achievement entry box.
func _create_achievement_entry(ach: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.9) if ach["unlocked"] else Color(0.7, 0.7, 0.7, 0.5)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.8, 0.85, 0.92, 1) if ach["unlocked"] else Color(0.5, 0.5, 0.5, 0.5)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(hbox)
	
	# Status icon
	var status_label = Label.new()
	status_label.text = "✅" if ach["unlocked"] else "🔒"
	status_label.add_theme_font_override("font", FONT)
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.custom_minimum_size = Vector2(40, 0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not ach["unlocked"]:
		status_label.modulate = Color(0.5, 0.5, 0.5, 1)
	hbox.add_child(status_label)
	
	# Name + description
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = ach["name"]
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1) if ach["unlocked"] else Color(0.4, 0.4, 0.4, 1))
	vbox.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = ach["description"]
	desc_label.add_theme_font_override("font", FONT)
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1) if ach["unlocked"] else Color(0.5, 0.5, 0.5, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	return panel


func _on_close_btn_pressed() -> void:
	visible = false
	queue_free()
