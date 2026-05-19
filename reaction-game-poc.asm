;-------------------------------------------------
;Countdown / Zaehlt auf Null
;in Minuten und Sekunden
;
; mit 4x7-segment anzeige
;
; P2.0 =  1er Sekunden => P3=R2
; P2.1 = 10er Sekunden => P3=R3
; P2.2 =  1er Minuten  => P3=R4
; P2.3 = 10er Minuten  => P3=R5
;
; Hauptprogrammschleife
;
; Start = P1.0
; Stop  = P1.1
; Reset = P1.2
;
; P0.0 = Merker RESET
; P0.1 = Lampe (1=aus, 0=an)
; 30h  = Vorcountdown (10 Sek)
; -------------------------------------------------
cseg at 0h ; Alles was jetzt kommt an Adresse 0 im Speicher
ajmp init ; Das hier wird direkt ausgeführt
cseg at 0Bh ; Wenn Timer abläuft dann führ das aus
call timer
reti ; Ende des Interrupts
;-------------------------------------------------------
; init
;-------------------------------------------------------
ORG 20h ; freie Adresse
init:
mov IE, #10010010b
mov tmod, #00000010b
mov r7, #00h        ; Minuten
mov r6, #00h        ; Sekunden
mov r1, #00h        ; Interrupt-Zähler
mov tl0, #0c0h
mov th0, #0c0h
mov P1, #00h
setb P0.0           ; Merker für RESET
setb P0.1           ; Lampe aus
mov 30h, #64h       ; 10 Sekunden Vorcountdown
call zeigen
initGame:
mov IE, #10010010b
mov tmod, #00000010b
mov r1, #00h        ; Interrupt-Zähler
mov tl0, #0c0h
mov th0, #0c0h
mov P1, #00h
setb P0.0           ; Merker für RESET
setb P0.1           ; Lampe aus
mov 30h, #64h       ; 10 Sekunden Vorcountdown
call zeigen
;---------------------------
anfang:
clr P0.0
jnb p1.0, starttimer
jnb p1.1, stoptimer
nurRT:
jnb p1.2, RT
jnb tr0, da
ajmp anfang
da:
jb P0.1, anfang     ; Lampe aus = Vorcountdown läuft, kein Display
call display
ajmp anfang
;------------------------------
starttimer:
setb tr0
setb P1.0
ajmp anfang
stoptimer:
clr tr0
setb P1.1
ajmp anfang
RT:
clr tr0
setb P1.2
ljmp initGame
;---------------------------------------------
; timer ISR
;---------------------------------------------
timer:
mov a, 30h
jnz vorcountdown
; Vorcountdown fertig, normale Stoppuhr
inc r1
cjne r1, #02h, nuranzeige
mov r1, #00h
call countup
ret
nuranzeige:
call display
ret
;---------------------------------------------
; vorcountdown: 100-Sek still runterzaehlen
;---------------------------------------------
vorcountdown:
inc r1
cjne r1, #02h, cdwait
mov r1, #00h
dec 30h
mov a, 30h
jnz cdwait
clr P0.1            ; Lampe AN
cdwait:
ret
;---------------------------------------------
; countup: Stoppuhr hochzaehlen
;---------------------------------------------
countup:
inc r6
cjne r6, #3ch, sekunden
mov r6, #00h
inc r7
cjne r7, #63h, minuten
hupe:
clr tr0
ret
minuten:
call zeigen
ret
sekunden:
call zeigen
ret
;-------------------------------------------------------
; zeigen
;-------------------------------------------------------
zeigen:
mov DPTR, #table
mov a, R6
mov b, #0ah
div ab
mov R0, a
movc a, @a+dptr
mov r3, a
mov a, r0
xch a, b
movc a, @a+dptr
mov r2, a
mov a, R7
mov b, #0ah
div ab
mov R0, a
movc a, @a+dptr
mov r5, a
mov a, r0
xch a, b
movc a, @a+dptr
mov r4, a
call display
ret
;-----------------------------------------------zeigen:
mov DPTR, #table
mov a, R6
mov b, #0ah
div ab
mov R0, a
movc a, @a+dptr
mov r3, a
mov a, r0
xch a, b
movc a, @a+dptr
mov r2, a
mov a, R7
mov b, #0ah
div ab
mov R0, a
movc a, @a+dptr
mov r5, a
mov a, r0
xch a, b
movc a, @a+dptr
mov r4, a
call display
ret
;-----------------------------------------------
; display
;-----------------------------------------------
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
; TABLE
;-------------------------------------------------
org 300h
table:
db 11000000b
db 11111001b, 10100100b, 10110000b
db 10011001b, 10010010b, 10000010b
db 11111000b, 10000000b, 10010000b
end

; display
;-----------------------------------------------
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
; TABLE
;-------------------------------------------------
org 300h
table:
db 11000000b
db 11111001b, 10100100b, 10110000b
db 10011001b, 10010010b, 10000010b
db 11111000b, 10000000b, 10010000b
end