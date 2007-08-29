unit EEGUnit;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  OleCtrls, StdCtrls, ExtCtrls, DTxPascal, DTAcq32Lib_TLB, DTPlot32Lib_TLB,
  ComCtrls, ToolWin, ImgList, Math, SurfMathLibrary;

const MAGMAX = 10000;
      MAGMIN = 0;
      FRQMIN = 1;
      FRQMAX = 150;
      FFTSIZE = 8192;
      BUFFERSIZE = 10000;
      SPECTRUM_BITMAP_WIDTH = 2000; //in pixels, enough for ~5hrs EEG
      SPECTRUM_XAXIS_SPACER = 15;
      SPECTRUM_TITLE_HEIGHT = 22;
type
  TWaveform = array of SHRT;
  TEEGWin = class(TForm)
    ScrollBar: TScrollBar;
    ToolBar: TToolBar;
    tbStartStop: TToolButton;
    tbSave: TToolButton;
    tbLUT: TToolButton;
    tbIcons: TImageList;
    ScaleBar: TImage;
    Spectrum: TImage;
    SaveGifDialog: TSaveDialog;
    StatusBar1: TStatusBar;
    procedure FormShow(Sender: TObject);
    procedure ScrollBarChange(Sender: TObject);
    procedure tbSaveClick(Sender: TObject);
    procedure tbLUTClick(Sender: TObject);
    procedure tbStartStopClick(Sender: TObject);
    procedure EEGPlotDblClick(Sender: TObject);
    procedure SpectrumMouseDown(Sender: TObject; Button: TMouseButton;
                Shift: TShiftState; X, Y: Integer);
    procedure SpectrumMouseUp(Sender: TObject; Button: TMouseButton;
                Shift: TShiftState; X, Y: Integer);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure SpectrumMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure SpectrumClick(Sender: TObject);
  private
    EEGBuffer : array [1..BUFFERSIZE] of TReal32; //nb. 1-based {TReal32Array open dynarr}
    Spectrumbm, Scalebm: TBitmap;
    LUT   : array[byte] of TRGBQuad;
    SamplesInBuffer : integer;
    SpectrumXIndex : integer;
    Freq2YPixel : single;
    SpectrumHintWindow : THintWindow;
    LeftButtonDown : boolean;
    procedure ResetSpectrumBitmap;
    procedure DrawScaleBar;
    procedure GScaleLUT(idxmin, idxmax : byte;
                        var c: array of TRGBQuad);
    procedure SpectrumLUT(idxmin, idxmax : byte;
                          var c: array of TRGBQuad);
    procedure FireLUT(idxmin, idxmax : byte;
                      var c: array of TRGBQuad);
    procedure SaveSpectrogram(Filename : string);
    procedure DrawDateTime;
    procedure DrawArrow(ArrowHeadXY : TPoint; Colour : TColor);
    //procedure LogFreq2ScreenY(const freqmin, freqmax, ypixels : integer);
    {procedure LogMagScreenY(); .... precompute log scales into corresponding pixel coords}
    { Private declarations }
  public
    Channel, SampleFreq, TotalGain : integer;
    Running : boolean;
    function UpdateEEG(const ADCBuffer : {LPUSHRT array of word} TWaveform; NumSamples : integer) : boolean; {success/failure}
    procedure DrawLabelMarker(ArrowColour : TColor = clWhite; LabelLine1 : string = '';
                              LabelLine2 : string = '');
    { Public declarations }
  end;

implementation

uses GIFImage; {include others from interface in here too?}

{$R *.DFM}

{-------------------------------------------------------------------------}
procedure TEEGWin.FormShow(Sender: TObject);
begin
  Scalebm:= TBitmap.Create;
  DrawScaleBar;
  GScaleLUT(0, 255, LUT); //set default LUT to grayscale...
  SetDIBColorTable(Scalebm.Canvas.Handle, 0, 256, LUT);
  ScaleBar.Canvas.Draw(0, 0, Scalebm);
  {Should be able to free this bm here (except Invalidate() doesn't appear to update palette)

  {initialise bitmap for spectrogram}
  SpectrumXIndex:= SPECTRUM_XAXIS_SPACER; {leaves space for y-axis frequency labels}
  Spectrumbm:= TBitmap.Create;
  ResetSpectrumBitmap;
  DrawDateTime;
  SetDIBColorTable(Spectrumbm.Canvas.Handle, 0, 256, LUT);
  Spectrum.Canvas.Draw(- ScrollBar.Position, 0, Spectrumbm);

  Caption:= 'EEG spectrogram (ch ' + inttostr(Channel) + ')';
  SaveGifDialog.FileName:= Caption; //default gif filename
  SpectrumHintWindow:= THintWindow.Create(Self);
  SpectrumHintWindow.Color := clInfoBk;
  SpectrumHintWindow.Font.Size:= 8;
  ScrollBar.Max:= Spectrumbm.Width - Spectrum.Width;
  SamplesInBuffer:= 1;
  Running:= True;
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.DrawScaleBar;
var x, y : integer;
  Row    : pByteArray;
  ColrIdx: byte;
begin
  Scalebm.Width  := ScaleBar.Width;
  Scalebm.Height := ScaleBar.Height;
  Scalebm.PixelFormat:= pf8bit;
  for y:= 0 to Scalebm.Height - 1 do
  begin
    Row:= Scalebm.ScanLine[y];
    ColrIdx:= Round(1 + y * 255/Scalebm.Height);
    for x:= 0 to Scalebm.Width - 1 do
      Row[x]:= 255 - ColrIdx;
  end;
  {draw log10(magnitude) y-axis labels}
  with Scalebm.Canvas do
  begin
    Brush.Style:= bsClear;
    Font.Name:= 'Small Fonts';
    Font.Size:= 5;
    Font.Color:= $00000000;
    for y:= 0 to 4 do
    begin
      if y = 2 then Font.Color:= $00FFFFFF;
      TextOut(0, Round((Scalebm.Height - 2 * Font.Size) / 4 * y),
              FloattoStrF((MAGMAX - MAGMIN) / Power(10, y), ffExponent, 1, 1));
    end;
  end;
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.ResetSpectrumBitmap;
var y : integer;
  Row : pByteArray;
begin
  with Spectrumbm do
  begin
    Width:= SPECTRUM_BITMAP_WIDTH;
    Height:= Spectrum.Height;
    PixelFormat:= pf8bit;
    Canvas.Brush.Color:= $00000000; //black, regardless of LUT
    Canvas.FillRect(Rect(0, 0, Spectrumbm.Width, Spectrumbm.Height));
    Canvas.Font.Color:=$00FFFFFF; //white, regardless of LUT
    Canvas.Font.Name:= 'Small Fonts';
    Canvas.Font.Size:= 5;
    {draw y-axis freq ticks: linear spacing}
    Freq2YPixel:= (Height-SPECTRUM_TITLE_HEIGHT) / (FRQMAX - FRQMIN);
    y:= 50;
    while y < FRQMAX + 1 do
    begin
      Canvas.TextOut(SPECTRUM_XAXIS_SPACER - Canvas.TextWidth(InttoStr(y)) - 3,
                     Height - Round(y * Freq2YPixel) + Canvas.Font.Height div 2 - 2,
                     InttoStr(y));
      Row:= ScanLine[Height - Round(y * Freq2YPixel) - 1];
      Row[SPECTRUM_XAXIS_SPACER - 2]:= $FF;
      Row[SPECTRUM_XAXIS_SPACER - 1]:= $FF;
      Inc(y, 50); {tick markers every 50Hz}
    end;
    Canvas.TextOut(3, Height - 10, 'Hz');
  end;
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.ScrollBarChange(Sender: TObject);
begin
  Spectrum.Canvas.Draw(- ScrollBar.Position, 0, Spectrumbm);
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.GScaleLUT(idxmin, idxmax : byte;
                            var c: array of TRGBQuad);
{Generates an 8 bit 'Grayscale' LUT given the range [idxmin, idxmax]
 In this case each colour component ranges from 0 (no contribution) to
 255 (fully saturated); modifications for other ranges is trivial.}
var index : integer;
begin
  for index := idxmin to idxmax do
    with LUT[index] do
    begin
      rgbBlue     := index;
      rgbGreen    := index;
      rgbRed      := index;
      rgbReserved := 0;
    end;
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.FireLUT(idxmin, idxmax : byte;
                          var c: array of TRGBQuad);
{Generates an 8-bit 'Fire' LUT given the range [idxmin, idxmax]
 In this case each colour component ranges from 0 (no contribution) to
 255 (fully saturated); modifications for other ranges is trivial.}
var
  dv : Single;
  index : integer;
begin
  dv:= idxmax - idxmin;
  for index:= idxmin to idxmax do
    with c[index] do
    begin
      if index < (idxmin + dv/3) then
      begin
        rgbRed:= Round((3 * (index - idxmin) / dv)* 255);
        rgbGreen:= 0;
        rgbBlue := 0;
      end else if index < (idxmin + dv*2/3) then
      begin
        rgbRed  := 255;
        rgbGreen:= Byte(Round((3 * (1 + idxmin + dv/3 + index) / dv) * 255));
        rgbBlue := 0;
      end else
      begin
        rgbBlue:= Byte(Round((3 * (1 + index - idxmin + dv/3) / dv) * 255));
        rgbRed:= 255;
        rgbGreen:= 255;
      end;
      rgbReserved := 0;
    end;
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.SpectrumLUT(idxmin, idxmax : byte;
                              var c: array of TRGBQuad);
{Generates an 8 bit 'Rainbow' LUT given the range [idxmin, idxmax]
 In this case each colour component ranges from 0 (no contribution) to
 255 (fully saturated); modifications for other ranges is trivial.}
var
  dv : Single;
  index : integer;
begin
  dv:= idxmax - idxmin;
  for index:= idxmin to idxmax do
    with c[index] do
    begin
      if index < (idxmin + 0.25 * dv) then
      begin
        rgbRed  := 0;
        rgbGreen:= Byte(Round((4 * (index - idxmin) / dv) * 255));
        rgbBlue := 255;
      end else if index < (idxmin + 0.5 * dv) then
      begin
        rgbRed  := 0;
        rgbGreen:= 255;
        rgbBlue := Byte(Round((4 * (idxmin + 0.25 * dv - index) / dv) * 255));
      end else if index < (idxmin + 0.75 * dv) then
      begin
        rgbRed  := Byte(Round((4 * (index - idxmin - 0.5 * dv) / dv) * 255));
        rgbGreen:= 255;
        rgbBlue := 0;
      end else
      begin
        rgbRed  := 255;
        rgbGreen:= Byte(Round((4 * (idxmin + 0.75 * dv - index) / dv) * 255));
        rgbBlue := 0;
      end;
      rgbReserved := 0;
    end;
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.tbStartStopClick(Sender: TObject);
begin
  DrawDateTime;
  Running:= not Running;
  if Running then
  begin
    tbStartStop.ImageIndex:= 1;
    tbStartStop.Hint:= 'Stop';
  end else
  begin
    tbStartStop.ImageIndex:= 0;
    tbStartStop.Hint:= 'Start';
    inc(SpectrumXIndex, 30); //insert spacer in spectrogram

    //RESET BUFFERINDEX HERE, SO UPON RESTART A VALID FFT IS EXECUTED

  end;
  if (SpectrumXIndex - ScrollBar.Position) > Spectrum.Width then ScrollBar.Position:= ScrollBar.Position + 15
    else Spectrum.Canvas.Draw(- ScrollBar.Position, 0, Spectrumbm); //refresh window
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.tbSaveClick(Sender: TObject);
begin
  if SaveGifDialog.Execute then
    SaveSpectrogram(SaveGifDialog.FileName)
  else ShowMessage('Spectrogram not saved.');
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.tbLUTClick(Sender: TObject);
begin
  tbLUT.Tag:= (tbLUT.Tag + 1) mod 3; //toggle 3 button states
  case tbLUT.Tag of
    0 : GScaleLUT(0, 255, LUT);
    1 : FireLUT(0, 255, LUT);
    2 : SpectrumLUT(1, 254, LUT); //keep black ($00) and white ($FF) for labels
  end;
  SetDIBColorTable(Scalebm.Canvas.Handle, 0, 256, LUT);
  ScaleBar.Canvas.Draw(0, 0, Scalebm);
  SetDIBColorTable(Spectrumbm.Canvas.Handle, 0, 256, LUT);
  Spectrum.Canvas.Draw(- ScrollBar.Position, 0, Spectrumbm);
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.EEGPlotDblClick(Sender: TObject);
begin
  {freeze display}
end;

{-------------------------------------------------------------------------}
{procedure TEEGWin.LogFreq2ScreenY(const freqmin, freqmax, ypixels : integer);
begin
//  for i := 0 to MAXFREQ do //generats LUT to optimise spectrum plotting
//    ScreenY[i] := Round((i-2047)/2047 * ScaledWaveformHeight);
end;
}

{-------------------------------------------------------------------------}
function TEEGWin.UpdateEEG(const ADCBuffer : {LPUSHRT array of word} TWaveform; NumSamples : integer) : boolean; {success/failure}
var y, idx : integer;
  Row : PByteArray;
  OutFile : Textfile;
  EEGBuffPtr : LPReal32;
begin
  Result:= False;
  if not Running then Exit;
  EEGBuffPtr:= @EEGBuffer[SamplesInBuffer];
  Input2Volts(@ADCBuffer, 12{bit}, TotalGain, EEGBuffPtr);
  inc(SamplesInBuffer, NumSamples);
  if SamplesInBuffer >= FFTSIZE then
  begin
//    AssignFile(OutFile, 'C:\Desktop\Test FFT.csv');
//    Rewrite(OutFile); //overwrites any existing file of the same name
    RealFFT(EEGBuffer, FFTSIZE, 1);

    {average/smooth FFT}

    {add line to Spectrogram}
    idx:= 1;
    for y:= SPECTRUM_TITLE_HEIGHT to Spectrumbm.Height-1 do
    begin
      row:= Spectrumbm.ScanLine[y];
      row[SpectrumXIndex]:= {Random(256);}Byte(Round(EEGBuffer[idx]*255));{fft value, scale 0-255}
      inc(idx{,2?});
    end;

    {update spectrogram/scrollwindow}
    if (SpectrumXIndex - ScrollBar.Position) > Spectrum.Width then ScrollBar.Position:= ScrollBar.Position + 1
      else Spectrum.Canvas.Draw(- ScrollBar.Position, 0, Spectrumbm);
    {o/l plot of most recent FFT}

    SamplesInBuffer:= 1; //reset index, discarding 'excess' samples (810, assuming 1000/block)
    //SamplesInBuffer:= (SamplesInBuffer mod FFTSIZE) + 1; //wrap buffer data pointer...
    //Move(EEGBuffer[FFTSIZE{+1?}], EEGBuffer[1], SizeOf(TReal32)*SamplesInBuffer); //...move 'spilled' data to start of buffer
    //Showmessage(inttostr(SamplesInBuffer));

    idx:= 1;
    while idx < High(EEGBuffer) div 2 do
    begin
      Writeln(OutFile, floattostr(EEGBuffer[idx]));
      inc(idx{, 2?});
    end;
    CloseFile(OutFile);

    inc(SpectrumXIndex);
    if SpectrumXIndex = Spectrumbm.Width then
    begin //bitmap full, cue user to save to file as gif...
      tbSaveClick(Self);
      SpectrumXIndex:= SPECTRUM_XAXIS_SPACER;
      ResetSpectrumBitmap;
      DrawDateTime;
      ScrollBar.Position:= 0;
    end;
  end;
  Result:= True;
end;
{-------------------------------------------------------------------------}
procedure TEEGWin.SpectrumMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    LeftButtonDown:= True;
    Screen.Cursor:= crCross;
  end;
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.SpectrumMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var Frequency : integer;
begin
if not LeftButtonDown then Exit;
  Frequency:= Round((Spectrum.Height - Y) / Freq2YPixel);
  if (X - SPECTRUM_XAXIS_SPACER < FRQMIN) or (Frequency > FRQMAX) then Exit;
  SpectrumHintWindow.ActivateHint(Rect(Mouse.CursorPos.x + 3, Mouse.CursorPos.y - 18,
                                  Mouse.CursorPos.x + 60, Mouse.CursorPos.y - 5),
                                  Inttostr(Frequency) + 'Hz, �V2');
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.SpectrumMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  LeftButtonDown:= False;
  SpectrumHintWindow.ReleaseHandle;
  Screen.Cursor:= crDefault;
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.SaveSpectrogram(Filename : string);
var SpectbmCopy : TBitmap;
begin
  SpectbmCopy:= TBitMap.Create;
  try
    with SpectbmCopy do
    begin
      Assign(Spectrumbm);//make temporary copy of bitmap, as SaveToFile modifies DIB
      Dormant;
      FreeImage;
      Width:= SpectrumXIndex; //shrink width of saved image;
      Canvas.Draw(SpectrumXIndex - Scalebm.Width, Spectrum.Height - Scalebm.Height, Scalebm); //add scalebar
    end;
    SaveToFileSingle(Filename, SpectbmCopy, False, False, 0);
  finally
    FreeAndNil(SpectbmCopy);
  end;
  //SetDIBColorTable(Spectrumbm.Canvas.Handle, 0, 256, LUT);
end;
{-------------------------------------------------------------------------}
procedure TEEGWin.DrawDateTime;
begin
  DrawLabelMarker(clWhite, FormatDateTime('d/m/y', Now), FormatDateTime('h:mmAM/PM', Now));
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.DrawLabelMarker(ArrowColour : TColor ; LabelLine1 : string;
                                  LabelLine2 : string);
var ArrowHead : TPoint;
begin
  ArrowHead.x:= SpectrumXIndex;
  ArrowHead.y:= 21;
  with Spectrumbm.Canvas do
  begin
    if LabelLine2 = '' then {only bottom line to display}
      TextOut(SpectrumXIndex - (TextWidth(LabelLine1)div 2), 7, LabelLine1)
    else begin
      TextOut(SpectrumXIndex - (TextWidth(LabelLine1)div 2), 0, LabelLine1);
      TextOut(SpectrumXIndex - (TextWidth(LabelLine2)div 2), 7, LabelLine2);
    end;
    DrawArrow(ArrowHead, ArrowColour);
  end;
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.DrawArrow(ArrowHeadXY : TPoint; Colour : TColor);
const Arrow : array[0..3] of TPoint = ((x: -2; y: -2), (x: 2; y: -2),
                                       (x: 0; y: 0), (x: 0; y: -7));
var i : integer;
begin
  with Spectrumbm.Canvas do
  begin
    Pen.Color:= Colour;
    MoveTo(ArrowHeadXY.x, ArrowHeadXY.y);
    for i:= 0 to High(Arrow) do
      LineTo(ArrowHeadXY.x + Arrow[i].x, ArrowHeadXY.y + Arrow[i].y);
  end;
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.SpectrumClick(Sender: TObject);
var i : integer; ADCBuffer : array [0..999] of Word; //TEMPORARY!
begin
 { for i:= low(ADCBuffer) to high(ADCBuffer) do
    ADCBuffer[i]:= 2048 + Round(cos(i/16*pi)*400 + sin(i/4*pi)*300 + sin(i/8*pi)*500); //dummy waveform to test RealFFT
  UpdateEEG(ADCBuffer, 1000); }
end;

{-------------------------------------------------------------------------}
procedure TEEGWin.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  {other things to free?}
  Scalebm.Free;
  Spectrumbm.Free;
  Action:= caFree;
end;

end.
