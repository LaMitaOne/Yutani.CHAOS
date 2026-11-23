unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  Winapi.Windows, FMX.Platform.Win, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.Graphics, FMX.Dialogs, Yutani.Chaos.Skia.GPU, uControls;

type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
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
  { Publish the live avatar to the control panel + tray menu so they do not
    have to fall back to the recursive FindChaos scan. }
  GChaos := FChaos;
  { Default desktop-pet behaviour: look at the cursor, float above
    other windows, and let clicks pass through to the desktop. Each
    is a live option on the tray menu and the controls panel. }
  FChaos.MouseFollow := True;
  FChaos.StayOnTop := True;
  FChaos.ClickThrough := True;
  { FMX finalizes the window handle when the form is shown (Transparency /
    FormStyle recreate the HWND), which drops the raw WS_EX_TRANSPARENT flag
    applied above. Re-apply it from OnShow so click-through is live from the
    very first show, not only after the first manual toggle. }
  Self.OnShow := FormShow;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FChaos.Active := False;
  FChaos.Free;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  { The window handle is now finalized by FMX; re-apply click-through so it
    takes effect from the first show instead of only after a manual toggle. }
  if Assigned(FChaos) then
    FChaos.ApplyClickThrough;
end;

end.

