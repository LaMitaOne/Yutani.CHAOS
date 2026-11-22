program Project1;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  Unit1 in 'Unit1.pas' {Form1},
  uControls in 'uControls.pas' {Form2},
  Yutani.Chaos.Skia.GPU in 'Yutani.Chaos.Skia.GPU.pas',
  uAppTray in 'uAppTray.pas',
  Yutani.MeshLoader in 'Yutani.MeshLoader.pas',
  uSkiaCustomThreadedBase in 'uSkiaCustomThreadedBase.pas',
  Yutani.PhotoTo3D in 'Yutani.PhotoTo3D.pas';

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
