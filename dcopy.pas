
program dcopya;

{$mode objfpc}{$H+}

uses {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Classes,
  SysUtils,
  CustApp,
  md5,
  fileutil,
  //crc,
  dateUtils;

var

  chunksize: integer = 65536;    { We split the file in chunksize bytes }
  minsize: integer = 65536;      { Minimum size to skip hashing }
  CalculateMD5: boolean = False; { Set default don't get md5 hash of file }

type

  { dcopy }

  dcopy = class(TCustomApplication)
  protected
    procedure DoRun;
      override;
  public
    constructor Create(TheOwner: TComponent);
      override;
    destructor Destroy;
      override;
    procedure WriteHelp;
      virtual;
  end;


  { dcopy }

  //------------------------------




  //------------------------------

  procedure copiarchivocompleto(const de, a: string);

  var
    FileStreamOr, FileStreamDes, FileStreamHashes: TFileStream;
    BytesCopiados, TotalBytesCopiados, medidatiempobytescopiados: int64;
    mb: double;
    TempBuffer: array of ansichar;
    HashBloque: string;
    timeblockstart, timeblockend, tiempo, totaltime: TDateTime;
    k: int64;
    MD5Context: TMD5Context;
    HashMD5: TMDDigest;
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
    if CalculateMD5 then
      MD5Init(MD5Context);
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
      if CalculateMD5 then
        MD5Update(MD5Context, TempBuffer[0], BytesCopiados);
      { TODO : mirar con CRC uses crc ; ejemplo en https://github.com/graemeg/freepascal/blob/master/packages/hash/examples/crctest.pas }
      FileStreamDes.Write(TempBuffer[0], BytesCopiados);
      FileStreamHashes.Write(HashBloque[1], 32);
      Inc(medidatiempobytescopiados, BytesCopiados);
      Inc(k);
      { TODO : Cambiar esto por un tiempo , con millisecondsbetween... }

{if (k = 512) then
      begin
        timeblockend := now;
        mb := (medidatiempobytescopiados / 1024) / 1024;
        tiempo := (MilliSecondsBetween(timeblockend, timeblockstart));
        Write('MB: ', mb: 4: 1, ' Tiempo: ', tiempo: 4: 1, ' milisegundos',
          ' Velocidad: ',
          (mb / (tiempo / 1000)): 3: 2, ' Total KB: ',
          (round(TotalBytesCopiados / 1024)));
        //Write(' Total copiado hasta el momento: ',round(TotalBytesCopiados/1024/1024),' MB',' Velocidad: ',round((medidatiempobytescopiados/(1024*1024)))/(MilliSecondsBetween(timeblockend, timeblockstart)/1000));
        Write(StringOfChar(#8, 80));
        k := 0;
        timeblockstart := now;
        medidatiempobytescopiados := 0;
      end;        }
      Sleep(0);
    end;
    writeln;
    writeln('Tiempo total:', MilliSecondsBetween(now, totaltime) / 1000: 4: 1);
    writeln('Terminamos, total copiado:', round(TotalBytesCopiados / 1024), ' KB');
    if CalculateMD5 then
    begin
      MD5Final(MD5Context, HashMD5);
      writeln('Hash MD5 Archivo original:', MD5Print(HashMD5));
    end;
    { TODO : Comprobar tiempo 0 }
    //writeln('Velocidad media:', round(TotalBytesCopiados / 1024) /
    //  (MilliSecondsBetween(now, totaltime) / 1000): 4: 1, ' MB/s');
    { TODO : ¿Mover esto más arriba, antes de imprimir los mensajes? }
    SetLength(TempBuffer, 0);
    FileStreamOr.Free;
    FileStreamDes.Free;
    FileStreamHashes.Free;
    FileSetDateUTF8(a, fileage(de));
  end;

  //------------------------------




  //------------------------------

  procedure copiarchivoconhash(const de, a: string);

  var

    TotalBytesRead, BytesRead, medidatiempobytescopiados: int64;
    Buffer: array of AnsiChar;
    FileStream, ArchivoHashes, ArchivoDestino: TFileStream;
    HashBloque: string;
    TempHashArray: array  [0..65535] of char;
    HashArray: array of array [0..31] of AnsiChar;
    i, j, k, l, TotalBytesCopied: longint;
    timeblockstart, timeblockend, totaltime, tiempo: TDateTime;
    mb: double;
    MD5Context: TMD5Context;
    HashMD5: TMDDigest;

  begin

    { TODO : Comprobar existencia archivo hashes, y si no llamar a copiararchivocompleto }
    ArchivoHashes := TFileStream.Create(de + '.hash', fmOpenReadWrite);
    ArchivoHashes.Position := 0;
    TotalBytesRead := 0;
    writeln('Leyendo archivo con los hashes:', de + '.hash', ' - ',
      (ArchivoHashes.Size / 1024): 0: 1, ' KB');
    i := round(ArchivoHashes.Size / 32);
    SetLength(HashArray, i + 1);
    //1 más por si acaso
    k := 0;
    while ArchivoHashes.Size > TotalBytesRead do
    begin
      BytesRead := ArchivoHashes.Read(TempHashArray, 65536);
      Inc(TotalBytesRead, BytesRead);
      for j := 0 to round(BytesRead / 32) - 1 do
      begin
        HashArray[k] := copy(TempHashArray, j * 32 + 1, 32);
        Inc(k);
      end;
    end;
    SetLength(Buffer, chunksize);
    if CalculateMD5 then
      MD5Init(MD5Context);
    // Recordar que el 1er elemento del array es el 0
    writeln('Comenzando a procesar el archivo original');
    FileStream := TFileStream.Create(de, fmOpenRead);
    { TODO : IMPORTANTE COMPROBAR ESTADO APERTURA}
    FileStream.Position := 0;
    TotalBytesRead := 0;
    TotalBytesCopied := 0;
    i := 0;
    totaltime := now;
    ArchivoDestino := TFileStream.Create(a, fmOpenReadWrite);
    { TODO : IMPORTANTE COMPROBAR ESTADO APERTURA}
    //Añadir no abrir hasta que haya que grabar
    while FileStream.Size > TotalBytesRead do
    begin
      BytesRead := FileStream.Read(Buffer[0], chunksize);
      // Read in lenght "chunksize" of data
      Inc(TotalBytesRead, BytesRead);
      HashBloque := MD4Print(MD4Buffer(Buffer[0], BytesRead));
      if CalculateMD5 then
        MD5Update(MD5Context, Buffer[0], BytesRead);
      if HashBloque <> HashArray[i] then
      begin
        Write(StringOfChar(#8, 80));
        Write('-----------Bloque distinto:', i);
        if FileStream.Position < chunksize then
          ArchivoDestino.Position := 0
        else
          ArchivoDestino.Position := (FileStream.Position - BytesRead);
        ArchivoDestino.Write(Buffer[0], BytesRead);
        Inc(TotalBytesCopied, BytesRead);
        ArchivoHashes.Position := (i * 32);
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
    writeln('Terminamos, total copiado:', round(TotalBytesCopied / 1024), ' KB');
    if CalculateMD5 then
    begin
      MD5Final(MD5Context, HashMD5);
      writeln('Hash MD5 Archivo Original:', MD5Print(HashMD5));
    end;
    //writeln('Velocidad media:', round(TotalBytesCopied / 1024) /
    //(MilliSecondsBetween(now, totaltime) / 1000): 4: 1, ' MB/s');
    ArchivoDestino.Size := FileStream.Size;
    { TODO: Comprobar Cambiar tamaño archivo hashes }
    FileStream.Free;
    ArchivoDestino.Free;
    ArchivoHashes.Free;
    SetLength(Buffer, 0);
    SetLength(HashArray, 0);
    FileSetDateUTF8(a, fileage(de));
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
    SourceDir, DestDir: string;
    SourceFilename, DestFilename: string;

  begin
    // quick check parameters
    ErrorMsg := CheckOptions('hc:5', 'help chunksize: md5');
    if ErrorMsg <> '' then
    begin
      writeln('Unknown option');
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

    if HasOption('5', 'md5') then
    begin
      CalculateMD5 := True;
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
    { TODO : Añadir comprobación directorio destino, y abrir destino+nombre original.FileExists }

    if (Origen = Destino) then
    begin
      writeln('You can''t copy a file/directory over itself');
      WriteHelp;
      Terminate;
      Exit;
    end;
    if (ExtractFileName(Origen) = '') then
      if (ExtractFileName(Destino) <> '') then
      begin
        writeln('You can''t copy a directory to a file');
        WriteHelp;
        Terminate;
        Exit;
      end
      else
      begin
        writeln('Bien, dos directorios');
        ScanFolder(Origen);
        //Enviar destino también
        Terminate;
        Exit;
      end;

    if (ExtractFilePath(Destino) = (ExtractFileDir(Destino) + '/')) then
      Destino := Destino + (ExtractFileName(Origen));

    writeln(Origen, '-', Destino);

    if FileExists(Destino) then //Comprobar si el tamaño es el mismo ¿y la fecha?
    begin
      writeln('Destino existe, procesamos archivo de hashes');
      writeln('Tamaño y fecha origen:',fileutil.Filesize(Origen),'-',datetimetostr(filedatetodatetime(fileage(Origen))));
      writeln('Tamaño y fecha destino:',fileutil.Filesize(Destino),'-',datetimetostr(filedatetodatetime(fileage(Destino))));
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
    writeln('dcopy - write description ');
    writeln(Exename, ' -h -c -m -n chunksize source destination');
    writeln(ExeName, ' -h --help Get help');
    writeln(ExeName, ' -c --chunksize Set chunk size (in bytes, between 32 and 1048576');
    writeln(ExeName,
      ' -m --minsize Minimum size to skip hashing (copy directly) (in Kbytes, default 65536');
    writeln(Exename, ' -r --mir Clone (as robocopy) a directory structure');
    writeln(Exename, ' -n --mon monitor folder for changes');
    writeln(Exename, ' -5 --md5 Calculate md5 hash');
  end;

var
  Application: dcopy;
begin
  Application := dcopy.Create(nil);
  Application.Run;
  Application.Free;
end.
