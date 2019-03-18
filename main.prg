/*        IDE: ooHGIDE+
*        Item: main.prg
* Description: Utility for convert DBF to script sql for Firebird 2.0'
*      Author: A/P Paola Bruccoleri
*       Email: pbruccoleri@adinet.com.uy - San José de Mayo - URUGUAY
*        Date: 2008.02.14
*/

#include 'minigui.ch'
#include 'dbstruct.ch'
#include "FileIO.ch"

#DEFINE SALTO          Chr(13)+Chr(10)
#DEFINE TABULADOR      Chr(9)

*------------------------------------------------------*
Function Main()
*------------------------------------------------------*
REQUEST DBFCDX, DBFFPT
RDDSETDEFAULT( "DBFCDX" )

REQUEST HB_CODEPAGE_ESWIN
HB_SETCODEPAGE("ESWIN")

REQUEST HB_LANG_ES
HB_LANGSELECT("ES")

LOAD WINDOW frmMain
ACTIVATE WINDOW frmMain
RETURN


//--------------------------------------------------------------------------------------------
STATIC FUNCTION FindFile(oWin)
//--------------------------------------------------------------------------------------------
LOCAL cArch
cArch := GETFILE({{'File .Dbf (*.dbf)','*.dbf'}},'Select file...',,.F.,.T.)

if !Empty(cArch)
   oWin:archivodbf_txb:value:= cArch
endif
RETURN nil


//--------------------------------------------------------------------------------------------
STATIC FUNCTION ConvertToSql(oWin)
//--------------------------------------------------------------------------------------------
LOCAL cArchivo, aStru, i, cSqlCreate, cSqlDatos, cSqlCampos, nHandle

if Empty(oWin:archivodbf_txb:value)
   MsgInfo('You must choose a file to convert or press Cancel','Warning')
   oWin:buscararch_btn:SetFocus()
else
   cArchivo:= alltrim(oWin:archivodbf_txb:value)
   USE (cArchivo) NEW alias archivo

   // table create
   cSqlCreate:='SET NAMES NONE;'+SALTO
   cSqlCreate+= "CONNECT 'c:\camino\archivo.fdb' USER 'SYSDBA' PASSWORD 'masterkey';"+SALTO 
   
   cSqlCreate+= 'CREATE TABLE '+NomArch(cArchivo) + ' ('+ SALTO

   aStru := archivo->(Dbstruct())

   for i:= 1 to LEN(aStru)
     cSqlCreate += TABULADOR+aStru[i,DBS_NAME]+' '
     DO CASE
        CASE aStru[i,DBS_TYPE] = 'C'
              cSqlCreate+= 'varchar('+alltrim(str(aStru[i,DBS_LEN]))+')' 
        CASE aStru[i,DBS_TYPE] = 'N'
              if aStru[i,DBS_DEC] > 0
                cSqlCreate+= 'numeric('+alltrim(str(aStru[i,DBS_LEN]))+','+alltrim(str(aStru[i,DBS_DEC]))+')'
              else
                cSqlCreate+= 'integer'
              endif  
        CASE aStru[i,DBS_TYPE] = 'D'
              cSqlCreate+= 'date' 
        CASE aStru[i,DBS_TYPE] = 'L'
              cSqlCreate+= 'char(1)' 
        CASE aStru[i,DBS_TYPE] = 'M'
              cSqlCreate+= 'blob'
     ENDCASE  

      if i < LEN(aStru)       
         cSqlCreate+= ','+SALTO  // , exception de last
      else
         cSqlCreate+= SALTO
      endif
   next
   cSqlCreate += ');'

   // the data
   cSqlCampos:= 'INSERT INTO '+NomArch(cArchivo)+' ('
   for i:= 1 to LEN(aStru)
      cSqlCampos+= aStru[i,DBS_NAME]

      if i < LEN(aStru)       
         cSqlCampos+= ','  // , exception de last
      endif
   next   
   cSqlCampos+= ') VALUES (' 
   
   cSqlDatos:= ''
   archivo->(DbGoTop())
   While !archivo->(Eof())
      cSqlDatos+= cSqlCampos     
      for i:= 1 to LEN(aStru)
         cCampo:= aStru[i,DBS_NAME]
         DO CASE
            CASE aStru[i,DBS_TYPE] = 'C' .or. aStru[i,DBS_TYPE] = 'M' 
                cSqlDatos+= "'"+ alltrim(HB_OEMTOANSI(archivo->&cCampo)) +"'" 
            CASE aStru[i,DBS_TYPE] = 'N'
                cSqlDatos+= alltrim(str(archivo->&cCampo))
            CASE aStru[i,DBS_TYPE] = 'D'
                if Empty(archivo->&cCampo)
                  cSqlDatos+= 'NULL'               
                else            
                  cSqlDatos+= "'"+ FormatDate(archivo->&cCampo) + "'"
                endif   
            CASE aStru[i,DBS_TYPE] = 'L'
                cSqlDatos+= "'"+ if(archivo->&cCampo,'S','N') + "'" 
         ENDCASE  
         if i < LEN(aStru)       
            cSqlDatos+= ','  // , exception the last
         endif
      next
      cSqlDatos+= ');'+SALTO
      archivo->(DbSkip())    
   End
   archivo->(DbCloseArea())

   cSqlDatos+= SALTO+'COMMIT WORK;'+SALTO

   // name of file (extension .sql)
   cNom:= NomArch(cArchivo)+'.sql'

   nHandle := FCreate( cNom, FC_NORMAL )
   FWrite(nHandle, cSqlCreate)
   FWrite(nHandle, SALTO)
   FWrite(nHandle, SALTO)
   FWrite(nHandle, cSqlDatos)
   FClose(nHandle)

   MsgInfo('Finalized process','Alert')
   
   frmMain.Release

endif
RETURN nil


//----------------------------------------------------------------------------
FUNCTION FormatDate(dFecha)
//----------------------------------------------------------------------------
/* dada una variable tipo fecha devuelve un string con este formato:
   AAAA-MM-DD.
   Dicho formato es necesario para las consultas de firebird
*/
RETURN substr(dtos(dFecha),1,4)+'-'+substr(dtos(dFecha),5,2)+'-'+substr(dtos(dFecha),7,2)


//----------------------------------------------------------------------------
FUNCTION NomArch (cArchivo)
//----------------------------------------------------------------------------
// return the name of file whithout extension and route
LOCAL nPos, cRet
if (nPos:= RAT("\", cArchivo) ) <> 0
  cRet:= substr(cArchivo, nPos+1)
else
  cRet:= cArchivo
endif

cRet:= substr(cRet, 1, LEN(cRet)-4)

RETURN cRet
