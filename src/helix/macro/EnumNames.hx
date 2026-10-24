package helix.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** The build macro on HeliX's enum abstracts over Int: it writes toString(), each value's own name ("Playing", "Space"), so a value
	traced, interpolated or passed to Std.string reads as its name while staying an Int (a GPU's or a platform's code). A value passed as
	Dynamic, or through haxe.Json, is still its number: Haxe calls an abstract's toString only where the value is typed. A value sharing
	another's number reads as the first one's name. */
@:noCompletion
class EnumNames {
	#if macro
	/** The enum abstract's fields with toString added (left alone when it has its own). */
	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		for (field in fields)
			if (field.name == "toString")
				return fields;
		var pos = Context.currentPos();
		var cases:Array<Case> = [], numbers = new Map<String, Bool>(), next = 0;
		for (field in fields)
			switch field.kind {
				case FVar(_, value) if (!field.access.contains(AStatic)):
					// Its number: written, or one past the last (as an enum abstract over Int numbers them).
					var number = next;
					if (value != null)
						switch value.expr {
							case EConst(CInt(v)): number = Std.parseInt(v);
							default: number = -1;
						}
					next = number + 1;
					var key = number < 0 ? field.name : Std.string(number);
					if (numbers.exists(key))
						continue;
					numbers.set(key, true);
					cases.push({values: [macro $i{field.name}], expr: macro $v{field.name}});
				default:
			}
		var body:Expr = {expr: ESwitch(macro abstract, cases, macro Std.string(this)), pos: pos};
		fields.push({
			name: "toString",
			access: [APublic],
			doc: "The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.",
			kind: FFun({
				args: [],
				ret: macro :String,
				expr: macro return $body
			}),
			pos: pos
		});
		return fields;
	}
	#end
}
