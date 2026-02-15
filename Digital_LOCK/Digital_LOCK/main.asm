; ======================================================================================
; ATmega64 Security Lock System
; project 3 
;Nima naqavi 40222323
; ======================================================================================

.INCLUDE "M64DEF.INC"

; --- Interrupt Vectors ---
.ORG 0x0000
    JMP MAIN

.ORG 0x0002
    JMP ISR_INT0        ; Input Bit '0'

.ORG 0x0004
    JMP ISR_INT1        ; Input Bit '1'

.ORG 0x0006
    JMP ISR_INT2        ; Switch to USER Mode

.ORG 0x0008
    JMP ISR_INT3        ; Switch to ADMIN Mode

.ORG 0x000A
    JMP ISR_INT4        ; Enter Key / Confirm ID 

.ORG 0x000C
    JMP ISR_INT5        ; Admin Hardware Key Verify

.ORG 0x0020
    JMP ISR_TIMER0      ; Timer0 Overflow (System Tick) 

.ORG 0x0050

; ======================================================================================
; MAIN INITIALIZATION
; ======================================================================================
MAIN:
    ; --- Stack Pointer Setup ---
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

    ; --- Interrupt Setup ---
    ; Enable INT0 - INT5
    LDI R16, 0x3F 
    OUT EIMSK, R16
    
    ; INT0-INT3: Falling Edge
    LDI R16, 0xAA 
    STS EICRA, R16
    
    ; INT4-INT5: Falling Edge
    LDI R16, 0x0A
    OUT EICRB, R16

    LDI R16, 0x07          ; Prescaler = 1024
    OUT TCCR0, R16
    LDI R16, 206           
    OUT TCNT0, R16
    LDI R16, 0x01          ; Enable Timer0 Overflow Interrupt
    OUT TIMSK, R16

    ; --- I/O Port Configuration ---
    CLR R16
    OUT DDRB, R16          ; PORTB = Input (Keypad/ID)
    LDI R16 , 0xFF              
    OUT DDRC, R16          ; PORTC = Output (LEDs)
    OUT PORTC , R16 ;       turn off all LED


    ; --- Register Initialization ---
    LDI R17 ,0x00               ; R17 = System State
    LDI R18 ,0x00               ; R18 = Admin Intropt
    LDI R19 ,0x00               ; R19 = Intropt 4
    LDI R20 ,0x00               ; R20 = Timer Counter
    LDI R21, 20                 ; R21 = Tolerance value
    LDI R22 ,0x00               ; LED sycle counter
    LDI R23 ,0x00               ; R23 = User ID 
    LDI R24 ,0x00               ; R24 = Bit Counter
    LDI R25 ,0x00               ; R25 = Math Temp 
    LDI R26 ,0x00               ; R26 = EEPROM Address Low
    LDI R27 ,0x00               ; R27 = Data Buffer
    
    ; Pointer Initialization
    ; Y Pointer (R29:R28) -> RAM Buffer for EEPROM Data (0x0200)
    LDI R28 , 0x00
    LDI R29 , 0x02
    ; Z Pointer (R31:R30) -> RAM Buffer for User Input (0x0100)
    LDI R30 , 0x00
    LDI R31 , 0x01

    SEI                    ; Enable Global Interrupts

; ======================================================================================
; MAIN LOOP (STATE MACHINE)
; ======================================================================================
IDLE:
    CBI PORTC, 0           
    CPI R17 , 0x00 
    BREQ IDLE
    
    CPI R17, 0x01          ; Check for ADMIN State
    BREQ ADMIN

    CPI R17, 0x02          ; Check for USER State
    BREQ USER
    
    JMP IDLE

    ; --- State: ADMIN (Registration) ---
ADMIN:
    SBI PORTC, 0
    
    CALL CHECK_ADMIN_KEY   
    CPI R18, 0x02          ; Check if success (0x02)
    BRNE ADMIN_EXIT
    
    CALL RED_LED
    
    CBI PORTC, 2
    CALL GET_INPUT_ID
    SBI PORTC, 2
    
    CALL RED_LED
    CBI PORTC, 2
    CALL CREATE_PASSWORD   
    SBI PORTC, 2
    
    CALL GREEN_LED

ADMIN_EXIT:
    LDI R17, 0x00          ; Reset State
    JMP IDLE

; --- State: USER (Login) ---
USER:
    SBI PORTC, 0           
    
    CALL YELLOW_LED
    
    ; 1. Get User ID
    CBI PORTC, 7           ; Indicator: Waiting for ID
    CALL GET_INPUT_ID      ; Wait for INT4
    SBI PORTC, 7
    
    ; 2. Get Pattern
    CALL YELLOW_LED        
    SBI PORTC, 7
    
    ; 3. Verify Pattern against EEPROM
    CALL VERIFY_PATTERN
    
    SBI PORTC, 7
    LDI R17, 0x00          ; Reset State
    JMP IDLE

; ======================================================================================
; INTERRUPT SERVICE ROUTINES (ISRs)
; ======================================================================================

; --- INT0: Input Bit '0' ---
ISR_INT0:
    PUSH R16
    IN R16, SREG
    PUSH R16
    
    CPI R24, 4             ; Check bit counter (R24)
    BRCC ISR0_EXIT         ; If 4 bits already received, ignore
    
    ST Z+, R20             ; Store interval (R20 Timer) in RAM
    JMP ISR0_PROCESS
    
ISR0_PROCESS:
    CLR R20                ; Reset Timer (R20)
    CLC                    ; Clear Carry (0)
    ROL R27                ; Shift '0' into Pattern Register (R27)
    INC R24                ; Increment bit counter
    
ISR0_EXIT:
    POP R16
    OUT SREG, R16
    POP R16
    RETI

; --- INT1: Input Bit '1' ---
ISR_INT1:
    PUSH R16
    IN R16, SREG
    PUSH R16
    
    CPI R24, 4
    BRCC ISR1_EXIT

    ST Z+, R20             ; Store interval (R20 Timer) in RAM
    JMP ISR1_PROCESS
    
ISR1_PROCESS:
    CLR R20               
    SEC                    
    ROL R27                
    INC R24

ISR1_EXIT:
    POP R16
    OUT SREG, R16
    POP R16
    RETI

; --- State Change Interrupts ---
ISR_INT2:
    LDI R17, 0x02          ; Set State to USER
    RETI

ISR_INT3:
    LDI R17, 0x01          ; Set State to ADMIN
    RETI

; --- Control Signals ---
ISR_INT4:
    LDI R19, 0x01          
    RETI

ISR_INT5:
    LDI R18, 0x01          
    RETI

; --- Timers ---
ISR_TIMER0:
    LDI R16, 206
    OUT TCNT0, R16
    INC R20                ; Increment Global Timer (R20)
    RETI

; ======================================================================================
; LOGIC SUBROUTINES
; ======================================================================================

; --- Wait for ID Input ---
GET_INPUT_ID:
    CLR R19               
WAIT_ID:
    CPI R19, 0x01
    BRNE WAIT_ID
    IN R23, PINB           
    CLR R19
    RET

CHECK_ADMIN_KEY:
    CPI R18, 0x01          
    BRNE CHECK_ADMIN_KEY   
    CLR R18                
    
    IN R22, PINB           
    LDI R21, 20            
    MUL R22, R21          
    
    MOV R25, R0           
    MOV R24, R0         
    
    ADD R25, R21       
    SUB R24, R21          
    CLR R20             
    
ADMIN_VERIFY_LOOP:
    CPI R18, 0x01         
    BRNE ADMIN_VERIFY_LOOP
    
    CP R25, R20           
    BRCS ADMIN_FAIL
    CP R20, R24
    BRCS ADMIN_FAIL
    
    CLR R25               
    CLR R24
    LDI R18, 0x02        
    RET
    
ADMIN_FAIL:
    CLR R25               
    CLR R24
    CLR R18                
    RET

	; ======================================================================================
; LED ROUTINES (Using R20 as Timer)
; ======================================================================================

YELLOW_LED:
    CLR R20                
    CLR R22               
Y_ON:
    CPI R22, 4            
    BREQ Y_END_LOOP
    
    CBI PORTC, 6          
    CPI R20, 12          
    BRCC Y_OFF_WAIT
    JMP Y_ON
    
Y_OFF_WAIT:
    CLR R20              
    INC R22
    INC R22
    
Y_OFF:
    SBI PORTC, 6          
    CPI R20, 8             
    BRCC Y_ON_RESTART
    JMP Y_OFF
    
Y_ON_RESTART:
    CLR R20              
    JMP Y_ON
    
Y_END_LOOP:
    RET

RED_LED:
    CLR R20             
    CLR R22
R_ON:
    CPI R22, 4
    BREQ R_END_LOOP
    
    CBI PORTC, 1        
    CPI R20, 12          
    BRCC R_OFF_WAIT
    JMP R_ON
    
R_OFF_WAIT:
    CLR R20
    INC R22
    INC R22
    
R_OFF:
    SBI PORTC, 1        
    CPI R20, 8        
    BRCC R_ON_RESTART
    JMP R_OFF
    
R_ON_RESTART:
    CLR R20
    JMP R_ON

R_END_LOOP:
    RET

GREEN_LED:
    CLR R20             
    CLR R22
G_ON:
    CPI R22, 4
    BREQ G_END_LOOP
    
    CBI PORTC, 3         
    CPI R20, 12            
    BRCC G_OFF_WAIT
    JMP G_ON
    
G_OFF_WAIT:
    CLR R20
    INC R22
    INC R22
    
G_OFF:
    SBI PORTC, 3       
    CPI R20, 8       
    BRCC G_ON_RESTART
    JMP G_OFF
    
G_ON_RESTART:
    CLR R20
    JMP G_ON

G_END_LOOP:
    RET

; ======================================================================================
; EEPROM & PATTERN LOGIC
; ======================================================================================

VERIFY_PATTERN:
    CLR R24                
    CLR R25             
    CLR R27              
   
    CALL CALC_EEPROM_ADDR
    
  
    MOV R30, R26          
    CLR R20                
    
WAIT_PATTERN_INPUT:
    CPI R24, 4
    BRCS WAIT_PATTERN_INPUT
  
    CLR R24
    ST Z+, R27             
    
    MOV R30, R26         
    MOV R28, R26        
   
READ_EEPROM_BLOCK:
    SBIC EECR, EEWE        
    JMP READ_EEPROM_BLOCK
    
    OUT EEARH, R31     
    OUT EEARL, R30     
    SBI EECR, EERE     
    IN R27, EEDR
    
    ST Y+, R27          
    
    INC R24
    INC R30
    CPI R24, 5            
    BRCS READ_EEPROM_BLOCK
    
    CLR R24
    CLR R23             
    MOV R30, R26        
    MOV R28, R26
    
COMPARE_LOOP:
    INC R24
    CPI R24, 5
    BRCC COMPARE_FINAL
    
    LD R27, Y+             
    LD R17, Z+           
    
    LDI R16, 20            
    ADD R27, R16          
    CP R27, R17
    BRCS COMPARE_LOOP      
    
    SUB R27, R16
    SUB R27, R16           
    CP R17, R27
    BRCS COMPARE_LOOP      
    
    INC R23                
    JMP COMPARE_LOOP

COMPARE_FINAL:
    LD R27, Y          
    LD R17, Z
    CP R27, R17
    BRNE RESULT_DISPLAY
    INC R23                

RESULT_DISPLAY:
    CPI R23, 5          
    BRCC ACCESS_GRANTED
    
ACCESS_DENIED:
    CALL RED_LED
    RET
ACCESS_GRANTED:
    CALL GREEN_LED
    RET


CREATE_PASSWORD:
    CLR R24
    CLR R27
    
    CALL CALC_EEPROM_ADDR
    
    MOV R30, R26        
    
    CLR R20            
WAIT_NEW_PATTERN:
    CPI R24, 4
    BRCS WAIT_NEW_PATTERN
 
    ST Z+, R27           
    MOV R30, R26       
    
    CLR R24
EEPROM_WRITE_LOOP:
    CLI                   
    
WAIT_WE:
    SBIC EECR, EEWE
    JMP WAIT_WE
    
    INC R24
    CPI R24, 6
    BRCC WRITE_DONE
    
    OUT EEARH, R31
    OUT EEARL, R30
    
    LD R27, Z+             
    OUT EEDR, R27
    
    SBI EECR, EEMWE     
    SBI EECR, EEWE         
    JMP WAIT_WE

WRITE_DONE:
    SEI
    RET

CALC_EEPROM_ADDR:
    MOV R26, R23           
    LDI R16, 5
    MUL R26, R16        
    MOV R26, R0        
    CLR R27           
    RET
