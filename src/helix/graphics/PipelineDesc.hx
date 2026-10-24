package helix.graphics;

import helix.graphics.DepthTest;
import helix.graphics.ClipFlip;

/** A vertex attribute a pipeline reads from one of its buffers: its shader's input slot, its float count (1 to 4) and its byte offset in
	each record. */
@:noCompletion
typedef VertexAttribute = {
	final slot:Int;
	final componentCount:Int;
	final offset:Int;
}

/** A vertex buffer a pipeline reads, by its index in a draw's buffers: its record's bytes, whether a record is an instance's (stepped once
	an instance) or a vertex's, and the attributes read from it. A buffer with no attributes is a gap the draw skips. */
@:noCompletion
typedef VertexBuffer = {
	final stride:Int;
	final instanced:Bool;
	final attributes:Array<VertexAttribute>;
}

/** What a pipeline's draws make: triangles, three vertices (or indices) each, or lines, two each. */
@:noCompletion
@:build(helix.macro.EnumNames.build())
enum abstract Primitive(Int) to Int {
	/** Triangles, three vertices (or indices) each. */
	var Triangles = 0;

	/** Lines, two each. */
	var Lines = 1;
}

/** Which faces of a pipeline's triangles aren't drawn. */
@:build(helix.macro.EnumNames.build())
@:noCompletion
enum abstract CullFace(Int) to Int {
	/** Neither: both sides draw. */
	var None = 0;

	/** The back faces, those facing away: a closed surface's far side. */
	var Back = 1;

	/** The front faces: only a surface's far side draws (an outline's shell). */
	var Front = 2;
}

/** A pipeline, everything a draw through it fixes: the program (an IGraphics.createShader handle), its vertex buffers' layout, what it
	draws, whether its draws are indexed (uint32 indices), how its colors meet the target's (blend), the depth test and write, which
	faces are culled and which winding is the front, whether it writes depth alone (a shadow pass's), and its block 0's clip flip.
	Shared code describes the framework's pipelines (Pipelines); an adapter only makes what the description says. */
@:noCompletion
typedef PipelineDesc = {
	final shader:Int;
	final buffers:Array<VertexBuffer>;
	final primitive:Primitive;
	final indexed:Bool;
	final blend:BlendMode;
	final depthTest:DepthTest;
	final depthWrite:Bool;
	final cull:CullFace;
	final clockwise:Bool;
	final depthOnly:Bool;
	final flip:ClipFlip;
}
