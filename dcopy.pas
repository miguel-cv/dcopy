program dcopya;

{$mode objfpc}{$H+}

uses {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Classes,
  SysUtils,
  CustApp,
  md5,
  fileutil,
  //lazutf8classes,
  dateUtils;

var

  ChunkSize: integer = 65536;    { We split the file in chunksize bytes }
  CalculateMD5: boolean = False; { Set default : don't calculate md5 hash of file }
  MIR: boolean = False;          { Recurse directories option : default false }
  Origen, Destino: string;       { Source and destination files }
  HashDir: string;               { Directory with hash files }
  TotalCopyTime : Tdatetime;     { Total copy time }
  TotalKBCopied : int64 ;        { Total KB Copied }

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


  function CompareFileSizeDate(const de, a: string): boolean;

  begin
    CompareFileSizeDate := False;
    if (fileutil.Filesize(de)) = (fileutil.Filesize(a)) then
      if (fileage(de)) = (fileage(a)) then
        CompareFileSizeDate := True;
  end;

  //------------------------------




  //------------------------------

  procedure CopyFullFile(const de, a: string);

  var
    SourceFile, DestFile: TFileStream;
    BytesCopied, TotalBytesCopied, medidatiempobytescopiados: int64;
    mb: double;
    Buffer: array of ansichar;
    BlockHash: string;
    timeblockstart, timeblockend, tiempo, totaltime: TDateTime;
    k: int64;
    MD5Context: TMD5Context;
    HashMD5: TMDDigest;
    HashTStringList: TStringList;
  begin
    SetLength(Buffer, ChunkSize);
    try
      SourceFile := TFileStream.Create(de, fmShareDenyNone);
      DestFile := TFileStream.Create(a, fmCreate);
    finally
    end;
    SourceFile.Position := 0;
    DestFile.Position := 0;
    TotalBytesCopied := 0;
    k := 0;
    HashTStringList := TStringList.Create;
    if CalculateMD5 then
      MD5Init(MD5Context);
    medidatiempobytescopiados := 0;
    timeblockstart := now;
    totaltime := now;

    while SourceFile.Size > TotalBytesCopied do
      // While the amount of data read is less than or equal to the size of the stream do
    begin

      BytesCopied := SourceFile.Read(Buffer[0], ChunkSize);
      // Read in ChunkSize of data
      Inc(TotalBytesCopied, BytesCopied);
      BlockHash := MD4Print(MD4Buffer(Buffer[0], BytesCopied));
      HashTStringList.Add(BlockHash);
      if CalculateMD5 then
        MD5Update(MD5Context, Buffer[0], BytesCopied);
      { TODO : mirar con CRC uses crc ; ejemplo en https://github.com/graemeg/freepascal/blob/master/packages/hash/examples/crctest.pas }
      DestFile.Write(Buffer[0], BytesCopied);
      Inc(medidatiempobytescopiados, BytesCopied);
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
          (round(TotalBytesCopied / 1024)));
        //Write(' Total copiado hasta el momento: ',round(TotalBytesCopied/1024/1024),' MB',' Velocidad: ',round((medidatiempobytescopiados/(1024*1024)))/(MilliSecondsBetween(timeblockend, timeblockstart)/1000));
        Write(StringOfChar(#8, 80));
        k := 0;
        timeblockstart := now;
        medidatiempobytescopiados := 0;
      end;        }
      Sleep(0);
    end;

    HashTStringList.SaveToFile((ExtractFilePath(ParamStr(0))) + MD5Print(MD5String(de)));
    HashTStringList.Free;
    writeln;
    writeln('Tiempo total:', MilliSecondsBetween(now, totaltime) / 1000: 4: 1);
    writeln('Terminamos, total copiado:', round(TotalBytesCopied / 1024), ' KB');
    if CalculateMD5 then
    begin
      MD5Final(MD5Context, HashMD5);
      writeln('Hash MD5 Archivo original:', MD5Print(HashMD5));
    end;
    { TODO : Comprobar tiempo 0 }
    //writeln('Velocidad media:', round(TotalBytesCopied / 1024) /
    //  (MilliSecondsBetween(now, totaltime) / 1000): 4: 1, ' MB/s');
    { TODO : ¿Mover esto más arriba, antes de imprimir los mensajes? }
    SetLength(Buffer, 0);
    SourceFile.Free;
    DestFile.Free;
    FileSetDateUTF8(a, fileage(de));
  end;

  //------------------------------




  //------------------------------

  procedure CopyFileWithHash(const de, a: string);

  var

    TotalBytesRead, BytesRead, medidatiempobytescopiados: int64;
    Buffer: array of AnsiChar;
    FileStream, FileHashes, DestFile: TFileStream;
    BlockHash: string;
    TempHashArray: array  [0..65535] of char;
    HashArray: array of array [0..31] of AnsiChar;
    i, j, k, l, TotalBytesCopied: longint;
    timeblockstart, timeblockend, totaltime, tiempo: TDateTime;
    mb: double;
    MD5Context: TMD5Context;
    HashMD5: TMDDigest;
    HashTStringList: TStringList;

  begin
    { TODO : Comprobar existencia archivo hashes, y si no llamar a copiararchivocompleto }

    TotalBytesRead := 0;
    writeln('Leyendo archivo con los hashes:');
    HashTStringList := TStringList.Create;
    HashTStringList.LoadFromFile((ExtractFilePath(ParamStr(0))) +
      MD5Print(MD5String(de)));
    SetLength(Buffer, ChunkSize);
    if CalculateMD5 then
      MD5Init(MD5Context);
    // Recordar que el 1er elemento del array es el 0
    writeln('Comenzando a procesar el archivo original');
    FileStream := TFileStream.Create(de, fmOpenRead or fmShareDenyNone);
    { TODO : IMPORTANTE COMPROBAR ESTADO APERTURA}
    FileStream.Position := 0;
    TotalBytesRead := 0;
    TotalBytesCopied := 0;
    i := 0;
    totaltime := now;
    DestFile := TFileStream.Create(a, fmOpenReadWrite);
    { TODO : IMPORTANTE COMPROBAR ESTADO APERTURA}
    //Añadir no abrir hasta que haya que grabar
    while FileStream.Size > TotalBytesRead do
    begin
      if (i >= HashTStringList.Count-1) then
          HashTStringList.Add('');
      BytesRead := FileStream.Read(Buffer[0], ChunkSize);
      // Read in lenght "ChunkSize" of data
      Inc(TotalBytesRead, BytesRead);
      BlockHash := MD4Print(MD4Buffer(Buffer[0], BytesRead));
      if CalculateMD5 then
        MD5Update(MD5Context, Buffer[0], BytesRead);
      if BlockHash <> HashTStringList[i] then
      begin
        Write(StringOfChar(#8, 80));
        Write('-----------Bloque distinto:', i);
        if FileStream.Position < ChunkSize then
          DestFile.Position := 0
        else
          DestFile.Position := (FileStream.Position - BytesRead);
        DestFile.Write(Buffer[0], BytesRead);
        Inc(TotalBytesCopied, BytesRead);
        if (i >= HashTStringList.Count) then
          HashTStringList.Add(BlockHash)
        else
          HashTStringList[i] := BlockHash;
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
    if ((HashTStringList.Count-1) > i) then
    begin
      for k := (HashTStringList.Count - 1) downto i do
      begin
        HashTStringList.Delete(k);
      end;
    end;
    HashTStringList.SaveToFile((ExtractFilePath(ParamStr(0))) + MD5Print(MD5String(de)));
    HashTStringList.Free;
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
    DestFile.Size := FileStream.Size;
    FileStream.Free;
    DestFile.Free;
    SetLength(Buffer, 0);
    FileSetDateUTF8(a, fileage(de));
  end;

  //------------------------------




  //------------------------------


  procedure ScanFolder(Path, DestPath: string);

  var
    SourcePath, DestPath2: string;
    SearchResult: TSearchRec;
  begin
    SourcePath := IncludeTrailingPathDelimiter(Path);

    if FindFirst(SourcePath + AllFilesMask, faAnyFile or faSymLink,
      SearchResult) = 0 then
    begin
      repeat
        writeln('Procesando --- SearchResult.Name : ', SourcePath + SearchResult.Name);
        // writeln(SourcePath+SearchResult.Name);
        if (SearchResult.Attr and faDirectory) <> 0 then
        begin
          // item is a directory

          if (SearchResult.Name <> '.') and (SearchResult.Name <> '..') then
          begin
            if ((SearchResult.Attr and faSymLink) <> faSymLink) then
            begin
              DestPath2 := DestPath + SearchResult.Name + PathDelim;
              //writeln('DestPath: ', DestPath, 'DestPath2: ', DestPath2);

              if MIR then
              begin
                ForceDirectoriesUTF8(DestPath2);
                ScanFolder(SourcePath + SearchResult.Name, DestPath2);
              end;
              //writeln('Directorio:',SourcePath+SearchResult.Name) ;

            end
            else;
            //writeln('Symlink:',SearchResult.Name);
          end;
        end
        else
        begin
          // item is a file
          //writeln('Origen:', SourcePath + SearchResult.Name);
          //writeln('Destino:', DestPath + SearchResult.Name);

          { TODO : Opción para forzar la copia aunque tamaño/fecha sean iguales }

          if ((SearchResult.Attr and faSymLink) <> faSymLink) then
            if FileExists(DestPath + SearchResult.Name) then
            begin
              if CompareFileSizeDate(SourcePath + SearchResult.Name,
                DestPath + SearchResult.Name) then
                writeln('Archivo sin modificar')
              else
                CopyFileWithHash(SourcePath + SearchResult.Name, DestPath + SearchResult.Name);

            end
            else
              CopyFullFile(SourcePath + SearchResult.Name, DestPath + SearchResult.Name);
          //writeln(SourcePath + SearchResult.Name);

        end;
      until FindNext(SearchResult) <> 0;
      FindClose(SearchResult);
    end;
  end;




  //------------------------------
  // PROGRAMA PRINCIPAL
  //------------------------------

  procedure dcopy.DoRun;

  var
    ErrorMsg: string;
    i: integer;
    SourceDir, DestDir: string;
    SourceFilename, DestFilename: string;

  begin
    // quick check parameters
    ErrorMsg := CheckOptions('hc:5r', 'help chunksize: md5 mir');
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

    if HasOption('r', 'mir') then
    begin
      MIR := True;
    end;

    if HasOption('c', 'chunksize') then
    begin
      ChunkSize := StrToInt(GetOptionValue('c', 'chunksize'));
      if (ChunkSize < 32) or (ChunkSize > 1048576) then
      begin
        writeln('Invalid chunk size');
        WriteHelp;
        Terminate;
        Exit;
      end;
    end;

    { add your program here }
    { TODO : Añadir try...finally }

    {$IFDEF UNIX}
    //Process parameters one on one
    {$EndIf}

    if (ParamStr(paramcount - 1) = '') or (ParamStr(paramcount) = '') then
    begin
      writeln('We need at least source and destination....');
      WriteHelp;
      Terminate;
      exit;
    end;
    { TODO : Si estamos en linux, dejar que la expansión la haga el shell
      y procesar todos los argumentos. }
    { TODO : Extraer path y nombre por separado}
    Origen := ParamStr(paramcount - 1);
    Destino := ParamStr(ParamCount);
    { TODO : Añadir comprobación directorio destino, y abrir destino+nombre original.FileExists }
    writeln('Prueba comodines, ', ExtractFileName(Origen) + ExtractFileExt(Origen));
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
        ScanFolder(Origen, Destino);
        Terminate;
        Exit;
      end;

    if (ExtractFilePath(Destino) = (ExtractFileDir(Destino) + '/')) then
      Destino := Destino + (ExtractFileName(Origen));

    writeln(Origen, '-', Destino);

    if FileExists(Destino) then //Comprobar si el tamaño es el mismo ¿y la fecha?
    begin
      if not (CompareFileSizeDate(Origen, Destino)) then
      begin
        writeln('Destino existe, procesamos archivo de hashes');
        CopyFileWithHash(Origen, Destino);
      end
      else
      begin
        writeln('Destino existe, y tiene la misma fecha/tamaño');
      end;
    end
    else
    begin
      writeln('Destino no existe, lo copiamos');
      CopyFullFile(Origen, Destino);
    end;
    Terminate;
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
    writeln(Exename, ' -h  -m -n -c chunksize source destination');
    writeln(ExeName, ' -h --help Get this text');
    writeln(ExeName, ' -c --chunksize Set chunk size (in bytes, between 32 and 1048576');
    writeln(Exename, ' -r --mir Clone (as robocopy) a directory structure');
    writeln(Exename, ' -n --mon monitor folder for changes (Not yet)');
    writeln(Exename, ' -5 --md5 Calculate md5 hash');
    writeln(Exename, ' -f --force Force overwrite');
    writeln(Exename, ' -d --delete with --mir delete files not on source ');
    writeln(Exename, ' -a --hashdir Directory containing hash files ');
  end;

var
  Application: dcopy;
begin
  Application := dcopy.Create(nil);
  Application.Run;
  Application.Free;
end.
