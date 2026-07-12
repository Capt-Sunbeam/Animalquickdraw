class_name TestNetBackendAwait
extends GdUnitTestSuite
## Slice 12: the backend coroutine contract (TDD 12 §11 integration). A stub
## backend that genuinely suspends a frame proves Net.host()'s await path
## works with callback-async backends (Steam), and that Net.leave() runs the
## backend teardown on every path.

const STUB_PORT: int = 24990  # clear of EnetBackend.BASE_PORT + instances


class SuspendingStubBackend:
	extends PlatformBackend
	var cleanup_calls: int = 0
	var suspended: bool = false

	func create_host_peer(_room_code: String) -> MultiplayerPeer:
		# Suspend one real frame like a Steam callback would.
		await (Engine.get_main_loop() as SceneTree).process_frame
		suspended = true
		var peer := ENetMultiplayerPeer.new()
		if peer.create_server(STUB_PORT, 2) != OK:
			return null
		return peer

	func leave_cleanup() -> void:
		cleanup_calls += 1


var _original_backend: PlatformBackend


func before_test() -> void:
	_original_backend = Platform.backend


func after_test() -> void:
	Net.leave()
	Platform.backend = _original_backend


func test_net_host_awaits_suspending_backend_and_leave_cleans_up() -> void:
	var stub := SuspendingStubBackend.new()
	Platform.backend = stub
	var err: Error = await Net.host("IGNORED")
	assert_int(err).is_equal(OK)
	assert_bool(stub.suspended).is_true()
	assert_bool(Net.has_active_peer()).is_true()
	Net.leave()
	assert_bool(Net.has_active_peer()).is_false()
	assert_int(stub.cleanup_calls).is_equal(1)
