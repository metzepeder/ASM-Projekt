;-------------------------------------------------
; Reaction Game
; Automatischer Start → LED an → Reaktionszeit messen
;
; P2.0 = 1er Hundertstel  => R2
; P2.1 = 10er Hundertstel => R3
; P2.2 = 1er Sekunden     => R4
; P2.3 = 10er Sekunden    => R5
;
; Reaktion = P1.1
; Reset    = P1.2
; LED      = P0.0
;
; State (30h): 01=WAITING, 02=ACTIVE, 03=RESULT
; RandDelay (31h): Verzögerungs-Zähler
; RandSeed  (32h): Freier Zähler als Zufallsquelle
;-------------------------------------------------
cseg at 0h
ajmp init
cseg at 100h

;-------------------------------------------------
; Interrupt für TIMER0: Einsprung bei 0Bh
;-------------------------------------------------
ORG 0Bh
call timer
reti

ORG 20h
init:
    mov IE, #10010010b    ; Global + Timer0 Interrupt
    mov tmod, #00000010b  ; Timer0 Mode 2 (8-bit auto-reload)
    mov tl0, #0c0h
    mov th0, #0c0h
    mov r1, #00h          ; ISR Tick-Zähler
    mov r6, #00h          ; Reaktionszeit: Hundertstel
    mov r7, #00h          ; Reaktionszeit: Sekunden
    ; 32h wird nicht zurückgesetzt (Zufallsquelle läuft durch)
    clr P0.0              ; LED aus
    setb tr0              ; Timer dauerhaft starten
    ; Zufälligen Delay berechnen und direkt WAITING starten
    mov a, 32h
    anl a, #3Fh           ; Maske 0-63
    add a, #14h           ; Minimum 20 → Bereich: 20-83 Ticks
    mov 31h, a
    mov 30h, #01h         ; State = WAITING
    call zeigen

;-------------------------------------------------
; Hauptschleife
;-------------------------------------------------
anfang:
    jnb p1.2, do_reset        ; P1.2: Reset + Neustart (jederzeit)
    mov a, 30h
    cjne a, #02h, anfang      ; nur in ACTIVE auf Reaktionstaste prüfen
    jnb p1.1, do_react        ; ACTIVE: Reaktionstaste (P1.1)
    ajmp anfang

do_react:
    mov 30h, #03h             ; State = RESULT
    clr P0.0                  ; LED aus
    call zeigen
    ajmp anfang

do_reset:
    ljmp init                 ; Reset + Neustart

;-------------------------------------------------
; Timer ISR
;-------------------------------------------------
timer:
    inc 32h                   ; Zufalls-Seed läuft immer
    inc r1
    cjne r1, #02h, nuranzeige
    mov r1, #00h
    call gamelogic
    ret

nuranzeige:
    call display
    ret

;-------------------------------------------------
; Spiellogik (je Tick aus der ISR)
;-------------------------------------------------
gamelogic:
    mov a, 30h
    cjne a, #01h, check_gl_active

    ; WAITING: Delay herunterzählen bis LED angeht
    djnz 31h, gl_ret
    setb P0.0                 ; LED an
    mov 30h, #02h             ; State = ACTIVE
    mov r6, #00h
    mov r7, #00h
    call zeigen
    ret

check_gl_active:
    cjne a, #02h, gl_ret

    ; ACTIVE: Reaktionszeit hochzählen
    call countup
    ret

gl_ret:
    call zeigen
    ret

;-------------------------------------------------
; Reaktionszeit in Hundertstel-Sekunden hochzählen
; Maximum: 9.99 Sekunden → Timeout
;-------------------------------------------------
countup:
    inc r6
    cjne r6, #64h, zeigen_ret ; noch keine 100 Hundertstel
    mov r6, #00h
    inc r7
    cjne r7, #0Ah, zeigen_ret ; noch keine 10 Sekunden
    ; Timeout: zu langsam → fixiere Anzeige auf 9.99
    mov r7, #09h
    mov r6, #63h
    mov 30h, #03h             ; State = RESULT
    clr P0.0                  ; LED aus

zeigen_ret:
    call zeigen
    ret

;-------------------------------------------------
; zeigen: BCD-Wandlung und Segment-Lookup
;-------------------------------------------------
zeigen:
    mov DPTR, #table
    mov a, R6
    mov b, #0ah
    div ab
    mov R0, a
    movc a,@a+dptr
    mov r3, a
    mov a, r0
    xch a,b
    movc a, @a+dptr
    mov r2, a
    mov a, R7
    mov b, #0ah
    div ab
    mov R0, a
    movc a,@a+dptr
    mov r5, a
    mov a, r0
    xch a,b
    movc a, @a+dptr
    mov r4, a
    call display
    ret

;-------------------------------------------------
; display: Multiplext 4-stellige 7-Segment-Anzeige
;-------------------------------------------------
display:
    mov P3, R2
    clr P2.0
    setb P2.0

    mov P3, R3
    clr P2.1
    setb P2.1

    mov P3, R4
    clr P2.2
    setb P2.2

    mov P3, R5
    clr P2.3
    setb P2.3

    ret

;-------------------------------------------------
; TABLE: 7-Segment-Kodierung für 0-9
;-------------------------------------------------
org 300h
table:
db 11000000b
db 11111001b, 10100100b, 10110000b
db 10011001b, 10010010b, 10000010b
db 11111000b, 10000000b, 10010000b

end
