main:
LDA #3
STA $01
LDA #15
STA $02
JSR multiply ; 15 * 3 = 45?
LDY $03
BRK
multiply: ; ($01) * ($02) = $($03)
LDA #$00
loop:
ADC $01
INX
CPX $02
BNE loop
STA $03
RTS
