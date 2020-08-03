{
    *******************************************************************
    *             IPSDOS Virtual Machine Version 0.1.26               *
    *                 (c) 2001 Paul Willmott, VP9MU                   *
    *        IPS-Mp Kernal (c) 1997-2001 James R. Miller, G3RUH       *
    *******************************************************************

    * This source was written using Turbo Pascal 7.0 for DOS.

    * The target O/S is MS-DOS 4.X onwards.

    * SEE THE IPSDOS.TXT file for installation instructions!


    Update History
    --------------

    Version 0.1   Apr 28, 2001 - Limited Release to W4SM & G3RUH

            0.1.1 Apr 29, 2001 - Clock Improvements
                               - Extra In-Line Documentation
                               - Dynamic Variable De-Allocate
                               - Compiler Directives added In-Line
                               - $SAVECODE Implemented
                               - $CLOSEFILE Implemented
                               - $LOADCODE Implemented
                               - Limited Release to W4SM & G3RUH

            0.1.2 Apr 30, 2001 - Timer Reset Test added to PeekB/PokeB
                               - Command Line Option (/NOBIOS) to not use BIOS
                                 Event Timer added
                               - Event Timer Bug Fix (1 tick too many!)
                               - Limited Release to W4SM & G3RUH

            0.1.3 Apr 30, 2001 - /SETCLOCK & /SHOWCLOCK command line switches added.
                               - /SLOWVIDEO command line switch added
                               - Limited Release to W4SM & G3RUH

            0.1.4 May 01, 2001 - P* bug fix
                               - P/MOD crash bug fix
                               - Insert scroll at #3ff bug fix
                               - Cursor Down then enter bug fix
                               - JE NUN/NUN+ bug fix
                               - Limited Release to W4SM & G3RUH

            0.1.5 May 01, 2001 - P* changed to use Integers not DOUBLEs
                               - P/MOD changed to use Integers not DOUBLEs
                               - 80x87 support unlinked!
                               - Range Checking TURNED OFF!!!!!
                               - Limited Release to W4SM & G3RUH

            0.1.6 May 03, 2001 - Overflow Check added to P/MOD
                                 P/MOD changed back to Real, 80x87 re-linked!
                               - Limited Release to W4SM & G3RUH

            0.1.7 May 03, 2001 - Block Cursor Added
                               - Insert Mode (KBD) only active TV8..TVE
                               - Work started on READ support!
                               - Cursor Blink Off added
                               - Limited Release to W4SM & G3RUH

            0.1.8 May 04, 2001 - GotoXY References Removed from Cursor Movement
                               - READ support added
                               - IPS-Mp Kernal added (user functions)
                               - Limited Release to W4SM & G3RUH

            0.1.9 May 08, 2001 - Acorn Text File Fix
                               - $FUNCT_00 - Read  I/O Port    Byte
                               - $FUNCT_01 - Read  I/O Port    Word
                               - $FUNCT_02 - Write I/O Port    Byte
                               - $FUNCT_03 - Write I/O Port    Word
                               - $FUNCT_04 - Read  Memory Addr Byte
                               - $FUNCT_05 - Read  Memory Addr Word
                               - $FUNCT_06 - Write Memory Addr Byte
                               - $FUNCT_07 - Write Memory Addr Word

            0.1.10 May 21, 2001 - Communications Support added
                                - CYC2 added
                                - Source release only to W4SM

            0.1.11 May 22, 2001 - $EBU buffer added
                                  TRANSPORT support added to IBMPC.IPS
                                  Interrupt Driven Serial Communications added
                                  Work started on /NOIDLE option!
                                  Released to W4SM & G3RUH

            0.1.12 May 24, 2001 - Aux I/O changed to more generic method
                                - COM 1 - 4 direct, ... 3 - 4 are placeholders!
                                - /NOIDLE removed - this will be done in IPS
                                - EBUREADY, $EBU removed - this will be done in IPS
                                - DATA_IN, $RBU added - Command Decoder support
                                - Numerous bits for Serial Communications
                                - CYC2 changed from addr of byte to byte

            0.1.13 Jun 09, 2001 - New Kernal from James
                                - Byte order of CYC2 changed
                                - Split into Units
                                - Lots of stuff for Serial I/O
                                - COM3, COM4
                                - Now using Turbo Pascal 7.0 for DOS
                                - All references to Crt unit removed
                                - New functions added to replace Crt
                                - Colour Screen
                                - Released to W4SM & G3RUH

            0.1.14 Jun 09, 2001 - Memory Shrink for OSCLI added
                                - OSCLI added - Screen looks naff!
                                - Cursor Keys Fixed in ReadKey
                                - Released to W4SM & G3RUH

            0.1.15 Jun 09, 2001 - MSDOS FileIO added
                                - Console File I/O and OSCLI changed to use new PopStr
                                - KERNAL-BIN and OSCLI-CMD path options added to Config.cfg
                                - Limited Release to W4SM & G3RUH

            0.1.16 Jun 10, 2001 - Linear Address Space added
                                - Limited Release to W4SM & G3RUH

            0.1.17 Jun 11, 2001 - Handle Number checking added to FILEIO
                                  fsize example added to FILEIO.IPS
                                  CORDIC routines added: code_tr_code, code_rp_code
                                  code_swap3 added
                                - Limited Release to W4SM & G3RUH

            0.1.18 Jun 11, 2001 - Date set from DOS fix! oops!!!
                                - Limited Release to W4SM & G3RUH

            0.1.19 Jun 13, 2001 - P+ P- added
                                - UTCOffset added
                                - Limited Release to W4SM & G3RUH

            0.1.20 Jun 23, 2001 - Multiple Kernal Binary Selection added
                                - /REMOTE /X switches added

            0.1.21 Jul 15, 2001 - Fixes to stop watches

            0.1.22 Aug 28, 2001 - AUXCLRBUF added

            0.1.23 Sep 08, 2001 - Timer fix
                                  CORDIC removed from Trig primitives
                                  $SCODE, $CSCAN added

            0.1.24 Sep 14, 2001 - UHR-LOCK & SLEEP-TIME stubs added
                                  User Functions #80 and #81 renumbered

            0.1.25 Nov 17, 2001 - cflag made static in CSCAN
                                  _Os support added for IPS-X

            0.1.26 Nov 24, 2001 - Naming convention changes to have ! & @ first in names
                                - Keyboard Macros added
}

{
    Turbo Pascal 7.0 Compiler Options
    ---------------------------------
}

{$m 16384,0,128000} { Shrink Memory for OSCLI }

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

PROGRAM IPSDOS ;

USES

     DOS      ,
     TypeDefs ,
     ASCII    ,
     Strings  ,
     AuxIO    ,
     FileIO   ,
     Config   ,
     FastCrt  ,
     Timer    ,
     Engine   ,
     Streams  ,
     MathLib  ,
     Kernal   ,
     _20ms    ;

{
     MAIN - Execution Starts Here!
}

BEGIN
     Version := ' ipsdos 1.0 build 26 ' ;
     RunKernal ;
END.
