extends CanvasLayer

# Referencias a los nodos de la escena
@onready var cabezal = get_parent().get_node("Cabezal")
@onready var nodo_fichas = get_parent().get_node("Fichas")
@onready var input_a = $InputA
@onready var input_b = $InputB
@onready var label_msg = $Mensaje

# Configuración de la cinta
var inicio_cinta_x = 32.0 # Ajusta esto a donde empieza tu primer bloque de cinta visual
var paso = 1.5 # La misma distancia que usa tu cabezal

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
		return
		
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
	for hijo in nodo_fichas.get_children():
		hijo.queue_free()

func generar_fichas_visuales(cadena):
	for i in range(cadena.length()):
		var caracter = cadena[i]
		var nueva_ficha
		
		if caracter == "1":
			nueva_ficha = cabezal.ficha_1_scene.instantiate()
		else:
			nueva_ficha = cabezal.ficha_0_scene.instantiate()
			
		nodo_fichas.add_child(nueva_ficha)
		# Posicionamos cada ficha separada por 'paso'
		var pos_x = inicio_cinta_x + (i * paso)
		nueva_ficha.position = Vector3(pos_x, 2.15, 0) # 2.15 es la altura Y de tus fichas

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
