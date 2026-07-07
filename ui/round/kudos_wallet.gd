class_name KudosWallet
extends Label
## Remaining-kudos pips for the judging-screen header (Slice 4 TDD §7).
## Reads the replicated local PlayerState (granted/spent); refreshes on the
## private wallet confirm and on every roster sync. Hidden entirely when the
## game runs with kudos off (allotment 0).

func _ready() -> void:
	add_theme_font_size_override("font_size", 18)
	EventBus.kudos_wallet_changed.connect(func(_remaining: int) -> void: _refresh())
	EventBus.roster_updated.connect(func(_players: Array) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var me: Roster.PlayerState = Session.local_player()
	if me == null or me.kudos_granted <= 0:
		text = ""
		return
	var remaining: int = maxi(0, me.kudos_granted - me.kudos_spent)
	text = "🏅".repeat(remaining) + "○".repeat(me.kudos_granted - remaining)
	tooltip_text = "%d of %d kudos left - giving one saves the drawing to your collection" \
			% [remaining, me.kudos_granted]
