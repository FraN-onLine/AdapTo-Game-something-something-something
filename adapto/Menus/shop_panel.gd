## Shop panel controller.
## Scene-based panel for unlocking and selecting characters using coins.
extends Control

signal shop_changed
signal closed

const FONT = preload("res://Assets/Fonts/Silkscreen-Regular.ttf")

const SHOP_ITEMS := [
	{"char_id": "none", "char_name": "None (Default)", "action": "Default", "cost": 0, "always_unlocked": true},
	{"char_id": "caius", "char_name": "Caius", "action": "Unlock Character", "cost": 300, "always_unlocked": false},
	{"char_id": "lucky", "char_name": "Lucky", "action": "Unlock Character", "cost": 150, "always_unlocked": false},
]

@onready var coins_label: Label = $PanelBox/VBox/CoinsLabel
@onready var current_label: Label = $PanelBox/VBox/CurrentLabel
@onready var shop_list: VBoxContainer = $PanelBox/VBox/Scroll/ShopListVBox


## Refresh the shop display with current GameInfo data.
func refresh() -> void:
	coins_label.text = "🪙 Coins: %d" % GameInfo.coins
	current_label.text = "Current: %s" % GameInfo.selected_character.capitalize()

	# Clear existing entries
	for child in shop_list.get_children():
		child.queue_free()

	for item in SHOP_ITEMS:
		var char_id: String = item["char_id"]
		var char_name: String = item["char_name"]
		var cost: int = item["cost"]
		var is_unlocked: bool = item["always_unlocked"] or GameInfo.unlocked_characters.get(char_id, false)
		_add_shop_item(char_id, char_name, cost, is_unlocked)


func _add_shop_item(char_id: String, char_name: String, cost: int, unlocked: bool) -> void:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 62)

	# Character name label
	var name_label := Label.new()
	name_label.text = char_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)

	# Action button
	var action_btn := Button.new()
	action_btn.name = char_id + "_btn"
	action_btn.custom_minimum_size = Vector2(140, 48)
	action_btn.add_theme_font_override("font", FONT)
	action_btn.add_theme_font_size_override("font_size", 16)

	if char_id == GameInfo.selected_character:
		# Currently selected
		action_btn.text = "SELECTED"
		action_btn.disabled = true
		action_btn.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2, 1))
		action_btn.add_theme_stylebox_override("normal", _make_style(Color(1, 1, 1, 1)))
	elif unlocked:
		# Unlocked but not selected
		action_btn.text = "SELECT"
		action_btn.pressed.connect(_on_select_character.bind(char_id))
		action_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		action_btn.add_theme_stylebox_override("normal", _make_style(Color(0.196, 0.435, 0.765, 1)))
	else:
		# Not unlocked
		action_btn.text = "%d 🪙" % cost
		action_btn.pressed.connect(_on_buy_character.bind(char_id, cost))
		action_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		if GameInfo.coins >= cost:
			action_btn.add_theme_stylebox_override("normal", _make_style(Color(0.18, 0.616, 0.306, 1)))
		else:
			action_btn.add_theme_stylebox_override("normal", _make_style(Color(0.749, 0.188, 0.188, 1)))
			action_btn.disabled = true

	hbox.add_child(action_btn)
	shop_list.add_child(hbox)


func _make_style(bg_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 14
	sb.corner_radius_bottom_left = 14
	return sb


func _on_buy_character(char_id: String, cost: int) -> void:
	if GameInfo.unlock_character(char_id):
		GameInfo._save_gameinfo()
		refresh()
		shop_changed.emit()
		_notify("Character unlocked! 🎉\nYou can now select this character.")
	else:
		_notify("Not enough coins!\nYou need %d 🪙 but have %d 🪙" % [cost, GameInfo.coins])


func _on_select_character(char_id: String) -> void:
	if GameInfo.select_character(char_id):
		GameInfo._save_gameinfo()
		refresh()
		shop_changed.emit()
		_notify("Character selected: %s!" % char_id.capitalize())


func _notify(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Shop"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func _on_close_pressed() -> void:
	closed.emit()