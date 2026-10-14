unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  System.UITypes, System.UIConsts, Yutani.Chaos.Skia;

type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FChaos: TSkChaos;
    FSpeakTimer: TTimer;
    FColorDialog: TColorDialog;

    procedure btnStartStopClick(Sender: TObject);
    procedure btnEyeClick(Sender: TObject);
    procedure btnMouthClick(Sender: TObject);
    procedure btnColorClick(Sender: TObject);
    procedure btnSpeakClick(Sender: TObject);
    procedure OnSpeakTimer(Sender: TObject);

    function CreateButton(const ACaption: string; ATop, ALeft, AWidth: Integer; ATag: Integer; AEvent: TNotifyEvent): TButton;
  public
    { Public-Deklarationen }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
var
  Btn: TButton;
  Y: Integer;
begin
  // Control Form Setup (Normaler Style, KEIN StayOnTop mehr!)
  Caption := 'Yutani CHAOS Control';
  ClientWidth := 320;
  ClientHeight := 450;
  Color := clBtnFace;
  Position := poScreenCenter;

  // Initialize AI Instance (aber nicht starten!)
  FChaos := TSkChaos.Create;

  // Setup Color Dialog
  FColorDialog := TColorDialog.Create(Self);

  // Setup Speak Timer (Disabled by default)
  FSpeakTimer := TTimer.Create(Self);
  FSpeakTimer.Interval := 120;
  FSpeakTimer.Enabled := False;
  FSpeakTimer.OnTimer := OnSpeakTimer;

  Y := 20;

  // --- Main Control ---
  Btn := CreateButton('START CHAOS', Y, 20, 280, 0, btnStartStopClick);
  Btn.Font.Style := [fsBold];
  Inc(Y, 50);

  // --- Eyes Controls ---
  Btn := CreateButton('Eye: Open', Y, 20, 130, 0, btnEyeClick);
  Btn := CreateButton('Eye: Mid', Y, 170, 130, 1, btnEyeClick);
  Inc(Y, 40);
  Btn := CreateButton('Eye: Closed', Y, 20, 130, 2, btnEyeClick);
  Btn := CreateButton('Eye: Auto/Blink', Y, 170, 130, 3, btnEyeClick);
  Inc(Y, 60);

  // --- Mouth Controls ---
  Btn := CreateButton('Mouth: Closed', Y, 20, 130, 0, btnMouthClick);
  Btn := CreateButton('Mouth: Min', Y, 170, 130, 1, btnMouthClick);
  Inc(Y, 40);
  Btn := CreateButton('Mouth: Mid', Y, 20, 130, 2, btnMouthClick);
  Btn := CreateButton('Mouth: Full', Y, 170, 130, 3, btnMouthClick);
  Inc(Y, 60);

  // --- Speak Simulation ---
  Btn := CreateButton('Simulate Speaking', Y, 20, 280, 0, btnSpeakClick);
  Inc(Y, 60);

  // --- Colors ---
  Btn := CreateButton('Color: Face', Y, 20, 130, 0, btnColorClick);
  Btn := CreateButton('Color: Eyes', Y, 170, 130, 1, btnColorClick);
  Inc(Y, 40);
  Btn := CreateButton('Color: Mouth', Y, 20, 130, 2, btnColorClick);
end;

function TForm1.CreateButton(const ACaption: string; ATop, ALeft, AWidth: Integer; ATag: Integer; AEvent: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := Self;
  Result.Caption := ACaption;
  Result.Top := ATop;
  Result.Left := ALeft;
  Result.Width := AWidth;
  Result.Tag := ATag;
  Result.OnClick := AEvent;
end;

procedure TForm1.btnStartStopClick(Sender: TObject);
begin
  if TButton(Sender).Caption = 'START CHAOS' then
  begin
    TButton(Sender).Caption := 'STOP CHAOS';
    FChaos.Start;
  end
  else
  begin
    TButton(Sender).Caption := 'START CHAOS';
    FChaos.Stop;
  end;
end;

procedure TForm1.btnEyeClick(Sender: TObject);
begin
  FSpeakTimer.Enabled := False; // Stop speaking if we manually override
  case TButton(Sender).Tag of
    0: FChaos.EyeOverride := esOpen;
    1: FChaos.EyeOverride := esMid;
    2: FChaos.EyeOverride := esClosed;
    3: FChaos.EyeOverride := esOpen; // Tag 3 = Auto (which is esOpen + internal blink logic)
  end;
end;

procedure TForm1.btnMouthClick(Sender: TObject);
begin
  FSpeakTimer.Enabled := False; // Stop speaking if we manually override
  case TButton(Sender).Tag of
    0: FChaos.MouthState := msClosed;
    1: FChaos.MouthState := msMin;
    2: FChaos.MouthState := msMid;
    3: FChaos.MouthState := msFull;
  end;
end;

procedure TForm1.btnSpeakClick(Sender: TObject);
begin
  // Toggle the speaking simulation
  FSpeakTimer.Enabled := not FSpeakTimer.Enabled;
  if FSpeakTimer.Enabled then
    TButton(Sender).Caption := 'STOP Speaking'
  else
  begin
    TButton(Sender).Caption := 'Simulate Speaking';
    FChaos.MouthState := msClosed; // Close mouth when done
  end;
end;

procedure TForm1.OnSpeakTimer(Sender: TObject);
const
  SpeakStates: array[0..3] of TMouthState = (msMin, msMid, msFull, msMid);
begin
  // Rapidly change mouth state to simulate talking
  FChaos.MouthState := SpeakStates[Random(Length(SpeakStates))];
end;

procedure TForm1.btnColorClick(Sender: TObject);
begin
  if FColorDialog.Execute then
  begin
    // Convert TColor to TAlphaColor (FF Alpha)
    var AlphaColor := TAlphaColorRec.Alpha or TColor(FColorDialog.Color);

    case TButton(Sender).Tag of
      0: FChaos.FaceColor := AlphaColor;
      1: FChaos.EyeColor := AlphaColor;
      2: FChaos.MouthColor := AlphaColor;
    end;
  end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FChaos.Stop;
  FChaos.Free;
end;

end.
