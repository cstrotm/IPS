{
     This UNIT implements the low level access to the serial
     I/O hardware.

     The IBM PC BIOS supports upto 4 Aux Devices.

     (c) 2001 Paul Willmott, VP9MU

     Version 1.0.0 - June 4, 2001

             1.0.1 - August 28, 2001 - AuxClrBuf added
}

UNIT AuxIO ;

{
     Public Interface
}

INTERFACE

USES

     DOS ;

CONST

     AuxBufSize    = 4096 ;  { I/O Buffer Size                      }
     MaxAuxDevices = 4    ;  { Max Devices supported by IBM-PC BIOS }

{
     I/O Data Stream Formats
}

     FORMAT_NONE  = $00 ; { Standard Buffered I/O - IPS Direct Control  }
     FORMAT_BLK   = $01 ; { I/O           512+CRCC                      }
     FORMAT_P3BLK = $02 ; { I/O Idle+Sync+512+CRCC                      }
     FORMAT_P3CMD = $04 ; { I   Idle+Sync+512+CRCC then compile         }

{
     Aux Device Workspace Definition
}

TYPE

     AuxType = RECORD
                     COM_RTD   : WORD                           ; { Receive / Transmit data register }
                     COM_IER   : WORD                           ; { Interrupt Enable Register }
                     COM_IIR   : WORD                           ; { Interrupt Identification Register }
                     COM_LCR   : WORD                           ; { Line Control Register }
                     COM_MCR   : WORD                           ; { Modem Control Register }
                     COM_LSR   : WORD                           ; { Line Status Register }
                     COM_MSR   : WORD                           ; { Modem Status Register }
                     COM_INT   : BYTE                           ; { Interrupt Number }
                     INT_MASK  : BYTE                           ;
                     BAUDRATE  : WORD                           ; { Baud Rate                         }
                     PARITY    : CHAR                           ; { Parity: E(ven), O(dd), N(one) }
                     WORDLEN   : BYTE                           ; { Word Length: 8,7,6,5 }
                     STOPBITS  : BYTE                           ; { Number of Stop Bits; 1 or 2 }
                     BRD_MASK  : WORD                           ; { Baud Rate Divisor Mask }
                     LCR_MASK  : BYTE                           ; { LCR Mask - Word Length etc }
                     OldIntVec : POINTER                        ; { Old Serial Port Interrupt Handler Address               }
                     IBuf      : ARRAY[0..AuxBufSize-1] OF BYTE ; { Serial Port Input Buffer                                }
                     IBufCount : WORD                           ; { Characters to be processed in Input Buffer              }
                     IBufWPtr  : WORD                           ; { Pointer to Next Write Position in Input Buffer          }
                     IBufRPtr  : WORD                           ; { Pointer to Next Read Position in Input Buffer           }
                     OBuf      : ARRAY[0..AuxBufSize-1] OF BYTE ; { Serial Port Output Buffer                               }
                     OBufCount : WORD                           ; { Characters to be processed in Output Buffer             }
                     OBufWPtr  : WORD                           ; { Pointer to Next Write Position in Output Buffer         }
                     OBufRPtr  : WORD                           ; { Pointer to Next Read Position in Output Buffer          }
                     RX_FORMAT : WORD                           ;
                     TX_FORMAT : WORD                           ;
                     AuxOpen   : BOOLEAN                        ;
               END ;

VAR

     MaxAuxDev : BYTE ; { Number of Last COM Port, ... 1 = COM1: }

     Aux : ARRAY[1..MaxAuxDevices] OF ^AuxType ;

PROCEDURE EnableInterrupts  ; INLINE($FB) ; { STI }
PROCEDURE DisableInterrupts ; INLINE($FA) ; { CLI }
PROCEDURE OpenAux(Index:BYTE) ;
PROCEDURE CloseAux(Index:BYTE) ;
PROCEDURE AuxOutChar(AuxPort:WORD) ;
PROCEDURE PutAuxOut(AuxPort:WORD;OutChar:BYTE) ;
FUNCTION GetAuxIn(AuxPort:WORD):BYTE ;
PROCEDURE AuxClrBuf(AuxPort:WORD) ;

{
     Hidden Implementation
}

IMPLEMENTATION

{$F+}

CONST

     PIC_MASK = $21 ; { 8259 interrupt mask port }
     PIC_EOI  = $20 ; { 8259 EOI port }

VAR

     CmdBufCount : WORD    ;
     ExitSave    : POINTER ; { Pointer to Next ExitProc }
     Index       : WORD    ;

{
     This routine returns the number of Aux devices
     detected by the BIOS POST.

     Reference: IBM Personal System/2 and Personal Computer
                BIOS Interface Reference Manual, First Edition
                April 1987. Section 3. Data Areas and ROM Tables.
}

FUNCTION NumberAuxDevices:BYTE ;
BEGIN
     NumberAuxDevices := (Mem[$0040:$0011] AND $0E) SHR 1 ;
END { NumberAuxDevices } ;

{
     This routine returns the base address for selected Aux device.
     1 = COM1: etc.

     Reference: IBM Personal System/2 and Personal Computer
                BIOS Interface Reference Manual, First Edition
                April 1987. Section 3. Data Areas and ROM Tables.
}

FUNCTION AuxBaseAddress(DevNumber:BYTE):WORD ;
BEGIN
     AuxBaseAddress := MemW[$0040:(DevNumber-1)*2] ;
END { AuxBaseAddress } ;

{
     ******************************************************************
     Serial Communications

     REFERENCE: Pages 113-125 Advanced MS-DOS Programming 2nd Ed, Ray Duncan, Microsoft Press 1988
                ISBN: 1-55615-157-8

     Art of Assembly Language: Chapter Twenty-Two
     http://burks.bton.ac.uk/burks/language/asm/artofasm/ch22/ch221.htm
     ******************************************************************
}

PROCEDURE IRQ4Handler ; INTERRUPT ;
VAR
     Index : BYTE ;
BEGIN
     Index := 1 ;
     WHILE (Index<=MaxAuxDev) DO BEGIN
         WITH Aux[Index]^ DO BEGIN
             IF (AuxOpen) AND (Port[COM_IIR] AND $04 <>0) THEN BEGIN
                 IBuf[IBufWPtr] := Port[COM_RTD] ;
                 Inc(IBufWPtr) ;
                 IF (IBufWPtr=AuxBufSize) THEN BEGIN
                     IBufWPtr := 0 ;
                 END ;
                 Inc(IBufCount) ;
                 EnableInterrupts ;
                 Port[PIC_EOI] := $20 ; { send EOI to 8259 }
                 Exit ;
             END ;
         END ;
         Inc(Index,2) ;
     END ;

{
     Should Never Be Executed!
}

     EnableInterrupts ;
     Port[PIC_EOI] := $20 ; { send EOI to 8259 }

END { IRQ4Handler } ;

PROCEDURE IRQ3Handler ; INTERRUPT ;
VAR
     Index : BYTE ;
BEGIN
     Index := 2 ;
     WHILE (Index<=MaxAuxDev) DO BEGIN
         WITH Aux[Index]^ DO BEGIN
             IF (AuxOpen) AND (Port[COM_IIR] AND $04 <>0) THEN BEGIN
                 IBuf[IBufWPtr] := Port[COM_RTD] ;
                 Inc(IBufWPtr) ;
                 IF (IBufWPtr=AuxBufSize) THEN BEGIN
                     IBufWPtr := 0 ;
                 END ;
                 Inc(IBufCount) ;
                 EnableInterrupts ;
                 Port[PIC_EOI] := $20 ; { send EOI to 8259 }
                 Exit ;
             END ;
         END ;
         Inc(Index,2) ;
     END ;

{
     Should Never Be Executed!
}

     EnableInterrupts ;
     Port[PIC_EOI] := $20 ; { send EOI to 8259 }

END { IRQ3Handler } ;

{
     This routine restores the interrupt vector to its previous
     value, and deallocates the I/O buffers

     NOTE: Close Ports in Reverse Order of Opening!
}

PROCEDURE CloseAux ;
VAR
     MASK : BYTE ;
BEGIN

     IF (Index<=MaxAuxDev) THEN BEGIN

         WITH Aux[Index]^ DO BEGIN

             AuxOpen := FALSE ;

{
     Read current 8259 mask
     reset mask for COM port
     write new mask
}

             MASK := Port[PIC_MASK] ;
             Port[PIC_MASK] := MASK OR INT_MASK ;

{
     Restore Previous Handler
}

             SetIntVec(COM_INT,OldIntVec) ;

         END ;

     END ;

END { CloseAux } ;

{
     This routine inits the I/O buffers, sets the Baud rate, then
     captures the interrupt vector.
}

PROCEDURE OpenAux ;
BEGIN

{
     Only Open if POST Found It!
}

     IF (Index<=MaxAuxDev) THEN BEGIN

         WITH Aux[Index]^ DO BEGIN

             IF (AuxOpen) THEN BEGIN
                 CloseAux(Index) ;
             END ;

             AuxOpen := TRUE ;

{
    Setup Port Addresses
}

             COM_RTD := AuxBaseAddress(Index) ;
             COM_IER := COM_RTD + $01 ;
             COM_IIR := COM_RTD + $02 ;
             COM_LCR := COM_RTD + $03 ;
             COM_MCR := COM_RTD + $04 ;
             COM_LSR := COM_RTD + $05 ;
             COM_MSR := COM_RTD + $06 ;

             CASE COM_RTD OF
             $2F8 : BEGIN
                         COM_INT  := $0B ;
                         INT_MASK := $08 ;
                    END ;
             $3E8 : BEGIN
                         COM_INT  := $0C ;
                         INT_MASK := $10 ;
                    END ;
             $2E8 : BEGIN
                         COM_INT  := $0B ;
                         INT_MASK := $08 ;
                    END ;
             ELSE
                         COM_INT  := $0C ;
                         INT_MASK := $10 ;
             END ;

{
     Settings, Baud Rate etc
}

             CASE WORDLEN OF
             5 : LCR_MASK := $00 ;
             6 : LCR_MASK := $01 ;
             7 : LCR_MASK := $02 ;
             ELSE
                 LCR_MASK := $03 ; { 8 }
             END ;

             CASE STOPBITS OF
             2 : LCR_MASK := $04 ;
             ELSE
                 LCR_MASK := LCR_MASK OR $00 ; { 1 }
             END ;

             CASE PARITY OF
             'E' : LCR_MASK := LCR_MASK OR $18 ;
             'O' : LCR_MASK := LCR_MASK OR $08 ;
             ELSE
                   LCR_MASK := LCR_MASK OR $00 ; { N }
             END ;

             CASE BAUDRATE OF
             150   : BRD_MASK := 768 ;
             300   : BRD_MASK := 384 ;
             600   : BRD_MASK := 192 ;
             1200  : BRD_MASK := 96  ;
             2400  : BRD_MASK := 48  ;
             4800  : BRD_MASK := 24  ;
             9600  : BRD_MASK := 12  ;
             19200 : BRD_MASK := 6   ;
             38400 : BRD_MASK := 3   ;
             ELSE
                     BRD_MASK := 1047 ; { 110 }
             END ;

             Port [COM_LCR] := LCR_MASK OR $80 ;
             PortW[COM_RTD] := BRD_MASK ;
             Port [COM_LCR] := LCR_MASK ;

{
     Capture Interrupt Vector
}

             GetIntVec(COM_INT,OldIntVec) ;
             CASE COM_INT OF
             $0B : SetIntVec(COM_INT,@IRQ3Handler) ;
             ELSE
                   SetIntVec(COM_INT,@IRQ4Handler) ;
             END ;

{
     Set Modem Control Register
     DTR and OUT2 bits
}

             Port[COM_MCR] := $0B ;

{
     Set interrupt enable register on serial port controller
}

             Port[COM_IER] := $01 ; { RX Only }

{
     Read current 8259 mask
     set mask for COM port
     write new mask
}

             Port[PIC_MASK] := Port[PIC_MASK] AND NOT INT_MASK ;

         END ;

     END ;

END { OpenAux } ;

{
     Write Character from Output Buffer to Aux Port
}

PROCEDURE AuxOutChar ;
BEGIN
     WITH Aux[AuxPort]^ DO BEGIN
         WHILE (AuxOpen) AND (OBufCount>0) DO BEGIN
(*           Write(OBuf[OBufRPtr], ' ') ; *)
             WHILE (Port[COM_LSR] AND $20 = 0) DO ;
             Port[COM_RTD] := OBuf[OBufRPtr] ;
             Inc(OBufRPtr) ;
             IF (OBufRPtr=AuxBufSize) THEN BEGIN
                 OBufRPtr := 0 ;
             END ;
             Dec(OBufCount) ;
         END ;
     END ;
END { AuxOutChar } ;

{
     This procedure writes a character to the Aux Port Output Buffer
     Characters after Overflow are eaten!
}

PROCEDURE PutAuxOut ;
BEGIN
     WITH Aux[AuxPort]^ DO BEGIN
         IF (AuxOpen) AND (OBufCount<AuxBufSize) THEN BEGIN
             OBuf[OBufWPtr] := OutChar ;
             Inc(OBufWPtr) ;
             IF (OBufWPtr=AuxBufSize) THEN BEGIN
                 OBufWPtr := 0 ;
             END ;
             Inc(OBufCount) ;
         END ;
     END ;
END { PutAuxOut } ;

{
     This Function reads a character from the Aux In Buffer.
     You must check the buffer count first for underflow!
     The return result is rubbish when underflow!
}

FUNCTION GetAuxIn ;
BEGIN
     WITH Aux[AuxPort]^ DO BEGIN
         IF (AuxOpen) AND (IBufCount>0) THEN BEGIN
             GetAuxIn := IBuf[IBufRPtr] ;
             Inc(IBufRPtr) ;
             IF (IBufRPtr=AuxBufSize) THEN BEGIN
                 IBufRPtr := 0 ;
             END ;
             DisableInterrupts ;
             Dec(IBufCount) ;
             EnableInterrupts ;
         END ;
     END ;
END { GetAuxIn } ;

PROCEDURE AuxClrBuf ;
BEGIN
     WITH Aux[AuxPort]^ DO BEGIN
         DisableInterrupts ;
         IBufCount := 0 ;
         IBufRPtr := 0 ;
         EnableInterrupts ;
     END ;
END { AuxClrBuf } ;

{
    Tidy-Up and De-Allocate dynamic variables
}

PROCEDURE MyExit ;
VAR
     Index : WORD ;
BEGIN

{
     Pass Control to Next Exit Procedure <- Always First!
}

     ExitProc := ExitSave ;

{
     De-Allocate Workspace & Close Open Aux Devices
     This is done in Reverse Order of creation!
}

     Index := MaxAuxDev ;
     WHILE (0<Index) DO BEGIN
         IF (Aux[Index]^.AuxOpen) THEN BEGIN
             CloseAux(Index) ;
         END ;
         Dispose(Aux[Index]) ;
         Dec(Index) ;
     END ;

END ;

{
     Initialization
}

BEGIN

{
     Find How Many Devices We Have to Play With :^)
}

     MaxAuxDev := NumberAuxDevices ;

{
     Create I/O Buffers on Heap
}

     Index := 1 ;
     WHILE (Index<=MaxAuxDev) DO BEGIN
         New(Aux[Index]) ;
         Fillchar(Aux[Index]^,SizeOf(Aux[Index]^),$00) ;
         WITH Aux[Index]^ DO BEGIN
              BAUDRATE  := 1200        ;
              PARITY    := 'N'         ;
              WORDLEN   := 8           ;
              STOPBITS  := 1           ;
              RX_FORMAT := FORMAT_NONE ;
              TX_FORMAT := FORMAT_NONE ;
              AuxOpen   := FALSE       ;
         END ;
         Inc(Index) ;
     END ;

{
     Link Exit Procedure
}

     ExitSave := ExitProc ;
     ExitProc := @MyExit ;

END. { AuxIO }
