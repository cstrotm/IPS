{
    This UNIT implements the 20ms Interrupt mechanism.

    (c) 2001 Paul Willmott, VP9MU

    Version 1.0.0 - June 3, 2001
}

UNIT Timer ;

{
    Public Interface
}

INTERFACE

USES

     DOS    ,
     Config ;

VAR

     Do20msIntr : BOOLEAN   ; { True if Semaphore has been set   }
     CheckTimer : PROCEDURE ; { Check Semaphore, and reset timer }

{
     Hidden Implementation
}

IMPLEMENTATION

{$F+}

VAR

     TimerFlag  : BYTE    ; { Semaphore used to control 20ms Pseudo-Interrupt    }
     TimerNudge : BYTE    ; { Count to control accuracy of 20ms Pseudo-Interrupt }
     LoopCount  : WORD    ; { Count of Loops left before Next 20ms Event         }
     LoopLimit  : WORD    ; { Number of Loops to do when faking Event Timer      }
     ExitSave   : POINTER ; { Pointer to Next ExitProc                           }

{
    ----------------------------------------------------------------------------------------
    REFERENCE: Page 566 Advanced MS-DOS Programming 2nd Ed, Ray Duncan, Microsoft Press 1988
               ISBN: 1-55615-157-8

    Int 15H
    Function 83H
    Event Wait

    Requests setting of a sempahore after a specified interval or cancels
    a previous request.

    The function call returns immediately. If the function is successful,
    bit 7 of the semaphore byte is set when the specified interval has elapsed.
    The calling program is responsible for clearing the semaphore before
    requesting this function.

    The actual duration of an event wait is always an integral multiple
    of 976 microseconds. The CMOS date/clock chip interrupts are used
    to implement this function.

    PW NOTE : The function is ONLY supported from the release of the IBM PC-AT onwards,
              ... i.e. it won't work on the IBM-PC or IBM PC-XT ... too bad!

    -----------------------------------------------------------------------------------
    The nudge factor is per James Miller Private Communication April 29, 2001
    -----------------------------------------------------------------------------------
}

PROCEDURE Set20msTimer ;
VAR
     RegPack : Registers ;
BEGIN

     TimerFlag := $00 ;

     RegPack.AH := $83 ;
     RegPack.AL := $00 ;
     RegPack.CX := $0 ;
     RegPack.DX := 976 * (19+(TimerNudge AND $01)) ;
     RegPack.ES := Seg(TimerFlag) ;
     RegPack.BX := Ofs(TimerFlag) ;
     Intr($15,RegPack) ;

     Dec(TimerNudge) ;
     IF (TimerNudge=0) THEN BEGIN
         TimerNudge := 24 ;
     END ;

END { Set20msTimer } ;

{
     This routine destroys the timer when it is time to quit!
}

PROCEDURE Kill20msTimer ;
VAR
     RegPack : Registers ;
BEGIN

     RegPack.AH := $83 ;
     RegPack.AL := $01 ;
     Intr($15,RegPack) ;

END { Kill20msTimer } ;

{
     Called by PeekB and PokeB when using a hardware
     timer.
}

PROCEDURE CheckTimer_Event ;
BEGIN
     IF (TimerFlag AND $80 <> 0) THEN BEGIN
         Do20msIntr := TRUE ;
         Set20msTimer ;
     END ;
END { CheckTimer_Event } ;

{
     Called by PeekB and PokeB when using a software
     timer.
}

PROCEDURE CheckTimer_Count ;
BEGIN
     Dec(LoopCount) ;
     IF (LoopCount = 0) THEN BEGIN
         Do20msIntr := TRUE ;
         LoopCount := LoopLimit ;
     END ;
END { CheckTimer_Event } ;

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
     Destroy Timer
}

     IF (UseBIOS) THEN BEGIN
         Kill20msTimer ;
     END ;

END { MyExit } ;

{
     Initialization
}

BEGIN

{
     Setup 20ms Pseudo Interrupt Control
}

     IF (UseBIOS) THEN BEGIN
         TimerFlag  := $80 ;
         TimerNudge := 24 ;
         CheckTimer := CheckTimer_Event ;
     END
     ELSE BEGIN
         LoopLimit  := 5000 ;
         LoopCount  := LoopLimit ;
         CheckTimer := CheckTimer_Count ;
     END ;

{
     Link Exit Procedure
}

     ExitSave := ExitProc ;
     ExitProc := @MyExit ;

END. { Timer }
