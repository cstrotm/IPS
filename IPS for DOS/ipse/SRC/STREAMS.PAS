{
     This UNIT implements the high level access to the serial
     I/O hardware, this is called by the 20ms Pusedo Interrupt
     service routines. 

     (c) 2001 Paul Willmott, VP9MU

     Version 1.0.0 - June 5, 2001
}

UNIT Streams ;

{
     Public Interface
}

INTERFACE

USES

     AuxIO  ,
     Config ,
     Engine ;

VAR

     RXStreams : ARRAY[1..MaxAuxDevices] OF PROCEDURE(AuxIndex:BYTE) ;
     TXStreams : ARRAY[1..MaxAuxDevices] OF PROCEDURE(AuxIndex:BYTE) ;

{
     Hidden Implementation
}

IMPLEMENTATION

{$F+}

CONST

     SyncVector : ARRAY[0..3] OF BYTE = ($39,$15,$ED,$30) ;

     _400BPSTimeOut = 2 ;

VAR

     CmdBufCount   : WORD ;
     Index         : BYTE ;
     TXPtr         : WORD ;
     P3TLMBufCount : WORD ;

     TimeOut : ARRAY[1..MaxAuxDevices] OF BYTE ;

PROCEDURE RX_Stream_NONE(AuxIndex:BYTE) ;
BEGIN
END { RX_Stream_NONE } ;

PROCEDURE TX_Stream_NONE(AuxIndex:BYTE) ;
BEGIN
(*     WITH Aux[AuxIndex]^ DO BEGIN
          WHILE (OBufCount>0) DO BEGIN
              AuxOutChar(AuxIndex) ;
          END ;
     END ; *)
END { TX_Stream_NONE } ;

PROCEDURE RX_Stream_P3BLK(AuxIndex:BYTE) ;
VAR
     InChar  : BYTE ;
     BufAddr : WORD ;
BEGIN

     IF (TimeOut[AuxIndex]=0) THEN BEGIN
         P3TLMBufCount := 0 ;
     END
     ELSE BEGIN
         Dec(TimeOut[AuxIndex]) ;
     END ;

     IF (PeekB(P3TLM_INFLAG)=1) THEN BEGIN

         PokeB(P3TLM_DATA_IN,0) ;

         WITH Aux[AuxIndex]^ DO BEGIN
             BufAddr := PeekW(P3TLM_BUFADDR) ;
             WHILE (P3TLMBufCount<514) AND (IBufCount>0) DO BEGIN
                 InChar := GetAuxIn(AuxIndex) ;
                 PokeB(BufAddr+P3TLMBufCount,InChar) ;
                 Inc(P3TLMBufCount) ;
                 TimeOut[AuxIndex] := _400BPSTimeOut ;
             END ;
         END ;

         IF (P3TLMBufCount=514) THEN BEGIN
             PokeB(P3TLM_INFLAG,0) ;
             PokeB(P3TLM_DATA_IN,1) ;
             P3TLMBufCount := 0 ;
             TimeOut[AuxIndex] := _400BPSTimeOut ;
         END ;

     END ;

END { RX_Stream_P3BLK } ;

PROCEDURE TX_Stream_P3BLK(AuxIndex:BYTE) ;
VAR
     _TZ     : BYTE ;
     OutChar : BYTE ;
BEGIN
     _TZ := PeekB(TZ) ;
     IF (_TZ=0) THEN BEGIN
         TXPtr := EBU-5 ;
     END
     ELSE IF (_TZ=30) THEN BEGIN
         Inc(TXPtr) ;
         IF (TXPtr=EBU+513) THEN BEGIN
             Dec(_TZ) ;
         END ;
     END
     ELSE BEGIN
         Dec(_TZ) ;
         TXPtr := EBU-5 ;
     END ;
     PutAuxOut(AuxIndex,PeekB(TXPtr)) ;
     PokeB(TZ,_TZ) ;
END { TX_Stream_P3BLK } ;

PROCEDURE RX_Stream_BLK(AuxIndex:BYTE) ;
BEGIN
END { RX_Stream_BLK } ;

PROCEDURE TX_Stream_BLK(AuxIndex:BYTE) ;
VAR
     _TZ     : BYTE ;
BEGIN
     _TZ := PeekB(TZ) ;
     IF (_TZ=0) THEN BEGIN
         TXPtr := EBU ;
     END
     ELSE IF (_TZ=30) THEN BEGIN
         PutAuxOut(AuxIndex,PeekB(TXPtr)) ;
         Inc(TXPtr) ;
         IF (TXPtr=EBU+514) THEN BEGIN
             Dec(_TZ) ;
         END ;
     END
     ELSE BEGIN
         TXPtr := EBU ;
         Dec(_TZ) ;
     END ;
     PokeB(TZ,_TZ) ;
END { TX_Stream_BLK } ;

PROCEDURE RX_Stream_P3CMD(AuxIndex:BYTE) ;
VAR
     InChar : BYTE ;
BEGIN
     IF (PeekB(INFLAG)=1) THEN BEGIN
         WITH Aux[AuxIndex]^ DO BEGIN
             WHILE (CmdBufCount<516) AND (IBufCount>0) DO BEGIN
                 InChar := GetAuxIn(AuxIndex) ;
                 IF (CmdBufCount<4) AND (InChar<>SyncVector[CmdBufCount]) THEN BEGIN
                     CmdBufCount := 0 ;
                 END
                 ELSE BEGIN
                     IF (CmdBufCount>3) THEN BEGIN { Only Transfer Data to RBU }
                         PokeB(RBU+CmdBufCount-4,InChar) ;
                     END ;
                     Inc(CmdBufCount) ;
                 END ;
             END ;
         END ;
         IF (CmdBufCount=516) THEN BEGIN
             PokeB(INFLAG,0) ;
             PokeB(DATA_IN,1) ;
         END ;
     END ;

END { RX_Stream_P3CMD } ;

{
     Initialization
}

BEGIN

{
     Set to Service Routine or NO-OP
}

     IF (KernalType<>IPSXKernal) THEN BEGIN

         FOR Index := 1 TO MaxAuxDevices DO BEGIN
             IF (Index<=MaxAuxDev) THEN BEGIN
                 WITH Aux[Index]^ DO BEGIN
                     CASE RX_FORMAT OF
                     FORMAT_BLK   : RXStreams[Index] := RX_Stream_BLK   ;
                     FORMAT_P3BLK : RXStreams[Index] := RX_Stream_P3BLK ;
                     FORMAT_P3CMD : RXStreams[Index] := RX_Stream_P3CMD ;
                     ELSE
                                    RXStreams[Index] := RX_Stream_NONE  ;
                     END ;
                     CASE TX_FORMAT OF
                     FORMAT_BLK   : TXStreams[Index] := TX_Stream_BLK   ;
                     FORMAT_P3BLK : TXStreams[Index] := TX_Stream_P3BLK ;
                     ELSE
                                    TXStreams[Index] := TX_Stream_NONE  ;
                     END ;
                 END ;
                 TimeOut[Index] := 0 ;
             END
             ELSE BEGIN
                 RXStreams[Index] := RX_Stream_NONE ;
                 TXStreams[Index] := TX_Stream_NONE ;
             END ;
         END ;

         CmdBufCount := 0 ;
         PokeB(TZ,0) ;
         P3TLMBufCount := 0 ;
     END ;

END. { Streams }

