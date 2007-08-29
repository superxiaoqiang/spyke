unit EnterGain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls;

type
  TEnterGainForm = class(TForm)
    OKBtn: TButton;
    CancelBtn: TButton;
    Label1: TLabel;
    GainEdit: TEdit;
    procedure CancelBtnClick(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
    gainstr : string;
    ok : boolean;
  public
    { Public declarations }
    min,max : single;
  end;

var
  EnterGainForm: TEnterGainForm;

implementation

{$R *.DFM}

procedure TEnterGainForm.CancelBtnClick(Sender: TObject);
begin
  Close;
end;

procedure TEnterGainForm.OKBtnClick(Sender: TObject);
var f : single;
    i : integer;
    isf : boolean;
begin
  isf := TRUE;
  for i := 1 to Length(GainEdit.Text) do
    if not (GainEdit.Text[i] in ['0'..'9','.']) then isf := FALSE;
  if isf
    then f := StrToFloat(GainEdit.Text)
    else f := -1;
  if (f >= Min) and (f <= MAX) then ok := TRUE;//within range
  Close;
end;

procedure TEnterGainForm.FormActivate(Sender: TObject);
begin
  ok := FALSE;
  GainStr := GainEdit.Text;
end;

procedure TEnterGainForm.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  if not ok then
    GainEdit.Text := GainStr;
end;

end.