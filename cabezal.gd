extends Node3D

signal maquina_termino(mensaje)

# === REFERENCIAS ===
@export var velocidad_movimiento: float = 1.0
@onready var raycast = $RayCast3D
@onready var spawn_point = $Marker3D
@onready var brazo_servo = $Servo2

# Referencia a la cinta (para moverla y pegarle las fichas)
@onready var cinta = get_parent().get_node("Cinta")

# Referencia al punto de salida de la caja (Ruta proporcionada por ti)
@onready var punto_caja = get_parent().get_node("Cabezal/CajaFichas/PuntoCaja")

# Moldes
var molde_azul = preload("res://ficha_azul.tscn")
var molde_rojo = preload("res://ficha_roja.tscn")

# Estados
enum Estado { Q0, Q1, Q1_BACK, Q2, Q3, Q3_BACK, Q3_RETURN, Q4, HALT }
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

	# 1. LEER
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
	
	# 2. LÓGICA CON ESPERAS (AWAIT)
	match modo_operacion:
		"SUMA": await logica_suma(simbolo_leido, objeto_detectado)
		"RESTA": await logica_resta(simbolo_leido, objeto_detectado)

# === LÓGICA SUMA ===
func logica_suma(simbolo, objeto_fisico):
	match estado_actual:
		Estado.Q0:
			if simbolo == "1": mover("R", Estado.Q0)
			elif simbolo == "0": 
				await borrar_ficha(objeto_fisico) # Pausa para borrar
				mover("R", Estado.Q1)
			elif simbolo == "_": finalizar()
			
		Estado.Q1:
			if simbolo == "1": 
				await borrar_ficha(objeto_fisico) # Pausa para borrar
				mover("L", Estado.Q2)
			elif simbolo == "_": finalizar()
			
		Estado.Q2:
			if simbolo == "_": 
				await escribir_ficha("1") # Pausa para escribir (viaje desde la caja)
				mover("R", Estado.Q3)
			elif simbolo == "1":
				mover("L", Estado.Q2)

		Estado.Q3:
			if simbolo == "1": mover("R", Estado.Q3)
			elif simbolo == "_": mover("R", Estado.Q1)
			
		Estado.HALT: finalizar()

# === LÓGICA RESTA SIMÉTRICA (Borrar desde los extremos) ===
# === LÓGICA RESTA FINAL (Con freno de seguridad) ===
func logica_resta(simbolo, objeto_fisico):
	match estado_actual:
		# Q0: Buscar el separador 0
		Estado.Q0:
			if simbolo == "1": mover("R", Estado.Q0)
			elif simbolo == "0": mover("R", Estado.Q1)
			elif simbolo == "_": finalizar()
			
		# Q1: Ir al final de B
		Estado.Q1:
			if simbolo == "1": mover("R", Estado.Q1)
			elif simbolo == "_": mover("L", Estado.Q1_BACK) # Fin de B
			elif simbolo == "0": mover("L", Estado.Q4) # B vacío
			
		# Q1_BACK: Borrar en B (Derecha)
		Estado.Q1_BACK:
			if simbolo == "1":
				await borrar_ficha(objeto_fisico)
				mover("L", Estado.Q2)
			elif simbolo == "0":
				# OPTIMIZACIÓN: Si al volver estamos sobre el 0, es que terminamos.
				# Lo borramos aquí mismo y nos ahorramos ir a Q4.
				await borrar_ficha(objeto_fisico)
				finalizar()
				
		# Q2: Volver al separador 0
		Estado.Q2:
			if simbolo == "1": mover("L", Estado.Q2)
			elif simbolo == "_": mover("L", Estado.Q2)
			elif simbolo == "0": mover("L", Estado.Q3) # Cruzar a A
			
		# Q3: Ir al extremo izquierdo de A
		Estado.Q3:
			if simbolo == "1": mover("L", Estado.Q3)
			elif simbolo == "_": mover("R", Estado.Q3_BACK)
			elif simbolo == "0": 
				ejecutando = false
				maquina_termino.emit("Error: A < B.")

		# Q3_BACK: Borrar en A (Izquierda)
		Estado.Q3_BACK:
			if simbolo == "1": 
				await borrar_ficha(objeto_fisico)
				mover("R", Estado.Q3_RETURN)
			elif simbolo == "0": 
				mover("R", Estado.Q1) 
			elif simbolo == "_":
				mover("R", Estado.Q3_BACK)

		# Q3_RETURN: Volver al separador 0
		Estado.Q3_RETURN:
			if simbolo == "1": mover("R", Estado.Q3_RETURN)
			elif simbolo == "_": mover("R", Estado.Q3_RETURN)
			elif simbolo == "0": mover("R", Estado.Q1)

		# Q4: Limpieza final (La red de seguridad)
		Estado.Q4:
			if simbolo == "1": mover("L", Estado.Q4) # Si hay 1s, seguimos buscando el 0
			
			# === AQUÍ ESTÁ TU SOLUCIÓN ===
			elif simbolo == "_": 
				print("Aviso: Se alcanzó el vacío en limpieza. Deteniendo.")
				finalizar() 
			# =============================
			
			elif simbolo == "0": 
				await borrar_ficha(objeto_fisico)
				finalizar()
				
func mover(direccion, nuevo_estado):
	estado_actual = nuevo_estado
	var paso = 2.5 # Debe coincidir con GameManager
	
	var vector_mov
	if direccion == "R":
		vector_mov = Vector3(-paso, 0, 0) # Cinta a la izquierda
	else:
		vector_mov = Vector3(paso, 0, 0)  # Cinta a la derecha
	
	var tween = create_tween()
	tween.tween_property(cinta, "position", cinta.position + vector_mov, velocidad_movimiento)
	tween.tween_callback(procesar_paso)

func borrar_ficha(objeto):
	if objeto and objeto is RigidBody3D:
		if objeto.is_in_group("ficha_1"): objeto.remove_from_group("ficha_1")
		if objeto.is_in_group("ficha_0"): objeto.remove_from_group("ficha_0")
		
		# 1. ANIMACIÓN SERVO (BASTÓN)
		var tween = create_tween()
		tween.tween_property(brazo_servo, "rotation_degrees:x", -90.0, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(brazo_servo, "rotation_degrees:x", 45.0, 0.2).set_delay(0.05)
		
		# Esperar el golpe visual
		await get_tree().create_timer(0.15).timeout
		
		# 2. FÍSICA
		if is_instance_valid(objeto):
			objeto.collision_mask = 0 
			objeto.freeze = false 
			objeto.global_position.y += 0.2 
			var fuerza_servo = Vector3(0, 2, 10) # Ajustar fuerza según necesidad
			objeto.apply_central_impulse(fuerza_servo)
			objeto.apply_torque(Vector3(randf(), randf(), randf()) * 10.0)
			
			# 3. ESPERA (La máquina se detiene mientras la ficha cae)
			await get_tree().create_timer(1.0).timeout
			
			if is_instance_valid(objeto):
				objeto.queue_free()
			
	elif objeto:
		objeto.queue_free()

func escribir_ficha(tipo):
	var nueva_ficha
	if tipo == "1": nueva_ficha = molde_azul.instantiate()
	else: nueva_ficha = molde_rojo.instantiate()
	
	# Añadir a la cinta
	cinta.add_child(nueva_ficha)
	nueva_ficha.freeze = true
	
	# === ANIMACIÓN DE VIAJE DESDE LA CAJA ===
	
	# 1. Inicio: En la caja
	nueva_ficha.global_position = punto_caja.global_position
	
	# 2. Destino: Bajo el cabezal (Forzando altura correcta)
	var destino = spawn_point.global_position
	destino.y = 1.8 
	
	# 3. Viaje suave
	var tween = create_tween()
	tween.tween_property(nueva_ficha, "global_position", destino, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 4. Esperar a que llegue antes de seguir
	await tween.finished
	
	# Pequeña pausa extra para asentarse
	await get_tree().create_timer(0.1).timeout

func finalizar():
	ejecutando = false
	estado_actual = Estado.HALT
	print("PROCESO TERMINADO")
	maquina_termino.emit("Proceso completado exitosamente.")
