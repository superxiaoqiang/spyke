unit SurfAcq;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, extctrls, Forms, Dialogs,
  SurfTypes,SurfPublicTypes,SurfShared;


type
  TSurfSpikeEvent = Procedure(Spike : TSpike) of Object;
  TSurfCrEvent = Procedure(Cr : TCr) of Object;
  TSurfSVEvent = Procedure(SV : TSVal) of Object;
  TSurfMsgEvent = Procedure(Msg : TSurfMsg) of Object;

  TSurfAcq = class(TPanel{WinControl})
  private
    { Private declarations }
    FOnSpike: TSurfSpikeEvent;
    FOnCr: TSurfCrEvent;
    FOnSV: TSurfSVEvent;
    FOnSurfMsg: TSurfMsgEvent;

    NumMsgs,ReadIndex : Integer;
    GlobData   : PGlobalDLLData;

    SurfParentExists,ReceivingFile : boolean;
    SurfHandle : THandle;
    SurfFile : TSurfFileInfo;//can be huge!

    Procedure OnAppMessage(var Msg: TMsg; var Handled : Boolean);
     Function NextWritePosition(size : integer) : integer;
    Procedure WriteToBuffer(data : pchar; buf : pchar; size : integer; var writeindex : integer);
    Procedure ReadFromBuffer(data : pchar; buf : pchar; size : integer; var readindex : integer);

    //Procedures for SurfAcq
    //Procedure GetProbeFromSurf(var Probe : TProbe; ReadIndex : Integer);
    Procedure GetSpikeFromSurf(var Spike : TSpike; ReadIndex : integer);
    Procedure GetCrFromSurf(var Cr : TCr; ReadIndex : integer);
    Procedure GetSValFromSurf(var SVal : TSVal; ReadIndex : integer);
    Procedure GetMsgFromSurf(var SurfMsg : TSurfMsg; ReadIndex : integer);
    //Procedure GetSurfEventFromSurf(var SurfEvent : TSurfEvent; ReadIndex : integer);
  protected
    { Protected declarations }
  public
    { Public declarations }
    Constructor Create(AOwner: TComponent); Override;
    Destructor  Destroy; Override;
    //Methods
    Procedure SendSpikeToSurf(Spike : TSpike);
    Procedure SendSVToSurf(Sval : TSVal); //for digital out
    Procedure SendDACToSurf(DAC : TDAC);  //for digital analog out (DAC)
    Procedure SendDIOToSurf(DIO : TDIO);  //for digital outpout (DIO)
  published
    { Published declarations }
    //Events
    property OnSpike: TSurfSpikeEvent read FOnSpike write FOnSpike;
    property OnCR: TSurfCREvent read FOnCR write FOnCr;
    property OnSV: TSurfSVEvent read FOnSV write FOnSV;
    property OnSurfMsg: TSurfMsgEvent read FOnSurfMsg write FOnSurfMsg;
    //property OnProbe: TSurfProbeEvent read FOnProbe write FOnProbe;
  end;

procedure Register;
{ Define the DLL's exported procedure }
procedure GetDLLData(var AGlobalData: PGlobalDLLData); StdCall External 'C:\Surf\Application\ShareLib.dll';

implementation

procedure Register;
begin
  RegisterComponents('SURF', [TSurfAcq]);
end;

Destructor TSurfAcq.Destroy;
var s,c,w,p : integer;
begin
  if (csDesigning in ComponentState) then exit;
  Inherited Destroy;
  SurfFile.SurfEventArray := nil;
  SurfFile.SValArray := nil;
  SurfFile.SurfMsgArray := nil;
  For p := 0 to Length(SurfFile.ProbeArray)-1 do
  begin
    For s := 0 to Length(SurfFile.ProbeArray[p].Spike)-1 do
    begin
      SurfFile.ProbeArray[p].Spike[s].Param := nil;
      For w := 0 to Length(SurfFile.ProbeArray[p].Spike[s].WaveForm)-1 do
        SurfFile.ProbeArray[p].Spike[s].WaveForm[w] := nil;
      SurfFile.ProbeArray[p].Spike[s].WaveForm := nil;
    end;
    SurfFile.ProbeArray[p].Spike := nil;
    For c := 0 to Length(SurfFile.ProbeArray[p].Cr)-1 do
      SurfFile.ProbeArray[p].Cr[c].WaveForm := nil;
    SurfFile.ProbeArray[p].Cr := nil;
  end;
  SurfFile.ProbeArray := nil;
end;

{-----------------------------------------------------------------------------}
Constructor TSurfAcq.Create(AOwner: TComponent);
begin
  Inherited Create(AOwner);
  Height := 28;
  Width := 85;
  Color := $0028799B;
  Font.Color := clWhite;
  caption := 'SURF Aqusition';

  //don't process anymore if just designing
  if (csDesigning in ComponentState) then exit;
  Visible := FALSE;
  ReadIndex := 0;

  //if running in standalone then getoutahere
  if ParamCount<>2 then //Looking for version info and Surf's handle
  begin
    beep;
    ShowMessage('SurfAcq will only run when the application is called from Surf.');
    Halt;
  end else
  begin
    if ParamStr(1) = 'SURFv1.0' then  //got the surf version
    begin
      ReceivingFile := FALSE;
      SurfHandle := strtoint(ParamStr(2)); //and now the handle
      if SurfHandle > 0 then SurfParentExists := TRUE;
      GetDllData(GlobData);
      //Intercept applicaiton messages and send them to SurfBridge message handler
      Application.OnMessage := OnAppMessage; //intercepts postmessages
      PostMessage(SurfHandle,WM_SURF_IN,SURF_IN_HANDLE,(AOwner as TForm).Handle);//send it back to Surf
    end;
  end;
end;

{-----------------------------------------------------------------------------}
Procedure TSurfAcq.OnAppMessage(var Msg: TMsg; var Handled : Boolean);
var Spike : TSpike;
    Cr : TCr;
    SVal : TSVal;
    SurfMsg : TSurfMsg;
    //SurfEvent : TSurfEvent;
    //SurfEventArray : TSurfEventArray;
    //SpikeArray : TSpikeArray;
    //CrArray : TCrArray;
    //SValArray : TSValArray;
    //SurfMsgArray : TSurfMsgArray;
    //Probe : TProbe;
    c,ReadIndex : integer;
begin
  Handled := FALSE;
  if Msg.Message <> WM_SURF_OUT
    then exit//only handle those messages from surf
    else Handled := TRUE; //intercept
  ReadIndex := Msg.LParam;
  inc(NumMsgs);
  Case Msg.WParam of
    SURF_OUT_SPIKE    :    begin
                             GetSpikeFromSurf(Spike,ReadIndex);
                             if Assigned(FOnSpike) then //see if user is actually calling this method
                               FOnSpike(Spike); //send it to user
                             //this unit is responsible for clearing the spike memory
                             For c := 0 to Length(Spike.WaveForm)-1 do
                               Spike.waveform[c] := nil;
                             Spike.waveform := nil;
                             Spike.param := nil;
                           end;
    SURF_OUT_CR       :    begin
                             GetCRFromSurf(Cr,ReadIndex);
                             if Assigned(FOnCR) then //see if user is actually calling this method
                               FOnCr(Cr); //send it to user
                             //this unit is responsible for clearing the waveform memory
                             Cr.waveform := nil;
                           end;
    SURF_OUT_SV       :    begin
                             GetSValFromSurf(SVal,ReadIndex);
                             if Assigned(FOnSv) then //see if user is actually calling this method
                               FOnSv(SVal); //send it to user
                           end;
    SURF_OUT_MSG       :   begin
                             GetMsgFromSurf(SurfMsg,ReadIndex);
                             if Assigned(FOnSurfMsg) then //see if user is actually calling this method
                                FOnSurfMsg(SurfMsg); //send it to user
                           end;

  end{case};
end;

{========================= WRITING FUNCTIONS ==================================}
Function TSurfAcq.NextWritePosition(size : integer) : integer;
var i : integer;
begin
  While GlobData^.Writing do;//pause if another process is currently writing
  GlobData^.Writing := TRUE;
  i := GlobData^.WriteIndex;
  if (i + size) > GLOBALDATARINGBUFSIZE-1 {wrap around}
    then i := 0;
  GlobData^.WriteIndex := i + size;
  RESULT := i;
  GlobData^.Writing := FALSE;
end;

Procedure TSurfAcq.WriteToBuffer(data : pchar; buf : pchar; size : integer; var writeindex : integer);
begin
  Move(data^,buf^,size);
  inc(writeindex,size);
end;
{----------------------------- SEND SPIKE ------------------------------------}
Procedure TSurfAcq.SendSpikeToSurf(Spike : TSpike);
var origindex,curindex : integer;
    size,c : integer;
    bufdesc : TBufDesc;
begin
  GetDllData(GlobData);

  bufdesc.d1{nchans} := Length(Spike.Waveform);
  bufdesc.d2{npts} := Length(Spike.Waveform[0]);
  bufdesc.d3{nparams} := Length(Spike.Param);

  Size :=  sizeof(TBufDesc) //desc info
         + sizeof(TSpike) - 8 {the waveform and param pointers}
         + bufdesc.d1 * bufdesc.d2*2 //the waveform
         + bufdesc.d3*2;  //the parameters

  CurIndex := NextWritePosition(size);
  origindex := curindex;

  //copy the spike to the global data array
  WriteToBuffer(@Spike,@GlobData^.data[curindex],sizeof(Spike) - 8,curindex);
  WriteToBuffer(@bufdesc,@GlobData^.data[curindex],sizeof(TBufDesc),curindex);
  For c := 0 to bufdesc.d1-1 do
    WriteToBuffer(@Spike.WaveForm[c,0],@GlobData^.data[curindex],bufdesc.d2*2,curindex);
  WriteToBuffer(@Spike.Param[0],@GlobData^.data[curindex],bufdesc.d3*2,curindex);

  //tell surf it is there
  PostMessage(SurfHandle,WM_SURF_IN,SURF_IN_SPIKE,origindex);
end;
{------------------------- SEND SV  ----------------------------------------}
Procedure TSurfAcq.SendSVToSurf(SVal : TSVal);
var origindex,curindex : integer;
    size : integer;
begin
  Size := sizeof(TSVal); //the sv record
  //get the next write position
  CurIndex := NextWritePosition(size);
  origindex := curindex;

  //copy the sv to the global data array
  WriteToBuffer(@SVal,@GlobData^.data[curindex],size,curindex);
  //tell surf it is there
  PostMessage(SurfHandle,WM_SURF_IN,SURF_IN_SV,origindex);
end;

{------------------------- SEND DAC  ----------------------------------------}
Procedure TSurfAcq.SendDACToSurf(DAC : TDAC);
var origindex,curindex : integer;
    size : integer;
begin
  Size := sizeof(TDAC); //the sv record
  //get the next write position
  CurIndex := NextWritePosition(size);
  origindex := curindex;

  //copy the DAC to the global data array
  WriteToBuffer(@DAC,@GlobData^.data[curindex],size,curindex);
  //tell surf it is there
  PostMessage(SurfHandle,WM_SURF_IN,SURF_IN_DAC,origindex);
end;

{------------------------- SEND DIO  ----------------------------------------}
Procedure TSurfAcq.SendDIOToSurf(DIO : TDIO);
var origindex,curindex : integer;
    size : integer;
begin
  Size := sizeof(TDIO); //the sv record
  //get the next write position
  CurIndex := NextWritePosition(size);
  origindex := curindex;

  //copy the DAC to the global data array
  WriteToBuffer(@DIO,@GlobData^.data[curindex],size,curindex);
  //tell surf it is there
  PostMessage(SurfHandle,WM_SURF_IN,SURF_IN_DIO,origindex);
end;

{========================= READING FUNCTIONS ==================================}
Procedure TSurfAcq.ReadFromBuffer(data : pchar; buf : pchar; size : integer; var readindex : integer);
begin
  Move(buf^,data^,size);
  inc(readindex,size);
end;

{------------------------  GET PROBE ------------------------------------------}
(*Procedure TSurfAcq.GetProbeFromSurf(var Probe : TProbe; ReadIndex : Integer);
var pc : array[0..31] of char;
    i : integer;
begin
  ReadFromBuffer(@Probe,@GlobData^.data[readindex],sizeof(TProbe),readindex);
  SetLength(Probe.paramname,probe.numparams);
  for i := 0 to probe.numparams -1 do
  begin
    ReadFromBuffer(@pc,@GlobData^.data[readindex],32,readindex);
    Probe.ParamName[i] := pc;
  end;
  Probe.Spike := nil;
  Probe.Cr := nil;
end;*)

{------------------------  GET SPIKE ------------------------------------------}
Procedure TSurfAcq.GetSpikeFromSurf(var Spike : TSpike; ReadIndex : integer);
var bufdesc : TBufDesc;
    c : integer;
begin
  ReadFromBuffer(@Spike,@GlobData^.data[readindex],sizeof(TSpike)-8,readindex);
  ReadFromBuffer(@bufdesc,@GlobData^.data[readindex],sizeof(TBufDesc),readindex);
  SetLength(Spike.waveform,bufdesc.d1{nchans});
  For c := 0 to bufdesc.d1{nchans}-1 do
  begin
    SetLength(Spike.WaveForm[c],bufdesc.d2{npts});
    ReadFromBuffer(@Spike.WaveForm[c,0],@GlobData^.data[readindex],bufdesc.d2{npts}*2,readindex);
  end;
  ReadFromBuffer(@Spike.Param[0],@GlobData^.data[readindex],bufdesc.d3{nparams}*2,readindex);
end;

{------------------------  GET CR ------------------------------------------}
Procedure TSurfAcq.GetCrFromSurf(var Cr : TCr; ReadIndex : integer);
var bufdesc : TBufDesc;
begin
  ReadFromBuffer(@Cr,@GlobData^.data[readindex],sizeof(Cr)-4,readindex);
  ReadFromBuffer(@bufdesc,@GlobData^.data[readindex],sizeof(TBufDesc),readindex);
  SetLength(Cr.waveform,bufdesc.d2{npts});
  Move(GlobData^.data[readindex],Cr.WaveForm[0],bufdesc.d2{npts}*2);
end;

{------------------------  GET SV ------------------------------------------}
Procedure TSurfAcq.GetSValFromSurf(var SVal : TSVal; ReadIndex : integer);
begin
  Move(GlobData^.data[readindex],SVal,sizeof(TSVal));
end;

{------------------------  GET SURFMSG---------------------------------}
Procedure TSurfAcq.GetMsgFromSurf(var SurfMsg : TSurfMsg; ReadIndex : integer);
begin
  Move(GlobData^.data[readindex],SurfMsg,sizeof(TSurfMsg));
end;

{------------------------  GET SurfEvent ------------------------------------------}
(*Procedure TSurfAcq.GetSurfEventFromSurf(var SurfEvent : TSurfEvent; ReadIndex : integer);
begin
  Move(GlobData^.data[readindex],SurfEvent,sizeof(SurfEvent));
end;*)

end.