program recursivo;
uses
Sysutils;
procedure ScanFolder(const Path: String);
var
  sPath: string;
  rec : TSearchRec;
begin
  sPath := IncludeTrailingPathDelimiter(Path);
  //if FindFirst(sPath + AllFilesMask, faAnyFile or faSymLink, rec) = 0 then
  if FindFirst(sPath + AllFilesMask, faAnyFile or faSymLink, rec) = 0 then
  begin
    repeat
      // TSearchRec.Attr contain basic attributes (directory, hidden,
      // system, etc). TSearchRec only supports a subset of all possible
      // info. TSearchRec.FindData contains everything that the OS
      // reported about the item during the search, if you need to
      // access more detailed information...
      //writeln(sPath+rec.Name);
      if (rec.Attr and faDirectory) <> 0 then
      begin
        // item is a directory

        if (rec.Name <> '.') and (rec.Name <> '..') then
           begin
             if ((rec.Attr and faSymLink) <> faSymLink) then
          ScanFolder(sPath + rec.Name)
          //writeln('Directorio:',sPath+rec.Name);
          else
          //writeln('Symlink:',rec.Name);
           end;
      end
      else
      begin
        // item is a file
        //writeln('Archivo:',sPath+rec.Name);
      if ((rec.Attr and faSymLink) <> faSymLink) then writeln(sPath+rec.Name);
      end;
    until FindNext(rec) <> 0;
    FindClose(rec);
  end;
end;

Var
  I : Longint;

begin
  //Writeln (paramstr(0),' : Got ',ParamCount,' command-line parameters: ');
  For i:=1 to ParamCount do
    begin
    //Writeln (ParamStr (i));
    ScanFolder(ParamStr(i));
    end ;
end.

