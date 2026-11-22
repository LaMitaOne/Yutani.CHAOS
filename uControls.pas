unit uControls;

{ Dynamic control panel for TSkChaos. Built at runtime as a wider, tabbed
  window (TTabControl) so every slider is reachable on a normal HD screen
  without vertical scrolling:

    Appearance / Shader  - holo style + particle/glow/rim/alpha/jitter/inner-core
    Mesh & Sources       - step filter, particle budget, reload buttons, source
    Face / Animation     - emotion + mouth/eyes/chaos/trail (marked WIP: the holo
                           shader does not yet consume uMouthOpen/uEyeOpeness/
                           uChaosLevel for mesh/hybrid sources)
    System / Performance - active/adaptive FPS, target FPS tiers, live read-outs

  Closing the form with the X button hides it (caHide) instead of freeing it,
  so the tray icon can surface it again at any time. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Math, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.StdCtrls, FMX.ListBox, FMX.Layouts, FMX.TabControl, Yutani.Chaos.Skia.GPU;

type
  TForm2 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    FTabs: TTabControl;
    FCurrentTab: TTabItem;
    FTimer: TTimer;
    FFpsLabel: TLabel;
    FIdleLabel: TLabel;
    FSrcLabel: TLabel;
    FValLabels: array[1..16] of TLabel;
    FNextY: Single;
    function NewTab(const ACaption: string): TTabItem;
    function AddSection(const ACaption: string): TLabel;
    function AddLabel(const ACaption: string): TLabel;
    procedure AddTrack(ATag: Integer; const ACaption: string; AMin, AMax, AStep, AValue: Single; AEnabled: Boolean = True);
    procedure AddCombo(ATag: Integer; const ACaption: string; const AItems: array of string; AIndex: Integer);
    procedure AddCheck(ATag: Integer; const ACaption: string; AChecked: Boolean);
    procedure AddButton(const ACaption: string; AOnClick: TNotifyEvent);
    procedure OnTrackChange(Sender: TObject);
    procedure OnComboChange(Sender: TObject);
    procedure OnCheckChange(Sender: TObject);
    procedure OnFpsTimer(Sender: TObject);
    procedure OnReloadMesh(Sender: TObject);
    procedure OnReloadPhoto(Sender: TObject);
    procedure OnLoadDepth(Sender: TObject);
    procedure OnNotify(Sender: TObject);
  public
    { Public declarations }
  end;

var
  Form2: TForm2;
  { Unit1 assigns this right after creating the TSkChaos instance, so the
    control panel and the tray menu can reach the live avatar. }
  GChaos: TSkChaos = nil;

{ Auto-locates the live TSkChaos on the main form so the panel and the tray
  menu work even when Unit1 never assigns GChaos explicitly. }
function FindChaos: TSkChaos;

implementation

{$R *.fmx}

function FindChaos: TSkChaos;

  { Recursively walk a component's owned-components tree. Catches a TSkChaos
    created at design time or with Create(Owner) - it lives in Components. }
  function WalkComp(Obj: TComponent): TSkChaos;
  var
    I: Integer;
    C: TComponent;
  begin
    Result := nil;
    if not Assigned(Obj) then
      Exit;
    if Obj is TSkChaos then
      Exit(TSkChaos(Obj));
    for I := 0 to Obj.ComponentCount - 1 do
    begin
      C := Obj.Components[I];
      Result := WalkComp(C);
      if Assigned(Result) then
        Exit;
    end;
  end;

  { Recursively walk a control's child tree. Catches a TSkChaos parented to a
    sub-control (TLayout / TPanel) even when owned by nil. }
  function WalkChildren(Obj: TFMXObject): TSkChaos;
  var
    I: Integer;
    C: TFMXObject;
  begin
    Result := nil;
    if not Assigned(Obj) then
      Exit;
    if Obj is TSkChaos then
      Exit(TSkChaos(Obj));
    for I := 0 to Obj.ChildrenCount - 1 do
    begin
      C := Obj.Children[I];
      Result := WalkChildren(C);
      if Assigned(Result) then
        Exit;
    end;
  end;

var
  I: Integer;
begin
  Result := nil;
  { Scan every loaded form, both its owned components and its child tree, so
    the avatar is found whether it sits on the main form, a sub-control, or a
    secondary form - and whether or not Unit1 assigned GChaos explicitly. }
  for I := 0 to Screen.FormCount - 1 do
  begin
    Result := WalkComp(Screen.Forms[I]);
    if Assigned(Result) then
      Exit;
    Result := WalkChildren(Screen.Forms[I]);
    if Assigned(Result) then
      Exit;
  end;
end;

const
  { Trackbar tags - map a trackbar to the property it drives. }
  tgParticleSize = 1;
  tgGlowIntensity = 2;
  tgRimLight = 3;
  tgHoloAlpha = 4;
  tgJitter = 5;
  tgMouthOpen = 6;
  tgEyeOpeness = 7;
  tgChaosLevel = 8;
  tgTrailPersist = 9;
  tgTargetFPS = 10;
  tgActiveTargetFPS = 11;
  tgIdleTargetFPS = 12;
  tgIdleTimeout = 13;
  tgStepFilter = 14;
  tgParticleBudget = 15;
  tgNeckPivot = 16;
  { Combobox tags. }
  tgHoloStyle = 1;
  tgEmotion = 2;
  { Checkbox tags. }
  tgActive = 1;
  tgAdaptiveFPS = 2;
  tgInnerCore = 3;
  tgMouseFollow = 4;
  tgStayOnTop = 5;
  tgClickThrough = 6;

const
  { Layout constants - wider-than-tall window sized for a normal HD screen. }
  PANEL_W = 640;
  PANEL_H = 500;
  CTRL_X = 24;
  CTRL_W = 560;
  BTN_W = 260;

procedure TForm2.FormCreate(Sender: TObject);
begin
  Caption := 'Yutani Chaos - Controls';
  Self.ClientWidth := PANEL_W;
  Self.ClientHeight := PANEL_H;
  Self.Position := TFormPosition.ScreenCenter;
  Self.OnClose := FormClose;
  Self.OnDestroy := FormDestroy;

  FTabs := TTabControl.Create(Self);
  FTabs.Parent := Self;
  FTabs.Align := TAlignLayout.Client;
  FTabs.TabHeight := 30;
  FTabs.TabPosition := TTabPosition.Top;

  if not Assigned(GChaos) then
    GChaos := FindChaos;
  if Assigned(GChaos) then
  begin
    { ---- Tab 1: Appearance / Shader ---- }
    FCurrentTab := NewTab('Appearance / Shader');
    AddSection('HOLO STYLE');
    AddCombo(tgHoloStyle, 'Style', ['Classic', 'Cyber', 'Volumetric', 'Photo'], Ord(GChaos.HoloStyle));
    AddSection('APPEARANCE');
    AddTrack(tgParticleSize, 'Particle size', 0.1, 8.0, 0.1, GChaos.ParticleSize);
    AddTrack(tgGlowIntensity, 'Glow intensity', 0.0, 3.0, 0.05, GChaos.GlowIntensity);
    AddTrack(tgRimLight, 'Rim light', 0.0, 3.0, 0.05, GChaos.RimLightStrength);
    AddTrack(tgHoloAlpha, 'Holo alpha', 0.0, 1.0, 0.02, GChaos.HoloAlpha);
    AddTrack(tgJitter, 'Jitter amount', 0.0, 2.0, 0.02, GChaos.JitterAmount);
    AddCheck(tgInnerCore, 'Inner brain-core', GChaos.InnerCore);

    { ---- Tab 2: Mesh & Sources ---- }
    FCurrentTab := NewTab('Mesh & Sources');
    AddSection('MESH / PARTICLES');
    AddTrack(tgStepFilter, 'Step filter', 1, 12, 1, GChaos.StepFilter);
    AddTrack(tgParticleBudget, 'Particle budget', 500, 200000, 500, GChaos.ParticleBudget);
    AddSection('SOURCES');
    AddButton('Reload mesh...', OnReloadMesh);
    AddButton('Reload photo...', OnReloadPhoto);
    AddButton('Load depthmap...', OnLoadDepth);
    AddButton('Ping activity', OnNotify);
    AddSection('STATUS');
    FSrcLabel := AddLabel('Source: -');

    { ---- Tab 3: Face / Animation ---- }
    FCurrentTab := NewTab('Face / Animation');
    AddSection('EMOTION');
    AddCombo(tgEmotion, 'Emotion', ['Neutral', 'Thinking', 'Happy', 'Alert'], Ord(GChaos.EmotionMode));
    AddSection('FACE / CHAOS (WORK IN PROGRESS)');
    AddLabel('Mouth / Eyes / Chaos / Trail are not yet wired into the holo');
    AddLabel('shader for mesh/hybrid sources - coming soon.');
    AddTrack(tgMouthOpen, 'Mouth open (WIP)', 0.0, 1.0, 0.02, GChaos.MouthOpen, True);
    AddTrack(tgEyeOpeness, 'Eye openess (WIP)', 0.0, 1.0, 0.02, GChaos.EyeOpeness, True);
    AddTrack(tgChaosLevel, 'Chaos level (WIP)', 0.0, 1.0, 0.02, GChaos.ChaosLevel, True);
    AddTrack(tgTrailPersist, 'Trail persistence (WIP)', 0.0, 1.0, 0.02, GChaos.TrailPersistence, True);
    AddTrack(tgNeckPivot, 'Neck pivot', 0.0, 1.0, 0.01, GChaos.NeckPivotRatio);

    { ---- Tab 4: System / Performance ---- }
    FCurrentTab := NewTab('System / Performance');
    AddSection('FRAME RATE');
    AddCheck(tgActive, 'Active', GChaos.Active);
    AddCheck(tgAdaptiveFPS, 'Adaptive FPS', GChaos.AdaptiveFPS);
    AddSection('WINDOW');
    AddCheck(tgMouseFollow, 'Mouse follow', GChaos.MouseFollow);
    AddCheck(tgStayOnTop, 'Stay on top', GChaos.StayOnTop);
    AddCheck(tgClickThrough, 'Click-through', GChaos.ClickThrough);
    AddTrack(tgTargetFPS, 'Target FPS', 5, 120, 1, GChaos.TargetFPS);
    AddTrack(tgActiveTargetFPS, 'Active target FPS', 5, 120, 1, GChaos.ActiveTargetFPS);
    AddTrack(tgIdleTargetFPS, 'Idle target FPS', 1, 60, 1, GChaos.IdleTargetFPS);
    AddTrack(tgIdleTimeout, 'Idle timeout (s)', 0.5, 30, 0.5, GChaos.IdleTimeoutSec);
    AddSection('LIVE');
    FFpsLabel := AddLabel('Real FPS: -');
    FIdleLabel := AddLabel('Idle: -');

    case GChaos.SourceType of
      srcDepthMap:
        FSrcLabel.Text := 'Source: depth-map face';
      srcMesh:
        FSrcLabel.Text := 'Source: mesh';
      srcPhoto:
        FSrcLabel.Text := 'Source: photo';
      srcHybrid:
        FSrcLabel.Text := 'Source: hybrid';
    end;
  end
  else
  begin
    FCurrentTab := NewTab('Status');
    AddSection('NO GCHAOS ASSIGNED');
    AddLabel('Set GChaos in Unit1 before opening this form.');
  end;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 400;
  FTimer.OnTimer := OnFpsTimer;
  FTimer.Enabled := True;

  FTabs.TabIndex := 0;
end;

procedure TForm2.FormDestroy(Sender: TObject);
begin
  if Assigned(FTimer) then
    FTimer.Enabled := False;
end;

procedure TForm2.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  { Hide instead of free so the tray can re-show us. }
  Action := TCloseAction.caHide;
end;

function TForm2.NewTab(const ACaption: string): TTabItem;
begin
  Result := TTabItem.Create(FTabs);
  Result.Parent := FTabs;
  Result.Text := ACaption;
  FNextY := 12;
end;

function TForm2.AddSection(const ACaption: string): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := FCurrentTab;
  Result.Position.X := CTRL_X;
  Result.Position.Y := FNextY + 4;
  Result.Text := '-- ' + ACaption + ' --';
  Result.Width := CTRL_W;
  Result.Height := 20;
  FNextY := FNextY + 30;
end;

function TForm2.AddLabel(const ACaption: string): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := FCurrentTab;
  Result.Position.X := CTRL_X + 4;
  Result.Position.Y := FNextY;
  Result.Text := ACaption;
  Result.Width := CTRL_W;
  Result.Height := 18;
  FNextY := FNextY + 20;
end;

procedure TForm2.AddTrack(ATag: Integer; const ACaption: string; AMin, AMax, AStep, AValue: Single; AEnabled: Boolean);
var
  L: TLabel;
  tb: TTrackBar;
begin
  L := AddLabel(ACaption + ': ' + FormatFloat('0.00', AValue));
  if (ATag >= Low(FValLabels)) and (ATag <= High(FValLabels)) then
    FValLabels[ATag] := L;
  tb := TTrackBar.Create(Self);
  tb.Parent := FCurrentTab;
  tb.Position.X := CTRL_X;
  tb.Position.Y := FNextY;
  tb.Width := CTRL_W;
  tb.Min := AMin;
  tb.Max := AMax;
  tb.Frequency := AStep;
  tb.Value := AValue;
  tb.Tag := ATag;
  tb.Enabled := AEnabled;
  tb.OnChange := OnTrackChange;
  FNextY := FNextY + 46;
end;

procedure TForm2.AddCombo(ATag: Integer; const ACaption: string; const AItems: array of string; AIndex: Integer);
var
  I: Integer;
  cb: TComboBox;
begin
  AddLabel(ACaption);
  cb := TComboBox.Create(Self);
  cb.Parent := FCurrentTab;
  cb.Position.X := CTRL_X;
  cb.Position.Y := FNextY;
  cb.Width := CTRL_W;
  for I := 0 to High(AItems) do
    cb.Items.Add(AItems[I]);
  cb.ItemIndex := AIndex;
  cb.Tag := ATag;
  cb.OnChange := OnComboChange;
  FNextY := FNextY + 44;
end;

procedure TForm2.AddCheck(ATag: Integer; const ACaption: string; AChecked: Boolean);
var
  cb: TCheckBox;
begin
  cb := TCheckBox.Create(Self);
  cb.Parent := FCurrentTab;
  cb.Position.X := CTRL_X;
  cb.Position.Y := FNextY;
  cb.Width := CTRL_W;
  cb.Text := ACaption;
  cb.IsChecked := AChecked;
  cb.Tag := ATag;
  cb.OnChange := OnCheckChange;
  FNextY := FNextY + 30;
end;

procedure TForm2.AddButton(const ACaption: string; AOnClick: TNotifyEvent);
var
  btn: TButton;
begin
  btn := TButton.Create(Self);
  btn.Parent := FCurrentTab;
  btn.Position.X := CTRL_X;
  btn.Position.Y := FNextY;
  btn.Width := BTN_W;
  btn.Text := ACaption;
  btn.OnClick := AOnClick;
  FNextY := FNextY + 34;
end;

procedure TForm2.OnTrackChange(Sender: TObject);
var
  tb: TTrackBar;
  v: Single;
begin
  if not Assigned(GChaos) then
    Exit;
  tb := Sender as TTrackBar;
  v := tb.Value;
  case tb.Tag of
    tgParticleSize:
      begin
        GChaos.ParticleSize := v;
        FValLabels[tgParticleSize].Text := 'Particle size: ' + FormatFloat('0.00', v);
      end;
    tgGlowIntensity:
      begin
        GChaos.GlowIntensity := v;
        FValLabels[tgGlowIntensity].Text := 'Glow intensity: ' + FormatFloat('0.00', v);
      end;
    tgRimLight:
      begin
        GChaos.RimLightStrength := v;
        FValLabels[tgRimLight].Text := 'Rim light: ' + FormatFloat('0.00', v);
      end;
    tgHoloAlpha:
      begin
        GChaos.HoloAlpha := v;
        FValLabels[tgHoloAlpha].Text := 'Holo alpha: ' + FormatFloat('0.00', v);
      end;
    tgJitter:
      begin
        GChaos.JitterAmount := v;
        FValLabels[tgJitter].Text := 'Jitter amount: ' + FormatFloat('0.00', v);
      end;
    tgMouthOpen:
      begin
        GChaos.MouthOpen := v;
        FValLabels[tgMouthOpen].Text := 'Mouth open (WIP): ' + FormatFloat('0.00', v);
      end;
    tgEyeOpeness:
      begin
        GChaos.EyeOpeness := v;
        FValLabels[tgEyeOpeness].Text := 'Eye openess (WIP): ' + FormatFloat('0.00', v);
      end;
    tgChaosLevel:
      begin
        GChaos.ChaosLevel := v;
        FValLabels[tgChaosLevel].Text := 'Chaos level (WIP): ' + FormatFloat('0.00', v);
      end;
    tgTrailPersist:
      begin
        GChaos.TrailPersistence := v;
        FValLabels[tgTrailPersist].Text := 'Trail persistence (WIP): ' + FormatFloat('0.00', v);
      end;
    tgStepFilter:
      begin
        GChaos.StepFilter := Round(v);
        FValLabels[tgStepFilter].Text := 'Step filter: ' + IntToStr(Round(v));
      end;
    tgParticleBudget:
      begin
        GChaos.ParticleBudget := Cardinal(Round(v));
        FValLabels[tgParticleBudget].Text := 'Particle budget: ' + IntToStr(Round(v));
      end;
    tgTargetFPS:
      begin
        GChaos.TargetFPS := Round(v);
        FValLabels[tgTargetFPS].Text := 'Target FPS: ' + IntToStr(Round(v));
      end;
    tgActiveTargetFPS:
      begin
        GChaos.ActiveTargetFPS := Round(v);
        FValLabels[tgActiveTargetFPS].Text := 'Active target FPS: ' + IntToStr(Round(v));
      end;
    tgIdleTargetFPS:
      begin
        GChaos.IdleTargetFPS := Round(v);
        FValLabels[tgIdleTargetFPS].Text := 'Idle target FPS: ' + IntToStr(Round(v));
      end;
    tgIdleTimeout:
      begin
        GChaos.IdleTimeoutSec := v;
        FValLabels[tgIdleTimeout].Text := 'Idle timeout (s): ' + FormatFloat('0.0', v);
      end;
    tgNeckPivot:
      begin
        GChaos.NeckPivotRatio := v;
        FValLabels[tgNeckPivot].Text := 'Neck pivot: ' + FormatFloat('0.00', v);
      end;
  end;
end;

procedure TForm2.OnComboChange(Sender: TObject);
var
  cb: TComboBox;
begin
  if not Assigned(GChaos) then
    Exit;
  cb := Sender as TComboBox;
  case cb.Tag of
    tgHoloStyle:
      GChaos.HoloStyle := THoloStyle(cb.ItemIndex);
    tgEmotion:
      GChaos.EmotionMode := TEmotionMode(cb.ItemIndex);
  end;
end;

procedure TForm2.OnCheckChange(Sender: TObject);
var
  cb: TCheckBox;
begin
  if not Assigned(GChaos) then
    Exit;
  cb := Sender as TCheckBox;
  case cb.Tag of
    tgActive:
      GChaos.Active := cb.IsChecked;
    tgAdaptiveFPS:
      GChaos.AdaptiveFPS := cb.IsChecked;
    tgInnerCore:
      GChaos.InnerCore := cb.IsChecked;
    tgMouseFollow:
      GChaos.MouseFollow := cb.IsChecked;
    tgStayOnTop:
      GChaos.StayOnTop := cb.IsChecked;
    tgClickThrough:
      GChaos.ClickThrough := cb.IsChecked;
  end;
end;

procedure TForm2.OnFpsTimer(Sender: TObject);
begin
  if not Assigned(GChaos) then
    Exit;
  FFpsLabel.Text := 'Real FPS: ' + IntToStr(GChaos.RealFPS);
  if GChaos.IdleMode then
    FIdleLabel.Text := 'Idle: yes (quiet pacing)'
  else
    FIdleLabel.Text := 'Idle: no (active pacing)';
end;

procedure TForm2.OnReloadMesh(Sender: TObject);
var
  dlg: TOpenDialog;
begin
  if not Assigned(GChaos) then
    Exit;
  dlg := TOpenDialog.Create(nil);
  try
    dlg.Filter := 'Mesh files|*.glb;*.obj|All files|*.*';
    dlg.InitialDir := ExtractFilePath(ParamStr(0));
    if dlg.Execute then
      GChaos.LoadMeshFile(dlg.FileName, Min(GChaos.Width, GChaos.Height) * 0.45, GChaos.StepFilter, GChaos.ParticleBudget);
  finally
    dlg.Free;
  end;
end;

procedure TForm2.OnReloadPhoto(Sender: TObject);
var
  dlg: TOpenDialog;
begin
  if not Assigned(GChaos) then
    Exit;
  dlg := TOpenDialog.Create(nil);
  try
    dlg.Filter := 'Photo files|*.png;*.jpg;*.jpeg|All files|*.*';
    dlg.InitialDir := ExtractFilePath(ParamStr(0));
    if dlg.Execute then
      GChaos.LoadPhotoFile(dlg.FileName, Min(GChaos.Width, GChaos.Height) * 0.45, GChaos.StepFilter, GChaos.ParticleBudget);
  finally
    dlg.Free;
  end;
end;

procedure TForm2.OnLoadDepth(Sender: TObject);
var
  dlg: TOpenDialog;
  f: string;
begin
  if not Assigned(GChaos) then
    Exit;
  dlg := TOpenDialog.Create(nil);
  try
    dlg.Filter := 'Depth map|*.png|All files|*.*';
    dlg.InitialDir := ExtractFilePath(ParamStr(0));
    f := ExtractFilePath(ParamStr(0)) + 'depthmap.png';
    if FileExists(f) then
      dlg.FileName := f;
    if dlg.Execute then
      GChaos.LoadDepthMap(dlg.FileName);
  finally
    dlg.Free;
  end;
end;

procedure TForm2.OnNotify(Sender: TObject);
begin
  if Assigned(GChaos) then
    GChaos.NotifyActivity;
end;

end.

