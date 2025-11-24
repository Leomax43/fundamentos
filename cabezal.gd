extends Node3D

signal maquina_termino(mensaje)

# Configuración
@export var velocidad_movimiento: float = 0.5
@onready var raycast = $RayCast3D
@onready var spawn_point = $Marker3D

# Referencia a la CINTA (Necesaria para moverla)
# Asumimos que la Cinta es hermana del Cabezal en el árbol de escena
@onready var cinta = get_parent().get_node("Cinta")

var ficha_1_scene = preload("res://ficha_azul.tscn")
var ficha_0_scene = preload("res://ficha_roja.tscn")

enum Estado { Q0, Q1, Q2, Q3, Q4, HALT }
var estado_actual = Estado.Q0
var modo_operacion = "SUMA"
var ejecutando = false

func _ready():
	# raycast.add_exception(self) # Ya no es necesario si es Node3D
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
		return

	# 1. LEER
	raycast.force_raycast_update()
	var objeto_detectado = raycast.get_collider()
	var simbolo_leido = "_"
	
	if objeto_detectado:
		if objeto_detectado.is_in_group("ficha_1"):
			simbolo_leido = "1"
		elif objeto_detectado.is_in_group("ficha_0"):
			simbolo_leido = "0"
	
	print("Estado: ", Estado.keys()[estado_actual], " | Leído: ", simbolo_leido)
	
	# 2. LÓGICA
	match modo_operacion:
		"SUMA": logica_suma(simbolo_leido, objeto_detectado)
		"RESTA": logica_resta(simbolo_leido, objeto_detectado)

# --- LÓGICA SUMA ---
func logica_suma(simbolo, objeto_fisico):
	match estado_actual:
		Estado.Q0:
			if simbolo == "1": mover("R", Estado.Q0)
			elif simbolo == "0": 
				borrar_ficha(objeto_fisico)
				mover("R", Estado.Q1)
			elif simbolo == "_": finalizar()
		Estado.Q1:
			if simbolo == "1": mover("R", Estado.Q2)
			elif simbolo == "_": finalizar()
		Estado.Q2:
			if simbolo == "1": mover("R", Estado.Q2)
			elif simbolo == "_": 
				escribir_ficha("1")
				mover("L", Estado.Q3)
		Estado.Q3:
			if simbolo == "1": mover("L", Estado.Q3)
			elif simbolo == "_": mover("R", Estado.Q1)
		Estado.HALT: finalizar()

# --- LÓGICA RESTA ---
func logica_resta(simbolo, objeto_fisico):
	match estado_actual:
		Estado.Q0:
			if simbolo == "1": mover("R", Estado.Q0)
			elif simbolo == "0": mover("R", Estado.Q1)
			elif simbolo == "_": finalizar()
		Estado.Q1:
			if simbolo == "1": 
				borrar_ficha(objeto_fisico)
				mover("L", Estado.Q2)
			elif simbolo == "_": mover("L", Estado.Q4)
		Estado.Q2:
			if simbolo == "1": mover("L", Estado.Q2)
			elif simbolo == "_": mover("L", Estado.Q2)
			elif simbolo == "0": mover("L", Estado.Q3)
		Estado.Q3:
			if simbolo == "1": 
				borrar_ficha(objeto_fisico)
				mover("R", Estado.Q0)
			elif simbolo == "0": 
				ejecutando = false
				maquina_termino.emit("Error: Formato incorrecto.")
		Estado.Q4:
			if simbolo == "1": mover("L", Estado.Q4)
			elif simbolo == "_": mover("L", Estado.Q4)
			elif simbolo == "0": 
				borrar_ficha(objeto_fisico)
				finalizar()

# --- ACCIONES FÍSICAS CORREGIDAS ---

func mover(direccion, nuevo_estado):
	estado_actual = nuevo_estado
	var paso = 1.5 
	
	# --- CORRECCIÓN 1: LÓGICA INVERTIDA ---
	# Si el cabezal "va a la derecha" (R), la cinta debe moverse a la IZQUIERDA.
	var vector_mov
	if direccion == "R":
		vector_mov = Vector3(-paso, 0, 0) # Cinta hacia atrás
	else:
		vector_mov = Vector3(paso, 0, 0)  # Cinta hacia adelante
	
	# --- CORRECCIÓN 2: MOVER LA CINTA, NO EL SELF ---
	var tween = create_tween()
	tween.tween_property(cinta, "position", cinta.position + vector_mov, velocidad_movimiento)
	tween.tween_callback(procesar_paso)

func borrar_ficha(objeto):
	if objeto and objeto is RigidBody3D:
		if objeto.is_in_group("ficha_1"): objeto.remove_from_group("ficha_1")
		if objeto.is_in_group("ficha_0"): objeto.remove_from_group("ficha_0")
		
		# --- CORRECCIÓN 3: DESCONGELAR ---
		# Para aplicar impulso, primero debemos quitar el Freeze
		objeto.freeze = false 
		
		var fuerza_servo = Vector3(0, 2, 8) 
		objeto.apply_central_impulse(fuerza_servo)
		objeto.apply_torque(Vector3(randf(), randf(), randf()) * 5.0)
		
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(objeto):
			objeto.queue_free()
			
	elif objeto:
		objeto.queue_free()

func escribir_ficha(tipo):
	var nueva_ficha
	if tipo == "1": nueva_ficha = ficha_1_scene.instantiate()
	else: nueva_ficha = ficha_0_scene.instantiate()
	
	# --- CORRECCIÓN 4: HIJO DE LA CINTA ---
	cinta.add_child(nueva_ficha)
	
	# Importante: Congelarla para que no explote
	nueva_ficha.freeze = true
	
	# --- CORRECCIÓN 5: POSICIÓN GLOBAL ---
	# Usamos global_position para que aparezca exactamente bajo el cabezal,
	# sin importar dónde esté la cinta en ese momento.
	nueva_ficha.global_position = spawn_point.global_position

func finalizar():
	ejecutando = false
	estado_actual = Estado.HALT
	print("PROCESO TERMINADO")
	maquina_termino.emit("Proceso completado exitosamente.")
