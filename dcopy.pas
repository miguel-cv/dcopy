program dcopya;

{$mode objfpc}{$H+}

uses {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Classes,
  SysUtils,
  CustApp,
  md5,
  dateUtils;

var

  chunksize: integer = 65536;

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


  { dcopy }
  procedure copiarchivocompleto(const de, a: string);
  var
    FileStreamOr, FileStreamDes, FileStreamHashes: TFileStream;
    BytesCopiados, TotalBytesCopiados, medidatiempobytescopiados: int64;
    mb: double;
    TempBuffer: array of ansichar;
    HashBloque: string;
    timeblockstart, timeblockend, tiempo, totaltime: TDateTime;
    k: int64;
  begin
    SetLength(TempBuffer, chunksize);
    try
      FileStreamOr := TFileStream.Create(de, fmShareDenyNone);
      FileStreamDes := TFileStream.Create(a, fmCreate);
      FileStreamHashes := TFileStream.Create(de + '.hash', fmCreate);
    finally
    end;
    FileStreamOr.Position := 0;
    FileStreamDes.Position := 0;
    TotalBytesCopiados := 0;
    k := 0;
    medidatiempobytescopiados := 0;
    timeblockstart := now;
    totaltime := now;
    while FileStreamOr.Size > TotalBytesCopiados do
      // While the amount of data read is less than or equal to the size of the stream do
    begin
      BytesCopiados := FileStreamOr.Read(TempBuffer[0], chunksize);
      // Read in chunksize of data
      Inc(TotalBytesCopiados, BytesCopiados);
      HashBloque := MD4Print(MD4Buffer(TempBuffer[0], BytesCopiados));
      //write('Hash Bloque:',HashBloque);
      FileStreamDes.Write(TempBuffer[0], BytesCopiados);
      FileStreamHashes.Write(HashBloque[1], 32);
      //write('Copiado:',round((TotalBytesCopiados/FileStreamOr.Size)*100),chr(10));
      Inc(medidatiempobytescopiados, BytesCopiados);
      Inc(k);
      if (k = 512) then
      begin
        timeblockend := now;
        mb := (medidatiempobytescopiados / 1024) / 1024;
        tiempo := (MilliSecondsBetween(timeblockend, timeblockstart));
        Write('MB: ', mb: 4: 1, ' Tiempo: ', tiempo: 4: 1, ' milisegundos',
          ' Velocidad: ',
          (mb / (tiempo / 1000)): 3: 2, ' Total KB: ',
          (TotalBytesCopiados / 1024): 8: 1);
        //Write(' Total copiado hasta el momento: ',round(TotalBytesCopiados/1024/1024),' MB',' Velocidad: ',round((medidatiempobytescopiados/(1024*1024)))/(MilliSecondsBetween(timeblockend, timeblockstart)/1000));
        Write(StringOfChar(#8, 80));
        k := 0;
        timeblockstart := now;
        medidatiempobytescopiados := 0;
      end;
      Sleep(0);
    end;
    writeln;
    writeln('Tiempo total:', MilliSecondsBetween(now, totaltime) / 1000: 4: 1);
    writeln('Terminamos, total copiado:', round(TotalBytesCopiados / 1024), ' KB');
    { TODO : Comprobar tiempo 0 }
    //writeln('Velocidad media:', round(TotalBytesCopiados / 1024) /
    //  (MilliSecondsBetween(now, totaltime) / 1000): 4: 1, ' MB/s');
    { TODO : ¿Mover esto más arriba, antes de imprimir los mensajes? }
    SetLength(TempBuffer, 0);
    FileStreamOr.Free;
    FileStreamDes.Free;
    FileStreamHashes.Free;

  end;

  //------------------------------




  //------------------------------

  procedure copiarchivoconhash(const de, a: string);

  var

    TotalBytesRead, BytesRead, medidatiempobytescopiados: int64;
    Buffer: array of AnsiChar;  // Tamaño de cada "chunk"
    FileStream, ArchivoHashes, ArchivoDestino: TFileStream;
    HashBloque: string;
    HashArray: array of array [0..31] of AnsiChar;
    //MaxArray : LongInt;
    i, k, TotalBytesCopied: longint;
    timeblockstart, timeblockend, totaltime, tiempo: TDateTime;
    mb: double;
  begin

    //leer hashes de archivo hashes a un array
    //TODO Comprobar existencia archivo hashes, y si no llamar a copiararchivocompleto
    ArchivoHashes := TFileStream.Create(de + '.hash', fmOpenReadWrite);
    ArchivoHashes.Position := 0;  // Ensure you are at the start of the file
    TotalBytesRead := 0;
    SetLength(Buffer, chunksize);
    SetLength(HashArray, 4096);
    i := 0;
    writeln('Leyendo archivo con los hashes:', de + '.hash', ' -',
      (ArchivoHashes.Size / 1024): 8: 1, ' KB');
    while ArchivoHashes.Size > TotalBytesRead do
    begin
      BytesRead := ArchivoHashes.Read(HashArray[i], 32);
      //writeln('Posición archivo hashes:',ArchivoHashes.Position);
      //write(i,'-',HashArray[i]);
      Inc(i);
      Inc(TotalBytesRead, BytesRead);
      //writeln('i:',i,' Total:',TotalBytesRead,' BytesRead:',BytesRead,' Tamaño:',ArchivoHashes.Size);
      if (i = (Length(HashArray) - 1)) then
        SetLength(HashArray, (Length(HashArray) + 4096));
      { TODO : Comprobar si es igual de rápido añadir de 1 en 1 en vez de 4095 }
      sleep(0);
    end;
    SetLength(HashArray, i + 1);
    // Recordar que el 1er elemento del array es el 0
    i := 0;
    writeln('Comenzando a procesar el archivo original');
    FileStream := TFileStream.Create(de, fmOpenRead);
    { TODO : IMPORTANTE COMPROBAR ESTADO APERTURA}
    FileStream.Position := 0;
    TotalBytesRead := 0;
    TotalBytesCopied := 0;
    totaltime := now;
    ArchivoDestino := TFileStream.Create(a, fmOpenReadWrite);
    { TODO : IMPORTANTE COMPROBAR ESTADO APERTURA}
    //Añadir no abrir hasta que haya que grabar
    while FileStream.Size > TotalBytesRead do
      // While the amount of data read is less than or equal to the size of the stream do
    begin
      BytesRead := FileStream.Read(Buffer[0], chunksize);
      // Read in lenght "chunk" of data
      Inc(TotalBytesRead, BytesRead);
      HashBloque := MD4Print(MD4Buffer(Buffer[0], chunksize));
      //HashBloque := MD4Print(MD4Buffer(Buffer, Length(Buffer)));
            Write(StringOfChar(#8, 80));
      write('Procesando bloque:',i);
      //writeln(HashBloque,'-',HashArray[i]);
      //writeln(Buffer);
      if HashBloque <> HashArray[i] then
      begin
        Write(StringOfChar(#8, 80));
        Write('-----------Bloque distinto:', i);
        //writeln('Posición:',FileStream.Position);
        //writeln('Vamos a escribir en ',(FileStream.Position-BytesRead));
        if FileStream.Position < chunksize then
          ArchivoDestino.Position := 0
        else
          ArchivoDestino.Position := (FileStream.Position - BytesRead);
        ArchivoDestino.Write(Buffer, BytesRead);
        Inc(TotalBytesCopied, BytesRead);
        //writeln('Posición archivohashes antes:',ArchivoHashes.Position);
        ArchivoHashes.Position := (i * 32);
        //writeln('Posición archivohashes después:',ArchivoHashes.Position);
        ArchivoHashes.Write(HashBloque[1], 32);
        Sleep(0);
      end;
      Inc(i);
   {   k:=0;
      writeln;
      timeblockstart:=now;
      medidatiempobytescopiados:=0;
      inc(medidatiempobytescopiados,BytesRead);
       inc(k);
       if (k = 512)   then
       begin
            timeblockend := now;
            mb:=(medidatiempobytescopiados/1024)/1024;
            tiempo:=(MilliSecondsBetween(timeblockend, timeblockstart));
            write('MB: ',mb:4:1,' Tiempo: ',tiempo:4:1,' milisegundos',' Velocidad: ', (mb/(tiempo/1000)):3:2,' Total KB: ',(TotalBytesCopied/1024):8:1);
            //Write(' Total copiado hasta el momento: ',round(TotalBytesCopied/1024/1024),' MB',' Velocidad: ',round((medidatiempobytescopiados/(1024*1024)))/(MilliSecondsBetween(timeblockend, timeblockstart)/1000));
            write(StringOfChar(#8,80));
            k:=0 ;
            timeblockstart := now;
            medidatiempobytescopiados:=0;
       end;   }

      Sleep(0);

    end;
    writeln;
    writeln('Tiempo total:', MilliSecondsBetween(now, totaltime) / 1000: 4: 1);
    writeln('Terminamos, total copiado:', round(TotalBytesCopied / 1024 ), ' KB');
    //writeln('Velocidad media:', round(TotalBytesCopied / 1024) /
      //(MilliSecondsBetween(now, totaltime) / 1000): 4: 1, ' MB/s');
    ArchivoDestino.Size := FileStream.Size;
    // TODO Cambiar tamaño archivo hashes
    SetLength(Buffer, 0);
    FileStream.Free;
    ArchivoDestino.Free;
    ArchivoHashes.Free;
    SetLength(HashArray, 0);
  end;

  //------------------------------




  //------------------------------


  procedure ScanFolder(const Path: string);
  var
    sPath: string;
    rec: TSearchRec;
  begin
    sPath := IncludeTrailingPathDelimiter(Path);

    if FindFirst(sPath + AllFilesMask, faAnyFile or faSymLink, rec) = 0 then
    begin
      repeat

        // writeln(sPath+rec.Name);
        if (rec.Attr and faDirectory) <> 0 then
        begin
          // item is a directory

          if (rec.Name <> '.') and (rec.Name <> '..') then
          begin
            if ((rec.Attr and faSymLink) <> faSymLink) then
              //     begin
              ScanFolder(sPath + rec.Name)
            //writeln('Directorio:',sPath+rec.Name) ;
            //      end
            else;
            //writeln('Symlink:',rec.Name);
          end;
        end
        else
        begin
          // item is a file
          //writeln('Archivo:',sPath+rec.Name);
          if ((rec.Attr and faSymLink) <> faSymLink) then
            writeln(sPath + rec.Name);
        end;
      until FindNext(rec) <> 0;
      FindClose(rec);
    end;
  end;




  //------------------------------
  // PROGRAMA PRINCIPAL
  //------------------------------

  procedure dcopy.DoRun;
  var
    ErrorMsg: string;
    Origen, Destino: string;
    i: integer;
    SourceDir,DestDir : string;
    SourceFilename,DestFilename : string;

  begin
    // quick check parameters
    ErrorMsg := CheckOptions('hc:', 'help chunksize:');
    if ErrorMsg <> '' then
    begin
      writeln('Opción desconocida');
      //ShowException(Exception.Create(ErrorMsg));
      WriteHelp;
      Terminate;
      Exit;
    end;

    // parse parameters
    if HasOption('h', 'help') then
    begin
      WriteHelp;
      Terminate;
      Exit;
    end;

    if HasOption('c', 'chunksize') then
    begin
      chunksize := StrToInt(GetOptionValue('c', 'chunksize'));
      if (chunksize < 32) or (chunksize > 1048576) then
      begin
        writeln('Invalid chunk size');
        WriteHelp;
        Terminate;
        Exit;
      end;
    end;

    { TODO : Añadir parámetros, chunk size, mir...}
    { add your program here }
    { TODO : Añadir try...finally }

    if (ParamStr(paramcount - 1) = '') or (ParamStr(paramcount) = '') then
    begin
      writeln('We need at least source and destination....');
      WriteHelp;
      Terminate;
      exit;
    end;


    { TODO : Extraer path y nombre por separado}
    Origen := ParamStr(paramcount - 1);
    Destino := ParamStr(ParamCount);
    { TODO : Añadir comprobación directorio destino, y abrir destino+nombre original. }
    writeln('Origen:', Origen);
    if (ExtractFilePath(Destino) = (ExtractFileDir(Destino) + '/')) then
      Destino := Destino + (ExtractFileName(Origen));
    writeln('Destino:', Destino);
    if FileExists(Destino) then //Comprobar si el tamaño es el mismo ¿y la fecha?
    begin
      writeln('Destino existe, procesamos archivo de hashes');
      copiarchivoconhash(Origen, Destino);
    end
    else
    begin
      writeln('Destino no existe, lo copiamos');
      copiarchivocompleto(Origen, Destino);
    end;
    writeln('fin');
    Terminate;
    // stop program loop
  end;

  constructor dcopy.Create(TheOwner: TComponent);
  begin
    inherited Create(TheOwner);
    StopOnException := True;
  end;

  destructor dcopy.Destroy;
  begin
    inherited Destroy;
  end;

  procedure dcopy.WriteHelp;
  begin
    { TODO: Añadir descripción programa y uso }
    writeln(Exename, ' -h -c -m -n chunksize source destination');
    writeln(ExeName, ' -h --help Get help');
    writeln(ExeName, ' -c --chunksize Set chunk size (in bytes, between 32 and 1048576');
    writeln(Exename, ' -m --mir Clone (as robocopy) a directory structure');
    writeln(Exename, ' -n --mon monitor folder for changes');
  end;

var
  Application: dcopy;
begin
  Application := dcopy.Create(nil);
  Application.Run;
  Application.Free;
end.
 
