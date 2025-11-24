extends Node3D

signal maquina_termino(mensaje)

# === 1. REFERENCIAS NECESARIAS ===
@export var velocidad_movimiento: float = 1
@onready var raycast = $RayCast3D
@onready var spawn_point = $Marker3D
@onready var brazo_servo = $Servo2
@onready var cinta = get_parent().get_node("Cinta")

# Moldes de fichas
var molde_azul = preload("res://ficha_azul.tscn")
var molde_rojo = preload("res://ficha_roja.tscn")

# Estados
enum Estado { Q0, Q1, Q2, Q3, Q4, HALT }
var estado_actual = Estado.Q0
var modo_operacion = "SUMA"
var ejecutando = false

func _ready():
	pass

func iniciar_maquina(modo):
	modo_operacion = modo
	estado_actual = Estado.Q0
	ejecutando = true
	procesar_paso()

func procesar_paso():
	if not ejecutando: return
	if estado_actual == Estado.HALT:
		print("FIN DEL PROCESO")
		ejecutando = false
		maquina_termino.emit("Proceso completado exitosamente.")
		return

	# LEER
	raycast.force_raycast_update()
	var objeto_detectado = raycast.get_collider()
	var simbolo_leido = "_"
	
	if objeto_detectado:
		print("¡GOLPE! Estoy tocando: ", objeto_detectado.name)
		if objeto_detectado.is_in_group("ficha_1"):
			simbolo_leido = "1"
		elif objeto_detectado.is_in_group("ficha_0"):
			simbolo_leido = "0"
	
	print("Estado: ", Estado.keys()[estado_actual], " | Leído: ", simbolo_leido)
	
	# Usamos await aquí también por si acaso las funciones internas lo requieren
	match modo_operacion:
		"SUMA": await logica_suma(simbolo_leido, objeto_detectado)
		"RESTA": await logica_resta(simbolo_leido, objeto_detectado)

# === LÓGICA SUMA CON PAUSAS ===
func logica_suma(simbolo, objeto_fisico):
	match estado_actual:
		Estado.Q0:
			if simbolo == "1": mover("R", Estado.Q0)
			elif simbolo == "0": 
				# ### CAMBIO: Esperamos a que el brazo termine antes de movernos
				await borrar_ficha(objeto_fisico) 
				mover("R", Estado.Q1)
			elif simbolo == "_": finalizar()
			
		Estado.Q1:
			if simbolo == "1": 
				# ### CAMBIO: Pausa para borrar
				await borrar_ficha(objeto_fisico)
				mover("L", Estado.Q2)
			elif simbolo == "_": finalizar()
			
		Estado.Q2:
			if simbolo == "_": 
				# Escribir es instantáneo, pero si quieres pausa aquí también puedes poner un timer
				escribir_ficha("1") 
				# await get_tree().create_timer(0.5).timeout # Opcional: Pausa al escribir
				mover("R", Estado.Q3)
			elif simbolo == "1":
				mover("L", Estado.Q2)

		Estado.Q3:
			if simbolo == "1": mover("R", Estado.Q3)
			elif simbolo == "_": mover("R", Estado.Q1)
			
		Estado.HALT: finalizar()

# === LÓGICA RESTA CON PAUSAS ===
func logica_resta(simbolo, objeto_fisico):
	match estado_actual:
		Estado.Q0:
			if simbolo == "1": mover("R", Estado.Q0)
			elif simbolo == "0": mover("R", Estado.Q1)
			elif simbolo == "_": finalizar()
		Estado.Q1:
			if simbolo == "1": 
				# ### CAMBIO: Pausa para borrar
				await borrar_ficha(objeto_fisico)
				mover("L", Estado.Q2)
			elif simbolo == "_": mover("L", Estado.Q4)
		Estado.Q2:
			if simbolo == "1": mover("L", Estado.Q2)
			elif simbolo == "_": mover("L", Estado.Q2)
			elif simbolo == "0": mover("L", Estado.Q3)
		Estado.Q3:
			if simbolo == "1": 
				# ### CAMBIO: Pausa para borrar
				await borrar_ficha(objeto_fisico)
				mover("R", Estado.Q0)
			elif simbolo == "0": 
				ejecutando = false
				maquina_termino.emit("Error: Formato incorrecto.")
		Estado.Q4:
			if simbolo == "1": mover("L", Estado.Q4)
			elif simbolo == "_": mover("L", Estado.Q4)
			elif simbolo == "0": 
				# ### CAMBIO: Pausa para borrar
				await borrar_ficha(objeto_fisico)
				finalizar()

# === ACCIONES FÍSICAS ===

func mover(direccion, nuevo_estado):
	estado_actual = nuevo_estado
	var paso = 2.5
	
	var vector_mov
	if direccion == "R":
		vector_mov = Vector3(-paso, 0, 0) 
	else:
		vector_mov = Vector3(paso, 0, 0)
	
	var tween = create_tween()
	tween.tween_property(cinta, "position", cinta.position + vector_mov, velocidad_movimiento)
	tween.tween_callback(procesar_paso)

func borrar_ficha(objeto):
	if objeto and objeto is RigidBody3D:
		if objeto.is_in_group("ficha_1"): objeto.remove_from_group("ficha_1")
		if objeto.is_in_group("ficha_0"): objeto.remove_from_group("ficha_0")
		
		# 1. GOLPE DEL BASTÓN
		var tween = create_tween()
		tween.tween_property(brazo_servo, "rotation_degrees:x", -90.0, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(brazo_servo, "rotation_degrees:x", 0.0, 0.2).set_delay(0.05)
		
		# Esperar el contacto visual
		await get_tree().create_timer(0.15).timeout
		
		# 2. FÍSICA
		if is_instance_valid(objeto):
			objeto.collision_mask = 0 
			objeto.freeze = false 
			objeto.global_position.y += 0.2 
			var fuerza_servo = Vector3(0, 2, 10) 
			objeto.apply_central_impulse(fuerza_servo)
			objeto.apply_torque(Vector3(randf(), randf(), randf()) * 10.0)
			
			# 3. ESPERA DRAMÁTICA (Aquí es donde la máquina se queda quieta)
			# Mientras corre este timer, la función 'mover' no se llama porque usamos 'await' arriba.
			await get_tree().create_timer(1.0).timeout
			
			if is_instance_valid(objeto):
				objeto.queue_free()
			
	elif objeto:
		objeto.queue_free()

func escribir_ficha(tipo):
	var nueva_ficha
	if tipo == "1": nueva_ficha = molde_azul.instantiate()
	else: nueva_ficha = molde_rojo.instantiate()
	
	cinta.add_child(nueva_ficha)
	nueva_ficha.freeze = true
	nueva_ficha.global_position = spawn_point.global_position
	
	# Opcional: Pequeña pausa visual al escribir para que no sea instantáneo
	# await get_tree().create_timer(0.2).timeout

func finalizar():
	ejecutando = false
	estado_actual = Estado.HALT
	print("PROCESO TERMINADO")
	maquina_termino.emit("Proceso completado exitosamente.")
