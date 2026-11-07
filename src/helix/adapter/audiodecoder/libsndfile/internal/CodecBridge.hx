package helix.adapter.audiodecoder.libsndfile.internal;

/** Built with the app by hxcpp: libsndfile: HELIX_CODEC_LIBRARY when a build names it (tools/native_build.py: the system's on Linux, the pinned release on
	Windows, Homebrew's on macOS); else, on Linux, the system's by soname, so a game built with only -lib helix-legacy links it. */
@:buildXml('<set name="HELIX_ROOT" value="${haxelib:helix}" unless="HELIX_ROOT"/>
<files id="helix-codec-libsndfile" dir="${HELIX_ROOT}/src/helix/adapter">
 <compilerflag value="-I${HELIX_ROOT}/vendor"/><compilerflag value="-I${HELIX_ROOT}/src/helix/adapter/shared"/><compilerflag value="-I${HELIX_ROOT}/src/helix/adapter/audiodecoder/libsndfile/internal"/>
 <compilerflag value="-DNDEBUG" unless="debug"/><compilerflag value="-O2" if="windows" unless="debug"/><compilerflag value="-O3" unless="windows||debug"/><compilerflag value="-D_POSIX_C_SOURCE=200809L" if="linux"/>
 <!-- hxcpp rebuilds an object when its source changes; these make a changed header rebuild it too. -->
 <depend name="${HELIX_ROOT}/vendor/sndfile/sndfile.h"/><depend name="${HELIX_ROOT}/src/helix/adapter/shared/lock.h"/><depend name="${HELIX_ROOT}/src/helix/adapter/audiodecoder/libsndfile/internal/codec.h"/>
 <file name="audiodecoder/libsndfile/internal/codec.c"/>
</files>
<files id="haxe"><compilerflag value="-I${HELIX_ROOT}/vendor"/><compilerflag value="-I${HELIX_ROOT}/src/helix/adapter/shared"/><compilerflag value="-I${HELIX_ROOT}/src/helix/adapter/audiodecoder/libsndfile/internal"/></files>
<target id="haxe">
 <files id="helix-codec-libsndfile"/>
 <lib name="${HELIX_CODEC_LIBRARY}" if="HELIX_CODEC_LIBRARY"/>
 <!-- Linux: the system runtime library by soname when nothing names one (its development symlink may be absent). -->
 <lib name="-l:libsndfile.so.1" if="linux" unless="HELIX_CODEC_LIBRARY"/>
</target>')
@:include("codec.h")
@:noCompletion
extern class CodecBridge {
	@:native("helix_codec_memory") static function codecMemory(data:cpp.RawPointer<cpp.UInt8>, bytes:Int):Int;
	@:native("helix_codec_file") static function codecFile(path:cpp.ConstCharStar):Int;
	@:native("helix_codec_arriving") static function codecArriving(data:cpp.RawPointer<cpp.UInt8>, bytes:Int, length:Int):Int;
	@:native("helix_codec_arrive") static function codecArrive(id:Int, data:cpp.RawPointer<cpp.UInt8>, bytes:Int):Int;
	@:native("helix_codec_position") static function codecPosition(id:Int):Int;
	@:native("helix_codec_frames") static function codecFrames(id:Int):Float;
	@:native("helix_codec_read") static function codecRead(id:Int, data:cpp.RawPointer<cpp.UInt8>, frames:Int):Int;
	@:native("helix_codec_rewind") static function codecRewind(id:Int):Int;
	@:native("helix_codec_close") static function codecClose(id:Int):Void;
	@:native("helix_codec_version") static function codecVersion():cpp.ConstCharStar;
}
