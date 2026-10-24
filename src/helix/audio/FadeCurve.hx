package helix.audio;

/** How a Fade moves between its levels: Decibels, linear in decibels, even to the ear for a fade to or from silence (a bus's and a playback's
	fades); Power, linear in power (the volume's square), so two sounds crossfaded this way, one out and one in, keep their sum's loudness
	through the middle (Audio.crossfade). */
@:build(helix.macro.EnumNames.build())
enum abstract FadeCurve(Int) {
	var Decibels;
	var Power;
}
