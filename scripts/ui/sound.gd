extends AudioStreamPlayer

func tap(kind: int = 0) -> void:
	var rate = 22050
	var duration = .11 if kind == 0 else .24
	var data = PackedByteArray()
	for i in range(int(rate*duration)):
		var time = float(i)/rate
		var frequency = 440.0 if kind == 0 else 660.0
		var wave = sin(time*TAU*frequency)*exp(-time*35.0)
		if kind == 1:
			wave += sin(time*TAU*880.0)*exp(-time*20.0)*.45
		var value = int(wave*5000)
		data.append(value & 255)
		data.append((value >> 8) & 255)
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = rate
	audio.data = data
	stream = audio
	play()
