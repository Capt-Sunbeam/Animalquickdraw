class_name AchievementDefs
extends RefCounted
## Slice 14: the v1 achievement table - 27 ids FROZEN by owner decision
## (decision log 2026-07-12). Each id IS the Steamworks API name Slice 15
## configures on the partner site; ids never change after that. Display
## names here are working copy - the partner site is their final home.
## Data-driven: adding an achievement = one row here + Steamworks config
## (+ a counter in StatsService if it reads a new stat).
##
## Condition sources (checked in is_met):
##   stat_key + threshold  - plain counter compare
##   title_id + threshold  - reads titles_earned[title_id]
##   custom                - Callable(stats: Dictionary) -> bool

class Def extends RefCounted:
	var id: String
	var display_name: String       # working copy (partner site finalizes)
	var stat_key: String = ""
	var threshold: int = 1
	var title_id: String = ""
	var custom: Callable = Callable()

	func _init(p_id: String, p_name: String) -> void:
		id = p_id
		display_name = p_name

	static func counter(p_id: String, p_name: String, key: String, at: int) -> Def:
		var def := Def.new(p_id, p_name)
		def.stat_key = key
		def.threshold = at
		return def

	static func title(p_id: String, p_name: String, p_title_id: String, at: int) -> Def:
		var def := Def.new(p_id, p_name)
		def.title_id = p_title_id
		def.threshold = at
		return def

	static func special(p_id: String, p_name: String, evaluator: Callable) -> Def:
		var def := Def.new(p_id, p_name)
		def.custom = evaluator
		return def


static var _all: Array[Def] = []


static func all() -> Array[Def]:
	if _all.is_empty():
		_all = _build()
	return _all


static func is_met(def: Def, stats: Dictionary) -> bool:
	if def.custom.is_valid():
		return bool(def.custom.call(stats))
	if not def.title_id.is_empty():
		return _title_count(stats, def.title_id) >= def.threshold
	return int(stats.get(def.stat_key, 0)) >= def.threshold


static func _title_count(stats: Dictionary, title_id: String) -> int:
	return int((stats.get("titles_earned", {}) as Dictionary).get(title_id, 0))


## One of Everything: every title in the live TitleIds set at least once.
static func _every_title_once(stats: Dictionary) -> bool:
	for title_id: String in TitleIds.PRIORITY:
		if _title_count(stats, title_id) < 1:
			return false
	return true


static func _build() -> Array[Def]:
	var defs: Array[Def] = []
	# Per-title first + tenth (7 titles x 2 = 14).
	var tenth_names: Dictionary = {
		TitleIds.HOTSHOT: ["Hotshot", "Serial Hotshot"],
		TitleIds.JUDGES_DARLING: ["Teacher's Pet", "Court Favorite"],
		TitleIds.PEOPLES_CHAMPION: ["Voice of the People", "Folk Hero"],
		TitleIds.GENEROUS_SOUL: ["Sharing is Caring", "Patron of the Arts"],
		TitleIds.SPEED_DEMON: ["Quick on the Draw", "Lightning Round"],
		TitleIds.DA_VINCI: ["Renaissance Mammal", "Old Master"],
		TitleIds.MINIMALIST: ["Less is More", "Bare Necessities"],
	}
	for title_id: String in TitleIds.PRIORITY:
		var names: Array = tenth_names[title_id]
		defs.append(Def.title("first_%s" % title_id, str(names[0]), title_id, 1))
		defs.append(Def.title("%s_x10" % title_id, str(names[1]), title_id, 10))
	# Milestones (6).
	defs.append(Def.counter("first_game", "Welcome to the Zoo", "games_played", 1))
	defs.append(Def.counter("first_win", "Top Dog", "wins", 1))
	defs.append(Def.counter("games_10", "Animal Aficionado", "games_played", 10))
	defs.append(Def.counter("games_100", "Party Animal", "games_played", 100))
	defs.append(Def.counter("rounds_100", "Century of Scribbles", "rounds_played", 100))
	defs.append(Def.counter("round_wins_25", "Judge Magnet", "round_wins", 25))
	# Collection & kudos (4).
	defs.append(Def.counter("save_10", "Petting Zoo", "drawings_saved", 10))
	defs.append(Def.counter("save_50", "Animal Enthusiast", "drawings_saved", 50))
	defs.append(Def.counter("save_100", "Animal Hoarder", "drawings_saved", 100))
	defs.append(Def.counter("all_kudos_spent", "Big Spender", "kudos_games_all_spent", 1))
	# Special (3).
	defs.append(Def.special("title_collector", "One of Everything",
			Callable(AchievementDefs, "_every_title_once")))
	defs.append(Def.counter("full_lobby", "Full House", "games_full_lobby", 1))
	defs.append(Def.counter("clean_sweep", "Clean Sweep", "clean_sweeps", 1))
	return defs
