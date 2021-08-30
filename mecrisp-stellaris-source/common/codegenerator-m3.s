@
@    Mecrisp-Stellaris - A native code Forth implementation for ARM-Cortex M microcontrollers
@    Copyright (C) 2013  Matthias Koch
@
@    This program is free software: you can redistribute it and/or modify
@    it under the terms of the GNU General Public License as published by
@    the Free Software Foundation, either version 3 of the License, or
@    (at your option) any later version.
@
@    This program is distributed in the hope that it will be useful,
@    but WITHOUT ANY WARRANTY; without even the implied warranty of
@    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
@    GNU General Public License for more details.
@
@    You should have received a copy of the GNU General Public License
@    along with this program.  If not, see <http://www.gnu.org/licenses/>.
@

@ Code generator for M3 and M4


  @ Is constant within the possibilities of the long movs/mvns Opcode ?
  @ Can this constant be generated by rotating an 8 bit value ?

  @ 8 Bit constant: 0000 00XY is encoded as | 0000 | XY |
  @                 00XY 00XY is encoded as | 0001 | XY |
  @                 XY00 XY00 is encoded as | 0010 | XY |
  @                 XYXY XYXY is encoded as | 0011 | XY |
  

@ The assembler encodes the constant in an instruction into imm12, as described below. imm12 is mapped
@ into the instruction encoding in hw1[10] and hw2[14:12,7:0], in the same order.

@ Shifted 8-bit values
@ If the constant lies in the range 0-255, then imm12 is the unmodified constant.
@ Otherwise, the 32-bit constant is rotated left until the most significant bit is bit[7]. The size of the left
@ rotation is encoded in bits[11:7], overwriting bit[7]. imm12 is bits[11:0] of the result.

@ For example, the constant 0x01100000 has its most significant bit at bit position 24. To rotate this bit to
@ bit[7], a left rotation by 15 bits is required. The result of the rotation is 0b10001000. The 12-bit encoding of
@ the constant consists of the 5-bit encoding of the rotation amount 15 followed by the bottom 7 bits of this
@ result, and so is 0b011110001000.

@ Constants of the form 0x00XY00XY
@ Bits[11:8] of imm12 are set to 0b0001, and bits[7:0] are set to 0xXY.
@ This form is UNPREDICTABLE if bits[7:0] == 0x00.

@ Constants of the form 0xXY00XY00
@ Bits[11:8] of imm12 are set to 0b0010, and bits[7:0] are set to 0xXY.
@ This form is UNPREDICTABLE if bits[7:0] == 0x00.

@ Constants of the form 0xXYXYXYXY
@ Bits[11:8] of imm12 are set to 0b0011, and bits[7:0] are set to 0xXY.
@ This form is UNPREDICTABLE if bits[7:0] == 0x00.

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "12bitencoding" @ ( x -- bitmask true | x false )
twelvebitencoding:
@ -----------------------------------------------------------------------------
  push {r0, r1, r2, r3, lr}

  @ If this is a 8 bit constant, the encoding is finished.
  cmp tos, #255
  bhi 1f
    @ writeln "12bitencoding: 0x000000XY"
    pushdatos       @ True-Flag
    movs tos, #-1
    pop {r0, r1, r2, r3, pc}

1:@ This is not a lowest-8-bits-only constant. 
  @ Check for other possibilities:

  @ 0x00XY00XY

  ands r0, tos, #0x00FF00FF 
  cmp r0, tos
  bne 2f

    movw r1, 0xFFFF
    ands r0, r1
    lsrs r1, tos, #16
    cmp r1, r0
    bne 2f
      @ writeln "12bitencoding: 0x00XY00XY"
      ands tos, #0xFF
      orrs tos, #0x00001000
      pushdatos       @ True-Flag
      movs tos, #-1
      pop {r0, r1, r2, r3, pc}

2: 

  @ 0xXY00XY00

  ands r0, tos, #0xFF00FF00
  cmp r0, tos
  bne 3f

    movw r1, #0xFFFF
    ands r0, r1
    lsrs r1, tos, #16
    cmp r1, r0
    bne 3f
      @ writeln "12bitencoding: 0xXY00XY00"
      lsrs tos, #8
      ands tos, #0xFF
      orrs tos, #0x00002000
      pushdatos       @ True-Flag  
      movs tos, #-1
      pop {r0, r1, r2, r3, pc}

3: 

  @ 0xXYXYXYXY

  movs r2, #0xFF
  movs r1, tos
  ands r1, r2

  lsrs r0, tos, #8
  ands r0, r2
  cmp r0, r1
  bne 4f

  lsrs r0, tos, #16
  ands r0, r2
  cmp r0, r1
  bne 4f

  lsrs r0, tos, #24
  ands r0, r2
  cmp r0, r1
  bne 4f
    @ writeln "12bitencoding: 0xXYXYXYXY"
    ands tos, #0xFF
    orrs tos, #0x00003000
    pushdatos       @ True-Flag   
    movs tos, #-1
    pop {r0, r1, r2, r3, pc}

4: 
    @ 0 of $FF and                                  const. endof \ Plain 8 Bit Constant
    @ 1 of $FF and                 dup 16 lshift or const. endof \ 0x00XY00XY
    @ 2 of $FF and        8 lshift dup 16 lshift or const. endof \ 0xXY00XY00
    @ 3 of $FF and dup 8 lshift or dup 16 lshift or const. endof \ 0xXYXYXYXY

  @ Can we generate this by rotating into an 8 bit constant ?

  movs r0, tos @ Backup of value if we cannot express this as a shifted constant
  movs r1, #0  @ Counter of shifts

5:@ Rotating loop to determine amount of shifts necessary

  adds r1, #1

  @ Rotate left by one bit place
  adds r0, r0, r0
  adcs r0, #0

  @ Does this fit into 8 bits with "msb" set: %1xxx xxxx ?
  movs r2, #0xFFFFFF80
  ands r2, r0
  cmp r2, #0x80
  beq 6f

  @ Not this time.
  cmp r1, #31
  blo 5b

7:@ Fallthrough if not possible to encode constant in 12 bits
  @ writeln "12bitencoding: unknown"
  pushdatos       @ False-Flag
  movs tos, #0
  pop {r0, r1, r2, r3, pc}



6: @ Yes, it can be opcoded as shifted 8-bit constant.
   @ write "12bitencoding: Shifted constant ? "

   @ write " Shift: "
   @ pushda r1
   @ bl hexdot

   @ write " Constant: "
   @ pushda r0
   @ bl hexdot

  cmp r1, #8
  blo 7b

  @ writeln " accepted :-)"

  @ if imm12<11:10> == '00' then Spezialfälle.
  @ We can only opcode this if the topmost 1 bits of shift count are not 00.
  @ At least a shift of "%01 000" = 8 is required. Special cases are encoded below.

  movs tos, r0 @ Shifted constant
  bics tos, #0x80 @ Clear MSB (which is always set here)

  @ Encode shift accordingly
  @ Shift-Bit 0 goes into bit 7 of bitmask
  @ Shift-Bits 1, 2, 3 go into bit 12, 13, 14 of bitmask
  @ Shift-Bit 4 goes into bit 26 of bitmask

  ands r0, r1, #0x1
  lsls r0, #7
  orrs tos, r0

  ands r0, r1, #0xE
  lsls r0, #11
  orrs tos, r0

  ands r0, r1, #0x10
  lsls r0, #22
  orrs tos, r0
   
  pushdatos       @ True-Flag
  movs tos, #-1
  pop {r0, r1, r2, r3, pc}

@ -----------------------------------------------------------------------------
movwkomma: @ Register r0: Konstante                                    Constant
           @ Register r3: Zielregister, fertig geschoben zum Verodern  Destination register, readily shifted to be ORed with opcode.
@ -----------------------------------------------------------------------------
  pushdatos    @ Platz auf dem Datenstack schaffen 
  ldr tos, =0xf2400000 @ Opcode movw r0, #0

  movs r1, #0x0000F000  @ Bit 16 - 13
  ands r2, r0, r1       @ aus der Adresse maskieren   Mask bits of constant
  lsls r2, #4           @ passend schieben            shift them accordingly
  orrs tos, r2          @ zum Opcode hinzufügen       and OR them to opcode.

  movs r1, #0x00000800  @ Bit 12
  ands r2, r0, r1       @ aus der Adresse maskieren   ...
  lsls r2, #15          @ passend schieben
  orrs tos, r2          @ zum Opcode hinzufügen

  movs r1, #0x00000700  @ Bit 11 - 9
  ands r2, r0, r1       @ aus der Adresse maskieren
  lsls r2, #4           @ passend schieben
  orrs tos, r2          @ zum Opcode hinzufügen

  movs r1, #0x000000FF  @ Bit 8 - 1
  ands r2, r0, r1       @ aus der Adresse maskieren
  @ lsrs r2, #0         @ passend schieben
  orrs tos, r2          @ zum Opcode hinzufügen

  @ Füge den gewünschten Register hinzu:  OR desired target register.
  orrs tos, r3
  
  b.n reversekomma @ Insert finished movw Opcode into Dictionary

@ -----------------------------------------------------------------------------
movtkomma: @ Register r0: Konstante                                    Constant
           @ Register r3: Zielregister, fertig geschoben zum Verodern  Destination register, readily shifted to be ORed with opcode.
@ -----------------------------------------------------------------------------
  pushdatos    @ Platz auf dem Datenstack schaffen
  ldr tos, =0xf2c00000 @ Opcode movt r0, #0

  movs r1, #0xF0000000  @ Bit 32 - 29
  ands r2, r0, r1       @ aus der Adresse maskieren
  lsrs r2, #12          @ passend schieben
  orrs tos, r2          @ zum Opcode hinzufügen

  movs r1, #0x08000000  @ Bit 28
  ands r2, r0, r1       @ aus der Adresse maskieren
  lsrs r2, #1           @ passend schieben
  orrs tos, r2          @ zum Opcode hinzufügen

  movs r1, #0x07000000  @ Bit 27 - 25
  ands r2, r0, r1       @ aus der Adresse maskieren
  lsrs r2, #12          @ passend schieben
  orrs tos, r2          @ zum Opcode hinzufügen

  movs r1, #0x00FF0000  @ Bit 24 - 17
  ands r2, r0, r1       @ aus der Adresse maskieren
  lsrs r2, #16          @ passend schieben
  orrs tos, r2          @ zum Opcode hinzufügen

  @ Füge den gewünschten Register hinzu:
  orrs tos, r3

  b.n reversekomma @ Insert finished movt Opcode into Dictionary


@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "registerliteral," @ ( x Register -- )
registerliteralkomma: @ Compile code to put a literal constant into a register.
@ -----------------------------------------------------------------------------
  push {r0, r1, r2, r3, lr}

  popda r3    @ Hole die Registermaske               Fetch register to generate constant for
  lsls r3, #8 @ Den Register um 8 Stellen schieben   Shift register accordingly for opcode generation

  @ Generiere movs-Opcode für sehr kleine Konstanten :-)
  @ Generate short movs Opcode for small constants within 0 and 255

  cmp tos, #0xFF @ Does literal fit in 8 bits ?
  bhi 1f         @ Gewünschte Konstante passt in 8 Bits. 
    @ Generate opcode for movs target, #...
    orrs tos, #0x2000 @ MOVS-Opcode
    orrs tos, r3      @ OR with register
    bl hkomma
    pop {r0, r1, r2, r3, pc}

1:@ Check if constant can be opcoded into a long 32 bit movs opcode.
  bl twelvebitencoding

  cmp tos, #0
  drop @ Preserves Flags !
  beq 2f
    ldr r0, =0xF05F0000 @ movs r0, #imm12 Opcode
    orrs tos, r0
    orrs tos, r3        @ OR with register
    bl reversekomma
    pop {r0, r1, r2, r3, pc}

2:@ Check if constant can be opcoded into a long 32 bit mvns opcode.

  mvns tos, tos @ Invert constant
  bl twelvebitencoding

  cmp tos, #0
  drop @ Preserves Flags !
  beq 3f
    ldr r0, =0xF07F0000 @ mvns r0, #imm12 Opcode
    orrs tos, r0
    orrs tos, r3        @ OR with register
    bl reversekomma
    pop {r0, r1, r2, r3, pc}

3:mvns tos, tos @ Invert back to original constant
  @ Generate a movw/movt Opcode
  b.n movwmovt_register_r3


@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "movwmovt," @ ( x Register -- )
  @ Compile code to put a literal constant into any register.
@ -----------------------------------------------------------------------------
  push {r0, r1, r2, r3, lr}
  
  popda r3    @ Hole die Registermaske               Fetch register to generate constant for
  lsls r3, #8 @ Den Register um 8 Stellen schieben   Shift register accordingly for opcode generation

movwmovt_register_r3:
  popda r0    @ Hole die Konstante                   Fetch constant
  @ Long constant that cannot be encoded in a small and simple way.
  @ Generate movw and movt pairs.

  bl movwkomma

  @ ldr r1, =0xffff0000 @ High-Teil
  @ ands r0, r1 
  @ cmp r0, #0 

  movw r1, #0xFFFF          @ Wenn der High-Teil Null ist, brauche ich keinen movt-Opcode mehr zu generieren.
  ands r0, r0, r1, lsl #16  @ If High-Part is zero there is no need to generate a movt opcode.
  beq 3f

    bl movtkomma @ Bei Bedarf einfügen

3:pop {r0, r1, r2, r3, pc}


@ -----------------------------------------------------------------------------
callkommalang: @ ( Zieladresse -- ) Schreibt einen LANGEN Call-Befehl für does>
               @ Es ist wichtig, dass er immer die gleiche Länge hat.
               @ Writes a long call instruction with known fixed length. 
               @ This is needed for does> as you cannot predict the call target address and 
               @ the shortest instruction length possible needed for it.
@ -----------------------------------------------------------------------------
  @ Dies ist ein bisschen schwierig und muss nochmal gründlich optimiert werden.
  @ Schreibe einen ganz langen Sprung ins Dictionary !
  @ Wichtig für <builds does> wo die Lückengröße vorher festliegen muss.

  push {r0, r1, r2, r3, lr}
  adds tos, #1 @ Ungerade Adresse für Thumb-Befehlssatz   Uneven target address for Thumb instruction set !

  popda r0     @ Zieladresse holen    Destination address
  movs r3, #0  @ Register r0 wählen   Choose register r0
  bl movwkomma
  bl movtkomma

  b.n callkommakurz_intern

@ -----------------------------------------------------------------------------
callkommakurz: @ ( Zieladresse -- )
               @ Schreibt einen Call-Befehl je nach Bedarf.
               @ Wird benötigt, wenn die Distanz für einen BL-Opcode zu groß ist.
               @ Writes a movw-call or a movw-movt-call if destination address is too far away.
@ ----------------------------------------------------------------------------
  @ Dies ist ein bisschen schwierig und muss nochmal gründlich optimiert werden.
  @ Gedanke: Für kurze Call-Distanzen die BL-Opcodes benutzen.

  push {r0, r1, r2, r3, lr}
  adds tos, #1 @ Ungerade Adresse für Thumb-Befehlssatz

  pushdaconst 0 @ Register r0
  bl registerliteralkomma

callkommakurz_intern:
  pushdaconstw 0x4780 @ blx r0
  bl hkomma
  pop {r0, r1, r2, r3, pc}  


@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "call," @ ( Zieladresse -- )
callkomma:  @ Versucht einen möglichst kurzen Aufruf einzukompilieren. 
            @ Write a call to destination with the shortest possible opcodes.
            @ Je nachdem: bl ...                            (4 Bytes)
            @             movw r0, ...              blx r0  (6 Bytes)
            @             movw r0, ... movt r0, ... blx r0 (10 Bytes)
@ ----------------------------------------------------------------------------

  push {r0, r1, r2, r3, lr}
  movs r3, tos @ Behalte Sprungziel auf dem Stack  Keep destination on stack
  @ ( Zieladresse )

  bl here
  popda r0 @ Adresse-der-Opcodelücke  Where the opcodes shall be inserted...
  
  subs r3, r0     @ Differenz aus Lücken-Adresse und Sprungziel bilden   Calculate relative jump offset
  subs r3, #4     @ Da der aktuelle Befehl noch läuft und es komischerweise andere Offsets beim ARM gibt.  Current instruction still running...

  @ 22 Bits für die Sprungweite mit Vorzeichen - 
  @ also habe ich 21 freie Bits, das oberste muss mit dem restlichen Vorzeichen übereinstimmen. 

  @ BL opcodes support 22 Bits jump range - one of that for sign.
  @ Check if BL range is enough to reach target:

  ldr r1, =0xFFC00001   @ 21 Bits frei
  ands r1, r3
  cmp r1, #0  @ Wenn dies Null ergibt, positive Distanz ok.
  beq 1f

  ldr r2, =0xFFC00000
  cmp r1, r2
  beq 1f      @ Wenn es gleich ist: Negative Distanz ok.
    pop {r0, r1, r2, r3, lr}
    b.n callkommakurz @ Too far away - BL cannot reach that destination. Time for long distance opcodes :-)
1:

  @ Within reach of BL. Generate the opcode !

  @ ( Zieladresse )
  drop
  @ ( -- )
  @ BL: S | imm10 || imm11
  @ Also 22 Bits, wovon das oberste das Vorzeichen sein soll.

  @ r3 enthält die Distanz:

  lsrs r3, #1            @ Bottom bit ignored
    ldr r0, =0xF000F800  @ Opcode-Template

    movw r1, #0x7FF       @ Bottom 11 bits of immediate
    ands r1, r3
    orrs r0, r1

  lsrs r3, #11

    movw r1, #0x3FF       @ 10 more bits shifted to second half
    ands r1, r3
    lsls r1, #16
    orrs r0, r1

  lsrs r3, #10         

    ands r1, r3, #1      @ Next bit, treated as sign, shifted into bit 26.
    lsls r1, #26
    orrs r0, r1

  @ Opcode fertig in r0
  pushda r0
  bl reversekomma  @ Write finished opcode into Dictionary.

  pop {r0, r1, r2, r3, pc}

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "literal," @ ( x -- )
literalkomma: @ Save r1, r2 and r3 !
@ -----------------------------------------------------------------------------
  push {r3, lr}

  pushdaconstw 0xf847  @ str tos, [psp, #-4]!
  bl hkomma
  pushdaconstw 0x6d04
  bl hkomma

  pushdaconst 6 @ Gleich in r6=tos legen
  bl registerliteralkomma

  pop {r3, pc}

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "create" @ ANS-Create with default action.
@ -----------------------------------------------------------------------------
  push {lr}
  bl builds

  @ Copy of the inline-code of does>

  @ Universeller Sprung zu dodoes:  Universal jump to dodoes. There has already been a push {lr} before in the definition that calls does>.
  @ Davor ist in dem Wort, wo does> eingefügt wird schon ein push {lr} gewesen.
  movw r0, #:lower16:dodoes+1
  .ifdef does_above_64kb
    movt r0, #:upper16:dodoes+1   @ Dieser Teil ist Null, da dodoes weit am Anfang des Flashs sitzt.  Not needed as dodoes in core is in the lowest 64 kb.
  .endif
  blx r0 @ Den Aufruf mit absoluter Adresse einkompilieren. Perform this call with absolute addressing.


    @ Die Adresse ist hier nicht auf dem Stack, sondern in LR. LR ist sowas wie "TOS" des Returnstacks.
    @ Address is in LR which is something like "TOS in register" of return stack.

  pushdatos
  subs tos, lr, #1 @ Denn es ist normalerweise eine ungerade Adresse wegen des Thumb-Befehlssatzes.  Align address. It is uneven because of Thumb-instructionset bit set.

  pop {pc}

@------------------------------------------------------------------------------
  Wortbirne Flag_inline, "does>"
does: @ Gives freshly defined word a special action.
      @ Has to be used together with <builds !
@------------------------------------------------------------------------------
    @ At the place where does> is used, a jump to dodoes is inserted and
    @ after that a pushda lr to put the address of the definition entering the does>-part
    @ on datastack. This is a very special implementation !

  @ Universeller Sprung zu dodoes:  Universal jump to dodoes. There has already been a push {lr} before in the definition that calls does>.
  @ Davor ist in dem Wort, wo does> eingefügt wird schon ein push {lr} gewesen.
  movw r0, #:lower16:dodoes+1
  .ifdef does_above_64kb
    movt r0, #:upper16:dodoes+1   @ Dieser Teil ist Null, da dodoes weit am Anfang des Flashs sitzt.  Not needed as dodoes in core is in the lowest 64 kb.
  .endif
  blx r0 @ Den Aufruf mit absoluter Adresse einkompilieren. Perform this call with absolute addressing.


    @ Die Adresse ist hier nicht auf dem Stack, sondern in LR. LR ist sowas wie "TOS" des Returnstacks.
    @ Address is in LR which is something like "TOS in register" of return stack.

  pushdatos
  subs tos, lr, #1 @ Denn es ist normalerweise eine ungerade Adresse wegen des Thumb-Befehlssatzes.  Align address. It is uneven because of Thumb-instructionset bit set.

  @ Am Ende des Wortes wird ein pop {pc} stehen, und das kommt prima hin.
  @ At the end of the definition there will be a pop {pc}, that is fine.
  bx lr @ Very important as delimiter as does> itself is inline.

dodoes:
  @ Hier komme ich an. Die Adresse des Teils, der als Zieladresse für den Call-Befehl genutzt werden soll, befindet sich in LR.

  @ The call to dodoes never returns.
  @ Instead, it compiles a call to the part after its invocation into the dictionary
  @ and exits through two call layers.  

  @ Momentaner Zustand von Stacks und LR:  Current stack:
  @    ( -- )
  @ R: ( Rücksprung-des-Wortes-das-does>-enthält )    R:  ( Return-address-of-the-definition-that-contains-does> )
  @ LR Adresse von dem, was auf den does>-Teil folgt  LR: Address of the code following does>

  @ Muss einen Call-Befehl an die Stelle, die in LR steht einbauen.
  @ Generate a long call to the destination in LR that is inserted into the hole alloted by <builds.

  @ Präpariere die Einsprungadresse, die via callkomma eingefügt werden muss.
  @ Prepare the destination address

  pushdatos
  subs tos, lr, #1
               @ Brauche den Link danach nicht mehr, weil ich über die in dem Wort das does> enthält gesicherte Adresse rückspringe
               @ We don't need this Link later because we return with the address saved by the definition that contains does>.
               @ Einen abziehen. Diese Adresse ist schon ungerade für Thumb-2, aber callkomma fügt nochmal eine 1 dazu. 
               @ Subtract one. Adress is already uneven for Thumb-instructionset, but callkomma will add one anyway.

    @ Dictionary-Pointer verbiegen:
      @ Dictionarypointer sichern
      ldr r2, =Dictionarypointer
      ldr r3, [r2] @ Alten Dictionarypointer auf jeden Fall bewahren  Save old Dictionarypointer.

  ldr r1, =Einsprungpunkt @ Get the address the long call has to be inserted.
  ldr r1, [r1] @ r1 enthält jetzt die Codestartadresse der aktuellen Definition.


  .ifdef flash8bytesblockwrite
    @ Special case which has different alignment depending if compiling into Flash (8-even) or into RAM (4-even).

    ldr r0, =Backlinkgrenze
    cmp r3, r0
.ifdef above_ram
    blo.n dodoes_ram
.else
    bhs.n dodoes_ram
.endif

2:    movs r0, #7
      ands r0, r1
      cmp r0, #4
      beq 1f
        adds r1, #2
        b 2b

dodoes_ram:
  .endif

  .ifdef flash16bytesblockwrite
    @ Special case for STM32L476 which has different alignment depending if compiling into Flash (16-even) or into RAM (4-even).

    ldr r0, =Backlinkgrenze
    cmp r3, r0
.ifdef above_ram
    blo.n dodoes_ram
.else
    bhs.n dodoes_ram
.endif

2:    movs r0, #15
      ands r0, r1
      cmp r0, #4
      beq 1f
        adds r1, #2
        b 2b

dodoes_ram:
  .endif

  @ This is to align dictionary pointer to have does> target locations that are always 4-even
  movs r0, #2
  ands r0, r1
  beq 1f
    adds r1, #2
1:
  
  adds r1, #2  @ Am Anfang sollte das neudefinierte Wort ein push {lr} enthalten, richtig ?
               @ Skip the push {lr} opcode in that definition.

  @ Change the Dictionarypointer to insert the long call with the normal comma mechanism.
      str r1, [r2] @ Dictionarypointer umbiegen
  bl callkommalang @ Aufruf einfügen
      str r3, [r2] @ Dictionarypointer wieder zurücksetzen.

  bl smudge
  pop {pc}


@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "<builds"
builds: @ Beginnt ein Defining-Wort.  Start a defining definition.
        @ Dazu lege ich ein neues Wort an, lasse eine Lücke für den Call-Befehl. Create a new definition and leave space for inserting the does>-Call later.
        @ Keine Strukturkennung  No structure pattern matching here !
@ -----------------------------------------------------------------------------
  push {lr}
  bl create       @ Neues Wort wird erzeugt

  .ifdef flash8bytesblockwrite
    @ It is necessary when Flash writes are aligned on 8.
    @ So if we are compiling into Flash, we need to make sure that
    @ the block the user might write to later is properly aligned.
    ldr r0, =Dictionarypointer
    ldr r1, [r0]

    ldr r2, =Backlinkgrenze
    cmp r1, r2
.ifdef above_ram
    blo.n builds_ram
.else
    bhs.n builds_ram
.endif

      @ See where we are. The sequence written for <builds does> is 12 Bytes long on M3/M4.
      @ So we need to advance to 8n + 4 so that the opcode sequence ends on a suitable border.

2:    bl here
      movs r0, #7
      ands tos, r0
      cmp tos, #4
      drop
      beq 1f
        pushdaconst 0x0036  @ nop = movs tos, tos
        bl hkomma
        b 2b

builds_ram:
  .endif

  .ifdef flash16bytesblockwrite
    @ It is necessary for STM32L476 that Flash writes are aligned on 16.
    @ So if we are compiling into Flash, we need to make sure that
    @ the block the user might write to later is properly aligned.
    ldr r0, =Dictionarypointer
    ldr r1, [r0]

    ldr r2, =Backlinkgrenze
    cmp r1, r2
.ifdef above_ram
    blo.n builds_ram
.else
    bhs.n builds_ram
.endif

      @ See where we are. The sequence written for <builds does> is 12 Bytes long on M3/M4.
      @ So we need to advance to 16n + 4 so that the opcode sequence ends on a suitable border.

2:    bl here
      movs r0, #15
      ands tos, r0
      cmp tos, #4
      drop
      beq 1f
        pushdaconst 0x0036  @ nop = movs tos, tos
        bl hkomma
        b 2b

builds_ram:
  .endif

  @ This is to align dictionary pointer to have does> target locations that are always 4-even
    bl here
    movs r0, #2
    ands tos, r0
    drop
    beq 1f
      pushdaconst 0x0036  @ nop = movs tos, tos
      bl hkomma
1:

  pushdaconstw 0xb500 @ Opcode für push {lr} schreiben  Write opcode for push {lr}
  bl hkomma

  pushdaconst 10  @ Hier kommt ein Call-Befehl hinein, aber ich weiß die Adresse noch nicht.
  bl allot        @ Lasse also eine passende Lücke frei !  Leave space for a long call opcode sequence.
  pop {pc}
