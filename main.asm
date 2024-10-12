; Created: 20/09/2024
; Author : Matheus Moreira e Reinaldo Assis
;

.def drem8u = r20 ;remainder
.def dd8u = r21 ;dividend and result
.def dv8u = r22 ;divisor
.def dcnt8u = r23 ;loop counter

.def dspTimeCtrl = r26  ; New register for display time control

;definir os semáforos
;s1 low end


;00 - estado nulo
;01 - vermelho
;10 - amarelo
;11 - verde

.def portB_state = r17

.def temp = r16
.def estado = r18
.def contador = r19
.def temp2 = r24

.def contador_semL = r25
.def contador_semH = r27

.cseg

jmp reset
.org OC1Aaddr
jmp OCI1A_Interrupt

reset:

; ---------- CONFIGURAÇÕES ------------------------------
; TODO: adicionar comentários para que possamos entender melhor
; o que (e como) está sendo configurado.

ldi temp, $FF ;set PORTD for output
out DDRD, temp
out DDRC, temp
out DDRB, temp

;Stack initialization
ldi temp, low(RAMEND)
out SPL, temp
ldi temp, high(RAMEND)
out SPH, temp

#define CLOCK 16.0e6 ;clock speed
#define DELAY 1;
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


lds r16, TIMSK1
sbr r16, 1 << OCIE1A
sts TIMSK1, r16
sei

; --------------------------------------

ldi contador, 0
ldi contador_semL, 0
ldi contador_semH, 0

table:
    .db $7E, $30, $6D, $79, $33, $5B, $5F, $70, $7F, $7B

; --------- MÁQUINA DE ESTADOS ---------
; Foi implementada a seguinte lógica para a implementação da máquina de estados
; em cada estado são chamadas as funções de tratamento, como o controle do display e o
; controle dos semáforos (que compartilham pinos). O semáforo s1 está no low end no
; registrador de estados, assim o registrador é composto por 2 bits para cada semáforo.
; O significado de cada combinação pode ser visto na tabela:
;
; -- Tabela de estados ----
; | 00 - estado nulo |
; | 01 - vermelho |
; | 10 - amarelo |
; | 11 - verde |
; -------------------------

;01010111
estado1:
ldi estado, 0b01010111
rcall display_ctrl
rcall state_decoder
cpi contador, 25
brlo estado1
rcall reset_semaforo
ldi contador, 0

estado2:
ldi estado, 0b01010110
rcall display_ctrl
rcall state_decoder
cpi contador, 4
brlo estado2
rcall reset_semaforo
ldi contador, 0
 
estado3:
ldi estado, 0b01010101
rcall display_ctrl
rcall state_decoder
cpi contador, 22
brlo estado3
ldi contador, 0
rcall reset_semaforo

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
rcall reset_semaforo
jmp estado1

; ----------------- CONTROLE DO DISPLAY ----------
; @argumento: contador_semH
; @argumento: contador_semL
; @return null
; Junta o contador high com o contador low para dar out no display
; Main display control function
display_ctrl:
    inc dspTimeCtrl     ; Increment display time control
    sbrc dspTimeCtrl, 0 ; Skip next instruction if bit 0 is clear (even)
    rjmp display_ctrl_dezena
    rjmp display_ctrl_unidade

; Function to control tens digit display
display_ctrl_dezena:
	
	ldi temp, 0
	out PORTB, temp
	out PORTD, temp

    mov dd8u, contador_semH
    rcall bcd

    ldi temp, 0b00000001
    out PORTB, temp
    out PORTD, dd8u

    ret

; Function to control units digit display
display_ctrl_unidade:
	ldi temp, 0
	out PORTB, temp
	out PORTD, temp

    mov dd8u, contador_semL
    rcall bcd

    ldi temp, 0b00000010
    out PORTB, temp
    out PORTD, dd8u

    ret


; -------------- INCREMENTAR SEMAFORO -------
; Incrementa contador_semL até que atinja 10, então reseta o low e incrementa o high
inc_semaforo:
inc contador_semL
cpi contador_semL, 10
breq inc_semaforoH
ret
inc_semaforoH:
ldi contador_semL, 0
inc contador_semH
ret

; Reseta ambos os contadores, high e low
reset_semaforo:
ldi contador_semL, 0
ldi contador_semH, 0
ret

;----------------- DECODIFICADOR DOS VALORES VERDE, VERMELHO E AMARELO ----------
; 3 bits da porta C reservados para Verde, vermelho, amarelo
; @argumento valor : temp
; @retorno decodificado : temp
; Responsável por decodificar o registrador de estados (semáforos) em 3 bits de seleção para
; os transistores que ligam os leds verde, vermelho e amarelo.

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
; Responsável por permitir o compartilhamento dos pinos, decodifica o estado em sinais de controle
; para acionar os semáforos e seus respectivos leds.
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



;bcd:
;    ; Usa o valor no r28 como índice na tabela
;    ldi r30, low(table) ; carrega o endereço da tabela
;    ldi r31, high(table)
;    mov r29, r28        ; copia o dígito a ser convertido
;    clr r28             ; limpa r28 para usar como índice
;    add r30, r29        ; adiciona o índice à base da tabela
;    ; Pega o valor correspondente na tabela
;    lpm r28, Z          ; r28 agora contém o valor para o display
;    out PORTD, r28      ; envia o valor para o PORTD
;    ret

; esta função serve como um bcd virtual, convertendo
; valores binários em sinais de drive para o display
bcd:
    ; Assumimos que o número a ser convertido está no registrador dd8u (r21)
    ; e que o resultado será armazenado no mesmo registrador.

    mov temp, dd8u      ; Move o número para temp para preservá-lo

    ldi ZH, high(table*2) ; Carrega o endereço alto da tabela de conversão
    ldi ZL, low(table*2)  ; Carrega o endereço baixo da tabela de conversão
    add ZL, temp        ; Adiciona o número ao endereço base da tabela

    lpm temp, Z         ; Carrega o valor da tabela correspondente ao número
    mov dd8u, temp      ; Armazena o valor de volta em `dd8u`

    ret

; Função genérica de delay em assembly AVR
; @param: r24 - Número de loops para o delay
;         Cada loop gera aproximadamente 4 ciclos de clock.
delay:
    mov temp, r24       ; Copia o valor de r24 (número de loops) para temp
delay_loop:
    dec temp            ; Decrementa o contador de loops
    brne delay_loop     ; Se o valor de temp não for zero, continue no loop
    ret                 ; Retorna quando o delay terminar



; TRATAMENTO DA INTERRUPÇÃO DE TIMER
OCI1A_Interrupt:
push r16
in r16, SREG
push r16


; incrementa o contador de controle
; de estados
inc contador
; chama a função responsável por incrementar o
; contador do semáforo
; NOTA: os autores estão cientes que isso não está
; em boas práticas, porém foi visto como necessário
; e em sua implementação atual não traz riscos ao programa.
rcall inc_semaforo

pop r16
out SREG, r16
pop r16
reti