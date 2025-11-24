extends DirectionalLight3D

# Velocidad del sol (grados por segundo)
var velocidad_rotacion = 10.0

func _process(delta):
	# Esto rota la luz en el eje Y (como si pasaran las horas)
	rotation_degrees.y += velocidad_rotacion * delta
	
