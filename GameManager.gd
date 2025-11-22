extends CanvasLayer

# --- REFERENCIAS (Arrástralas desde el editor si no se conectan solas) ---
@onready var input_a = $InputA     # Asegúrate de que tu LineEdit se llame así
@onready var input_b = $InputB     # Asegúrate de que tu LineEdit se llame así
@onready var label_msg = $Mensaje  # Tu etiqueta para errores/mensajes
@onready var cabezal = get_parent().get_node("Cabezal")
@onready var contenedor_fichas = get_parent().get_node("Fichas") # Nodo padre de las fichas


# --- CONFIGURACIÓN ---
var posicion_inicio_x = 32.0  # Donde empieza la cinta visualmente
var paso_entre_fichas = 1.5   # Debe coincidir con el 'paso' de tu cabezal.gd

func _ready():
	print("hola")
	# Conectamos los botones (Asegúrate de que se llamen así en tu escena)
	# Si tus botones tienen otros nombres, cámbialos aquí o en la escena
	if has_node("BtnSumar"):
		$BtnSumar.pressed.connect(func(): _procesar_operacion("SUMA"))
	
	if has_node("BtnRestar"):
		$BtnRestar.pressed.connect(func(): _procesar_operacion("RESTA"))

	# Escuchamos al cabezal (si agregaste la señal en el paso anterior)
	if cabezal.has_signal("maquina_termino"):
		cabezal.maquina_termino.connect(_on_resultado_maquina)

func _procesar_operacion(tipo_operacion):
	# 1. LIMPIEZA PREVIA
	label_msg.text = ""
	
	# 2. OBTENER TEXTO
	var texto_a = input_a.text
	var texto_b = input_b.text
	
	# 3. CONTROL DE ERRORES (Validaciones)
	
	# A) ¿Están vacíos?
	if texto_a == "" or texto_b == "":
		label_msg.text = "Error: Faltan números."
		label_msg.modulate = Color.RED
		return

	# B) ¿Son números válidos?
	if not texto_a.is_valid_int() or not texto_b.is_valid_int():
		label_msg.text = "Error: Solo se aceptan números enteros."
		label_msg.modulate = Color.RED
		return

	var num_a = int(texto_a)
	var num_b = int(texto_b)

	# C) ¿Son positivos? (La máquina unaria no suele usar negativos)
	if num_a < 0 or num_b < 0:
		label_msg.text = "Error: Usa solo números positivos."
		label_msg.modulate = Color.RED
		return

	# D) Regla especial para RESTA (Evitar resultados negativos simples)
	if tipo_operacion == "RESTA" and num_a < num_b:
		label_msg.text = "Error Lógico: En esta máquina, A debe ser mayor o igual que B."
		label_msg.modulate = Color.YELLOW
		return

	# 4. CONSTRUIR LA CINTA (Traducción Decimal -> Unario)
	# Ejemplo: 3 + 2 se convierte en "111" + "0" + "11"
	var codigo_cinta = ""
	
	# Agregar A
	for i in range(num_a): 
		codigo_cinta += "1"
	
	# Agregar Separador
	codigo_cinta += "0"
	
	# Agregar B
	for i in range(num_b): 
		codigo_cinta += "1"
	
	# Generar visualmente
	_generar_fichas_3d(codigo_cinta)
	
	# 5. INICIAR CABEZAL
	label_msg.text = "Calculando " + tipo_operacion + "..."
	label_msg.modulate = Color.GREEN
	
	# Reseteamos posición del cabezal un poco antes de la primera ficha
	cabezal.position.x = posicion_inicio_x - (paso_entre_fichas * 1.5)
	
	# Llamamos a la función de tu script 'cabezal.gd'
	cabezal.iniciar_maquina(tipo_operacion)

func _generar_fichas_3d(secuencia):
	# Primero borramos las fichas viejas
	for hijo in contenedor_fichas.get_children():
		hijo.queue_free()
	
	# Creamos las nuevas
	for i in range(secuencia.length()):
		var simbolo = secuencia[i]
		var nueva_ficha
		
		# Usamos las escenas que el cabezal ya tiene cargadas (preload)
		# Nota: Para que esto funcione, las variables en cabezal.gd deben ser públicas
		# o cargar las escenas aquí mismo también.
		if simbolo == "1":
			nueva_ficha = load("res://ficha_azul.tscn").instantiate()
		else:
			nueva_ficha = load("res://ficha_roja.tscn").instantiate()
			
		contenedor_fichas.add_child(nueva_ficha)
		
		# Posicionamiento
		var nueva_x = posicion_inicio_x + (i * paso_entre_fichas)
		# Altura Y=3.0 para que caigan con física, o 2.15 si quieres que aparezcan en el suelo
		nueva_ficha.position = Vector3(nueva_x, 3.0, 0) 

func _on_resultado_maquina(mensaje_final):
	label_msg.text = "Fin: " + str(mensaje_final)
	# Opcional: Aquí podrías contar las fichas azules que quedaron para mostrar el número resultante
