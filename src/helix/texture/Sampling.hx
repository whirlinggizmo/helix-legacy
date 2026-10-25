package helix.texture;

import helix.texture.Wrap;

/** How a draw samples a texture: its filter (Linear, smooth and through its mipmaps when it has them; or Nearest, sharp, for pixel art) and how
	it wraps along u and v. A small value, passed with each texture a draw uses; adapters keep one sampler for each that is used. */
abstract Sampling(Int) to Int {
	/** Nearest, clamped: pixel art. */
	public static final NEAREST = new Sampling(Nearest);

	/** Linear, clamped: smooth. */
	public static final LINEAR = new Sampling(Linear);

	/** Filtered by filter, wrapping as wrapU and wrapV say. */
	public inline function new(filter:Filter, wrapU:Wrap = Clamp, wrapV:Wrap = Clamp)
		this = (filter : Int) | (wrapU : Int) << 1 | (wrapV : Int) << 3;

	/** How it filters: Linear or Nearest. */
	public var filter(get, never):Filter;

	inline function get_filter():Filter
		return cast this & 1;

	/** How it wraps along u. */
	public var wrapU(get, never):Wrap;

	inline function get_wrapU():Wrap
		return cast(this >> 1) & 3;

	/** How it wraps along v. */
	public var wrapV(get, never):Wrap;

	inline function get_wrapV():Wrap
		return cast(this >> 3) & 3;

	/** The same, filtered by filter. */
	public inline function withFilter(filter:Filter):Sampling
		return new Sampling(filter, get_wrapU(), get_wrapV());

	/** The same wrapping as wrapU and wrapV. */
	public inline function withWrap(wrapU:Wrap, wrapV:Wrap):Sampling
		return new Sampling(get_filter(), wrapU, wrapV);

	/** Every value there is, 0 to COUNT - 1, for an adapter's table of samplers. */
	public static inline var COUNT = 32;
}
