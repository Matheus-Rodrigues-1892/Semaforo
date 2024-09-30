
.cseg

ldi r28, 9
ldi r16, $FF ;set PORTD for output
out DDRD, temp

bcd:
    ; Usa o valor no r28 como �ndice na tabela
    ldi r30, low(table) ; carrega o endere�o da tabela
    ldi r31, high(table)
    mov r29, r28        ; copia o d�gito a ser convertido
    clr r28             ; limpa r24 para usar como �ndice
    add r30, r29        ; adiciona o �ndice � base da tabela
    ; Pega o valor correspondente na tabela
    lpm r28, Z          ; r24 agora cont�m o valor para o display
    out PORTD, r28      ; envia o valor para o PORTD
    ret