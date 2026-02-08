extends Node2D

@onready var question = $Question
@onready var option1_button = $Option1Button
@onready var option2_button = $Option2Button
@onready var submit_button = $SubmitButton
@onready var feedback_label = $FeedbackLabel

var lesson: Lesson
var current_item: LessonItem
var selected_option: int = -1  # 0 for option1, 1 for option2
var question_type: int = 0  # 0=show definition, 1=show keyword, 2=show term
var option1_value: String = ""
var option2_value: String = ""

func _ready() -> void:
	# Load the OOP lesson
	lesson = load("res://Lessons/lesson_files/Object Oriented/oop.tres")
	
	# Connect button signals
	option1_button.pressed.connect(_on_option1_pressed)
	option2_button.pressed.connect(_on_option2_pressed)
	submit_button.pressed.connect(_on_submit_pressed)
	
	# Load first question
	load_next_question()

func load_next_question() -> void:
	# Clear feedback and reset selection
	feedback_label.text = ""
	selected_option = -1
	option1_button.modulate = Color.WHITE
	option2_button.modulate = Color.WHITE
	
	# Get random lesson item
	current_item = lesson.get_random_lesson_item()
	if current_item == null:
		question.text = "No lesson items available!"
		return
	
	# Randomly choose what to display (0=keyword, 1=simple_terms, 2=term)
	question_type = randi() % 3
	
	# Set up the question text
	var display_text = ""
	match question_type:
		0:  # Show keyword
			display_text = current_item.keyword
		1:  # Show simple_terms
			display_text = current_item.simple_terms
		2:  # Show term
			display_text = current_item.term
	
	# Find second term (either related or random)
	var second_term = find_related_or_random_term()
	
	# Create options array with terms
	var options = [current_item.term, second_term]
	options.shuffle()
	
	# Store the option values for answer checking
	option1_value = options[0]
	option2_value = options[1]
	
	# Set UI text
	question.text = "What is this?\n\n" + display_text
	option1_button.text = option1_value
	option2_button.text = option2_value

func _on_option1_pressed() -> void:
	selected_option = 0
	option1_button.modulate = Color.YELLOW
	option2_button.modulate = Color.WHITE

func _on_option2_pressed() -> void:
	selected_option = 1
	option2_button.modulate = Color.YELLOW
	option1_button.modulate = Color.WHITE

func find_related_or_random_term() -> String:
	# Try to find a term with shared related_to values
	var candidates = []
	
	for item in lesson.lesson_items:
		if item.id == current_item.id:
			continue  # Skip the current item
		
		# Check if they share any related_to values
		for related in current_item.related_to:
			if related in item.related_to:
				candidates.append(item.term)
				break
	
	# If we found candidates with shared related_to, pick a random one
	if not candidates.is_empty():
		return candidates[randi() % candidates.size()]
	
	# Otherwise, pick a random term from the lesson
	var random_item = lesson.get_random_lesson_item()
	while random_item.id == current_item.id:
		random_item = lesson.get_random_lesson_item()
	return random_item.term

func _on_submit_pressed() -> void:
	if selected_option == -1:
		feedback_label.text = "Please select an option!"
		feedback_label.modulate = Color.WHITE
		return
	
	var selected_value = option1_value if selected_option == 0 else option2_value
	var is_correct = (selected_value == current_item.term)
	
	if is_correct:
		feedback_label.text = "✓ Correct! Loading next question..."
		feedback_label.modulate = Color.GREEN
		await get_tree().create_timer(1.5).timeout
		load_next_question()
	else:
		feedback_label.text = "✗ Incorrect. The answer was: " + current_item.term
		feedback_label.modulate = Color.RED
