# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## Synthesizes the slice's music loop and sound effects into AudioStreamWAV
## resources. Prototype only. No audio files.

const RATE: int = 22050
## The music uses a lower rate: it is built in GDScript and this keeps it quick.
const MUSIC_RATE: int = 16000
const BPM: float = 96.0
const BARS: int = 8
const BEATS_PER_BAR: int = 3

# A short waltz lullaby in F major. Each note: [beat, midi note, length in beats].
const MELODY: Array = [
	[0.0, 72, 1.0], [1.0, 69, 1.0], [2.0, 72, 1.0],
	[3.0, 77, 2.0], [5.0, 74, 1.0],
	[6.0, 74, 1.0], [7.0, 72, 1.0], [8.0, 70, 1.0],
	[9.0, 67, 2.0], [11.0, 72, 1.0],
	[12.0, 69, 1.0], [13.0, 72, 1.0], [14.0, 77, 1.0],
	[15.0, 76, 1.0], [16.0, 74, 0.5], [16.5, 72, 0.5], [17.0, 69, 1.0],
	[18.0, 67, 1.0], [19.0, 70, 1.0], [20.0, 76, 1.0],
	[21.0, 77, 2.0], [23.0, 69, 1.0],
]
# One chord per bar: bass note, then the chord tones for the two soft plucks.
const CHORDS: Array = [
	[41, [57, 60, 65]], [38, [57, 62, 65]], [46, [58, 62, 65]], [48, [55, 60, 64]],
	[41, [57, 60, 65]], [45, [57, 60, 64]], [43, [55, 58, 62]], [41, [57, 60, 65]],
]


## Returns the music loop's samples. Slow in GDScript, so call it off the
## main thread.
static func music_samples() -> PackedFloat32Array:
	var beat: float = 60.0 / BPM
	var total: int = int(float(BARS * BEATS_PER_BAR) * beat * float(MUSIC_RATE))
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(total)
	for n: Array in MELODY:
		_music_box(buf, float(n[0]) * beat, _hz(int(n[1])), 0.26)
	for bar: int in CHORDS.size():
		var chord: Array = CHORDS[bar]
		var start: float = float(bar * BEATS_PER_BAR) * beat
		_bass(buf, start, _hz(int(chord[0])), 0.30)
		for k: int in 2:
			for tone: int in chord[1]:
				_pluck(buf, start + float(k + 1) * beat, _hz(tone), 0.07)
	# Soft echo, wrapped around the loop so it stays seamless.
	var delay: int = int(beat * 0.5 * float(MUSIC_RATE))
	for _pass: int in 2:
		for i: int in total:
			buf[i] += buf[(i - delay + total) % total] * 0.22
	return buf


static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)


static func _music_box(buf: PackedFloat32Array, start: float, f: float, amp: float) -> void:
	var n: int = int(1.1 * float(MUSIC_RATE))
	var s0: int = int(start * float(MUSIC_RATE))
	var total: int = buf.size()
	for i: int in n:
		var t: float = float(i) / float(MUSIC_RATE)
		var env: float = minf(1.0, t * 300.0) * exp(-t * 3.2)
		var w: float = sin(TAU * f * t) + 0.3 * sin(TAU * 2.0 * f * t) * exp(-t * 6.0) + 0.12 * sin(TAU * 3.01 * f * t) * exp(-t * 10.0)
		buf[(s0 + i) % total] += w * env * amp


static func _pluck(buf: PackedFloat32Array, start: float, f: float, amp: float) -> void:
	var n: int = int(0.5 * float(MUSIC_RATE))
	var s0: int = int(start * float(MUSIC_RATE))
	var total: int = buf.size()
	for i: int in n:
		var t: float = float(i) / float(MUSIC_RATE)
		var env: float = minf(1.0, t * 200.0) * exp(-t * 6.0)
		buf[(s0 + i) % total] += (sin(TAU * f * t) + 0.25 * sin(TAU * 2.0 * f * t)) * env * amp


static func _bass(buf: PackedFloat32Array, start: float, f: float, amp: float) -> void:
	var n: int = int(1.7 * float(MUSIC_RATE))
	var s0: int = int(start * float(MUSIC_RATE))
	var total: int = buf.size()
	for i: int in n:
		var t: float = float(i) / float(MUSIC_RATE)
		var env: float = minf(1.0, t * 120.0) * exp(-t * 2.0)
		# The second and third harmonics keep the bass audible on a phone speaker.
		var w: float = sin(TAU * f * t) + 0.6 * sin(TAU * 2.0 * f * t) + 0.25 * sin(TAU * 3.0 * f * t)
		buf[(s0 + i) % total] += w * env * amp


static func to_stream(samples: PackedFloat32Array, loop: bool, rate: int = RATE) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	var peak: float = 0.0
	for v: float in samples:
		peak = maxf(peak, absf(v))
	var gain: float = 0.9 / peak if peak > 0.9 else 1.0
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


# Sound effects. Each returns a short stream.

static func _buffer(seconds: float) -> PackedFloat32Array:
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(int(seconds * float(RATE)))
	return buf


static func _bell(buf: PackedFloat32Array, start: float, f: float, amp: float, decay: float) -> void:
	var s0: int = int(start * float(RATE))
	for i: int in range(s0, buf.size()):
		var t: float = float(i - s0) / float(RATE)
		var env: float = minf(1.0, t * 400.0) * exp(-t * decay)
		buf[i] += (sin(TAU * f * t) + 0.4 * sin(TAU * 2.76 * f * t) * exp(-t * decay)) * env * amp


static func _noise(buf: PackedFloat32Array, start: float, length: float, amp: float, smooth: float, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var s0: int = int(start * float(RATE))
	var n: int = mini(int(length * float(RATE)), buf.size() - s0)
	var last: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		last = lerpf(last, rng.randf_range(-1.0, 1.0), smooth)
		buf[s0 + i] += last * amp * (1.0 - t) * minf(1.0, float(i) / 40.0)


## Tower shot: a short soft "pip" with a falling pitch.
static func shot() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.09)
	var phase: float = 0.0
	for i: int in buf.size():
		var t: float = float(i) / float(RATE)
		phase += TAU * lerpf(1250.0, 650.0, t / 0.09) / float(RATE)
		buf[i] = sin(phase) * exp(-t * 40.0) * 0.5
	return to_stream(buf, false)


## Bakehouse lob: a low round "thoomp".
static func lob() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.22)
	var phase: float = 0.0
	for i: int in buf.size():
		var t: float = float(i) / float(RATE)
		phase += TAU * lerpf(260.0, 110.0, t / 0.22) / float(RATE)
		buf[i] = sin(phase) * exp(-t * 16.0) * 0.8
	_noise(buf, 0.0, 0.06, 0.15, 0.3, 7)
	return to_stream(buf, false)


## Creature puff: a soft breath of noise and two rising chimes.
static func puff() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.5)
	_noise(buf, 0.0, 0.22, 0.45, 0.12, 11)
	_bell(buf, 0.03, 1568.0, 0.16, 11.0)
	_bell(buf, 0.09, 2093.0, 0.13, 10.0)
	return to_stream(buf, false)


## Gate placed: a wooden knock and a warm bell.
static func gate_closed() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.6)
	_noise(buf, 0.0, 0.05, 0.6, 0.5, 3)
	var phase: float = 0.0
	for i: int in int(0.12 * float(RATE)):
		var t: float = float(i) / float(RATE)
		phase += TAU * lerpf(200.0, 120.0, t / 0.12) / float(RATE)
		buf[i] += sin(phase) * exp(-t * 30.0) * 0.6
	_bell(buf, 0.05, 880.0, 0.3, 6.0)
	return to_stream(buf, false)


## Gate lifted: a lighter knock and a lower bell.
static func gate_opened() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.5)
	_noise(buf, 0.0, 0.04, 0.4, 0.5, 5)
	_bell(buf, 0.03, 660.0, 0.25, 8.0)
	return to_stream(buf, false)


## Tower built: a knock and two bell notes going up.
static func build() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.5)
	_noise(buf, 0.0, 0.05, 0.5, 0.45, 9)
	_bell(buf, 0.04, 784.0, 0.22, 9.0)
	_bell(buf, 0.12, 1175.0, 0.2, 9.0)
	return to_stream(buf, false)


## A creature reached the village: two soft falling notes.
static func leak() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.6)
	_bell(buf, 0.0, 523.0, 0.25, 7.0)
	_bell(buf, 0.16, 392.0, 0.25, 6.0)
	return to_stream(buf, false)


## Button tap.
static func click() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _buffer(0.05)
	for i: int in buf.size():
		var t: float = float(i) / float(RATE)
		buf[i] = sin(TAU * 1800.0 * t) * exp(-t * 90.0) * 0.35
	return to_stream(buf, false)
