ORG 0000H

MAIN:
    MOV R1, #100      ; R1 = 10
    SETB P0.0          ; LED aus (P0.0 = 1 = aus, aktiv low)

COUNT_DOWN:
    DJNZ R1, COUNT_DOWN ; R1 dekrementieren, solange != 0 weiterspringen

    CLR P0.0           ; LED anschalten (P0.0 = 0 = an, aktiv low)

LOOP:
    SJMP LOOP          ; Endlosschleife, LED bleibt an

END