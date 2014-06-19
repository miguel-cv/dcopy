program spinner;

uses sysutils;

const Frame: array[0..3] of char =   ('|','/','-','\');
  //('.','o','O','o');
//

var   i,x,y : Integer;

begin
 while True do  begin

  for i := 0 to Length(Frame)-1 do begin
  Write(Frame[i]+#8);
  Sleep (random(75)*random(3));

 end;

  ///do something
 end;
    ReadLn;
end.
