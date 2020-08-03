{
    This UNIT implements IPS-Mp Kernal Low Level Primatives

    (c) 2001 Paul Willmott, VP9MU

    Version 1.0.0 - June       3, 2001
    Version 1.0.1 - June      10, 2001 - MSDOS File Handling added
    Version 1.0.2 - June      11, 2001 - code_tr_loop, code_rp_loop, code_3v3 added
    Version 1.0.3 - June      14, 2001 - P+ P- added
                                       - UTCOffset support added
    Version 1.0.4 - June      23, 2001 - Tidyup
    Version 1.0.5 - August    25, 2001 - AUXWRITE & AUXREAD added
    Version 1.0.6 - August    28, 2001 - AUXCLRBUF added
    Version 1.0.7 - September  8, 2001 - $SCODE and $CSCAN added
                                       - CORDIC replaced by Real calculations
    Version 1.0.8 - September 14, 2001 - UHR-LOCK & SLEEP-TIME stubs added
                                       - User Functions #80 and #81 renumbered
    Version 1.0.9 - November  17, 2001 - cflag in CSCAN made static
    Version 1.0.10 - November 17, 2001 - keyboard macros added
}

UNIT Kernal ;

{
    Public Interface
}

INTERFACE

USES

    DOS      ,
    TypeDefs ,
    AuxIO    ,
    FileIO   ,
    Config   ,
    Engine   ,
    MathLib  ;

VAR

{
     Emulator Workspace
}

     PPC          : WORD         ; { Pseudo-PC (Program Counter)                          }
     HP           : WORD         ; { Header Pointer                                       }
     CPC          : WORD         ; { Code Program Counter - PC address in a real system ! }
     LOADPOINTER  : WORD         ; { Pointer to Next Address to Place File Input          }
     INPUTPOINTER : WORD         ; { Pointer to Next Address to Place Keyboard Input      }
     TextFile     : FILE OF CHAR ; { File handle for READ Disk Operations                 }
     IsOpen       : BOOLEAN      ; { True iff READ file is open                           }

TYPE

     KeyboardMacroPtr = ^KeyboardMacro ;

     KeyboardMacro = RECORD
                           ScanCode  : BYTE             ;
                           Macro     : STRING           ;
                           NextMacro : KeyboardMacroPtr ;
                     END ;

VAR

    KeyboardMacros : KeyboardMacroPtr ;

{
     The JumpTable is an array of IPS primative procedures. Space is
     allocated for 256 primatives, though not all are used. The unused
     ones are initialized to a dummy procedure by ReloadKernal.
}

     JumpTable : ARRAY[$00..$ff] OF PROCEDURE ;

{
     IPS Type Codes
     --------------
}

CONST

     ips_return = $0        ; { RUMPELSTILZCHEN    }
     ips_defex = $1         ; { DEFEX              }
     ips_consex = $2        ; { CONSEX             }
     ips_varex = $3         ; { VAREX              }
     ips_retex = $4         ; { RETEX              }
     ips_get = $5           ; { @                  }
     ips_getB = $6          ; { @B                 }
     ips_put = $7           ; { !                  }
     ips_putB = $8          ; { !B                 }
     ips_blit_1 = $9        ; { 1BLITERAL          }
     ips_blit_2 = $A        ; { 2BLITERAL          }
     ips_bronz = $B         ; { BRONZ              }
     ips_jump = $C          ; { JUMP               }
     ips_weg = $D           ; { WEG                }
     ips_pweg = $E          ; { PWEG               }
     ips_plus = $F          ; { +                  }
     ips_minus = $10        ; { -                  }
     ips_dup = $11          ; { DUP                }
     ips_pdup = $12         ; { PDUP               }
     ips_vert = $13         ; { VERT               }
     ips_zwo = $14          ; { ZWO                }
     ips_rdu = $15          ; { RDU                }
     ips_rdo = $16          ; { RDO                }
     ips_index = $17        ; { I                  }
     ips_s_to_r = $18       ; { S>R                }
     ips_r_to_s = $19       ; { R>S                }
     ips_eqz = $1A          ; { =0                 }
     ips_gz = $1B           ; { >0                 }
     ips_lz = $1C           ; { <0                 }
     ips_geu = $1D          ; { >=U                }
     ips_f_vergl = $1E      ; { F-VERGL            }
     ips_nicht = $1F        ; { NICHT              }
     ips_und = $20          ; { UND                }
     ips_oder = $21         ; { ODER               }
     ips_exo = $22          ; { EXO                }
     ips_bit = $23          ; { BIT                }
     ips_cbit = $24         ; { CBIT               }
     ips_sbit = $25         ; { SBIT               }
     ips_tbit = $26         ; { TBIT               }
     ips_jeex = $27         ; { $JEEX              }
     ips_loopex = $28       ; { LOOPEX             }
     ips_plusloopex = $29   ; { +LOOPEX            }
     ips_field_trans = $2A  ; { >>>                }
     ips_pmul = $2B         ; { P*                 }
     ips_pdiv = $2C         ; { P/MOD              }
     ips_tue = $2D          ; { $TUE               }
     ips__polyname = $2E    ; { $POLYNAME          }
     ips__scode = $2F       ; { $SCODE             }
     ips__cscan = $30       ; { $CSCAN             }
     ips_chs = $31          ; { CHS                }
     ips_cyc2 = $32         ; { CYC2               }
     ips_close = $33        ; { $CLOSEFILE         }
     ips_open = $34         ; { $OPENFILE          }
     ips_oscli = $35        ; { $OSCLICODE         }
     ips_load = $36         ; { $LOADCODE          }
     ips_save = $37         ; { $SAVECODE          }
     ips_setkbptr = $38     ; { $IPSETZEN          }
     ips_getPS = $39        ; { $PSHOLEN           }
     ips_setPS = $3A        ; { $PSSETZEN          }
     ips_rp_code = $3B      ; { RP-LOOP            }
     ips_tr_code = $3C      ; { TR-LOOP            }
     ips_swap3 = $3D        ; { 3V3                }
     ips_defchar = $3E      ; { $DEFCHARCODE       }
     ips_pplus = $3F        ; { P+                 }
     ips_pminus = $40       ; { P-                 }

{
     User Functions - Used here for IPSDOS specifics
}

     ips__funct_00 = $80    ; { UHR-LOCK              }
     ips__funct_01 = $81    ; { SLEEP-TIME            }
     ips__funct_02 = $82    ; { Read I/O Port Word    }
     ips__funct_03 = $83    ; { Write I/O Port Word   }
     ips__funct_04 = $84    ; { Read DOS Memory Byte  }
     ips__funct_05 = $85    ; { Read DOS Memory Word  }
     ips__funct_06 = $86    ; { Write DOS Memory Byte }
     ips__funct_07 = $87    ; { Write DOS Memory Word }
     ips__funct_08 = $88    ; { AUXOUTB               }
     ips__funct_09 = $89    ; { AUXINB                }
     ips__funct_0A = $8A    ; { AUXINCOUNT            }
     ips__funct_0B = $8B    ; { AUXOUTCOUNT           }
     ips__funct_0C = $8C    ; { FOPEN                 }
     ips__funct_0D = $8D    ; { FCLOSE                }
     ips__funct_0E = $8E    ; { FREAD                 }
     ips__funct_0F = $8F    ; { FWRITE                }
     ips__funct_10 = $90    ; { FSEEK                 }
     ips__funct_11 = $91    ; { FGETB                 }
     ips__funct_12 = $92    ; { FPUTB                 }
     ips__funct_13 = $93    ; { FFLUSH                }
     ips__funct_14 = $94    ; { FDELETE               }
     ips__funct_15 = $95    ; { FRENAME               }
     ips__funct_16 = $96    ; { FEOF                  }
     ips__funct_17 = $97    ; { AUXREAD               }
     ips__funct_18 = $98    ; { AUXWRITE              }
     ips__funct_19 = $99    ; { AUXCLRBUF             }
     ips__funct_1a = $9A    ; { Read I/O Port Byte    }
     ips__funct_1b = $9B    ; { Write I/O Port Byte   }
     ips__funct_1c = $9c    ; { Define Keyboard Macro }
     ips__funct_1d = $9d    ; {                       }
     ips__funct_1e = $9e    ; {                       }
     ips__funct_1f = $9f    ; {                       }

PROCEDURE ReloadKernal ;
PROCEDURE code_closefile ;

{
     Hidden Implementation
}

IMPLEMENTATION

{$F+}

VAR

     ExitSave    : POINTER ;

{
     **********
     Primitives
     **********

     ---------------------
     Arithmetic Primitives
     ---------------------

     +   Adds 2 2s complement words.
     <n> <m> +
     <n+m>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_plus ;
BEGIN
     PushI(PopI+PopI) ;
END { code_plus } ;

{
     -   Subtracts 2 2s complement words
     <n> <m> -
     <n-m>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_minus ;
VAR
     M : INTEGER ;
BEGIN
     M := PopI ;              { <- variable used to guarentee execution order! }
     PushI(PopI-M) ;
END { code_minus } ;

{
     P+  Adds 2 32-bit 2s complement words.
     <n-LSB> <n-MSB> <m-LSB> <m-MSB> P+
     <n+m LSB> <n+m MSB>

     REFERENCE: One liner from James!
}

PROCEDURE code_pplus ;
VAR
     N, M, R : LONGINT ;
BEGIN
     DWordRecType(M).Hi := PopW ;
     DWordRecType(M).Lo := PopW ;
     DWordRecType(N).Hi := PopW ;
     DWordRecType(N).Lo := PopW ;
     Add32(M,N,R) ;
     PushW(DWordRecType(R).Lo) ;
     PushW(DWordRecType(R).Hi) ;
END { code_pplus } ;

{
     P-  Subtracts 2 32-bit 2s complement words.
     <n-LSB> <n-MSB> <m-LSB> <m-MSB> P-
     <n-m LSB> <n-m MSB>

     REFERENCE: One liner from James!
}

PROCEDURE code_pminus ;
VAR
     N, M, R : LONGINT ;
BEGIN
     DWordRecType(M).Hi := PopW ;
     DWordRecType(M).Lo := PopW ;
     DWordRecType(N).Hi := PopW ;
     DWordRecType(N).Lo := PopW ;
     Subtract32(N,M,R) ;
     PushW(DWordRecType(R).Lo) ;
     PushW(DWordRecType(R).Hi) ;
END { code_pminus } ;

{
     CHS     changes the sign of the item on the stack
     <n> CHS
     <-n>

     REFERENCE: IPS-M for Acorn Risc Computers, James Miller, G3RUH, 1997 Jul 18
}

PROCEDURE code_chs ;
BEGIN
     PushI(-PopI) ;
END { code_chs } ;

{
     P*      Multiplies 2 16 bit positive words, result is their 32 bit product
     <n> <m> P*
     <n * m, least sig. 16 bits>, <n * m, most sig. 16 bits>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_pmul ;
VAR
     R : LONGINT ;
BEGIN
     Mult16(PopW,PopW,R) ; { <- 16bit by 16bit Multiply 32bit Result }
     PushW(DWordRecType(R).Lo) ;
     PushW(DWordRecType(R).Hi) ;
END { code_pmul } ;

{
     P/MOD   Divides a 32 bit positive word by a 16 bit positive word,
             produces 16 bit quotient and 16 bit remainder.
             IF the quotient overflows it is set to #FFFF.
     <n, least sig. 16 bits> <n, most sig. 16 bits> <m> P/MOD
     <quotient n/m> <remainder n/m>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_pdiv ;
VAR
     N : DOUBLE ;
     M : DOUBLE ;
     Q : DOUBLE ;
     R : DOUBLE ;
BEGIN
     M := PopW ;
     N := PopW * 65536.0 ;
     N := N + PopW ;
     IF (M=0) THEN BEGIN
         Q := $FFFF ;
         R := $0000 ;
     END
     ELSE BEGIN
         Q := Trunc(N / M) ;
         IF ($FFFF<Q) THEN BEGIN
             Q := $FFFF ;
             R := $0000 ;
         END
         ELSE BEGIN
             R := Trunc(N - Q * M) ;
         END ;
     END ;
     PushW(Trunc(Q) AND $FFFF) ;
     PushW(Trunc(R) AND $FFFF) ;
END { code_pdiv } ;

{
     ------------------
     Logical Primitives
     ------------------

     NICHT   Inverts all bits
     <bbbbbbbbbbbbbbbb> NICHT
     <b*b*b*b*b*b*b*b*b*b*b*b*b*b*b*b*>
     (b* = complement of b)

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_nicht ;
BEGIN
     PokeW(PSP, Not PeekW(PSP)) ;
END { code_nicht } ;

{
     UND     Logically ANDs all bits.
     <n> <m> UND
     <n AND m, bitwise>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_und ;
VAR
     M : WORD ;
BEGIN
     M := PopW ;
     PokeW(PSP,M AND PeekW(PSP)) ;
END { code_und } ;

{
     ODER    Logically ORs all bits
     <n> <m> ODER
     <n OR m, bitwise>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_oder ;
VAR
     M : WORD ;
BEGIN
     M := PopW ;
     PokeW(PSP, M OR PeekW(PSP)) ;
END { code_oder } ;

{
     EXO    Logically Exclusive-ORs all bits
     <n> <m> EXO
     <n exclusive-OR m, bitwise>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_exo ;
VAR
     M : WORD ;
BEGIN
     M := PopW ;
     PokeW(PSP, M XOR PeekW(PSP)) ;
END { code_exo } ;

{
     BIT     Set mask for bit of word specified. Mask is all zeroes
             with bit specified set to 1.
     <n> BIT
     <mask, only 1 bit set to 1>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_bit ;
BEGIN
     PushW(1 SHL PopW) ;
END { code_bit } ;

{
     CBIT    Clear bit of byte.
     <bit-no> <addr of byte> CBIT
     Bit specified set to 0, all other bits unaffected.

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_cbit ;
VAR
     MemAddr : WORD ;
BEGIN
     MemAddr := PopW ;         { <- variable to ensure execution order! }
     PokeB(MemAddr, PeekB(MemAddr) AND Lo(NOT (1 SHL PopW))) ;
END { code_cbit } ;

{
     SBIT    Set bit of byte.
     <bit-no> <addr of byte> SBIT
     Bit specIFied set to 1, all other bits unaffected.

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_sbit ;
VAR
     MemAddr : WORD ;
BEGIN
     MemAddr := PopW ;        { <- variable to ensure execution order! }
     PokeB(MemAddr, PeekB(MemAddr) OR Lo((1 SHL PopW))) ;
END { code_sbit } ;

{
     TBIT    Test bit of byte
     <bit-no> <addr of byte> TBIT
     <result>
     Result is 1 if bit specified is 1, 0 if bit specified is 0.

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_tbit ;
VAR
     MemAddr : WORD ;
BEGIN
     MemAddr := PopW ;        { <- variable to ensure execution order! }
     IF ( PeekB(MemAddr) AND Lo(1 SHL PopW) = 0 ) THEN BEGIN
        MemAddr := 0 ;
     END
     ELSE BEGIN
        MemAddr := 1 ;
     END ;
     PushW(MemAddr) ;
END { code_tbit } ;

{
     ---------------------------------------
     Parameter Stack Manipulation Primitives
     ---------------------------------------

     DUP     Duplicate stack.
     <n> DUP
     <n> <n>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_dup ;
BEGIN
     PushW(PeekW(PSP)) ;
END { code_dup } ;

{
     PDUP    Duplicates 2 stack entries.
     <n> <m> PDUP
     <n> <m> <n> <m>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_pdup ;
BEGIN
    PushW(PeekW(PSP+2)) ;
    PushW(PeekW(PSP+2)) ;
END { code_pdup } ;

{
     VERT    Swap top 2 entries
     <n> <m> VERT
     <m> <n>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_vert ;
VAR
     M : WORD ;
     N : WORD ;
BEGIN
     M := PopW ;
     N := PopW ;
     PushW(M) ;
     PushW(N) ;
END { code_vert } ;

{
     WEG     Destroy top entry
     <m> <n> WEG
     <m>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_weg ;
BEGIN
     Inc(PSP,2) ;
END { code_weg } ;

{
     PWEG    Destroy 2 entries
     <m> <n> PWEG
     empty

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_pweg ;
BEGIN
     Inc(PSP,4) ;
END { code_pweg } ;

{
     ZWO     Duplicate 2nd entry
     <n> <m> ZWO
     <n> <m> <n>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_zwo ;
BEGIN
     PushW(PeekW(PSP+2)) ;
END { code_zwo } ;

{
     RDU     Rotates 3 entries.
     <a> <b> <c> RDU
     <c> <a> <b>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_rdu ;
VAR
     A : WORD ;
     B : WORD ;
     C : WORD ;
BEGIN
     C := PopW ;
     B := PopW ;
     A := PopW ;
     PushW(C) ;
     PushW(A) ;
     PushW(B) ;
END { code_rdu } ;

{
     RDO     Rotates 3 entries.
     <a> <b> <c> RDO
     <b> <c> <a>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_rdo ;
VAR
     A : WORD ;
     B : WORD ;
     C : WORD ;
BEGIN
     C := PopW ;
     B := PopW ;
     A := PopW ;
     PushW(B) ;
     PushW(C) ;
     PushW(A) ;
END { code_rdo } ;

{
     ------------------------
     Fetch & Store Primitives
     ------------------------

     @   Get word
     <addr> @
     <contents of addr>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_get ;
BEGIN
     PokeW(PSP,PeekW(PeekW(PSP))) ;
END { code_get } ;

{
     @B  Get byte
     <addr> @B
     <byte at addr, MSB = 0>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_getb ;
BEGIN
     PokeW(PSP,PeekW(PeekW(PSP)) AND $ff) ;
END { code_getb } ;

{
     !   Store word
     <n> <addr> !
     empty. Word at addr now contains value n.

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_put ;
VAR
     MemAddr : WORD ;
BEGIN
     MemAddr := PopW ;
     PokeW(MemAddr, PopW) ;
END { code_put } ;

{
     !B  Store byte
     <n> <addr> !B
     empty. Byte at addr now contains LSB of n.
     Only 1 byte is affected.

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_putb ;
VAR
     MemAddr : WORD ;
BEGIN
     MemAddr := PopW ;
     PokeB(MemAddr,Lo(PopW)) ;
END { putb } ;

{
     -----------------------
     Return Stack Primitives
     -----------------------

     I       Copies top of return stack to parameter stack.
     I
     <top of return stack>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_index ;
BEGIN
     PushW(PeekW(RSP)) ;
END { code_index } ;

{
     S>R     Moves parameter stack to return stack.
     <n> S>R
     empty. <n> is now top of the return stack.

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_s_to_r ;
BEGIN
     PushRSW(PopW) ;
END { code_s_to_r } ;

{
     R>S     Moves one word from return stack to parameter stack.
     R>S <top of return stack>. Top is lost from return stack.

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_r_to_s ;
BEGIN
     PushW(PopRSW) ;
END { code_r_to_s } ;

{
     ---------------------
     Relational Primitives
     ---------------------

     =0      Tests for zero.
     <n> =0
     <TRUE IF n=0>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_eqz ;
BEGIN
     IF (PeekI(PSP)=0) THEN BEGIN
         PokeW(PSP,1) ;
     END
     ELSE BEGIN
         PokeW(PSP,0) ;
     END ;
END { code_eqz } ;

{
     >0      Tests for greater than zero.
     <n> >0
     <TRUE IF n>0>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_gz ;
BEGIN
     IF (PeekI(PSP)>0) THEN BEGIN
         PokeW(PSP,1) ;
     END
     ELSE BEGIN
         PokeW(PSP,0) ;
     END ;
END { code_gz } ;

{
     <0      Tests for less than zero.
     <n> <0
     <TRUE IF n<0>

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_lz ;
BEGIN
     IF (PeekI(PSP)<0) THEN BEGIN
         PokeW(PSP,1) ;
     END
     ELSE BEGIN
         PokeW(PSP,0) ;
     END ;
END { code_lz } ;

{
    >=U     Unsigned Test
    <n> <m> >=U
    <TRUE IF n>=m, as unsigned 16 bit numbers>

    REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_geu ;
VAR
     M : WORD ;
BEGIN
     M := PopW ;                { <- variable to ensure execution order! }
     IF (PeekW(PSP)>=M) THEN BEGIN
         PokeW(PSP,1) ;
     END
     ELSE BEGIN
         PokeW(PSP,0) ;
     END ;
END { code_geu } ;

{
     F-VERGL     Field Comparison
     <a> <b> <n> F-VERGL
     <result>

     This instruction compares n pairs of bytes starting at locations a and b.
     If equal, result is 1. If bytes in a are numerically greater than in b, result is 2,
     else 0. Higher addressed bytes are treated as more significant.

     REFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_f_vergl ;

VAR

     MemAddrA : WORD ;
     MemAddrB : WORD ;
     Result   : WORD ;
     B1       : BYTE ;
     B2       : BYTE ;
     Count    : WORD ;

BEGIN

     Count    := PopW ; { Number of Bytes }
     MemAddrB := PopW ;
     MemAddrA := PeekW(PSP) ;
     Result := 1 ;
     REPEAT
           B1 := PeekB(MemAddrA) ;
           Inc(MemAddrA) ;
           B2 := PeekB(MemAddrB) ;
           Inc(MemAddrB) ;
           IF (B1>B2) THEN Result := 2 ;
           IF (B1<B2) THEN Result := 0 ;
           Count := (Count - 1) AND $ff ;
     UNTIL (Count = 0) ;
     PokeW(PSP,Result) ;

END { code_f_vergl } ;

{
     -----------------------------------------------------------------------
     Trig Primatives

     Reference: IPS-M Trigonometry Extensions by James Miller, July 20, 1997
     -----------------------------------------------------------------------
}

{
     TR-LOOP is only called by the library function T-R. You are unlikely
     to use this routine directly.

     Entry: 4 items on the stack: theta, X, Y, 0
     Exit: 3 items on the stack: ~0, k*X', k*Y'
     where k=1.6468. Routine rotates the vector <X,Y> anti-clockwise
     through the angle theta. The angle theta must lie in the right
     hand hemisphere; that is, -90 <= theta <= +90. The handler T-R
     ensures this.

     Input: theta, X, Y, 0
     Output: 0, k*Cos(theta + atn2<X,Y>), k*Sin(theta + atn2<X,Y>)
}

PROCEDURE code_tr_code ;
VAR
     theta, X, Y : INTEGER ; { 2pi radians = 65536 for X,Y,theta }
     Yrad , Xrad, trad, F, R : DOUBLE ;
BEGIN

     Y := PopI ;
     Y := PopI ;
     X := PopI ;
     theta := PopI ;

     Yrad := Y / 10430.38 ; { convert to radians }
     Xrad := X / 10430.38 ;
     trad := theta / 10430.38 ;
     R := Sqrt(Yrad*Yrad + Xrad*Xrad) ;
     F := trad + Atn2(Yrad,Xrad) ;
     X := Trunc(IPS_K*R*Cos(F)*10430.38 + 0.5) ;
     Y := Trunc(IPS_K*R*Sin(F)*10430.38 + 0.5) ;

     PushI(0) ;
     PushI(X) ;
     PushI(Y) ;

END { code_tr_code } ;

{
     RP-LOOP is only called by the library function R>P. You are
     unlikely to use this routine directly.
     Entry: 4 items on the stack: theta0, X, Y, 0
     Exit: 3 items on the stack: (theta0+atn2<X,Y>), k*X', ~0
     where k=1.6468. Routine rotates the vector <X,Y> clockwise through
     an angle such as to drive Y' to zero. The initial vector must
     lie in the right hand hemisphere; that is , X must be positive.
     The handler R>P ensures this.

     Input: theta0, X, Y, 0
     Output: (theta0 + atn2<X,Y>), k*SQR(X*X+Y*Y), 0
}

PROCEDURE code_rp_code ;
VAR
     X, Y, theta0 : INTEGER ;
     Xrad, Yrad, trad, D, E : DOUBLE ;
BEGIN

     Y := PopI ; { Remove 0 }
     Y := PopI ;
     X := PopI ;
     theta0 := PopI ;
     Yrad := Y / 10430.38 ; { convert to radians }
     Xrad := X / 10430.38 ;
     trad := theta0 / 10430.38 ;

     D := trad + Atn2(Yrad,Xrad) ;
     E := IPS_K*Sqrt(Xrad*Xrad + Yrad*Yrad) ;
     X := Trunc(D*10430.38 + 0.5) ;
     Y := Trunc(E*10430.38 + 0.5) ;

     PushI(X) ;
     PushI(Y) ;
     PushI(0) ;

END { code_rp_code } ;

{
    swap3 (3V3) swaps two triples on the stack.

    That is, a b c d e f -> d e f a b c

    Reference: Private Communication, James Miller, May 10, 2001
}

PROCEDURE code_swap3 ;
VAR
     Index : WORD ;
     Swap  : WORD ;
BEGIN
     Index := PSP ;
     WHILE (Index<PSP+6) DO BEGIN
         Swap := PeekW(Index) ;
         PokeW(Index,PeekW(Index+6)) ;
         PokeW(Index+6,Swap) ;
         Inc(Index,2) ;
     END ;
END { code_swap3 } ;

{
     ------------------
     Control Primitives
     ------------------

     -----------------------------------------------------------------------------
     THE FOLLOWING CODE ROUTINES CAN ONLY BE COMPILED WITHIN THE PROPER ROUTINES;
     TRYING TO EXECUTE THEM FROM THE KEYBOARD MAY RESULT IN A SYSTEM CRASH.
     -----------------------------------------------------------------------------

     2BLITERAL   within programs pushes the number (2 bytes) following it on to
                 the stack. The pseudo-PC is incremented beyond these 2 bytes.

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Page 89 - 6.3 Code routines managed by the compiler
}

PROCEDURE code_blit_2 ;
BEGIN
     PushW(PeekW(PPC)) ;
     PPC := PPC + 2 ;
END { code_blit_2 } ;

{
     1BLITERAL   like 2BLITERAL, but pushes only 1 byte following it on the stack and
                 THEN increments the pseudo-PC beyond the byte.

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Page 89 - 6.3 Code routines managed by the compiler
}

PROCEDURE code_blit_1 ;
BEGIN
     PushW(PeekB(PPC)) ;
     PPC := PPC + 1 ;
END { code_blit_1 } ;

{
     BRONZ       branches on finding a 0 (even number) to the address following it
                 in the program. If it found an odd number, it increments the
                 pseudo-PC beyond the address.

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Page 89 - 6.3 Code routines managed by the compiler
}

PROCEDURE code_bronz ;
BEGIN
     IF ((PopW AND $1) = 0) THEN BEGIN
         PPC := PeekW(PPC) ;
     END
     ELSE BEGIN
         PPC := PPC + 2 ;
     END ;
END { code_bronz } ;

{
     LOOPEX      the action taken with the NUN of loops. The address to the loop
                 entry follows LOOPEX in the program. The NUN increments the iteration
                 counter and the checks whether it exceeds the loop limit. IF not, the
                 loop (between JE and NUN) repeats. Else, the NUN discards the two
                 parameters on the return stack and the loop is terminated. Inside the
                 loop the loop limit and the iteration counter are on the return stack;
                 the later on top. IF the initial value of the iteration counter exceeds
                 the limit, the loop action is not executed at all.

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Pages 18 to 19 - 3.1.2 Loops
                 Page 89 - 6.3 Code routines managed by the compiler

                 JE NUN  Iteration loop, with a test at end of loop, with unity increments.
                         The value of the loop index is available by the use of the word I.
                         NB: This construct uses the return stack.

                 <a> <b> JE
                 <iterated actions>
                 NUN

                 Index starts set to a and incremented by 1 until the index is
                 equal or greater than b.

     REFERENCE:  IPS Language Reference Manual Draft E 15 Feb 1996

     Private Communication from James R. Miller, April 25, 2001

     : LOOP JE I @ 2 +NUN ; compiles as (e.g.):

     ADDRESS DATA
     ---------------------------------------
     #1DA1 #5C04 ]
     #1DA3 #2389 5C 89 23 hash_name LOOP ] Header stuff
     #1DA5 #1D55 #1D55 (prev defn. start) ]

     #1DA7 #0F0D DEFEX ( entry)
     #1DA9 #0C47 $JEEX
     #1DAB #1DB5 ----------+
     #1DAD +-->#0CF6 I |
     #1DAF | #0B7C @ |
     #1DB1 | #0FEE 2 kon |
     #1DB3 | #0C2E +LOOPEX |
     #1DB5 +-- #1DAD <---------+
     #1DB7 #0BD0 RETEX

}

PROCEDURE code_loopex ;
VAR
     I   : LONGINT ; { Iteration Counter }
     L   : WORD    ; { Loop Limit }
BEGIN
     I := PopRSW ;
     I := I + 1 ;
     L := PeekW(RSP) ;
     IF (I<=L) THEN BEGIN
         PushRSW(DWordRecType(I).Lo) ;
         PPC := PeekW(PPC) ;
     END
     ELSE BEGIN
         L := PopRSW ;
         PPC := PPC + 2 ;
     END ;
END { code_loopex } ;

{
     +LOOPEX     like LOOPEX, but now the +NUN taking the increment off the stack.

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Pages 18 to 19 - 3.1.2 Loops
                 Page 89 - 6.3 Code routines managed by the compiler

                 JE +NUN Iteration loop, with a test at end of loop, and non
                         unity increments. The value of the loop index is available
                         by the use of the word I. NB: This construct uses the return
                         stack.

                 <a> <b> JE
                 <iterated actions>
                 <n> +NUN

                 Index starts set to a and takes an increment n off the stack each time
                 through the loop until the index is equal to or greater than b.

     REFERENCE:  IPS Language Reference Manual Draft E 15 Feb 1996

     Private Communication from James R. Miller, April 25, 2001
}

PROCEDURE code_plusloopex ;
VAR
     I   : LONGINT ;    { Iteration Counter }
     L   : WORD    ;    { Loop Limit }
BEGIN
     I := PopRSW ;
     I := I + PopW ;
     L := PeekW(RSP) ;
     IF (I<=L) THEN BEGIN
         PushRSW(DWordRecType(I).Lo) ;
         PPC := PeekW(PPC) ;
     END
     ELSE BEGIN
         L := PopRSW ;
         PPC := PPC + 2 ;
     END ;
END { code_plusloopex } ;

{
     $JEEX       The action going with the JE. The address of the corresponding LOOPEX
                 address follows $JEEX in the program to enable it to bypass the loop
                 in it is not to be executed at all.

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Pages 18 to 19 - 3.1.2 Loops
                 Page 89 - 6.3 Code routines managed by the compiler

                 JE NUN  Iteration loop, with a test at end of loop, with unity increments.
                         The value of the loop index is available by the use of the word I.
                         NB: This construct uses the return stack.

                 <a> <b> JE
                 <iterated actions>
                 NUN

                 Index starts set to a and incremented by 1 until the index is
                 equal or greater than b.

     REFERENCE:  IPS Language Reference Manual Draft E 15 Feb 1996

     Private Communication from James R. Miller, April 25, 2001
}

PROCEDURE code_jeex ;
VAR
     I : LONGINT ;    { Iteration Counter }
     L : WORD    ;    { Loop Limit }
BEGIN

     PPC := PeekW(PPC) ;
     PushRSW(PopW) ;
     I := PopW ;

     L := PeekW(RSP) ;
     IF (I<=L) THEN BEGIN
         PushRSW(DWordRecType(I).Lo) ;
         PPC := PeekW(PPC) ;
     END
     ELSE BEGIN
         L := PopRSW ;
         PPC := PPC + 2 ;
     END ;

END { code_jeex } ;

{
     JUMP        like BRONZ, but the jump is always taken and nothing is taken
                 off the stack. (Unconditional jump).

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Pages 18 to 19 - 3.1.2 Loops
                 Page 89 - 6.3 Code routines managed by the compiler
}

PROCEDURE code_jump ;
BEGIN
     PPC := PeekW(PPC) ;
END { code_jump } ;

{
     $TUE        expects a typecode field address on the stack. $TUE executes this
                 word and thus allows indirect execution.

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Page 88 - 6.2 Directly available code routines
}

PROCEDURE code_tue ;
BEGIN
     HP := PopW ;
     CPC := PeekW(HP) ;
     HP := HP + 2 ;
     JumpTable[Lo(CPC)] ;
END { code_tue } ;

{
     Dummy Procedure, ... No-Op!
}

PROCEDURE code_rumpelstilzchen ;
BEGIN
END { code_rumpelstilzchen };

{
     -----------------------------------------------------------------------------
     THE FOLLOWING WORDS MAY ALSO BE USED BY THE USER DIRECTLY. THEIR FUNCTION
     IS SOMEWHAT SPECIALIZED AND THEY ARE THUS NOT NECESSARILY VERY USEFUL OUTSIDE
     THE COMPILER. THEREFORE THEY ARE DEFINED AS PART OF THE IMPLEMENTATION RATHER
     THAN PART OF THE IPS LANGUAGE.
     -----------------------------------------------------------------------------

     RETEX       exits from a definition. It is compiled by the ; and using this word
                 directly allows multiple exits from a definition.

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Page 15 - 3.1 Definitions
                 Page 88 - 6.2 Directly available code routines
}

PROCEDURE code_retex ;
BEGIN
     PPC := PopRSW ;
END { code_retex } ;

{
     $PSHOLEN    gets the parameter stack pointer and pushes it on the parameter stack.

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Page 88 - 6.2 Directly available code routines
}

PROCEDURE code_getPS ;
BEGIN
     PushW(PSP) ;
END { code_getPS } ;

{
     $PSSETZEN   takes a number off the parameter stack and sets the stack pointer to this
                 number.

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Page 88 - 6.2 Directly available code routines
}

PROCEDURE code_setPS ;
BEGIN
     PSP := PopW ;
END { code_setPS } ;

PROCEDURE code_defex ;
BEGIN
     PushRSW(PPC) ;
     PPC := HP ;
END { code_defex } ;

PROCEDURE code_varex ;
BEGIN
     PushW(HP) ;
END { code_varex } ;

PROCEDURE code_consex ;
BEGIN
     PushW(PeekW(HP)) ;
END { code_consex } ;

{
     ----------------
     Field Primitives
     ----------------

     >>>     Field Transport
     <source-addr> <dest-addr> <n> >>>
     empty. Copies n bytes from source-addr to dest-addr.
     1<=n <= 256. Lowest address is copied first.

     RERFERENCE: IPS Language Reference Manual Draft E 15 Feb 1996
}

PROCEDURE code_field_trans ;
VAR
     SourceAddr      : WORD ;
     DestinationAddr : WORD ;
     Count           : WORD ;
     B               : BYTE ;
BEGIN

     Count           := PopW ;
     DestinationAddr := PopW ;
     SourceAddr      := PopW ;

     REPEAT
           B := PeekB(SourceAddr) ;
           Inc(SourceAddr) ;
           PokeB(DestinationAddr,B) ;
           Inc(DestinationAddr) ;
           Count := (Count - 1) AND $ff ;
     UNTIL (Count = 0) ;

END { code_field_trans } ;

{
     -----------------
     Kernel Primitives
     -----------------

     REFERENCE:  IPS High Level Programming of Small Systems, 2nd Edition, Karl Meinzer, 1978
                 Page 76 - 5.2.1 Scanner and name coding
                 Page 81 - 5.4 Entry generating routines ($POLYNAME examaple!!!!)
}

PROCEDURE code__polyname ;
VAR
     A : WORD ;
     B : WORD ;
     C : WORD ;
     D : LONGINT ;
     X : LONGINT ;
     P : LONGINT ;
BEGIN

{
     "WEG/AB" encodes as #D5 #10 #17
}

     D := PopW ;      { character }
     C := PopW ;      { 008d }
     B := PopW ;      { ce57 }
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

     WordRecType(B).Hi := Lo(B) ;
     WordRecType(B).Lo := Lo(A) ;

     PushW(B) ;
     PushW(C) ;

END { code__polyname } ;

(*

Dear Paul,

I have written primitives in C++ for $SCODE, and $CSCAN. The first makes
compiling files about 2-3 times faster!!

To run these I had to modify the IPS-Mp source code to call the primitives
instead of IPS, as well as changes to $P3, $SUCH, and $ND and recompile it.

When done the results were impressive. $CSCAN doesn't add much, but by
having both of the primitives we can bring our IPS in line with James' and
hopefully need only one set of kernels.

Here are the primitives in C++, should be easy to convert to PASCAL.


Now your quiz question, why does the value of E have the "&" with 0x3F??
*)

(*
Looks through linked list until name found
------------------------------------------
Return address of a word. 0 if not found
$P3 points to SYS PAGE loc. holding initial link pointer
$ND contains the 4-byte hashed name
*)

PROCEDURE code__scode ;
VAR
     D, N , Os : WORD ;
     E, F, G, H, I : BYTE ;
BEGIN
     N := PeekW(ND) ;
     Os := PeekW(_Os) ;
     D := PeekW(P3) + Os ; { Link value }
     E := PeekB(D) AND $3F ; { value at Link, LSB }
     F := PeekB(N) ; { $ND, LSB }
     G := PeekB(N+1) ; { $ND }
     H := PeekB(N+2) ; { $ND }
     I := PeekB(N+3) ; { $ND, MSB }
     WHILE (E<>F) OR (PeekB(D+1)<>G) OR (PeekB(D+2)<>H) OR (PeekB(D+3)<>I) DO BEGIN
         D := PeekW(D+4) + Os ;
         IF (D=Os) THEN BEGIN
             PushW(0) ;
             Exit ;
         END ;
         E := PeekB(D) AND $3F ;
     END ;
     Inc(D,6) ;
     PushW(D) ;
END { code__scode } ;

(*
$CSCAN Scan input buffer for separators/non-separators
-------------------------------------------------------
There are only two calls to this, both from $NAME
The first has entry flag =1, and causes scan to first
non-separator

The 2nd has entry flag =2 which scans to next separator.
Thus a found word is bracketed by $P1 Start byte and $PI
where $PI is the Index pointer.

Entry = 1
---------
Scan until valid character found
Returns >0 if valid character found
0 if invalid character
$P1 = $PI init by $NAME when valid char found
$P2 = 1 if if end of buffer found i.e. $PI=$PE

Entry = 2
---------
Scan until separator found
Returns n1 which can be discarded ???
n2 which can be discarded ???
$P1 and $PI-1 identifies word string

Separator = space { } <eob>
Valid character = NOT [ the above or anything inside { } ]
*)

PROCEDURE code__cscan ;

CONST cflag : BOOLEAN = FALSE ;

VAR
     _PI, _PE, I, RS : WORD ;
     J, K, C : BYTE ;

BEGIN

     PushW(0) ;
     _PI := PeekW(PI) ;
     _PE := PeekW(PE) ;
     I := _PI ;
     WHILE (I<=_PE) DO BEGIN (* for(I=Pi;I<=Pe;I++){ *)
         Inc(PSP,2) ;
         PushW(1) ;
         C := PeekB(I) ;
         IF (C<>$20) THEN BEGIN
             IF (cflag) THEN BEGIN
                IF (C=$29) THEN BEGIN
                    cflag := FALSE ;
                END ;
             END
             ELSE BEGIN
                IF (C=$28) THEN BEGIN
                    cflag := TRUE ;
                END
                ELSE BEGIN
                    Inc(PSP,2) ;
                    PushW(2) ;
                END ;
             END ;
         END ;
         J := PopW ;
         K := PopW ;
         PushW(J) ;
         IF (J=K) THEN BEGIN
             PushW(0) ;
         END
         ELSE BEGIN
             PokeW(PI,I) ;
             I := _PE ;
         END ;
         Inc(I) ;
     END ;

     IF (PeekW(PSP)=0) THEN BEGIN
         PokeW(PI,Succ(PeekW(PE))) ;
         J := PopW ;
         K := PopW ;
         PushW(J) ;
         PokeW(P2,1) ;
     END ;

END { code__cscan } ;

{
     ******************
     Emulator & Support
     ******************

     This is the code for the IPS word $IPSETZEN Takes a value off the stack,
     sets the keyboard pointer to this, AND &3FF. This will be where the cursor
     appears (a black blob) and where new typing will thus appear.
}

PROCEDURE code_setkbptr ;
BEGIN
     INPUTPOINTER := PopW AND $3FF ;
     LOADPOINTER := INPUTPOINTER ;
     PokeB(INPUTPOINTER,PeekB(INPUTPOINTER) OR $80) ;
END { code_setkbptr } ;

{
     This routine returns the string specified in IPS " STR " on
     the stack.
}

FUNCTION PopStr:STRING ;
VAR
     StrLen   : WORD   ;
     StrStart : WORD   ;
     OutStr   : STRING ;
BEGIN

     StrLen := PopW ;
     StrStart := PopW ;

     OutStr := '' ;
     WHILE (0<StrLen) DO BEGIN
         OutStr := OutStr + CHAR(PeekB(StrStart)) ;
         Inc(StrStart) ;
         Dec(StrLen) ;
     END ;

     PopStr := OutStr ;

END { PopStr } ;

{
     **************************
     Console Disk File Handling
     **************************

     $CLOSEFILE - takes no parameters, does just what it says.

     REFERENCE: James R. Miller, Private Communication, December 18, 2000.
}

PROCEDURE code_closefile ;
BEGIN
     IF (IsOpen) THEN BEGIN
         Close(TextFile) ;
         IsOpen := FALSE ;
     END ;
END { code_closefile } ;

{
     $OPENFILE - is called by READ, which executes a file of IPS
     words. Expects two items on the stack which are pointers to
     the start and end of the filename you typed in on the screen as
     in " MYFILE " READ. Removes two items from the stack, and returns
     one item on the stack, value 1 for success, 0 for failure of
     some kind plus debris.

     REFERENCE: James R. Miller, Private Communication, December 18, 2000.

     NOTE: The filename pointers are Start Address, and Length.

     i.e.

     The keyboard commands: " FILENAME " READ

     generates:

     <Filename Start Address> <Filename Length> $OPENFILE
}

PROCEDURE code_openfile ;

LABEL Failure ;

BEGIN

     Assign(TextFile,PopStr) ;
     {$i-}
     Reset(TextFile) ;
     IF (IOResult<>0) THEN BEGIN
         GOTO Failure ;
     END ;
     {$i+}

     PushW(1) ;

     IsOpen := TRUE ;

     Exit ;

Failure:

     {$i+}
     PushW(0) ;

END { code_openfile } ;

{
     $LOADCODE - is called by LOAD, which loads a file to memory.
     Requires 3 items on the stack; address to load data, and filename
     pointers. Removes three items from stack, and returns one item
     on the stack value 1 for success, 0 for failure of some kind plus
     debris.

     REFERENCE: James R. Miller, Private Communication, December 18, 2000.

     NOTE: The filename pointers are Start Address, and Length.

     i.e.

     The keyboard commands: <Load Address> " FILENAME " $LOAD

     generates:

     <Load Address> <Filename Start Address> <Filename Length> $LOADCODE
}

PROCEDURE code_loadcode ;

VAR
     LoadAddr  : WORD         ;
     ByteValue : BYTE         ;
     FSize     : LONGINT      ;
     TextFile  : FILE OF BYTE ;

LABEL Failure, Failure2 ;

BEGIN

     Assign(TextFile,PopStr) ;
     LoadAddr  := PopW ;

     {$i-}
     Reset(TextFile) ;
     IF (IOResult<>0) THEN BEGIN
         GOTO Failure ;
     END ;
     FSize := FileSize(TextFile) ;
     IF (IOResult<>0) THEN BEGIN
         GOTO Failure2 ;
     END ;
     IF (FSize=0) OR ((LoadAddr+FSize)>65536) THEN BEGIN
         GOTO Failure2 ;
     END ;
     {$i+}

     WHILE (NOT Eof(TextFile)) DO BEGIN
         Read(TextFile,ByteValue) ;
         PokeB(LoadAddr,ByteValue) ;
         Inc(LoadAddr) ;
     END ;

     Close(TextFile) ;

     PushW(1) ;

     Exit ;

Failure2:

     Close(TextFile) ;

Failure:

     {$i+}
     PushW(LoadAddr) ;
     PushW(0) ;

END { code_loadcode } ;

{
     $SAVECODE - is called by SAVE ; saves out a block of memory.
     Requires 4 items on the stack; Start addr, last addr+1 and filename
     pointers. Removes 4 items from stack, and returns one item on the
     stack, value 1 for success, 0 for failure of some kind, plus debris.

     REFERENCE: James R. Miller, Private Communication, December 18, 2000.
}

PROCEDURE code_savecode ;
VAR
     LastAddr  : WORD    ;
     StartAddr : WORD    ;
     BlockLen  : LONGINT ;
     ByteValue : BYTE    ;
     TextFile  : FILE OF BYTE  ;

LABEL Failure ;

BEGIN

     Assign(TextFile,PopStr) ;
     LastAddr := PopW ;
     StartAddr := PopW ;
     BlockLen := LastAddr - StartAddr ;

     IF (BlockLen<>0) AND (StartAddr<LastAddr) THEN BEGIN

         {$i-}
         ReWrite(TextFile) ;
         IF (IOResult<>0) THEN BEGIN
             GOTO Failure ;
         END ;
         {$i+}

         BlockLen := ((BlockLen+511) DIV 512) * 512 ;

         WHILE (0<BlockLen) DO BEGIN
             ByteValue := PeekB(StartAddr) ;
             Write(TextFile,ByteValue) ;
             Inc(StartAddr) ;
             Dec(BlockLen) ;
         END ;

         Close(TextFile) ;

         PushW(1) ;

         Exit ;

     END ;

Failure:

     {$i+}
     PushW(StartAddr) ;
     PushW(LastAddr) ;
     PushW(0) ;

END { code_savecode } ;

{
     CYC2 takes a 16-bit seed and a byte and returns the
     crcc'd value. Typically used in a loop, e.g.
     #FFFF 0 511 JE I @B CYC2 NUN

     <seed> <byte> CYC2
     <new seed>

     NOTE: CRCC needs MSB sent first!
}

PROCEDURE code_cyc2 ;
VAR
     OutChar : BYTE ;
     Swap    : WORD ;
BEGIN
     OutChar := PopW AND $FF ;
     Swap := PopW ;
     Swap := AMSAT_CRCC(Lo(Swap) SHL 8 + Hi(Swap),OutChar) ;
     PushW(Lo(Swap) SHL 8 + Hi(Swap)) ;
END { code_cyc2 } ;

{
     OSCLI - Send a command to the DOS Operating System.
             (Note: OSCLI = Operating System Command Line Interpreter)
             This word cannot be used within a definition.

     < " Command " > OSCLI

     Examples:

     " dir " OSCLI

     Error Conditions:
      Invalid Command. (Up to 2 words may be left on the stack)

     NOTE: This makes a real mess of the screen, ... I can't find
     a way as yet of forcing the DOS output to a small window.
}

PROCEDURE code_oscli ;
BEGIN
    Exec(OSCLIPath,'/C '+PopStr) ;
    PushW(1) ;
END { code_oscli } ;

{
     *********************************
     PC I/O Port and DOS Memory Access
     *********************************
}

{
     <M> PCPORT@B
     Reads the PC I/O Port address M, and places the
     byte on top of the parameter stack

     : PCPORT@B $funct_00 ;
}

PROCEDURE code__funct_00 ;
VAR
     Addr : WORD ;
BEGIN
     Addr := PopW ;
     PushW(Port[Addr]) ;
END { code__funct_00 } ;

{
     <M> PCPORT@
     Reads the PC I/O Port address M, and places the
     word on top of the parameter stack

     : PCPORT@  $funct_01 ;
}

PROCEDURE code__funct_01 ;
VAR
     Addr : WORD ;
BEGIN
     Addr := PopW ;
     PushW(PortW[Addr]) ;
END { code__funct_01 } ;

{
     <N> <M> PCPORT!B
     Writes the byte N to the PC I/O Port address M

     : PCPORT!B $funct_02 ;
}

PROCEDURE code__funct_02 ;
VAR
     Addr : WORD ;
BEGIN
     Addr := PopW ;
     Port[Addr] := Lo(PopW) ;
END { code__funct_02 } ;

{
     <N> <M> PCPORT!
     Writes the word N to the PC I/O Port address M

     : PCPORT!  $funct_03 ;
}

PROCEDURE code__funct_03 ;
VAR
     Addr : WORD ;
BEGIN
     Addr := PopW ;
     PortW[Addr] := PopW ;
END { code__funct_03 } ;

{
     <Seg> <Off> PCMEM@B
     Reads the PC Memory address Seg:Off, and places
     the byte on top of the parameter stack

     : PCMEM@B $funct_04 ;
}

PROCEDURE code__funct_04 ;
VAR
     AddrOfs : WORD ;
     AddrSeg : WORD ;
BEGIN
     AddrOfs := PopW ;
     AddrSeg := PopW ;
     PushW(Mem[AddrSeg:AddrOfs]) ;
END { code__funct_04 } ;

{
     <Seg> <Off> PCMEM@
     Reads the PC Memory address Seg:Off, and places
     the word on top of the parameter stack            

     : PCMEM@  $funct_05 ;
}

PROCEDURE code__funct_05 ;
VAR
     AddrOfs : WORD ;
     AddrSeg : WORD ;
BEGIN
     AddrOfs := PopW ;
     AddrSeg := PopW ;
     PushW(MemW[AddrSeg:AddrOfs]) ;
END { code__funct_05 } ;

{
     <N> <Seg> <Off> PCMEM!B
     Writes the byte N to the PC Memory address
     Seg:Off

     : PCMEM!B $funct_06 ;
}

PROCEDURE code__funct_06 ;
VAR
     AddrOfs : WORD ;
     AddrSeg : WORD ;
BEGIN
     AddrOfs := PopW ;
     AddrSeg := PopW ;
     Mem[AddrSeg:AddrOfs] := Lo(PopW) ;
END { code__funct_06 } ;

{
     <N> <Seg> <Off> PCMEM!
     Writes the word N to the PC Memory address
     Seg:Off

     : PCMEM!  $funct_07 ;
}

PROCEDURE code__funct_07 ;
VAR
     AddrOfs : WORD ;
     AddrSeg : WORD ;
BEGIN
     AddrOfs := PopW ;
     AddrSeg := PopW ;
     MemW[AddrSeg:AddrOfs] := PopW ;
END { code__funct_07 } ;

{
     <N> <M> AUXOUTB                                      

     Writes the byte <N> to the output buffer of COM Port <M>
     : AUXOUTB $funct_08 ;
}

PROCEDURE code__funct_08 ;
VAR
     AuxPort : WORD ;
BEGIN
     AuxPort := PopW ;
     PutAuxOut(AuxPort,Lo(PopW)) ;
END { code__funct_08 } ;

{
     <M> AUXINB

     Reads a byte from the input buffer of COM Port <M>, and places
     it on the parameter stack.

     : AUXINB $funct_09 ;
}

PROCEDURE code__funct_09 ;
BEGIN
     PushW(GetAuxIn(PopW)) ;
END { code__funct_09 } ;

{
     <M> AUXINCOUNT

     Places the number of characters in the input buffer of COM Port <M> on
     the parameter stack

     : AUXINCOUNT $funct_0A ;
}

PROCEDURE code__funct_0a ;
BEGIN
     PushW(Aux[PopW]^.IBufCount) ;
END { code__funct_0a } ;

{
     <M> AUXOUTCOUNT

     Places the number of characters in the output buffer of COM Port <M> on
     the parameter stack

     : AUXOUTCOUNT $funct_0B ;
}

PROCEDURE code__funct_0b ;
BEGIN
     PushW(Aux[PopW]^.OBufCount) ;
END { code__funct_0b } ;

{
     <N> <Addr> <M> AUXREAD

     Reads N bytes from the specified Com port <M> to the buffer at
     address Addr.

     Returns the actual number of bytes read on the stack if successfull,
     otherwise 0.

     : AUXREAD $funct_17 ;
}

PROCEDURE code__funct_17 ;
VAR
     Handle    : WORD ;
     BufAddr   : WORD ;
     BytesToGo : WORD ;
     BytesRead : WORD ;
BEGIN

     Handle    := PopW ;
     BufAddr   := PopW ;
     BytesToGo := PopW ;

     BytesRead := 0 ;

     WHILE (Aux[Handle]^.IBufCount>0) AND (0<BytesToGo) DO BEGIN

         PokeB(BufAddr,GetAuxIn(Handle)) ;
         Inc(BufAddr) ;
         Inc(BytesRead) ;
         Dec(BytesToGo) ;

     END ;

     PushW(BytesRead) ;

END { code__funct_17 } ;

{
     <N> <Addr> <M> AUXWRITE

     Writes N bytes from the buffer at address Addr to the specified COM
     Port <M> buffer.

     Returns the actual number of bytes written on the stack if successful,
     otherwise 0.

     : AUXWRITE $funct_18 ;
}

PROCEDURE code__funct_18 ;
VAR
     Handle       : WORD ;
     BufAddr      : WORD ;
     BytesToGo    : WORD ;
     BytesWritten : WORD ;
BEGIN

     Handle    := PopW ;
     BufAddr   := PopW ;
     BytesToGo := PopW ;

     BytesWritten := 0 ;

     WHILE (Aux[Handle]^.OBufCount<AuxBufSize) AND (0<BytesToGo) DO BEGIN

         PutAuxOut(Handle,PeekB(BufAddr)) ;
         Inc(BufAddr) ;
         Inc(BytesWritten) ;
         Dec(BytesToGo) ;

     END ;

     PushW(BytesWritten) ;

END { code__funct_18 } ;

{
     <M> AUXCLRBUF

     Empties the input buffer associated with specified COM
     Port <M> buffer.

     Returns nothing

     : AUXCLRBUF $funct_19 ;
}

PROCEDURE code__funct_19 ;
BEGIN
     AuxClrBuf(PopW) ;
END { code__funct_19 } ;

{
     *******************
     MSDOS File Handling
     *******************
}

(*
     ips__funct_16 = $96    ; { feof                  }
*)

{
     <OpenMode> <Filename Start Address> <Filename Length> FOPEN

     Opens the specified file, in the mode specified by OpenMode.

     OpenMode:

         0 = Open file as read only. Fail if file does not exist.
             The file pointer is placed at the start of the file.

         1 = Create a file for read/write, if the file exists then
             it is replaced. The file pointer is placed at the
             start of the file.

         2 = Open a file for read/write, if the file exists then
             the file pointer is placed at the end of the file.
             If the file does not exist then it is created.

     Returns a non-zero file handle on the stack if successfull,
     otherwise 0.

     : FOPEN $funct_0C ;
}

PROCEDURE code__funct_0C ;
VAR
     FileName : STRING ;
     Handle   : WORD   ;
BEGIN
     FileName := PopStr ;
     Handle := fopen(FileName,PopW) ;
     IF (ferror=0) THEN BEGIN
         PushW(Handle) ;
     END
     ELSE BEGIN
         PushW(0) ;
     END ;
END { code__funct_0C } ;

{
     <Handle> FCLOSE

     Closes the specified file

     Returns 1 on the stack if successfull, otherwise 0.

     : FCLOSE $funct_0D ;
}

PROCEDURE code__funct_0D ;
BEGIN
     fclose(PopW) ;
     IF (ferror=0) THEN BEGIN
         PushW(1) ;
     END
     ELSE BEGIN
         PushW(0) ;
     END ;
END { code__funct_0D } ;

{
     <N> <Addr> <Handle> FREAD

     Reads N bytes from the specified file, starting at the current file
     pointer position, to the buffer at address Addr.

     Returns the actual number of bytes read on the stack if successfull,
     otherwise 0.

     : FREAD $funct_0E ;
}

PROCEDURE code__funct_0E ;
CONST
     ReadBufSize = 1024 ;
VAR
     Handle    : WORD ;
     BufAddr   : WORD ;
     Buffer    : ARRAY[0..ReadBufSize-1] OF BYTE ;
     BytesToGo : WORD ;
     ThisRead  : WORD ;
     Index     : WORD ;
     BytesRead : WORD ;
BEGIN

     Handle    := PopW ;
     BufAddr   := PopW ;
     BytesToGo := PopW ;

     BytesRead := 0 ;

     WHILE (feof(Handle)=0) AND (0<BytesToGo) DO BEGIN

         ThisRead := WMin(BytesToGo,ReadBufSize) ;

         fread(Handle,Buffer,ThisRead) ;

         IF (ferror=0) THEN BEGIN

             Index := 0 ;
             WHILE (Index<ThisRead) DO BEGIN
                 PokeB(BufAddr,Buffer[Index]) ;
                 Inc(BufAddr) ;
                 Inc(Index) ;
             END ;

             Inc(BytesRead,ThisRead) ;
             Dec(BytesToGo,ThisRead) ;

         END
         ELSE BEGIN
             PushW(0) ;
             Exit ;
         END ;

     END ;

     PushW(BytesRead) ;

END { code__funct_0E } ;

{
     <N> <Addr> <Handle> FWRITE

     Writes N bytes from the buffer at address Addr to the specified file,
     starting at the current file pointer position.

     Returns the actual number of bytes written on the stack if successful,
     otherwise 0.

     : FWRITE $funct_0F ;
}

PROCEDURE code__funct_0F ;
CONST
     WriteBufSize = 1024 ;
VAR
     Handle       : WORD ;
     BufAddr      : WORD ;
     Buffer       : ARRAY[0..WriteBufSize-1] OF BYTE ;
     BytesToGo    : WORD ;
     ThisWrite    : WORD ;
     Index        : WORD ;
     BytesWritten : WORD ;
BEGIN

     Handle    := PopW ;
     BufAddr   := PopW ;
     BytesToGo := PopW ;

     BytesWritten := 0 ;

     WHILE (0<BytesToGo) DO BEGIN

         ThisWrite := WMin(BytesToGo,WriteBufSize) ;

         Index := 0 ;
         WHILE (Index<ThisWrite) DO BEGIN
             Buffer[Index] := PeekB(BufAddr) ;
             Inc(BufAddr) ;
             Inc(Index) ;
         END ;

         fwrite(Handle,Buffer,ThisWrite) ;

         IF (ferror=0) THEN BEGIN

             Inc(BytesWritten,ThisWrite) ;
             Dec(BytesToGo,ThisWrite) ;

         END
         ELSE BEGIN
             PushW(0) ;
             Exit ;
         END ;

     END ;

     PushW(BytesWritten) ;

END { code__funct_0F } ;

{
     <Offset, least sig. 16 bits>, <Offset, most sig. 16 bits> <Mode> <Handle> FSEEK

     Changes the file pointer for the selected file.

     Mode:  fs_Absolute        = 0  Absolute Offset Start of File
            fs_OffsetCurrent   = 1  Signed Offset from Current File Pointer
            fs_OffsetEndOfFile = 2  Signed Offset from End of File

     Returns the 3 words on the stack.

     <New Absolute Offset, least sig. 16 bits>, <New Absolute Offset, most sig. 16 bits> <Status>

     Where Status = 1 if successfull, 0 if failure.

     : FSEEK $funct_10 ;
}

PROCEDURE code__funct_10 ;
VAR
     Handle    : WORD    ;
     SeekMode  : BYTE    ;
     Offset    : LONGINT ;
BEGIN
     Handle := PopW ;
     SeekMode := PopW AND $FF ;
     DWordRecType(Offset).Hi := PopW ;
     DWordRecType(Offset).Lo := PopW ;
     fseek(Handle,Offset,SeekMode) ;
     PushW(DWordRecType(Offset).Lo) ;
     PushW(DWordRecType(Offset).Hi) ;
     IF (ferror=0) THEN BEGIN
         PushW(1) ;
     END
     ELSE BEGIN
         PushW(0) ;
     END ;
END { code__funct_10 } ;

{
     <Handle> FGETB
     <Return Value>

     Reads 1 byte from the specified file, starting at the current file
     pointer position, and places it in the LSB of the return value.

     If successfull the MSB of the return value is 1, otherwise 0

     : FGETB $funct_11 ;
}

PROCEDURE code__funct_11 ;
VAR
     Handle      : WORD ;
     ReturnValue : WORD ;
     ThisRead    : WORD ;
BEGIN

     Handle   := PopW ;
     ThisRead := 1    ;

     fread(Handle,ReturnValue,ThisRead) ;

     IF (ferror=0) AND (ThisRead=1) THEN BEGIN
         ReturnValue := ReturnValue OR $0100 ;
     END
     ELSE BEGIN
         ReturnValue := 0 ;
     END ;

     PushW(ReturnValue) ;

END { code__funct_11 } ;

{
     <N> <Handle> FPUTB
     <Return Value>

     Writes the LS-byte of N to the specified file, starting at the current file
     pointer position.

     If successfull the return value is 1, otherwise 0

     : FPUTB $funct_12 ;
}

PROCEDURE code__funct_12 ;
VAR
     Handle      : WORD ;
     ThisWrite   : WORD ;
     Buffer      : WORD ;
BEGIN

     Handle := PopW ;
     Buffer := PopW ;

     ThisWrite := 1 ;

     fwrite(Handle,Buffer,ThisWrite) ;

     IF (ferror=0) AND (ThisWrite=1) THEN BEGIN
         PushW(1) ;
     END
     ELSE BEGIN
         PushW(0) ;
     END ;

END { code__funct_12 } ;

{
     <Handle> FFLUSH

     This routine forces all data in MS-DOS's internal buffers
     associated with the specified handle to be physically
     written to the disk, the time and date stamp and file
     size in the file's directory entry are updated. It is
     equivalent to closing then re-opening the file, with the
     benefit of not changing the file handle value.

     Returns 1 on the stack if successfull, otherwise 0.

     : FFLUSH $funct_13 ;
}

PROCEDURE code__funct_13 ;
BEGIN
     fflush(PopW) ;
     IF (ferror=0) THEN BEGIN
         PushW(1) ;
     END
     ELSE BEGIN
         PushW(0) ;
     END ;
END { code__funct_13 } ;

{
     <Filename Start Address> <Filename Length> FDELETE

     Deletes the specified file.

     Returns 1 on the stack if successfull, otherwise 0.

     : FDELETE $funct_14 ;
}

PROCEDURE code__funct_14 ;
VAR
     FileName : STRING ;
BEGIN
     FileName := PopStr ;
     fdelete(FileName) ;
     IF (ferror=0) THEN BEGIN
         PushW(1) ;
     END
     ELSE BEGIN
         PushW(0) ;
     END ;
END { code__funct_14 } ;

{
     <Old Filename Start Address> <Old Filename Length> <New Filename Start Address> <New Filename Length> FRENAME

     Renames the specified file.

     Returns 1 on the stack if successfull, otherwise 0.

     : FRENAME $funct_15 ;
}

PROCEDURE code__funct_15 ;
VAR
     NewName : STRING ;
BEGIN
     NewName := PopStr ;
     frename(PopStr,NewName) ;
     IF (ferror=0) THEN BEGIN
         PushW(1) ;
     END
     ELSE BEGIN
         PushW(0) ;
     END ;
END { code__funct_15 } ;

{
     <Handle> FEOF

     Returns 1 on the stack if there is nothing left to read from the
     specified file, otherwise 0.

     : FEOF $funct_16 ;
}

PROCEDURE code__funct_16 ;
VAR
     ReturnResult : WORD ;
BEGIN
     ReturnResult := feof(PopW) ;
     IF (ferror=0) THEN BEGIN
         PushW(ReturnResult) ;
     END
     ELSE BEGIN
         PushW(1) ;
     END ;
END { code__funct_16 } ;

{
     Define Keyboard Macro

     <Macro String Start Address> <Macro String Length> <Scan Code> DEF-KEY-MACRO

     Returns Nothing
}

PROCEDURE code__funct_1C ;
VAR
     NewMacro : KeyboardMacroPtr ;
BEGIN
     New(NewMacro) ;
     WITH NewMacro^ DO BEGIN
         ScanCode := Lo(PopW) ;
         Macro := PopStr ;
         NextMacro := KeyboardMacros ;
     END ;
     KeyboardMacros := NewMacro ;
     NewMacro := NIL ;
END { code__funct_1C } ;

{
     *************
     Miscellaneous
     *************
}

PROCEDURE SetDateFromDos ;
VAR
     AMSATDay, Year, Month, Day, DayOfWeek : WORD ;
BEGIN
     GetDate(Year,Month,Day,DayOfWeek) ;
     Month := Month + 1 ;
     IF (Month < 4) THEN BEGIN
         Year := Year - 1 ;
         Month := Month + 12 ;
     END ;
     Month := Month * 306 DIV 10 ;
     Year := Year - 1900 ;
     AMSATDay := Year * 365 ;
     AMSATDay := AMSATDay + Year DIV 4 + Month ;
     AMSATDay := AMSATDay + Day - 28553 ;
     PokeW(UHR+4,AMSATDay) ;
END ;

PROCEDURE SetTimeFromDos ;
VAR
     Hours, Minutes, Seconds, Sec100 : WORD ;
     Time : DOUBLE ;
BEGIN

     GetTime(Hours,Minutes,Seconds,Sec100) ;

     Time := Hours +
             Minutes / (60.0                      ) +
             Seconds / (60.0 * 60.0               ) +
             Sec100  / (60.0 * 60.0 * 60.0 * 100.0) -
             UTCOffset                              ;

     IF (Time<0.0) THEN BEGIN
         PokeW(UHR+4,PeekW(UHR+4)-1) ;
         Time := Time + 24.0
     END
     ELSE IF (Time>24.0) THEN BEGIN
         PokeW(UHR+4,PeekW(UHR+4)+1) ;
         Time := Time - 24.0
     END ;

     Hours   := Trunc(Time) ; Time := (Time - Hours  ) *  60.0 ;
     Minutes := Trunc(Time) ; Time := (Time - Minutes) *  60.0 ;
     Seconds := Trunc(Time) ; Time := (Time - Seconds) * 100.0 ;
     Sec100  := Trunc(Time) ;

     PokeB(UHR+0,Sec100 AND $fe) ; { Mask off odd Sec100 } ;
     PokeB(UHR+1,Lo(Seconds)) ;
     PokeB(UHR+2,Lo(Minutes)) ;
     PokeB(UHR+3,Lo(Hours)) ;

END ;

PROCEDURE code_uhr_lock ;
BEGIN
END { code_uhr_lock } ;

PROCEDURE code_sleep_time ;
BEGIN
END { code_sleep_time } ;

{
     Initialize IPSDOS Virtual Machine
     This routine reloads the kernal from file.
}

PROCEDURE ReloadKernal ;
VAR
     BinaryImage : FILE OF BYTE ;
     MemValue    : BYTE         ;
     Index       : WORD         ;
BEGIN

{
     Load IPS-Mw kernel
}

     Assign(BinaryImage, KernalPath) ;
     Reset(BinaryImage) ;
     Index := $0000 ;
     WHILE (NOT EOF(BinaryImage)) DO BEGIN
         Read(BinaryImage,MemValue) ;
         PokeB(Index,MemValue) ;
         Inc(Index) ;
     END ;
     Close(BinaryImage) ;

{
     Set JumpTable to Dummy IPS Primative (NO-OP)
}

     FOR Index := $00 To $ff DO BEGIN
         JumpTable[Index] := code_rumpelstilzchen ;
     END ;

{
     Set JumpTable for IPS Primatives
}

     JumpTable[ips_return]      := code_rumpelstilzchen ;
     JumpTable[ips_defex]       := code_defex           ;
     JumpTable[ips_consex]      := code_consex          ;
     JumpTable[ips_varex]       := code_varex           ;
     JumpTable[ips_retex]       := code_retex           ;
     JumpTable[ips_get]         := code_get             ;
     JumpTable[ips_getB]        := code_getb            ;
     JumpTable[ips_put]         := code_put             ;
     JumpTable[ips_putB]        := code_putb            ;
     JumpTable[ips_blit_1]      := code_blit_1          ;
     JumpTable[ips_blit_2]      := code_blit_2          ;
     JumpTable[ips_bronz]       := code_bronz           ;
     JumpTable[ips_jump]        := code_jump            ;
     JumpTable[ips_weg]         := code_weg             ;
     JumpTable[ips_pweg]        := code_pweg            ;
     JumpTable[ips_plus]        := code_plus            ;
     JumpTable[ips_minus]       := code_minus           ;
     JumpTable[ips_pplus]       := code_pplus           ;
     JumpTable[ips_pminus]      := code_pminus          ;
     JumpTable[ips_dup]         := code_dup             ;
     JumpTable[ips_pdup]        := code_pdup            ;
     JumpTable[ips_vert]        := code_vert            ;
     JumpTable[ips_zwo]         := code_zwo             ;
     JumpTable[ips_rdu]         := code_rdu             ;
     JumpTable[ips_rdo]         := code_rdo             ;
     JumpTable[ips_index]       := code_Index           ;
     JumpTable[ips_s_to_r]      := code_s_to_r          ;
     JumpTable[ips_r_to_s]      := code_r_to_s          ;
     JumpTable[ips_eqz]         := code_eqz             ;
     JumpTable[ips_gz]          := code_gz              ;
     JumpTable[ips_lz]          := code_lz              ;
     JumpTable[ips_geu]         := code_geu             ;
     JumpTable[ips_f_vergl]     := code_f_vergl         ;
     JumpTable[ips_nicht]       := code_nicht           ;
     JumpTable[ips_und]         := code_und             ;
     JumpTable[ips_oder]        := code_oder            ;
     JumpTable[ips_exo]         := code_exo             ;
     JumpTable[ips_bit]         := code_bit             ;
     JumpTable[ips_cbit]        := code_cbit            ;
     JumpTable[ips_sbit]        := code_sbit            ;
     JumpTable[ips_tbit]        := code_tbit            ;
     JumpTable[ips_jeex]        := code_jeex            ;
     JumpTable[ips_loopex]      := code_loopex          ;
     JumpTable[ips_plusloopex]  := code_plusloopex      ;
     JumpTable[ips_field_trans] := code_field_trans     ;
     JumpTable[ips_pmul]        := code_pmul            ;
     JumpTable[ips_pdiv]        := code_pdiv            ;
     JumpTable[ips_tue]         := code_tue             ;
     JumpTable[ips__polyname]   := code__polyname       ;
     JumpTable[ips__scode]      := code__scode          ;
     JumpTable[ips__cscan]      := code__cscan          ;
     JumpTable[ips_chs]         := code_chs             ;
     JumpTable[ips_cyc2]        := code_cyc2            ;
     JumpTable[ips_close]       := code_closefile       ;
     JumpTable[ips_open]        := code_openfile        ;
     JumpTable[ips_oscli]       := code_oscli           ;
     JumpTable[ips_load]        := code_loadcode        ;
     JumpTable[ips_save]        := code_savecode        ;
     JumpTable[ips_setkbptr]    := code_setkbptr        ;
     JumpTable[ips_getPS]       := code_getps           ;
     JumpTable[ips_setPS]       := code_setps           ;
     JumpTable[ips_rp_code]     := code_rp_code         ;
     JumpTable[ips_tr_code]     := code_tr_code         ;
     JumpTable[ips_swap3]       := code_swap3           ;
(*   JumpTable[ips_defchar]     := code_defchar         ; *)
     JumpTable[ips__funct_00]   := code_uhr_lock        ;
     JumpTable[ips__funct_01]   := code_sleep_time      ;
     JumpTable[ips__funct_02]   := code__funct_02       ;
     JumpTable[ips__funct_03]   := code__funct_03       ;
     JumpTable[ips__funct_04]   := code__funct_04       ;
     JumpTable[ips__funct_05]   := code__funct_05       ;
     JumpTable[ips__funct_06]   := code__funct_06       ;
     JumpTable[ips__funct_07]   := code__funct_07       ;
     JumpTable[ips__funct_08]   := code__funct_08       ;
     JumpTable[ips__funct_09]   := code__funct_09       ;
     JumpTable[ips__funct_0A]   := code__funct_0A       ;
     JumpTable[ips__funct_0B]   := code__funct_0B       ;
     JumpTable[ips__funct_0C]   := code__funct_0C       ;
     JumpTable[ips__funct_0D]   := code__funct_0D       ;
     JumpTable[ips__funct_0E]   := code__funct_0E       ;
     JumpTable[ips__funct_0F]   := code__funct_0F       ;
     JumpTable[ips__funct_10]   := code__funct_10       ;
     JumpTable[ips__funct_11]   := code__funct_11       ;
     JumpTable[ips__funct_12]   := code__funct_12       ;
     JumpTable[ips__funct_13]   := code__funct_13       ;
     JumpTable[ips__funct_14]   := code__funct_14       ;
     JumpTable[ips__funct_15]   := code__funct_15       ;
     JumpTable[ips__funct_16]   := code__funct_16       ;
     JumpTable[ips__funct_17]   := code__funct_17       ;
     JumpTable[ips__funct_18]   := code__funct_18       ;
     JumpTable[ips__funct_19]   := code__funct_19       ;
     JumpTable[ips__funct_1A]   := code__funct_00       ;
     JumpTable[ips__funct_1B]   := code__funct_01       ;
     JumpTable[ips__funct_1C]   := code__funct_1C       ;
(*   JumpTable[ips__funct_1D]   := code__funct_1D       ; *)
(*   JumpTable[ips__funct_1E]   := code__funct_1E       ; *)
(*   JumpTable[ips__funct_1F]   := code__funct_1F       ; *)

{
     Initialize the Emulator workspace
}

     PPC          := SYSPAGE ;
     IsOpen       := FALSE   ;
     INPUTPOINTER := TV8     ;

{
     Optionally Set the Clock
}

     IF (SetClock) THEN BEGIN
         SetDateFromDOS ;
         SetTimeFromDOS ;
     END ;

END { ReloadKernal } ;

{
    Tidy-Up and De-Allocate dynamic variables
}

PROCEDURE MyExit ;
VAR
     MacroPtr : KeyboardMacroPtr ;
BEGIN

{
     Pass Control to Next Exit Procedure <- Always First!
}

     ExitProc := ExitSave ;

{
     De-Allocate Dynamics
}

     WHILE (KeyboardMacros<>NIL) DO BEGIN
         MacroPtr := KeyboardMacros ;
         KeyboardMacros := KeyboardMacros^.NextMacro ;
         Dispose(MacroPtr) ;
     END ;

END { MyExit } ;


BEGIN

     KeyboardMacros := NIL ;

{
     Link Exit Procedure
}

     ExitSave := ExitProc ;
     ExitProc := @MyExit ;
END. { Kernal }


