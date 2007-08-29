unit MBarAnal;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Gauges, ComCtrls, SurfFile, StdCtrls, SurfTypes, Spin, Math, ExtCtrls,ShellApi,
  Z_timer, MPlayer;

const AD2DEG = 81.92;
      DEGPERSCREEN = 20 {+/- 20};

type
  TMBarForm = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Screen: TPanel;
    Guage: TGauge;
    StatusBar: TStatusBar;
    StopButton: TButton;
    Pause: TCheckBox;
    Delayed: TCheckBox;
    PlotPositions: TCheckBox;
    Display: TImage;
    TicSound: TCheckBox;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    lxpos: TLabel;
    lypos: TLabel;
    llen: TLabel;
    lwid: TLabel;
    lcon: TLabel;
    lori: TLabel;
    Label10: TLabel;
    ltime: TLabel;
    procedure StopButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormActivate(Sender: TObject);
  private
    { Private declarations }
    DisplayScale : single;
    lastx,lasty,lastlen,lastwid,lastori,lastcon,HalfSize : integer;
    HaltRead : boolean;
    Procedure UpdateStimulus(var stim : StimRec; timestamp : LNG; var x,y,blen,bwid,con,ori : integer);
    Procedure PlotBar(x,y,len,wid{all in pixels},ori {deg},con{?} : integer);
    Procedure PlotPixel(x,y,con : integer);
    Procedure Rotate(x,y,ori : integer; var pt : TPoint);
  public
    { Public declarations }
    Procedure Analyze(FileName : String);
    Procedure AcceptFiles( var msg : TMessage ); message WM_DROPFILES;
  end;

var
  MBarForm: TMBarForm;

implementation

{$R *.DFM}

{---------------------------------------------------------------------------}
procedure TMBarForm.AcceptFiles( var msg : TMessage );
const
  cnMaxFileNameLen = 255;var  i,  nCount     : integer;
  acFileName : array [0..cnMaxFileNameLen] of char;
begin
  // find out how many files we're accepting
  nCount := DragQueryFile( msg.WParam,$FFFFFFFF,acFileName,cnMaxFileNameLen );
  // query Windows one at a time for the file name
  for i := 0 to nCount-1 do
  begin
    DragQueryFile( msg.WParam, i, acFileName, cnMaxFileNameLen );
    // do your thing with the acFileName
    {MessageBox( Handle, acFileName, '', MB_OK );}
    Analyze(acFileName);
  end;
  // let Windows know that you're done
  DragFinish( msg.WParam );
end;

{---------------------------------------------------------------------------}
Procedure TMBarForm.Rotate(x,y,ori : integer; var pt : TPoint);
var theta,costheta,sintheta : single;
begin
  theta := ori * PI/180;
  costheta := cos(theta);
  sintheta := sin(theta);
  pt.x := round(x*costheta - y*sintheta);
  pt.y := round(x*sintheta + y*costheta);
 end;

{---------------------------------------------------------------------------}
Procedure TMBarForm.PlotBar(x,y,len,wid{all in pixels},ori {deg},con{?} : integer);
var pt : array[0..4] of TPoint;
    i : integer;
begin //plot the bar
  Rotate(-len div 2,-wid div 2,ori,pt[0]);
  Rotate(-len div 2,+wid div 2,ori,pt[1]);
  Rotate(+len div 2,+wid div 2,ori,pt[2]);
  Rotate(+len div 2,-wid div 2,ori,pt[3]);
  pt[4].x := pt[0].x;
  pt[4].y := pt[0].y;
  For i := 0 to 4 do
  begin
    pt[i].x := pt[i].x + x;
    pt[i].y := pt[i].y + y;
  end;

  Display.Canvas.Pen.Mode := pmXOR;
  Display.Canvas.Pen.Width := 1;
  if con > 0 then Display.Canvas.Pen.Color := clLIME
             else Display.Canvas.Pen.Color := clFUCHSIA;
  Display.Canvas.Brush.Color :=  Display.Canvas.Pen.Color;
  Display.Canvas.PolyGon(pt);

  lastx := x;
  lasty := y;
  lastlen := len;
  lastwid := wid;
  lastori := ori;
  lastcon := con;
end;

{---------------------------------------------------------------------------}
Procedure TMBarForm.PlotPixel(x,y,con : integer);
begin  //plot the point
  Display.Canvas.Pen.Mode := pmCopy;
  Display.Canvas.Pen.Width := 1;
  if plotpositions.Checked then
    if {(con > 0) and} (Display.Canvas.Pixels[x,y] = clBLACK)
      then Display.Canvas.Pixels[x,y] := clDkGray;//clLime
      //else Display.Canvas.Pixels[x,y] := clFuchsia;
end;

{---------------------------------------------------------------------------}
Procedure TMBarForm.UpdateStimulus(var stim : StimRec; timestamp : LNG; var x,y,blen,bwid,con,ori : integer);
begin
  x := round(HalfSize + Stim.Posx * DisplayScale);
  y := round(HalfSize - Stim.Posy * DisplayScale);
  blen := round((Stim.Len+2047) * DisplayScale);//length of bar in pixels
  bwid := round((Stim.Wid+2047) * DisplayScale);//width of bar in pixels
  con := Stim.Contrast;

  if Delayed.Checked and (lastx <> NOSTIMULUS) then PlotBar(lastx,lasty,lastlen,lastwid,lastori,lastcon);
  if plotpositions.checked then PlotPixel(x,y,con);
  if not Delayed.Checked then exit;
  PlotBar(x,y,blen,bwid,ori,con);

  lxpos.caption := FloatToStrF(Stim.Posx/AD2DEG,fffixed,4,2);
  lypos.caption := FloatToStrF(Stim.Posy/AD2DEG,fffixed,4,2);
  llen.caption := FloatToStrF((Stim.Len+2047)/AD2DEG,fffixed,4,2);
  lwid.caption := FloatToStrF((Stim.Wid+2047)/AD2DEG,fffixed,4,2);
  lcon.caption := inttostr(con);
  lori.caption := inttostr(ori);
  ltime.caption := inttostr(timestamp);
end;

{---------------------------------------------------------------------------}
Procedure TMBarForm.Analyze(FileName : String);
var
  ReadSurf : TSurfFile;
  e,pr,cl,i,x,y,tm,t,con,ori,len,wid,lasttm,maxtm : integer;
  w,lsb,msb : WORD;
begin
  ReadSurf := TSurfFile.Create;
  if not ReadSurf.ReadEntireSurfFile(FileName,FALSE{do not read the spike waveforms},FALSE{don't average waveforms}) then //this reads everything
  begin
    ReadSurf.Free;
    ShowMessage('Error Reading '+ FileName);
    Exit;
  end;

  Show;

  MBarForm.BringToFront;
  StatusBar.SimpleText := 'Filename : '+ Filename;

  HalfSize := Display.Width div 2;
  DisplayScale := HalfSize/(DEGPERSCREEN*AD2DEG);

  Display.Canvas.Brush.Color := clBLACK;
  Display.Canvas.FillRect(Display.ClientRect);
  Display.Canvas.Pen.Style := psDot;
  Display.Canvas.Pen.Color := clDkGray;
  Display.Canvas.MoveTo(0,HalfSize);
  Display.Canvas.LineTo(Display.Width,HalfSize);
  Display.Canvas.MoveTo(HalfSize,0);
  Display.Canvas.LineTo(HalfSize,Display.Height);
  Display.Canvas.Pen.Style := psSolid;

  //tic.open;
  //tic.wait := FALSE;
  x := NOSTIMULUS;
  y := NOSTIMULUS;
  lastx := NOSTIMULUS;
  lasttm := -1;
  HaltRead := FALSE;
  With ReadSurf do
  begin
    // Now read the data using the event array
    Guage.MinValue := 0;
    Guage.MaxValue := Length(Stimulus.Time)-1;

    ori := 0;
    maxtm := Length(Stimulus.Time)-1;
    For e := 0 to NEvents-1 do
    begin
      //Figure out what the stimulus was doing
      tm := round(Event[e].Time_Stamp * Stimulus.TimeDiv);
      if tm > maxtm then tm := maxtm;
      //if there were any stimuli before this event, update the stimulus window and values
      if tm > lasttm  then
        for t := lasttm+1 to tm do
          if Stimulus.Time[t].Posx <> NOSTIMULUS then
             UpdateStimulus(Stimulus.Time[t],round(t/Stimulus.TimeDiv),x,y,len,wid,con,ori);
      lasttm := tm;
      //get fetch the event
      i := Event[e].Index;
      pr := Event[e].Probe;
      case Event[e].EventType of
        SURF_PT_REC_UFFTYPE {'N'}: //handle spikes and continuous records
          case Event[e].subtype of
            SPIKETYPE  {'S'}:
              begin //spike record found
                cl := prb[pr].spike[i].cluster;
                if (x<>NOSTIMULUS) and (y<>NOSTIMULUS) then
                begin
                   Display.Canvas.Pen.Mode := pmCopy;
                   Display.Canvas.Pen.Color := clRed;//COLORTABLE[cl];
                   Display.Canvas.Rectangle(x-1,y-1,x+1,y+1);
                   //if Delayed.Checked and TicSound.Checked then tic.play;
                end;
              end;
          end;
        SURF_SV_REC_UFFTYPE {'V'}: //handle single values (including digital signals)
          case Event[e].subtype of
            SURF_DIGITAL {'D'}:
              begin
                w := sval[i].sval;
                msb := w and $00FF; //get the last byte of this word
                lsb := w shr 8;      //get the first byte of this word
                ori := (msb and $01) shl 8 + lsb; {get the last bit of the msb}
              end;
          end;
        SURF_MSG_REC_UFFTYPE {'M'}://handle surf messages
          begin
            ShowMessage(Msg[i].Msg);
            StatusBar.SimpleText := Msg[i].Msg;
          end;
      end {case};

      If Delayed.Checked then
      begin
        Application.ProcessMessages;
        Guage.Progress := tm;
      end;

      While pause.checked do
      begin
        Application.ProcessMessages;
        if HaltRead then break;
      end;
      if HaltRead then break;
    end;
  end;
  //tic.close;

  Guage.Progress := 0;

  ReadSurf.CleanUp;
  ReadSurf.Free;
end;


procedure TMBarForm.StopButtonClick(Sender: TObject);
begin
  HaltRead := TRUE;
end;

procedure TMBarForm.FormCreate(Sender: TObject);
begin
  DragAcceptFiles( Handle, True );
end;

procedure TMBarForm.FormActivate(Sender: TObject);
begin
  if ParamCount > 0 then
    Analyze(paramStr(1));
end;

end.