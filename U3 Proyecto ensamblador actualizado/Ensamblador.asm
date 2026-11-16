; =====================================================================
; PROYECTO: Sistema de Ventas e Inventario para Papeleria (VERSION REFACTORIZADA)
; EQUIPO: GONZALEZ BELTRAN JOSE DAVID
;         CARRERA ENRIQUEZ LUZ ZUSZETH
; MATERIA: LENGUAJES ENSAMBLADOR
; DOCENTE: ING. MEDINA JOSE LUIS

INCLUDE Irvine32.inc

; ---------------------------------------------------------------------
; Constantes
; ---------------------------------------------------------------------
MAX_PRODUCTOS   EQU 10
TAM_PRODUCTO    EQU 42              ; 8 + 26 + 4 + 4
TAM_INVENTARIO  EQU 420             ; TAM_PRODUCTO * MAX_PRODUCTOS
MAX_EXISTENCIA  EQU 100
ALERTA_MIN      EQU 5               ; alerta si existencia <= 5
MAYOREO_MIN     EQU 10              ; descuento desde 10 piezas
PRECIO_MIN      EQU 1               ; 0.01 en centavos
PRECIO_MAX      EQU 999999          ; 9999.99 en centavos
LONG_CODIGO     EQU 7
BUF_LECTURA     EQU 29              ; maximo de caracteres para ReadString

; =====================================================================
; MACROS
; =====================================================================

; Imprime una cadena terminada en 0.  Modifica: EDX.
MostrarMsg MACRO texto
    mov edx, OFFSET texto
    call WriteString
ENDM

; Imprime 'texto' solo si valor <= limite (sin signo).  Modifica: EDX, flags.
MostrarMsgSiMenorIgual MACRO valor, limite, texto
    LOCAL saltar
    cmp valor, limite
    ja saltar
    MostrarMsg texto
saltar:
ENDM

; Imprime 'texto' solo si la variable/registro es distinto de 0.
MostrarMsgSiNoCero MACRO variable, texto
    LOCAL saltar
    cmp variable, 0
    je saltar
    MostrarMsg texto
saltar:
ENDM

; Salta a 'fuera' si minimo > valor o valor > maximo (sin signo).
EnRango MACRO valor, minimo, maximo, fuera
    cmp valor, minimo
    jb fuera
    cmp valor, maximo
    ja fuera
ENDM

; Salta a 'noEs' si el caracter en 'car' no esta entre '0' y '9'.
EsDigito MACRO car, noEs
    EnRango car, '0', '9', noEs
ENDM

; acum = acum*10 + (dig - '0').  dig es un registro de 32 bits con el ASCII.
AgregaDigito MACRO acum, dig
    sub dig, '0'
    imul acum, acum, 10
    add acum, dig
ENDM

; Copia 'cantidad' bytes de 'origen' hacia donde apunta EDI (EDI avanza).
CopiarSeg MACRO origen, cantidad
    mov esi, OFFSET origen
    mov ecx, cantidad
    rep movsb
ENDM

; Copia 'cantidad' bytes de 'origen' a 'destino'.  Modifica: ESI, EDI, ECX.
CopiarBytes MACRO destino, origen, cantidad
    mov edi, OFFSET destino
    CopiarSeg origen, cantidad
ENDM

; Imprime "etiqueta valor" + salto de linea (valor: registro o variable).
ImprimirDato MACRO texto, valor
    MostrarMsg texto
    mov eax, valor
    call ImprimirEntero
    call Crlf
ENDM

; Igual que ImprimirDato pero el valor (centavos) se muestra como "$X.XX MXN".
ImprimirDatoMXN MACRO texto, valor
    MostrarMsg texto
    mov eax, valor
    call MostrarPrecioMXN
    call Crlf
ENDM

; Si EAX = numero, llama al procedimiento y regresa a 'volver'.
OpcionLlama MACRO numero, procedimiento, volver
    LOCAL siguiente
    cmp eax, numero
    jne siguiente
    call procedimiento
    jmp volver
siguiente:
ENDM

; Escribe 'cantidad' bytes de 'dato' al archivo abierto; error -> 'malo'.
EscribirArchivo MACRO dato, cantidad, malo
    mov eax, fileHandle
    mov edx, OFFSET dato
    mov ecx, cantidad
    call WriteToFile
    cmp eax, cantidad
    jne malo
ENDM

; Lee 'cantidad' bytes del archivo abierto hacia 'dato'; error -> 'malo'.
LeerArchivo MACRO dato, cantidad, malo
    mov eax, fileHandle
    mov edx, OFFSET dato
    mov ecx, cantidad
    call ReadFromFile
    jc malo
    cmp eax, cantidad
    jne malo
ENDM

CerrarArchivo MACRO
    mov eax, fileHandle
    call CloseFile
ENDM

.data
    Inventario     BYTE 420 DUP(0)
    TotalProductos DWORD 0
    IngresosSesion DWORD 0
    ptrProducto    DWORD 0
    totalVenta     DWORD 0
    aplicoDesc     DWORD 0          ; 1 si la venta tuvo descuento de mayoreo

    ; Temporales de captura (el registro se escribe solo si todo es valido)
    codTmp         BYTE 8 DUP(0)
    nomTmp         BYTE 26 DUP(0)
    precioTmp      DWORD 0
    existTmp       DWORD 0

    ; Temporales para cargar archivo
    tmpTotal       DWORD 0
    tmpInv         BYTE 420 DUP(0)

    NombreArchivo  BYTE "inventario.dat", 0
    fileHandle     HANDLE ?
    errorArchivo   BYTE "Error: archivo ausente, danado o invalido. Se conserva el catalogo actual.", 0Dh, 0Ah, 0
    errorGuardar   BYTE "Error al guardar el archivo de disco.", 0Dh, 0Ah, 0
    msgCargado     BYTE "Catalogo cargado exitosamente desde disco.", 0Dh, 0Ah, 0
    msgGuardado    BYTE "Catalogo guardado exitosamente en disco.", 0Dh, 0Ah, 0
    msgSinArchivo  BYTE "No se encontro inventario.dat (catalogo vacio).", 0Dh, 0Ah, 0
    msgSubArchivo  BYTE 0Dh, 0Ah, "1. Guardar inventario", 0Dh, 0Ah,
                        "2. Cargar inventario", 0Dh, 0Ah,
                        "3. Volver al menu principal", 0Dh, 0Ah,
                        "Opcion: ", 0
    msgCancelado   BYTE "Operacion cancelada.", 0Dh, 0Ah, 0

    msgTitulo      BYTE "=== SISTEMA DE INVENTARIO - PAPELERIA ===", 0
    msgMenu        BYTE 0Dh, 0Ah, "1. Registrar producto", 0Dh, 0Ah,
                        "2. Consultar inventario y buscar", 0Dh, 0Ah,
                        "3. Recibir mercancia", 0Dh, 0Ah,
                        "4. Vender producto (con mayoreo)", 0Dh, 0Ah,
                        "5. Mostrar resumen e ingresos", 0Dh, 0Ah,
                        "6. Guardar y Cargar archivo", 0Dh, 0Ah,
                        "7. Salir", 0Dh, 0Ah,
                        "Seleccione una opcion: ", 0
    msgOpcionInv   BYTE "Opcion invalida. Intente de nuevo.", 0Dh, 0Ah, 0

    msgCodIng      BYTE "Ingrese codigo (ENTER para cancelar): ", 0
    msgNomIng      BYTE "Ingrese nombre (1 a 25 caracteres): ", 0
    msgPreIng      BYTE "Ingrese precio en pesos (0.01 a 9999.99, Ej. 18.50): ", 0
    msgExiIng      BYTE "Ingrese existencia inicial (0-100): ", 0
    msgErrCap      BYTE "Error: Capacidad maxima alcanzada (10).", 0Dh, 0Ah, 0
    msgErrDup      BYTE "Error: El codigo ya existe en el sistema.", 0Dh, 0Ah, 0
    msgErrCod      BYTE "Error: codigo invalido. Use 3 letras mayusculas, guion y 3 digitos.", 0Dh, 0Ah, 0
    msgErrNom      BYTE "Error: el nombre debe tener de 1 a 25 caracteres.", 0Dh, 0Ah, 0
    msgErrPre      BYTE "Error: precio invalido (0.01 a 9999.99, sin simbolos).", 0Dh, 0Ah, 0
    msgErrExi      BYTE "Error: existencia invalida (entero de 0 a 100).", 0Dh, 0Ah, 0
    msgExitoAlta   BYTE "Producto registrado exitosamente.", 0Dh, 0Ah, 0

    msgCantRec     BYTE "Unidades a recibir (ENTER para cancelar): ", 0
    msgExitoRec    BYTE "Mercancia recibida. Existencia actualizada.", 0Dh, 0Ah, 0
    msgErrExceso   BYTE "Error: la existencia no puede pasar de 100 unidades.", 0Dh, 0Ah, 0

    msgCantVenta   BYTE "Cantidad a vender (ENTER para cancelar): ", 0
    msgVentaOk     BYTE "Venta realizada correctamente.", 0Dh, 0Ah, 0
    msgDescuento   BYTE "Se aplico 10% de descuento por mayoreo (10 o mas piezas).", 0Dh, 0Ah, 0
    msgTotalVenta  BYTE "Total cobrado: ", 0
    msgSinStock    BYTE "Error: existencia insuficiente.", 0Dh, 0Ah, 0
    msgErrCant     BYTE "Error: cantidad invalida (entero mayor que cero).", 0Dh, 0Ah, 0
    msgDesborde    BYTE "Error: desbordamiento en el calculo. Venta rechazada.", 0Dh, 0Ah, 0

    msgListHead    BYTE 0Dh, 0Ah, "--- CATALOGO DE PAPELERIA ---", 0Dh, 0Ah, 0
    msgResHead     BYTE 0Dh, 0Ah, "--- RESUMEN ---", 0Dh, 0Ah, 0
    msgCodProd     BYTE "Ingrese codigo del producto (ENTER para cancelar): ", 0
    msgBusqOpc     BYTE "Codigo a buscar (ENTER para omitir): ", 0
    msgNoEncontr   BYTE "Producto no encontrado.", 0Dh, 0Ah, 0
    msgInvVacio    BYTE "El inventario esta vacio.", 0Dh, 0Ah, 0
    msgAlertaMin   BYTE " [ALERTA: Existencia baja <= 5]", 0
    msgSepPrecio   BYTE " | Precio: ", 0
    msgSepExist    BYTE " | Existencia: ", 0

    msgResProd     BYTE "Productos registrados: ", 0
    msgResUnid     BYTE "Unidades disponibles: ", 0
    msgResValor    BYTE "Valor total del inventario: ", 0
    msgResIngr     BYTE "Ingresos de la sesion: ", 0

    strDolar       BYTE "$", 0
    strPunto       BYTE ".", 0
    strCero        BYTE "0", 0
    strEspacio     BYTE " ", 0
    etiquetaMXN    BYTE " MXN", 0

    bufferIn       BYTE 30 DUP(0)
    bufNum         BYTE 12 DUP(0)

.code
; =====================================================================
; PROGRAMA PRINCIPAL
; =====================================================================
main PROC
    cld
    call ClrScr
    call CargarInventario

MenuPrincipal:
    call Crlf
    MostrarMsg msgTitulo
    mov edx, OFFSET msgMenu
    call LeerEntero                 ; EAX = opcion, CF=1 si no es numero
    jc OpcionInvalida

    OpcionLlama 1, RegistrarProducto,  MenuPrincipal
    OpcionLlama 2, ConsultarInventario, MenuPrincipal
    OpcionLlama 3, RecibirMercancia,   MenuPrincipal
    OpcionLlama 4, VenderProducto,     MenuPrincipal
    OpcionLlama 5, MostrarResumen,     MenuPrincipal
    cmp eax, 6
    je OpArchivoMenu
    cmp eax, 7
    je SalirPrograma

OpcionInvalida:
    MostrarMsg msgOpcionInv
    jmp MenuPrincipal

OpArchivoMenu:                      ; Submenu: 1 = guardar, 2 = cargar
    mov edx, OFFSET msgSubArchivo
    call LeerEntero
    jc SubInvalida
    OpcionLlama 1, GuardarInventario, MenuPrincipal
    OpcionLlama 2, CargarInventario,  MenuPrincipal
    cmp eax, 3
    je MenuPrincipal
SubInvalida:                        ; opcion invalida: vuelve a pedir el submenu
    MostrarMsg msgOpcionInv
    jmp OpArchivoMenu

SalirPrograma:
    exit
main ENDP

; =====================================================================
; 1. REGISTRAR PRODUCTO
; Cada dato invalido muestra su error y se vuelve a pedir ese mismo dato.
; ENTER vacio en el codigo cancela.
; Recibe: nada (captura por teclado).  Devuelve: nada.
; Modifica: TotalProductos, Inventario, temporales *Tmp.
; Conserva: todos los registros (USES).
; =====================================================================
RegistrarProducto PROC USES eax ecx edx esi edi
    cmp TotalProductos, MAX_PRODUCTOS
    jae L_CapLlena

    ; ---- Codigo (ENTER vacio cancela; si es invalido o repetido, se vuelve a pedir) ----
L_PedirCod:
    mov edx, OFFSET msgCodIng
    call LeerTexto
    cmp eax, 0
    je L_Cancelado
    call ValidarCapturaCodigo
    jc L_ErrCod
    call BuscarProductoPorCodigo
    cmp esi, 0
    jne L_Duplicado
    CopiarBytes codTmp, bufferIn, 8

    ; ---- Nombre (1 a 25) ----
L_PedirNom:
    mov edx, OFFSET msgNomIng
    call LeerTexto
    EnRango eax, 1, 25, L_ErrNom
    CopiarBytes nomTmp, bufferIn, 26

    ; ---- Precio ----
L_PedirPre:
    mov edx, OFFSET msgPreIng
    call LeerTexto
    call StringACentavos
    jc L_ErrPre
    mov precioTmp, eax

    ; ---- Existencia ----
L_PedirExi:
    mov edx, OFFSET msgExiIng
    call LeerEntero
    jc L_ErrExi
    cmp eax, MAX_EXISTENCIA
    ja L_ErrExi
    mov existTmp, eax

    ; ---- Todo valido: escribir el registro ----
    call ObtenerPunteroLibre        ; ESI = registro libre
    call EscribirRegistroTmp
    inc TotalProductos
    MostrarMsg msgExitoAlta
    ret

L_CapLlena:                         ; catalogo lleno: no hay nada que reintentar
    MostrarMsg msgErrCap
    ret
L_Cancelado:
    MostrarMsg msgCancelado
    ret
; Cada error muestra su mensaje y vuelve a pedir SOLO ese dato
L_Duplicado:
    MostrarMsg msgErrDup
    jmp L_PedirCod
L_ErrCod:
    MostrarMsg msgErrCod
    jmp L_PedirCod
L_ErrNom:
    MostrarMsg msgErrNom
    jmp L_PedirNom
L_ErrPre:
    MostrarMsg msgErrPre
    jmp L_PedirPre
L_ErrExi:
    MostrarMsg msgErrExi
    jmp L_PedirExi
RegistrarProducto ENDP

; Copia codTmp, nomTmp, precioTmp y existTmp al registro apuntado por ESI.
; Recibe: ESI = direccion del registro destino.  Devuelve: nada.
; Modifica: memoria del registro.  Conserva: todos (USES).
EscribirRegistroTmp PROC USES eax ecx esi edi
    mov edi, esi
    CopiarSeg codTmp, 8             ; offset 0
    CopiarSeg nomTmp, 26            ; offset 8
    mov eax, precioTmp
    stosd                           ; offset 34
    mov eax, existTmp
    stosd                           ; offset 38
    ret
EscribirRegistroTmp ENDP

; =====================================================================
; 2. CONSULTAR INVENTARIO Y BUSQUEDA
; Recibe: nada.  Devuelve: nada.  Conserva: todos los registros (USES).
; =====================================================================
ConsultarInventario PROC USES eax ecx edx esi
    MostrarMsg msgListHead
    mov ecx, TotalProductos
    cmp ecx, 0
    je L_Vacio

    mov esi, OFFSET Inventario
L_LoopList:
    call ImprimirProducto
    add esi, TAM_PRODUCTO
    loop L_LoopList

    call Crlf
L_Buscar:
    mov edx, OFFSET msgBusqOpc
    call LeerTexto
    cmp eax, 0
    je L_FinCons                    ; solo ENTER: termina la busqueda
    call ValidarCapturaCodigo
    jc L_BusqMal
    call BuscarProductoPorCodigo
    cmp esi, 0
    je L_BusqNo
    call ImprimirProducto
    jmp L_FinCons

L_BusqMal:                          ; codigo invalido: vuelve a pedir
    MostrarMsg msgErrCod
    jmp L_Buscar
L_BusqNo:                           ; no existe: vuelve a pedir
    MostrarMsg msgNoEncontr
    jmp L_Buscar
L_Vacio:
    MostrarMsg msgInvVacio
L_FinCons:
    ret
ConsultarInventario ENDP

; Imprime: CODIGO Nombre | Precio: $X.XX MXN | Existencia: N [alerta]
; Recibe: ESI = registro.  Devuelve: nada.  Conserva: todos (USES).
ImprimirProducto PROC USES eax edx
    mov edx, esi
    call WriteString                ; codigo
    MostrarMsg strEspacio
    lea edx, [esi + 8]
    call WriteString                ; nombre
    MostrarMsg msgSepPrecio
    mov eax, [esi + 34]
    call MostrarPrecioMXN
    MostrarMsg msgSepExist
    mov eax, [esi + 38]
    call ImprimirEntero             ; conserva EAX
    MostrarMsgSiMenorIgual eax, ALERTA_MIN, msgAlertaMin
    call Crlf
    ret
ImprimirProducto ENDP

; =====================================================================
; 3. RECIBIR MERCANCIA (tope: 100 unidades)
; Recibe: nada.  Devuelve: nada.
; Modifica: existencia del producto elegido.  Conserva: registros (USES).
; =====================================================================
RecibirMercancia PROC USES eax edx esi
    call PedirProducto              ; ptrProducto = producto; CF=1 si cancelo
    jc L_FinRec
L_PedirCantRec:
    mov edx, OFFSET msgCantRec
    call PedirCantidad              ; EAX = cantidad > 0; CF=1 si cancelo
    jc L_FinRec
    mov esi, ptrProducto
    cmp eax, MAX_EXISTENCIA
    ja L_ExcedeMax
    add eax, [esi + 38]
    cmp eax, MAX_EXISTENCIA
    ja L_ExcedeMax
    mov [esi + 38], eax
    MostrarMsg msgExitoRec
L_FinRec:
    ret

L_ExcedeMax:                        ; vuelve a pedir la cantidad
    MostrarMsg msgErrExceso
    jmp L_PedirCantRec
RecibirMercancia ENDP

; =====================================================================
; 4. VENDER PRODUCTO (10% de descuento desde 10 piezas)
; Recibe: nada.  Devuelve: nada.
; Modifica: IngresosSesion, totalVenta, aplicoDesc, existencia del producto
; (solo si la venta es aceptada).  Conserva: registros (USES).
; =====================================================================
VenderProducto PROC USES eax ecx edx esi
    call PedirProducto              ; ptrProducto = producto; CF=1 si cancelo
    jc L_FinVenta
L_PedirCantVta:
    mov edx, OFFSET msgCantVenta
    call PedirCantidad              ; EAX = cantidad > 0; CF=1 si cancelo
    jc L_FinVenta
    mov esi, ptrProducto
    mov ecx, eax                    ; ECX = cantidad
    cmp ecx, [esi + 38]
    ja L_SinStock

    call CalcularImporte            ; EAX = importe, CF=1 si desborda
    jc L_Desborde
    mov totalVenta, eax
    add eax, IngresosSesion
    jc L_Desborde                   ; aun no se ha modificado nada

    mov IngresosSesion, eax         ; venta aceptada
    sub [esi + 38], ecx
    MostrarMsg msgVentaOk
    MostrarMsgSiNoCero aplicoDesc, msgDescuento
    ImprimirDatoMXN msgTotalVenta, totalVenta
L_FinVenta:
    ret

L_Desborde:                         ; venta rechazada: vuelve a pedir la cantidad
    MostrarMsg msgDesborde
    jmp L_PedirCantVta
L_SinStock:                         ; no alcanza la existencia: vuelve a pedir
    MostrarMsg msgSinStock
    jmp L_PedirCantVta
VenderProducto ENDP

; Importe = cantidad * precio; si cantidad >= MAYOREO_MIN aplica 10% de
; descuento (importe*90/100, sin fraccion).
; Recibe: ESI = registro del producto, ECX = cantidad.
; Devuelve: EAX = importe en centavos; CF=1 si hubo desbordamiento;
;           aplicoDesc = 1 si se aplico descuento.
; Modifica: aplicoDesc.  Conserva: EBX, EDX (USES); ECX y ESI no se tocan.
CalcularImporte PROC USES ebx edx
    mov aplicoDesc, 0
    mov eax, ecx
    mul DWORD PTR [esi + 34]        ; EDX:EAX = cantidad * precio
    jc L_ImpDesb
    cmp ecx, MAYOREO_MIN
    jb L_ImpOk

    mov ebx, 90
    mul ebx
    jc L_ImpDesb
    xor edx, edx
    mov ebx, 100
    div ebx
    mov aplicoDesc, 1
L_ImpOk:
    clc
    ret
L_ImpDesb:
    stc
    ret
CalcularImporte ENDP

; Pide el codigo de un producto existente; si es invalido o no existe,
; muestra el error y VUELVE A PEDIRLO.  ENTER vacio cancela.
; Recibe: nada.
; Devuelve: CF=0 -> ptrProducto = registro del producto, ESI = igual.
;           CF=1 -> el usuario cancelo (ESI sin significado).
; Modifica: ptrProducto.  Conserva: EAX, ECX, EDX (USES); EDI intacto.
PedirProducto PROC USES eax ecx edx
L_PPPedir:
    mov edx, OFFSET msgCodProd
    call LeerTexto
    cmp eax, 0
    je L_PPCancel
    call ValidarCapturaCodigo
    jc L_PPErrCod
    call BuscarProductoPorCodigo
    cmp esi, 0
    je L_PPNoEnc
    mov ptrProducto, esi
    clc
    ret
L_PPErrCod:
    MostrarMsg msgErrCod
    jmp L_PPPedir
L_PPNoEnc:
    MostrarMsg msgNoEncontr
    jmp L_PPPedir
L_PPCancel:
    MostrarMsg msgCancelado
    stc
    ret
PedirProducto ENDP

; Pide una cantidad entera > 0; si es invalida muestra el error y VUELVE A
; PEDIRLA.  ENTER vacio cancela.
; Recibe: EDX = mensaje para pedir la cantidad.
; Devuelve: CF=0 -> EAX = cantidad (> 0).  CF=1 -> cancelo (EAX sin significado).
; Modifica: EDX (queda con otro valor).  Conserva: EBX (USES).
PedirCantidad PROC USES ebx
    mov ebx, edx                    ; guarda el mensaje para repetirlo
L_PCPedir:
    mov edx, ebx
    call LeerTexto                  ; EAX = longitud
    cmp eax, 0
    je L_PCCancel
    call StringAEntero
    jc L_PCErr
    cmp eax, 0
    je L_PCErr
    clc
    ret
L_PCErr:
    MostrarMsg msgErrCant
    jmp L_PCPedir
L_PCCancel:
    MostrarMsg msgCancelado
    stc
    ret
PedirCantidad ENDP

; =====================================================================
; 5. MOSTRAR RESUMEN
; Recibe: nada.  Devuelve: nada.  Conserva: todos los registros (USES).
; =====================================================================
MostrarResumen PROC USES eax ebx ecx edx esi edi
    MostrarMsg msgResHead
    xor ebx, ebx                    ; valor del inventario (centavos)
    xor edi, edi                    ; unidades disponibles
    mov ecx, TotalProductos
    cmp ecx, 0
    je L_MostrarRes
    mov esi, OFFSET Inventario
L_LoopRes:
    mov eax, [esi + 34]
    mov edx, [esi + 38]
    add edi, edx
    mul edx
    add ebx, eax
    add esi, TAM_PRODUCTO
    loop L_LoopRes

L_MostrarRes:
    ImprimirDato    msgResProd,  TotalProductos
    ImprimirDato    msgResUnid,  edi
    ImprimirDatoMXN msgResValor, ebx
    ImprimirDatoMXN msgResIngr,  IngresosSesion
    ret
MostrarResumen ENDP

; =====================================================================
; 6. GUARDAR Y CARGAR ARCHIVO
; Formato: [TotalProductos: 4 bytes][Inventario: 420 bytes]
; =====================================================================
; Recibe: nada.  Devuelve: nada.  Modifica: fileHandle, archivo en disco.
; Conserva: todos los registros (USES).
GuardarInventario PROC USES eax ecx edx
    mov edx, OFFSET NombreArchivo
    call CreateOutputFile
    mov fileHandle, eax
    cmp eax, INVALID_HANDLE_VALUE
    je L_ErrFile

    EscribirArchivo TotalProductos, 4, L_ErrEscr
    EscribirArchivo Inventario, TAM_INVENTARIO, L_ErrEscr
    CerrarArchivo
    MostrarMsg msgGuardado
    ret

L_ErrEscr:
    CerrarArchivo
L_ErrFile:
    MostrarMsg errorGuardar
    ret
GuardarInventario ENDP

; Lee inventario.dat a temporales, valida y solo si todo es correcto
; reemplaza el catalogo.
; Recibe: nada.  Devuelve: nada.
; Modifica: fileHandle, tmpTotal, tmpInv, y (solo si es valido)
; TotalProductos e Inventario.  Conserva: todos los registros (USES).
CargarInventario PROC USES eax ecx edx esi edi
    mov edx, OFFSET NombreArchivo
    call OpenInputFile
    mov fileHandle, eax
    cmp eax, INVALID_HANDLE_VALUE
    je L_SinArchivo

    LeerArchivo tmpTotal, 4, L_ArchivoMalo
    LeerArchivo tmpInv, TAM_INVENTARIO, L_ArchivoMalo
    CerrarArchivo

    cmp tmpTotal, MAX_PRODUCTOS
    ja L_Invalido
    mov ecx, tmpTotal
    cmp ecx, 0
    je L_Copiar
    mov esi, OFFSET tmpInv
L_ValReg:
    call ValidarRegistro
    jc L_Invalido
    add esi, TAM_PRODUCTO
    loop L_ValReg

L_Copiar:
    mov eax, tmpTotal
    mov TotalProductos, eax
    CopiarBytes Inventario, tmpInv, TAM_INVENTARIO
    MostrarMsg msgCargado
    ret

L_ArchivoMalo:
    CerrarArchivo
L_Invalido:
    MostrarMsg errorArchivo
    ret
L_SinArchivo:
    MostrarMsg msgSinArchivo
    ret
CargarInventario ENDP

; Valida un registro leido de disco.
; Recibe: ESI = registro.  Devuelve: CF=1 si es invalido, CF=0 si es valido.
; Conserva: EAX (USES) y ESI.
ValidarRegistro PROC USES eax
    call ValidarCodigoEn
    jc L_RegMal
    cmp BYTE PTR [esi + 8], 0       ; nombre no vacio
    je L_RegMal
    cmp BYTE PTR [esi + 33], 0      ; nombre terminado en 0
    jne L_RegMal
    mov eax, [esi + 34]
    EnRango eax, PRECIO_MIN, PRECIO_MAX, L_RegMal
    cmp DWORD PTR [esi + 38], MAX_EXISTENCIA
    ja L_RegMal
    clc
    ret
L_RegMal:
    stc
    ret
ValidarRegistro ENDP

; =====================================================================
; AUXILIARES
; =====================================================================

; Pone en ceros los 30 bytes de bufferIn.
; Recibe/Devuelve: nada.  Conserva: EAX, ECX, EDI (USES).
LimpiarBuffer PROC USES eax ecx edi
    mov edi, OFFSET bufferIn
    mov ecx, 30
    xor al, al
    rep stosb
    ret
LimpiarBuffer ENDP

; ESI = Inventario + TotalProductos * TAM_PRODUCTO.
; Recibe: nada.  Devuelve: ESI = primer registro libre.
; Conserva: EAX, EBX, EDX (USES).
ObtenerPunteroLibre PROC USES eax ebx edx
    mov eax, TotalProductos
    mov ebx, TAM_PRODUCTO
    mul ebx
    mov esi, OFFSET Inventario
    add esi, eax
    ret
ObtenerPunteroLibre ENDP

; Valida 3 letras mayusculas, guion y 3 digitos, y fin de cadena.
; Recibe: ESI = cadena.  Devuelve: CF=1 invalido, CF=0 valido.
; Conserva: EAX, ECX, ESI (USES).
ValidarCodigoEn PROC USES eax ecx esi
    mov ecx, 3
L_Letras:
    mov al, [esi]
    EnRango al, 'A', 'Z', L_CodMal
    inc esi
    loop L_Letras

    cmp BYTE PTR [esi], '-'
    jne L_CodMal
    inc esi

    mov ecx, 3
L_Digitos:
    mov al, [esi]
    EsDigito al, L_CodMal
    inc esi
    loop L_Digitos

    cmp BYTE PTR [esi], 0
    jne L_CodMal
    clc
    ret
L_CodMal:
    stc
    ret
ValidarCodigoEn ENDP

; Valida el codigo ya capturado en bufferIn (longitud exacta y formato).
; Recibe: EAX = longitud capturada (la que devuelve LeerTexto).
; Devuelve: CF=1 invalido, CF=0 valido.  Conserva: ESI (USES); EAX intacto.
ValidarCapturaCodigo PROC USES esi
    cmp eax, LONG_CODIGO
    jne L_CapMal
    mov esi, OFFSET bufferIn
    call ValidarCodigoEn            ; CF = resultado
    ret
L_CapMal:
    stc
    ret
ValidarCapturaCodigo ENDP

; Busca en el catalogo el codigo guardado en bufferIn (7 caracteres).
; Recibe: bufferIn con el codigo.  Devuelve: ESI = registro o 0.
; Conserva: ECX, EDI (USES).
BuscarProductoPorCodigo PROC USES ecx edi
    mov ecx, TotalProductos
    cmp ecx, 0
    je L_NoFnd
    mov esi, OFFSET Inventario
L_CheckNext:
    push esi                        ; cmpsb modifica ESI y ECX
    push ecx
    mov edi, OFFSET bufferIn
    mov ecx, LONG_CODIGO
    repe cmpsb
    pop ecx
    pop esi
    je L_Encontrado
    add esi, TAM_PRODUCTO
    loop L_CheckNext
L_NoFnd:
    xor esi, esi
L_Encontrado:
    ret
BuscarProductoPorCodigo ENDP

; Muestra un mensaje y lee una linea en bufferIn (limpiandolo antes).
; Recibe: EDX = mensaje.  Devuelve: EAX = caracteres leidos; bufferIn lleno.
; Conserva: ECX, EDX (USES).
LeerTexto PROC USES ecx edx
    call WriteString
    call LimpiarBuffer
    mov edx, OFFSET bufferIn
    mov ecx, BUF_LECTURA
    call ReadString
    ret
LeerTexto ENDP

; Muestra un mensaje y lee un entero sin signo de 1 a 4 digitos.
; Recibe: EDX = mensaje.  Devuelve: EAX = numero; CF=1 si es invalido.
; Conserva: ECX, EDX (via LeerTexto).
LeerEntero PROC
    call LeerTexto
    call StringAEntero
    ret
LeerEntero ENDP

; Convierte bufferIn (solo digitos, 1 a 4) a entero.
; Recibe: bufferIn.  Devuelve: EAX = numero; CF=1 si error.
; Conserva: EBX, ECX, ESI (USES).
StringAEntero PROC USES ebx ecx esi
    xor eax, eax
    xor ecx, ecx
    mov esi, OFFSET bufferIn
L_EntLp:
    movzx ebx, BYTE PTR [esi]
    cmp bl, 0
    je L_EntFin
    EsDigito bl, L_EntErr
    AgregaDigito eax, ebx
    inc ecx
    cmp ecx, 4
    ja L_EntErr
    inc esi
    jmp L_EntLp
L_EntFin:
    cmp ecx, 0
    je L_EntErr
    clc
    ret
L_EntErr:
    stc
    ret
StringAEntero ENDP

; Convierte bufferIn ("18", "18.5", "18.50") a centavos (rango 1 a 999999).
; Recibe: bufferIn.  Devuelve: EAX = centavos; CF=1 si formato invalido
; (rechaza 3er decimal).  Conserva: EBX, ECX, ESI (USES).
StringACentavos PROC USES ebx ecx esi
    xor eax, eax
    xor ecx, ecx                    ; digitos enteros
    mov esi, OFFSET bufferIn

L_EnteroLp:
    movzx ebx, BYTE PTR [esi]
    cmp bl, 0
    je L_SinPunto
    cmp bl, '.'
    je L_Punto
    EsDigito bl, L_ErrConv
    AgregaDigito eax, ebx
    inc ecx
    cmp ecx, 4
    ja L_ErrConv                    ; maximo 4 digitos enteros
    inc esi
    jmp L_EnteroLp

L_SinPunto:                         ; "18" -> 1800
    cmp ecx, 0
    je L_ErrConv
    imul eax, eax, 100
    jmp L_Rango

L_Punto:
    cmp ecx, 0
    je L_ErrConv                    ; no se permite ".50"
    inc esi
    movzx ebx, BYTE PTR [esi]       ; primer decimal (obligatorio)
    EsDigito bl, L_ErrConv
    AgregaDigito eax, ebx
    inc esi
    movzx ebx, BYTE PTR [esi]       ; segundo decimal (opcional)
    cmp bl, 0
    je L_UnDecimal
    EsDigito bl, L_ErrConv
    AgregaDigito eax, ebx
    inc esi
    cmp BYTE PTR [esi], 0           ; un tercer caracter se rechaza
    jne L_ErrConv
    jmp L_Rango

L_UnDecimal:                        ; "18.5" -> 1850
    imul eax, eax, 10

L_Rango:
    EnRango eax, PRECIO_MIN, PRECIO_MAX, L_ErrConv
    clc
    ret
L_ErrConv:
    stc
    ret
StringACentavos ENDP

; Imprime el entero sin signo de EAX en decimal.
; Recibe: EAX.  Devuelve: nada.  Conserva: EAX, EBX, ECX, EDX, ESI (USES).
; (los digitos se apilan y se desapilan: la pila queda balanceada)
ImprimirEntero PROC USES eax ebx ecx edx esi
    mov ebx, 10
    xor ecx, ecx
L_DivLp:
    xor edx, edx
    div ebx
    add dl, '0'
    push edx
    inc ecx
    cmp eax, 0
    jne L_DivLp

    mov esi, OFFSET bufNum
L_PopLp:
    pop edx
    mov [esi], dl
    inc esi
    loop L_PopLp
    mov BYTE PTR [esi], 0

    MostrarMsg bufNum
    ret
ImprimirEntero ENDP

; Imprime "$18.50 MXN".
; Recibe: EAX = centavos.  Devuelve: nada.  Conserva: EAX, EBX, EDX (USES).
MostrarPrecioMXN PROC USES eax ebx edx
    xor edx, edx
    mov ebx, 100
    div ebx                         ; EAX = pesos, EDX = centavos
    push edx
    push eax
    MostrarMsg strDolar
    pop eax
    call ImprimirEntero             ; pesos
    MostrarMsg strPunto
    pop eax                         ; centavos
    push eax
    MostrarMsgSiMenorIgual eax, 9, strCero   ; centavos de 1 digito: "05"
    pop eax
    call ImprimirEntero
    MostrarMsg etiquetaMXN
    ret
MostrarPrecioMXN ENDP

END main
