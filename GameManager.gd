extends CanvasLayer

# Referencias a los nodos de la escena
@onready var cabezal = get_parent().get_node("Cabezal")
@onready var nodo_fichas = get_parent().get_node("Fichas")
@onready var input_a = $InputA
@onready var input_b = $InputB
@onready var label_msg = $Mensaje
@onready var cinta = get_parent().get_node("Cinta")

# Configuración de la cinta
var inicio_cinta_x = 32.0 # Ajusta esto a donde empieza tu primer bloque de cinta visual
var paso = 2.5 # La misma distancia que usa tu cabezal

func _ready():
	# Conectamos los botones
	$BtnSumar.pressed.connect(func(): configurar_y_arrancar("SUMA"))
	$BtnRestar.pressed.connect(func(): configurar_y_arrancar("RESTA"))
	
	# Conectamos la señal del cabezal (que crearemos en el paso 4)
	cabezal.maquina_termino.connect(_on_maquina_termino)

func configurar_y_arrancar(modo):
	var txt_a = input_a.text
	var txt_b = input_b.text
	
	# 1. CONTROL DE ERRORES
	if not txt_a.is_valid_int() or not txt_b.is_valid_int():
		label_msg.text = "Error: Por favor ingresa solo números enteros."
		
		
	var num_a = int(txt_a)
	var num_b = int(txt_b)
	
	if num_a < 0 or num_b < 0:
		label_msg.text = "Error: Solo números positivos."
		return

	if modo == "RESTA" and num_a < num_b:
		label_msg.text = "Error matemático: El primer número debe ser mayor para restar."
		return

	# 2. PREPARAR LA CINTA (Traducción Decimal -> Unario)
	limpiar_cinta()
	
	# Construimos la cadena: Ej. 2 + 1 -> "11" + "0" + "1"
	# La lógica de tu máquina usa '0' como separador
	var cadena_maquina = ""
	
	# Añadir A
	for i in range(num_a): cadena_maquina += "1"
	
	# Añadir Separador
	cadena_maquina += "0"
	
	# Añadir B
	for i in range(num_b): cadena_maquina += "1"
	
	# Instanciar las fichas en el mundo 3D
	generar_fichas_visuales(cadena_maquina)
	
	# 3. REINICIAR CABEZAL
	# Movemos el cabezal al inicio (un poco antes de la primera ficha)
	cabezal.position.x = inicio_cinta_x - (paso * 1) 
	cabezal.iniciar_maquina(modo)
	label_msg.text = "Calculando " + modo + "..."

func limpiar_cinta():
	# 1. Recorrer todos los hijos de la cinta
	for hijo in cinta.get_children():
		# 2. Preguntar: "¿Eres una ficha?" (Usando los grupos)
		if hijo.is_in_group("ficha_1") or hijo.is_in_group("ficha_0"):
			# Si es ficha, la borramos. Los bloques blancos (MeshInstance) se quedan.
			hijo.queue_free()
	
	# 3. ¡CRÍTICO! Devolver la cinta al inicio (Rebobinar)
	# Si no haces esto, la cinta seguirá desplazada de la operación anterior
	cinta.position = Vector3(0, 0, 0)

func generar_fichas_visuales(cadena):
	for i in range(cadena.length()):
		var caracter = cadena[i]
		var nueva_ficha
		
		if caracter == "1":
			nueva_ficha = cabezal.ficha_1_scene.instantiate()
		else:
			nueva_ficha = cabezal.ficha_0_scene.instantiate()
			
		cinta.add_child(nueva_ficha)
		
		# --- CORRECCIÓN 1: Usar Freeze para evitar que salgan volando ---
		# Si la ficha es un RigidBody, la congelamos para que sea estática
		if nueva_ficha is RigidBody3D:
			nueva_ficha.freeze = true 
			# Ojo: Si luego el cabezal necesita empujarlas, tendrías que 
			# poner nueva_ficha.freeze = false en el momento del empuje.
			# Pero como tu lógica usa queue_free (borrar), ¡esto es perfecto!

		# Posicionamos cada ficha
		var pos_x = inicio_cinta_x + (i * paso)
		
		# --- CORRECCIÓN 2: Altura más baja ---
		# Cambiamos el 3 por 0.6 (ajústalo según el grosor de tu cinta)
		nueva_ficha.position = Vector3(pos_x, 0.6, 0)
		
func _on_maquina_termino(mensaje):
	label_msg.text = "Fin: " + mensaje
	# Opcional: Contar las fichas azules restantes para dar el resultado numérico
	var resultado = contar_resultado()
	label_msg.text += " | Resultado Decimal: " + str(resultado)

func contar_resultado():
	var total = 0
	for ficha in nodo_fichas.get_children():
		# Cuidado: queue_free no es inmediato, verifica si no está 'queued_for_deletion'
		if is_instance_valid(ficha) and not ficha.is_queued_for_deletion():
			if ficha.is_in_group("ficha_1"):
				total += 1
	return total
