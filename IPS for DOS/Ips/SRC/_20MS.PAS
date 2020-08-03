{
     This UNIT implements Inner Interpreter and 20ms Pseudo
     Interrupt service routines.

     (c) 2001 Paul Willmott, VP9MU

     Version 1.0.0 - June  4, 2001
     Version 1.0.1 - June 23, 2001 - P3TLM Capture added
     Version 1.0.2 - July 15, 2001 - Stopwatch stop test fix
     Version 1.0.3 - September 8, 2001 - Stopwatch fix
     Version 1.0.4 - November 24, 2001 - Keyboard Macros added
}

UNIT _20ms ;

{
     Public Interface
}

INTERFACE

USES

     ASCII   ,
     Strings ,
     AuxIO   ,
     FastCrt ,
     Config  ,
     Timer   ,
     Engine  ,
     Streams ,
     Kernal  ;

CONST

     Version : STRING = ' Ver:1.0.0 ' ; { Set in MAIN }

PROCEDURE RunKernal ;

{
     Hidden Implementation
}

IMPLEMENTATION

VAR

     InsertON     : BOOLEAN      ; { TRUE=Keyboard Insert Mode, FALSE=Keyboard Overwrite Mode }
     TimeToStop   : BOOLEAN      ; { Program Termination Flag        }

{
    **************************************
    20ms Pseudo Interrupt Service Routines
    **************************************
}

PROCEDURE code_StopWatch(StopWatchAddress:WORD) ;
VAR
     MilliSeconds : BYTE ;
     Seconds      : BYTE ;
     Minutes      : INTEGER ;
BEGIN

     MilliSeconds := PeekB(StopWatchAddress) ;

     IF ((MilliSeconds AND $01) <> 1) THEN BEGIN
        IF (0 < MilliSeconds) THEN BEGIN
            MilliSeconds := MilliSeconds - 2 ;
        END
        ELSE BEGIN
            MilliSeconds := 98 ;
            Seconds := PeekB(StopWatchAddress + 1) ;
            IF (0 < Seconds) THEN BEGIN
                Seconds := Seconds - 1 ;
            END
            ELSE BEGIN
                Seconds := 59 ;
                Minutes := PeekW(StopWatchAddress + 2) ;
                IF (0 < Minutes) THEN BEGIN
                    Minutes := Minutes - 1 ;
                    PokeW(StopWatchAddress + 2, Minutes) ;
                END
                ELSE BEGIN
                    Seconds := 0 ;
                    MilliSeconds := 1 ;
                END ;
            END ;
            PokeB(StopWatchAddress + 1, Seconds) ;
        END ;
        PokeB(StopWatchAddress, MilliSeconds) ;
    END ;

END { code_StopWatch } ;

PROCEDURE code_uhr ;
VAR
     MilliSeconds : BYTE ;
     Seconds      : BYTE ;
     Minutes      : BYTE ;
     Hours        : BYTE ;
BEGIN

{
     $418 UHR 10ms
     $419 UHR Seconds
     $41A UHR Minutes
     $41B UHR Hours
     $41C UHR Days Lo
     $41D UHR Days Hi
}

     MilliSeconds := PeekB($418) ;
     IF (MilliSeconds < 98) THEN BEGIN
         MilliSeconds := MilliSeconds + 2 ;
     END
     ELSE BEGIN
         MilliSeconds := 0 ;
         Seconds      := PeekB($419) ;
         IF (Seconds<59) THEN BEGIN
             Inc(Seconds) ;
         END
         ELSE BEGIN
             Seconds := 0 ;
             Minutes      := PeekB($41A) ;
             IF (Minutes<59) THEN BEGIN
                 Inc(Minutes) ;
             END
             ELSE BEGIN
                 Minutes := 0 ;
                 Hours        := PeekB($41B) ;
                 IF (Hours<23) THEN BEGIN
                     Inc(Hours) ;
                 END
                 ELSE BEGIN
                     Hours := 0 ;
                     PokeW($41C,Succ(PeekW($41C))) ; { Days }
                 END ;
                 PokeB($41B,Hours) ;
             END ;
             PokeB($41A,Minutes) ;
         END ;
         PokeB($419,Seconds) ;
     END ;
     PokeB($418,MilliSeconds) ;

{
     Update Stop Watches
}

     code_StopWatch(SU0) ;
     code_StopWatch(SU1) ;
     code_StopWatch(SU2) ;
     code_StopWatch(SU3) ;

{
     This Section displays the current UHR Time. It is not a part of IPS!
}

     IF (ShowClock) THEN BEGIN

         WriteStr(IPS_XOFFSET+44,IPS_YOFFSET+16,
         ' ' +
         WtoS(PeekW($41C)) + ' ' +
         WtopS(PeekB($41B),2) + ':' +
         WtopS(PeekB($41A),2) + ':' +
         WtopS(PeekB($419),2) + '.' +
         WtopS(PeekB($418),2) + ' ') ;

     END ;

END { code_uhr } ;

PROCEDURE code_ipptrcheck ;
BEGIN
    IF (PeekB(READYFLAG) = 0) THEN BEGIN
        IF (PeekW(PE)<INPUTPOINTER) OR (PeekW(PE)<LOADPOINTER) THEN BEGIN
            PokeB(READYFLAG,1) ;
        END ;
    END ;
END { code_ipptrcheck } ;

{
    Service Keyboard
}

PROCEDURE code_keyb ;
VAR
     InChar   : BYTE ;
     Index    : WORD ;
     MacroPtr : KeyboardMacroPtr ;
BEGIN

    WHILE (Not TimeToStop) AND (KeyPressed) DO BEGIN

{
    Remove Blob Cursor
}

         PokeB(INPUTPOINTER,PeekB(INPUTPOINTER) AND $7F) ;

         InChar := ReadKey ;

{
    PC Control Keys
}

         IF (InChar=$00) THEN BEGIN

             InChar := ReadKey ;

             CASE InChar OF
             71 : BEGIN { Home }
                       INPUTPOINTER := TV8 ;
                  END ;
             72 : BEGIN { Up Arrow }
                       Dec(INPUTPOINTER,64) ;
                  END ;
             75 : BEGIN { Left Arrow }
                       Dec(INPUTPOINTER) ;
                  END ;
             77 : BEGIN { Right Arrow }
                       Inc(INPUTPOINTER) ;
                  END ;
             79 : BEGIN { End }
                       INPUTPOINTER := TVE ;
                  END ;
             80 : BEGIN { Down Arrow }
                       Inc(INPUTPOINTER,64) ;
                  END ;
             82 : BEGIN { Insert }
                       InsertON := NOT InsertON ;
                  END ;
             83 : BEGIN { Delete }
                       FOR Index := INPUTPOINTER TO Pred(TVE) DO BEGIN
                           PokeB(Index,PeekB(Succ(Index))) ;
                       END ;
                       PokeB(TVE,32) ;
                  END ;
             45 : BEGIN { Alt-X }
                       TimeToStop := True ;
                  END ;
             ELSE
                 MacroPtr := KeyboardMacros ;
                 WHILE (MacroPtr<>NIL) AND (MacroPtr^.ScanCode<>InChar) DO BEGIN
                     MacroPtr := MacroPtr^.NextMacro ;
                 END ;
                 IF (MacroPtr<>NIL) THEN BEGIN
                     WITH MacroPtr^ DO BEGIN
                         INPUTPOINTER := TV8 ;
                         FOR Index := 1 TO Length(Macro) DO BEGIN
                             PokeB(INPUTPOINTER,BYTE(Macro[Index])) ;
                             Inc(INPUTPOINTER) ;
                         END ;
                         PokeW(PE, Pred(INPUTPOINTER)) ;
                     END ;
                 END ;
             END ;

             INPUTPOINTER := INPUTPOINTER AND $3FF ;

         END

{
     Return! ... do stuff!
}

         ELSE IF (InChar = 13) THEN BEGIN
             PokeW(PE, Pred(INPUTPOINTER)) ;
         END
         ELSE IF (InChar = 8) THEN BEGIN { BackSpace }
             INPUTPOINTER := Pred(INPUTPOINTER) AND $3FF ;
             PokeB(INPUTPOINTER,32) ;
             IF (InsertON) THEN BEGIN
                 FOR Index := INPUTPOINTER TO TVE DO BEGIN
                     PokeB(Index,PeekB(Succ(Index))) ;
                 END ;
                 PokeB(TVE,32) ;
             END ;
         END

         ELSE BEGIN
             IF (InsertON) AND (TV8<=INPUTPOINTER) THEN BEGIN
                 FOR Index := TVE DOWNTO Succ(INPUTPOINTER) DO BEGIN
                     PokeB(Index,PeekB(Pred(Index))) ;
                 END ;
             END ;
             PokeB(INPUTPOINTER, InChar) ;
             INPUTPOINTER := Succ(INPUTPOINTER) AND $3FF ;
         END ;

{
    Put Blob Cursor On Screen iff not end of input
}

         IF (INPUTPOINTER<=PeekW(PE)) THEN BEGIN
             PokeB(INPUTPOINTER,PeekB(INPUTPOINTER) OR $80) ;
         END ;

    END ;

END { code_keyb } ;

{
    Service source file READ
}

PROCEDURE code_file_in ;
VAR
     RowCount : BYTE    ;
     ColCount : BYTE    ;
     sLine    : STRING  ;
     InEOL    : BOOLEAN ;
     InChar   : CHAR    ;
BEGIN

     IF (IsOpen) AND (PeekB(READYFLAG)=0) AND (PeekB(LOADFLAG)=1) THEN BEGIN
         IF (Eof(TextFile)) THEN BEGIN
             PokeB(LOADFLAG,0) ;
             code_closefile ;
         END
         ELSE BEGIN
             FOR LOADPOINTER := TV8 TO TVE DO BEGIN
                 PokeB(LOADPOINTER,32) ;
             END ;
             LOADPOINTER := TV8 ;
             RowCount := 8 ;
             WHILE (Not Eof(TextFile)) AND (0<RowCount) DO BEGIN

                 FillChar(sLine,SizeOf(sLine),$20) ;
                 ColCount := 1 ;
                 InEOL := FALSE ;

                 WHILE (NOT Eof(TextFile)) AND (NOT InEOL) DO BEGIN
                     Read(TextFile,InChar) ;
                     InEOL := Ord(InChar) < $20 ;
                     IF (NOT InEOL) AND (ColCount<65) THEN BEGIN
                         sLine[ColCount] := InChar ;
                         Inc(ColCount) ;
                     END ;
                 END ;
                 sLine[0] := CHAR(64) ;
                 FOR ColCount := 1 TO 64 DO BEGIN
                     PokeB(LOADPOINTER,BYTE(sLine[ColCount])) ;
                     Inc(LOADPOINTER) ;
                 END ;
                 Dec(RowCount) ;
             END ;
             IF (Eof(TextFile)) THEN BEGIN
                 PokeB(LOADFLAG,0) ;
                 code_closefile ;
             END ;
             PokeW(PE,Pred(LOADPOINTER)) ;
         END ;
     END ;

END { code_file_in } ;

{
    Aux I/O 20ms Service Routine
    *** WORK IN PROGRESS ***
}

PROCEDURE code_aux_io ;
VAR
     AuxPort : WORD ;
BEGIN
     IF (KernalType<>IPSXKernal) THEN BEGIN
         FOR AuxPort := 1 TO MaxAuxDev DO BEGIN
             RXStreams[AuxPort](AuxPort) ;
             TXStreams[AuxPort](AuxPort) ;
             AuxOutChar(AuxPort) ;
         END ;
     END ;
END { code_aux_io } ;

{
     Inner Interpretor Loop
}

PROCEDURE RunKernal ;
VAR
     Index : WORD ;
BEGIN

{
     Build Screen Display
}

     TextColor := IntenseWhite ;
     TextBackground := Black ;
     ClrScr ;
     TextBackground := Blue ;

{
     Draw Frame
}

     WriteStr(IPS_XOFFSET-1,IPS_YOFFSET-1,KC_TLS+Strng(KC_HRS,1)+' Meinzer M-9097 IPS Computer '+Strng(KC_HRS,34)+KC_TRS) ;
     FOR Index := 0 TO 15 DO BEGIN
         WriteStr(IPS_XOFFSET-1,IPS_YOFFSET+Index,KC_VTS+Strng(SPC,64)+KC_VTS) ;
     END ;
     WriteStr(IPS_XOFFSET-1,IPS_YOFFSET+16,KC_BLS+Strng(KC_HRS,1)+Version+Strng(KC_HRS,63-Length(Version))+KC_BRS) ;

{
     Load Kernel and Initialize Emulator
}

     ReloadKernal ;

     TimeToStop := FALSE ;
     InsertON   := TRUE  ;

     REPEAT

{
     Command Dispatcher
}

{ emu }
           HP := PeekW(PPC) ;
           PPC := PPC + 2 ;
{ exec }
           CPC := PeekW(HP) ;
           HP := HP + 2 ;
           JumpTable[Lo(CPC)] ;
{ ret }

{
    20ms Pseudo Interrupt Handler
}

           IF (Do20msIntr) THEN BEGIN
               code_uhr        ; { update time/stopwatches          }
               code_ipptrcheck ; { block is ready to be processed ? }
               code_keyb       ; { service keyboard                 }
               code_file_in    ; { service file input               }
               code_aux_io     ; { service serial in/out            }
               Do20msIntr := FALSE ;
           END ;

{
     Keep going until <ALT>+X pressed!
}

     UNTIL (TimeToStop) ;

END { RunKernal } ;

END. { _20ms }

