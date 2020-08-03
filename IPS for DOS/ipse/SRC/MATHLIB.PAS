{
    This UNIT implements various math support routines.

    (c) 2001 Paul Willmott, VP9MU

    Version 1.0.0 - June  3, 2001
    Version 1.0.1 - June 10, 2001 - WMin, WMax added
    Version 1.0.2 - June 10, 2001 - CORDIC routines added
    Version 1.0.3 - June 14, 2001 - Subtract32 added
    Version 1.0.4 - June 23, 2001 - Sgn, Atn2 added
    Version 1.0.5 - September 14, 2001 - CORDIC commented out
}

UNIT MathLib ;

{
    Public Interface
}

INTERFACE

CONST

     MaxCORDICIterations = 31 ; { Well overkill!, ... only 16 needed }
     CORDIC_K = 0.607252935008881 ;
     IPS_K    = 1.6468 ;

FUNCTION  AMSAT_CRCC(CRCC:WORD;OutChar:BYTE):WORD ;
PROCEDURE Add32(N:LONGINT;M:LONGINT;VAR R:LONGINT) ;
PROCEDURE Subtract32(M:LONGINT;N:LONGINT;VAR R:LONGINT) ;
PROCEDURE Mult16(N:WORD;M:WORD;VAR R:LONGINT) ;
FUNCTION  GE32(A:LONGINT;B:LONGINT):BOOLEAN ;
PROCEDURE Div32(N:LONGINT;M:LONGINT;VAR Q:LONGINT;VAR R:LONGINT) ;
FUNCTION  WMin(A,B:WORD):WORD ;
FUNCTION  WMax(A,B:WORD):WORD ;
(*
PROCEDURE TR_LOOP(VAR _A,_X,_Y:INTEGER) ;
PROCEDURE RP_LOOP(VAR _A,_X,_Y:INTEGER) ;
*)
FUNCTION  Atn2(Y,X:DOUBLE):DOUBLE ;

{
     Hidden Implementation
}

IMPLEMENTATION

CONST

     RA2C = 65536.0 / (2.0 * PI) ;

VAR

     CORDICLookup : ARRAY[0..MaxCORDICIterations] OF DOUBLE ;
     CORDICIndex  : LONGINT ;

{
     **************************************
     32-Bit Arithmetic / Logical Operations
     **************************************

     Add32 - Adds 2 unsigned 32 bit d-words (N & M) to
     form Unsigned 32 bit result (R).
}

PROCEDURE Add32(N:LONGINT;M:LONGINT;VAR R:LONGINT) ;
VAR
     _N : ARRAY[0..3] OF BYTE ABSOLUTE N ;
     _M : ARRAY[0..3] OF BYTE ABSOLUTE M ;
     _R : ARRAY[0..3] OF BYTE ABSOLUTE R ;
     A  : BYTE ;
     B  : WORD ;
     C  : WORD ; { Carry }
BEGIN
     R := 0 ;
     C := 0 ;
     FOR A := 0 TO 3 DO BEGIN
         B := _N[A] + _M[A] + C ;
         _R[A] := B AND $FF ;
         C := B SHR 8 ;
     END ;
END { Add32 } ;

{
     Subtract32 - Subtracts 2 unsigned 32 bit d-words (N & M) to
     form Unsigned 32 bit result (R=M-N).
}

PROCEDURE Subtract32(M:LONGINT;N:LONGINT;VAR R:LONGINT) ;
VAR
     _N : ARRAY[0..3] OF BYTE ABSOLUTE N ;
     _M : ARRAY[0..3] OF BYTE ABSOLUTE M ;
     _R : ARRAY[0..3] OF BYTE ABSOLUTE R ;
     A  : BYTE ;
     B  : WORD ;
     D  : WORD ;
     C  : WORD ; { Borrow }
BEGIN
     R := 0 ;
     C := 0 ;
     FOR A := 0 TO 3 DO BEGIN
         D := _N[A] + C ;
         B := _M[A] ;
         IF (B<D) THEN BEGIN
             Inc(B,$100) ;
             C := 1 ;
         END
         ELSE BEGIN
             C := 0 ;
         END ;
         B := B - D ;
         _R[A] := B AND $FF ;
     END ;
END { Subtract32 } ;

{
     Unsigned Multiply of 16 bit words N & M to form 32-bit unsigned result R
}

PROCEDURE Mult16 ;
VAR
     _N : ARRAY[0..1] OF BYTE ABSOLUTE N ;
     _M : ARRAY[0..1] OF BYTE ABSOLUTE M ;
     _R : ARRAY[0..3] OF BYTE ABSOLUTE R ;
     A  : BYTE ;
     B  : BYTE ;
     C  : WORD ;
     D  : LONGINT ;
     _D : ARRAY[0..3] OF BYTE ABSOLUTE D ;
BEGIN
     R := 0 ;
     FOR A := 0 TO 1 DO BEGIN
         FOR B := 0 TO 1 DO BEGIN
             D := 0 ;
             C := 0 ;
             C := $FFFF AND (_N[A] * _M[B]) ;
             _D[A+B] := C AND $FF ;
             _D[A+B+1] := C SHR 8 ;
             Add32(R,D,R) ;
         END ;
     END ;
END { Mult16 } ;

{
     32-bit compare - Greater or Equal, ... True if B<=A
}

FUNCTION GE32 ;
VAR
     _A : ARRAY[0..3] OF BYTE ABSOLUTE A ;
     _B : ARRAY[0..3] OF BYTE ABSOLUTE B ;
     Index : BYTE ;
BEGIN
     FOR Index := 3 DOWNTO 0 DO BEGIN
         IF (_B[Index]>_A[Index]) THEN BEGIN
             GE32 := FALSE ;
             Exit ;
         END ;
     END ;
     GE32 := TRUE ;
END { GE32 } ;

{
     32-bit Divide N / M returning 32-bit Quotient (Q) and Remainder (R)
}

PROCEDURE Div32 ;
BEGIN
     Q := N ;
     R := 0 ;
     FOR N := 1 TO 32 DO BEGIN
         Add32(R SHL 1,Q SHR 31,R) ;
         Q := Q SHL 1 ;
         IF (GE32(R,M)) THEN BEGIN
             Subtract32(R,M,R) ; { R = R - M }
             Add32(Q,1,Q) ;
         END ;
     END ;
END { Div32 } ;

{
    Reference: Page 35. AMSAT-UK OSCAR 13 Operations And Technical Handbook
    Note: CRCC Seed is #FFFF
}

FUNCTION AMSAT_CRCC ;
VAR
     NN    : BYTE ;
     Ch    : WORD ;
     Test  : WORD ;
BEGIN
     Ch := OutChar SHL 8 ;
     FOR NN := 0 TO 7 DO BEGIN
         Test := (Ch XOR CRCC) AND $8000 ;
         CRCC := CRCC SHL 1 ;
         Ch := Ch SHL 1 ;
         IF (Test<>0) THEN BEGIN
             CRCC := CRCC XOR $1021 ;
         END ;
     END ;
     AMSAT_CRCC := CRCC ;
END { AMSAT_CRCC } ;

{
     This function returns the greater of the words A and B
}

FUNCTION WMax ;
BEGIN
     IF (B<A) THEN BEGIN
         WMax := A ;
     END
     ELSE BEGIN
         WMax := B ;
     END ;
END { WMax } ;

{
     This function returns the lesser of the words A and B
}

FUNCTION WMin ;
BEGIN
     IF (B>A) THEN BEGIN
         WMin := A ;
     END
     ELSE BEGIN
         WMin := B ;
     END ;
END { WMax } ;

(*

ABANDONED IN PLACE - NO LONGER USED

{
     ********************************************
     CORDIC (COrdinate Rotation DIgital Computer)
     ********************************************

     CORDIC is a method for computing elementary functions using
     minimal hardware such as shift and add. It is typically
     used when these functions need to be implemented directly
     in hardware. In fact, a CORDIC was actually a piece of
     hardware developed for doing real-time high precision
     navigational computations in the 1950's. Remember, this was
     before you could actually put a general purpose digital
     computer in an airplane. Almost all scientific calculators
     have used the CORDIC techniques since then.

     CORDIC works by rotating the coordinate system through
     constant angles until the angle is reduced to zero. The
     angle offsets are selected such that the operations on X and
     Y are only shifts and adds.
}

PROCEDURE TR_LOOP(VAR _A,_X,_Y:INTEGER) ;

VAR

     i : LONGINT ;

     A,X,Y,da,dx,dy : DOUBLE  ;

     ang : DOUBLE  ;

BEGIN

     A := _A ;
     X := _X * IPS_K ;
     Y := _Y * IPS_K ;

     FOR i := 0 TO MaxCORDICIterations DO BEGIN
         da := CORDICLookup[i] ;
         dx := X / (1 SHL i) ;
         dy := Y / (1 SHL i) ;
         IF (A>=0) THEN BEGIN
             A := A - da ;
             X := X - dy ;
             Y := Y + dx ;
         END
         ELSE BEGIN
             A := A + da ;
             X := X + dy ;
             Y := Y - dx ;
         END ;
     END ;

     _A  := Trunc(A + 0.5) ;
     _X  := Trunc(X * CORDIC_K + 0.5) ;
     _Y  := Trunc(Y * CORDIC_K + 0.5) ;

END { TR_LOOP } ;

PROCEDURE RP_LOOP(VAR _A,_X,_Y:INTEGER) ;

VAR

     i : LONGINT ;

     A,X,Y,da,dx,dy : DOUBLE  ;

     ang : DOUBLE  ;

BEGIN

     A := _A ;
     X := _X * IPS_K ;
     Y := _Y * IPS_K ;

     FOR i := 0 TO MaxCORDICIterations DO BEGIN
         da := CORDICLookup[i] ;
         dx := X / (1 SHL i) ;
         dy := Y / (1 SHL i) ;
         IF (Y<=0) THEN BEGIN
             A := A - da ;
             X := X - dy ;
             Y := Y + dx ;
         END
         ELSE BEGIN
             A := A + da ;
             X := X + dy ;
             Y := Y - dx ;
         END ;
     END ;

     _A  := Trunc(A + 0.5) ;
     _X  := Trunc(X * CORDIC_K + 0.5) ;
     _Y  := Trunc(Y * CORDIC_K + 0.5) ;

END { RP_LOOP } ;

*)

{
     This routine returns the sign of the given number.
}

FUNCTION Sgn(Value:DOUBLE):INTEGER ;
BEGIN
     IF (Value>=0.0) THEN BEGIN
         Sgn := +1 ;
     END
     ELSE BEGIN
         Sgn := -1 ;
     END ;
END { Sgn } ;

{
     Quadrant preserving ArcTan function.

     REFERENCE: PLAN-13 Satellite Position Calculation Program
                James R. Miller, G3RUH 1993
}

FUNCTION Atn2(Y,X:DOUBLE):DOUBLE ;
VAR
     A : DOUBLE ;
BEGIN
     IF (X=0.0) THEN BEGIN
         Atn2 := Pi / 2.0 * Sgn(Y) ;
     END
     ELSE BEGIN
         A := ArcTan(Y/X) ;
         IF (X<0.0) THEN BEGIN
             A := A + PI ;
         END ;
         IF (A<0.0) THEN BEGIN
             Atn2 := A + 2.0 * PI ;
         END
         ELSE BEGIN
             Atn2 := A ;
         END ;
     END ;
END { Atn2 } ;

(*
{
     Initialization
}

BEGIN

{
     Build CORDIC Lookup Table
}

     FOR CORDICIndex := 0 TO MaxCORDICIterations DO BEGIN
         CORDICLookup[CORDICIndex] := RA2C * ArcTan(1.0 / (1 SHL CORDICIndex)) ;
     END ;
*)
END. { MathLib }

