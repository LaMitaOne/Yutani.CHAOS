unit Unit1;

interface
uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants, Winapi.Windows, FMX.Platform.Win,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  Yutani.Chaos.Skia.GPU;
type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FChaos: TSkChaos;
  public
  end;
var
  Form1: TForm1;
implementation
{$R *.fmx}
procedure TForm1.FormCreate(Sender: TObject);
var
  Wnd: HWND;
begin
  Wnd := WindowHandleToPlatform(Self.Handle).Wnd;
  SetWindowLong(Wnd, GWL_EXSTYLE, GetWindowLong(Wnd, GWL_EXSTYLE) or WS_EX_TRANSPARENT);

  Caption := 'Yutani CHAOS';
  BorderStyle := TFmxFormBorderStyle.None;
  Transparency := True;
  Fill.Color := TAlphaColorRec.Null;

  ClientWidth := Round(Screen.Size.Width);
  ClientHeight := Round(Screen.Size.Height);
  Left := 0;
  Top := 0;
  Position := TFormPosition.Designed;
  FChaos := TSkChaos.Create(Self);
  FChaos.Parent := Self;
  FChaos.Position.X := ClientWidth - 236 - 20;
  FChaos.Position.Y := ClientHeight - 252 - 50;
  FChaos.Width := 236;
  FChaos.Height := 252;
  FChaos.Active := True;
end;
procedure TForm1.FormDestroy(Sender: TObject);
begin
  FChaos.Active := False;
  FChaos.Free;
end;
end.
