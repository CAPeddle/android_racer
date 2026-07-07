extends RefCounted
class_name Sfx

# Procedural sound-effect generator. Builds short AudioStreamWAV clips entirely
# in code so the game ships NO binary audio assets — it stays tiny, ad-free, and
# side-loadable with a single project folder. All clips are mono 16-bit PCM.
#
# These are pure functions (no scene/tree dependencies), which is what keeps
# them unit-testable — see test/unit/test_sfx.gd.

const DEFAULT_MIX_RATE: int = 22050


# A single sine tone. Set looping=true for sustained sounds (engine, siren).
static func tone(freq: float, seconds: float, volume: float = 0.5, mix_rate: int = DEFAULT_MIX_RATE, looping: bool = false) -> AudioStreamWAV:
	var count: int = maxi(int(seconds * mix_rate), 1)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t: float = float(i) / float(mix_rate)
		var value: float = sin(TAU * freq * t) * volume * _envelope(i, count, mix_rate)
		data.encode_s16(i * 2, _to_s16(value))
	return _wrap(data, mix_rate, looping)


# A tone that glides from start_freq to end_freq (rising = happy, falling = ow).
static func sweep(start_freq: float, end_freq: float, seconds: float, volume: float = 0.5, mix_rate: int = DEFAULT_MIX_RATE) -> AudioStreamWAV:
	var count: int = maxi(int(seconds * mix_rate), 1)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t: float = float(i) / float(mix_rate)
		var k: float = float(i) / float(count)
		var freq: float = lerpf(start_freq, end_freq, k)
		var value: float = sin(TAU * freq * t) * volume * _envelope(i, count, mix_rate)
		data.encode_s16(i * 2, _to_s16(value))
	return _wrap(data, mix_rate, false)


# A sequence of equal-length tones — used for pickup/clear/win jingles.
static func jingle(freqs: PackedFloat32Array, note_seconds: float, volume: float = 0.5, mix_rate: int = DEFAULT_MIX_RATE) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	for freq: float in freqs:
		data.append_array(tone(freq, note_seconds, volume, mix_rate).data)
	return _wrap(data, mix_rate, false)


# Linear 5 ms fade-in / 30 ms fade-out so tones don't click at the edges.
static func _envelope(i: int, count: int, mix_rate: int) -> float:
	var attack: int = mini(int(mix_rate * 0.005), count)
	var release: int = mini(int(mix_rate * 0.03), count)
	if attack > 0 and i < attack:
		return float(i) / float(attack)
	if release > 0 and i > count - release:
		return float(count - i) / float(release)
	return 1.0


static func _to_s16(value: float) -> int:
	return int(clampf(value, -1.0, 1.0) * 32767.0)


static func _wrap(data: PackedByteArray, mix_rate: int, looping: bool) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size() / 2
	stream.data = data
	return stream
