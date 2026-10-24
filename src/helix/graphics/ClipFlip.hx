package helix.graphics;

/** What uniform block 0 holds, so an adapter whose render targets are stored upside down (GL's bottom-left origin) can draw a target the
	right way up: nothing it touches, a clip scale it writes (x 1, y -1 in such a pass, else 1), or a view-projection matrix (column-major,
	its first 64 bytes) whose y row it negates in such a pass. */
@:build(helix.macro.EnumNames.build())
enum abstract ClipFlip(Int) to Int {
	/** Block 0 isn't touched (or there is none). */
	var None = 0;

	/** Block 0 is a vec4 clip scale the adapter writes. */
	var ClipScale = 1;

	/** Block 0 starts with a view-projection matrix whose y row the adapter negates. */
	var ViewProjection = 2;
}
