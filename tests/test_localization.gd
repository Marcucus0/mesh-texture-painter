extends SceneTree
const I18n = preload("res://addons/mesh_texture_painter/localization.gd")

func _initialize() -> void:
	var failures := 0
	var placeholders := RegEx.create_from_string("%[sd]")
	for source in I18n.ENGLISH:
		var english: String = I18n.ENGLISH[source]
		if I18n.in_language(source, "en_US") != english or I18n.in_language(source, "fr_BE") != source:
			failures += 1
			push_error("Missing translation: " + source)
		var a := placeholders.search_all(source)
		var b := placeholders.search_all(english)
		if a.size() != b.size():
			failures += 1
		else:
			for index in a.size():
				if a[index].get_string() != b[index].get_string():
					failures += 1
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	if I18n.in_language("Dureté", "de") != "Hardness":
		failures += 1
	TranslationServer.set_locale(original_locale)
	print("LOCALIZATION RESULT: %d messages, %d failures" % [I18n.ENGLISH.size(), failures])
	quit(1 if failures else 0)
