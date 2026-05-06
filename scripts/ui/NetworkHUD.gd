extends Control

signal leave_requested

@onready var session_label: Label = %SessionLabel #$MarginContainer/PanelContainer/MarginContainer/VBoxContainer/SessionLabel
@onready var help_label: Label = %HelpLabel #$MarginContainer/PanelContainer/MarginContainer/VBoxContainer/HelpLabel
@onready var leave_button: Button = %LeaveButton #$LeaveButton


func _ready() -> void:
	help_label.text = "ZQSD ou WASD pour bouger, clic gauche pour tirer, Échap pour revenir au menu."
	leave_button.pressed.connect(_on_leave_button_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		leave_requested.emit()


func set_session_text(value: String) -> void:
	session_label.text = value


func _on_leave_button_pressed() -> void:
	leave_requested.emit()
