; Program 8.1 ? LED Blinker
; Illustrate the use of a Timer/Counter to blink an LED
; LEDBlinker_Timer.asm
;
; Created: 27/02/2017 11:56:54
; Author : Erick
;

.def drem8u = r20 ;remainder
.def dd8u = r21 ;dividend and result
.def dv8u = r22 ;divisor
.def dcnt8u = r23 ;loop counter

;LED's on PORTB
;Clock speed 16 MHz

;Timer 1 é utilizado para definir um intervalo de 0,5 s
;A cada intervalo os LEDs piscam
;4 LEDs conectados a PORTB

;.def leds = r17 ;current LED value

;definir os semáforos
;s1 low end


;00 - estado nulo
;01 - vermelho
;10 - amarelo 
;11 - verde 
.def temp = r16
.def estado = r18
.def contador = r19
.def temp2 = r24

.cseg

jmp reset
.org OC1Aaddr
jmp OCI1A_Interrupt


reset:

	ldi temp, $FF ;set PORTD for output
	out DDRD, temp
	out DDRC, temp

	;Stack initialization
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	;leds display alternating pattern
	;ldi temp, s1
	;ldi temp, $FF
	;out DDRB, temp
	;ldi leds, $AA ;0b10101010
	;out PORTB, leds ;alternating pattern

	#define CLOCK 16.0e6 ;clock speed
	#define DELAY 0.05;
	.equ PRESCALE = 0b100 ;/256 prescale
	.equ PRESCALE_DIV = 256
	.equ WGM = 0b0100 ;Waveform generation mode: CTC
	;you must ensure this value is between 0 and 65535
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535
	.error "TOP is out of range"
	.endif

	;On MEGA series, write high byte of 16-bit timer registers first
	ldi temp, high(TOP) ;initialize compare value (TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp
	ldi temp, ((WGM&0b11) << WGM10) ;lower 2 bits of WGM
	; WGM&0b11 = 0b0100 & 0b0011 = 0b0000 
	sts TCCR1A, temp
	;upper 2 bits of WGM and clock select
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
	; WGM >> 2 = 0b0100 >> 2 = 0b0001
	; (WGM >> 2) << WGM12 = (0b0001 << 3) = 0b0001000
	; (PRESCALE << CS10) = 0b100 << 0 = 0b100
	; 0b0001000 | 0b100 = 0b0001100
	sts TCCR1B, temp ;start counter

	
	lds	 r16, TIMSK1
	sbr r16, 1 << OCIE1A
	sts TIMSK1, r16
	sei

ldi contador, 0

;00 - estado nulo
;01 - vermelho
;10 - amarelo 
;11 - verde 
;01010111
estado1:
	ldi estado, 0b01010111
	rcall display_ctrl
	rcall state_decoder
	cpi contador, 25
	brlo estado1
	ldi contador, 0

estado2:
	ldi estado, 0b01010110
	rcall display_ctrl
	rcall state_decoder
	cpi contador, 4
	brlo estado2
	ldi contador, 0
 
estado3:
	ldi estado, 0b01010101
	rcall display_ctrl
	rcall state_decoder
	cpi contador, 22
	brlo estado3
	ldi contador, 0

estado4:
	ldi estado, 0b01111101
	rcall display_ctrl
	rcall state_decoder
	cpi contador, 22
	brlo estado4
	ldi contador, 0

estado5:
	ldi estado, 0b01101101
	rcall display_ctrl
	rcall state_decoder
	cpi contador, 4
	brlo estado5
	ldi contador, 0

estado6:
	ldi estado, 0b01011101
	rcall display_ctrl
	rcall state_decoder
	cpi contador, 2
	brlo estado6
	ldi contador, 0

;00 - estado nulo
;01 - vermelho
;10 - amarelo 
;11 - verde 
;01100110

estado7:
	ldi estado, 0b11011101
	rcall display_ctrl
	rcall state_decoder
	cpi contador, 50
	brlo estado7
	ldi contador, 0

estado8:
	ldi estado, 0b10011001
	rcall display_ctrl
	rcall state_decoder
	cpi contador, 4
	brlo estado8
	ldi contador, 0

estado9:
	ldi estado, 0b01010101
	rcall display_ctrl
	rcall state_decoder
	cpi contador, 1
	brlo estado9
	ldi contador, 0
	jmp estado1

; ----------------- CONTROLE DO DISPLAY ----------
display_ctrl:
	ldi dv8u, 10
	mov dd8u, contador

	rcall div8u

	; nao achei como fazer shift variavel, segue o lider
	lsl dd8u
	lsl dd8u
	lsl dd8u
	lsl dd8u
	or dd8u, drem8u
	out PORTD, dd8u

	ret

;----------------- DECODIFICADOR DOS VALORES VERDE, VERMELHO E AMARELO ----------
; 3 bits da porta C reservados para Verde, vermelho, amarelo
; @argumento valor : temp
; @retorno decodificado : temp
;001 - vermelho
;010 - amarelo 
;100 - verde 
light_value_decoder:
	cpi temp2, 0b11
	breq lvd_verde
	; ---- se não for verde ----
	ori temp2, 0b000
	ret

	lvd_verde:
		ldi temp2, 0b100
		ret
		



;---------------- DECODIFICADOR DA MAQUINA DE ESTADOS ------------
state_decoder:
	; logica para o select dos semaforos
	; s1 - 0001
	; s2 - 0010
	; s3 - 0100
	; s4 - 1000

	; sintaxe 
	; b b b b (select) b b b (cor)

	; ------ s1 ---------------
	mov temp2, estado
	andi temp2, 0b11 ; mascara
	rcall light_value_decoder
	ldi temp, 0b0001
	lsl temp
	lsl temp
	lsl temp
	or temp2, temp
	out PORTC, temp2

	; ------ s2 ---------------
	mov temp2, estado
	lsr temp2
	lsr temp2
	andi temp2, 0b11 ; mascara
	rcall light_value_decoder
	ldi temp, 0b0010
	lsl temp
	lsl temp
	lsl temp
	or temp2, temp
	out PORTC, temp2

	; ------ s3 ---------------
	mov temp2, estado
	lsr temp2
	lsr temp2
	lsr temp2
	lsr temp2
	andi temp2, 0b11 ; mascara
	rcall light_value_decoder
	ldi temp, 0b0100
	lsl temp
	lsl temp
	lsl temp
	or temp2, temp
	out PORTC, temp2

	; ------ s4 ---------------
	mov temp2, estado
	lsr temp2
	lsr temp2
	lsr temp2
	lsr temp2
	lsr temp2
	lsr temp2
	andi temp2, 0b11 ; mascara
	rcall light_value_decoder
	ldi temp, 0b1000
	lsl temp
	lsl temp
	lsl temp
	or temp2, temp

	out PORTC, temp2
	ret
	

div8u:    sub    drem8u,drem8u    ;clear remainder and carry
    ldi    dcnt8u,9    ;init loop counter
d8u_1:    rol    dd8u        ;shift left dividend
    dec    dcnt8u        ;decrement counter
    brne    d8u_2        ;if done
    ret            ;    return
d8u_2:    rol    drem8u        ;shift dividend into remainder
    sub    drem8u,dv8u    ;remainder = remainder - divisor
    brcc    d8u_3        ;if result negative
    add    drem8u,dv8u    ;    restore remainder
    clc            ;    clear carry to be shifted into result
    rjmp    d8u_1        ;else
d8u_3:    sec            ;    set carry to be shifted into result
    rjmp    d8u_1

OCI1A_Interrupt:
	push r16
	in r16, SREG
	push r16

	
	;overflow event code goes here
	;ldi temp, $FF
	;eor leds, temp ;0b10101010 --> 0b01010101

	inc contador

	;out PORTD, contador


	pop r16
	out SREG, r16
	pop r16
	reti