PROGRAM IPSXASM ;

{
------------------------------------------------------------------------

                        IPS-X Assembler 1.0.2

                   (c) 2001 Paul Willmott, VP9MU

------------------------------------------------------------------------


The IPS-X Assembler (IPSXASM) is a simple utility designed to build
IPS-X Cross Compiler kernals for IPS virtual machines. Though it
forms part of the IPSDOS implementation, it may be used to create
kernals for any 16-bit IPS virtual machine.

IPSXASM converts the tokens and directives in the input source code
file into the IPS-X kernal binary image. The source code syntax is
similar to regular IPS-M, however IPSXASM is NOT a real complete IPS
implementation.

------------------------------------------------------------------------

}

{$a-} { byte-align data within records }
{$b-} { Short-Circuit Boolean Evaluation - Like C! }
{$d-} { Debug Info Off }
{$e+} { Link 80x87 emulator for old machines, ... Only used if 80x87 not present }
{$f+} { Force Far Calls for JumpTable }
{$g+} { Use 80286 instructions }
{$l-} { Local symbols Off }
{$n+} { Use IEEE floating point types }
{$q-} { Disable Overflow checking }
{$o-} { Disable Overlays }
{$r-} { Range Checking Off }
{$s-} { Stack Overflow Checking Off }
{$t-} { Type checking on pointers off }
{$v-} { Var-String Checking Off }

USES

     Strings ,
     TypeDefs ;

CONST

     MaxImageSize = $4000 ;
     MaxStackSize = $200 ;
     HexChar : ARRAY[$0..$f] OF CHAR = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F') ;

     I_DEFEX      = 0  ;
     I_VAREX      = 2  ;
     I_CONSEX     = 4  ;
     I_2BLITERAL  = 6 ;
     I_1BLITERAL  = 8  ;
     I_BRONZ      = 10 ;
     I_JUMP       = 12 ;
     I__JEEX      = 14 ;
     I_LOOPEX     = 16 ;
     I_PLUSLOOPEX = 18 ;
     I_RETEX      = 20 ;


TYPE

     DictionaryEntryPtr = ^DictionaryEntry ;

     DictionaryEntry = RECORD
                             Identifier : STRING[63]         ;
                             DictAddr   : WORD               ;
                             NextEntry  : DictionaryEntryPtr ;
                             LastEntry  : DictionaryEntryPtr ;
                       END { DictionaryEntry } ;

     MacroDefinitionPtr = ^MacroDefinition ;

     MacroDefinition = RECORD
                             Identifier : STRING[63] ;
                             Macro      : STRING[255] ;
                             NextEntry  : MacroDefinitionPtr ;
                       END { MacroDefinition } ;

     MacroBufferPtr = ^MacroBuffer ;

     MacroBuffer     = RECORD
                             Macro      : STRING[255] ;
                             NextEntry  : MacroBufferPtr ;
                       END { MacroBuffer } ;

VAR

     MemImage    : ARRAY[0..MaxImageSize-1] OF BYTE ; { Assembled IPS-X Memory Image                          }
     _H          : WORD ;                             { Pointer to Free Memory Position                       }
     _KK         : WORD ;                             { Address of Start of Current Dictionary Entry          }
     CompileFlag : BOOLEAN ;                          { True if compiling a Definition                        }
     EchoFlag    : BOOLEAN ;                          { True if Input Stream echoed during assembly           }
     InComment   : BOOLEAN ;                          { TRUE if inside a Comment                              }
     FromFile    : BOOLEAN ;
     ASMFlag     : BOOLEAN ;                          { TRUE when in Assembler Mode, Numbers written to Image }
     Stack       : ARRAY[0..MaxStackSize-1] OF WORD ; { Stack for Jump Addresses etc                          }
     StackPtr    : WORD ;                             { Pointer to Next Free Position on Stack                }
     Dictionary  : DictionaryEntryPtr ;               { Pointer to Start of Dictionary List                   }
     MacroList   : MacroDefinitionPtr ;               { Pointer to Start of Macro List                        }
     MacroStack  : MacroBufferPtr ;                   { Macro Input Buffer                                    }
     SourceFile  : FILE OF CHAR ;                     { Input Source Code File                                }
     OutFile     : FILE OF BYTE ;                     { Memory Image File }
     InWordStr   : STRING ;                           { Word from Source File to Process                      }
     InString    : BOOLEAN ;                          { TRUE if inside String Literal                         }
     sLiteral    : STRING ;                           { String Literal may be used once only                  }
     LogFile     : TEXT ;
     bb          : CHAR ;
     kk          : BYTE ;
     BaseName    : STRING ; { Base Filename, e.g. "IPS-MP" from "IPS-MP.SRC" }
     ExitSave    : POINTER ;

{
    Tidy-Up and De-Allocate dynamic variables
}

PROCEDURE MyExit ;
VAR
     DPtr  : DictionaryEntryPtr ;
     MLPtr : MacroDefinitionPtr ;
     MSPtr : MacroBufferPtr ;
BEGIN

{
     Pass Control to Next Exit Procedure <- Always First!
}

     ExitProc := ExitSave ;

{
     De-Allocate Virtual Memory Space
}

     WHILE (Dictionary<>NIL) DO BEGIN
         DPtr := Dictionary^.NextEntry ;
         Dispose(Dictionary) ;
         Dictionary := DPtr ;
     END ;
     WHILE (MacroList<>NIL) DO BEGIN
         MLPtr := MacroList^.NextEntry ;
         Dispose(MacroList) ;
         MacroList := MLPtr ;
     END ;
     WHILE (MacroStack<>NIL) DO BEGIN
         MSPtr := MacroStack^.NextEntry ;
         Dispose(MacroStack) ;
         MacroStack := MSPtr ;
     END ;

END { MyExit } ;

{
     Error Handler
}

PROCEDURE CompileError(sError:STRING) ;
BEGIN
     Close(SourceFile) ;
     WriteLn(sError) ;
     WriteLn('Press <Enter> to Finish...') ;
     ReadLn ;
     Halt(1) ;
END { CompileError } ;

{
     Hex Conversions
}

FUNCTION HexStrB(bb:WORD):STRING ;
BEGIN
     bb := bb AND $FF ;
     HexStrB := HexChar[bb SHR 4] + HexChar[bb AND $F] ;
END ;

FUNCTION HexStr(ww:WORD):STRING ;
BEGIN
     HexStr := HexStrB(Hi(ww))+HexStrB(Lo(ww)) ;
END ;

{
     Stack Operators
}

PROCEDURE PushW(M:WORD) ;
BEGIN
     IF (StackPtr=0) THEN BEGIN
         CompileError('Stack Overflow') ;
     END ;
     Stack[StackPtr] := M ;
     Dec(StackPtr) ;
END { PushW } ;

PROCEDURE PushI(M:INTEGER) ;
BEGIN
     PushW(WORD(M)) ;
END { PushI } ;

FUNCTION PopW:WORD ;
BEGIN
     IF (StackPtr=MaxStackSize-1) THEN BEGIN
         CompileError('Stack Underflow') ;
     END ;
     Inc(StackPtr) ;
     PopW := Stack[StackPtr] ;
END { PopW } ;

FUNCTION PopI:INTEGER ;
BEGIN
     PopI := INTEGER(PopW) ;
END { PopI } ;

{
     Memory Image Manipulators
}

FUNCTION PeekB(Addr:WORD):BYTE ;
BEGIN
     PeekB := MemImage[Addr] ;
END { PeekB } ;


FUNCTION PeekW(Addr:WORD):WORD ;
BEGIN
     PeekW := PeekB(Addr) + PeekB(Succ(Addr)) SHL 8 ;
END { PeekW } ;

PROCEDURE PokeB(Addr,Value:WORD) ;
BEGIN
     IF (Addr>MaxImageSize-1) THEN BEGIN
         CompileError('Write to memory outside of Image Buffer attempted.') ;
     END ;
     MemImage[Addr] := Lo(Value) ;
END { PokeB } ;

PROCEDURE PokeW(Addr,Value:WORD) ;
BEGIN
     PokeB(Addr      ,Lo(Value)) ;
     PokeB(Succ(Addr),Hi(Value)) ;
END { PokeW } ;

{
     This routine returns the address of the start of
     a dictionary entry for requested identifier.

     Returns $0000 if not found
}

FUNCTION GetDictAddr(sIdentifier:STRING):WORD ;
VAR
     tPtr : DictionaryEntryPtr ;
BEGIN
     sIdentifier := Trim(sIdentifier) ;
     GetDictAddr := $0000 ;
     tPtr := Dictionary ;
     WHILE (tPtr<>NIL) AND (tPtr^.Identifier<>sIdentifier) DO BEGIN
         tPtr := tPtr^.NextEntry ;
     END ;
     IF (tPtr<>NIL) THEN BEGIN
         GetDictAddr := tPtr^.DictAddr ;
     END ;
END { GetDictAddr } ;

FUNCTION GetDictIdentifier(Addr:WORD):STRING ;
VAR
     tPtr : DictionaryEntryPtr ;
BEGIN
     GetDictIdentifier := '' ;
     tPtr := Dictionary ;
     WHILE (tPtr<>NIL) AND (tPtr^.DictAddr+6<>Addr) DO BEGIN
         tPtr := tPtr^.NextEntry ;
     END ;
     IF (tPtr<>NIL) THEN BEGIN
         GetDictIdentifier := tPtr^.Identifier ;
     END ;
END { GetDictIdentifier } ;

{
     This routine gets a $CCODE table value
}

FUNCTION GetCCODE(Index:WORD):WORD ;
VAR
     nAddr : WORD ;
BEGIN
     nAddr := GetDictAddr('$CCODES')+8 ;
     IF (nAddr=$0000) THEN BEGIN
         CompileError('The field $CCODES has not be defined in the source code.') ;
     END ;
     GetCCODE := PeekW(nAddr+Index) ;
END { GetCCODE } ;

{
     Macro Word Handler
}

FUNCTION MacroWord(NewIdentifier:STRING;Test:BOOLEAN):BOOLEAN ;
VAR
     TokenFound : BOOLEAN ;
     ListPtr    : MacroDefinitionPtr ;
     tPtr       : MacroBufferPtr ;
BEGIN
     TokenFound := FALSE ;
     ListPtr := MacroList ;
     NewIdentifier := Trim(NewIdentifier) ;
     WHILE (NOT TokenFound) AND (ListPtr<>NIL) DO BEGIN
         IF (ListPtr^.Identifier=NewIdentifier) THEN BEGIN
             TokenFound := TRUE ;
             IF (NOT Test) THEN BEGIN
                 New(tPtr) ;
                 tPtr^.NextEntry := MacroStack ;
                 tPtr^.Macro := ListPtr^.Macro ;
                 MacroStack := tPtr ;
                 tPtr := NIL ;
             END ;
         END ;
         ListPtr := ListPtr^.NextEntry ;
     END ;
     MacroWord := TokenFound ;
END { MacroWord } ;

{
     This routine gets the next byte from the input stream; File or Macro Stack

     Returns TRUE if successful or FALSE if end of input is reached
}

FUNCTION GetByte(VAR cc:CHAR):BOOLEAN ;

VAR

     GotChar : BOOLEAN        ;
     tPtr    : MacroBufferPtr ;

BEGIN

     GotChar := FALSE ;

     IF (MacroStack<>NIL) THEN BEGIN
         tPtr := MacroStack ;
         WITH tPtr^ DO BEGIN
             cc := Macro[1] ; { Get first character of string }
             GotChar := TRUE ;
             Move(Macro[2],Macro[1],Length(Macro)-1) ; Dec(Macro[0]) ; { Delete 1st character of string }
             IF (Length(Macro)=0) THEN BEGIN { When the string is empty remove entry from stack }
                 MacroStack := NextEntry ;
                 Dispose(tPtr) ;
             END ;
         END ;
     END ;

     IF (NOT GotChar) AND (NOT Eof(SourceFile)) THEN BEGIN
         Read(SourceFile,cc) ;
         IF (NOT (cc IN [' '..'~'])) THEN BEGIN { replace all control characters with spaces }
             cc := ' ' ;
         END ;
         GotChar := TRUE ;
     END ;
     IF (EchoFlag) THEN BEGIN
         Write(cc) ;
     END ;

     GetByte := GotChar ;

END { GetByte } ;

{
     This routine gets a sequence of characters from the input stream upto and
     including the requested delimiter character.

     Returns the requested string in ss.

     The function returns TRUE if successful or FALSE if end of input is reached.
}

FUNCTION GetNextWord(DelimChar:CHAR;VAR InWordStr:STRING):BOOLEAN ;

VAR

     GotToken  : BOOLEAN ;
     cc        : CHAR ;
     Quit      : BOOLEAN ;
BEGIN

     InWordStr := '' ;
     GotToken := FALSE ;

     IF (DelimChar=' ') THEN BEGIN
         WHILE (GetByte(cc)) AND (cc=' ') DO BEGIN
         END ;
     END
     ELSE BEGIN
         IF (GetByte(cc)) THEN ;
     END ;
     Quit := FALSE ;
     WHILE (NOT Quit) AND (NOT GotToken) DO BEGIN
         InWordStr := InWordStr + cc ;
         IF (cc=DelimChar) THEN BEGIN
             GotToken := TRUE ;
         END ;
         IF (NOT GotToken) AND (NOT (GetByte(cc))) THEN BEGIN
             Quit := TRUE ;
         END ;
     END ;

     IF (Length(InWordStr)<>0) AND (NOT (GotToken)) AND (DelimChar=' ') THEN BEGIN
         InWordStr := InWordStr + DelimChar ;
         GotToken := TRUE ;
     END ;

     GetNextWord := GotToken ;

END { GetNextWord } ;

{
     This routine writes a byte to the memory image
     and increments the memory pointer
}

PROCEDURE WriteToImageB(bb:BYTE) ;
BEGIN
     PokeB(_H,bb) ;
     Inc(_H) ;
END { WriteToImageB } ;

{
     This routine writes a word to the memory image
     and increments the memory pointer as necessary
}

PROCEDURE WriteToImage(ww:WORD) ;
BEGIN
     WriteToImageB(Lo(ww)) ;
     WriteToImageB(Hi(ww)) ;
END { WriteToImage } ;

{
     This routine writes a numeric literal to the Image
}

PROCEDURE WriteLiteral(ww:WORD) ;
BEGIN
     IF (CompileFlag) THEN BEGIN
         IF (ww<$100) THEN BEGIN
             WriteToImage(GetCCODE(I_1BLITERAL)) ;
             WriteToImageB(Lo(ww)) ;
         END
         ELSE BEGIN
             WriteToImage(GetCCODE(I_2BLITERAL)) ;
             WriteToImage(ww) ;
         END ;
     END
     ELSE BEGIN
         PushW(ww) ;
     END ;
END { WriteLiteral } ;

{
     Numeric Value Handler
}

FUNCTION NumericValue(InWordStr:STRING;Test:BOOLEAN):BOOLEAN ;
VAR
     IsHex : BOOLEAN ;
     Basis : LONGINT ;
     NumberGood : BOOLEAN ;
     Digit : LONGINT ;
     Value : LONGINT ;
     Sign  : LONGINT ;
     ii, jj : INTEGER ;
     WValue : WORD ;
     IValue : INTEGER ;
BEGIN

     NumberGood := FALSE ;

     InWordStr := Trim(InWordStr) ;

     IF (InWordStr<>'') THEN BEGIN

         IsHex := (InWordStr[1]='#') ;

         IF (IsHex) THEN BEGIN
             Basis := 16 ;
             InWordStr := Right(InWordStr,Length(InWordStr)-1) ;
         END
         ELSE BEGIN
             IF (InWordStr[1]='-') THEN BEGIN
                 Sign := -1 ;
                 InWordStr := Right(InWordStr,Length(InWordStr)-1) ;
             END
             ELSE BEGIN
                 Sign := +1 ;
             END ;
             Basis := 10 ;
         END ;

         IF (InWordStr<>'') THEN BEGIN
             Value := 0 ;
             FOR ii := 1 TO Length(InWordStr) DO BEGIN
                 Digit := -1 ;
                 FOR jj := 0 TO Basis-1 DO BEGIN
                     IF (InWordStr[ii]=HexChar[jj]) THEN BEGIN
                         Digit := jj ;
                     END ;
                 END ;
                 IF (Digit=-1) THEN BEGIN
                     Exit ;
                 END
                 ELSE BEGIN
                     Value := Value * Basis + Digit ;
                 END ;
             END ;

             IF (IsHex) THEN BEGIN
                 IF (Value<0) OR (Value>$FFFF) THEN BEGIN
                     Exit ;
                 END ;
                 WValue := Value AND $FFFF ;
                 IF (NOT Test) THEN BEGIN
                     WriteLiteral(WValue) ;
                 END ;
             END
             ELSE BEGIN
                 Value := Value * Sign ;
                 IF (Value<-32768) OR (Value>32767) THEN BEGIN
                     Exit ;
                 END ;
                 IValue := Value ;
                 IF (NOT Test) THEN BEGIN
                     WriteLiteral(WORD(IValue)) ;
                 END ;
             END ;

             NumberGood := TRUE ;

         END ;

     END ;

     NumericValue := NumberGood ;

END { NumericValue } ;

{
     Defined Word Handler
}

FUNCTION DefinedWord(InWordStr:STRING;Test:BOOLEAN):BOOLEAN ;
VAR
     DictEntry : DictionaryEntryPtr ;
     GotWord   : BOOLEAN            ;
     nType     : WORD               ;
     nAddr     : WORD               ;
BEGIN
     InWordStr := Trim(InWordStr) ;
     DefinedWord := FALSE ;
     GotWord := FALSE ;
     DictEntry := Dictionary ;
     WHILE (NOT GotWord) AND (DictEntry<>NIL) DO BEGIN
         IF (InWordStr=DictEntry^.Identifier) THEN BEGIN
             IF (NOT Test) THEN BEGIN
                 nAddr := DictEntry^.DictAddr+6 ;
                 IF (CompileFlag) THEN BEGIN
                     WriteToImage(nAddr) ;
                 END
                 ELSE BEGIN
                     nType := PeekW(nAddr) ;
                     IF (nType=GetCCODE(I_CONSEX)) THEN BEGIN
                         PushW(PeekW(nAddr+2)) ;
                     END
                     ELSE IF (nType=GetCCODE(I_VAREX)) THEN BEGIN
                         PushW(nAddr+2) ;
                     END
                     ELSE BEGIN
                         CompileError('Definition calls not allowed outside compile mode') ;
                     END ;
                 END ;
             END ;
             GotWord := TRUE ;
         END ;
         DictEntry := DictEntry^.NextEntry ;
     END ;

     DefinedWord := GotWord ;

END { DefinedWord } ;

{
     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Page 76 - 5.2.1 Scanner and name coding
                 Page 81 - 5.4 Entry generating routines ($POLYNAME examaple!!!!)
}

FUNCTION PolyName(S:STRING):LONGINT ;
VAR
     A : WORD ;
     B : WORD ;
     C : WORD ;
     D : LONGINT ;
     X : LONGINT ;
     P : LONGINT ;
     I : Byte ;
     Hash : LONGINT ;
BEGIN

     Hash := $8dce57 ;

     FOR I := 1 to Length(S) DO BEGIN

         D := Ord(S[I]) ;

{
     "WEG/AB" encodes as #D5 #10 #17
}

         C := DWordRecType(Hash).Hi ;      { 008d }
         B := DWordRecType(Hash).Lo ;      { ce57 }
         A := Lo(B) ;
         B := Hi(B) ;

{
     X = #57CE8D <- Seed
}

         DWordRecType(X).Hi := A ;
         WordRecType(DWordRecType(X).Lo).Hi := B ;
         WordRecType(DWordRecType(X).Lo).Lo := C ;

         P := D Xor X Xor (X SHR 1) Xor (X SHR 2) Xor (X SHR 7) ;

         WordRecType(DWordRecType(X).Hi).Hi := Lo(DWordRecType(P).Lo) ;
         WordRecType(DWordRecType(X).Hi).Lo := A ;
         WordRecType(DWordRecType(X).Lo).Hi := B ;
         WordRecType(DWordRecType(X).Lo).Lo := C ;

         X := X SHR 7 ;

         A := Lo(DWordRecType(X).Hi) ;
         B := Hi(DWordRecType(X).Lo) ;
         C := Lo(DWordRecType(X).Lo) ;

         DWordRecType(Hash).Hi := C ;
         DWordRecType(Hash).Lo := B * 256 + A ;

     END ;

     PolyName := Hash ;

END { PolyName } ;

FUNCTION ReservedWord(InWordStr:STRING;Test:BOOLEAN):BOOLEAN ; FORWARD ;

{
     Setup Dictionary Entry
}

PROCEDURE EntrySetup(CodeAddr,EntryType:WORD) ;

VAR

     Hash      : LONGINT            ;
     DictEntry : DictionaryEntryPtr ;
     InWordStr : STRING             ;
     Temp : WORD ;

BEGIN

{
     Get the Entry Name
}

     IF (NOT (GetNextWord(' ',InWordStr))) THEN BEGIN
         CompileError('Syntax Error.') ;
     END ;

     InWordStr := Trim(InWordStr) ;

{
     Check its not already used
}

     IF (MacroWord   (InWordStr,TRUE)) OR
        (ReservedWord(InWordStr,TRUE)) OR
        (DefinedWord (InWordStr,TRUE)) THEN BEGIN
         CompileError('The token ' + InWordStr + ' is a duplicate.') ;
     END ;

{
     Create New Dictionary Entry
}

     New(DictEntry) ;

     DictEntry^.NextEntry := Dictionary ;
     Dictionary^.LastEntry := DictEntry ;
     DictEntry^.LastEntry := NIL ;
     Dictionary := DictEntry ;
     DictEntry^.Identifier := InWordStr ;

     Hash := PolyName(InWordStr) ;

     DictEntry^.DictAddr := _H ;

{
     Write to Memory Image
}

     WriteToImageB(Length(InWordStr) OR EntryType) ;
     WriteToImageB(Lo(DWordRecType(Hash).Lo)) ;
     WriteToImageB(Hi(DWordRecType(Hash).Lo)) ;
     WriteToImageB(Lo(DWordRecType(Hash).Hi)) ;
     WriteToImage(_KK)                    ;
     WriteToImage(CodeAddr) ;

{
     Store Link for Next Entry
}

     _KK := DictEntry^.DictAddr ;

END ;

FUNCTION ReservedWord ;

VAR

     NoneFound : BOOLEAN ;
     tStr      : STRING  ;
     MacroDone : BOOLEAN ;
     MacroDef  : MacroDefinitionPtr ;
     sID       : STRING ;
     cc        : CHAR   ;
     sTag      : STRING ;
     nAddr     : WORD   ;
     nVal      : WORD   ;
     SourceAddr      : WORD ;
     DestinationAddr : WORD ;
     Count           : WORD ;
     B               : BYTE ;
     M : INTEGER ;
     Hash : LONGINT ;
     DictEntry : DictionaryEntryPtr ;

BEGIN

     NoneFound := FALSE ;

     InWordStr := Trim(InWordStr) ;

{
     Gobble Up Comments
}

     IF (InWordStr='(') THEN BEGIN
         sTag := InWordStr+' ' ;
         WHILE (sTag<>' )') AND (GetByte(cc)) DO BEGIN
             sTag[1] := sTag[2] ;
             sTag[2] := cc ;
         END ;
         InComment := (sTag = ' )') ;
     END

{
     Handle Macro Definitions
}

     ELSE IF (InWordStr=':MACRO') THEN BEGIN

         IF (NOT Test) THEN BEGIN

             IF (NOT ((GetNextWord(' ',InWordStr)) AND (Trim(InWordStr)<>';MACRO'))) THEN BEGIN
                 CompileError('Syntax Error.') ;
             END ;

             sID := Trim(InWordStr) ;

             IF (MacroWord(sID,TRUE)) OR
                (ReservedWord(sID,TRUE)) OR
                (DefinedWord(sID,TRUE)) THEN BEGIN
                 CompileError('The Macro name ' + InWordStr + ' is already used.') ;
             END ;

             tStr := ' ' ;

             WHILE ((GetNextWord(' ',InWordStr)) AND (Trim(InWordStr)<>';MACRO')) DO BEGIN
                 InWordStr := Trim(InWordStr) ;

                 IF (NOT (MacroWord(InWordStr,TRUE))) AND
                    (NOT (ReservedWord(InWordStr,TRUE))) AND
                    (NOT (DefinedWord(InWordStr,TRUE))) AND
                    (NOT (NumericValue(InWordStr,TRUE))) THEN BEGIN
                     CompileError('The token ' + InWordStr + ' is not numeric or is unknown.') ;
                 END ;

                 tStr := tStr + InWordStr + ' ' ;

             END ;

             IF (Trim(InWordStr)=';MACRO') THEN BEGIN
                 New(MacroDef) ;
                 WITH MacroDef^ DO BEGIN
                      Identifier := sID ;
                      Macro := tStr ;
                      NextEntry := MacroList ;
                 END ;
                 MacroList := MacroDef ;
             END
             ELSE BEGIN
                 CompileError('Macro definition not completed.') ;
             END ;

         END ;

     END

{
     Store Memory Pointer
}

     ELSE IF (InWordStr='!$H') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             _H := PopW ;
         END ;
     END

     ELSE IF (InWordStr=',') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             PokeB(_H,PopW) ;
             Inc(_H) ;
         END ;
     END

     ELSE IF (InWordStr='@LINK') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             PushW(_KK) ;
         END ;
     END

     ELSE IF (InWordStr='H2INC') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             Inc(_H,2) ;
         END ;
     END

     ELSE IF (InWordStr='$DEP') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             PokeW(_H,PopW) ;
             Inc(_H,2) ;
         END ;
     END

     ELSE IF (InWordStr='INCR') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             nAddr := PopW ;
             PokeW(nAddr,Succ(PeekW(nAddr))) ;
         END ;
     END

     ELSE IF (InWordStr='KON') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             EntrySetup(GetCCODE(I_CONSEX),0) ;
             WriteToImage(PopW) ;
         END ;
     END

     ELSE IF (InWordStr='VAR') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             EntrySetup(GetCCODE(I_VAREX),0) ;
             WriteToImage(PopW) ;
         END ;
     END

     ELSE IF (InWordStr='FELD') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             EntrySetup(GetCCODE(I_VAREX),0) ;
             Inc(_H,PopW) ;
         END ;
     END

     ELSE IF (InWordStr='RCODE') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             EntrySetup(PopW,0) ;
         END ;
     END

     ELSE IF (InWordStr=':') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             EntrySetup(GetCCODE(I_DEFEX),0) ;
             CompileFlag := TRUE ;
         END ;
     END

     ELSE IF (InWordStr=':HPRI') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             EntrySetup(GetCCODE(I_DEFEX),$40) ;
             CompileFlag := TRUE ;
         END ;
     END

     ELSE IF (InWordStr=':PRIOR') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             EntrySetup(GetCCODE(I_DEFEX),$80) ;
             CompileFlag := TRUE ;
         END ;
     END

     ELSE IF (InWordStr=':INT') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             EntrySetup(GetCCODE(I_DEFEX),$C0) ;
             CompileFlag := TRUE ;
         END ;
     END

{
     Turn Echo On
}

     ELSE IF (InWordStr='ECHO-ON') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             EchoFlag := TRUE ;
         END ;
     END

{
     Turn Echo Off
}

     ELSE IF (InWordStr='ECHO-OFF') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             EchoFlag := FALSE ;
         END ;
     END

{
     Exit Compile Mode
}

     ELSE IF (InWordStr='A>') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             CompileFlag := FALSE ;
         END ;
     END

{
     Enter Compile Mode
}

     ELSE IF (InWordStr='<A') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             CompileFlag := TRUE ;
         END ;
     END

{
     Modify Header
}

     ELSE IF (InWordStr='PRIMODIFY') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             PokeB(_KK,PeekB(_KK) OR Lo(PopW)) ;
         END ;
     END


{
     Push Memory Pointer to Stack or Image
}

     ELSE IF (InWordStr='HIER') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             PushW(_H) ;
         END ;
     END

{
     Store in Image
}

     ELSE IF (InWordStr='!') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             nAddr := PopW ;
             PokeW(nAddr,PopW) ;
         END ;
     END

{
     Store Byte in Image
}

     ELSE IF (InWordStr='!B') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             nAddr := PopW ;
             PokeB(nAddr,PopW) ;
         END ;
     END

{
     Get From Image
}

     ELSE IF (InWordStr='@') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             PushW(PeekW(PopW)) ;
         END ;
     END

{
     Get Byte From Image
}

     ELSE IF (InWordStr='@B') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             PushW(PeekB(PopW)) ;
         END ;
     END

{
     Store Field Components
}

     ELSE IF (InWordStr='!FK') THEN BEGIN

         IF (NOT Test) THEN BEGIN

             nVal := PopW ;
             nAddr := PopW ;

             WHILE (nVal<>0) DO BEGIN
                 PokeW(nAddr+(nVal-1)*2, PopW) ;
                 Dec(nVal) ;
             END ;

         END ;

     END

{
     Swap top 2 stack entries
}

     ELSE IF (InWordStr='VERT') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             nAddr := PopW ;
             nVal := PopW ;
             PushW(nAddr) ;
             PushW(nVal) ;
         END ;
     END

{
     Duplicate top of stack
}

     ELSE IF (InWordStr='DUP') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             nVal := PopW ;
             PushW(nVal) ;
             PushW(nVal) ;
         END ;
     END

{
     Field Translate Long
}

     ELSE IF (InWordStr='L>>>') THEN BEGIN

         IF (NOT Test) THEN BEGIN

             Count           := PopW ;
             DestinationAddr := PopW ;
             SourceAddr      := PopW ;

             REPEAT
                   PokeB(DestinationAddr,MemImage[SourceAddr]) ;
                   Inc(SourceAddr) ;
                   Inc(DestinationAddr) ;
                   Dec(Count) ;
             UNTIL (Count = 0) ;

         END ;

     END

{
     +   Adds 2 2s complement words.
     <n> <m> +
     <n+m>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

     ELSE IF (InWordStr='+') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             PushI(PopI+PopI) ;
         END ;
     END

{
     -   Subtracts 2 2s complement words
     <n> <m> -
     <n-m>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

     ELSE IF (InWordStr='-') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             M := PopI ;              { <- variable used to guarentee execution order! }
             PushI(PopI-M) ;
         END ;
     END
{
     Get Address of Dictionary Entry Executable Code
}

     ELSE IF (InWordStr='''') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             IF (NOT GetNextWord(' ',InWordStr)) THEN BEGIN
                 CompileError('Token expected.') ;
             END ;
             nVal := GetDictAddr(InWordStr) ;
             IF (nVal=$0000) THEN BEGIN
                 CompileError('The token ' + InWordStr + ' is unknown.') ;
             END ;
             Inc(nVal,6) ;
             IF (CompileFlag) THEN BEGIN
                 WriteLiteral(nVal) ;
             END
             ELSE BEGIN
                 PushW(nVal) ;
             END ;
         END ;
     END
{
     String Literal
}

     ELSE IF (InWordStr='"') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             IF (NOT GetNextWord('"',sLiteral)) THEN BEGIN
                 CompileError('Incomplete String Literal.') ;
             END ;
         END ;
     END

{
     Store String Literal
}

     ELSE IF (InWordStr='!T') THEN BEGIN
         IF (NOT Test) THEN BEGIN
             nAddr := PopW ;
             FOR M := 1 TO Length(sLiteral)-2 DO BEGIN
                 PokeB(nAddr,BYTE(sLiteral[M])) ;
                 Inc(nAddr) ;
             END ;
             sLiteral := '' ;
         END ;
     END

{
     Echo String Literal
}

     ELSE IF (InWordStr='ECHO') THEN BEGIN
         IF (NOT Test) AND (sLiteral<>'') THEN BEGIN
             WriteLn(Left(sLiteral,Length(sLiteral)-2)) ;
             sLiteral := '' ;
         END ;
     END

{
     Set None Found Flag
}

     ELSE BEGIN
         NoneFound := TRUE ;
     END ;

     ReservedWord := NOT NoneFound ;

END { ReservedWord } ;

PROCEDURE DumpList(DPtr:DictionaryEntryPtr;Full:BOOLEAN) ;
VAR
     LL,AA,OP : WORD ;
     ss : STRING ;
     OpType : WORD ;

BEGIN

     IF (DPtr<>NIL) THEN BEGIN

         WHILE (DPtr^.NextEntry<>NIL) DO BEGIN
             DPtr := DPtr^.NextEntry ;
         END ;

         REPEAT

              IF (DPtr^.LastEntry=NIL) THEN BEGIN
                  LL := _H-1 ;
              END
              ELSE BEGIN
                  LL := DPtr^.LastEntry^.DictAddr-1 ;
              END ;

              IF (Full) THEN BEGIN
                  WriteLn(LogFile) ;
              END ;

              AA := DPtr^.DictAddr+6 ;
              OPType := PeekW(AA) ;

              WriteLn(LogFile, '#' + HexStr(AA) + '  #'+HexStr(OPType)+'  [' + DPtr^.Identifier+']') ;
              AA := AA + 2 ;

              IF (Full) THEN BEGIN

                  WHILE (AA<=LL) DO BEGIN

                      OP := PeekW(AA) ;
                      ss := GetDictIdentifier(OP) ;

                      IF (OpType=GetCCODE(I_DEFEX)) THEN BEGIN

                          IF (ss='1bliteral') THEN BEGIN
                              WriteLn(LogFile,'#'+HexStr(AA)+'  '+ss) ;
                              AA := AA + 2 ;
                              WriteLn(LogFile,'#'+HexStr(AA)+'  #'+HexStrB(PeekB(AA))) ;
                              AA := AA + 1 ;
                          END
                          ELSE IF (ss='2bliteral') OR
                                  (ss='jump') OR
                                  (ss='bronz') OR
                                  (ss='loopex') OR
                                  (ss='+loopex') OR
                                  (ss='$jeex')

                                   THEN BEGIN
                              WriteLn(LogFile,'#'+HexStr(AA)+'  '+ss) ;
                              AA := AA + 2 ;
                              WriteLn(LogFile,'#'+HexStr(AA)+'  #'+HexStr(PeekW(AA))) ;
                              AA := AA + 2 ;
                          END
                          ELSE IF (ss='') THEN BEGIN
                              WriteLn(LogFile,'#'+HexStr(AA)+'  #'+HexStr(OP)) ;
                              AA := AA + 2 ;
                          END
                          ELSE BEGIN
                              WriteLn(LogFile,'#'+HexStr(AA)+'  '+ss) ;
                              AA := AA + 2 ;
                          END ;
                      END
                      ELSE BEGIN
                          WriteLn(LogFile,'#'+HexStr(AA)+'  #'+HexStrB(OP)) ;
                          AA := AA + 1 ;
                      END ;
                 END ;

             END ;

             DPtr := DPtr^.LastEntry ;

         UNTIL (DPtr=NIL) ;

     END ;

END { DumpList } ;

{
     MAIN
}

BEGIN

{
     Link Exit Procedure
}

     ExitSave := ExitProc ;
     ExitProc := @MyExit ;

{
     Display Splash
}

     WriteLn('IPSXASM: IPS-X Cross Compiler Assembler Version 1.0.2') ;
     WriteLn('(c) 2001 Paul Willmott, VP9MU') ;
     WriteLn ;

{
     Open Source File
}
     BaseName := ParamStr(1) ;
     Assign(SourceFile,BaseName) ;
     Reset(SourceFile) ;

     kk := Pos('.',BaseName) ;

     IF (kk>0) THEN BEGIN
         BaseName := Left(BaseName,kk-1) ;
     END ;

     IF (BaseName='') THEN BEGIN
         CompileError('Usage: IPSXASM <filename>') ;
     END ;

     WriteLn('Assembling: '+BaseName+'...') ;

{
     Initialise Workspace
}

     StackPtr := MaxStackSize-1 ;

     FillChar(MemImage,SizeOf(MemImage),$00) ;

     InComment := FALSE ;
     InString := FALSE ;
     ASMFlag := FALSE ;
     _H := $0000 ;
     _KK := $0000 ;
     Dictionary := NIL ;
     MacroList := NIL ;
     MacroStack := NIL ;
     sLiteral := '' ;
     EchoFlag := FALSE ;

{
     Process Source File
}

     WHILE (Not Eof(SourceFile)) DO BEGIN

{
     Get Next Word, handling comments as necessary
}

         IF (GetNextWord(' ',InWordStr)) THEN BEGIN

{
     Check for Macro Substitutions
}

             IF (NOT MacroWord(InWordStr,FALSE)) THEN BEGIN

{
     Check for IPSXASM Reserved Words
}

                 IF (NOT ReservedWord(InWordStr,FALSE)) THEN BEGIN

{
     Check for Numbers
}

                     IF (NOT NumericValue(InWordStr,FALSE)) THEN BEGIN

{
     Check for Previously Defined Words
}

                         IF (NOT DefinedWord(InWordStr,FALSE)) THEN BEGIN


{
     Flag Error & Quit
}
                            IF (Trim(InWordStr)<>'') THEN BEGIN
                                CompileError('Unknown definition ['+Trim(InWordStr)+']') ;
                            END ;

                         END ;

                     END ;

                 END ;

             END ;

         END ;

     END ;

     IF (StackPtr<>MaxStackSize-1) THEN BEGIN
         CompileError('Items Left on Stack.') ;
     END ;

{
     Close Source File
}

     Close(SourceFile) ;

{
     Check if Assembly Completed, and write Image if so!
}

     Assign(OutFile,BaseName+'.BIN') ;
     ReWrite(OutFile) ;

     Assign(LogFile,BaseName+'.LOG') ;
     ReWrite(LogFile) ;

     Writeln('Writing: '+BaseName+'.BIN ...') ;

     Writeln('Writing: '+BaseName+'.LOG ...') ;

     FOR _KK := $0000 TO _H DO BEGIN
         kk :=PeekB(_KK) ;
         Write(OutFile,kk) ;
         IF (_KK MOD 16 = 0) THEN BEGIN
              WriteLn(LogFile) ;
              Write(LogFile,'#' + HexStr(_KK)+': ' ) ;
         END ;
         Write(LogFile,'#'+HexStrB(PeekB(_KK))+' ') ;
     END ;
     WriteLn(LogFile) ;
     DumpList(Dictionary,FALSE) ;
     WriteLn(LogFile) ;
     DumpList(Dictionary,TRUE) ;
     Close(OutFile) ;
     Close(LogFile) ;

     Write('Assembly Complete... press <Enter> to Finish.') ;
     ReadLn ;

END. { IPSXASM }