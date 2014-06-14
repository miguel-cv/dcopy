unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, DirMonitor, StdCtrls;

type
  TForm1 = class(TForm)
    Edit1: TEdit;
    ListBox1: TListBox;
    DirMonitor1: TDirMonitor;
    Label1: TLabel;
    Button1: TButton;
    CheckBox1: TCheckBox;
    Label2: TLabel;
    Edit2: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure DirMonitor1Change(sender: TObject; Action: TAction;
      FileName: String);
    procedure CheckBox1Click(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
    cuenta: integer;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}





procedure TForm1.FormCreate(Sender: TObject);
begin
  self.cuenta:=0;
end;


procedure TForm1.Button1Click(Sender: TObject);
begin
  self.Edit1.Text:='';
  self.cuenta:=0;
  self.ListBox1.Clear;
end;

procedure TForm1.DirMonitor1Change(sender: TObject; Action: TAction;
  FileName: String);
var acc:string;
begin
  inc(self.cuenta);
  self.Edit1.Text:=inttostr(self.cuenta);

  acc:='';

  case Action of
    faADDED: acc:='ADD';
    faREMOVED: acc:='REMOVED';
    faMODIFIED: acc:='MODIFIED';
    faRENAMED_OLD_NAME: acc:='RENAMED_OLD_NAME';
    faRENAMED_NEW_NAME: acc:='RENAMED_NEW_NAME';
  end;

  self.ListBox1.Items.Add(FileName+' -- '+acc);
end;

procedure TForm1.CheckBox1Click(Sender: TObject);
begin
  if not self.DirMonitor1.Active then
  begin
    form1.Caption:='Monitoring '+self.Edit2.Text;
    DirMonitor1.Directory:=self.Edit2.Text;
    DirMonitor1.Active:=true;
  end
  else DirMonitor1.Active:=false;
end;

end.
