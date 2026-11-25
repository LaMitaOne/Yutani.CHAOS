unit uControls;

{ Dynamic control panel for TSkChaos. Built at runtime as a wider, tabbed
  window (TTabControl) so every slider is reachable on a normal HD screen
  without vertical scrolling:

    Appearance / Shader  - holo style; Head / Brain target radios select which
                           property set the glow / particle size / softness /
                           rim power trackbars edit; rim light, holo alpha and
                           jitter apply to the whole avatar
    Mesh                 - step filter, particle budget, load mesh, per-part
                           checkbox list with live preview (reloads the mesh on
                           each toggle) plus a colour picker per part, source
    Photo & Depth        - load photo / depth-map, source
    Inner Core / Brain   - inner-core toggle, custom brain/core mesh load and
                           clear, scale / vertical offset / particle budget,
                           per-part colour pickers for the core sub-meshes
    Face / Animation     - emotion, mouth/eye tracks (drive the holo shader:
                           jaw hinge + speech glow, dim-blink), auto-blink
                           interval / duration, neck pivot
    Desktop Overlay      - alive highlighter: send the entity to this panel's
                           screen rectangle or dismiss it; avatar placement
                           (mouse drag, bottom-corner snaps) and live
                           resizing; per-mesh ini presets (save the current
                           head's setup, save/load named files) - and every
                           tab syncs to a restored startup preset on open
    System / Performance - active/adaptive FPS with active/idle target tiers,
                           idle timeout, live read-outs

  Closing the form with the X button hides it (caHide) instead of freeing it,
  so the tray icon can surface it again at any time. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Math, System.Generics.Collections, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.ListBox, FMX.Colors, FMX.Layouts,
  FMX.TabControl, Yutani.Chaos.Skia.GPU, Yutani.MeshLoader;

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
    FValLabels: array[1..22] of TLabel;
    FNextY: Single;
    { Per-part checkbox grid built from GChaos.MeshNames after a mesh load.
      FPartChecks mirrors the MeshNames order so a checkbox toggle maps to the
      same index. FPartCaptions holds the raw mesh-name string shown on each
      checkbox - used to rebuild the IncludeNames filter on each toggle. }
    FPartChecks: TList<TCheckBox>;
    FPartCaptions: TList<string>;
    { Compact colour picker per part row, parallel to FPartChecks; Tag carries
      the MeshNames index the picked colour applies to. }
    FPartColorBoxes: TList<TColorComboBox>;
    FMeshTab: TTabItem;
    FMeshPartsHost: TLayout;
    FMeshPartsScroll: TScrollBox;
    FNoPartsLabel: TLabel;
    { Inner core / brain tab: one name label + colour picker row per
      InnerMeshNames entry, rebuilt after a core mesh loads or clears;
      the picker's Tag carries the InnerMeshNames index. }
    FInnerPartLabels: TList<TLabel>;
    FInnerPartColorBoxes: TList<TColorComboBox>;
    FInnerPartsHost: TLayout;
    FInnerPartsScroll: TScrollBox;
    FInnerNoPartsLabel: TLabel;
    { Appearance target radios: pick whether the Glow / Particle size /
      Softness / Rim power trackbars edit the outer head or the inner core.
      FInnerAppearanceTarget mirrors rbAppBrain's state for the track
      change handler. }
    rbAppHead: TRadioButton;
    rbAppBrain: TRadioButton;
    FInnerAppearanceTarget: Boolean;
    { References to the four target-dependent trackbars so the target
      toggle can reload their values from the active property set. }
    FTbGlow: TTrackBar;
    FTbParticleSize: TTrackBar;
    FTbSoftness: TTrackBar;
    FTbRimPower: TTrackBar;
    { Desktop Overlay tab: the drag-mode checkbox and the avatar-size
      trackbar, synced from GChaos every time the panel is shown. }
    FDragCheck: TCheckBox;
    FTbAvatarSize: TTrackBar;
    { Style combo and parts-mode checkbox, kept as references so a preset
      load can refresh them from the avatar state. }
    FStyleCombo: TComboBox;
    FAutoCheck: TCheckBox;
    { FAutomaticParts tracks the "Automatic" checkbox state: when True the
      loader applies its built-in auto-exclude list (hair/fur/mouth...); when
      False the per-part checkbox grid below wins and the auto-exclude list
      is bypassed so the user can re-include hair/teeth/etc. by ticking them. }
    FAutomaticParts: Boolean;
    function NewTab(const ACaption: string): TTabItem;
    function AddSection(const ACaption: string): TLabel;
    function AddLabel(const ACaption: string): TLabel;
    function AddTrack(ATag: Integer; const ACaption: string; AMin, AMax, AStep, AValue: Single; AEnabled: Boolean = True): TTrackBar;
    function AddCombo(ATag: Integer; const ACaption: string; const AItems: array of string; AIndex: Integer): TComboBox;
    function AddCheck(ATag: Integer; const ACaption: string; AChecked: Boolean): TCheckBox;
    procedure AddButton(const ACaption: string; AOnClick: TNotifyEvent);
    procedure OnTrackChange(Sender: TObject);
    procedure OnComboChange(Sender: TObject);
    procedure OnCheckChange(Sender: TObject);
    procedure OnFpsTimer(Sender: TObject);
    procedure OnLoadMesh(Sender: TObject);
    procedure OnLoadPhoto(Sender: TObject);
    procedure OnLoadDepth(Sender: TObject);
    { Inner core / brain tab handlers: pick / clear the custom core mesh and
      push per-part colour picks into GChaos.SetInnerPartColor. }
    procedure OnLoadInnerMesh(Sender: TObject);
    procedure OnClearInnerMesh(Sender: TObject);
    procedure OnInnerPartColorChange(Sender: TObject);
    { Mesh-parts live preview handler. }
    procedure OnPartToggle(Sender: TObject);
    { Per-part colour picker handler: pushes the picked colour into
      GChaos.SetPartColor using the picker's Tag as the part index. }
    procedure OnPartColorChange(Sender: TObject);
    procedure RebuildPartsList;
    { Mirrors RebuildPartsList for the custom inner core mesh: rebuilds the
      name + picker rows from GChaos.InnerMeshNames. }
    procedure RebuildInnerPartsList;
    { Appearance target toggle: reloads the four target-dependent trackbars
      from the newly selected property set (outer head or inner core). }
    procedure OnAppearanceTargetToggle(Sender: TObject);
    procedure SyncAppearanceTracks;
    { Desktop Overlay tab: drive the alive highlighter entity. }
    procedure OnTestHighlighter(Sender: TObject);
    procedure OnDismissHighlight(Sender: TObject);
    { Desktop Overlay tab: dock the avatar to a bottom corner of the screen. }
    procedure OnSnapBottomLeft(Sender: TObject);
    procedure OnSnapBottomRight(Sender: TObject);
    { Form lifecycle: hide keeps drag mode active (presets round-trip it
      and the tray menu can restore click-through), show refreshes the
      overlay controls from the live avatar. }
    procedure OnFormShow(Sender: TObject);
    procedure OnFormHide(Sender: TObject);
    procedure SyncOverlayControls;
    { Desktop Overlay tab: per-mesh preset save / load. }
    procedure OnSaveHeadPreset(Sender: TObject);
    procedure OnSavePresetAs(Sender: TObject);
    procedure OnLoadPreset(Sender: TObject);
    { Refreshes every panel control a preset can change (style combo,
      parts mode, appearance tracks, overlay controls). }
    procedure SyncControlsFromChaos;
    { Preset files default to <ExeDir>\presets so the dialogs open where
      the per-mesh automatic slots live. }
    function GetPresetFolder: string;
    procedure ApplyPartsFilter;
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
  tgBlinkInterval = 8;
  tgActiveTargetFPS = 9;
  tgIdleTargetFPS = 10;
  tgIdleTimeout = 11;
  tgStepFilter = 12;
  tgParticleBudget = 13;
  tgNeckPivot = 14;
  tgBlinkDuration = 15;
  tgCoreScale = 16;
  tgCoreOffsetY = 17;
  tgCoreBudget = 18;
  tgSoftness = 19;
  tgRimPower = 20;
  tgDragMode = 21;
  tgAvatarSize = 22;
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
  tgAutoParts = 7;

const
  { Layout constants - wider-than-tall window sized for a normal HD screen. }
  PANEL_W = 800;
  PANEL_H = 700;
  CTRL_X = 24;
  CTRL_W = 560;
  BTN_W = 260;

procedure TForm2.FormCreate(Sender: TObject);
var
  SnapL, SnapR: TButton;
begin
  Caption := 'Yutani Chaos - Controls';
  Self.ClientWidth := PANEL_W;
  Self.ClientHeight := PANEL_H;
  Self.Position := TFormPosition.ScreenCenter;
  Self.OnClose := FormClose;
  Self.OnDestroy := FormDestroy;
  Self.OnShow := OnFormShow;
  Self.OnHide := OnFormHide;

  FPartChecks := TList<TCheckBox>.Create;
  FPartCaptions := TList<string>.Create;
  FPartColorBoxes := TList<TColorComboBox>.Create;
  FInnerPartLabels := TList<TLabel>.Create;
  FInnerPartColorBoxes := TList<TColorComboBox>.Create;
  FAutomaticParts := True;

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
    AddSection('APPEARANCE TARGET');
    { Radios pick which property set the four target-dependent trackbars
      below edit: the outer head shell or the inner core / brain. IsChecked
      is assigned before OnChange is wired so setup cannot fire the toggle. }
    rbAppHead := TRadioButton.Create(Self);
    rbAppHead.Parent := FCurrentTab;
    rbAppHead.Position.X := CTRL_X;
    rbAppHead.Position.Y := FNextY;
    rbAppHead.Width := (CTRL_W div 2) - 4;
    rbAppHead.Text := 'Head / Outer';
    rbAppHead.GroupName := 'AppearanceTarget';
    rbAppHead.IsChecked := True;
    rbAppBrain := TRadioButton.Create(Self);
    rbAppBrain.Parent := FCurrentTab;
    rbAppBrain.Position.X := CTRL_X + (CTRL_W div 2);
    rbAppBrain.Position.Y := FNextY;
    rbAppBrain.Width := (CTRL_W div 2);
    rbAppBrain.Text := 'Brain / Inner Core';
    rbAppBrain.GroupName := 'AppearanceTarget';
    rbAppBrain.IsChecked := False;
    FInnerAppearanceTarget := False;
    rbAppHead.OnChange := OnAppearanceTargetToggle;
    rbAppBrain.OnChange := OnAppearanceTargetToggle;
    FNextY := FNextY + 30;
    AddSection('HOLO STYLE');
    FStyleCombo := AddCombo(tgHoloStyle, 'Style', ['Hologram', 'Android Circuit', 'Cyber Matrix', 'Blueprint', 'Solid'], Ord(GChaos.HoloStyle));
    AddSection('APPEARANCE');
    { The first four trackbars edit the active target above (outer head or
      inner core); rim light, holo alpha and jitter apply to the whole
      avatar regardless of the target. }
    FTbGlow := AddTrack(tgGlowIntensity, 'Glow', 0.0, 3.0, 0.05, GChaos.GlowIntensity);
    FTbParticleSize := AddTrack(tgParticleSize, 'Particle size', 0.1, 8.0, 0.1, GChaos.ParticleSize);
    FTbSoftness := AddTrack(tgSoftness, 'Softness', 0.10, 1.00, 0.02, GChaos.Softness);
    FTbRimPower := AddTrack(tgRimPower, 'Rim power', 0.5, 6.0, 0.05, GChaos.RimPower);
    AddTrack(tgRimLight, 'Rim light', 0.0, 3.0, 0.05, GChaos.RimLightStrength);
    AddTrack(tgHoloAlpha, 'Holo alpha', 0.0, 1.0, 0.02, GChaos.HoloAlpha);
    AddTrack(tgJitter, 'Jitter amount', 0.0, 2.0, 0.02, GChaos.JitterAmount);

    { ---- Tab 2: Mesh ---- }
    FMeshTab := NewTab('Mesh');
    FCurrentTab := FMeshTab;
    AddSection('MESH / PARTICLES');
    AddTrack(tgStepFilter, 'Step filter', 1, 12, 1, GChaos.StepFilter);
    AddTrack(tgParticleBudget, 'Particle budget', 500, 250000, 500, GChaos.ParticleBudget);
    AddSection('LOAD');
    AddButton('Load mesh...', OnLoadMesh);
    AddSection('PARTS');
    { "Automatic" ticked (default) means: load every surviving part with the
      built-in auto-exclude (hair/fur/mouth... removed). Untick it to take
      manual control - then only the ticked parts below are loaded, and the
      auto-exclude list is bypassed so hair/teeth/etc. can be re-included. }
    FAutoCheck := AddCheck(tgAutoParts, 'Automatic (auto-exclude hair/mouth...)', True);
    { Per-part checkbox list lives in a scroll box so a long mesh (rigged
      avatar with dozens of named parts) cannot overflow the tab. Using
      TScrollBox (vertical is the default) keeps it portable across FMX
      versions where TVertScrollBox lives in different units. }
    FMeshPartsScroll := TScrollBox.Create(Self);
    FMeshPartsScroll.Parent := FCurrentTab;
    FMeshPartsScroll.Position.X := CTRL_X;
    FMeshPartsScroll.Position.Y := FNextY;
    FMeshPartsScroll.Width := CTRL_W;
    FMeshPartsScroll.Height := 220;
    FMeshPartsScroll.Anchors := [TAnchorKind.akLeft, TAnchorKind.akRight, TAnchorKind.akTop, TAnchorKind.akBottom];
    FNextY := FNextY + 230;
    FMeshPartsHost := TLayout.Create(Self);
    FMeshPartsHost.Parent := FMeshPartsScroll;
    FMeshPartsHost.Align := TAlignLayout.Client;
    { FNoPartsLabel is shown when no mesh is loaded yet; RebuildPartsList
      hides it once a real parts list is built. }
    FNoPartsLabel := TLabel.Create(Self);
    FNoPartsLabel.Parent := FMeshPartsHost;
    FNoPartsLabel.Position.X := 8;
    FNoPartsLabel.Position.Y := 8;
    FNoPartsLabel.Width := CTRL_W - 16;
    FNoPartsLabel.Text := 'Load a .glb/.obj mesh to see its parts here.';
    RebuildPartsList;

    { ---- Tab 3: Photo & Depth ---- }
    FCurrentTab := NewTab('Photo & Depth');
    AddSection('LOAD');
    AddButton('Load photo...', OnLoadPhoto);
    AddButton('Load depthmap...', OnLoadDepth);
    AddLabel('Photo / depth-map sources have no named parts to toggle.');

    { ---- Tab 4: Inner Core / Brain ---- }
    FCurrentTab := NewTab('Inner Core / Brain');
    AddSection('INNER CORE');
    AddCheck(tgInnerCore, 'Enable inner core', GChaos.InnerCore);
    AddSection('CUSTOM CORE MESH');
    AddButton('Load brain / core mesh...', OnLoadInnerMesh);
    AddButton('Clear custom core mesh', OnClearInnerMesh);
    AddSection('PLACEMENT');
    AddTrack(tgCoreScale, 'Core scale', 0.10, 1.20, 0.02, GChaos.InnerCoreScale);
    AddTrack(tgCoreOffsetY, 'Core vertical offset', -80.0, 80.0, 1.0, GChaos.InnerCoreOffsetY);
    AddTrack(tgCoreBudget, 'Core particle budget', 2000, 100000, 1000, GChaos.InnerCoreBudget);
    AddSection('CORE PARTS');
    { Scrollable per-part colour list for the core mesh, mirroring the mesh
      tab's parts list: one name label plus a colour picker per
      InnerMeshNames entry so brain lobes / core sub-meshes tint live. }
    FInnerPartsScroll := TScrollBox.Create(Self);
    FInnerPartsScroll.Parent := FCurrentTab;
    FInnerPartsScroll.Position.X := CTRL_X;
    FInnerPartsScroll.Position.Y := FNextY;
    FInnerPartsScroll.Width := CTRL_W;
    FInnerPartsScroll.Height := 220;
    FInnerPartsScroll.Anchors := [TAnchorKind.akLeft, TAnchorKind.akRight, TAnchorKind.akTop, TAnchorKind.akBottom];
    FNextY := FNextY + 230;
    FInnerPartsHost := TLayout.Create(Self);
    FInnerPartsHost.Parent := FInnerPartsScroll;
    FInnerPartsHost.Align := TAlignLayout.Client;
    { Shown until a core mesh is loaded; RebuildInnerPartsList hides it once
      a real parts list is built. }
    FInnerNoPartsLabel := TLabel.Create(Self);
    FInnerNoPartsLabel.Parent := FInnerPartsHost;
    FInnerNoPartsLabel.Position.X := 8;
    FInnerNoPartsLabel.Position.Y := 8;
    FInnerNoPartsLabel.Width := CTRL_W - 16;
    FInnerNoPartsLabel.Text := 'Load a .glb/.obj core mesh to tint its parts.';
    RebuildInnerPartsList;

    { ---- Tab 5: Face / Animation ---- }
    FCurrentTab := NewTab('Face / Animation');
    AddSection('EMOTION');
    AddCombo(tgEmotion, 'Emotion', ['Neutral', 'Thinking', 'Happy', 'Alert'], Ord(GChaos.EmotionMode));
    AddSection('FACE');
    AddLabel('Mouth and eyes drive the holo shader (jaw hinge, dim-blink).');
    AddTrack(tgMouthOpen, 'Mouth open', 0.0, 1.0, 0.02, GChaos.MouthOpen);
    AddTrack(tgEyeOpeness, 'Eye openess', 0.0, 1.0, 0.02, GChaos.EyeOpeness);
    AddTrack(tgNeckPivot, 'Neck pivot', 0.0, 1.0, 0.01, GChaos.NeckPivotRatio);
    AddSection('AUTO-BLINK');
    AddTrack(tgBlinkInterval, 'Blink interval (s)', 0.5, 12.0, 0.1, GChaos.BlinkInterval);
    AddTrack(tgBlinkDuration, 'Blink speed / duration (s)', 0.10, 1.50, 0.02, GChaos.BlinkDuration);

    { ---- Tab 6: Desktop Overlay ---- }
    FCurrentTab := NewTab('Desktop Overlay');
    AddSection('ALIVE HIGHLIGHTER');
    { The test button sends the entity to this form's screen rectangle so
      the organic light-snake flies across the desktop and orbits the
      panel; GChaos draws it on top of the avatar image. }
    AddButton('Test highlighter (point to controls)', OnTestHighlighter);
    AddButton('Dismiss highlighter', OnDismissHighlight);
    AddLabel('The highlighter entity is drawn by GChaos, tinted with the accent colour.');
    AddSection('POSITION & SIZE');
    { Drag mode hands the avatar mouse input (click-through off) so the
      left button can carry it around the screen. }
    FDragCheck := AddCheck(tgDragMode, 'Drag avatar with mouse', GChaos.DragMode);
    { Corner docks: side by side so both presets sit on one row. }
    SnapL := TButton.Create(Self);
    SnapL.Parent := FCurrentTab;
    SnapL.Position.X := CTRL_X;
    SnapL.Position.Y := FNextY;
    SnapL.Width := BTN_W div 2;
    SnapL.Text := 'Snap Bottom-Left';
    SnapL.OnClick := OnSnapBottomLeft;
    SnapR := TButton.Create(Self);
    SnapR.Parent := FCurrentTab;
    SnapR.Position.X := CTRL_X + BTN_W div 2 + 8;
    SnapR.Position.Y := FNextY;
    SnapR.Width := BTN_W div 2 - 8;
    SnapR.Text := 'Snap Bottom-Right';
    SnapR.OnClick := OnSnapBottomRight;
    FNextY := FNextY + 34;
    FTbAvatarSize := AddTrack(tgAvatarSize, 'Avatar size (px)', 140, 640, 4, GChaos.Width);
    AddSection('PRESETS');
    { The per-head slot saves next to the executable, where the automatic
      reload finds it; the two dialog buttons cover sharing setups between
      heads or machines. }
    AddButton('Save preset for this head', OnSaveHeadPreset);
    AddButton('Save preset as...', OnSavePresetAs);
    AddButton('Load preset...', OnLoadPreset);

    { ---- Tab 7: System / Performance ---- }
    FCurrentTab := NewTab('System / Performance');
    AddSection('FRAME RATE');
    AddCheck(tgActive, 'Active', GChaos.Active);
    AddCheck(tgAdaptiveFPS, 'Adaptive FPS', GChaos.AdaptiveFPS);
    AddSection('WINDOW');
    AddCheck(tgMouseFollow, 'Mouse follow', GChaos.MouseFollow);
    AddCheck(tgStayOnTop, 'Stay on top', GChaos.StayOnTop);
    AddCheck(tgClickThrough, 'Click-through', GChaos.ClickThrough);
    AddTrack(tgActiveTargetFPS, 'Active target FPS', 5, 120, 1, GChaos.ActiveTargetFPS);
    AddTrack(tgIdleTargetFPS, 'Idle target FPS', 1, 60, 1, GChaos.IdleTargetFPS);
    AddTrack(tgIdleTimeout, 'Idle timeout (s)', 0.5, 30, 0.5, GChaos.IdleTimeoutSec);
    AddSection('LIVE');
    FFpsLabel := AddLabel('Real FPS: -');
    FIdleLabel := AddLabel('Idle: -');

    { The avatar may already run a restored startup preset (last.ini or the
      per-mesh automatic slot): sync every tab to that state now, so the
      panel opens showing the live style, part tints, inner parts and
      sizes instead of constructor defaults. }
    SyncControlsFromChaos;
    RebuildPartsList;
    RebuildInnerPartsList;
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
  FreeAndNil(FPartChecks);
  FreeAndNil(FPartCaptions);
  FreeAndNil(FPartColorBoxes);
  FreeAndNil(FInnerPartLabels);
  FreeAndNil(FInnerPartColorBoxes);
end;

procedure TForm2.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  { Hide instead of free so the tray can re-show us. Drag mode survives
    the hide: presets round-trip it, and the tray menu can restore
    click-through while the panel is closed. }
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

function TForm2.AddTrack(ATag: Integer; const ACaption: string; AMin, AMax, AStep, AValue: Single; AEnabled: Boolean): TTrackBar;
var
  L: TLabel;
  tb: TTrackBar;
  InitialText: string;
const
  { Integer-valued trackbars get a plain integer label (no decimal comma) -
    StepFilter / ParticleBudget / the FPS tiers are whole numbers, so
    "Particle budget: 250000.00" reads wrong. }
  INT_TAGS: set of Byte = [tgStepFilter, tgParticleBudget, tgActiveTargetFPS, tgIdleTargetFPS, tgAvatarSize];
begin
  if ATag in INT_TAGS then
    InitialText := ACaption + ': ' + IntToStr(Round(AValue))
  else
    InitialText := ACaption + ': ' + FormatFloat('0.00', AValue);
  L := AddLabel(InitialText);
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
  Result := tb;
end;

function TForm2.AddCombo(ATag: Integer; const ACaption: string; const AItems: array of string; AIndex: Integer): TComboBox;
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
  Result := cb;
end;

function TForm2.AddCheck(ATag: Integer; const ACaption: string; AChecked: Boolean): TCheckBox;
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
  Result := cb;
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

{==============================================================================
  Per-part checkbox list (live preview)
==============================================================================}
function IsExcludedName(const AName: string): Boolean;
var
  KW, LowName: string;
begin
  LowName := AName.ToLower;
  for KW in TMeshLoadOptions.Default.ExcludeKeywords do
    if (KW <> '') and LowName.Contains(KW.ToLower) then
      Exit(True);
  Result := False;
end;

function IsIncludedPartName(const AName: string): Boolean;
var
  N: string;
begin
  { Manual include mode: a part is visible iff its name is in the live
    filter, matching what the loader emits for a non-empty IncludeNames. }
  for N in GChaos.MeshIncludeNames do
    if SameText(N, AName) then
      Exit(True);
  Result := False;
end;

procedure TForm2.RebuildPartsList;
var
  Names: TArray<string>;
  I: Integer;
  cb: TCheckBox;
  ccb: TColorComboBox;
  OldY: Single;
begin
  { Tear down the previous checkbox grid and its colour pickers. The list is
    rebuilt after every LoadMeshFile/LoadPhotoFile/LoadDepthMap so the
    checkbox set always mirrors the currently loaded mesh's actual mesh-name
    list. }
  while FPartChecks.Count > 0 do
  begin
    cb := FPartChecks.Last;
    cb.Parent := nil;
    cb.Free;
    FPartChecks.Delete(FPartChecks.Count - 1);
  end;
  FPartCaptions.Clear;
  while FPartColorBoxes.Count > 0 do
  begin
    ccb := FPartColorBoxes.Last;
    ccb.Parent := nil;
    ccb.Free;
    FPartColorBoxes.Delete(FPartColorBoxes.Count - 1);
  end;

  if not Assigned(GChaos) then
  begin
    if Assigned(FNoPartsLabel) then
      FNoPartsLabel.Visible := True;
    Exit;

  end;

  Names := GChaos.MeshNames;
  if Length(Names) = 0 then
  begin
    { Photo / depth sources have no named parts to toggle. }
    if Assigned(FNoPartsLabel) then
    begin
      FNoPartsLabel.Visible := True;
      if GChaos.SourceType = srcPhoto then
        FNoPartsLabel.Text := 'Photo source - no named parts.'
      else
        FNoPartsLabel.Text := 'Load a .glb/.obj mesh to see its parts here.';
    end;
    Exit;
  end;

  if Assigned(FNoPartsLabel) then
    FNoPartsLabel.Visible := False;

  { Save/restore the next-row cursor because the parts list is laid out inside
    the scroll box, not on the tab page's main flow. }
  OldY := FNextY;
  FNextY := 6;
  for I := 0 to High(Names) do
  begin
    cb := TCheckBox.Create(Self);
    cb.Parent := FMeshPartsHost;
    cb.Position.X := 8;
    cb.Position.Y := FNextY;
    { Narrower than the host so the per-row colour picker fits on the
      right without the caption running underneath it. }
    cb.Width := CTRL_W - 126;
    cb.Text := Names[I];
    { Default: every part is included. Toggling off removes the part from the
      IncludeNames filter and triggers an immediate reload for live preview.
      A live manual include list wins over the auto-exclude guess, so a
      rebuilt grid reflects an applied preset's per-part visibility. }
    if Length(GChaos.MeshIncludeNames) > 0 then
      cb.IsChecked := IsIncludedPartName(Names[I])
    else
      cb.IsChecked := not IsExcludedName(Names[I]);
    cb.Tag := I;
    cb.OnChange := OnPartToggle;
    FPartChecks.Add(cb);
    FPartCaptions.Add(Names[I]);
    { Compact colour picker on the right of the row: picking a colour tints
      that part live via SetPartColor. The initial value is assigned before
      OnChange is wired so programmatic setup cannot fire the handler; parts
      without an override keep the picker's own default selection. }
    ccb := TColorComboBox.Create(Self);
    ccb.Parent := FMeshPartsHost;
    ccb.Position.X := CTRL_W - 114;
    ccb.Position.Y := FNextY;
    ccb.Width := 90;
    if Cardinal(GChaos.GetPartColor(I)) <> $00000000 then
      ccb.Color := GChaos.GetPartColor(I);
    ccb.Tag := I;
    ccb.OnChange := OnPartColorChange;
    FPartColorBoxes.Add(ccb);
    FNextY := FNextY + 26;
  end;
  FNextY := OldY;
end;

procedure TForm2.RebuildInnerPartsList;
var
  Names: TArray<string>;
  I: Integer;
  lbl: TLabel;
  ccb: TColorComboBox;
  OldY: Single;
begin
  { Tear down the previous core-part rows (name label + colour picker);
    the grid is rebuilt after every LoadInnerMeshFile / ClearInnerMesh so
    it always mirrors the currently loaded core mesh. }
  while FInnerPartColorBoxes.Count > 0 do
  begin
    ccb := FInnerPartColorBoxes.Last;
    ccb.Parent := nil;
    ccb.Free;
    FInnerPartColorBoxes.Delete(FInnerPartColorBoxes.Count - 1);
  end;
  while FInnerPartLabels.Count > 0 do
  begin
    lbl := FInnerPartLabels.Last;
    lbl.Parent := nil;
    lbl.Free;
    FInnerPartLabels.Delete(FInnerPartLabels.Count - 1);
  end;

  if not Assigned(GChaos) then
  begin
    if Assigned(FInnerNoPartsLabel) then
      FInnerNoPartsLabel.Visible := True;
    Exit;
  end;

  Names := GChaos.InnerMeshNames;
  if Length(Names) = 0 then
  begin
    { No core mesh loaded: keep the hint visible. }
    if Assigned(FInnerNoPartsLabel) then
    begin
      FInnerNoPartsLabel.Visible := True;
      FInnerNoPartsLabel.Text := 'Load a .glb/.obj core mesh to tint its parts.';
    end;
    Exit;
  end;

  if Assigned(FInnerNoPartsLabel) then
    FInnerNoPartsLabel.Visible := False;

  { Rows live inside the scroll box, so save/restore the next-row cursor the
    same way the mesh parts list does. }
  OldY := FNextY;
  FNextY := 6;
  for I := 0 to High(Names) do
  begin
    lbl := TLabel.Create(Self);
    lbl.Parent := FInnerPartsHost;
    lbl.Position.X := 8;
    lbl.Position.Y := FNextY + 2;
    lbl.Width := CTRL_W - 126;
    lbl.Text := Names[I];
    FInnerPartLabels.Add(lbl);
    { Compact colour picker beside the name: picking a colour tints that
      core part live via SetInnerPartColor. The initial value is assigned
      before OnChange is wired so programmatic setup cannot fire the
      handler; parts without an override keep the accent colour. }
    ccb := TColorComboBox.Create(Self);
    ccb.Parent := FInnerPartsHost;
    ccb.Position.X := CTRL_W - 114;
    ccb.Position.Y := FNextY;
    ccb.Width := 90;
    if Cardinal(GChaos.GetInnerPartColor(I)) <> $00000000 then
      ccb.Color := GChaos.GetInnerPartColor(I);
    ccb.Tag := I;
    ccb.OnChange := OnInnerPartColorChange;
    FInnerPartColorBoxes.Add(ccb);
    FNextY := FNextY + 26;
  end;
  FNextY := OldY;
end;

procedure TForm2.OnInnerPartColorChange(Sender: TObject);
var
  ccb: TColorComboBox;
begin
  if not Assigned(GChaos) then
    Exit;
  ccb := Sender as TColorComboBox;
  { Tag carries the part index in InnerMeshNames order. }
  GChaos.SetInnerPartColor(Integer(ccb.Tag), ccb.Color);
end;

procedure TForm2.ApplyPartsFilter;
var
  Filter: TArray<string>;
  I: Integer;
begin
  if not Assigned(GChaos) then
    Exit;

  if FAutomaticParts then
  begin
    GChaos.MeshIncludeNames := nil;
  end
  else
  begin
    SetLength(Filter, 0);
    for I := 0 to FPartChecks.Count - 1 do
      if FPartChecks[I].IsChecked then
      begin
        SetLength(Filter, Length(Filter) + 1);
        Filter[High(Filter)] := FPartCaptions[I];
      end;

    if Length(Filter) = 0 then
      Filter := ['__NONE__'];

    GChaos.MeshIncludeNames := Filter;
  end;

  if (GChaos.SourceType = srcMesh) and (Length(GChaos.MeshNames) > 0) then
    GChaos.ReloadCurrentSource;
end;

procedure TForm2.OnPartToggle(Sender: TObject);
begin
  { A per-part checkbox was toggled: if the user is manually curating parts
    (Automatic unticked) we take that as "manual mode" and reload with the
    new IncludeNames set. If Automatic is still ticked we ignore the toggle
    - the user has to untick Automatic first to take control of the list. }
  if not FAutomaticParts then
    ApplyPartsFilter;
end;

procedure TForm2.OnPartColorChange(Sender: TObject);
var
  ccb: TColorComboBox;
begin
  if not Assigned(GChaos) then
    Exit;
  ccb := Sender as TColorComboBox;
  { Tag carries the part index in MeshNames order, the same index the
    checkbox next to the picker uses. }
  GChaos.SetPartColor(Integer(ccb.Tag), ccb.Color);
end;

{==============================================================================
  Track / Combo / Check change handlers
==============================================================================}

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
        { Target-dependent knob: writes to the outer shell or the inner
          core, following the appearance radios at the tab top. }
        if FInnerAppearanceTarget then
          GChaos.InnerParticleSize := v
        else
          GChaos.ParticleSize := v;
        FValLabels[tgParticleSize].Text := 'Particle size: ' + FormatFloat('0.00', v);
      end;
    tgGlowIntensity:
      begin
        if FInnerAppearanceTarget then
          GChaos.InnerGlow := v
        else
          GChaos.GlowIntensity := v;
        FValLabels[tgGlowIntensity].Text := 'Glow: ' + FormatFloat('0.00', v);
      end;
    tgSoftness:
      begin
        if FInnerAppearanceTarget then
          GChaos.InnerSoftness := v
        else
          GChaos.Softness := v;
        FValLabels[tgSoftness].Text := 'Softness: ' + FormatFloat('0.00', v);
      end;
    tgRimPower:
      begin
        if FInnerAppearanceTarget then
          GChaos.InnerRimPower := v
        else
          GChaos.RimPower := v;
        FValLabels[tgRimPower].Text := 'Rim power: ' + FormatFloat('0.00', v);
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
        FValLabels[tgMouthOpen].Text := 'Mouth open: ' + FormatFloat('0.00', v);
      end;
    tgEyeOpeness:
      begin
        GChaos.EyeOpeness := v;
        FValLabels[tgEyeOpeness].Text := 'Eye openess: ' + FormatFloat('0.00', v);
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
    tgBlinkInterval:
      begin
        GChaos.BlinkInterval := v;
        FValLabels[tgBlinkInterval].Text := 'Blink interval (s): ' + FormatFloat('0.00', v);
      end;
    tgBlinkDuration:
      begin
        GChaos.BlinkDuration := v;
        FValLabels[tgBlinkDuration].Text := 'Blink speed / duration (s): ' + FormatFloat('0.00', v);
      end;
    tgCoreScale:
      begin
        GChaos.InnerCoreScale := v;
        FValLabels[tgCoreScale].Text := 'Core scale: ' + FormatFloat('0.00', v);
      end;
    tgCoreOffsetY:
      begin
        GChaos.InnerCoreOffsetY := v;
        FValLabels[tgCoreOffsetY].Text := 'Core vertical offset: ' + FormatFloat('0', v);
      end;
    tgCoreBudget:
      begin
        GChaos.InnerCoreBudget := Cardinal(Round(v));
        FValLabels[tgCoreBudget].Text := 'Core particle budget: ' + IntToStr(Round(v));
      end;
    tgAvatarSize:
      begin
        { Live resize: GChaos keeps the aspect and re-fits the mesh clouds;
          the label mirrors the pixel width the user asked for. }
        GChaos.SetAvatarSize(Round(v));
        FValLabels[tgAvatarSize].Text := 'Avatar size (px): ' + IntToStr(Round(v));
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
        if v <= 0.001 then
          FValLabels[tgNeckPivot].Text := 'Neck pivot: OFF (Rigid Head)'
        else
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
    tgDragMode:
      GChaos.DragMode := cb.IsChecked;
    tgAutoParts:
      begin
        { Toggling Automatic switches between auto-exclude mode (tick) and
          manual per-part mode (untick). In manual mode we immediately reload
          with the current checkbox set so the avatar reflects the choice. }
        FAutomaticParts := cb.IsChecked;
        ApplyPartsFilter;
      end;
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

{==============================================================================
  Source reload handlers
==============================================================================}

procedure TForm2.OnLoadMesh(Sender: TObject);
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
    begin
      { Reset the per-part filter on a fresh file pick so every part is shown
        by default; RebuildPartsList then mirrors the newly loaded mesh's
        actual mesh-name list. }
      GChaos.MeshIncludeNames := nil;
      GChaos.LoadMeshFile(dlg.FileName, Min(GChaos.Width, GChaos.Height) * 0.45, GChaos.StepFilter, GChaos.ParticleBudget);
      RebuildPartsList;
    end;
  finally
    dlg.Free;
  end;
end;

procedure TForm2.OnLoadPhoto(Sender: TObject);
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
    begin
      GChaos.LoadPhotoFile(dlg.FileName, Min(GChaos.Width, GChaos.Height) * 0.45, GChaos.StepFilter, GChaos.ParticleBudget);
      RebuildPartsList;
    end;
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
    begin
      GChaos.LoadDepthMap(dlg.FileName);
      RebuildPartsList;
    end;
  finally
    dlg.Free;
  end;
end;

procedure TForm2.OnLoadInnerMesh(Sender: TObject);
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
    begin
      GChaos.LoadInnerMeshFile(dlg.FileName);
      RebuildInnerPartsList;
    end;
  finally
    dlg.Free;
  end;
end;

procedure TForm2.OnClearInnerMesh(Sender: TObject);
begin
  if not Assigned(GChaos) then
    Exit;
  GChaos.ClearInnerMesh;
  RebuildInnerPartsList;
end;

procedure TForm2.OnAppearanceTargetToggle(Sender: TObject);
begin
  { Whichever radio fires last sees the settled group state, so reading
    rbAppBrain.IsChecked here is stable for both toggle directions. }
  FInnerAppearanceTarget := Assigned(rbAppBrain) and rbAppBrain.IsChecked;
  SyncAppearanceTracks;
end;

procedure TForm2.SyncAppearanceTracks;
var
  Glow, Size, Soft, Rim: Single;
begin
  if not Assigned(GChaos) then
    Exit;
  { Reload the four target-dependent trackbars from the active property
    set. OnChange stays disconnected while assigning so the programmatic
    value updates cannot write back into the properties they came from. }
  if FInnerAppearanceTarget then
  begin
    Glow := GChaos.InnerGlow;
    Size := GChaos.InnerParticleSize;
    Soft := GChaos.InnerSoftness;
    Rim := GChaos.InnerRimPower;
  end
  else
  begin
    Glow := GChaos.GlowIntensity;
    Size := GChaos.ParticleSize;
    Soft := GChaos.Softness;
    Rim := GChaos.RimPower;
  end;
  FTbGlow.OnChange := nil;
  FTbParticleSize.OnChange := nil;
  FTbSoftness.OnChange := nil;
  FTbRimPower.OnChange := nil;
  FTbGlow.Value := Glow;
  FTbParticleSize.Value := Size;
  FTbSoftness.Value := Soft;
  FTbRimPower.Value := Rim;
  FTbGlow.OnChange := OnTrackChange;
  FTbParticleSize.OnChange := OnTrackChange;
  FTbSoftness.OnChange := OnTrackChange;
  FTbRimPower.OnChange := OnTrackChange;
  FValLabels[tgGlowIntensity].Text := 'Glow: ' + FormatFloat('0.00', Glow);
  FValLabels[tgParticleSize].Text := 'Particle size: ' + FormatFloat('0.00', Size);
  FValLabels[tgSoftness].Text := 'Softness: ' + FormatFloat('0.00', Soft);
  FValLabels[tgRimPower].Text := 'Rim power: ' + FormatFloat('0.00', Rim);
end;

procedure TForm2.OnTestHighlighter(Sender: TObject);
begin
  if not Assigned(GChaos) then
    Exit;
  { Screen rectangle of this panel: the entity flies across the desktop and
    orbits the form so it points at the controls. }
  GChaos.HighlightRect(TRectF.Create(Self.Left, Self.Top, Self.Left + Self.Width, Self.Top + Self.Height));
end;

procedure TForm2.OnDismissHighlight(Sender: TObject);
begin
  if not Assigned(GChaos) then
    Exit;
  GChaos.DismissHighlight;
end;

procedure TForm2.OnSnapBottomLeft(Sender: TObject);
begin
  if not Assigned(GChaos) then
    Exit;
  GChaos.SnapBottomLeft;
end;

procedure TForm2.OnSnapBottomRight(Sender: TObject);
begin
  if not Assigned(GChaos) then
    Exit;
  GChaos.SnapBottomRight;
end;

procedure TForm2.OnFormShow(Sender: TObject);
begin
  { Every re-show (tray "Show controls", close/hide cycle) refreshes the
    overlay controls from the live avatar state. }
  SyncOverlayControls;
end;

procedure TForm2.OnFormHide(Sender: TObject);
begin
  { Drag mode intentionally survives hiding: it is part of the placement
    presets and the tray menu can restore click-through while the panel
    is closed. Kept as the OnFormHide hook so the intent stays explicit
    where the close path cascades into it through caHide. }
end;

procedure TForm2.SyncOverlayControls;
var
  SizePx: Integer;
begin
  if not Assigned(GChaos) or not Assigned(FDragCheck) then
    Exit;
  { Programmatic checkbox / trackbar updates must not fire their change
    handlers and write back into the properties they came from. }
  FDragCheck.OnChange := nil;
  FDragCheck.IsChecked := GChaos.DragMode;
  FDragCheck.OnChange := OnCheckChange;
  SizePx := Max(Round(GChaos.Width), 1);
  FTbAvatarSize.OnChange := nil;
  FTbAvatarSize.Value := EnsureRange(SizePx, Round(FTbAvatarSize.Min), Round(FTbAvatarSize.Max));
  FTbAvatarSize.OnChange := OnTrackChange;
  FValLabels[tgAvatarSize].Text := 'Avatar size (px): ' + IntToStr(SizePx);
end;

function TForm2.GetPresetFolder: string;
begin
  { Dialogs open where the per-mesh automatic slots live, so saving "as"
    and loading browse the same pool the avatar restores from. }
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'presets';
end;

procedure TForm2.OnSaveHeadPreset(Sender: TObject);
begin
  if not Assigned(GChaos) then
    Exit;
  GChaos.SaveCurrentMeshPreset;
end;

procedure TForm2.OnSavePresetAs(Sender: TObject);
var
  Dlg: TSaveDialog;
begin
  if not Assigned(GChaos) then
    Exit;
  ForceDirectories(GetPresetFolder);
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Title := 'Save chaos preset';
    Dlg.Filter := 'Chaos Preset (*.ini)|*.ini';
    Dlg.DefaultExt := '.ini';
    Dlg.InitialDir := GetPresetFolder;
    Dlg.Options := [TOpenOption.ofOverwritePrompt];
    if Dlg.Execute then
      GChaos.SavePresetToFile(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

procedure TForm2.OnLoadPreset(Sender: TObject);
var
  Dlg: TOpenDialog;
  Dir: string;
begin
  if not Assigned(GChaos) then
    Exit;
  Dir := GetPresetFolder;
  if not DirectoryExists(Dir) then
    Dir := ExtractFilePath(ParamStr(0));
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := 'Load chaos preset';
    Dlg.Filter := 'Chaos Preset (*.ini)|*.ini';
    Dlg.InitialDir := Dir;
    if Dlg.Execute and GChaos.LoadPresetFromFile(Dlg.FileName) then
    begin
      { The preset may have switched the mesh and the inner mesh, restyled
        the avatar, moved and resized it, and re-tinted every part: rebuild
        the whole panel state from the live avatar. }
      SyncControlsFromChaos;
      RebuildPartsList;
      RebuildInnerPartsList;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TForm2.SyncControlsFromChaos;
var
  StyleIdx: Integer;
begin
  if not Assigned(GChaos) then
    Exit;
  { Style combo: guard the index so a future enum growth cannot raise. }
  if Assigned(FStyleCombo) then
  begin
    StyleIdx := Ord(GChaos.HoloStyle);
    if (StyleIdx >= 0) and (StyleIdx < FStyleCombo.Items.Count) then
    begin
      FStyleCombo.OnChange := nil;
      FStyleCombo.ItemIndex := StyleIdx;
      FStyleCombo.OnChange := OnComboChange;
    end;
  end;
  { Parts mode: a preset applies an explicit per-part setup, so the panel
    mirrors the manual / automatic state of the include list. }
  if Assigned(FAutoCheck) then
  begin
    FAutoCheck.OnChange := nil;
    FAutoCheck.IsChecked := Length(GChaos.MeshIncludeNames) = 0;
    FAutoCheck.OnChange := OnCheckChange;
    FAutomaticParts := FAutoCheck.IsChecked;
  end;
  SyncAppearanceTracks;
  SyncOverlayControls;
end;

end.

