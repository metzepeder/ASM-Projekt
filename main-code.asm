;==============================================================
; Reaktionszeitmesser fuer 8051
;
; Hardware:
;   P1.0 = LED (Startsignal, aktiv LOW)
;   P3.2 = Taster (INT0, aktiv LOW)
;   P2   = 7-Segment Anzeige Datenleitungen
;   P0.0 = Digit-Select Stelle 1 (Hunderter ms)
;   P0.1 = Digit-Select Stelle 2 (Zehner ms)
;   P0.2 = Digit-Select Stelle 3 (Einer ms)
;
; Ablauf:
;   1. Zufaellige Wartezeit (1 - 15 s, LFSR-RNG)
;   2. LED leuchtet auf
;   3. Spieler drueckt Taster
;   4. Reaktionszeit wird in ms auf Display angezeigt
;   5. Bei False Start (zu frueh): Neustart
;
; Takt: 12 MHz  ->  1 Maschinenzyklus = 1 us
;       Timer-0 Mode 1 (16-bit), Reload fuer 1 ms: 64536 = FC18H
;==============================================================

; --- Speicherbereiche (iRAM) ---
REACT_H     EQU 30H     ; Reaktionszeit High-Byte (ms)
REACT_L     EQU 31H     ; Reaktionszeit Low-Byte  (ms)
RAND_SEED   EQU 32H     ; Zufallszahl (LFSR-Zustand)
DISP_1      EQU 33H     ; Segmentwert Stelle 1 (Hunderter)
DISP_2      EQU 34H     ; Segmentwert Stelle 2 (Zehner)
DISP_3      EQU 35H     ; Segmentwert Stelle 3 (Einer)
STATE       EQU 36H     ; Zustandsvariable

; State-Konstanten
ST_WAIT     EQU 00H     ; Warten / Zufallsverzoegerung
ST_MEASURE  EQU 01H     ; LED an, Zeit wird gemessen
ST_SHOW     EQU 02H     ; Ergebnis anzeigen


LED     EQU P1.0    ; Port 1, Bit 0
BUTTON  EQU P3.2    ; Port 3, Bit 2 (INT0)

; --- Timer-0 Reload fuer 1 ms bei 12 MHz ---
; 65536 - 1000 = 64536 = FC18H
T0_RELOAD_H EQU 0FCH
T0_RELOAD_L EQU 018H

; --- Maximale Messzeit: 999 ms = 03E7H ---
REACT_MAX_H EQU 03H
REACT_MAX_L EQU 0E7H

;==============================================================
; RESET- UND INTERRUPT-VEKTOREN
;==============================================================
    ORG 0000H
    LJMP MAIN               ; Reset-Vektor

    ORG 0003H               ; INT0-Vektor (Taster)
    LJMP ISR_BUTTON

    ORG 000BH               ; Timer-0-Vektor (ms-Zaehler)
    LJMP ISR_TIMER0

;==============================================================
; HAUPTPROGRAMM
;==============================================================
    ORG 0030H

MAIN:
    MOV SP, #60H

    ; Ports: LED aus (aktiv LOW -> Ausgang HIGH)
    MOV P1, #0FFH
    MOV P2, #00H
    MOV P0, #00H

    ; Zustand und Messvariablen initialisieren
    MOV STATE,     #ST_WAIT
    MOV REACT_H,   #00H
    MOV REACT_L,   #00H
    MOV RAND_SEED, #0A5H    ; LFSR-Startwert (darf nicht 0 sein)

    ; Timer 0: Mode 1 (16-bit), noch gestoppt
    MOV TMOD, #01H
    MOV TH0,  #T0_RELOAD_H
    MOV TL0,  #T0_RELOAD_L

    ; Interrupts: INT0 flankengetriggert, Timer0 und INT0 freigeben
    SETB IT0
    SETB EX0
    SETB ET0
    SETB EA

    ; --- START-BLINK: LED kurz aufleuchten als Bereitschaftssignal ---
    CLR  LED            ; LED an (aktiv LOW)
    MOV  R6, #0FFH     ; \
    BLINK_WAIT:         ;  > kurze Verzoegerung (~50ms bei 12MHz)
    MOV  R7, #0FFH     ;  |
    BW_INNER:           ;  |
    DJNZ R7, BW_INNER  ;  |
    DJNZ R6, BLINK_WAIT ; /
    SETB LED            ; LED aus

LOOP:
    MOV A, STATE
    CJNE A, #ST_WAIT,    CHECK_SHOW

    ; === ST_WAIT: Zufaellig warten, dann LED einschalten ===
    LCALL RANDOM_WAIT
    CLR  LED                ; LED an (aktiv LOW)
    MOV  REACT_H,   #00H
    MOV  REACT_L,   #00H
    MOV  STATE,     #ST_MEASURE
    SETB TR0                ; ms-Zaehler starten
    SJMP LOOP

CHECK_SHOW:
    CJNE A, #ST_SHOW, LOOP

    ; === ST_SHOW: Ergebnis anzeigen, dann Reset ===
    LCALL DISPLAY_RESULT
    SJMP LOOP

;==============================================================
; ISR: Taster (INT0)
; Flankengetriggert - IE0 wird von Hardware geloescht
;==============================================================
ISR_BUTTON:
    PUSH ACC
    MOV  A, STATE
    CJNE A, #ST_MEASURE, FALSE_START

    ; Gueltige Reaktion: Timer stoppen, Zustand wechseln
    CLR  TR0
    SETB LED                ; LED aus
    MOV  STATE, #ST_SHOW
    POP  ACC
    RETI

FALSE_START:
    ; Zu frueh gedrueckt: Reset
    CLR  TR0
    SETB LED                ; LED sicherheitshalber aus
    MOV  STATE, #ST_WAIT
    POP  ACC
    RETI

;==============================================================
; ISR: Timer 0 - zaehlt Millisekunden
; FIX: Addiert Reload-Wert statt absolutem Ueberschreiben,
;      um Jitter durch ISR-Latenz zu kompensieren.
;==============================================================
ISR_TIMER0:
    PUSH ACC
    PUSH B

    ; Praeziser Reload: aktuellen Zaehlerstand + Reload-Wert
    MOV  A, TL0
    ADD  A, #T0_RELOAD_L
    MOV  TL0, A
    MOV  A, TH0
    ADDC A, #T0_RELOAD_H
    MOV  TH0, A

    ; 16-bit Inkrement REACT_H:REACT_L
    INC  REACT_L
    MOV  A, REACT_L
    CJNE A, #00H, ISR_T0_END
    INC  REACT_H

    ; Overflow-Schutz: bei 999 ms stoppen
    MOV  A, REACT_H
    CJNE A, #REACT_MAX_H, ISR_T0_END
    MOV  A, REACT_L
    CJNE A, #REACT_MAX_L, ISR_T0_END
    CLR  TR0
    MOV  STATE, #ST_SHOW    ; direkt zur Anzeige

ISR_T0_END:
    POP  B
    POP  ACC
    RETI

;==============================================================
; RANDOM_WAIT: Zufaellige Wartezeit ~1 - 15 s (max. 15 s)
;
; Struktur: R2 Bloecke, je Block R5*R4 Iterationen
;   R2  = 1-15  (unteres Nibble RAND_SEED nach Warmup)
;   R5  = 255   (aeussere Iterationen pro Block)
;   R4  = 255   (innere Iterationen)
;   Pro innere Iteration: LCALL LFSR_STEP + DJNZ ~ 15 us
;   Pro Block: 255 * 255 * 15 us ~ 975 ms ~ 1 s
;   Gesamt:     1 * 975 ms .. 15 * 975 ms  ~  1 - 15 s
;==============================================================
RANDOM_WAIT:
    MOV  P2, #00H
    MOV  P0, #00H
    SETB LED                ; LED aus

    ; LFSR 32x vorlaufen lassen fuer mehr Entropie
    MOV  R6, #20H
RW_WARMUP:
    LCALL LFSR_STEP
    DJNZ R6, RW_WARMUP

    ; Anzahl Sekunden-Bloecke: 1-15 aus unterem Nibble RAND_SEED
    MOV  A, RAND_SEED
    ANL  A, #0FH            ; 0-15
    JNZ  RW_CNT_OK
    INC  A                  ; 0 -> 1 (Sicherheit, LFSR liefert nie 0)
RW_CNT_OK:
    MOV  R2, A              ; 1-15 Bloecke

RW_BLOCKS:
    MOV  R5, #0FFH
RW_OUTER:
    MOV  R4, #0FFH
RW_INNER:
    LCALL LFSR_STEP
    DJNZ R4, RW_INNER
    DJNZ R5, RW_OUTER
    DJNZ R2, RW_BLOCKS
    RET

;==============================================================
; LFSR_STEP: 8-bit Galois-LFSR
; Polynom: x^8 + x^6 + x^5 + x^4 + 1  (Rueckkopplungsmaske B8H)
; FIX: CLR C vor RLC sichert definierten Eingang;
;      dead-code XRL entfernt.
;==============================================================
LFSR_STEP:
    MOV  A, RAND_SEED
    CLR  C
    RLC  A                  ; MSB -> Carry, 0 kommt von rechts rein
    JNC  LFSR_NO_XOR
    XRL  A, #0B8H           ; Galois-Rueckkopplung
LFSR_NO_XOR:
    MOV  RAND_SEED, A
    RET

;==============================================================
; DISPLAY_RESULT: Reaktionszeit (0-999 ms) auf 3 Stellen zeigen
; FIX: Berechnung aus dem vollen 16-bit-Wert REACT_H:REACT_L.
;      Anzeige per Multiplexing fuer ~200 Zyklen, dann STATE 0.
;==============================================================
DISPLAY_RESULT:
    ; --- 16-bit-Wert REACT_H:REACT_L -> Dezimalstellen ---
    ; Strategie: Hunderter = Ganzzahlanteil / 100
    ;            Rest -> Zehner und Einer wie bisher
    ;
    ; Da Maximum 999 ms = 03E7H, ist REACT_H maximal 3.
    ; Hunderter = REACT_H * 256/100 + REACT_L/100
    ; Einfacher: Hunderter direkt per Schleife subtrahieren.

    ; Schritt 1: Hunderter aus 16-bit-Wert
    MOV  A, REACT_H
    MOV  B, REACT_L
    MOV  R0, #00H           ; Hunderterzaehler

DR_HUNDRED:
    ; Subtrahiere 100 (= 0064H) solange >= 100
    MOV  A, B
    SUBB A, #64H            ; Low-Byte - 100 (C gesetzt wenn Borrow)
    JC   DR_HUNDRED_DONE
    MOV  B, A               ; Low-Byte-Rest merken
    MOV  A, REACT_H
    ; REACT_H muss Borrow beruecksichtigen (bereits in C)
    SUBB A, #00H            ; zieht Carry ab
    JC   DR_HUNDRED_DONE    ; REACT_H wurde negativ -> fertig
    MOV  REACT_H, A
    INC  R0
    SJMP DR_HUNDRED

DR_HUNDRED_DONE:
    ; Hunderterstelle wiederherstellen (letzte Subtraktion rueckgaengig)
    MOV  DISP_1, R0

    ; Schritt 2: Zehner aus verbliebendem Rest in B (0-99)
    MOV  A, B
    MOV  B, #10
    DIV  AB
    MOV  DISP_2, A          ; Zehner
    MOV  DISP_3, B          ; Einer

    ; Schritt 3: Multiplexing ~200 Durchlaeufe
    MOV  R3, #200

DISP_LOOP:
    MOV  A, DISP_1
    LCALL SEG_LOOKUP
    MOV  P2, A
    MOV  P0, #01H
    LCALL SHORT_DELAY

    MOV  A, DISP_2
    LCALL SEG_LOOKUP
    MOV  P2, A
    MOV  P0, #02H
    LCALL SHORT_DELAY

    MOV  A, DISP_3
    LCALL SEG_LOOKUP
    MOV  P2, A
    MOV  P0, #04H
    LCALL SHORT_DELAY

    DJNZ R3, DISP_LOOP

    ; Display aus, Zustand zuruecksetzen
    MOV  P2, #00H
    MOV  P0, #00H
    MOV  STATE, #ST_WAIT
    RET

;==============================================================
; SEG_LOOKUP: Ziffer (0-9) -> 7-Segment-Muster
; Common Cathode, aktiv HIGH
; Eingabe:  A = Ziffer
; Ausgabe:  A = Segmentmuster
;==============================================================
SEG_LOOKUP:
    MOV  DPTR, #SEG_TABLE
    MOVC A, @A+DPTR
    RET

;==============================================================
; SHORT_DELAY: ~100 us Verzoegerung fuer Display-Multiplexing
;==============================================================
SHORT_DELAY:
    MOV  R7, #80H
SD_LOOP:
    DJNZ R7, SD_LOOP
    RET

;==============================================================
; 7-SEGMENT-TABELLE (Common Cathode, aktiv HIGH)
; FIX: Hierher verschoben (war vor ORG 0000H -> ueberschrieb
;      den Reset-Vektor mit Datenbytes).
; Index: 0  1    2    3    4    5    6    7    8    9
;==============================================================
SEG_TABLE:
    DB 3FH, 06H, 5BH, 4FH, 66H, 6DH, 7DH, 07H, 7FH, 6FH

    END
