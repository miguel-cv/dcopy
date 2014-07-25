program dcopya;

{$mode objfpc}{$H+}
{$IFDEF UNIX}{$CODEPAGE UTF8}{$ENDIF}
uses {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Classes,
  SysUtils,
  CustApp,
  md5,
  fileutil,
  lazutf8classes,
  lazfileutils,  //LConvEncoding,
 {$IFDEF WINDOWS} Windows, {$ENDIF}
  dateUtils;

var

  ChunkSize: longint = 65536;    { We split the file in chunksize bytes, default 65536 }
  CalculateMD5: boolean = False; { Set default : don't calculate md5 hash of file }
  ForceCopy: boolean = False;    { Set default : don't copy files with same size/date }
  Recursive: boolean = False;    { Recurse directories option : default false }
  Source, Destination: string;   { Source and destination files }
  HashDir: string;               { Directory with hash files }
  MakeHashFile: boolean = False;
  { Set default : don't make hash files to send only differences }
  SameDisk: boolean = False;     { Set default : copy not within same disk }
  TotalCopyTime: Tdatetime;
  TotalKBCopied: int64 = 0;
  TotalFilesCopied: longint = 0;
  FailedFilesCopied: longint = 0;
  FailedFilesList: TStringListUTF8; {List of failed files}
  MaxMemToUse: int64 = 32 * 1024 * 1024;   {Set default max memory to use:32 M}
  MemUsed: int64 = 0;
  DestFileName: array[0..131072] of string;
  DestDate: array[0..131072] of longint;
  FilesArray: array of TMemoryStream;

const
  Frame: array[0..3] of char = ('|', '/', '-', '\');

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
    //writeln(' ',FilesizeUTF8(de),' ',FilesizeUTF8(a),'-',FileAgeUTF8(a),' ',FileAgeUTF8(de));
    CompareFileSizeDate := False;
    if (FilesizeUTF8(de)) = (FilesizeUTF8(a)) then
      if (fileageUTF8(de)) = (fileageUTF8(a)) then
        CompareFileSizeDate := True;
  end;

  //------------------------------




  //------------------------------

  procedure WriteFilesToDisk;
  var
    m: longint;
  begin
    writeln;
    writeln('FilesArray Length:',Length(FilesArray));
    //FilesArray[NumberOfFiles].Free;
    for m := Length(FilesArray) - 1 downto 0 do
    begin
      FilesArray[m].Position := 0;
      writeln('Saving to disk:', DestFileName[m], '-', m);
      try
        try
          FilesArray[m].SaveToFile(DestFileName[m]);
          FileSetDateUTF8(DestFileName[m], DestDate[m]);
                finally
        FilesArray[m].Free;
        //writeln('Liberado:', m);
      end;
        except
            writeln('Error grabando:', DestFileName[m]);
            Inc(FailedFilesCopied);
            FailedFilesList.Add(DestFileName[m]);
          end;

    end;
    MemUsed := 0;
    SetLength(FilesArray, 0);
  end;



  //------------------------------




  //------------------------------

  procedure CopyFullFile(const de, a: string);

  var
    SourceFile, DestFile: TStream;
    BytesCopied, TotalBytesCopied: int64;
    Buffer: array of ansichar;
    BlockHash: string;
    totaltime: TDateTime;
    k, sizeoffile: int64;
    MD5Context: TMD5Context;
    HashMD5: TMDDigest;
    HashTStringList: TStringList;
    Flag: boolean = False;
    Numberoffiles:int64=0;
  begin
    TotalBytesCopied := 0;
    BytesCopied := 0;
    try
      try
        SourceFile := TFileStream.Create(de, fmShareDenyNone);
        SourceFile.Position := 0;
        if not SameDisk then
          DestFile := TFileStream.Create(a, fmCreate);
        //DestFile.Position := 0;

        sizeoffile := SourceFile.Size;
        if (sizeoffile >= MaxMemToUse) and SameDisk then
        begin
          SameDisk := False;
          Flag := True;
          DestFile := TFileStream.Create(a, fmCreate);
          dec(NumberOfFiles);
        end;
        if ChunkSize > sizeoffile then
          SetLength(Buffer, sizeoffile)
        else
          SetLength(Buffer, ChunkSize);

        if SameDisk then
        begin
          writeln(' to memory');
          //writeln(' Antes de writefilestodisk MemUsed=', MemUsed, ' MaxMemToUse=', MaxMemToUse, ' FileSize:', sizeoffile, ' Length FilesArray:',Length(FilesArray));
          if ((MemUsed + sizeoffile) >= MaxMemToUse) then
            WriteFilesToDisk;
          NumberofFiles:=Length(FilesArray);
         // writeln('Después de writefilestodisk,numberoffiles=', NumberOfFiles,
           // ' MemUsed=', MemUsed, ' MaxMemToUse=', MaxMemToUse, ' FileSize:', sizeoffile);
          SetLength(FilesArray, Numberoffiles + 1);
          { TODO : IMPORTANTE:Comprobar si el tamaño del archivo es > que la memoria disponible }
          //WriteFilesToDisk;
          //if sizeoffile > MaxMemToUse then SameDisk:=False; {CAMBIAR ESTO, VOLVER A PONER EL FLAG}
          //end
          FilesArray[Numberoffiles] := TMemoryStream.Create;
          FilesArray[NumberOfFiles].Position := 0;
          FilesArray[NumberOfFiles].copyfrom(SourceFile, sizeoffile);
          FilesArray[NumberOfFiles].Position := 0;
          DestFileName[NumberOfFiles] := a;
          DestDate[NumberOfFiles] := FileAgeUTF8(de);
          MemUsed += sizeoffile;

       { writeln(' Number of files:', NumberOfFiles, ' Mem Used:',
          MemUsed, ' FileSize:', sizeoffile); }
        end;
        //k := 0;
        if MakeHashFile then
          HashTStringList := TStringList.Create;
        if CalculateMD5 then
          MD5Init(MD5Context);
        totaltime := now;

        while True do
        begin

          if SameDisk then
            BytesCopied := FilesArray[NumberOfFiles].Read(Buffer[0], ChunkSize)
          else
            BytesCopied := SourceFile.Read(Buffer[0], ChunkSize);

          if BytesCopied < 1 then
            break;
          Inc(TotalBytesCopied, BytesCopied);
          if CalculateMD5 then
            MD5Update(MD5Context, Buffer[0], BytesCopied);

          if MakeHashFile then
          begin
            BlockHash := MD4Print(MD4Buffer(Buffer[0], BytesCopied));
            HashTStringList.Add(BlockHash);
          end;
          if not (samedisk) then
            DestFile.Write(Buffer[0], BytesCopied);
        end;

        Write(' *** Total time:', MilliSecondsBetween(now, totaltime));
        writeln(' Copied:', round(TotalBytesCopied / 1024), ' KB');
        Inc(TotalKBCopied, round(TotalBytesCopied / 1024));
        if MakeHashFile then
        begin
          HashTStringList.SaveToFile(ExtractFilePath(ParamStr(0)) +
            'Hashdir' + PathDelim + MD5Print(MD5String(de)));
          HashTStringList.Free;
        end;
        if CalculateMD5 then
        begin
          MD5Final(MD5Context, HashMD5);
          writeln('MD5 Hash: ', MD5Print(HashMD5));
        end;
        { TODO : Comprobar tiempo 0 }
        //writeln('Velocidad media:', round(TotalBytesCopied / 1024) /
        //  (MilliSecondsBetween(now, totaltime) / 1000): 4: 1, ' MB/s');
      except
        writeln(' **** Error processing file ****', de);
        Inc(FailedFilesCopied);
        FailedFilesList.Add(de);
      end;
    finally
      Inc(NumberOfFiles);
      SetLength(Buffer, 0);
      if not (Samedisk) then
        DestFile.Free;
      SourceFile.Free;
    end;

    if not (SameDisk) then
      FileSetDateUTF8(a, fileageutf8(de));
    if flag then
      SameDisk := True;
    Inc(TotalFilesCopied);
  end;

  //------------------------------




  //------------------------------

  procedure CopyFileWithHash(const de, a: string);

  var

    TotalBytesRead, BytesRead: int64;
    Buffer: array of AnsiChar;
    SourceFile, DestFile: TFileStream;
    BlockHash: string;
    i, k, TotalBytesCopied: longint;
    totaltime: TDateTime;
    MD5Context: TMD5Context;
    HashMD5: TMDDigest;
    HashTStringList: TStringList;

  begin
    if not (MakeHashFile) then
    begin
      CopyFullFile(de, a);
      exit;
    end;
    TotalBytesRead := 0;
    writeln(' Reading hashes file:', ExtractFilePath(ParamStr(0)) +
      'Hashdir' + PathDelim + MD5Print(MD5String(de)));
    try
      if not FileExistsUTF8((ExtractFilePath(ParamStr(0))) + 'Hashdir' +
        PathDelim + MD5Print(MD5String(de))) then
      begin
        { TODO : Comprobar fecha/tamaño. Si force copiar completo, si no pasar. }
        writeln('Hashes file doesn''t exists, copying full file');
        CopyFullFile(de, a);
        exit;
      end;
      HashTStringList := TStringList.Create;
      HashTStringList.LoadFromFile((ExtractFilePath(ParamStr(0))) +
        'Hashdir' + PathDelim + MD5Print(MD5String(de)));

      if CalculateMD5 then
        MD5Init(MD5Context);
      // Recordar que el 1er elemento del array es el 0
      writeln('Start processing source file');
      SourceFile := TFileStream.Create(de, fmOpenRead or fmShareDenyNone);
      if ChunkSize > SourceFile.size then
        SetLength(Buffer, SourceFile.Size)
      else
        SetLength(Buffer, ChunkSize);
      SourceFile.Position := 0;
      TotalBytesRead := 0;
      TotalBytesCopied := 0;
      i := 0;
      totaltime := now;
      DestFile := TFileStream.Create(a, fmOpenReadWrite);
      while SourceFile.Size > TotalBytesRead do
      begin
        if (i >= HashTStringList.Count - 1) then
          HashTStringList.Add('');
        BytesRead := SourceFile.Read(Buffer[0], ChunkSize);
        // Read in lenght "ChunkSize" of data
        Inc(TotalBytesRead, BytesRead);
        BlockHash := MD4Print(MD4Buffer(Buffer[0], BytesRead));
        if CalculateMD5 then
          MD5Update(MD5Context, Buffer[0], BytesRead);
        if BlockHash <> HashTStringList[i] then
        begin
          Write(StringOfChar(#8, 80));
          Write('-----------Bloque distinto:', i);
          if SourceFile.Position < ChunkSize then
            DestFile.Position := 0
          else
            DestFile.Position := (SourceFile.Position - BytesRead);
          DestFile.Write(Buffer[0], BytesRead);
          Inc(TotalBytesCopied, BytesRead);
          if (i >= HashTStringList.Count) then
            HashTStringList.Add(BlockHash)
          else
            HashTStringList[i] := BlockHash;
          //Sleep(0);
        end;
        Inc(i);
      end;
      if ((HashTStringList.Count - 1) > i) then
      begin
        for k := (HashTStringList.Count - 1) downto i do
        begin
          HashTStringList.Delete(k);
        end;
      end;
      Write(' ***Total Time:', SecondsBetween(now, totaltime) / 1000: 4: 1);
      writeln(' Copied:', round(TotalBytesCopied / 1024), ' KB');
      if CalculateMD5 then
      begin
        MD5Final(MD5Context, HashMD5);
        writeln('Hash MD5 Archivo Original:', MD5Print(HashMD5));
      end;
      //writeln('Velocidad media:', round(TotalBytesCopied / 1024) /
      //(MilliSecondsBetween(now, totaltime) / 1000): 4: 1, ' MB/s');
    finally
      HashTStringList.SaveToFile((ExtractFilePath(ParamStr(0))) +
        'Hashdir' + PathDelim + MD5Print(MD5String(de)));
      HashTStringList.Free;
      DestFile.Size := SourceFile.Size;
      SourceFile.Free;
      DestFile.Free;
      SetLength(Buffer, 0);
    end;
    Inc(TotalFilesCopied);
    FileSetDateUTF8(a, fileageutf8(de));
  end;

  //------------------------------




  //------------------------------

{$IfNDef WINDOWS}
  procedure ScanFolder(Path, DestPath: string);

  var
    SourcePath, DestPath2: string;
    SearchResult: TSearchRec;
  begin
    SourcePath := IncludeTrailingPathDelimiter(Path);

    if FindFirstUTF8(systoutf8(SourcePath + AllFilesMask), faAnyFile or
      faSymLink, SearchResult) = 0 then
    begin
      repeat

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

              if Recursive then
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
          Write(SourcePath + SearchResult.Name);
          { TODO : Opción para forzar la copia aunque tamaño/fecha sean iguales }
          try
            if ((SearchResult.Attr and faSymLink) <> faSymLink) then
              if FileExistsUTF8(sysToUTF8(DestPath + SearchResult.Name)) then
              begin
                if CompareFileSizeDate(sysToUTF8(SourcePath + SearchResult.Name),
                  sysToUTF8(DestPath + SearchResult.Name)) then
                  writeln(' *** same date/size ***')
                else
                begin
                  CopyFileWithHash(SourcePath + SearchResult.Name,
                    DestPath + SearchResult.Name);
                end;

              end
              else
              begin
                CopyFullFile(SourcePath + SearchResult.Name, DestPath +
                  SearchResult.Name);
              end;
            //writeln(SourcePath + SearchResult.Name);
          except
            writeln(' **** Error processing file **** ', SourcePath + SearchResult.Name);
            Inc(FailedFilesCopied);
            FailedFilesList.Add(SourcePath + SearchResult.Name);
          end;

        end;
      until FindNextUTF8(SearchResult) <> 0;
      FindCloseUTF8(SearchResult);
    end;
  end;

 {$ENDIF}
 {$IFDEF WINDOWS}

  procedure scanfolder(Source, DestPath: UTF8String);
  var
    sFind: UTF8String;
    hFind: thandle;
    rFind: WIN32_FIND_DATAW;
    sFile: UTF8string;
    DestPath2: UTF8String;
    temp, temp2: UTF8String;
  begin
    //WriteLn('Current Directory: ' + ExpandFileName('.'));

    // search the target directory
    sFind := IncludeTrailingPathDelimiter(Source);
    DestPath := IncludeTrailingPathDelimiter(DestPath);
    try
    //WriteLn('Find: ' + utf8decode(sFind));
    hFind := Windows.FindFirstFileW(pwidechar(utf8decode(sFind + AllFilesMask)), rFind);
    //hFind := FindFirstFileW(PWideChar(sFind), rFind);
    if hFind <> INVALID_HANDLE_VALUE then
    begin

      repeat
        try
        if (rFind.cFileName <> '.') and (rfind.cFileName <> '..') then
        begin
          sFile := rFind.cFileName;
          if (rFind.dwFileAttributes and faDirectory) <> faDirectory then
          begin
            //Write(sFile);
            // writeln(' - ', fileutil.FileSize((utf8encode(sFind + sFile))),
            //   ' - ', FileAge(sFind + sFile));
            temp := sFind + Sfile;
            temp2 := DestPath + sFile;
            if FileExistsUTF8(utf8encode(DestPath + sFile)) then
            begin
              if CompareFileSizeDate(utf8encode(temp), utf8encode(temp2)) then
                writeln(temp, ' *** same date/size ***')
              else
              begin
                Write(temp, ' ');
                CopyFileWithHash(utf8encode(temp),
                  utf8encode(temp2));
              end;

            end
            else
            begin
              Write('Copying ', temp);
              CopyFullFile(utf8encode(temp),
                utf8encode(temp2));
            end;
            //writeln(SourcePath + SearchResult.Name);

          end
          else
          begin
            //writeln(unicodestring(rFind.cFileName), ' es un directorio');
            DestPath2 := DestPath + sFile;
            IncludeTrailingPathDelimiter(DestPath2);
            if Recursive then
            begin
              ForceDirectories(DestPath2);
              scanfolder(utf8encode(sFind + sFile), utf8encode(DestPath2));
            end;
          end;
        end;
        except
      end;
      until not FindNextFileW(hFind, rFind);

    end;
    finally
    FindClose(hFind);
  end;

  end;

{$ENDIF}


  //------------------------------
  // PROGRAMA PRINCIPAL
  //------------------------------

  procedure dcopy.DoRun;

  var
    ErrorMsg: string;
    i: integer;

  begin
    // quick check parameters
    SetLength(FilesArray, 0);
    ErrorMsg := CheckOptions('hc:5rmsx',
      'help chunksize: md5 recursive makehash same-disk max-mem');
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

    if HasOption('s', 'same-disk') then
      SameDisk := True;

    if HasOption('5', 'md5') then
      CalculateMD5 := True;

    if HasOption('r', 'recursive') then
      Recursive := True;

    if HasOption('m', 'makehash') then
      MakeHashFile := True;

    if HasOption('x', 'max-mem') then
    begin
      MaxMemToUse := StrToInt(GetOptionValue('x', 'max-mem'));
      if (MaxMemToUse < 1) or (MaxMemToUse > 4096) then
      begin
        writeln('Invalid max-mem value (it has to be from 1-4096)');
        WriteHelp;
        Terminate;
        Exit;
      end
      else
        MaxMemToUse := MaxMemToUse * 1024 * 1024;
    end;

    if HasOption('c', 'chunksize') then
    begin
      ChunkSize := StrToInt(GetOptionValue('c', 'chunksize'));
      if (ChunkSize < 32) or (ChunkSize > 4194304) then
      begin
        writeln('Invalid chunk size (it has to be from 32-4194304)');
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

    ForceDirectoriesUTF8((ExtractFilePath(ParamStr(0))) + 'Hashdir');
    FailedFilesList := TStringListUTF8.Create;
    TotalCopyTime := now;

    if (ParamStr(paramcount - 1) = '') or (ParamStr(paramcount) = '') then
    begin
      writeln('We need at least source and destination....');
      WriteHelp;
      Terminate;
      exit;
    end;
    { TODO : Si estamos en linux, dejar que la primera expansión la haga el shell
      y procesar todos los argumentos. }
    { TODO : Extraer path y nombre por separado}

    Source := ParamStr(paramcount - 1);
    Destination := ParamStr(ParamCount);
    if DirectoryExistsUTF8(systoutf8(Source)) then
      if Source[Length(Source)] <> PathDelim then
        Source += PathDelim;
    if DirectoryExistsUTF8(systoutf8(Destination)) then
      if Destination[Length(Destination)] <> PathDelim then
        Destination += PathDelim;

    if (Source = Destination) then
    begin
      writeln('You can''t copy a file/directory over itself');
      WriteHelp;
      Terminate;
      Exit;
    end;

    if (ExtractFileName(Source) = '') then
    begin
      if ((ExtractFileName(Destination) <> '')) and
        (FileExistsUTF8(sysToUTF8(Destination))) then
      begin
        writeln('You can''t copy a directory to a file');
        WriteHelp;
        Terminate;
        Exit;
      end
      else  // copy from dir to dir
      begin
        ScanFolder(Source, Destination);
        if (samedisk) and (Length(FilesArray) <> 0) then
          WriteFilesToDisk;
        writeln('Total files copied:', TotalFilesCopied);
        writeln('Total copied:', TotalKBCopied, 'KB');
        writeln('Total time: ', SecondsBetween(now, TotalCopyTime));
        writeln('Files with errors:', FailedFilesCopied);
        if (FailedFilesList.Count <> 0) then
          if FailedFilesList.Count = 1 then
            writeln(FailedFilesList[0])
          else
          begin
            for i := 0 to FailedFilesList.Count - 1 do
              writeln(FailedFilesList[i]);
          end;
        FailedFilesList.Free;
        SetLength(FilesArray, 0);
        Terminate;
        Exit;
      end;
    end;


    if (ExtractFileName(Destination) = '') then
      Destination := Destination + (ExtractFileName(Source));


    writeln(Source, ' - ', Destination);

    if FileExistsUTF8(sysToUTF8(Destination)) then
    begin
      if not (CompareFileSizeDate(sysToUTF8(Source), sysToUTF8(Destination))) then
      begin
        //writeln('File exists in destination, copying using hash file');
        CopyFileWithHash(Source, Destination);
      end
      else
      begin
        writeln('File exists in destination, and has same date/size');
      end;
    end
    else
    begin
      //writeln('Copying file to destination');
      CopyFullFile(Source, Destination);
    end;
    writeln('Total files copied:', TotalFilesCopied);
    writeln('Total copied:', TotalKBCopied, ' KB');
    writeln('Total time: ', SecondsBetween(now, TotalCopyTime));
    writeln('Files with errors:', FailedFilesCopied);
    FailedFilesList.Free;
    SetLength(FilesArray, 0);
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
    writeln(Exename, ' -h -r -5 -c chunksize -m -s -x source destination');
    writeln(ExeName, ' -h --help Get this text');
    writeln(ExeName, ' -c --chunksize Set chunk size (in bytes, between 32 and 1048576)');
    writeln(Exename, ' -r --recursive Recursive copy of files/directories');
    //writeln(Exename, ' -n --mon monitor folder for changes ');
    writeln(Exename, ' -5 --md5 Calculate md5 hash');
    //writeln(Exename, ' -f --force Force overwrite');
    //writeln(Exename, ' -d --delete Delete files not on source ');
    //writeln(Exename, ' -a --hashdir Directory containing hash files ');
    writeln(Exename, ' -m --makehash save hash files to send only changed content ');
    writeln(Exename, ' -s --same-disk Copy files to memory first ');
    writeln(ExeName, ' -x --max-mem Max memory to use for same disk copy (in MB)');
  end;

var
  Application: dcopy;
begin
  Application := dcopy.Create(nil);
  Application.Title := 'Aplicacion de copia';
  Application.Run;
  Application.Free;
end.
