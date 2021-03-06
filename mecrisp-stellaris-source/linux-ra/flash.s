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

@ Simply store, as everything is in RAM on this target.

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "flash!" @ ( x Addr -- )
  @ Schreibt an die auf 4 gerade Adresse in den Flash.
@ -----------------------------------------------------------------------------
  popda r0 @ Adresse
  popda r1 @ Inhalt.

  @ Prüfe die Adresse: Sie muss auf 4 gerade sein:
  ands r2, r0, #3
  cmp r2, #0
  bne 3f

  @ Ist die gewünschte Stelle im Flash-Dictionary ? Außerhalb des Forth-Kerns ?
  ldr r3, =Kernschutzadresse
  cmp r0, r3
  blo 3f  
  
  str r1, [r0]
  
  bx lr

3:Fehler_Quit "Wrong address or data for writing flash !"

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "hflash!" @ ( x Addr -- )
  @ Schreibt an die auf 2 gerade Adresse in den Flash.
h_flashkomma:
@ -----------------------------------------------------------------------------
  popda r0 @ Adresse
  popda r1 @ Inhalt.

  @ Prüfe die Adresse: Sie muss auf 2 gerade sein:
  ands r2, r0, #1
  cmp r2, #0
  bne 3b

  @ Ist die gewünschte Stelle im Flash-Dictionary ? Außerhalb des Forth-Kerns ?
  ldr r3, =Kernschutzadresse
  cmp r0, r3
  blo 3b
  
  strh r1, [r0]
  
  bx lr
 
 @ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "cflash!" @ ( x Addr -- )
  @ Schreibt ein einzelnes Byte in den Flash.
c_flashkomma:
@ -----------------------------------------------------------------------------
  popda r0 @ Adresse
  popda r1 @ Inhalt.

  @ Ist die gewünschte Stelle im Flash-Dictionary ? Außerhalb des Forth-Kerns ?
  ldr r3, =Kernschutzadresse
  cmp r0, r3
  blo 3b
  
  strb r1, [r0]  
  
  bx lr
        
@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "eraseflash" @ ( -- )
eraseflash: @ Löscht den gesamten Inhalt des Flashdictionaries.
@ -----------------------------------------------------------------------------
        ldr r0, =FlashDictionaryAnfang
eraseflash_intern:
        ldr r1, =FlashDictionaryEnde
        movs r2, #0

1:      strh r2, [r0]
        adds r0, #2
        cmp r0, r1
        bne 1b
  b Reset

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "eraseflashfrom" @ ( Addr -- )
  @ Beginnt an der angegebenen Adresse mit dem Löschen des Dictionaries.
@ -----------------------------------------------------------------------------
        popda r0
        b.n eraseflash_intern
  
@
@ Signal handling
@
@ We need to
@ - save+restore non-scratch registers r4…r7
@ - use a temp param stack
@ - save r0…r3 to the parameter stack
@ - set the TOS register
@
@ Yes I know that this should live in its own file
@ but this way is least intrusive to the rest of Mecrisp

@------------------------------------------------------------------------------
  Wortbirne Flag_visible|Flag_variable, "sigpsp" @ ( -- addr ) 
  CoreVariable sigpsp
@------------------------------------------------------------------------------
  pushdatos
  ldr tos, =sigpsp   
  bx lr
  .word 0  @ not set

.macro pushreg register @ Push TOS on Datastack - a common, often used factor.

  .ifdef m0core
    subs psp, #4
    str \register, [psp]
  .else
    str \register, [psp, #-4]!
  .endif

.endm

@------------------------------------------------------------------------------
  Wortbirne Flag_visible, "sigenter" @ ( -- )
sigenter:
@------------------------------------------------------------------------------
  push { r4, r5, r6, r7 }
  ldr psp, =sigpsp  
  ldr psp, [ psp ]
  pushreg r2
  pushreg r1
  mov tos, r0
  bx lr       


@------------------------------------------------------------------------------
  Wortbirne Flag_visible, "sigexit" @ ( result -- )
sigexit:
@------------------------------------------------------------------------------
  popda r0
  pop { r4, r5, r6, r7 }
  bx lr       


