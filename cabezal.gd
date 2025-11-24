extends Node3D

signal maquina_termino(mensaje)
# Configuración
@export var velocidad_movimiento: float = 0.5
@onready var raycast = $RayCast3D
@onready var spawn_point = $Marker3D

#holaaaa, cargamos las fichas desde codigo para que se agregren a la escena
var ficha_1_scene = preload("res://ficha_azul.tscn")
var ficha_0_scene = preload("res://ficha_roja.tscn")

# Estados (Basados en tu PDF de Conceptualización)
enum Estado { Q0, Q1, Q2, Q3, Q4, HALT }
var estado_actual = Estado.Q0
var modo_operacion = "SUMA" # O "RESTA"

# Variable para controlar si la máquina está trabajando
var ejecutando = false

#func _ready():
	#raycast.add_exception(self)

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

	# 1. LEER (Simulación del sensor óptico)
	raycast.force_raycast_update()
	var objeto_detectado = raycast.get_collider()
	var simbolo_leido = "_" # Blanco por defecto
	
	if objeto_detectado:
		# Asumimos que las fichas tienen un grupo o metadato para identificarlas
		if objeto_detectado.is_in_group("ficha_1"):
			simbolo_leido = "1"
		elif objeto_detectado.is_in_group("ficha_0"):
			simbolo_leido = "0"
	
	print("Estado: ", Estado.keys()[estado_actual], " | Leído: ", simbolo_leido)
	
	# 2. LOGICA (Tu Tabla de Transiciones)
	match modo_operacion:
		"SUMA": logica_suma(simbolo_leido, objeto_detectado)
		"RESTA": logica_resta(simbolo_leido, objeto_detectado)

# --- LÓGICA DE SUMA (Según PDF Pág. 5) ---
func logica_suma(simbolo, objeto_fisico):
	match estado_actual:
		Estado.Q0:
			if simbolo == "1": mover("R", Estado.Q0)
			elif simbolo == "0": 
				borrar_ficha(objeto_fisico) # Escribe blanco
				mover("R", Estado.Q1)
			elif simbolo == "_": finalizar()
			
		Estado.Q1:
			if simbolo == "1": mover("R", Estado.Q2) # Busca el final de B
			elif simbolo == "_": finalizar() # B está vacío, terminar
			
		Estado.Q2:
			if simbolo == "1": mover("R", Estado.Q2) # Sigue avanzando
			elif simbolo == "_": 
				escribir_ficha("1") # Escribe 1 al final
				mover("L", Estado.Q3) # Retrocede
				
		Estado.Q3:
			if simbolo == "1": mover("L", Estado.Q3) # Retrocede hasta...
			elif simbolo == "_": mover("R", Estado.Q1) # ...encontrar el hueco, vuelve a Q1
			
		Estado.HALT: finalizar()

# --- LÓGICA DE RESTA (Según PDF Pág. 7) ---
func logica_resta(simbolo, objeto_fisico):
	match estado_actual:
		Estado.Q0: # Buscar separador
			if simbolo == "1": mover("R", Estado.Q0)
			elif simbolo == "0": mover("R", Estado.Q1)
			elif simbolo == "_": finalizar()

		Estado.Q1: # Estamos en B, buscar 1 para borrar
			if simbolo == "1": 
				borrar_ficha(objeto_fisico) # Borra 1 de B
				mover("L", Estado.Q2) # Va a borrar uno de A
			elif simbolo == "_": mover("L", Estado.Q4) # B vacío, ir a limpiar
			
		Estado.Q2: # Retrocediendo hacia A
			if simbolo == "1": mover("L", Estado.Q2) # Ignora 1s de B que queden
			elif simbolo == "_": mover("L", Estado.Q2) # Ignora espacios borrados
			elif simbolo == "0": mover("L", Estado.Q3) # Cruzó el separador
			
		Estado.Q3: # En A, borrar un 1
			if simbolo == "1": 
				borrar_ficha(objeto_fisico) # Borra 1 de A
				mover("R", Estado.Q0) # Vuelve a empezar el ciclo
			elif simbolo == "0": 
				ejecutando = false
				maquina_termino.emit("Error: Cinta vacía o formato incorrecto en resta.")
		Estado.Q4: # Limpieza final (borrar separador)
			if simbolo == "1": mover("L", Estado.Q4)
			elif simbolo == "_": mover("L", Estado.Q4)
			elif simbolo == "0": 
				borrar_ficha(objeto_fisico)
				finalizar()

# --- ACCIONES FÍSICAS ---

func mover(direccion, nuevo_estado):
	estado_actual = nuevo_estado
	var paso = 1.5 # Distancia entre centros de tus cubos de cinta (ajustar a ojo)
	var vector_mov = Vector3(paso, 0, 0) if direccion == "R" else Vector3(-paso, 0, 0)
	
	# Animación suave usando Tween
	var tween = create_tween()
	tween.tween_property(self, "position", position + vector_mov, velocidad_movimiento)
	tween.tween_callback(procesar_paso) # Llamada recursiva al terminar movimiento


func borrar_ficha(objeto):
	if objeto and objeto is RigidBody3D:
		# 1. Desconectar lógica: Ya no es una ficha válida para la máquina
		if objeto.is_in_group("ficha_1"): objeto.remove_from_group("ficha_1")
		if objeto.is_in_group("ficha_0"): objeto.remove_from_group("ficha_0")
		
		# 2. SIMULACIÓN DEL SERVO (Acción Mecánica)
		# En lugar de explotar hacia arriba, la empujamos fuerte hacia el lado (Eje Z)
		# como si un brazo mecánico la golpeara hacia el "depósito de fichas".
		
		# Vector3(X, Y, Z) -> (0 avance, 2 saltito suave, 8 empujón lateral)
		var fuerza_servo = Vector3(0, 2, 8) 
		objeto.apply_central_impulse(fuerza_servo)
		
		# Le damos un poco de rotación aleatoria para realismo
		objeto.apply_torque(Vector3(randf(), randf(), randf()) * 5.0)
		
		# 3. Limpieza: Borrar el nodo después de 3 segundos (cuando ya esté fuera de pantalla)
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(objeto):
			objeto.queue_free()
			
	elif objeto:
		objeto.queue_free() # Si no tiene físicas, borrar directo
		
		
func escribir_ficha(tipo):
	var nueva_ficha
	if tipo == "1": nueva_ficha = ficha_1_scene.instantiate()
	else: nueva_ficha = ficha_0_scene.instantiate()
	
	get_parent().add_child(nueva_ficha) # Añadir a la escena, no al cabezal
	nueva_ficha.position = spawn_point.global_position

func finalizar():
	ejecutando = false
	estado_actual = Estado.HALT
	print("PROCESO TERMINADO")
	maquina_termino.emit("Proceso completado exitosamente.")
