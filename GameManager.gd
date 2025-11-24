extends CanvasLayer

# === REFERENCIAS ===
@onready var cabezal = get_parent().get_node("Cabezal")
@onready var cinta = get_parent().get_node("Cinta")
@onready var input_a = $InputA
@onready var input_b = $InputB
@onready var label_msg = $Mensaje
@onready var cam_general = get_parent().get_node("Camera3D")
@onready var cam_top = get_parent().get_node("CamaraTop")
@onready var cam_detalle = get_parent().get_node("CamaraDetalle") # Opcional si la creaste
@onready var btn_cam1 = $BtnCam1
@onready var btn_cam2 = $BtnCam2
@onready var btn_cam3 = $BtnCam3 # Opcional
# Distancias y ajustes
var inicio_cinta_x = 32.0
var paso = 2.5

# === NUEVO: VARIABLES PARA MEMORIA ===
var memoria_a = 0
var memoria_b = 0

func _ready():
	$BtnCrearFichas.pressed.connect(crear_fichas)
	$BtnIniciarSuma.pressed.connect(func(): iniciar_maquina("SUMA"))
	$BtnIniciarResta.pressed.connect(func(): iniciar_maquina("RESTA"))
	cabezal.maquina_termino.connect(_on_maquina_termino)
	btn_cam1.pressed.connect(func(): cambiar_camara(cam_general))
	btn_cam2.pressed.connect(func(): cambiar_camara(cam_top))
	btn_cam3.pressed.connect(func(): cambiar_camara(cam_detalle))



func cambiar_camara(nueva_camara):
	if nueva_camara:
		nueva_camara.make_current()
		
	
func crear_fichas():
	var txt_a = input_a.text
	var txt_b = input_b.text

	if not txt_a.is_valid_int() or not txt_b.is_valid_int():
		label_msg.text = "Error: ingresa solo números."
		return

	var num_a = int(txt_a)
	var num_b = int(txt_b)

	if num_a < 0 or num_b < 0:
		label_msg.text = "Error: números positivos."
		return
	if num_a > 9 or num_b > 9:
		label_msg.text = "Error: Máximo 9 por número (Solo un dígito)."
		return
	# === NUEVO: GUARDAMOS LOS VALORES VALIDADOS ===
	memoria_a = num_a
	memoria_b = num_b
	# ==============================================

	limpiar_cinta()

	# Crear cadena unaria
	var cadena = ""
	for i in range(num_a): cadena += "1"
	cadena += "0"
	for i in range(num_b): cadena += "1"

	generar_fichas_visuales(cadena)

	label_msg.text = "Fichas creadas (" + str(num_a) + " y " + str(num_b) + "). Lista para operar."

func iniciar_maquina(modo):
	# === NUEVO: VALIDACIÓN DE RESTA IMPOSIBLE ===
	if modo == "RESTA":
		if memoria_a < memoria_b:
			label_msg.text = "⚠️ ERROR MATEMÁTICO: No se puede restar " + str(memoria_a) + " - " + str(memoria_b) + " (Resultado negativo)."
			return # ¡ABORTAR MISIÓN! No arranca la máquina.
	# ============================================

	# Reposicionar cabezal
	cabezal.position.x = inicio_cinta_x
	cabezal.iniciar_maquina(modo)
	label_msg.text = "Procesando " + modo + "..."


# =====================================================
# FUNCIONES DE SOPORTE
# =====================================================

func limpiar_cinta():
	for hijo in cinta.get_children():
		if hijo.is_in_group("ficha_1") or hijo.is_in_group("ficha_0"):
			hijo.queue_free()

	# Muy importante: reiniciar posición
	cinta.position = Vector3(0, 0, 0)


func generar_fichas_visuales(cadena):
	for i in range(cadena.length()):
		var c = cadena[i]
		var nueva_ficha

		# === CORRECCIÓN AQUÍ ===
		# Usamos los nombres nuevos que definimos en cabezal.gd
		if c == "1":
			nueva_ficha = cabezal.molde_azul.instantiate() 
		else:
			nueva_ficha = cabezal.molde_rojo.instantiate()
		# =======================

		cinta.add_child(nueva_ficha)

		# Congelar para evitar que exploten al instanciar
		if nueva_ficha is RigidBody3D:
			nueva_ficha.freeze = true

		# Posición física
		var px = inicio_cinta_x + (i * paso)
		nueva_ficha.position = Vector3(px, 1.8, 0)

# =====================================================
# FINALIZACIÓN
# =====================================================

func _on_maquina_termino(mensaje):
	label_msg.text = "Fin: " + mensaje + " | Resultado Decimal: " + str(contar_resultado())


func contar_resultado():
	var total = 0
	for hijo in cinta.get_children():
		if hijo.is_in_group("ficha_1") and not hijo.is_queued_for_deletion():
			total += 1
	return total
