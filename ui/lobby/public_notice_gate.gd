class_name PublicNoticeGate
## Slice 13: accept-once-per-install (per wording version) gate for the 18+
## unmoderated-play notice (TDD 13 §4/§8). Acceptance is of specific
## wording, not of the concept: Slice 15's legal pass bumps
## GameConstants.PUBLIC_NOTICE_VERSION and everyone re-accepts exactly once.

## Test seam (AvatarStore.path precedent): suites point this at a scratch
## file so gate tests never touch the owner's real profile.json.
static var path: String = "profile.json"


static func is_accepted() -> bool:
	var profile: Dictionary = Save.read_json(path, {})
	return int(profile.get("public_notice_accepted_v", 0)) \
			>= GameConstants.PUBLIC_NOTICE_VERSION


static func mark_accepted() -> void:
	var profile: Dictionary = Save.read_json(path, {})
	profile["public_notice_accepted_v"] = GameConstants.PUBLIC_NOTICE_VERSION
	Save.write_json(path, profile)
