class_name TitleIds
## Slice 10 wrap-up award identifiers (reworked by Slice 19). The String ids
## are the wire/stats contract - Slice 14 keys its lifetime titles_earned
## counters off them - so, like every wire enum, the set is append-only and
## ids are never renamed once shipped. Display names live here too: one
## lookup site for every card/summary surface.
## Slice 19 (owner, 2026-07-12): WORST_DRAWER and all superlatives removed
## with the emoji reaction retirement; titles stack (no one-per-player rule).

const HOTSHOT: String = "hotshot"
const JUDGES_DARLING: String = "judges_darling"
const PEOPLES_CHAMPION: String = "peoples_champion"
const GENEROUS_SOUL: String = "generous_soul"
const SPEED_DEMON: String = "speed_demon"
const DA_VINCI: String = "da_vinci"
const MINIMALIST: String = "minimalist"

## Ceremony/display order (Slice 19: titles stack, so this no longer ranks
## exclusivity - it is purely the order cards are awarded and badges listed).
const PRIORITY: Array[String] = [HOTSHOT, JUDGES_DARLING, PEOPLES_CHAMPION,
		GENEROUS_SOUL, SPEED_DEMON, DA_VINCI, MINIMALIST]

const DISPLAY_NAMES: Dictionary = {
	HOTSHOT: "Hotshot",
	JUDGES_DARLING: "Judge's Darling",
	PEOPLES_CHAMPION: "People's Champion",
	GENEROUS_SOUL: "Generous Soul",
	SPEED_DEMON: "Speed Demon",
	DA_VINCI: "Da Vinci",
	MINIMALIST: "Minimalist",
}


static func display_name(title_id: String) -> String:
	return str(DISPLAY_NAMES.get(title_id, title_id.capitalize()))
