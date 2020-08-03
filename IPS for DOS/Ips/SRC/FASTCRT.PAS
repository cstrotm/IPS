{
    This UNIT implements the fast and slow access to PC video
    memory.

    NOTE: The Fast & Slow Options are the same!
          This unit now uses the colour video memory!

    (c) 2001 Paul Willmott, VP9MU

    Version 1.0.0 - June  9, 2001
    Version 1.0.1 - June  9, 2001 - Cursor Keys Fix
    Version 1.0.2 - June 11, 2001 - ReadKey return value changed to BYTE
}

UNIT FastCrt ;

{
    Public Interface
}

INTERFACE

USES

     DOS    ,
     Config ;

{
     Constants for Character graphics
}

CONST

     KC_TLD = #201 ; { Top Left Double     }
     KC_TRD = #187 ; { Top Right Double    }
     KC_BLD = #200 ; { Bottom Left Double  }
     KC_BRD = #188 ; { Bottom Right Double }
     KC_VTD = #186 ; { Vertical Double     }
     KC_HRD = #205 ; { Horizontal Double   }
     KC_TLS = #218 ; { Top Left Single     }
     KC_TRS = #191 ; { Top Right Single    }
     KC_BLS = #192 ; { Bottom Left Single  }
     KC_BRS = #217 ; { Bottom Right Single }
     KC_VTS = #179 ; { Vertical Single     }
     KC_HRS = #196 ; { Horizontal Single   }

{
     Colour Constants
}

     Black        = 00 ;
     Blue         = 01 ;
     Green        = 02 ;
     Cyan         = 03 ;
     Red          = 04 ;
     Magenta      = 05 ;
     Brown        = 06 ;
     White        = 07 ;
     Gray         = 08 ;
     LightBlue    = 09 ;
     LightGreen   = 10 ;
     LightCyan    = 11 ;
     LightRed     = 12 ;
     LightMagenta = 13 ;
     Yellow       = 14 ;
     IntenseWhite = 15 ;

{
     TextBackground and TextColor Attributes
}

     TextBackground : BYTE = Black ;
     TextColor      : BYTE = White ;

     IPS_XOFFSET = 9 ; { X Offset of IPS Screen Within PC Screen }
     IPS_YOFFSET = 5 ; { Y Offset of IPS Screen Within PC Screen }


VAR

{
     This routine writes a character to the PC screen
     corresponding to the IPS address MemAddr.
}

     WriteChar : PROCEDURE(MemAddr:WORD;PokeValue:BYTE) ;

{
     This routine writes the string ss to the PC screen
     starting at x (1-80) , y (1-25)
}

     WriteStr  : PROCEDURE(x,y:WORD;ss:STRING) ;

{
     This function returns true if there is a character ready
     in the keyboard buffer
}

     FUNCTION KeyPressed:BOOLEAN ;

{
     This function returns character waiting in the keyboard
     buffer. If the key pressed is an extended character like F12,
     then the first call to this function will return #0, and the
     second the keyboard scan code.
}

     FUNCTION ReadKey:BYTE ;

{
     This routine clears the screen display using the current
     Background and Foreground Attributes.
}

     PROCEDURE ClrScr ;

{
     Hidden Implementation
}

IMPLEMENTATION

{$F+}

{
     IPSDOS directly addresses the video memory, avoiding the VERY
     slow BIOS functions. The IBM-PC MONO screen is accessed using
     a memory-mapped array of record.
}

TYPE

     PCScreenLine = ARRAY[0..79] OF RECORD
                                          Character : BYTE ;
                                          Attribute : BYTE ;
                                    END ;
VAR

     PCScreen : ARRAY[0..24] OF PCScreenLine ABSOLUTE $B800:$0000 ;

     ExitSave    : POINTER      ; { Pointer to Next ExitProc }

     CharWaiting : BOOLEAN      ; { True if Next ReadKey call returns Scan Code }
     ScanCode    : BYTE         ; { Scan Code to be returned on Next call to ReadKey }

FUNCTION KeyPressed ;
VAR
     RegPack : Registers ;
BEGIN
     WITH RegPack DO BEGIN
          AH := $11 ;
          Intr($16,RegPack) ;
          KeyPressed := (Flags AND FZero = 0) ;
     END ;
END { KeyPressed } ;

FUNCTION ReadKey ;
VAR
     RegPack : Registers ;
BEGIN
     IF (CharWaiting) THEN BEGIN
         ReadKey := ScanCode ;
         CharWaiting := FALSE ;
     END
     ELSE BEGIN
         WITH RegPack DO BEGIN
              AH := $10 ;
              Intr($16,RegPack) ;
              IF (AL=$0) OR (AL=224) THEN BEGIN
                  AL := $0 ;
                  CharWaiting := TRUE ;
                  ScanCode := AH ;
              END ;
              ReadKey := AL ;
         END ;
     END ;
END { ReadKey } ;


PROCEDURE _WriteCharFast(MemAddr:WORD;PokeValue:BYTE) ;
BEGIN

     WITH PCScreen[MemAddr DIV 64 + Pred(IPS_YOFFSET),MemAddr MOD 64 + Pred(IPS_XOFFSET)] DO BEGIN
         Character := PokeValue AND $7F ;
         IF (PokeValue AND $80 = 0) THEN BEGIN
             Attribute := TextBackground SHL 4 OR TextColor ;
         END
         ELSE BEGIN
             Attribute := (TextColor AND $07) SHL 4 OR TextBackground ;
         END ;
     END ;

END { _WriteCharFast } ;

PROCEDURE _WriteCharSlow(MemAddr:WORD;PokeValue:BYTE) ;
BEGIN
     _WriteCharFast(MemAddr,PokeValue) ;
END { _WriteCharSlow } ;

PROCEDURE _WriteStrFast(x,y:WORD;ss:STRING) ;
VAR
     Index  : WORD ;
     Attrib : BYTE ;
BEGIN
     Attrib := TextBackground SHL 4 OR TextColor ;
     FOR Index := 0 to Pred(Length(ss)) DO BEGIN
         WITH PCScreen[Pred(y),x+Pred(Index)] DO BEGIN
             Character := Ord(ss[Succ(Index)]) ;
             Attribute := Attrib ;
         END ;
     END ;
END { _WriteStrFast } ;

PROCEDURE _WriteStrSlow(x,y:WORD;ss:STRING) ;
BEGIN
     _WriteStrFast(x,y,ss) ;
END { _WriteStrSlow } ;

{
     This routine turns on and off the hardware flashing
     cursor.
}

PROCEDURE CursorStatus(ON:BOOLEAN) ;
VAR
     RegPack : Registers ;
BEGIN
     WITH RegPack DO BEGIN
          AH := $01 ;
          CL := 12 ;
          IF (ON) THEN BEGIN
              CH := 11 ;
          END
          ELSE BEGIN
              CH := $20 ;
          END ;
     END ;
     Intr($10,RegPack) ;
END { CursorStatus } ;

{
     This routine clears the video buffer
}

PROCEDURE ClrScr ;
VAR
     ClrScrLine : PCScreenLine ;
     Index      : WORD         ;
     BufLen     : WORD         ;
     Attrib     : BYTE         ;
BEGIN
     Attrib := TextBackground SHL 4 OR TextColor ;
     FOR Index := 0 TO 79 DO BEGIN
         WITH ClrScrLine[Index] DO BEGIN
             Character := $20 ; { Space }
             Attribute := Attrib ;
         END ;
     END ;
     BufLen := SizeOf(ClrScrLine) ;
     FOR Index := 0 TO 24 DO BEGIN
         Move(ClrScrLine,PCScreen[Index],BufLen) ;
     END ;
END { ClrScr } ;

{
    Tidy-Up
}

PROCEDURE MyExit ;
BEGIN

{
     Pass Control to Next Exit Procedure <- Always First!
}

     ExitProc := ExitSave ;

{
     Clear Screen and Restore Cursor Blink
}

     TextColor := White ;
     TextBackground := Black ;

     ClrScr ;

     WriteLn('IPS-Mp & IPS-X Kernals (c) 1997-2001 James R. Miller, G3RUH') ;
     WriteLn('ipsdos Virtual Machine (c) 2000-2001 Paul C. L. Willmott, VP9MU') ;
     WriteLn ;

     CursorStatus(TRUE) ;

END { MyExit } ;

{
     Initialization
}

BEGIN

{
     Choose fast or slow video mode
}

     IF (SlowVideo) THEN BEGIN
         WriteChar := _WriteCharSlow ;
         WriteStr  := _WriteStrSlow  ;
     END
     ELSE BEGIN
         WriteChar := _WriteCharFast ;
         WriteStr  := _WriteStrFast  ;
     END ;

{
     Turn Off Flashing Cursor
}

     CursorStatus(FALSE) ;

{
     Init Keyboard Handler
}

     CharWaiting := FALSE ;

{
     Link Exit Procedure
}

     ExitSave := ExitProc ;
     ExitProc := @MyExit ;

END. { FastCrt }
