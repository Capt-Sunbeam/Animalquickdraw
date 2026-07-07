class_name Palette
## Versioned palette (Slice 1 §2). `c` indices in DrawingDocs point here
## FOREVER: the table is APPEND-ONLY - never reorder, remove, or recolor an
## existing index. A reorder would silently recolor every saved drawing.
##
## Flat table; index = family * SHADES_PER_FAMILY + shade. Shade 0 is the
## lightest, shade 4 the darkest; the middle shade is each family's "base"
## swatch. Family 0 is greyscale (shade 0 = white == canvas background, so
## "erase" is just painting white; shade 4 = black, the default brush color).

const PALETTE_VERSION: int = 1
const FAMILY_COUNT: int = 12
const SHADES_PER_FAMILY: int = 5
const BASE_SHADE: int = 2

## Family indices, for readability at call sites.
const FAMILY_GREYSCALE: int = 0

## Default brush color: black (greyscale family, darkest shade).
const DEFAULT_COLOR_INDEX: int = 4

## Eraser strokes paint this index (Slice 16): white == CANVAS_BACKGROUND,
## so "erasing" is an ordinary deterministic stroke op that replays visibly.
const ERASE_COLOR_INDEX: int = 0

const COLORS: Array[Color] = [
	# 0 greyscale: white -> black
	Color("#ffffff"), Color("#c8c8c8"), Color("#8c8c8c"), Color("#4b4b4b"), Color("#000000"),
	# 1 red
	Color("#ffc9c9"), Color("#ff8a80"), Color("#e53935"), Color("#b71c1c"), Color("#7f0000"),
	# 2 orange
	Color("#ffe0b2"), Color("#ffb74d"), Color("#fb8c00"), Color("#e65100"), Color("#9e3d00"),
	# 3 yellow
	Color("#fff9c4"), Color("#fff176"), Color("#fdd835"), Color("#f9a825"), Color("#c17900"),
	# 4 green
	Color("#c8e6c9"), Color("#81c784"), Color("#43a047"), Color("#2e7d32"), Color("#1b4d1e"),
	# 5 teal
	Color("#b2dfdb"), Color("#4db6ac"), Color("#00897b"), Color("#00695c"), Color("#003d33"),
	# 6 blue
	Color("#bbdefb"), Color("#64b5f6"), Color("#1e88e5"), Color("#1565c0"), Color("#0d3c78"),
	# 7 navy
	Color("#c5cae9"), Color("#7986cb"), Color("#3949ab"), Color("#283593"), Color("#141c54"),
	# 8 purple
	Color("#e1bee7"), Color("#ba68c8"), Color("#8e24aa"), Color("#6a1b9a"), Color("#3e1055"),
	# 9 pink
	Color("#f8bbd0"), Color("#f06292"), Color("#e91e63"), Color("#c2185b"), Color("#78103a"),
	# 10 brown
	Color("#d7ccc8"), Color("#a1887f"), Color("#6d4c41"), Color("#4e342e"), Color("#2e1e18"),
	# 11 tan
	Color("#f5e9da"), Color("#e6cba8"), Color("#c9a26d"), Color("#a87f4f"), Color("#7a5a36"),
]

const CANVAS_BACKGROUND: Color = Color.WHITE  # == COLORS[0]


static func base_index(family: int) -> int:
	return family * SHADES_PER_FAMILY + BASE_SHADE


static func family_of(color_index: int) -> int:
	@warning_ignore("integer_division")
	return color_index / SHADES_PER_FAMILY
