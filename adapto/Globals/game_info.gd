## GameInfo - Central player progression system for AdapTo.
##
## Replaces the old Gamification autoload. Manages:
## - XP & leveling (levels 1-50)
## - Coins currency
## - Achievements (28+ creative milestones)
## - Game history tracking
## Persistent per user via Database.
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal achievement_unlocked(achievement_id: String, achievement_name: String, achievement_desc: String)
signal level_up(new_level: int)

# ── Achievements Registry ────────────────────────────────────────────────────
# We load from .tres files at runtime for easy editing
var _achievement_cache: Dictionary = {}  # id -> Achievement Resource

# ── State ─────────────────────────────────────────────────────────────────────
var xp_total := 0
var level := 1
var coins := 0
var achievements_unlocked: Dictionary = {}  # achievement_id -> timestamp
var games_played_count: Dictionary = {}     # game_id -> count
var total_games_completed := 0
var max_streak_ever := 0
var hints_used_total := 0
var total_xp_earned := 0
var total_coins_earned := 0
var current_session_wins := 0  # For tracking trifecta/pentagon
var current_game: String = ""  # Which game is currently being played
var last_jeopardy_money := 0   # For tracking exact $200 achievement
var comeback_count := 0       # For tracking comeback_king achievement

# ── Character Cosmetics ──────────────────────────────────────────────────────
var unlocked_characters: Dictionary = {
	"none": true,  # Default (no cosmetic), always unlocked
	"caius": false,
	"lucky": false
}
var selected_character: String = "none"

const CHARACTER_COSTS := {
	"none": 0,
	"caius": 300,
	"lucky": 150
}

const CHARACTER_SPRITES := {
	"none": "res://Assets/Sabine/Sabine-Sheet.png",  # Default sprite
	"caius": "res://Assets/Caius/Caius-Sheet.png",
	"lucky": "res://Assets/Lucky/Lucky-Sheet.png"
}

## Attempt to unlock a character by spending coins.
func unlock_character(char_id: String) -> bool:
	if not unlocked_characters.has(char_id):
		return false
	if unlocked_characters[char_id]:
		return false  # Already unlocked
	var cost := int(CHARACTER_COSTS.get(char_id, 0))
	if coins >= cost:
		coins -= cost
		unlocked_characters[char_id] = true
		_save_gameinfo()
		return true
	return false


## Select a character to display on the main menu.
func select_character(char_id: String) -> bool:
	if not unlocked_characters.has(char_id):
		return false
	if not unlocked_characters[char_id]:
		return false  # Not unlocked yet
	selected_character = char_id
	_save_gameinfo()
	return true

# ── Init ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_achievements()


# Loads all .tres achievement files from the achievements directory.
func _load_achievements() -> void:
	var dir = DirAccess.open("res://Globals/achievements")
	if dir == null:
		push_error("GameInfo: Could not open achievements directory.")
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var ach = load("res://Globals/achievements/" + file_name) as Achievement
			if ach != null and ach.id != "":
				_achievement_cache[ach.id] = ach
		file_name = dir.get_next()
	dir.list_dir_end()


# ── XP / Leveling ─────────────────────────────────────────────────────────────

const XP_PER_LEVEL_BASE := 100
const XP_PER_LEVEL_SCALE := 1.5
const MAX_LEVEL := 50

func _xp_for_level(lvl: int) -> int:
	return int(XP_PER_LEVEL_BASE * pow(XP_PER_LEVEL_SCALE, lvl - 1))

func get_xp_progress() -> float:
	if level >= MAX_LEVEL:
		return 1.0
	var current_xp := _xp_for_level(level)
	var next_xp := _xp_for_level(level + 1)
	var xp_in := xp_total - current_xp
	var needed := next_xp - current_xp
	return clampf(float(xp_in) / float(needed), 0.0, 1.0) if needed > 0 else 1.0

func get_xp_for_next_level() -> int:
	if level >= MAX_LEVEL:
		return 0
	return _xp_for_level(level + 1) - xp_total

func award_xp(amount: int) -> bool:
	if amount <= 0:
		return false
	var old_level := level
	xp_total += amount
	total_xp_earned += amount
	while level < MAX_LEVEL and xp_total >= _xp_for_level(level + 1):
		level += 1
		level_up.emit(level)
		_check_level_achievements()
	return level > old_level


func award_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	total_coins_earned += amount


# ── Reward Calculation ────────────────────────────────────────────────────────

const COIN_BASE := 10
const COIN_ACC_BONUS := 5
const COIN_STREAK_BONUS := 3

func calc_coin_reward(accuracy: float, max_streak: int, completion_ratio: float) -> int:
	var r := COIN_BASE
	if accuracy > 50.0:
		r += int(COIN_ACC_BONUS * ((accuracy - 50.0) / 10.0))
	if max_streak >= 3:
		r += COIN_STREAK_BONUS * (max_streak / 3)
	if completion_ratio >= 1.0:
		r += 10
	return clampi(r, COIN_BASE, 200)

func calc_xp_reward(accuracy: float, fair_score: float, completion_ratio: float) -> int:
	var xp := int(fair_score * 0.8)
	xp += int(accuracy * 0.2)
	if completion_ratio >= 1.0:
		xp += 15
	return clampi(xp, 5, 200)


# ── Game Completion ───────────────────────────────────────────────────────────

## Called by each game script when the game ends.
## Only awards XP/coins if game_won is true. Achievements are checked regardless.
## Returns { "new_achievements": [{id, name, desc}], "leveled_up": bool, "xp_gained": int, "coins_gained": int }
func record_game_completion(
	game_id: String,
	accuracy: float,
	fair_score: float,
	completion_ratio: float,
	max_streak: int,
	hints_used: int,
	time_spent: float,
	time_limit: float,
	game_won: bool,
	extra_data: Dictionary = {}
) -> Dictionary:
	var result := {
		"new_achievements": [],
		"leveled_up": false,
		"xp_gained": 0,
		"coins_gained": 0
	}

	# Track game played
	if not games_played_count.has(game_id):
		games_played_count[game_id] = 0
	games_played_count[game_id] += 1
	total_games_completed += 1
	hints_used_total += hints_used

	if max_streak > max_streak_ever:
		max_streak_ever = max_streak

	# Track session wins
	if game_won:
		current_session_wins += 1
	else:
		current_session_wins = 0

	# Only award XP/coins for wins
	if game_won:
		var xp_gained := calc_xp_reward(accuracy, fair_score, completion_ratio)
		result.xp_gained = xp_gained
		var leveled := award_xp(xp_gained)
		result.leveled_up = leveled

		var coins_gained := calc_coin_reward(accuracy, max_streak, completion_ratio)
		award_coins(coins_gained)
		result.coins_gained = coins_gained

	# Check achievements (always check, even on loss)
	result.new_achievements = _check_achievements(game_id, accuracy, max_streak, hints_used, time_spent, time_limit, game_won, extra_data)

	return result


# ── Achievement Checks ────────────────────────────────────────────────────────

func _check_achievements(game_id: String, accuracy: float, max_streak: int, hints_used: int, time_spent: float, time_limit: float, game_won: bool, extra: Dictionary) -> Array:
	var new_achievements := []

	# first_game
	if _try_unlock("first_game"):
		new_achievements.append("first_game")

	# diagnostic_done
	if UserStats.has_completed_diagnostic() and _try_unlock("diagnostic_done"):
		new_achievements.append("diagnostic_done")

	# perfect_game - 100% accuracy
	if accuracy >= 100.0 and _try_unlock("perfect_game"):
		new_achievements.append("perfect_game")

	# streak_5/10
	if max_streak >= 5 and _try_unlock("streak_5"):
		new_achievements.append("streak_5")
	if max_streak >= 10 and _try_unlock("streak_10"):
		new_achievements.append("streak_10")

	# all_games_played
	if games_played_count.size() >= 5 and _try_unlock("all_games_played"):
		new_achievements.append("all_games_played")

	# score_master - 1000 XP earned
	if total_xp_earned >= 1000 and _try_unlock("score_master"):
		new_achievements.append("score_master")

	# adaptive_master
	if UserStats.adaptive_games_played >= 5 and _try_unlock("adaptive_master"):
		new_achievements.append("adaptive_master")

	# coin_collector - 500 coins
	if total_coins_earned >= 500 and _try_unlock("coin_collector"):
		new_achievements.append("coin_collector")

	# level achievements
	if level >= 10 and _try_unlock("level_10"):
		new_achievements.append("level_10")
	if level >= 25 and _try_unlock("level_25"):
		new_achievements.append("level_25")

	# speed_demon - under 50% time, only on win
	if game_won and time_limit > 0 and time_spent <= time_limit * 0.5 and _try_unlock("speed_demon"):
		new_achievements.append("speed_demon")

	# no_hints - only on win
	if game_won and hints_used <= 0 and _try_unlock("no_hints"):
		new_achievements.append("no_hints")

	# comeback - accuracy < 50% but won
	if game_won and accuracy < 50.0:
		comeback_count += 1
		if _try_unlock("comeback"):
			new_achievements.append("comeback")

	# ── Game-specific creative achievements ──

	# jeopardy_exact_200 - Game2 with exactly $200
	if game_id == "game2" and game_won and extra.has("money") and int(extra["money"]) == 200 and _try_unlock("jeopardy_exact_200"):
		new_achievements.append("jeopardy_exact_200")

	# jeopardy_no_answers - Game2 with ALL questions as empty submissions
	if game_id == "game2" and extra.has("empty_submissions") and extra.has("total_questions") \
		and int(extra["empty_submissions"]) >= int(extra["total_questions"]) \
		and int(extra["total_questions"]) > 0 \
		and _try_unlock("jeopardy_no_answers"):
		new_achievements.append("jeopardy_no_answers")

	# crossword_skipped - Game3 skipped entirely
	if game_id == "game3" and extra.has("skipped") and bool(extra["skipped"]) and _try_unlock("crossword_skipped"):
		new_achievements.append("crossword_skipped")

	# game1_1hp - Game1 won with exactly 1 HP remaining
	if game_id == "game1" and game_won and extra.has("hp") and int(extra["hp"]) == 1 and _try_unlock("game1_1hp"):
		new_achievements.append("game1_1hp")

	# hangman_no_wrong_letters - Game5 won with zero mistakes
	if game_id == "game5" and game_won and extra.has("mistakes") and int(extra["mistakes"]) == 0 and _try_unlock("hangman_no_wrong_letters"):
		new_achievements.append("hangman_no_wrong_letters")

	# matching_same_type - Game4 attempted to match two cards of the same type
	if game_id == "game4" and extra.has("same_type_attempts") and int(extra["same_type_attempts"]) > 0 and _try_unlock("matching_same_type"):
		new_achievements.append("matching_same_type")

	# hangman_no_mistakes - Game5 with zero mistakes
	if game_id == "game5" and game_won and extra.has("mistakes") and int(extra["mistakes"]) == 0 and _try_unlock("hangman_no_mistakes"):
		new_achievements.append("hangman_no_mistakes")

	# crossword_lightning - Game3 under 60 seconds
	if game_id == "game3" and game_won and time_spent <= 60.0 and _try_unlock("crossword_lightning"):
		new_achievements.append("crossword_lightning")

	# matching_perfect - Game4 no wrong attempts
	if game_id == "game4" and game_won and extra.has("wrong_attempts") and int(extra["wrong_attempts"]) == 0 and _try_unlock("matching_perfect"):
		new_achievements.append("matching_perfect")

	# game1_no_hp_loss - Game1 with full HP
	if game_id == "game1" and game_won and extra.has("hp_lost") and int(extra["hp_lost"]) == 0 and _try_unlock("game1_no_hp_loss"):
		new_achievements.append("game1_no_hp_loss")

	# trifecta - 3 wins in a row this session
	if game_won and current_session_wins >= 3 and _try_unlock("trifecta"):
		new_achievements.append("trifecta")

	# pentagon - 5 wins in a row this session
	if game_won and current_session_wins >= 5 and _try_unlock("pentagon"):
		new_achievements.append("pentagon")

	# millionaire - 10000 coins earned total
	if total_coins_earned >= 10000 and _try_unlock("millionaire"):
		new_achievements.append("millionaire")

	# scholar - play 10 games total
	if total_games_completed >= 10 and _try_unlock("scholar"):
		new_achievements.append("scholar")

	# night_owl - play after midnight
	var hour = Time.get_time_dict_from_system()["hour"]
	if hour >= 0 and hour < 6 and _try_unlock("night_owl"):
		new_achievements.append("night_owl")

	# speed_runner - any game under 30 seconds, win
	if game_won and time_spent <= 30.0 and _try_unlock("speed_runner"):
		new_achievements.append("speed_runner")

	# comeback_king - 3 comebacks total
	if comeback_count >= 3 and _try_unlock("comeback_king"):
		new_achievements.append("comeback_king")

	# hint_avoidance - 5 games no hints
	var games_with_no_hints := 0
	# Rough check: if this game had no hints and total hints used is still 0
	if hints_used_total == 0 and games_played_count.size() >= 5 and _try_unlock("hint_avoidance"):
		new_achievements.append("hint_avoidance")

	# perfectionist - 100% accuracy in all 5 games (check through overall_stats)
	if _check_perfectionist() and _try_unlock("perfectionist"):
		new_achievements.append("perfectionist")

	return new_achievements


func _check_perfectionist() -> bool:
	var games_data = UserStats.overall_stats
	var required = ["game1", "game2", "game3", "game4", "game5"]
	for gid in required:
		if not games_data.has(gid):
			return false
		var acc = games_data[gid].get("accuracy", 0.0)
		# game1's accuracy is an Array (per question type), not a float
		if typeof(acc) == TYPE_ARRAY:
			var all_perfect = true
			for a in acc:
				if float(a) < 100.0:
					all_perfect = false
					break
			if not all_perfect:
				return false
		elif typeof(acc) == TYPE_FLOAT or typeof(acc) == TYPE_INT:
			if float(acc) < 100.0:
				return false
	return true


func _check_level_achievements() -> void:
	if level >= 10:
		_try_unlock("level_10")
	if level >= 25:
		_try_unlock("level_25")


func _try_unlock(achievement_id: String) -> bool:
	if achievements_unlocked.has(achievement_id):
		return false
	if not _achievement_cache.has(achievement_id):
		return false
	achievements_unlocked[achievement_id] = Time.get_unix_time_from_system()
	var ach = _achievement_cache[achievement_id]
	achievement_unlocked.emit(achievement_id, ach.name, ach.description)
	# Save immediately so achievements persist even if the game crashes
	_save_gameinfo()
	return true


## Save GameInfo data to database immediately.
func _save_gameinfo() -> void:
	if Global.current_user != null:
		Database.save_user_gameinfo(Global.current_user, serialize())


# ── Queries ───────────────────────────────────────────────────────────────────

func is_unlocked(ach_id: String) -> bool:
	return achievements_unlocked.has(ach_id)

func get_achievement(ach_id: String) -> Achievement:
	return _achievement_cache.get(ach_id, null)

func get_all_achievements() -> Array:
	var arr: Array = []
	for ach_id in _achievement_cache:
		var ach = _achievement_cache[ach_id]
		arr.append({
			"id": ach_id,
			"name": ach.name,
			"description": ach.description,
			"icon": ach.icon,
			"unlocked": achievements_unlocked.has(ach_id),
			"unlocked_at": achievements_unlocked.get(ach_id, 0)
		})
	return arr

func get_unlocked_count() -> int:
	return achievements_unlocked.size()

func get_total_count() -> int:
	return _achievement_cache.size()


# ── Serialization ─────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"xp_total": xp_total,
		"level": level,
		"coins": coins,
		"achievements_unlocked": achievements_unlocked.duplicate(),
		"games_played_count": games_played_count.duplicate(),
		"total_games_completed": total_games_completed,
		"max_streak_ever": max_streak_ever,
		"hints_used_total": hints_used_total,
		"total_xp_earned": total_xp_earned,
		"total_coins_earned": total_coins_earned,
		"comeback_count": comeback_count,
		"unlocked_characters": unlocked_characters.duplicate(),
		"selected_character": selected_character
	}

func deserialize(data: Dictionary) -> void:
	if data.is_empty():
		return
	xp_total = int(data.get("xp_total", 0))
	level = int(data.get("level", 1))
	coins = int(data.get("coins", 0))
	achievements_unlocked = data.get("achievements_unlocked", {}).duplicate()
	games_played_count = data.get("games_played_count", {}).duplicate()
	total_games_completed = int(data.get("total_games_completed", 0))
	max_streak_ever = int(data.get("max_streak_ever", 0))
	hints_used_total = int(data.get("hints_used_total", 0))
	total_xp_earned = int(data.get("total_xp_earned", 0))
	total_coins_earned = int(data.get("total_coins_earned", 0))
	comeback_count = int(data.get("comeback_count", 0))
	# Load character cosmetics
	if data.has("unlocked_characters") and typeof(data["unlocked_characters"]) == TYPE_DICTIONARY:
		for char_id in unlocked_characters:
			if data["unlocked_characters"].has(char_id):
				unlocked_characters[char_id] = bool(data["unlocked_characters"][char_id])
	if data.has("selected_character"):
		var sel = str(data["selected_character"])
		if unlocked_characters.has(sel) and unlocked_characters[sel]:
			selected_character = sel


## Reset all GameInfo data (for new users or testing).
func reset_all() -> void:
	xp_total = 0
	level = 1
	coins = 0
	achievements_unlocked.clear()
	games_played_count.clear()
	total_games_completed = 0
	max_streak_ever = 0
	hints_used_total = 0
	total_xp_earned = 0
	total_coins_earned = 0
	current_session_wins = 0
	comeback_count = 0
	unlocked_characters = {"none": true, "caius": false, "lucky": false}
	selected_character = "none"
