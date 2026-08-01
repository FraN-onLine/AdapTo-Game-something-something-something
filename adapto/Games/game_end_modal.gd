extends CanvasLayer

signal confirmed

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var continue_btn: Button = $Panel/VBox/ContinueBtn

func show_stats(title_text: String, message_text: String, gameinfo_data: Dictionary = {}) -> void:
	if not is_node_ready():
		await ready
	
	# Append game info rewards to the message text
	var full_message := message_text
	if not gameinfo_data.is_empty():
		full_message += "\n\n─── Rewards ───"
		var has_rewards := false
		if gameinfo_data.has("xp_gained") and gameinfo_data["xp_gained"] > 0:
			full_message += "\n+%d XP" % gameinfo_data["xp_gained"]
			has_rewards = true
		if gameinfo_data.has("coins_gained") and gameinfo_data["coins_gained"] > 0:
			full_message += "\n+%d 🪙" % gameinfo_data["coins_gained"]
			has_rewards = true
		if gameinfo_data.has("leveled_up") and gameinfo_data["leveled_up"]:
			full_message += "\n⬆ LEVEL UP! Now Level %d" % (GameInfo.level if GameInfo != null else 0)
			has_rewards = true
		if gameinfo_data.has("new_achievements") and not gameinfo_data["new_achievements"].is_empty():
			full_message += "\n🏆 Achievements:"
			for ach_id in gameinfo_data["new_achievements"]:
				if GameInfo != null:
					var ach = GameInfo.get_achievement(ach_id)
					if ach != null:
						full_message += "\n  %s" % ach.name
			has_rewards = true
		if not has_rewards:
			full_message = message_text  # No rewards, show original
	
	title_label.text = title_text
	message_label.text = full_message

func _on_continue_btn_pressed() -> void:
	emit_signal("confirmed")
