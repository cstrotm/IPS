{
     This UNIT implements the DOS disk file handling sub-system.

     (c) 2001 Paul Willmott, VP9MU

     Version 1.0.0 - June 9, 2001
}

UNIT FileIO ;

{
     Public Interface
}

INTERFACE

USES

     DOS      ,
     TypeDefs ,
     Strings  ;

CONST

{
     fopen constants
}

     fm_Reset   = 0 ;
     fm_ReWrite = 1 ;
     fm_Append  = 2 ;

{
     fseek constants
}

     fs_Absolute        = 0 ; { Absolute Offset Start of File           }
     fs_OffsetCurrent   = 1 ; { Signed Offset from Current File Pointer }
     fs_OffsetEndOfFile = 2 ; { Signed Offset from End of File          }

VAR

     ferror : WORD ; { 0 = Last Operation OK, 1 = Failure }

     FUNCTION  fopen(FileName:STRING;OpenMode:WORD):WORD ;
     PROCEDURE fclose(Handle:WORD) ;
     PROCEDURE fread(Handle:WORD;VAR Buffer;VAR BufSize:WORD) ;
     FUNCTION  feof(Handle:WORD):WORD ;
     PROCEDURE fwrite(Handle:WORD;VAR Buffer;VAR BufSize:WORD) ;
     PROCEDURE fflush(Handle:WORD) ;
     PROCEDURE fseek(Handle:WORD;VAR SeekOffset:LONGINT;SeekMethod:BYTE) ;
     PROCEDURE fdelete(FileName:STRING) ;
     PROCEDURE frename(OldName,NewName:STRING) ;

{
     Hidden Implementation
}

IMPLEMENTATION

{
     ------------------------------------------------------
     NOTE: Buffered Read is not yet implemented!

           Therefore a byte by byte read of a file requires
           a dos call for each byte!
     ------------------------------------------------------
}

CONST

     MaxFile = 100 ;

TYPE

     FileType = RECORD
                      DOSHandle : WORD    ; { MSDOS File Handle                  }
                      Eof       : BYTE    ; { 1 = End of File                    }
                      SeekPtr   : LONGINT ; { Pointer to current file position   }
                END ;

VAR

     FileList : ARRAY [1..MaxFile] OF ^FileType ;

     ExitSave : POINTER ; { Pointer to Next ExitProc }
     Index    : WORD    ; { Used by Init and Exit Procs ONLY! }

{
     ----------------------------------------------------------------------------------------
     REFERENCE: Advanced MS-DOS Programming 2nd Ed, Ray Duncan, Microsoft Press 1988
                ISBN: 1-55615-157-8
     ----------------------------------------------------------------------------------------
}

{
     _fopen support constants
     ------------------------
}

CONST

{
     OpenMode Constants
}

     ReadOnly  : WORD = 0 ;
     WriteOnly : WORD = 1 ;
     ReadWrite : WORD = 2 ;

{
     File Attribute Constants
}

     Normal : WORD = 0 ;

{
     Open Flag Constants <- OR Together!
}

     Extant_Fail      = $0000 ;
     Extant_Open      = $0001 ;
     Extant_Replace   = $0002 ;
     NotExtant_Fail   = $0000 ;
     NotExtant_Create = $0010 ;


VAR

     _ferror : WORD ;



{
     ********************************************
     These are the primitives that talk to MS-DOS
     ********************************************
}

{
     This routine opens, creates or replaces the specified file. Returns
     a handle that can be used by the program for subsequent access to the
     file.

     Note: DOS 4.0 onwards!
}

FUNCTION  _fopen(FileName:STRING;OpenMode,FileAttribute,OpenFlag:WORD):WORD ;
VAR
     RegPack : Registers ;
BEGIN
     WITH RegPack DO BEGIN
         AH := $6c ;
         AL := $00 ;
         BX := OpenMode ;
         CX := FileAttribute ;
         DX := OpenFlag ;
         FileName := Trim(FileName) + #000 ;
         DS := Seg(FileName[1]) ;
         SI := Ofs(FileName[1]) ;
         MsDOS(RegPack) ;
         IF (FLAGS AND FCarry = 0) THEN BEGIN
             _fopen := AX ;
             AX := $0 ;
         END ;
         _ferror := AX ;
     END ;
END { _fopen } ;

{
     This routine flushes all internal buffers associated with
     the file to disk, closes the file, and releases the handle
     for reuse. If the file was modified, the time and date
     stamp and file size are updated in the file's directory
     entry.
}

PROCEDURE _fclose(Handle:WORD) ;
VAR
     RegPack : Registers ;
BEGIN
     WITH RegPack DO BEGIN
         AH := $3e ;
         BX := Handle ;
         MsDOS(RegPack) ;
         IF (FLAGS AND FCarry = 0) THEN BEGIN
             AX := $0 ;
         END ;
         _ferror := AX ;
     END ;
END { _fclose } ;

{
     This routine transfers a block of data, at the current file
     pointer position, from the disk file associated with the
     specified handle into the buffer and then updates the file
     pointer position.
}

PROCEDURE _fread(Handle:WORD;VAR Buffer;VAR BufSize:WORD) ;
VAR
     RegPack : Registers ;
BEGIN
     WITH RegPack DO BEGIN
         AH := $3f ;
         BX := Handle ;
         CX := BufSize ;
         DS := Seg(Buffer) ;
         DX := Ofs(Buffer) ;
         MsDOS(RegPack) ;
         IF (FLAGS AND FCarry = 0) THEN BEGIN
             BufSize := AX ;
             AX := $0 ;
         END
         ELSE BEGIN
             BufSize := $0 ;
         END ;
         _ferror := AX ;
     END ;
END { _fread } ;

{
     This routine writes a block of data from the buffer into the
     file specified by the handle, and then updates the file
     pointer position.
}

PROCEDURE _fwrite(Handle:WORD;VAR Buffer;VAR BufSize:WORD) ;
VAR
     RegPack : Registers ;
BEGIN
     WITH RegPack DO BEGIN
         AH := $40 ;
         BX := Handle ;
         CX := BufSize ;
         DS := Seg(Buffer) ;
         DX := Ofs(Buffer) ;
         MsDOS(RegPack) ;
         IF (FLAGS AND FCarry = 0) THEN BEGIN
             BufSize := AX ;
             AX := $0 ;
         END
         ELSE BEGIN
             BufSize := $0 ;
         END ;
         _ferror := AX ;
     END ;
END { _fwrite } ;

{
     This routine forces all data in MS-DOS's internal buffers
     associated with the specified handle to be physically
     written to the disk, the time and date stamp and file
     size in the file's directory entry are updated. It is
     equivalent to closing then re-opening the file, with the
     benefit of not changing the file handle value.
}

PROCEDURE _fflush(Handle:WORD) ;
VAR
     RegPack : Registers ;
BEGIN
     WITH RegPack DO BEGIN
         AH := $68 ;
         BX := Handle ;
         MsDOS(RegPack) ;
         IF (FLAGS AND FCarry = 0) THEN BEGIN
             AX := $0 ;
         END ;
         _ferror := AX ;
     END ;
END { _fflush } ;

{
     This routine sets the file location pointer relative to
     the start of the file, end of file, or current file
     position.
}

PROCEDURE _fseek(Handle:WORD;VAR SeekOffset:LONGINT;SeekMethod:BYTE) ;
VAR
     RegPack : Registers ;
BEGIN
     WITH RegPack DO BEGIN
         AH := $42 ;
         AL := SeekMethod ;
         BX := Handle ;
         CX := DWordRecType(SeekOffset).Hi ;
         DX := DWordRecType(SeekOffset).Lo ;
         MsDOS(RegPack) ;
         IF (FLAGS AND FCarry = 0) THEN BEGIN
             DWordRecType(SeekOffset).Hi := DX ;
             DWordRecType(SeekOffset).Lo := AX ;
             AX := $0 ;
         END ;
         _ferror := AX ;
     END ;
END { _fseek } ;

{
     This routine deletes the specified file.
}

PROCEDURE fdelete(FileName:STRING) ;
VAR
     RegPack : Registers ;
BEGIN
     WITH RegPack DO BEGIN
         AH := $41 ;
         FileName := Trim(FileName) + #000 ;
         DS := Seg(FileName[1]) ;
         DX := Ofs(FileName[1]) ;
         MsDOS(RegPack) ;
         IF (FLAGS AND FCarry = 0) THEN BEGIN
             ferror := 0 ;
         END
         ELSE BEGIN
             ferror := 1 ;
         END ;
     END ;
END { fdelete } ;

{
     This routine renames and/or moves a file or directory to
     a different directory on the same disk drive.
}

PROCEDURE frename(OldName,NewName:STRING) ;
VAR
     RegPack : Registers ;
BEGIN
     WITH RegPack DO BEGIN
         AH := $56 ;
         OldName := Trim(OldName) + #000 ;
         DS := Seg(OldName[1]) ;
         DX := Ofs(OldName[1]) ;
         NewName := Trim(NewName) + #000 ;
         ES := Seg(NewName[1]) ;
         DI := Ofs(NewName[1]) ;
         MsDOS(RegPack) ;
         IF (FLAGS AND FCarry = 0) THEN BEGIN
             ferror := 0 ;
         END
         ELSE BEGIN
             ferror := 1 ;
         END ;
     END ;
END { frename } ;

{
     **************************************
     These are the simplified routines that
     are called by IPSDOS Virtual Machine
     **************************************
}

{
     This routine opens a file in one of 3 modes:

     Reset   - Read Only, the open will fail if the file does not exist.
               The file pointer is placed at the beginning of the file.

     ReWrite - Read/Write, creates a file, if the file exists it is replaced.

     Append  - Read/Write, creates a file, if the file exists then it is
               opened and the file pointer placed at end of file.
}

FUNCTION fopen ;
VAR
     Handle      : WORD ;
     DOSOpenMode : WORD ;
     DOSOpenFlag : WORD ;
     SeekMethod  : WORD ;
BEGIN

     Handle := 1 ;

     WHILE (0<Handle) AND (Handle<=MaxFile) DO BEGIN

         IF (FileList[Handle]=NIL) THEN BEGIN

             New(FileList[Handle]) ;

             WITH FileList[Handle]^ DO BEGIN
                 CASE OpenMode OF
                 fm_Reset  : BEGIN
                                  DOSOpenMode      := ReadOnly ;
                                  DOSOpenFlag      := Extant_Open OR NotExtant_Fail ;
                             END ;
                 fm_Append : BEGIN
                                  DOSOpenMode      := ReadWrite ;
                                  DOSOpenFlag      := Extant_Open OR NotExtant_Create ;
                             END ;
                 ELSE { fm_Rewrite }
                                  DOSOpenMode      := ReadWrite ;
                                  DOSOpenFlag      := Extant_Replace OR NotExtant_Create ;
                 END ;
                 DOSHandle := _fopen(FileName,DOSOpenMode,Normal,DOSOpenFlag) ;
             END ;

             IF (_ferror=0) THEN BEGIN

                 fopen := Handle ;
                 ferror := 0 ;

                 WITH FileList[Handle]^ DO BEGIN

                     CASE OpenMode OF
                     fm_Reset  : BEGIN
                                      SeekMethod := fs_Absolute ;
                                 END ;
                     fm_Append : BEGIN
                                      SeekMethod := fs_OffsetEndOfFile ;
                                 END ;
                     ELSE { fm_Rewrite }
                                      SeekMethod := fs_Absolute ;
                     END ;

                     SeekPtr := 0 ;
                     _fseek(DOSHandle,SeekPtr,SeekMethod) ;

                     Eof := 0 ; { Eof is controlled by fread }

                 END ;

             END
             ELSE BEGIN
                 Dispose(FileList[Handle]) ;
                 FileList[Handle] := NIL ;
                 ferror := 1 ;
             END ;

             Exit ;

         END ;

         Inc(Handle) ;

     END ;

     ferror := 1 ;

END { fopen } ;

{
     This routine closes the specified open file, and re-allocates
     associated memory.
}

PROCEDURE fclose(Handle:WORD) ;
BEGIN
     IF ((Handle<1) OR (Handle>MaxFile)) OR (FileList[Handle]=NIL) THEN BEGIN
         ferror := 1 ;
     END
     ELSE BEGIN
         _fclose(FileList[Handle]^.DOSHandle) ;
         IF (_ferror=0) THEN BEGIN
             ferror := 0 ;
         END
         ELSE BEGIN
             ferror := 1 ;
         END ;
         Dispose(FileList[Handle]) ;
         FileList[Handle] := NIL ;
     END ;
END { fclose } ;

{
     This routine transfers a block of data, at the current file
     pointer position, from the disk file associated with the
     specified handle into the buffer and then updates the file
     pointer position.
}

PROCEDURE fread(Handle:WORD;VAR Buffer;VAR BufSize:WORD) ;
VAR
     ReqBufSize : WORD ;
BEGIN

     IF ((Handle<1) OR (Handle>MaxFile)) OR (FileList[Handle]=NIL) THEN BEGIN
         BufSize := 0 ;
         ferror := 1 ;
     END
     ELSE BEGIN

         WITH FileList[Handle]^ DO BEGIN
             ReqBufSize := BufSize ;
             _fread(DOSHandle,Buffer,BufSize) ;
             IF (_ferror=0) THEN BEGIN
                 IF (BufSize=ReqBufSize) THEN BEGIN
                     Eof := 0 ;
                 END
                 ELSE BEGIN
                     Eof := 1 ;
                 END ;
                 ferror := 0 ;
             END
             ELSE BEGIN
                 ferror := 1 ;
             END ;
         END ;

     END ;

END { fread } ;

{
     This routine returns 1 if there is no more data to be
     read from the specified file. This is based upon the
     last read.
}

FUNCTION feof(Handle:WORD):WORD ;
BEGIN

     IF ((Handle<1) OR (Handle>MaxFile)) OR (FileList[Handle]=NIL) THEN BEGIN
         ferror := 1 ;
     END
     ELSE BEGIN

         WITH FileList[Handle]^ DO BEGIN
             feof := Eof ;
             ferror := 0 ;
         END ;

     END ;

END { feof } ;

{
     This routine writes a block of data from the buffer into the
     file specified by the handle, and then updates the file
     pointer position.
}

PROCEDURE fwrite(Handle:WORD;VAR Buffer;VAR BufSize:WORD) ;
VAR
     ReqBufSize : WORD ;
BEGIN

     IF ((Handle<1) OR (Handle>MaxFile)) OR (FileList[Handle]=NIL) THEN BEGIN
         BufSize := 0 ;
         ferror := 1 ;
     END
     ELSE BEGIN

         WITH FileList[Handle]^ DO BEGIN
             ReqBufSize := BufSize ;
             _fwrite(DOSHandle,Buffer,BufSize) ;
             IF (_ferror=0) THEN BEGIN
                 IF (BufSize=ReqBufSize) THEN BEGIN
                     Eof := 0 ;
                 END
                 ELSE BEGIN
                     Eof := 1 ;
                 END ;
                 ferror := 0 ;
             END
             ELSE BEGIN
                 ferror := 1 ;
             END ;
         END ;

     END ;

END { fwrite } ;

{
     This routine forces all data in MS-DOS's internal buffers
     associated with the specified handle to be physically
     written to the disk, the time and date stamp and file
     size in the file's directory entry are updated. It is
     equivalent to closing then re-opening the file, with the
     benefit of not changing the file handle value.
}

PROCEDURE fflush(Handle:WORD) ;
BEGIN

     IF ((Handle<1) OR (Handle>MaxFile)) OR (FileList[Handle]=NIL) THEN BEGIN
         ferror := 1 ;
     END
     ELSE BEGIN

         WITH FileList[Handle]^ DO BEGIN
             _fflush(DOSHandle) ;
             IF (_ferror=0) THEN BEGIN
                 ferror := 0 ;
             END
             ELSE BEGIN
                 ferror := 1 ;
             END ;
         END ;

     END ;
END { fflush } ;

{
     This routine sets the file location pointer relative to
     the start of the file, end of file, or current file
     position.
}

PROCEDURE fseek(Handle:WORD;VAR SeekOffset:LONGINT;SeekMethod:BYTE) ;
BEGIN

     IF ((Handle<1) OR (Handle>MaxFile)) OR (FileList[Handle]=NIL) THEN BEGIN
         ferror := 1 ;
     END
     ELSE BEGIN

         WITH FileList[Handle]^ DO BEGIN

             SeekPtr := SeekOffset ;
             _fseek(DOSHandle,SeekPtr,SeekMethod) ;

             IF (_ferror=0) THEN BEGIN
                 SeekOffset := SeekPtr ;
                 ferror := 0 ;
             END
             ELSE BEGIN
                 ferror := 1 ;
             END ;
         END ;

     END ;

END { fseek } ;

{
     Tidy-Up and De-Allocate dynamic variables
}

PROCEDURE MyExit ;
BEGIN

{
     Pass Control to Next Exit Procedure <- Always First!
}

     ExitProc := ExitSave ;

{
     Close Open Files
}

     Index := MaxFile ;
     WHILE (0<Index) DO BEGIN
         fclose(Index) ;
         Dec(Index) ;
     END ;

END ;

{
     Initialization
}

BEGIN

{
     Initialize File List
}

     FOR Index := 1 TO MaxFile DO BEGIN
         FileList[Index] := NIL ;
     END ;

{
     Link Exit Procedure
}

     ExitSave := ExitProc ;
     ExitProc := @MyExit ;

END. { FileIO }
