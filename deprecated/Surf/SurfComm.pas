unit SurfComm;
interface

USES  Messages,Sysutils,Controls,Classes,Exec,Surf2SurfBridge,SurfFile,Dialogs,
      SurfTypes,SurfPublicTypes,PahUnit;

TYPE
  //SurfComm needs a handle for communications, so make it descend from TWinControl
  TSurfComm = class (TWinControl)
    private
      Procedure ReadDataFile(Filename : String);
      Procedure SaveDataFile;
    public
      //my message handler for messages to SURF
      procedure MesgFromSurfBridge( var msg : TMessage ); message WM_SURF_IN;
      //calls from SurfMain
      Procedure CallUserApp(Filename : string);

      //callbacks for user to get access to SurfMainAcq
      Procedure PutDACOut(DAC : TDAC); virtual; //abstract;
      Procedure PutDIOOut(DIO : TDIO); virtual; //abstract;
  end;

implementation

{------------------------------------------------------------------------------}
procedure TSurfComm.MesgFromSurfBridge(var msg : TMessage );
var  Spike : TSpike;
     Sv : TSVal;
     DAC : TDAC;
     DIO : TDIO;
     //Probe : TProbe;
     FileName : String;
begin
  Case msg.WParam of
    SURF_IN_HANDLE     : SurfBridgeFormHandle := msg.lparam;
    SURF_IN_SV         : begin
                           GetSvFromSurfBridge(Sv,msg.lparam);
                           //PutDIOOut(DIO : TDIO);
                           //showmessage('Surf received sv: '+inttostr(sv.time_stamp)+','+sv.subtype+','+inttostr(sv.sval));
                           //output sv
                         end;
    SURF_IN_DIO        : begin
                           GetDIOFromSurfBridge(DIO,msg.lparam);
                           PutDIOOut(DIO);
                           //showmessage('Surf received dac: '+inttostr(dac.channel)+','+inttostr(dac.val));
                           //output dac
                         end;
    SURF_IN_DAC        : begin
                           GetDACFromSurfBridge(DAC,msg.lparam);
                           PutDACOut(DAC);
                           //showmessage('Surf received dac: '+inttostr(dac.channel)+','+inttostr(dac.val));
                           //output dac
                         end;
    SURF_IN_SPIKE      : begin
                           GetSpikeFromSurfBridge(Spike,msg.lparam);
                         end;
    SURF_IN_READFILE   : begin  //user wants a file by the name of...
                           GetFileNameFromSurfBridge(FileName,msg.lparam);
                           //do something with filename
                           ReadDataFile(Filename);
                         end;
    SURF_IN_SAVEFILE   : begin
                           SaveDataFile;
                         end;
  end{case};
end;

{------------------------------------------------------------------------------}
Procedure TSurfComm.CallUserApp(Filename : string);
begin
  SurfBridgeFormHandle := -1;
  NewExec(Filename + ' SURFv1.0 '+inttostr(Handle));
end;

{------------------------------------------------------------------------------}
Procedure TSurfComm.ReadDataFile(Filename : String);
var
  ReadSurf : TSurfFile;
begin
//ShowMessage('In surfcomm, About to create object '+Filename);
  ReadSurf := TSurfFile.Create;
  if not ReadSurf.ReadEntireSurfFile(FileName,TRUE{read the spike waveforms},FALSE{average the waveforms}) then //this reads everything
  begin
    ReadSurf.Free;
    ShowMessage('Error Reading '+ FileName);
    Exit;
  end;

//ShowMessage('In surfcomm, About to read '+Filename);
  With ReadSurf do
  begin
    //must send it in pieces to surfbridge, who will reassemble it
    //send a message first that the stream will be coming
    StartFileSend;
    SendEventArrayToSurfBridge(SurfEvent);
    Delay(0,50);
    SendProbeArrayToSurfBridge(Prb);
    Delay(0,50);
    if Length(SVal)>0 then SendSValArrayToSurfBridge(SVal);
    Delay(0,50);
    if Length(Msg)>0 then SendMsgArrayToSurfBridge(Msg);
    Delay(0,50);
    EndFileSend;
  end;
//ShowMessage('In surfcomm, end of read '+Filename);
  ReadSurf.CleanUp;
  ReadSurf.Free;
end;

{------------------------------------------------------------------------------}
Procedure TSurfComm.SaveDataFile;
begin
  //don't know how to handle this yet
  //possibly read all into an event rec and dump messages to user?
  //can't dump entire event rec because surfbridge buffer is too small
  //and can't increase it because some files may be over 100MB.
end;

{------------------------------------------------------------------------------}
Procedure TSurfComm.PutDACOut(DAC : TDAC);
begin
  //put in to create a concrete instantiation of the procedure
end;
{------------------------------------------------------------------------------}
Procedure TSurfComm.PutDIOOut(DIO : TDIO);
begin
  //put in to create a concrete instantiation of the procedure
end;

end.