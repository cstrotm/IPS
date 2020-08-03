{
    This UNIT implements miscellaneous string manipulation
    routines.

    (c) 2001 Paul Willmott, VP9MU

    Version 1.0.0 - June  3, 2001
    Version 1.0.1 - June 14, 2001 - DVal added
}

UNIT Strings ;

{
    Public Interface
}

INTERFACE

FUNCTION Upper(ss:STRING):STRING ;
FUNCTION Left(ss:STRING;Len:BYTE):STRING ;
FUNCTION Right(ss:STRING;Len:BYTE):STRING ;
FUNCTION TrimL(ss:STRING):STRING ;
FUNCTION TrimR(ss:STRING):STRING ;
FUNCTION Trim(ss:STRING):STRING ;
PROCEDURE DecodeConfig(sLine:STRING;VAR sToken:String;VAR sValue:STRING) ;
FUNCTION WVal(sValue:STRING):WORD ;
FUNCTION BVal(sValue:STRING):BYTE ;
FUNCTION DVal(sValue:STRING):DOUBLE ;
FUNCTION StoC(SValue:STRING):CHAR ;
FUNCTION Strng(cc:CHAR;Len:BYTE):STRING ;
FUNCTION WtoS(wValue:WORD):STRING ;
FUNCTION WtopS(wValue:WORD;Len:BYTE):STRING ;

{
     Hidden Implementation
}

IMPLEMENTATION

{
     NOTE: Turbo Pascal strings are a fixed length block of
           256 characters. They can be accessed as an array
           of character, e.g. ss[3] accesses the 3rd character
           of the string ss. The length of the string is stored 
           at ss[0], thus the largest string can only be 255
           characters long. There is no string termination 
           character as in "C", ... you use the string length 
           instead.
}

{
     Return parameter string forced to upper case.
}

FUNCTION Upper(ss:STRING):STRING ;
VAR
     Index : BYTE ;
BEGIN
     FOR Index := 1 TO Length(ss) DO BEGIN
         ss[Index] := UpCase(ss[Index]) ;
     END ;
     Upper := ss ;
END { Upper } ;

{
     Returns the left-most Len characters of the parameter
     string. If the parameter string length is less than
     Len, then it is returned unchanged.
}

FUNCTION Left ;
BEGIN
     IF (Length(ss)>Len) THEN BEGIN
         ss[0] := Chr(Len) ;
     END ;
     Left := ss ;
END { Left } ;

{
     Returns the right-most Len characters of the parameter
     string. If the parameter string length is less than
     Len, then it is returned unchanged.
}

FUNCTION Right ;
VAR
     LenAct : BYTE ;
BEGIN
     LenAct := Length(ss) ;
     IF (Len<LenAct) THEN BEGIN
         Delete(ss,1,LenAct-Len) ;
     END ;
     Right := ss ;     
END { Right } ;

{
     Returns the parameter string, with all spaces to the left
     of the first non-space character removed.
}

FUNCTION TrimL ;
BEGIN
     WHILE (Length(ss)>0) AND (ss[1]=' ') DO BEGIN
         Delete(ss,1,1) ;
     END ;
     TrimL := ss ;
END { TrimL } ;

{
     Returns the parameter string, with all spaces to the right
     of the last non-space character removed.
}

FUNCTION TrimR ;
VAR
     Len : BYTE ;
BEGIN
     Len := Length(ss) ;
     WHILE (Len>0) AND (ss[Len]=' ') DO BEGIN
         Delete(ss,Len,1) ;
         Len := Length(ss) ;
     END ;
     TrimR := ss ;
END { TrimL } ;

{
     Returns the parameter string, with all spaces to the left
     of the first non-space character, and all spaces from the
     right of the last non-space character removed.
}

FUNCTION Trim ;
BEGIN
     Trim := TrimR(TrimL(ss)) ;
END { Trim } ;

{
     Converts the parameter string to a WORD type, if the
     parameter string is prefixed with # then the number
     is treated as a Hex value. No error checking is done!
}

FUNCTION WVal(sValue:STRING):WORD ;
VAR
     _WVAL : WORD    ;
     Index : WORD    ;
     Digit : BYTE    ;
     Code  : INTEGER ;
BEGIN
     _WVAL := $0000 ;
     IF (sValue[1]='#') THEN BEGIN
         Index := 2 ; { Skip # }
         WHILE (Index<=Length(sValue)) DO BEGIN
             _WVAL := _WVAL SHL 8 ;
             Digit := Ord(sValue[Index]) ;
             IF (sValue[Index] IN ['0'..'9']) THEN BEGIN
                 _WVAL := _WVAL + Digit - Ord('0') ;
             END
             ELSE IF (sValue[Index] IN ['A'..'F']) THEN BEGIN
                 _WVAL := _WVAL + Digit - Ord('A') ;
             END ;
             Dec(Index) ;
         END ;
     END
     ELSE BEGIN
         Val(sValue,_WVAL,Code) ;
     END ;
     WVal := _WVAL ;
END { WVal } ;

{
     Converts the parameter string to a BYTE type, if the
     parameter string is prefixed with # then the number
     is treated as a Hex value. No error checking is done!
}

FUNCTION BVal(sValue:STRING):BYTE ;
BEGIN
     BVal := Lo(WVal(sValue)) ;
END { BVal } ;

{
     Converts the parameter string to a DOUBLE type.
     No error checking is done!
}

FUNCTION DVal(sValue:STRING):DOUBLE ;
VAR
     _DVAL : DOUBLE  ;
     Code  : INTEGER ;
BEGIN
     Val(sValue,_DVAL,Code) ;
     DVal := _DVAL ;
END { DVal } ;


{
     This routine is used to split a line of the form:

     TOKEN STRING = VALUE STRING ' THIS IS A COMMENT

     into its component parts: sToken, and sValue

     Another including and after the ' character is considered
     to be a comment as is deleted.

     Double spaces are removed and the returned values are 
     trimmed and changed to upper case.

     Used for reading configuration files!
}

PROCEDURE DecodeConfig(sLine:STRING;VAR sToken:String;VAR sValue:STRING) ;
VAR
     Index : WORD ;
BEGIN

{
     Strip Comments !
}

     Index := Pos('''',sLine) ;
     WHILE (Index<>0) DO BEGIN
         sLine := Left(sLine,Pred(Index)) ;
         Index := Pos('''',sLine) ;
     END ;

{
     Single Space
}

     sLine := Trim(sLine) + ' ' ;
     Index := Pos('  ',sLine) ;
     WHILE (Index<>0) DO BEGIN
         Delete(sLine,Index,1) ;
         Index := Pos('  ',sLine) ;
     END ;

{
     Clear Outputs
}

     sToken := '' ;
     sValue := '' ;

{
     Split into components biased on =, and force to upper case!
}

     Index := Pos('=',sLine) ;

     IF (Index<>0) THEN BEGIN
         sToken := Upper(Trim(Left (sLine,Pred(Index)))) ;
         Delete(sLine,1,Index) ;
         sValue := Upper(Trim(sLine)) ;
     END
     ELSE BEGIN
         sToken := Upper(Trim(sLine)) ;
     END ;

END { DecodeConfig } ;

{
     This routine converts the first character of a string
     to the data type CHAR.
}

FUNCTION StoC ;
BEGIN
     StoC := sValue[1] ;
END { StoC } ;

{
     This routine returns a string of the character cc of length Len.
}

FUNCTION Strng ;
VAR
     ss : STRING ;
BEGIN
     Fillchar(ss,SizeOf(ss),cc) ;
     ss[0] := CHAR(Len) ;
     Strng := ss ;
END { Strng } ;

{
     This routine converts an unsigned number to a string
}

FUNCTION WtoS ;
VAR
     ss : STRING ;
BEGIN
     Str(wValue:5,ss) ;
     WtoS := Trim(ss) ;
END { WtoS } ;

{
     This routine converts an unsigned number to a string, padded with
     leading zeroes to length Len
}

FUNCTION WtopS ;
BEGIN
     WtopS := Right(Strng('0',Len)+WtoS(WValue),Len) ;
END { WtopS } ;

END. { Strings }

