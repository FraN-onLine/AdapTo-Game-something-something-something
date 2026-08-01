#!/usr/bin/env python3
"""Generate all achievement .tres resource files for AdapTo."""
import os
import random

ACHIEVEMENTS = [
    # (id, name, description)
    ("first_game", "First Steps", "Complete your first game"),
    ("diagnostic_done", "Fully Diagnosed", "Complete the full diagnostic round (all 5 games)"),
    ("perfect_game", "Flawless Victory", "Achieve 100% accuracy in any game"),
    ("streak_5", "On Fire", "Reach a 5-correct streak in any game"),
    ("streak_10", "Unstoppable", "Reach a 10-correct streak in any game"),
    ("all_games_played", "Explorer", "Play all 5 games at least once"),
    ("score_master", "Score Master", "Earn over 1000 total XP"),
    ("adaptive_master", "Adaptive Master", "Complete 5 adaptive mode sessions"),
    ("coin_collector", "Coin Collector", "Collect over 500 coins"),
    ("level_10", "Dedicated Learner", "Reach level 10"),
    ("level_25", "Knowledge Seeker", "Reach level 25"),
    ("speed_demon", "Speed Demon", "Complete a game with under 50% of the time limit remaining"),
    ("no_hints", "Pure Skill", "Complete a game without using any hints"),
    ("comeback", "Comeback Kid", "Win a game after a rough start (accuracy < 50% but still won)"),
    # Creative new achievements
    ("jeopardy_exact_200", "At Least It Didn't Go Under", "Complete Jeopardy with exactly $200"),
    ("hangman_no_mistakes", "Word Wizard", "Complete Hangman without any mistakes"),
    ("crossword_lightning", "Crossword Lightning", "Complete the crossword in under 60 seconds"),
    ("matching_perfect", "Perfect Match", "Match all pairs in Matching Game without any wrong guesses"),
    ("game1_no_hp_loss", "Flawless Fighter", "Complete Game 1 without losing any HP"),
    ("trifecta", "Trifecta", "Win 3 games in a row"),
    ("pentagon", "Pentagon", "Win all 5 games in a single session"),
    ("millionaire", "Millionaire", "Earn a total of 10000 coins across all sessions"),
    ("scholar", "Scholar", "Complete 10 different lessons"),
    ("night_owl", "Night Owl", "Play a game after midnight"),
    ("speed_runner", "Speed Runner", "Complete any game in under 30 seconds"),
    ("comeback_king", "Comeback King", "Win 3 games after being near failure"),
    ("hint_avoidance", "Houdini", "Complete 5 games without using any hints"),
    ("perfectionist", "Perfectionist", "Get 100% accuracy in all 5 games at least once"),
]

def generate_uid():
    chars = '0123456789abcdefghijklmnopqrstuvwxyz'
    return "uid://achv_" + ''.join(random.choice(chars) for _ in range(8))

OUTPUT_DIR = "C:/AdapTo/adapto/Globals/achievements"
os.makedirs(OUTPUT_DIR, exist_ok=True)

for ach_id, name, desc in ACHIEVEMENTS:
    uid = generate_uid()
    content = f'''[gd_resource type="Resource" script_class="Achievement" load_steps=2 format=3 uid="{uid}"]

[ext_resource type="Script" path="res://Globals/achievement.gd" id="1"]

[resource]
script = ExtResource("1")
id = "{ach_id}"
name = "{name}"
description = "{desc}"
icon = null
'''
    path = os.path.join(OUTPUT_DIR, f"{ach_id}.tres")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Created: {path}")

print(f"\nGenerated {len(ACHIEVEMENTS)} achievement .tres files.")