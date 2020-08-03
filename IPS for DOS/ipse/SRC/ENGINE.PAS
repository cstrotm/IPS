{
    This UNIT implements the memory space for the virtual
    machine, and checks the 20ms Interrupt mechanism.

    (c) 2001 Paul Willmott, VP9MU

    Version 1.0.0 - June  2, 2001
    Version 1.0.1 - June 10, 2001 - Linear Memory Space added
    Version 1.0.2 - June 23, 2001 - P3TLM constants added
    Version 1.0.3 - November 17, 2001 - _Os added for IPS-X
}

UNIT Engine ;

{
    Public Interface
}

INTERFACE

USES

     DOS      ,
     TypeDefs ,
     FastCrt  ,
     Timer    ;

{
     --------------------------
     IPS Fixed Memory Addresses
     --------------------------

     IPS-Mp SysPage Assignments
     --------------------------

 Syspage assignments 400-47F
 ---------------------------
 400  ' COMPILER                      420  SU0 Minutes LSW
 401                                  421  SU0 Minutes MSW
 402  0 ' ZEIG-STAPEL (KETTE)         422  SU1 10ms    (0-98)
 403                                  423  SU1 Seconds (0-59)
 404  1                               424  SU1 Minutes LSW
 405                                  425  SU1 Minutes MSW
 406  2                               426  SU2 10ms    (0-98)
 407                                  427  SU2 Seconds (0-59)
 408  3                               428  SU2 Minutes LSW
 409                                  429  SU2 Minutes MSW
 40A  4                               42A  SU3 10ms    (0-98)
 40B                                  42B  SU3 Seconds (0-59)
 40C  5                               42C  SU3 Minutes LSW
 40D                                  42D  SU3 Minutes MSW
 40E  6                               42E  READYFLAG
 40F                                  42F  $PE value
 410  7                               430
 411                                  431  $PI value
 412  JUMP                            432
 413                                  433  $P1 value
 414  #0400                           434
 415                                  435  $P2 value
 416  --                              436
 417  --                              437  $P3 value
 418  UHR 10ms    (0-98)              438
 419  UHR Seconds (0-59)              439  $H  value
 41A  UHR Minutes (0-59)              43A
 41B  UHR Hours   (0-23)              43B  LOADFLAG
 41C  UHR Days LSW                    43C  $Os value (IPS-X)
 41D  UHR Days MSW                    43D
 41E  SU0 10ms    (0-98)              43E  $ND value
 41F  SU0 Seconds (0-59)              43F

 Syspage assignments 480-4FF
 ---------------------------
 Nearly all of this is for return stack; more than enough, although (e.g.)
 6 12 18 TAK  will use from #4F8  down to #4B2.

 480 Return stack max 60 items          4C0
 481       ^                            4C1
 482       ^                            4C2
 483                                    4C3
 484                                    4C4
 485                                    4C5
 486                                    4C6
 487                                    4C7
 488                                    4C8
 489                                    4C9
 48A                                    4CA
 48B                                    4CB
 48C                                    4CC
 48D                                    4CD
 48E                                    4CE
 48F                                    4CF
 490                                    4D0
 491                                    4D1
 492                                    4D2
 493                                    4D3
 494                                    4D4
 495                                    4D5
 496                                    4D6
 497                                    4D7
 498                                    4D8
 499                                    4D9
 49A                                    4DA
 49B                                    4DB
 49C                                    4DC
 49D                                    4DD
 49E                                    4DE
 49F                                    4DF
 4A0                                    4E0
 4A1                                    4E1
 4A2                                    4E2
 4A3                                    4E3
 4A4                                    4E4
 4A5                                    4E5
 4A6                                    4E6
 4A7                                    4E7
 4A8                                    4E8
 4A9                                    4E9
 4AA                                    4EA
 4AB                                    4EB
 4AC                                    4EC
 4AD                                    4ED
 4AE                                    4EE
 4AF                                    4EF
 4B0                                    4F0
 4B1                                    4F1
 4B2.                                   4F2
 4B3                                    4F3
 4B4                                    4F4
 4B5                                    4F5
 4B6                                    4F6        ^
 4B7                                    4F7        ^
 4B8                                    4F8   IPS Return Stack base
 4B9                                    4F9   (Stack underflow)
 4BA                                    4FA        v
 4BB                                    4FB        v
 4BC                                    4FC        v
 4BD                                    4FD        v
 4BE                                    4FE        v
 4BF                                    4FF   (Underflow max 4 items)

Syspage Extension
-----------------
 500   ]
 501   ]
 502   ]
 503   ]
 504   ]
 505   ]
 506   ]  Uncommitted workspace for
 507   ]  system implementer.
 508   ]
 509   ]
 50A   ]
 50B   ]
 50C   ]
 50D   ]
 50E   ]
 50F   ]

 510   IPS begins here (RUMPELSTILZCHEN)

jrm
2001 Jun 16 [Sat] 1240 utc

}

CONST

     SYSPAGE   = $400 ; { Start of SYSPAGE <- COMPILER / COMPILER/R }
     KETTE     = $402 ; { CHAIN }
     UHR       = $418 ; { UHR 10ms }
     SU0       = $41E ; { Stopwatch 0 }
     SU1       = $422 ; { Stopwatch 1 }
     SU2       = $426 ; { Stopwatch 2 }
     SU3       = $42A ; { Stopwatch 3 }
     RBU       = $000 ; { Command Buffer Address }
     EBU       = $500 ; { EB Output Buffer }
     READYFLAG = $42E ; { Compiler free to process input }
     DATA_IN   = $43D ; { Command Block Ready to be Processed }
     TZ        = $42E ; { Block TX Flag }
     PE        = $42F ; { Pointer to end of input }
     PI        = $431 ; { Compiler Read Pointer }
     P1        = $433 ; { Compiler Parsing Position }
     P2        = $435 ; { End of Block reached Flag }
     P3        = $437 ; { Link Pointer for $SUCH }
     H         = $439 ; { Pointer to 1st Free Memory Position }
     LOADFLAG  = $43B ; { Input Coming From File }
     _Os       = $43C ; { Link offset for IPS-X }
     ND        = $43E ; { $ND }
     TV0       = $000 ; { 1st   TV Screen line position }
     TVS       = $000 ; { Stack TV Screen line position }
     TV4       = $100 ; { 4th   TV Screen line position }
     SYSLINE   = $1C0 ; { Position Buffer for messages  }
     TV8       = $200 ; { 8th   TV Screen line position }
     TVE       = $3FF ; { Last  TV Screen line position }
     INFLAG    = $480 ; { }

     P3TLM_INFLAG  = $500 ; { Ready to Receive Telemetry Input      }
     P3TLM_DATA_IN = $501 ; { Telemetry Block Ready to be Processed }
     P3TLM_BUFADDR = $502 ; { Address of 514 Byte Telemetry Buffer  }

VAR

     PSP : WORD ; { Parameter Stack Pointer }
     RSP : WORD ; { Return Stack Pointer    }

FUNCTION PeekB(MemAddr:WORD):BYTE ;
FUNCTION PeekW(MemAddr:WORD):WORD ;
FUNCTION PeekI(MemAddr:WORD):INTEGER ;

PROCEDURE PokeB(MemAddr:WORD;PokeValue:BYTE) ;
PROCEDURE PokeW(MemAddr:WORD;PokeValue:WORD) ;
PROCEDURE PokeI(MemAddr:WORD;PokeValue:INTEGER) ;

PROCEDURE PushW(Value:WORD) ;
PROCEDURE PushI(Value:INTEGER) ;

FUNCTION PopW:WORD ;
FUNCTION PopI:INTEGER ;

PROCEDURE PushRSW(Value:WORD) ;
PROCEDURE PushRSI(Value:INTEGER) ;

FUNCTION PopRSW:WORD ;
FUNCTION PopRSI:INTEGER ;

{
     Hidden Implementation
}

IMPLEMENTATION

{$F+}

CONST

     PARAMETERSTACK = $FFF8 ; { Start of Parameter Stack }
     RETURNSTACK    = $4F0  ; { Start of Return Stack    }

VAR

     ExitSave    : POINTER ;
     BaseSegAddr : WORD    ;

{
	*************************
	Memory Space Manipulation
	*************************
}

FUNCTION PeekB(MemAddr:WORD):BYTE ;
BEGIN
     CheckTimer ;
     PeekB := Mem[BaseSegAddr:MemAddr] ;
END { PeekB } ;

FUNCTION PeekW ;
BEGIN
     PeekW := MemW[BaseSegAddr:MemAddr] ;
END { PeekW } ;

FUNCTION PeekI ;
BEGIN
     PeekI := INTEGER(MemW[BaseSegAddr:MemAddr]) ;
END { PeekI } ;

PROCEDURE PokeB(MemAddr:WORD;PokeValue:BYTE) ;
BEGIN
     CheckTimer ;
     Mem[BaseSegAddr:MemAddr] := PokeValue ;
     IF (MemAddr<=TVE) THEN BEGIN
	 WriteChar(MemAddr,PokeValue) ;
     END ;
END { PokeB } ;

PROCEDURE PokeW ;
BEGIN
     PokeB(MemAddr,Lo(PokeValue)) ;
     PokeB(Succ(MemAddr),Hi(PokeValue)) ;
END { PokeW } ;

PROCEDURE PokeI ;
BEGIN
     PokeB(MemAddr,Lo(PokeValue)) ;
     PokeB(Succ(MemAddr),Hi(PokeValue)) ;
END { PokeI } ;

{
     ******************
     Stack Manipulation
     ******************

     All stack entries are 16-Bit (2 bytes), and grow downwards.
     The stack pointers point to the last entry in use by the stack.
     These stack routines perform no overflow checking - that is left to IPS!!!!

     IPS has two variables containing pointers to the last position in use by the stack.
     Thus the system "knows" how many numbers it has on the stack; it keeps track of
     the entries by decrementing or incrementing these pointers. Only 16-bit numbers are held
     on the stacks. Thus the stack pointers always change in twos.

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
		 Pages 31 to 32 - 4.1 The address space

     ---------------
     Parameter Stack
     ---------------
}

PROCEDURE PushW ;
BEGIN
     Dec(PSP,2) ;
     MemW[BaseSegAddr:PSP] := Value ;
END { PushW } ;

FUNCTION PopW ;
BEGIN
     PopW := MemW[BaseSegAddr:PSP] ;
     Inc(PSP,2) ;
END { PopW } ;

PROCEDURE PushI ;
BEGIN
     Dec(PSP,2) ;
     MemW[BaseSegAddr:PSP] := WORD(Value) ;

END { PushI } ;

FUNCTION PopI ;
BEGIN
     PopI := INTEGER(MemW[BaseSegAddr:PSP]) ;
     Inc(PSP,2) ;
END { PopI } ;

{
     ------------
     Return Stack
     ------------
}

PROCEDURE PushRSW ;
BEGIN
     Dec(RSP,2) ;
     MemW[BaseSegAddr:RSP] := Value ;
END { PushRSW } ;

FUNCTION PopRSW ;
BEGIN
     PopRSW := MemW[BaseSegAddr:RSP] ;
     Inc(RSP,2) ;
END { PopRSW } ;

PROCEDURE PushRSI ;
BEGIN
     Dec(RSP,2) ;
     MemW[BaseSegAddr:RSP] := WORD(Value) ;
END { PushRSI } ;

FUNCTION PopRSI ;
BEGIN
     PopRSI := INTEGER(MemW[BaseSegAddr:RSP]) ;
     Inc(RSP,2) ;
END { PopRSI } ;

{
    This routine allocates a block of memory of specified
    size, and returns its base segment address.
}

FUNCTION MemAllocate(NumberOfParagraphs:WORD):WORD ;
VAR
     RegPack : Registers ;
BEGIN
     WITH RegPack DO BEGIN
	 AH := $48 ;
	 BX := NumberOfParagraphs ;
	 MsDOS(RegPack) ;
	 MemAllocate := AX ;
	 { assume it works ! }
     END ;
END { MemAllocate } ;

{
     This routine releases a previously allocated block
     of memory.
}

PROCEDURE ReleaseMem(BaseSegAddr:WORD) ;
VAR
     RegPack : Registers ;
BEGIN
     WITH RegPack DO BEGIN
	 AH := $49 ;
	 ES := BaseSegAddr ;
	 MsDOS(RegPack) ;
      { assume it works ! }
     END ;
END { ReleaseMem } ;

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
     De-Allocate Virtual Memory Space
}

     ReleaseMem(BaseSegAddr) ;

END { MyExit } ;

{
     Initialization Section
}

BEGIN

{
     Create virtual memory space
}

     BaseSegAddr := MemAllocate($1000) ;

{
     Init Stack Pointers
}

     RSP := RETURNSTACK ;
     PSP := PARAMETERSTACK ;

{
     Link Exit Procedure
}

     ExitSave := ExitProc ;
     ExitProc := @MyExit ;

END. { Engine }
