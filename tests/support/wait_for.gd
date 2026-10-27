extends RefCounted
## Waits for a signal of an object that the test will free.
##
## GUT's wait_for_signal() also watches every signal of that object, keeping the object as a
## dictionary key until the test ends. When the object has been freed by then (a hero who fell
## and was replaced, a defeated boss), GUT's cleanup iterating those keys sometimes never ends
## and the whole run freezes. This waits on a direct connection instead.


## True if `sig` fired within `seconds` (physics time).
static func signal_or_timeout(tree: SceneTree, sig: Signal, seconds: float) -> bool:
	var fired := [false]
	var on_fired := func(_a: Variant = null, _b: Variant = null) -> void: fired[0] = true
	sig.connect(on_fired, CONNECT_ONE_SHOT)
	var left := seconds
	while not fired[0] and left > 0.0:
		await tree.physics_frame
		left -= tree.root.get_physics_process_delta_time()
	if not fired[0] and is_instance_valid(sig.get_object()) and sig.is_connected(on_fired):
		sig.disconnect(on_fired)
	return fired[0]
