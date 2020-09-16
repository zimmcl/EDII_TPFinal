	LIST P=16f887
	INCLUDE <P16f887.inc>
	
; CONFIG1
; __config 0x2FF4
 __CONFIG _CONFIG1, _FOSC_INTRC_NOCLKOUT & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_ON & _FCMEN_ON & _LVP_OFF
; CONFIG2
; __config 0x3FFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

		
CONTA1		EQU 0x20	;Registro donde se almacena el valor de N
CONTA2		EQU	0x21	;Registro donde se almacena el valor de M
UNIDADES	EQU	0x22	;Registros que almacenan la distancia sensada
DECENAS		EQU	0x23
CENTENAS	EQU	0x24	
MD_UNI		EQU	0x25	;Registros que almacenan la distancia máxima
MD_DEC		EQU	0x26	;configurada por el usuario
MD_CEN		EQU	0x27	
UNI_CONV	EQU	0x28	
DEC_CONV	EQU	0x29
CEN_CONV	EQU	0x2A
BCD_CONV	EQU	0x2B	;Conversión de 3 registros BCD a BINARIO
MD_UNI_C	EQU	0x2C		
MD_DEC_C	EQU	0x2D
MD_CEN_C	EQU	0x2E
MD_BCD_C	EQU	0x2F	
W_TEMP		EQU	0x30	
S_TEMP		EQU	0x31				
DEC_FLAG	EQU	0x32	
BANDERAS	EQU	0x33
CONTADOR	EQU	0x34
BIN			EQU	0x35
B_CONT		EQU	0x36
TEMP		EQU	0x37
TEMPORAL	EQU	0x38
RESTA		EQU	0x39
SUP			EQU	0x3A
MED			EQU	0x3B
INT			EQU	0x3C
CONTA3		EQU	0x3D
RANGO		EQU	0x3E
INTERVALO	EQU	0x3F
	
N	EQU	.33				;Literales para los contadores de RETARDO
M	EQU	.20
	
	;Definición de Bits
	#DEFINE	DISPARO		PORTB,1			;Entrada
	#DEFINE	ECO			PORTB,0			;Salida
	#DEFINE	BUZZER		PORTE,2
	#DEFINE	ECO_DONE	BANDERAS,0
	#DEFINE	SIN_SHOT	BANDERAS,1
	#DEFINE	LED_B		PORTC,2
	#DEFINE	LED_G		PORTC,1
	#DEFINE	LED_R		PORTC,0

	ORG		0x00
	GOTO	CONFIGURAR
	ORG		0x04
	GOTO	INT_VECTOR
	ORG		0x05

CONFIGURAR
	BANKSEL	TRISA				;Cambio al banco 1
	CLRF	TRISA				;Pines del Puerto A como salida
	MOVLW	B'00000001'
	MOVWF	TRISB				;Pines del Puerto B como salida, salvo el Pin0
	CLRF	TRISC				;Pines del Puerto C como salida
	MOVLW	B'11100000'
	MOVWF	TRISD				;Pines <7:5> como entrada. Restantes como salida
	MOVLW	B'00000000'			
	MOVWF	TRISE				
	MOVLW	0x75				
	MOVWF	OSCCON				;Fosc 8MHz
	MOVLW	B'11010000'
	MOVWF	OPTION_REG			;Pull-up deshabilitadas. PS 1:2. RB0 flanco ascendente
	MOVLW	B'10010000'		
	MOVWF	INTCON				;GIE (ON), T0IE (OFF), INTE (ON)
	
	MOVLW   .51					;9600 baudios con Fosc 8MHz
	MOVWF   SPBRG
	
	MOVLW	B'00100100'			;Transmisión de 8bits, asincrona de alta velocidad
	MOVWF	TXSTA				;Bit de transmisión TXEN habilitado
	
	BANKSEL	ANSEL				;Cambio a banco 3
	CLRF	ANSEL				;Puerto A con I/O digital
	CLRF	ANSELH				;Puerto B con I/O digital
	BCF		BAUDCTL,BRG16		;BRG 8bits
	
	BANKSEL	PORTA				;Cambio al banco 0
	MOVLW	B'10000000'			;Habilitamos Puerto Serial (Bit SPEN)
	MOVWF	RCSTA				
	CLRF    PORTA			
	MOVLW	b'00111000'			;Deshabilitamos todos los display poniendolos en alto.
	MOVWF	PORTB				;La lógica de control es negada. 
	MOVWF	PORTC
	CLRF	BANDERAS
	CLRF	MD_UNI
	CLRF	UNIDADES
	CLRF	DECENAS
	CLRF	CENTENAS
	MOVLW	.5					;Inicializamos distancia máxima en 50
	MOVWF	MD_DEC
	CLRF	MD_CEN
	CLRF	DEC_FLAG
	MOVLW	.50					
	MOVWF	CONTADOR
	GOTO	INICIO	

;*****************************************************************************************
;RUTINA
;Gestión de las interrupciones. Se guarda el contexto, se chequean las banderas para
;determinar el origen de la interrupción y se direcciona a la subrutina correspondiente
;a dicha interrupción. Finalmente se recupere el contexto previo a la interrupción y se
;retorna habilitando la interrupción global
;*****************************************************************************************
INT_VECTOR
	;Guardamos el contexto
	MOVLW	W_TEMP
	SWAPF	STATUS,W
	MOVWF	S_TEMP
	;Chequeamos banderas de interrupcion
	BTFSC	INTCON,INTF
	CALL	RB0_INT	
	BTFSC	INTCON,T0IF
	CALL	TMR0_INT
	;Recuperamos el contexto
	SWAPF	S_TEMP,W
	MOVWF	STATUS
	SWAPF	W_TEMP,F
	SWAPF	W_TEMP,W
	RETFIE
	
;*****************************************************************************************
;SUB-RUTINA
;Con cada interrupción incrementa los registros. Cuando el de menor denominación alcanza
;el valor de 10, lo setea con un 0 e incrementa el registro siguiente en denominación.
;*****************************************************************************************	
TMR0_INT
	BCF		INTCON	,T0IF	
	MOVLW	.202
	MOVWF	TMR0
	INCF	UNIDADES

	MOVLW	0x0A
	SUBWF	UNIDADES,W
	BTFSS	STATUS,Z
	RETURN
	CLRF	UNIDADES
	INCF	DECENAS		
	MOVLW	0x0A
	SUBWF	DECENAS,W
	BTFSS	STATUS,Z
	RETURN
	CLRF	DECENAS
	INCF	CENTENAS	
	MOVLW	0x0A
	SUBWF	CENTENAS,w
	BTFSS	STATUS,Z
	RETURN
	CLRF	CENTENAS	
	RETURN

;*****************************************************************************************
;SUB-RUTINA
;Detecta el cambio de estado del pin0 del puerto B asociado al ECHO del sensor.
;Chequea el nivel del pin, si esta en Alto, comienza la temporización habilitanda la
;interrupción por TMR0.
;Cuando llega la siguiente interrupción (pin0 en Bajo), se detiene la temporización
;deshabilitando el TMR0, y poniendo en alto la bandera ECO_DONE.
;Se alterna entre flanco ascendente y descendente la interrupción por RB0. 
;*****************************************************************************************	
RB0_INT
	BCF		INTCON,INTF
	BTFSS	ECO
	GOTO	DETENER_TIMER
	MOVLW	.202				;Cargo al TMR0 para interrupción de 58us 
	MOVWF	TMR0			
	BSF		INTCON,T0IE			;Habilitamos (inicia) el TMR0
	CLRF	UNIDADES			;Reseteamos los registros asociados a los displays
	CLRF	DECENAS
	CLRF	CENTENAS
	BANKSEL	OPTION_REG
	BCF		OPTION_REG,6		;Activación de RB0 por flanco descendente
	BANKSEL	PORTA
	RETURN
DETENER_TIMER
	BCF		INTCON,T0IE			;Se detine al TMR0
	BSF		ECO_DONE			;Se levanta la bandera de adquisición de distancia
	BANKSEL	OPTION_REG			
	BSF		OPTION_REG,6		;Activación de RB0 por flanco ascendente
	BANKSEL	PORTA
	RETURN
	
;*****************************************************************************************
;RUTINA
;Multiplexa los display y despliega el contenido de los registros. Se emplea un retardo
;aproximado de 1ms entre multiplexaciones.
;El valor 7-SEG es obtenido mediante conversión por tablas.
;*****************************************************************************************	
MOSTRAR
	MOVLW	b'00111000'		;Deshabilitamos todos los display poniendolos en alto.
	MOVWF	PORTB
	MOVLW	UNIDADES
	MOVWF	FSR				;Apunto a donde se encuentran las UNIDADES con FSR, y
	MOVF	INDF,W			;recupero el contenido del registro al que apunta con INDF
	CALL	CONVIERTE		
	BCF		PORTB,5			;Habilito el display UNIDADES
	MOVWF	PORTA			;Muestro el valor convertido por el puerto A
	CALL	RETARDO			;Delay 1ms
	BSF		PORTB,5			;Deshabilito el display UNIDADES
	INCF	FSR				;Incremento puntero hacia DECENAS
	MOVF	INDF,W		
	CALL	CONVIERTE
	BCF		PORTB,4			;Habilito el display DECENAS 
	MOVWF	PORTA
	CALL	RETARDO
	BSF		PORTB,4			;Deshabilito el display DECENAS
	INCF	FSR				;Incremento puntero hacia CENTENAS
	MOVF	INDF,W
	CALL	CONVIERTE
	BCF		PORTB,3			;Habilito el display CENTENAS 
	MOVWF	PORTA
	CALL	RETARDO
	BSF		PORTB,3			;Deshabilito el display CENTENAS
	INCF	FSR				;Incremento puntero hacia MD_UNI
MOSTRAR_MD	
	MOVF	INDF,W
	CALL	CONVIERTE
	BCF		PORTC,5			;Habilito el display MD_UNI
	MOVWF	PORTA
	CALL	RETARDO
	BSF		PORTC,5			;Deshabilito el display MD_UNI
	INCF	FSR				;Incremento puntero hacia MD_DEC
	MOVF	INDF,W
	CALL	CONVIERTE
	BCF		PORTC,4			;Habilito el display MD_DEC
	MOVWF	PORTA
	CALL	RETARDO
	BSF		PORTC,4			;Deshabilito el display MD_DEC
	INCF	FSR				;Incremento puntero hacia MD_CEN
	MOVF	INDF,W
	CALL	CONVIERTE
	BCF		PORTC,3			;Habilito el display MD_CEN 
	MOVWF	PORTA
	CALL	RETARDO
	BSF		PORTC,3			;Deshabilito el display MD_CEN
	RETURN
	
;*****************************************************************************************
;Empaqueta en un unico registro los 3 registros BCD representativos de las CENTENAS, 
;DECENAS y UNIDADES correspondientes a la medición obtenida por el sensor y a la
;configurada por el usuario como distancia mínima. Esta converción se hace a los fines
;de realizar la comparación de ambas magnitudes y activar la alerta de proximidad.
;*****************************************************************************************	
BCD2BIN
	MOVF	DECENAS,W
	CALL	MULT_10
	MOVWF	DEC_CONV
	MOVF	CENTENAS,W
	CALL	MULT_10
	CALL	MULT_10
	MOVWF	CEN_CONV
	MOVF	UNIDADES,W
	ADDWF	DEC_CONV,W
	ADDWF	CEN_CONV,W
	MOVWF	BCD_CONV
	
	MOVF	MD_DEC,W
	CALL	MULT_10
	MOVWF	MD_DEC_C
	MOVF	MD_CEN,W
	CALL	MULT_10
	CALL	MULT_10
	MOVWF	MD_CEN_C
	MOVF	MD_UNI,W
	ADDWF	MD_DEC_C,W
	ADDWF	MD_CEN_C,W
	MOVWF	MD_BCD_C
	CLRF	TEMP
	RETURN
;Multiplica un registro en BCD por 10 mediante sumas sucesivas de si mismo.	
MULT_10	
	MOVWF	TEMP
	MOVWF	TEMPORAL	
	MOVLW	.9
	MOVWF	B_CONT
MULT	
	MOVF	TEMPORAL,W
	ADDWF	TEMP,F
	DECF	B_CONT,F
	BTFSS	STATUS,Z
	GOTO	MULT
	MOVF	TEMP,W
	RETURN
	
;*****************************************************************************************
;BLOQUE DE RETARDOS
;*****************************************************************************************	
;Retardo de 1ms	para la multiplexación de los displays
RETARDO
	MOVLW	M			;Cargamos el contador 2 con el valor de M
	MOVWF	CONTA2
CICLO2
	MOVLW	N			;Cargamos el contador 1 con el valor de N
	MOVWF	CONTA1
CICLO1
	DECFSZ	CONTA1,1
	GOTO	CICLO1
	DECFSZ	CONTA2,1
	GOTO	CICLO2
	RETURN
;*****************************************************************************************
;Retardo de habilitación del TRIGGER
DELAY
	MOVLW	0x06
	MOVWF	CONTA1
LOOP
	DECFSZ	CONTA1,F
	GOTO	LOOP
	RETURN
;*****************************************************************************************
;Retardo variable para la alerta de proximidad
;					SUP	MED	INT	TIEMPO
;NIVEL 4 - 36.5Hz	10	26	69	27.55ms
;NIVEL 3 - 12.2Hz	30	26	69	82.3ms
;NIVEL 2 - 7.3Hz	50	26	69	137ms
;NIVEL 1 - 5.2Hz	70	26	69	192ms
;NIVEL 0 - 4Hz		90	26	69	250ms
	
RETARDO_BUZ
	MOVF	SUP,W			
	MOVWF	CONTA3
CICLO_3
	CALL	MOSTRAR
	CALL	CHECK_BOTON
	MOVF	MED,W
	MOVWF	CONTA2
CICLO_2
	MOVF	INT,W			
	MOVWF	CONTA1
CICLO_1
	DECFSZ	CONTA1,F
	GOTO	CICLO_1
	DECFSZ	CONTA2,F
	GOTO	CICLO_2
	DECFSZ	CONTA3,F
	GOTO	CICLO_3
	RETURN
;*****************************************************************************************
;LOGICA DE DATOS NEGADA - b'pgfedcba'
CONVIERTE	ADDWF PCL,F ;suma al PC el valor del dígito
	RETLW	0x40 ;obtiene el valor 7 segmentos del 0 - b'01000000'
	RETLW	0x79 ;obtiene el valor 7 segmentos del 1 - b'01111001'
	RETLW	0x24 ;obtiene el valor 7 segmentos del 2 - b'00100100'
	RETLW	0x30 ;obtiene el valor 7 segmentos del 3 - b'00110000'
	RETLW	0x19 ;obtiene el valor 7 segmentos del 4 - b'00011001'
	RETLW	0x12 ;obtiene el valor 7 segmentos del 5 - b'00010010'
	RETLW	0x02 ;obtiene el valor 7 segmentos del 6 - b'00000010'
	RETLW	0x78 ;obtiene el valor 7 segmentos del 7 - b'01111000'
	RETLW	0x00 ;obtiene el valor 7 segmentos del 8 - b'00000000'
	RETLW	0x18 ;obtiene el valor 7 segmentos del 9 - b'00011000'
	RETLW	0xBF 

TEXT_DISTANCIA	ADDWF	PCL,F
	DT "Distancia: "

;*****************************************************************************************
;RUTINA
;Resguarda la distancia máxima seteada por el usuario para recuperarla cuando se retorne
;desde esta rutina.
;Se chequea la pulsación de las teclas de sensado (RD7) y retorno  (RD5).
;*****************************************************************************************	
SINGLE_SHOT
	MOVF	MD_UNI,W
	MOVWF	MD_UNI_C
	MOVF	MD_DEC,W
	MOVWF	MD_DEC_C
	MOVF	MD_CEN,W
	MOVWF	MD_CEN_C	
ESPERA
	MOVLW	.10
	MOVWF	MD_UNI
	MOVWF	MD_DEC
	MOVWF	MD_CEN
	MOVLW	MD_UNI
	MOVWF	FSR
	CALL	MOSTRAR_MD
	BTFSC	PORTD,RD7
	CALL	DISPARO_
	BTFSS	PORTD,RD5
	GOTO	ESPERA

SALIR_
	BTFSC	PORTD,RD5
	GOTO	SALIR_
	MOVLW	UNIDADES
	MOVWF	FSR
	MOVF	MD_UNI_C,W
	MOVWF	MD_UNI
	MOVF	MD_CEN_C,W
	MOVWF	MD_CEN
	MOVF	MD_DEC_C,W
	MOVWF	MD_DEC
	BCF		SIN_SHOT				;Bajamos la bandera de 'Modo Simple'
	RETURN
DISPARO_
	CALL	SENSADO
	BTFSC	PORTD,RD7				;Mientras el boton de disparo se mantenga
	CALL	MOSTRAR					;precionado se muestra la distancia por el
	BTFSC	PORTD,RD7				;display. Cuando el pulsador se suelta,
	GOTO	$-3						;la información se transmite de manera
;	CALL	SENSADO					;serial al PC.
	CALL	ENVIAR
;	CALL	MOSTRAR
	RETURN	
	
;*****************************************************************************************
;RUTINA
;Chequa la pulsación de los botones. Si se preciona el boton de cambio de modo de
;funcionamiento (RD5), se levanta la bandera de 'Modo Simple'. Si se preciona el
;boton RD6 se incrementan los registros de distancia máxima; y si se preciona el
;boton RD7 se decrementan los registros de distancia máxima.
;*****************************************************************************************
CHECK_BOTON
	BTFSC	PORTD,RD5
	GOTO	RD_5	
	BTFSC	PORTD,RD6
	GOTO	RD_6
	BTFSC	PORTD,RD7
	GOTO	RD_7
	RETURN
RD_5
	BTFSC	PORTD,RD5
	GOTO	RD_5
	BSF		SIN_SHOT
	;CALL	SINGLE_SHOT
	RETURN		
RD_6
	BTFSC	PORTD,RD6
	GOTO	RD_6
	INCF	MD_UNI,F
	BCF		DEC_FLAG,0
	MOVLW	.10
	XORWF	MD_UNI,W
	BTFSS	STATUS,Z
	RETURN
	CLRF	MD_UNI
	INCF	MD_DEC,F
	BCF		DEC_FLAG,1
	MOVLW	.10
	XORWF	MD_DEC,W
	BTFSS	STATUS,Z
	RETURN
	CLRF	MD_DEC
	INCF	MD_CEN,F
	BCF		DEC_FLAG,2
	MOVLW	.10
	XORWF	MD_CEN,W
	BTFSS	STATUS,Z
	RETURN
	CLRF	CENTENAS	
	RETURN
		
RD_7 
	BTFSC	PORTD,RD7
	GOTO	RD_7
	BTFSC	DEC_FLAG,0
	RETURN
	MOVF	MD_UNI,W
	XORLW	.0
	BTFSC	STATUS,Z
	GOTO	CHECK_DEC
	DECF	MD_UNI,F
	RETURN
 
CHECK_DEC
	BTFSC	DEC_FLAG,1
	GOTO	CLR_MD_UNI
	MOVLW	.9
	MOVWF	MD_UNI
	DECF	MD_DEC,F
	MOVLW	0xFF
	XORWF	MD_DEC,W
	BTFSS	STATUS,Z
	RETURN

	BTFSC	DEC_FLAG,2
	GOTO	CLR_MD_DEC
	MOVLW	.9
	MOVWF	MD_DEC
	DECF	MD_CEN,F
	MOVLW	0xFF
	XORWF	MD_CEN,W
	BTFSS	STATUS,Z
	RETURN
CLR_MD_CEN
	BSF		DEC_FLAG,2
	MOVLW	0x00
	MOVWF	MD_CEN
	MOVWF	MD_DEC
	MOVWF	MD_UNI
	RETURN
CLR_MD_DEC
	BSF		DEC_FLAG,1
	MOVLW	0x00
	MOVWF	MD_UNI
	MOVWF	MD_DEC
	RETURN
CLR_MD_UNI
	BSF		DEC_FLAG,0
	MOVLW	0x00
	MOVWF	MD_UNI
	RETURN	

;*****************************************************************************************
;RUTINA
;Compara la distancia sensada con la distancia máxima fijada por el usuario. A partir de
;esta comparación determina si deshabilita la alerta sonora y visual, ó si procede a
;determinar los niveles de corte de alerta.
;*****************************************************************************************	
COMPARAR_DISTANCIA
	CALL	BCD2BIN
	MOVF	BCD_CONV,W
	SUBWF	MD_BCD_C,W
	BTFSS	STATUS,C
	GOTO	OFF_
	
	MOVLW	.5						;Distancia mínima
	SUBWF	MD_BCD_C,W				;Diferencia entre distancia máxima (fijada por el usuario)
	MOVWF	RANGO					;y distancia mínima (5)
	MOVWF	TEMP
	INCF	INTERVALO,F				;Valor del intervalo
	MOVLW	.5						;Cantidad de ntervalos
	SUBWF	TEMP,F
	BTFSC	STATUS,C
	GOTO	$-4
	DECF	INTERVALO,F
	MOVF	INTERVALO,W
	ADDLW	.8
	MOVWF	TEMP
	
	;A partir de este punto se verifica en que intervalo cae el valor de distancia
	;sensado y se accede a la subrutina correspondiente para configurar el bucle
	;de RETARDO_BUZ y la alerta visual (LED RGB).
	MOVLW	.8
	SUBWF	BCD_CONV,W
	BTFSS	STATUS,C
	GOTO	NIV_5
	
	MOVF	BCD_CONV,W
	SUBWF	TEMP,W
	BTFSC	STATUS,C
	GOTO	NIV_4
	MOVF	INTERVALO,W
	ADDWF	TEMP,F
	
	MOVF	BCD_CONV,W
	SUBWF	TEMP,W
	BTFSC	STATUS,C
	GOTO	NIV_3
	MOVF	INTERVALO,W
	ADDWF	TEMP,F
	
	MOVF	BCD_CONV,W
	SUBWF	TEMP,W
	BTFSC	STATUS,C
	GOTO	NIV_2
	MOVF	INTERVALO,W
	ADDWF	TEMP,F
	
	MOVF	BCD_CONV,W
	SUBWF	TEMP,W
	BTFSC	STATUS,C
	GOTO	NIV_1
	MOVF	INTERVALO,W
	ADDWF	TEMP,F	
	
	MOVF	BCD_CONV,W
	SUBWF	TEMP,W
	BTFSC	STATUS,C
	GOTO	NIV_0
	
	;Desactiva toda alerta
OFF_
	BCF		BUZZER
	BCF		LED_B
	BCF		LED_R
	BCF		LED_G
	RETURN
	;Activa toda alerta.
NIV_5
	BANKSEL	PORTC
	BSF		BUZZER
	BSF		LED_R
	RETURN
	
NIV_4
	BANKSEL	PORTC
	BSF		LED_R
	BCF		LED_G
	BCF		LED_B
	MOVLW	.10
	MOVWF	SUP
	GOTO	CARGAR_RES	
NIV_3
	BANKSEL	PORTC
	BSF		LED_G
	BCF		LED_B
	BCF		LED_R
	MOVLW	.30
	MOVWF	SUP
	GOTO	CARGAR_RES
NIV_2
	BANKSEL	PORTC
	BSF		LED_G
	BCF		LED_B
	BCF		LED_R
	MOVLW	.50
	MOVWF	SUP
	GOTO	CARGAR_RES
NIV_1
	BANKSEL	PORTC
	BSF		LED_B
	BCF		LED_R
	BCF		LED_G	
	MOVLW	.70
	MOVWF	SUP
	GOTO	CARGAR_RES
NIV_0
	BANKSEL	PORTC
	BSF		LED_B
	BCF		LED_R
	BCF		LED_G
	MOVLW	.90
	MOVWF	SUP
	GOTO	CARGAR_RES
	
CARGAR_RES
	MOVLW	.26
	MOVWF	MED
	MOVLW	.69
	MOVWF	INT
	CLRF	TEMP
	CLRF	INTERVALO
	BTFSC	BUZZER
	GOTO	SWITCH
	BSF		BUZZER
	CALL	RETARDO
	CALL	RETARDO
	RETURN	
SWITCH
	MOVLW	0xF8
	ANDWF	PORTC
	BCF		BUZZER
	CLRF	TEMP
	CLRF	INTERVALO
	CALL	RETARDO_BUZ
	RETURN

;*****************************************************************************************
;RUTINA
;Carga el registro TXREG a enviar con el contenido del registro de trabajo W.
;Espera a que el registro TXREG se vacie (transmisión completada)
;*****************************************************************************************	
ENVIAR_DATO_TX
	BANKSEL	TXREG
	MOVWF	TXREG
	BSF		STATUS,RP0	
	BTFSS	TXSTA,TRMT			;Chequeo TSR, espero a que se vacie (0)
	GOTO	$-1
	BCF		STATUS,RP0
	RETURN

;*****************************************************************************************
;RUTINA
;El TRIGGER recibe un pulso de habilitación ('1' lógico) de parte del microcontrolador,
;mediante el cual se le indica al módulo que comience a realizar la medición de distancia. 
;El sensor envia 8 Pulsos de 40KHz (Ultrasonido) y coloca su salida ECHO en Alto, este
;evento es detectado por interrupción (flanco ascendente RB0), iniciando el conteo de 
;tiempo. La salida ECHO se mantendrá en Alto hasta recibir la cola del eco reflejado por el 
;obstáculo a lo cual el sensor pondrá su pin ECHO en Bajo, y al igual que antes, el evento 
;es detectado por RB0, esta vez por flanco descendiente, terminando el conteo de tiempo.
;*****************************************************************************************
SENSADO
	BCF		ECO		
	BCF		ECO_DONE
	;RB0 configurado como entrada de ECO, RB1 salida del DISPARO
	BSF		DISPARO		;HC-SR04 DISPARO en Alto
	CALL	DELAY		;Delay de 13us
	BCF		DISPARO		;HC-SR04 DISPARO en Bajo
	BTFSS	ECO
	GOTO	$-4
	BTFSS	ECO_DONE	;Espera activa hasta que termine la adquisicion
	GOTO	$-1			;de la distancia
	RETURN	
	
;*****************************************************************************************
;RUTINA
;Se chequea la bandera de modo de funcionamiento. Si SIN_SHOT es 1 se accede al modo
;de disparo simple, sino continua con el modo continua, realizando sensados periodicos.
;Obtenido el valor sensado, es enviado por serie al PC.
;*****************************************************************************************
INICIO
;	CALL	COMPARAR_DISTANCIA
	BTFSC	SIN_SHOT
	CALL	SINGLE_SHOT
	CALL	MOSTRAR
	CALL	SENSADO
;*****************************************************************************************
ENVIAR
	CLRF	CONTA1
	MOVF	CONTA1,W
	CALL	TEXT_DISTANCIA
	CALL	ENVIAR_DATO_TX
	INCF	CONTA1,F
	MOVLW	.11
	XORWF	CONTA1,W
	BTFSS	STATUS,Z
	GOTO	$-7
	
	MOVLW	CENTENAS
	MOVWF	FSR
	MOVF	INDF,W
	ADDLW	0x30
	CALL	ENVIAR_DATO_TX
	CALL	DELAY
	DECF	FSR,F
	MOVLW	0x21
	XORWF	FSR,W
	BTFSS	STATUS,Z
	GOTO	$-8
	MOVLW	0x0A
	CALL	ENVIAR_DATO_TX
	BTFSC	SIN_SHOT
	RETURN
;*****************************************************************************************		
	CALL	COMPARAR_DISTANCIA
	CALL	CHECK_BOTON
SHOW
	CALL	MOSTRAR
	DECF	CONTADOR,F
	BTFSS	STATUS,Z
	GOTO	SHOW
	MOVLW	.50
	MOVWF	CONTADOR
	GOTO	INICIO
	END