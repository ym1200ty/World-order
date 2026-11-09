extends Node
## Language (autoload "Lang"): Arabic by default, English optional. Use Lang.t("English text").
const AR_DICT := preload("res://scripts/lang_ar.gd")
var ar := true
var font: Font


func _ready() -> void:
	var f: FontFile = load("res://fonts/Cairo.ttf")
	f.fallbacks = [ThemeDB.fallback_font]
	font = f


func t(s: String) -> String:
	if not ar:
		return s
	return AR_DICT.AR.get(s, s)


func set_arabic(on: bool) -> void:
	ar = on
	TranslationServer.set_locale("ar" if on else "en")
