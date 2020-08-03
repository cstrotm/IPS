{
     Turbo Pascal 5.5 Implementation Features
     ----------------------------------------
}

UNIT TypeDefs ;

INTERFACE

{
     ------------------------------------------------------------------------
     Turbo Pascal 5.5 defines the following standard data types:

     BYTE      Unsigned 8-Bit              (1 byte )
     INTEGER   Signed 16-Bit 2s Complement (2 bytes)
     WORD      Unsigned 16-Bit             (2 bytes)
     LONGINT   Signed 32-Bit 2s Complement (4 bytes)

     DOUBLE    IEEE Double Precision Real 5.0e-324 to 1.7e308
               15 to 16 significant digits (8 bytes)
     ------------------------------------------------------------------------
}

TYPE

{
     WORD and DWORD data types for type-casting purposes.
     Turbo Pascal allows you to type-cast between any two types
     provided that they have the same number of bytes. These
     user definied data types allow easy access to the MSB/W 
     and LSB/W of the INTEGER/WORD and LONGINT standard data 
     types.
}

     WordRecType = RECORD
         Lo : BYTE ;
         Hi : BYTE ;
     END ;

     DWordRecType = RECORD
         Lo : WORD ;
         Hi : WORD ;
     END ;

IMPLEMENTATION

END. { TypeDefs }

