class_name CampFarewellDialogue
extends DialogueUI
signal aborted
func _input(event:InputEvent)->void:
	if is_open() and UIFlow.is_top(self) and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		cancel();aborted.emit();get_viewport().set_input_as_handled();return
	super._input(event)
