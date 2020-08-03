{
     This UNIT implements the user configuration of the IPSDOS
     system.

     The UNIT expects the file IPSDOS.CFG to be in the same
     directory as the executable!

     (c) 2001 Paul Willmott, VP9MU

     Version 1.0.0 - June  2, 2001
     Version 1.0.1 - June 10, 2001 - KernalPath, OSCLIPath added
     Version 1.0.2 - June 14, 2001 - UTCOffset added
     Version 1.0.3 - June 23, 2001 - KernalType added, and changes for multiple kernal binaries
}

UNIT Config ;

{
     Public Interface
}

INTERFACE

USES

     Strings ,
     AuxIO   ;

CONST

     DesktopKernal = 0 ;
     RemoteKernal  = 1 ;
     IPSXKernal    = 2 ;

VAR

     UseBIOS    : BOOLEAN ; { True if safe to use the BIOS Event Wait Call       }
     ShowClock  : BOOLEAN ; { True if UHR displayed in bottom left of PC Screen  }
     SlowVideo  : BOOLEAN ; { True if Direct Video Access to be by-passed        }
     SetClock   : BOOLEAN ; { True if Clock set from DOS at start-up             }
     OSCLIPath  : STRING  ; { DOS Command Interpreter Path & Filename            }
     UTCOffset  : DOUBLE  ; { UTC Offset in Hours                                }
     KernalType : BYTE    ; { 0 = Desktop, 1 = Remote, 2 = IPS-X                 }
     KernalPath : STRING  ; { Path and Filename of Active Kernal Binary File     }

{
     Hidden Implementation
}

IMPLEMENTATION

{
    *********************************************
             LOAD HARDWARE CONFIGURATION
                NO ERROR CHECKING!!!!
    IPSDOS.CFG FILE MUST BE IN CURRENT DIRECTORY!
    *********************************************
}

VAR

     ConfigFile : TEXT     ;
     sLine      : STRING   ;
     sToken     : STRING   ;
     sValue     : STRING   ;
     InAux      : BOOLEAN  ;
     AuxIndex   : BYTE     ;
     ii         : WORD     ;

     DesktopKernalPath : STRING  ; { Path and Filename of Desktop Kernal Binary File }
     RemoteKernalPath  : STRING  ; { Path and Filename of Remote Kernal Binary File  }
     IPSXKernalPath    : STRING  ; { Path and Filename of IPS-X Kernal Binary File   }

{
     Initialization
}

BEGIN

{
     Set Defaults
}

     UseBIOS    := TRUE  ;
     SlowVideo  := FALSE ;
     ShowClock  := FALSE ;
     SetClock   := FALSE ;
     UTCOffset  := 0.0   ;
     KernalType := DesktopKernal ;

{
     Load Config File
}

     InAux := FALSE ;

     Assign(ConfigFile,'IPSDOS.CFG') ;
     Reset(ConfigFile) ;

     WHILE (Not Eof(ConfigFile)) DO BEGIN

          ReadLn(ConfigFile,sLine) ;
          DecodeConfig(sLine,sToken,sValue) ;

          IF (sToken<>'') THEN BEGIN
              IF (InAux) THEN BEGIN
                  IF (sToken='END') THEN BEGIN
                      OpenAux(AuxIndex) ;
                      InAux := FALSE ;
                  END
                  ELSE IF (sToken='SETTINGS') THEN BEGIN
                      WITH Aux[AuxIndex]^ DO BEGIN
                           ii := Pos(',',sValue) ;
                           BAUDRATE := WVal(Trim(Left(sValue,ii-1))) ;
                           Delete(sValue,1,ii) ;
                           ii := Pos(',',sValue) ;
                           PARITY := StoC(Trim(Left(sValue,ii-1))) ;
                           ii := Pos(',',sValue) ;
                           WORDLEN := BVal(Trim(Left(sValue,ii-1))) ;
                           Delete(sValue,1,ii) ;
                           STOPBITS := BVal(Trim(sValue)) ;
                      END ;
                  END
                  ELSE IF (sToken='RXFORMAT') THEN BEGIN
                      WITH Aux[AuxIndex]^ DO BEGIN
                          IF (sValue='P3BLK') THEN BEGIN
                              RX_FORMAT := FORMAT_P3BLK ;
                          END
                          ELSE IF (sValue='P3CMD') THEN BEGIN
                              RX_FORMAT := FORMAT_P3CMD ;
                          END
                          ELSE BEGIN
                              RX_FORMAT := FORMAT_NONE ;
                          END ;
                      END ;
                  END
                  ELSE IF (sToken='TXFORMAT') THEN BEGIN
                      WITH Aux[AuxIndex]^ DO BEGIN
                          IF (sValue='P3BLK') THEN BEGIN
                              TX_FORMAT := FORMAT_P3BLK ;
                          END
                          ELSE IF (sValue='BLK') THEN BEGIN
                              TX_FORMAT := FORMAT_BLK ;
                          END
                          ELSE BEGIN
                              TX_FORMAT := FORMAT_NONE ;
                          END ;
                      END ;
                  END ;
              END

              ELSE BEGIN
                  IF (sToken='AUX') THEN BEGIN
                      AuxIndex := BVal(sValue) ;
                      IF (AuxIndex<=MaxAuxDev) THEN BEGIN
                          InAux := TRUE ;
                      END ;
                  END
                  ELSE IF (sToken='NOBIOS') THEN BEGIN
                      IF (sValue='TRUE') THEN BEGIN
                          UseBIOS := FALSE ;
                      END ;
                  END
                  ELSE IF (sToken='SETCLOCK') THEN BEGIN
                      IF (sValue='TRUE') THEN BEGIN
                          SetClock := TRUE ;
                      END ;
                  END
                  ELSE IF (sToken='SHOWCLOCK') THEN BEGIN
                      IF (sValue='TRUE') THEN BEGIN
                          ShowClock := TRUE ;
                      END ;
                  END
                  ELSE IF (sToken='SLOWVIDEO') THEN BEGIN
                      IF (sValue='TRUE') THEN BEGIN
                          SlowVideo := TRUE ;
                      END ;
                  END
                  ELSE IF (sToken='DESKTOP-KERNAL-BIN') THEN BEGIN
                      DesktopKernalPath := sValue ;
                  END
                  ELSE IF (sToken='REMOTE-KERNAL-BIN') THEN BEGIN
                      RemoteKernalPath := sValue ;
                  END
                  ELSE IF (sToken='IPSX-KERNAL-BIN') THEN BEGIN
                      IPSXKernalPath := sValue ;
                  END
                  ELSE IF (sToken='OSCLI-CMD') THEN BEGIN
                      OSCLIPath := sValue ;
                  END
                  ELSE IF (sToken='UTC-OFFSET') THEN BEGIN
                      UTCOffset := DVal(sValue) ;
                  END
                  ELSE IF (sToken='DEFAULT-KERNAL') THEN BEGIN
                      KernalType := BVal(sValue) ;
                  END ;
              END ;

          END ;

     END ;

     Close(ConfigFile) ;

{
     Decode Command Line Parameters
     These have a higher priority than the .CFG file!
}

     FOR ii := 1 TO ParamCount DO BEGIN
         sToken := Upper(ParamStr(ii)) ;
         IF (sToken='/NOBIOS') THEN BEGIN
             UseBIOS := FALSE ;
         END
         ELSE IF (sToken='/SETCLOCK') THEN BEGIN
             SetClock := TRUE ;
         END
         ELSE IF (sToken='/SHOWCLOCK') THEN BEGIN
             ShowClock := TRUE ;
         END
         ELSE IF (sToken='/REMOTE') THEN BEGIN
             KernalType := RemoteKernal ;
         END
         ELSE IF (sToken='/X') THEN BEGIN
             KernalType := IPSXKernal ;
         END
         ELSE IF (sToken='/SLOWVIDEO') THEN BEGIN
             SlowVideo := TRUE ;
         END ;
     END ;

{
     Select Active Kernal Binary
}

     CASE KernalType OF
     RemoteKernal : KernalPath := RemoteKernalPath  ;
     IPSXKernal   : KernalPath := IPSXKernalPath    ;
     ELSE
                    KernalPath := DesktopKernalPath ;
     END ;

END. { Config }
