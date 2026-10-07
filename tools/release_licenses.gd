extends SceneTree
## Obtain the engine's own complete bundled third-party notices.
func _initialize() -> void:
	var output := OS.get_cmdline_user_args()[0]
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string("PETRIVERSE — Engine and third-party notices\n\n")
	file.store_string("Godot Engine\n============\n"+Engine.get_license_text()+"\n\n")
	for component in Engine.get_copyright_info():
		file.store_string(component.name+"\n")
		for part in component.parts:
			file.store_string("Files: "+", ".join(part.files)+"\n")
			file.store_string("Copyright: "+"; ".join(part.copyright)+"\n")
			file.store_string("License: "+part.license+"\n\n")
	var licenses: Dictionary = Engine.get_license_info()
	for name in licenses:
		file.store_string("\n"+name+"\n"+"=".repeat(name.length())+"\n"+licenses[name]+"\n")
	# The interface typeface ships with the game, so its OFL notice ships too.
	var font_notice := FileAccess.get_file_as_string("res://assets/fonts/OFL.txt")
	if not font_notice.is_empty():
		file.store_string("\nInter typeface\n==============\n"+font_notice+"\n")
	file.close()
	print("Wrote engine and third-party notices.")
	quit()
