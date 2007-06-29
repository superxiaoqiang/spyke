program ReadSurf;

uses
  Forms,
  ReadSurfMain in 'ReadSurfMain.pas' {ReadSurfForm},
  SurfPublicTypes in '..\Public\SurfPublicTypes.pas',
  WaveFormPlotUnit in '..\Public\WaveFormPlotUnit.pas' {WaveFormPlotForm},
  ElectrodeTypes in '..\Public\ElectrodeTypes.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TReadSurfForm, ReadSurfForm);
  Application.Run;
end.