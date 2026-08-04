## Game select panel controller.
## Scene-based panel for choosing a game to play in single-game mode.
extends Control

signal game_selected(game_id: String)
signal closed

const FONT = preload("res://Assets/Fonts/Silkscreen-Regular.ttf")

@onready var title_label: Label = $PanelBox/VBox/TitleLabel
@onready var game_list: VBoxContainer = $PanelBox/VBox/Scroll/GameListVBox


## Populate the game list with buttons for each game.
func populate_games() -> void:
	for child in game_list.get_children():
		child.queue_free()

	var game_names := {
		"game1": "Multiple Choice",
		"game2": "Jeopardy",
		"game3": "Crossword",
		"game4": "Matching Game",
		"game5": "Hangman"
	}

	title_label.text = "Select a Game (1 of %d)" % UserStats.GAME_SEQUENCE.size()

	for game_id in UserStats.GAME_SEQUENCE:
		var gname: String = game_names.get(game_id, game_id)
		var btn := Button.new()
		btn.text = gname
		btn.custom_minimum_size = Vector2(0, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_override("font", FONT)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 1)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_right = 12
		style.corner_radius_bottom_left = 12
		btn.add_theme_stylebox_override("normal", style)
		btn.pressed.connect(_on_game_button_pressed.bind(game_id))
		game_list.add_child(btn)


func _on_game_button_pressed(game_id: String) -> void:
	game_selected.emit(game_id)


func _on_cancel_pressed() -> void:
	closed.emit()