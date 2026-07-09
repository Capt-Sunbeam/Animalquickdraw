class_name TitleIds
## Slice 10 wrap-up award identifiers (TDD 10 §2). The String ids are the
## wire/stats contract - Slice 14 keys its lifetime titles_earned counters
## off them - so, like every wire enum, the set is append-only and ids are
## never renamed once shipped. Display names live here too: one lookup site
## for every card/summary surface.

const HOTSHOT: String = "hotshot"
const JUDGES_DARLING: String = "judges_darling"
const PEOPLES_CHAMPION: String = "peoples_champion"
const GENEROUS_SOUL: String = "generous_soul"
const SPEED_DEMON: String = "speed_demon"
const DA_VINCI: String = "da_vinci"
const MINIMALIST: String = "minimalist"
const WORST_DRAWER: String = "worst_drawer"

## Award priority order (TDD 10 §2): titles are assigned top-down and each
## player holds AT MOST ONE card, so earlier rows outrank later ones and the
## cards spread across the table.
const PRIORITY: Array[String] = [HOTSHOT, JUDGES_DARLING, PEOPLES_CHAMPION,
		GENEROUS_SOUL, SPEED_DEMON, DA_VINCI, MINIMALIST, WORST_DRAWER]

const DISPLAY_NAMES: Dictionary = {
	HOTSHOT: "Hotshot",
	JUDGES_DARLING: "Judge's Darling",
	PEOPLES_CHAMPION: "People's Champion",
	GENEROUS_SOUL: "Generous Soul",
	SPEED_DEMON: "Speed Demon",
	DA_VINCI: "Da Vinci",
	MINIMALIST: "Minimalist",
	WORST_DRAWER: "Worst Drawer",
}

## Superlative ids/display names indexed by NetIds.Reaction (append-only,
## exactly like the enum they mirror).
const SUPERLATIVE_IDS: Array[String] = ["funniest", "most_beloved",
		"most_impressive", "most_cursed", "biggest_tearjerker", "straight_fire"]
const SUPERLATIVE_NAMES: Array[String] = ["Funniest Drawing", "Most Beloved",
		"Most Impressive", "Most Cursed", "Biggest Tearjerker", "Straight Fire"]


static func display_name(title_id: String) -> String:
	return str(DISPLAY_NAMES.get(title_id, title_id.capitalize()))
