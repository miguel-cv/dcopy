program dcopya;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp , md5 ,dateUtils
  { you can add units after this };

type

  { dcopya }

  dcopy = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

const chunksize=65535 ;

{ dcopy }
procedure copiarchivocompleto(de,a:string);
var
  FileStreamOr, FileStreamDes, FileStreamHashes: TFileStream;
  BytesCopiados, TotalBytesCopiados, medidatiempobytescopiados,tiempo: int64;
  mb:double;
  TempBuffer : array [0..chunksize] of AnsiChar;
  HashBloque: string;
  timeblockstart,timeblockend :TDateTime   ;
  i: int64;
begin
  try
  FileStreamOr:= TFileStream.Create (de,fmShareDenyNone);
  FileStreamDes:= TFileStream.Create (a,fmCreate);
  FileStreamHashes:= TFileStream.Create(de+'.hash',fmCreate);
  finally
  end;
  FileStreamOr.Position := 0;  // Ensure you are at the start of the file
  FileStreamDes.Position:= 0;
  TotalBytesCopiados:=0;
  //writeln;
  //writeln('Tamaño archivo:',FileStreamOr.Size);
  i:=0;
  medidatiempobytescopiados:=0;
  timeblockstart := now;
  while FileStreamOr.Size > TotalBytesCopiados do  // While the amount of data read is less than or equal to the size of the stream do
  begin

       BytesCopiados := FileStreamOr.Read(TempBuffer,sizeof(TempBuffer));  // Read in chunksize of data
       inc(TotalBytesCopiados, BytesCopiados);  // Increase TotalByteRead by the size of the buffer, i.e. 4096 bytes
       //write('Bytes leídos en esta tacada:',BytesCopiados,'   ');
       //write('Bytes leídos:',TotalBytesCopiados);
       // Do something with Buffer data
       //write(Buffer);
       //write(Buffer);
       //HashBloque:=MD4Print(MD4String(TempBuffer[0]));
       HashBloque:=MD4Print(MD4Buffer(TempBuffer,chunksize+1));
       //writeln;
       //write('Hash Bloque:',HashBloque);
       FileStreamDes.Write(TempBuffer,BytesCopiados);
       FileStreamHashes.Write(HashBloque[1],32);
       //write('Copiado:',round((TotalBytesCopiados/FileStreamOr.Size)*100),chr(10));
       inc(medidatiempobytescopiados,BytesCopiados);
       inc(i);
       if (i = 512)   then
       begin
            timeblockend := now;
            mb:=(medidatiempobytescopiados/1024)/1024;
            tiempo:=(MilliSecondsBetween(timeblockend, timeblockstart));
            write(' MB: ',mb:4:1,' Tiempo: ',tiempo,' milisegundos',' Velocidad: ', (mb/(tiempo/1000)):3:2,' Total KB: ',(TotalBytesCopiados/1024):4:2);
            //Write(' Total copiado hasta el momento: ',round(TotalBytesCopiados/1024/1024),' MB',' Velocidad: ',round((medidatiempobytescopiados/(1024*1024)))/(MilliSecondsBetween(timeblockend, timeblockstart)/1000));
            write(#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8);
            i:=0 ;
            timeblockstart := now;
            medidatiempobytescopiados:=0;
       end;
       Sleep(0);
  end;
  writeln;
  writeln('Terminamos, total copiado:',round(TotalBytesCopiados/1024),' KB');
  FileStreamOr.Free;
  FileStreamDes.Free;
  FileStreamHashes.Free;

end;

procedure dcopy.DoRun;
var
  ErrorMsg: String;
  Origen,Destino: String;
  TotalBytesRead, BytesRead : Int64;
  Buffer : array [0..chunksize] of AnsiChar;  // Tamaño de cada "chunk"
  FileStream,ArchivoHashes, ArchivoDestino  : TFileStream;
  HashBloque: string;
  HashArray : array of array [0..31] of AnsiChar;
  //MaxArray : LongInt;
  i , TotalBytesCopied : LongInt;
  timeblockstart,timeblockend :TDateTime   ;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions('h','help');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h','help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  { add your program here }
  // Añadir try...finally
   Origen:=ParamStr(1);
   Destino:=ParamStr(2);
   //Añadir comprobación directorio destino, y abrir destino+nombre original.
   writeln('Origen:',Origen);
   writeln('Destino:',Destino);
   If FileExists(Destino) then //Comprobar si el tamaño es el mismo ¿y la fecha?
     begin
     //leer hashes de archivo hashes a un array
     writeln('Destino existe,leyendo archivo de hashes');
     //TODO Comprobar existencia archivo hashes, y si no llamar a copiararchivocompleto
     ArchivoHashes:= TFileStream.Create(Origen+'.hash',fmOpenReadWrite);
     ArchivoHashes.Position := 0;  // Ensure you are at the start of the file
     TotalBytesRead:=0;
     SetLength(HashArray,4095);
     //writeln('Lenght Array:',Length(HashArray));
     i:=0;
     //writeln(Origen+'.hash','-',ArchivoHashes.Size) ;
     while ArchivoHashes.Size > TotalBytesRead do
           begin
                BytesRead := ArchivoHashes.Read(HashArray[i] ,32);
                //writeln('Posición archivo hashes:',ArchivoHashes.Position);
                //write(i,'-',HashArray[i]);
                inc(i);
                inc(TotalBytesRead, BytesRead);
                //writeln('i:',i,' Total:',TotalBytesRead,' BytesRead:',BytesRead,' Tamaño:',ArchivoHashes.Size);
                if (i=(Length(HashArray)-1)) then SetLength(HashArray,(Length(HashArray)+4095));
                sleep(0);
           end;
     SetLength(HashArray,i+1);
     //writeln('Lenght Array:',Length(HashArray));
     //MaxArray:=i;
     //writeln('Archivo de Hashes leído...imprimimos,por ejemplo 1,2 y último');
     //writeln(HashArray[0],'-',HashArray[1],'-',HashArray[i-1]);
     i:=0;
     writeln('Comenzando a procesar el archivo original');
     FileStream:= TFileStream.Create (Origen,fmOpenRead);
     FileStream.Position := 0;
     TotalBytesRead:=0;
     TotalBytesCopied:=0;
     ArchivoDestino:= TFileStream.Create(Destino,fmOpenReadWrite); //Añadir no abrir hasta que haya que grabar
     while FileStream.Size > TotalBytesRead do  // While the amount of data read is less than or equal to the size of the stream do
     begin
       BytesRead := FileStream.Read(Buffer,sizeof(Buffer));  // Read in 16384 of data
       inc(TotalBytesRead, BytesRead);
       //write('Bytes leídos en esta tacada:',BytesRead,'   ');
       //write('Bytes leídos:',TotalBytesRead);
       // Do something with Buffer data
       //write(Buffer);
       //HashBloque:=MD4Print(MD4String(Buffer[0]));
       HashBloque:=MD4Print(MD4Buffer(Buffer,chunksize+1));
       //writeln;
       //writeln('Tamaño:',FileStream.Size,'- Leído:',BytesRead,'- Total leído:',TotalBytesRead);
       //writeln('Procesando bloque:',i);
       //writeln(HashBloque,'-',HashArray[i]);
       //writeln(Buffer);
       //readln;
       if HashBloque<>HashArray[i] then
       begin
       writeln('-----------Bloque distinto:',i);
       //writeln('Posición:',FileStream.Position);
       //writeln('Vamos a escribir en ',(FileStream.Position-BytesRead));
       if FileStream.Position<chunksize then ArchivoDestino.Position:=0
       else ArchivoDestino.Position:=(FileStream.Position-BytesRead);
       ArchivoDestino.Write(Buffer,BytesRead);
       inc(TotalBytesCopied,BytesRead);
       //MODIFICAR ARCHIVO HASHES
       //writeln('Posición archivohashes antes:',ArchivoHashes.Position);
       ArchivoHashes.Position:=(i*32);
       //writeln('Posición archivohashes después:',ArchivoHashes.Position);
       ArchivoHashes.Write(HashBloque[1],32);
       Sleep(0);
       end;
     inc(i);
     Sleep(0);
     end;
     writeln('Terminamos, total copiado:',round(TotalBytesCopied/1024/1024),' MB');
     ArchivoDestino.Size:=FileStream.Size;
     // TODO Cambiar tamaño archivo hashes
     FileStream.Free;
     ArchivoDestino.Free;
     ArchivoHashes.Free;
     end
     else
     begin
     writeln('Destino no existe, lo copiamos');
     copiarchivocompleto(Origen,Destino);
     end;
//try
  //FileStream:= TFileStream.Create (Origen,fmShareDenyNone);
  //FileStream.Free;
  //Terminate;
  SetLength(HashArray,0);
  writeln('fin');
  Terminate;
//finally
// stop program loop
end;



constructor dcopy.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor dcopy.Destroy;
begin
  inherited Destroy;
end;

procedure dcopy.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ',ExeName,' -h');
end;

var
  Application: dcopy;
begin
  Application:=dcopy.Create(nil);
  Application.Run;
  Application.Free;
end.
 
