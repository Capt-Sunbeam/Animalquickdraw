extends Control
## Placeholder main menu (skeleton exit state): dev Host/Join buttons wired
## to Net, plus a connected-peers list for the two-instance gate. The real
## menu grows in later slices (lobby: Slice 2; collection: Slice 8; ...).
##
## CI hooks (debug builds): --ci-host hosts and quits 0 when a peer
## connects; --ci-join joins and quits 0 when connected to the host.
## tools/verify_connect.sh drives both as the automated equivalent of the
## Chunk 1 two-instance playtest gate.

const CI_TIMEOUT_SEC: float = 20.0

## Friendly text for Session close reasons (EventBus.session_closed keys).
## "left" is deliberately absent - leaving on purpose needs no toast.
const CLOSE_MESSAGES: Dictionary = {
	"full": "Lobby is full.",
	"in_progress": "That game has already started.",
	"bad_identity": "Couldn't join - identity error.",
	"host_quit": "Host left the game.",
	"connection_failed": "Connection failed.",
	"timeout": "Couldn't reach the host.",
}

@onready var _status_label: Label = %StatusLabel
@onready var _identity_label: Label = %IdentityLabel
@onready var _peer_list: ItemList = %PeerList
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _collection_button: Button = %CollectionButton
@onready var _sandbox_button: Button = %SandboxButton
@onready var _join_dialog: JoinDialog = %JoinDialog
@onready var _toast: Toast = %Toast


func _ready() -> void:
	_identity_label.text = "%s  (%s)" % [Platform.get_display_name(), Platform.get_platform_id().substr(0, 8)]
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_join_dialog.join_requested.connect(_on_join_code_entered)
	_collection_button.pressed.connect(func() -> void: Nav.goto(Routes.COLLECTION))
	_sandbox_button.visible = OS.is_debug_build()
	_sandbox_button.pressed.connect(func() -> void: Nav.goto(Routes.CANVAS_SANDBOX))
	EventBus.peer_connected.connect(_on_peer_connected)
	EventBus.peer_disconnected.connect(_on_peer_disconnected)
	_refresh_peer_list()
	# Session returns players here after closes/rejects; explain why.
	var close_reason: String = Session.consume_close_reason()
	if CLOSE_MESSAGES.has(close_reason):
		_toast.show_error(str(CLOSE_MESSAGES[close_reason]))
	if OS.is_debug_build():
		_handle_ci_args()


func _room_code() -> String:
	return EnetBackend.arg_value(OS.get_cmdline_user_args(), "code", "LOCAL")


func _on_host_pressed() -> void:
	_set_buttons_enabled(false)
	var err: Error = await Session.host_session(_room_code())
	if err != OK:
		_toast.show_error("Couldn't host (%s)." % error_string(err))
		_set_buttons_enabled(true)
	# Success navigates to the lobby; nothing more to do here.


func _on_join_pressed() -> void:
	_join_dialog.open(_room_code())


func _on_join_code_entered(code: String) -> void:
	_set_buttons_enabled(false)
	_status_label.text = "Connecting to %s..." % code
	var err: Error = await Session.join_session(code)
	if err != OK:
		_toast.show_error("Couldn't connect (%s)." % error_string(err))
		_status_label.text = ""
		_set_buttons_enabled(true)
	# Success: Session registers and navigates to the lobby; failures after
	# this point (reject/timeout) reload the menu with a close reason.


func _on_peer_connected(_peer_id: int) -> void:
	_refresh_peer_list()


func _on_peer_disconnected(_peer_id: int) -> void:
	_refresh_peer_list()


func _set_buttons_enabled(enabled: bool) -> void:
	_host_button.disabled = not enabled
	_join_button.disabled = not enabled


func _refresh_peer_list() -> void:
	_peer_list.clear()
	if not Net.has_active_peer():
		return
	_peer_list.add_item("You (peer %d)%s" % [Net.local_peer_id(), " [host]" if Net.is_host() else ""])
	for peer_id: int in multiplayer.get_peers():
		_peer_list.add_item("Peer %d%s" % [peer_id, " [host]" if peer_id == 1 else ""])


# --- CI hooks (automated two-instance connect gate) ---


func _handle_ci_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--ci-host"):
		_run_ci(true)
	elif args.has("--ci-join"):
		_run_ci(false)
	elif args.has("--ci-lobby-host") or args.has("--ci-lobby-join") or args.has("--ci-lobby-join-fail"):
		_run_lobby_ci(args)
	elif args.has("--ci-round-host") or args.has("--ci-round-join"):
		_run_round_ci(args)


## Slice 2 automated gate (tools/verify_lobby.sh): the driver node lives on
## the tree root so it survives the menu -> lobby navigation.
func _run_lobby_ci(args: PackedStringArray) -> void:
	var driver: LobbyCiDriver = LobbyCiDriver.new()
	if args.has("--ci-lobby-host"):
		driver.role = "host"
	elif args.has("--ci-lobby-join"):
		driver.role = "join"
	else:
		driver.role = "join_fail"
	driver.room_code = _room_code()
	driver.expect_players = int(EnetBackend.arg_value(args, "expect", "3"))
	get_tree().root.add_child.call_deferred(driver)


## Slice 3 automated gate (tools/verify_round.sh): full scripted game.
func _run_round_ci(args: PackedStringArray) -> void:
	var driver: RoundCiDriver = RoundCiDriver.new()
	driver.role = "host" if args.has("--ci-round-host") else "join"
	driver.room_code = _room_code()
	get_tree().root.add_child.call_deferred(driver)


func _run_ci(as_host: bool) -> void:
	get_tree().create_timer(CI_TIMEOUT_SEC).timeout.connect(_ci_fail.bind("timeout"))
	if as_host:
		EventBus.peer_connected.connect(func(_peer_id: int) -> void: _ci_pass("host saw a peer connect"))
		var err: Error = await Net.host(_room_code())
		if err != OK:
			_ci_fail("host error %s" % error_string(err))
	else:
		EventBus.peer_connected.connect(func(peer_id: int) -> void:
			if peer_id == 1:
				_ci_pass("client connected to host"))
		EventBus.connection_failed.connect(_ci_fail.bind("connection_failed"))
		var err: Error = await Net.join(_room_code())
		if err != OK:
			_ci_fail("join error %s" % error_string(err))


func _ci_pass(reason: String) -> void:
	print("CI_CONNECT_OK: " + reason)
	# Linger a beat so in-flight ENet handshake ACKs reach the other side
	# before this process exits (a real client stays connected).
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0)


func _ci_fail(reason: String) -> void:
	print("CI_CONNECT_FAIL: " + reason)
	get_tree().quit(1)
