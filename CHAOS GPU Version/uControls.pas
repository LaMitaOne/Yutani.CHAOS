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
  System.IniFiles, System.IOUtils,
  System.Math, System.Generics.Collections, Winapi.Windows, Winapi.ShellAPI,
  FMX.Types, FMX.Controls, FMX.Forms,
  FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.ListBox, FMX.Colors, FMX.Layouts,
  FMX.TabControl, FMX.Menus, FMX.Edit, FMX.Memo, FMX.Platform, FMX.Clipboard,
  Yutani.Chaos.Skia.GPU, Yutani.MeshLoader;

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
    { Desktop Overlay tab: the drag-mode checkbox, the auto-dim checkbox and
      the avatar-size trackbar, synced from GChaos every time the panel is
      shown. }
    FDragCheck: TCheckBox;
    FAutoDimCheck: TCheckBox;
    { Send-to-monitor dropdown: rebuilt from the live display list every
      time it opens (hot-plug safe), so no stale entries survive a dock
      / beamer change. The check mark marks the monitor the host window
      currently sits on. }
    FMonitorMenu: TPopupMenu;
    { Behavior toggles (Face / Animation tab): kept as fields so preset
      loads can re-sync them without re-scanning the control tree. }
    FTouchEffectsCheck: TCheckBox;
    FIdleLifeCheck: TCheckBox;
    FNaturalBlinkCheck: TCheckBox;
    { TouchEffects row: effect style combo (ItemIndex =
      Ord(TChaosTouchEffectStyle)) and accent colour picker sitting
      directly right of the checkbox; both enable/disable with its
      Checked state (UpdateTouchEffectEnable). }
    FTouchEffectCombo: TComboBox;
    FTouchEffectColorBox: TColorComboBox;
    FTbAvatarSize: TTrackBar;
    { Mesh tab: combo picking which mesh part acts as the eyes. '(Auto)' is
      the first entry followed by every MeshNames entry; Tag stays unused,
      the selection maps to GChaos.CustomEyePartName. }
    FEyeCombo: TComboBox;
    { Style combo and parts-mode checkbox, kept as references so a preset
      load can refresh them from the avatar state. }
    FStyleCombo: TComboBox;
    FAutoCheck: TCheckBox;
    { System / Performance tab track + check references so a preset load
      can refresh the FPS tiers and the neck pivot from the avatar state. }
    FTbActiveFPS: TTrackBar;
    FTbIdleFPS: TTrackBar;
    FTbIdleTimeout: TTrackBar;
    { Particle budget slider (System tab) - kept as a field so the Info /
      Debug tab's Apply Recommended Particle Budget button can mirror it. }
    FTbParticleBudget: TTrackBar;
    FTbNeckPivot: TTrackBar;
    FAdaptiveCheck: TCheckBox;
    { FAutomaticParts tracks the "Automatic" checkbox state: when True the
      loader applies its built-in auto-exclude list (hair/fur/mouth...); when
      False the per-part checkbox grid below wins and the auto-exclude list
      is bypassed so the user can re-include hair/teeth/etc. by ticking them. }
    FAutomaticParts: Boolean;
    { ---- AI & Voice tab --------------------------------------------------
      Model combos auto-scan vosk\* / sherpa\* folders next to the EXE and
      accept manual folder picks through Browse... (SelectDirectory), so any
      language / path works. The endpoint edits + system prompt round-trip
      through the INI; the live-test row talks straight to the avatar's
      AI client / voice pipeline. }
    { Two INDEPENDENT voice toggles (one master switch was too coarse):
      TTS = speech output (Piper/SAPI + lip-sync), STT = microphone +
      Vosk recognition. Both off = pure text chat. }
    FTtsEnableCheck: TCheckBox;
    FSttEnableCheck: TCheckBox;
    FMicLipSyncCheck: TCheckBox;
    FVoskCombo: TComboBox;
    FVoskBrowseBtn: TButton;
    { Download buttons next to Reload models: open the official model pages
      in the browser (ShellExecute). }
    FDownloadVoskBtn: TButton;
    FDownloadPiperBtn: TButton;
    FPiperCombo: TComboBox;
    FPiperBrowseBtn: TButton;
    FBaseUrlEdit: TEdit;
    FModelEdit: TEdit;
    FApiKeyEdit: TEdit;
    { System prompt as multi-line TMemo: the prompt is a whole paragraph,
      TEdit would force it into one scroll-less line. }
    FSystemPromptEdit: TMemo;
    FAskEdit: TEdit;
    FSendBtn: TButton;
    FTestTtsBtn: TButton;
    FVoiceStatusLbl: TLabel;
    { ---- Info / Debug tab -------------------------------------------------
      Top: GPU & SYSTEM INFO block (live snapshot from the avatar's GL init
      detection) + Apply Recommended Particle Budget. Bottom: the
      thread-safe DEBUG LOG ring buffer mirror in a read-only memo. }
    FGpuInfoLbl: TLabel;
    FApplyGpuBudgetBtn: TButton;
    FDebugMemo: TMemo;
    FCopyLogBtn: TButton;
    FClearLogBtn: TButton;
    { Debug-log mirror state: last serial the memo text was built from, so
      OnFpsTimer only rebuilds the memo when NEW lines actually arrived -
      scrolling / marking inside the memo stays undisturbed otherwise. }
    FLastLogSerial: Integer;
    { AI & voice settings file: <ExeDir>\ai.ini, separate from the per-mesh
      presets so it survives mesh switches. }
    { Parallel path arrays behind the model combos: the combos show SHORT
      names (ExtractFileName) so long paths cannot blow up the layout,
      while the full paths - what the pipeline and the INI need - live in
      these arrays at the same index as the combo entry. }
    FVoskPaths: TStringList;
    FPiperPaths: TStringList;
    { TRUE while LoadAiSettings pushes INI values into the controls: their
      OnChange / OnTyping handlers (OnTtsEnableToggle etc.) would otherwise
      fire DURING the load and call SaveAiSettings with the still-empty /
      default control state, instantly overwriting ai.ini with defaults. }
    FLoadingAiSettings: Boolean;
    { Adds a full model path to a combo + its parallel array (displaying the
      short name), selecting it; returns True when the entry was new. }
    function SelectModelEntry(ACombo: TComboBox; APaths: TStringList;
      const AFullPath: string): Boolean;
    { Model path for the combo's current selection ('' when none). }
    function PathForComboIndex(ACombo: TComboBox; APaths: TStringList): string;
    function GetAiIniPath: string;
    function SelectedVoskDir: string;
    function SelectedPiperVoice: string;
    procedure FillModelCombos;
    procedure FillCombo(cb: TComboBox; const AFolders: array of string);
    procedure LoadAiSettings;
    procedure SaveAiSettings;
    { Handlers: master toggles, model combos, browse buttons, reloads, live
      test row (Ask / Send to AI / Test TTS) and the status timer refresh. }
    procedure OnTtsEnableToggle(Sender: TObject);
    procedure OnSttEnableToggle(Sender: TObject);
    procedure OnMicLipSyncToggle(Sender: TObject);
    procedure OnVoskComboChange(Sender: TObject);
    procedure OnPiperComboChange(Sender: TObject);
    procedure OnBrowseVosk(Sender: TObject);
    procedure OnBrowsePiper(Sender: TObject);
    { Download buttons: open the official model pages in the default browser
      (ShellExecute 'open'), so the user lands on the right download source
      without hunting for it. }
    procedure OnDownloadVoskModels(Sender: TObject);
    procedure OnDownloadPiperVoices(Sender: TObject);
    procedure OnReloadModels(Sender: TObject);
    procedure OnAskSend(Sender: TObject);
    { Enter in FAskEdit fires the send: the main vkReturn key routes
      straight into OnAskSend. }
    procedure OnAskKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure OnTestTts(Sender: TObject);
    procedure OnAiSettingChange(Sender: TObject);
    { Key-level net for the endpoint edits: OnTyping does NOT fire on FMX
      for clipboard pastes (Ctrl+V / right-click insert), so every key-up
      (including Ctrl on paste) lands in ai.ini too. }
    procedure OnAiKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    { Info / Debug tab handlers: apply the GPU-recommended particle budget
      onto the avatar + the System tab slider, copy / clear the log memo. }
    procedure OnApplyGpuBudget(Sender: TObject);
    procedure OnCopyDebugLog(Sender: TObject);
    procedure OnClearDebugLog(Sender: TObject);
    { Rebuilds the Info / Debug tab's GPU info block from the live avatar
      (detection may land AFTER the panel was built - GL init is lazy). }
    procedure RefreshGpuInfo;
    { Re-applies the whole AI & voice state onto the avatar after an INI
      load: master toggle, mic / lip-sync mode, client config, pipeline. }
    procedure ApplyAiSettingsToChaos;
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
    { Mesh tab: eye-part combo handler - writes the picked part name into
      GChaos.CustomEyePartName and rebuilds the particle cloud so the eye
      flag lands on the chosen part. }
    procedure OnEyePartChange(Sender: TObject);
    { TouchEffects row: accent colour picker handler plus the shared
      enable/disable refresh for both selectors. }
    procedure OnTouchEffectColorChange(Sender: TObject);
    procedure UpdateTouchEffectEnable;
    procedure RebuildPartsList;
    { Refreshes the eye-part combo from GChaos.MeshNames: '(Auto)' first,
      then every part name, selection mirroring CustomEyePartName. Also
      called after a mesh load or a preset apply. }
    procedure SyncEyeCombo;
    { Mirrors RebuildPartsList for the custom inner core mesh: rebuilds the
      name + picker rows from GChaos.InnerMeshNames. }
    procedure RebuildInnerPartsList;
    { Appearance target toggle: reloads the four target-dependent trackbars
      from the newly selected property set (outer head or inner core). }
    procedure OnAppearanceTargetToggle(Sender: TObject);
    procedure SyncAppearanceTracks;
    { Desktop Overlay tab: drive the alive highlighter entity. Test enables
      mouse-follow mode so the entity chases the live cursor; dismiss turns
      the mode off and walks the entity out. }
    procedure OnTestHighlighter(Sender: TObject);
    procedure OnDismissHighlight(Sender: TObject);
    { Send-to-monitor: opens the live monitor list under the button and
      applies the picked entry via GChaos.SendToDisplay. }
    procedure OnSendToScreen(Sender: TObject);
    procedure OnPickMonitor(Sender: TObject);
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
    { Final-exit save for external forms (Unit1.FormDestroy): persists
      ai.ini when the AI tab was built - a pasted endpoint value that fired
      no OnTyping/OnChange event must not be lost on quit. }
    procedure SaveSettingsIfBuilt;
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
  tgActiveTargetFPS = 9;
  tgIdleTargetFPS = 10;
  tgIdleTimeout = 11;
  tgStepFilter = 12;
  tgParticleBudget = 13;
  tgNeckPivot = 14;
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
  { Touch effect style combo: ItemIndex maps 1:1 onto
    Ord(TChaosTouchEffectStyle) in the CHAOS unit. }
  tgTouchEffectStyle = 3;
  { Checkbox tags. }
  tgActive = 1;
  tgAdaptiveFPS = 2;
  tgInnerCore = 3;
  tgMouseFollow = 4;
  tgStayOnTop = 5;
  tgClickThrough = 6;
  tgAutoParts = 7;
  tgAutoDim = 8;
  tgTouchEffects = 9;
  tgIdleLife = 10;
  tgNaturalBlink = 11;

const
  { Layout constants - wider-than-tall window sized for a normal HD screen.
    The extra height (920) hosts the new AI & Voice tab with its model
    combos, endpoint fields and the live-test row. }
  PANEL_W = 900;
  PANEL_H = 920;
  CTRL_X = 24;
  CTRL_W = 560;
  BTN_W = 260;

procedure TForm2.FormCreate(Sender: TObject);
var
  { Row cursor captured before the TouchEffects checkbox is added so the
    style combo and the colour picker can sit on the same row, directly
    right of the toggle. }
  TouchY: Single;
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
    FTbParticleBudget := AddTrack(tgParticleBudget, 'Particle budget', 500, 250000, 500, GChaos.ParticleBudget);
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
    { Eye-part override: '(Auto)' keeps the automatic eye-name detection,
      picking a concrete part flags exactly that mesh as the eyes. The list
      refreshes on every mesh load via RebuildPartsList. }
    AddLabel('Use part as eyes:');
    FEyeCombo := TComboBox.Create(Self);
    FEyeCombo.Parent := FCurrentTab;
    FEyeCombo.Position.X := CTRL_X;
    FEyeCombo.Position.Y := FNextY;
    FEyeCombo.Width := CTRL_W;
    FEyeCombo.Items.Add('(Auto)');
    FEyeCombo.ItemIndex := 0;
    FEyeCombo.OnChange := OnEyePartChange;
    SyncEyeCombo;
    FNextY := FNextY + 44;

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
    FTbNeckPivot := AddTrack(tgNeckPivot, 'Neck pivot', 0.0, 1.0, 0.01, GChaos.NeckPivotRatio);
    AddSection('BEHAVIOR');
    { Feature toggles for isolated measurement / disabling - the direct
      counterparts of the TouchEffectsEnabled / IdleLifeMotion /
      NaturalBlinking properties on TSkChaos. }
    TouchY := FNextY;
    FTouchEffectsCheck := AddCheck(tgTouchEffects, 'TouchEffects', GChaos.TouchEffectsEnabled);
    { Narrow the checkbox so the style combo and the accent colour picker
      fit onto the same row, directly right of the toggle. }
    FTouchEffectsCheck.Width := 150;
    { Effect style combo: the four entries map 1:1 onto
      TChaosTouchEffectStyle (FMX TComboBox is a pure drop-down list, the
      built-in equivalent of the VCL csDropDownList). }
    FTouchEffectCombo := TComboBox.Create(Self);
    FTouchEffectCombo.Parent := FCurrentTab;
    FTouchEffectCombo.Position.X := CTRL_X + 160;
    FTouchEffectCombo.Position.Y := TouchY;
    FTouchEffectCombo.Width := 140;
    FTouchEffectCombo.Items.Add('Forcefield');
    FTouchEffectCombo.Items.Add('Glow');
    FTouchEffectCombo.Items.Add('ColorFade');
    FTouchEffectCombo.Items.Add('Ripple');
    { Initial selection assigned before OnChange is wired so the
      programmatic setup cannot fire the handler (same pattern as the
      per-part colour pickers). }
    FTouchEffectCombo.ItemIndex := Ord(GChaos.TouchEffectStyle);
    FTouchEffectCombo.Tag := tgTouchEffectStyle;
    FTouchEffectCombo.OnChange := OnComboChange;
    { Touch accent colour picker right beside the style combo, built
      after the same component pattern as the per-part colour
      selectors (TColorComboBox). }
    FTouchEffectColorBox := TColorComboBox.Create(Self);
    FTouchEffectColorBox.Parent := FCurrentTab;
    FTouchEffectColorBox.Position.X := CTRL_X + 310;
    FTouchEffectColorBox.Position.Y := TouchY;
    FTouchEffectColorBox.Width := 100;
    FTouchEffectColorBox.Color := GChaos.TouchEffectColor;
    FTouchEffectColorBox.OnChange := OnTouchEffectColorChange;
    { Both selectors follow the TouchEffects checkbox's Checked state. }
    UpdateTouchEffectEnable;
    FIdleLifeCheck := AddCheck(tgIdleLife, 'Idle breathing & micro-glances', GChaos.IdleLifeMotion);
    FNaturalBlinkCheck := AddCheck(tgNaturalBlink, 'Natural random blinking', GChaos.NaturalBlinking);

    { ---- Tab 6: Desktop Overlay ---- }
    FCurrentTab := NewTab('Desktop Overlay');
    AddSection('ALIVE HIGHLIGHTER');
    { Test turns on mouse-follow mode: the entity chases the live cursor
      (converted into GChaos' local frame every frame) instead of flying to
      a one-off rectangle. Dismiss turns the mode off and walks the entity
      out with its exit animation. }
    AddButton('Test highlighter (follow mouse)', OnTestHighlighter);
    AddButton('Dismiss highlighter', OnDismissHighlight);
    AddLabel('The highlighter entity is drawn by the desktop overlay on Form1, tinted with the accent colour.');
    AddSection('POSITION & SIZE');
    { Drag mode hands the avatar mouse input (click-through off) so the
      left button can carry it around the screen. }
    FDragCheck := AddCheck(tgDragMode, 'Drag avatar with mouse', GChaos.DragMode);
    { Auto-dim: eases the avatar alpha toward AUTO_DIM_ALPHA while the
      cursor hovers its screen rect, back to full when it leaves. }
    FAutoDimCheck := AddCheck(tgAutoDim, 'Auto-dim on mouseover', GChaos.AutoDimOnHover);
    FNextY := FNextY + 4;
    FTbAvatarSize := AddTrack(tgAvatarSize, 'Avatar size (px)', 140, 1200, 4, GChaos.Width);
    { Send to Screen: opens the live monitor list; picking an entry moves
      and exactly fits the overlay window onto that monitor. }
    AddButton('Send to Screen', OnSendToScreen);
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
    FAdaptiveCheck := AddCheck(tgAdaptiveFPS, 'Adaptive FPS', GChaos.AdaptiveFPS);
    AddSection('WINDOW');
    AddCheck(tgMouseFollow, 'Mouse follow', GChaos.MouseFollow);
    AddCheck(tgStayOnTop, 'Stay on top', GChaos.StayOnTop);
    AddCheck(tgClickThrough, 'Click-through', GChaos.ClickThrough);
    FTbActiveFPS := AddTrack(tgActiveTargetFPS, 'Active target FPS', 5, 120, 1, GChaos.ActiveTargetFPS);
    FTbIdleFPS := AddTrack(tgIdleTargetFPS, 'Idle target FPS', 1, 60, 1, GChaos.IdleTargetFPS);
    FTbIdleTimeout := AddTrack(tgIdleTimeout, 'Idle timeout (s)', 0.5, 30, 0.5, GChaos.IdleTimeoutSec);
    AddSection('LIVE');
    FFpsLabel := AddLabel('Real FPS: -');
    FIdleLabel := AddLabel('Idle: -');

    { ---- Tab 8: AI & Voice ---- }
    FCurrentTab := NewTab('AI & Voice');
    AddSection('VOICE AI');
    { Two INDEPENDENT toggles instead of one coupled master switch:
      TTS-only starts just ma_engine + TYutaniPiperTTS (no capture device,
      no libvosk.dll), STT-only starts just ma_device capture + Vosk (AI
      answers appear as text + head gestures, no audio). Pure text chat
      (Ask / Send to AI below) works with both off. }
    FTtsEnableCheck := AddCheck(60, 'Enable TTS (Voice Output)', False);
    FTtsEnableCheck.OnChange := OnTtsEnableToggle;
    FSttEnableCheck := AddCheck(61, 'Enable STT (Microphone / Vosk)', False);
    FSttEnableCheck.OnChange := OnSttEnableToggle;
    { OBS / creator mode: the microphone only drives the mouth animation;
      recognized text is never sent to the AI. }
    FMicLipSyncCheck := AddCheck(62, 'Mic Lip-Sync Only (OBS Mode)', False);
    FMicLipSyncCheck.OnChange := OnMicLipSyncToggle;
    AddSection('STT / TTS MODELS');
    { Vosk model combo: auto-scan of vosk\* folders + manual Browse. }
    AddLabel('Vosk STT Model (auto-scan vosk\\*):');
    FVoskCombo := TComboBox.Create(Self);
    FVoskCombo.Parent := FCurrentTab;
    FVoskCombo.Position.X := CTRL_X;
    FVoskCombo.Position.Y := FNextY;
    FVoskCombo.Width := CTRL_W - 110;
    FVoskCombo.Tag := 60;
    FVoskCombo.OnChange := OnVoskComboChange;
    FVoskBrowseBtn := TButton.Create(Self);
    FVoskBrowseBtn.Parent := FCurrentTab;
    FVoskBrowseBtn.Position.X := CTRL_X + CTRL_W - 100;
    FVoskBrowseBtn.Position.Y := FNextY;
    FVoskBrowseBtn.Width := 96;
    FVoskBrowseBtn.Text := 'Browse...';
    FVoskBrowseBtn.OnClick := OnBrowseVosk;
    FNextY := FNextY + 40;
    { Reload re-scans the model folders (new files / drives). }
    AddButton('Reload models', OnReloadModels);
    { Download buttons: open the official model download pages in the
      browser - compact width, placed right of Reload models so the whole
      model-acquisition row stays together. }
    FDownloadVoskBtn := TButton.Create(Self);
    FDownloadVoskBtn.Parent := FCurrentTab;
    FDownloadVoskBtn.Position.X := CTRL_X + 270;
    FDownloadVoskBtn.Position.Y := FNextY - 34;
    FDownloadVoskBtn.Width := 150;
    FDownloadVoskBtn.Text := 'Download Vosk Models';
    FDownloadVoskBtn.OnClick := OnDownloadVoskModels;
    FDownloadPiperBtn := TButton.Create(Self);
    FDownloadPiperBtn.Parent := FCurrentTab;
    FDownloadPiperBtn.Position.X := CTRL_X + 430;
    FDownloadPiperBtn.Position.Y := FNextY - 34;
    FDownloadPiperBtn.Width := 150;
    FDownloadPiperBtn.Text := 'Download Piper Voices';
    FDownloadPiperBtn.OnClick := OnDownloadPiperVoices;
    AddLabel('Piper TTS Voice (auto-scan sherpa\\*):');
    FPiperCombo := TComboBox.Create(Self);
    FPiperCombo.Parent := FCurrentTab;
    FPiperCombo.Position.X := CTRL_X;
    FPiperCombo.Position.Y := FNextY;
    FPiperCombo.Width := CTRL_W - 110;
    FPiperCombo.Tag := 61;
    FPiperCombo.OnChange := OnPiperComboChange;
    FPiperBrowseBtn := TButton.Create(Self);
    FPiperBrowseBtn.Parent := FCurrentTab;
    FPiperBrowseBtn.Position.X := CTRL_X + CTRL_W - 100;
    FPiperBrowseBtn.Position.Y := FNextY;
    FPiperBrowseBtn.Width := 96;
    FPiperBrowseBtn.Text := 'Browse...';
    FPiperBrowseBtn.OnClick := OnBrowsePiper;
    FNextY := FNextY + 44;
    AddSection('AI ENDPOINT');
    { Any OpenAI-compatible chat/completions endpoint. Defaults match an
      Ollama server on this machine. }
    AddLabel('AI Base URL:');
    FBaseUrlEdit := TEdit.Create(Self);
    FBaseUrlEdit.Parent := FCurrentTab;
    FBaseUrlEdit.Position.X := CTRL_X;
    FBaseUrlEdit.Position.Y := FNextY;
    FBaseUrlEdit.Width := CTRL_W;
    FBaseUrlEdit.OnChange := OnAiSettingChange;
    { OnTyping fires per keystroke (FMX OnChange waits for focus loss on
      some platforms) - the endpoint config must land in ai.ini at EVERY
      intermediate state so a tray quit mid-typing cannot lose it. OnExit +
      OnKeyUp catch what OnTyping misses: clipboard pastes (Ctrl+V / right
      click insert) fire NEITHER OnTyping nor OnChange until focus leaves. }
    FBaseUrlEdit.OnTyping := OnAiSettingChange;
    FBaseUrlEdit.OnExit := OnAiSettingChange;
    FBaseUrlEdit.OnKeyUp := OnAiKeyUp;
    FNextY := FNextY + 34;
    AddLabel('AI Model:');
    FModelEdit := TEdit.Create(Self);
    FModelEdit.Parent := FCurrentTab;
    FModelEdit.Position.X := CTRL_X;
    FModelEdit.Position.Y := FNextY;
    FModelEdit.Width := CTRL_W;
    FModelEdit.OnChange := OnAiSettingChange;
    FModelEdit.OnTyping := OnAiSettingChange;
    FModelEdit.OnExit := OnAiSettingChange;
    FModelEdit.OnKeyUp := OnAiKeyUp;
    FNextY := FNextY + 34;
    AddLabel('API Key (optional):');
    FApiKeyEdit := TEdit.Create(Self);
    FApiKeyEdit.Parent := FCurrentTab;
    FApiKeyEdit.Position.X := CTRL_X;
    FApiKeyEdit.Position.Y := FNextY;
    FApiKeyEdit.Width := CTRL_W;
    FApiKeyEdit.Password := True;
    FApiKeyEdit.OnChange := OnAiSettingChange;
    FApiKeyEdit.OnTyping := OnAiSettingChange;
    FApiKeyEdit.OnExit := OnAiSettingChange;
    FApiKeyEdit.OnKeyUp := OnAiKeyUp;
    FNextY := FNextY + 34;
    AddLabel('System Prompt:');
    { Multi-line TMemo (not a single-line TEdit): the system prompt is a
      whole paragraph, and TMemo.Text works the same as TEdit.Text for the
      INI (Save/Load) - no OnTyping needed, TMemo fires OnChange per line. }
    FSystemPromptEdit := TMemo.Create(Self);
    FSystemPromptEdit.Parent := FCurrentTab;
    FSystemPromptEdit.Position.X := CTRL_X;
    FSystemPromptEdit.Position.Y := FNextY;
    FSystemPromptEdit.Width := CTRL_W;
    FSystemPromptEdit.Height := 60;
    FSystemPromptEdit.OnChange := OnAiSettingChange;
    FNextY := FNextY + 64;
    AddSection('LIVE TEST');
    { Ask / Say something... + Send to AI + Test TTS + status label. }
    AddLabel('Ask / Say something...');
    FAskEdit := TEdit.Create(Self);
    FAskEdit.Parent := FCurrentTab;
    FAskEdit.Position.X := CTRL_X;
    FAskEdit.Position.Y := FNextY;
    FAskEdit.Width := CTRL_W - 200;
    FNextY := FNextY + 36;
    FSendBtn := TButton.Create(Self);
    FSendBtn.Parent := FCurrentTab;
    FSendBtn.Position.X := CTRL_X;
    FSendBtn.Position.Y := FNextY;
    FSendBtn.Width := 130;
    FSendBtn.Text := 'Send to AI';
    FSendBtn.OnClick := OnAskSend;
    FTestTtsBtn := TButton.Create(Self);
    FTestTtsBtn.Parent := FCurrentTab;
    FTestTtsBtn.Position.X := CTRL_X + 140;
    FTestTtsBtn.Position.Y := FNextY;
    FTestTtsBtn.Width := 130;
    FTestTtsBtn.Text := 'Test TTS';
    FTestTtsBtn.OnClick := OnTestTts;
    FNextY := FNextY + 44;
    { Status label: multi-line capable - word wrap on and ~52 px height so
      AI answers in text-only mode ('AI: ...') and long fallback reasons
      wrap instead of being cut off after the first line. }
    FVoiceStatusLbl := AddLabel('Status: Idle');
    FVoiceStatusLbl.WordWrap := True;
    FVoiceStatusLbl.Height := 52;
    FNextY := FNextY + 40;
    { Enter in the ask edit sends the question right away - no mouse detour
      to the Send button needed. }
    FAskEdit.OnKeyDown := OnAskKeyDown;
    { Parallel path arrays behind the model combos BEFORE the first fill -
      FillModelCombos / SelectModelEntry write full paths into them while the
      combos show short names only. }
    FVoskPaths := TStringList.Create;
    FPiperPaths := TStringList.Create;
    { Model combos filled BEFORE the INI load so the saved picks appear in
      them (SelectModelEntry inserts unknown-but-existing paths). The
      load+apply here is the startup pass; OnFormShow repeats the load on
      EVERY panel open so the edits always show the persisted values. }
    FLoadingAiSettings := True;
    try
      FillModelCombos;
      LoadAiSettings;
    TThread.CreateAnonymousThread(
      procedure
      begin
        Sleep(2600);
        TThread.Synchronize(nil,
          procedure
          begin
            if (not Application.Terminated) and (Form2 <> nil) then
              Form2.ApplyAiSettingsToChaos;
          end);
      end).Start;
    finally
      FLoadingAiSettings := False;
    end;


    { ---- Tab 9: Info / Debug ---- }
    FCurrentTab := NewTab('Info / Debug');
    AddSection('GPU & SYSTEM INFO');
    { GPU info block: detection runs lazily at the avatar's first GL frame,
      so the label starts pending and RefreshGpuInfo fills it from
      GChaos.GpuInfoText as soon as the snapshot exists (checked again in
      OnFpsTimer). WordWrap + 6 lines of height give the multi-line block
      room. }
    FGpuInfoLbl := AddLabel('GPU detection pending (runs at first frame)...');
    FGpuInfoLbl.WordWrap := True;
    FGpuInfoLbl.Height := 110;
    FNextY := FNextY + 98;
    { Apply Recommended Particle Budget: pushes GpuRecommendedParticles into
      GChaos.ParticleBudget and mirrors the System tab slider, so the
      recommendation is one click instead of a manual slider hunt. }
    FApplyGpuBudgetBtn := TButton.Create(Self);
    FApplyGpuBudgetBtn.Parent := FCurrentTab;
    FApplyGpuBudgetBtn.Position.X := CTRL_X;
    FApplyGpuBudgetBtn.Position.Y := FNextY;
    FApplyGpuBudgetBtn.Width := BTN_W;
    FApplyGpuBudgetBtn.Text := 'Apply Recommended Particle Budget';
    FApplyGpuBudgetBtn.OnClick := OnApplyGpuBudget;
    FNextY := FNextY + 40;
    AddSection('DEBUG LOG');
    { Big read-only multi-line mirror of the avatar's thread-safe debug ring
      buffer (GPU init, Vosk / piper status, AI requests / responses /
      errors). ReadOnly so the user can scroll and MARK text without
      accidentally editing; WordWrap keeps long lines visible. Updated from
      OnFpsTimer ONLY when new lines arrived (serial changed). }
    FDebugMemo := TMemo.Create(Self);
    FDebugMemo.Parent := FCurrentTab;
    FDebugMemo.Position.X := CTRL_X;
    FDebugMemo.Position.Y := FNextY;
    FDebugMemo.Width := CTRL_W;
    FDebugMemo.Height := 300;
    FDebugMemo.ReadOnly := True;
    FDebugMemo.WordWrap := True;
    FDebugMemo.Text := '';
    FLastLogSerial := -1;
    FNextY := FNextY + 310;
    { Copy / Clear buttons in one row: Copy writes the memo text to the
      clipboard (bug reports), Clear empties the mirror AND the avatar's
      ring buffer. }
    FCopyLogBtn := TButton.Create(Self);
    FCopyLogBtn.Parent := FCurrentTab;
    FCopyLogBtn.Position.X := CTRL_X;
    FCopyLogBtn.Position.Y := FNextY;
    FCopyLogBtn.Width := 130;
    FCopyLogBtn.Text := 'Copy Log';
    FCopyLogBtn.OnClick := OnCopyDebugLog;
    FClearLogBtn := TButton.Create(Self);
    FClearLogBtn.Parent := FCurrentTab;
    FClearLogBtn.Position.X := CTRL_X + 140;
    FClearLogBtn.Position.Y := FNextY;
    FClearLogBtn.Width := 130;
    FClearLogBtn.Text := 'Clear Log';
    FClearLogBtn.OnClick := OnClearDebugLog;
    FNextY := FNextY + 34;
    RefreshGpuInfo;

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
  { AI & voice settings persist across sessions; writes only when the AI tab
    was actually built (combo assigned), so a nil-field guard is included. }
  if FVoskCombo <> nil then
    SaveAiSettings;
  FLoadingAiSettings := True; //let it here, trust me :D
  FreeAndNil(FVoskPaths);
  FreeAndNil(FPiperPaths);
  FreeAndNil(FPartChecks);
  FreeAndNil(FPartCaptions);
  FreeAndNil(FPartColorBoxes);
  FreeAndNil(FInnerPartLabels);
  FreeAndNil(FInnerPartColorBoxes);
end;

procedure TForm2.SaveSettingsIfBuilt;
begin
  { Public wrapper so Unit1.FormDestroy can flush ai.ini on the way down
    without reaching into the private fields. }
  if FVoskCombo <> nil then
    SaveAiSettings;
end;

procedure TForm2.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  { Hide instead of free so the tray can re-show us. Drag mode survives
    the hide: presets round-trip it, and the tray menu can restore
    click-through while the panel is closed. }
  { AI settings persist on every close (X button, Esc, tray 'close
    panel'): endpoint, model, API key and system prompt land in ai.ini
    even when no single control fired a change event before closing. }
  if FVoskCombo <> nil then
    SaveAiSettings;
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
  { The eye-part combo mirrors the same mesh-name list. }
  SyncEyeCombo;
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

procedure TForm2.OnTouchEffectColorChange(Sender: TObject);
begin
  if not Assigned(GChaos) then
    Exit;
  { Touch accent colour: the ColorFade blend target and Glow tint the
    holo shader receives as uTouchEffectColor. }
  GChaos.TouchEffectColor := (Sender as TColorComboBox).Color;
end;

procedure TForm2.UpdateTouchEffectEnable;
begin
  { Both selectors are meaningful only while the touch effects are on,
    so their enabled state mirrors the TouchEffects checkbox (they stay
    visible either way - the disabled look communicates the toggle). }
  if Assigned(FTouchEffectCombo) then
    FTouchEffectCombo.Enabled := Assigned(FTouchEffectsCheck) and FTouchEffectsCheck.IsChecked;
  if Assigned(FTouchEffectColorBox) then
    FTouchEffectColorBox.Enabled := Assigned(FTouchEffectsCheck) and FTouchEffectsCheck.IsChecked;
end;

procedure TForm2.SyncEyeCombo;
var
  Names: TArray<string>;
  I, Sel: Integer;
begin
  if not Assigned(FEyeCombo) or not Assigned(GChaos) then
    Exit;
  { Rebuild the item list: '(Auto)' plus every mesh name. OnChange stays
    disconnected while filling so the programmatic selection cannot fire
    the change handler back into GChaos. }
  FEyeCombo.OnChange := nil;
  FEyeCombo.Items.Clear;
  FEyeCombo.Items.Add('(Auto)');
  Names := GChaos.MeshNames;
  for I := 0 to High(Names) do
    FEyeCombo.Items.Add(Names[I]);
  Sel := 0;
  if (GChaos.CustomEyePartName <> '') and (GChaos.CustomEyePartName <> '(Auto)') then
    for I := 0 to High(Names) do
      if SameText(Names[I], GChaos.CustomEyePartName) then
      begin
        Sel := I + 1;
        Break;
      end;
  { No exact entry: the preset's eye part may only approximate the loaded
    mesh's naming (Eyes vs. LeftEye_Mesh.001). TSkChaos.MatchesEyePartName
    accepts substring matches in both directions, so pick the first part
    that matches the same way instead of silently falling back to (Auto). }
  if Sel = 0 then
    for I := 0 to High(Names) do
      if GChaos.MatchesEyePartName(Names[I]) then
      begin
        Sel := I + 1;
        Break;
      end;
  if Sel < FEyeCombo.Items.Count then
    FEyeCombo.ItemIndex := Sel
  else
    FEyeCombo.ItemIndex := 0;
  FEyeCombo.OnChange := OnEyePartChange;
end;

procedure TForm2.OnEyePartChange(Sender: TObject);
var
  cb: TComboBox;
begin
  if not Assigned(GChaos) then
    Exit;
  cb := Sender as TComboBox;
  { Index 0 is '(Auto)': an empty CustomEyePartName restores the automatic
    eye-name detection. Any other index maps to MeshNames[Index - 1]. }
  if cb.ItemIndex <= 0 then
    GChaos.CustomEyePartName := ''
  else
    GChaos.CustomEyePartName := cb.Items[cb.ItemIndex];
  { A custom part that the loader's auto-exclude keywords would drop
    (cornea, sclera, iris, ...) is only re-admitted while the mesh file is
    (re)parsed - the stored point cloud of a skipped part is gone, so a
    plain cloud rebuild cannot bring it back. Reload the source for such
    parts; everything else re-flags fine through RebuildTargetCloud. }
  if (GChaos.CustomEyePartName <> '') and IsExcludedName(GChaos.CustomEyePartName) then
    GChaos.ReloadCurrentSource
  else
    GChaos.RebuildTargetCloud;
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
    tgTouchEffectStyle:
      GChaos.TouchEffectStyle := TChaosTouchEffectStyle(cb.ItemIndex);
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
    tgAutoDim:
      GChaos.AutoDimOnHover := cb.IsChecked;
    tgTouchEffects:
      begin
        GChaos.TouchEffectsEnabled := cb.IsChecked;
        { The style / colour selectors only matter while the touch
          effects are on, so their enabled state follows the toggle. }
        UpdateTouchEffectEnable;
      end;
    tgIdleLife:
      GChaos.IdleLifeMotion := cb.IsChecked;
    tgNaturalBlink:
      GChaos.NaturalBlinking := cb.IsChecked;
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
  { Live voice status on the AI & Voice tab (Idle / Listening / Thinking /
    Speaking / Fallback: ...). }
  if FVoiceStatusLbl <> nil then
    FVoiceStatusLbl.Text := 'Status: ' + GChaos.VoiceStatusText;
  { Info / Debug tab: GPU info once the lazy GL detection landed, and the
    debug log mirror ONLY when new lines arrived (serial changed) - a
    constant rebuild would stomp the user's scroll position / selection
    inside the memo every 400 ms. }
  if FGpuInfoLbl <> nil then
    RefreshGpuInfo;
  if (FDebugMemo <> nil) and (FLastLogSerial <> GChaos.DebugLogSerial) then
  begin
    FLastLogSerial := GChaos.DebugLogSerial;
    FDebugMemo.Text := GChaos.GetDebugLogText;
  end;
end;

procedure TForm2.RefreshGpuInfo;
begin
  if (FGpuInfoLbl = nil) or (not Assigned(GChaos)) then
    Exit;
  { GPU detection runs inside the avatar's first GL frame (lazy), so the
    panel may be built BEFORE the snapshot exists. Show the pending text
    until GpuInfoText is filled, then the detection block - refresh cost is
    one string compare per timer tick. }
  if GChaos.GpuInfoText <> '' then
  begin
    if FGpuInfoLbl.Text <> GChaos.GpuInfoText then
      FGpuInfoLbl.Text := GChaos.GpuInfoText;
  end
  else if FGpuInfoLbl.Text <> 'GPU detection pending (runs at first frame)...' then
    FGpuInfoLbl.Text := 'GPU detection pending (runs at first frame)...';
end;

procedure TForm2.OnApplyGpuBudget(Sender: TObject);
var
  Budget: Integer;
begin
  { One click from the detection straight into the live budget: pushes the
    recommended particle count into the avatar AND mirrors the System /
    Performance tab slider, so both stay in sync. 0 (detection failed / not
    yet run) is a silent no-op - the button does nothing instead of
    zeroing the budget. }
  if not Assigned(GChaos) then
    Exit;
  Budget := GChaos.GpuRecommendedParticles;
  if Budget <= 0 then
    Exit;
  GChaos.ParticleBudget := Cardinal(Budget);
  if FValLabels[tgParticleBudget] <> nil then
    FValLabels[tgParticleBudget].Text := 'Particle budget: ' + IntToStr(Budget);
  if FTbParticleBudget <> nil then
  begin
    { Programmatic slider refresh without firing the change handler back
      into the property the value came from (same pattern the preset sync
      uses). }
    FTbParticleBudget.OnChange := nil;
    FTbParticleBudget.Value := EnsureRange(Budget, FTbParticleBudget.Min, FTbParticleBudget.Max);
    FTbParticleBudget.OnChange := OnTrackChange;
  end;
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
  { Mouse-follow mode: the desktop overlay control converts the live cursor
    into its own full-screen frame every frame and keeps the entity
    retargeted there, so it chases the mouse anywhere on the desktop
    instead of orbiting a fixed rect. }
  GChaos.HighlightFollowMouse := True;
end;

procedure TForm2.OnDismissHighlight(Sender: TObject);
begin
  if not Assigned(GChaos) then
    Exit;
  { Drop the follow mode first so the exit animation is not overridden by
    the next per-frame retarget, then walk the entity off-screen. }
  GChaos.HighlightFollowMouse := False;
  GChaos.DismissHighlight;
end;

procedure TForm2.OnSendToScreen(Sender: TObject);
var
  I, Cnt, CurIdx: Integer;
  Info: TChaosDisplayInfo;
  Item: TMenuItem;
  Btn: TControl;
  P: TPointF;
begin
  if not Assigned(GChaos) then
    Exit;
  { Live list: read the displays now so a beamer plugged in since the
    last click appears immediately. Nothing attached -> nothing to do. }
  Cnt := GChaos.DisplayCount;
  if Cnt <= 0 then
    Exit;
  CurIdx := GChaos.CurrentDisplayIndex;
  { Rebuild the menu as a fresh object on every click (FreeAndNil +
    Create - FMX popup menus have no reliable Clear, and a fresh build
    can never keep a stale entry alive). The IsChecked item marks the
    monitor the host window currently sits on. }
  FreeAndNil(FMonitorMenu);
  FMonitorMenu := TPopupMenu.Create(Self);
  for I := 0 to Cnt - 1 do
  begin
    Info := GChaos.DisplayInfo(I);
    Item := TMenuItem.Create(FMonitorMenu);
    if Info.Primary then
      Item.Text := Format('Monitor %d (%dx%d - Primary)', [I + 1, Info.Bounds.Width, Info.Bounds.Height])
    else
      Item.Text := Format('Monitor %d (%dx%d)', [I + 1, Info.Bounds.Width, Info.Bounds.Height]);
    Item.Tag := I;
    Item.IsChecked := (I = CurIdx);
    Item.OnClick := OnPickMonitor;
    FMonitorMenu.AddObject(Item);
  end;
  { Dropdown anchored under the button's bottom-left corner. TPopupMenu
    .Popup takes a screen point in FMX, so the local corner goes through
    LocalToScreen (the control tree's conversion to global coordinates). }
  Btn := Sender as TControl;
  P := Btn.LocalToScreen(PointF(0, Btn.Height));
  FMonitorMenu.Popup(P.X, P.Y);
end;

procedure TForm2.OnPickMonitor(Sender: TObject);
begin
  if not Assigned(GChaos) then
    Exit;
  { Tag carries the display index from the menu item. SendToDisplay moves
    the host window onto that monitor's exact bounds (DPI-safe, position
    first) - the render surface and touch coordinates follow on the next
    frame. }
  GChaos.SendToDisplay((Sender as TMenuItem).Tag);
end;

procedure TForm2.OnFormShow(Sender: TObject);
begin
  LoadAiSettings;
  ApplyAiSettingsToChaos;
end;

procedure TForm2.OnFormHide(Sender: TObject);
begin
  { Drag mode intentionally survives hiding: it is part of the placement
    presets and the tray menu can restore click-through while the panel
    is closed. Kept as the OnFormHide hook so the intent stays explicit
    where the close path cascades into it through caHide. }
  { AI settings safety net: FormClose cascades into this hook through
    caHide, so persisting here covers BOTH close paths (X button, tray
    'close panel') plus every programmatic Hide - Base URL / Model /
    API Key / System Prompt always land in ai.ini. Guarded against the
    tab not being built (no combos = no settings worth saving). }
  if FVoskCombo <> nil then
    SaveAiSettings;
end;

procedure TForm2.SyncOverlayControls;
var
  SizePx, StyleIdx: Integer;
begin
  if not Assigned(GChaos) or not Assigned(FDragCheck) then
    Exit;
  { Programmatic checkbox / trackbar updates must not fire their change
    handlers and write back into the properties they came from. }
    FDragCheck.OnChange := OnCheckChange;
  if Assigned(FAutoDimCheck) then
  begin
    FAutoDimCheck.OnChange := nil;
    FAutoDimCheck.IsChecked := GChaos.AutoDimOnHover;
    FAutoDimCheck.OnChange := OnCheckChange;
  end;
  { Behavior toggles live in the Face / Animation tab but mirror the same
    three properties the preset round-trips, so a preset load updates
    them here exactly like the drag / auto-dim pair above. }
  if Assigned(FTouchEffectsCheck) then
  begin
    FTouchEffectsCheck.OnChange := nil;
    FTouchEffectsCheck.IsChecked := GChaos.TouchEffectsEnabled;
    FTouchEffectsCheck.OnChange := OnCheckChange;
  end;
  { Touch effect selectors: style index and accent colour mirror the
    (possibly preset-driven) avatar state; handlers stay disconnected
    while assigning so the programmatic update cannot write back into
    the properties it came from. }
  if Assigned(FTouchEffectCombo) then
  begin
    StyleIdx := Ord(GChaos.TouchEffectStyle);
    if (StyleIdx >= 0) and (StyleIdx < FTouchEffectCombo.Items.Count) then
    begin
      FTouchEffectCombo.OnChange := nil;
      FTouchEffectCombo.ItemIndex := StyleIdx;
      FTouchEffectCombo.OnChange := OnComboChange;
    end;
  end;
  if Assigned(FTouchEffectColorBox) then
  begin
    FTouchEffectColorBox.OnChange := nil;
    FTouchEffectColorBox.Color := GChaos.TouchEffectColor;
    FTouchEffectColorBox.OnChange := OnTouchEffectColorChange;
  end;
  UpdateTouchEffectEnable;
  if Assigned(FIdleLifeCheck) then
  begin
    FIdleLifeCheck.OnChange := nil;
    FIdleLifeCheck.IsChecked := GChaos.IdleLifeMotion;
    FIdleLifeCheck.OnChange := OnCheckChange;
  end;
  if Assigned(FNaturalBlinkCheck) then
  begin
    FNaturalBlinkCheck.OnChange := nil;
    FNaturalBlinkCheck.IsChecked := GChaos.NaturalBlinking;
    FNaturalBlinkCheck.OnChange := OnCheckChange;
  end;
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

  { Programmatic track refresh without firing the change handler back into
    the property the value came from. }
  procedure SyncTrack(tb: TTrackBar; AValue: Single; const ALabel: string);
  begin
    if not Assigned(tb) then
      Exit;
    tb.OnChange := nil;
    tb.Value := EnsureRange(AValue, tb.Min, tb.Max);
    tb.OnChange := OnTrackChange;
    if Assigned(FValLabels[tb.Tag]) then
      FValLabels[tb.Tag].Text := ALabel;
  end;

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
  { Eye-part combo follows the (possibly preset-driven) override. }
  SyncEyeCombo;
  { Neck pivot: 0 reads as "OFF (Rigid Head)" like the live label does. }
  if GChaos.NeckPivotRatio <= 0.001 then
    SyncTrack(FTbNeckPivot, GChaos.NeckPivotRatio, 'Neck pivot: OFF (Rigid Head)')
  else
    SyncTrack(FTbNeckPivot, GChaos.NeckPivotRatio, 'Neck pivot: ' + FormatFloat('0.00', GChaos.NeckPivotRatio));
  { Performance tiers follow the preset-loaded adaptive settings. }
  if Assigned(FAdaptiveCheck) then
  begin
    FAdaptiveCheck.OnChange := nil;
    FAdaptiveCheck.IsChecked := GChaos.AdaptiveFPS;
    FAdaptiveCheck.OnChange := OnCheckChange;
  end;
  SyncTrack(FTbActiveFPS, GChaos.ActiveTargetFPS, 'Active target FPS: ' + IntToStr(GChaos.ActiveTargetFPS));
  SyncTrack(FTbIdleFPS, GChaos.IdleTargetFPS, 'Idle target FPS: ' + IntToStr(GChaos.IdleTargetFPS));
  SyncTrack(FTbIdleTimeout, GChaos.IdleTimeoutSec, 'Idle timeout (s): ' + FormatFloat('0.0', GChaos.IdleTimeoutSec));
end;

{==============================================================================
  AI & Voice tab
==============================================================================}

function TForm2.GetAiIniPath: string;
begin
  { ONE fixed, unambiguous path so reads and writes can never diverge:
    ai.ini ALWAYS sits directly beside the EXE. The previous multi-folder
    lookup (exe dir / two levels up) could resolve reads to the project
    folder while a later save hit the exe copy (or vice versa) after a
    rebuild/move - the panel then showed defaults no matter what was
    stored. Debug and Release each keep their own file next to their own
    binary; copy once when switching profiles. }
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'ai.ini';
end;

procedure TForm2.FillCombo(cb: TComboBox; const AFolders: array of string);
var
  I: Integer;
  ExePath, Folder, Entry: string;
  { System.SysUtils-qualified: Winapi.Windows sits AFTER SysUtils in the
    uses clause and re-exports FindFirstFile etc.; unqualified FindFirst
    would resolve into the Winapi overload and hand the SysUtils record to
    a Windows handle API (NativeUInt vs TSearchRec compile clash). }
  SR: System.SysUtils.TSearchRec;
begin
  { NIL CHECK FIRST: the panel may build the AI tab before the combos exist
    (startup order) - never touch a nil combo. }
  if cb = nil then
    Exit;
  ExePath := ExtractFilePath(ParamStr(0));
  for I := 0 to High(AFolders) do
  begin
    Folder := IncludeTrailingPathDelimiter(ExePath) + AFolders[I];
    if not DirectoryExists(Folder) then
      Continue;
    { Every direct sub-folder is a candidate model (vosk-model-small-en-us,
      a piper voice folder, ...); the combo entry shows the SHORT folder
      name, the full path lives in the parallel array at the same index. }
    if System.SysUtils.FindFirst(IncludeTrailingPathDelimiter(Folder) + '*', faDirectory, SR) = 0 then
    try
      repeat
        Entry := IncludeTrailingPathDelimiter(Folder) + SR.Name;
        if (SR.Name <> '.') and (SR.Name <> '..') and DirectoryExists(Entry) then
        begin
          if cb = FVoskCombo then
            SelectModelEntry(FVoskCombo, FVoskPaths, Entry)
          else if cb = FPiperCombo then
            SelectModelEntry(FPiperCombo, FPiperPaths, Entry);
        end;
      until System.SysUtils.FindNext(SR) <> 0;
    finally
      System.SysUtils.FindClose(SR);
    end;
  end;
  { Ensure a usable empty state. }
  if cb.Items.Count > 0 then
    cb.ItemIndex := 0;
end;

function TForm2.SelectModelEntry(ACombo: TComboBox; APaths: TStringList;
  const AFullPath: string): Boolean;
begin
  { Adds AFullPath (combo shows the SHORT name, array keeps the full path)
  and selects it. Returns True when the entry was new. The combo items and
  the array stay index-parallel: every path goes in through here. }
  Result := False;
  if (ACombo = nil) or (APaths = nil) or (AFullPath = '') then
    Exit;
  if APaths.IndexOf(AFullPath) < 0 then
  begin
    APaths.Add(AFullPath);
    ACombo.Items.Add(ExtractFileName(ExcludeTrailingPathDelimiter(AFullPath)));
    Result := True;
  end;
  ACombo.ItemIndex := APaths.IndexOf(AFullPath);
end;

function TForm2.PathForComboIndex(ACombo: TComboBox; APaths: TStringList): string;
begin
  { Full path behind the combo's current selection ('' when none). The
    indices are kept parallel by SelectModelEntry, so the combo's ItemIndex
    reads the array directly. }
  Result := '';
  if (ACombo = nil) or (APaths = nil) then
    Exit;
  if (ACombo.ItemIndex >= 0) and (ACombo.ItemIndex < APaths.Count) then
    Result := APaths[ACombo.ItemIndex];
end;

procedure TForm2.FillModelCombos;
var
  SherpaDir: string;
  { Same System.SysUtils qualification as in FillCombo - see the note there. }
  SR: System.SysUtils.TSearchRec;
  ExePath: string;
begin
  { NIL CHECK FIRST: FillModelCombos runs from FormCreate after the AI tab is
    built - but also defensively from Reload; a nil combo must never AV. }
  if FVoskCombo = nil then
    Exit;
  if FPiperCombo = nil then
    Exit;
  ExePath := ExtractFilePath(ParamStr(0));
  { Combo items + parallel path arrays are rebuilt together (the arrays are
    the source of truth; combos display short names only). }
  FVoskCombo.Items.Clear;
  FPiperCombo.Items.Clear;
  FVoskPaths.Clear;
  FPiperPaths.Clear;
  { Vosk STT: every sub-folder of vosk\ (unpacked model directories). }
  FillCombo(FVoskCombo, ['vosk']);
  { Piper TTS: every sub-folder of sherpa\ (voice folders with .onnx +
    tokens.txt + optional espeak-ng-data / lexicon.txt inside). }
  FillCombo(FPiperCombo, ['sherpa']);
  { Loose piper voice directly in sherpa\ (the .onnx + tokens.txt sit in
    the folder root): add the folder itself as an entry. FindFirst must run
    into its own try/finally so the handle is always closed. }
  SherpaDir := IncludeTrailingPathDelimiter(ExePath) + 'sherpa';
  if DirectoryExists(SherpaDir) then
  begin
    if System.SysUtils.FindFirst(IncludeTrailingPathDelimiter(SherpaDir) + '*.onnx', faAnyFile, SR) = 0 then
    try
      if FileExists(IncludeTrailingPathDelimiter(SherpaDir) + 'tokens.txt') then
        SelectModelEntry(FPiperCombo, FPiperPaths, SherpaDir);
    finally
      System.SysUtils.FindClose(SR);
    end;
  end;
  { Scan finished; leave selection to LoadAiSettings / defaults. }
  if (FVoskCombo.Items.Count > 0) and (FVoskCombo.ItemIndex < 0) then
    FVoskCombo.ItemIndex := 0;
  if (FPiperCombo.Items.Count > 0) and (FPiperCombo.ItemIndex < 0) then
    FPiperCombo.ItemIndex := 0;
end;

procedure TForm2.LoadAiSettings;
var
  Ini: TMemIniFile;
  S: string;
  I: Integer;
begin
  if not FileExists(GetAiIniPath) then
    Exit;
  { GUARD FIRST: setting the checkboxes / edits below fires their already
    wired OnChange / OnTyping handlers; without the guard the very first
    assignment (FTtsEnableCheck.IsChecked := ...) would run
    OnTtsEnableToggle -> SaveAiSettings while FBaseUrlEdit & co. still
    hold their empty / default state, instantly wiping ai.ini with the
    defaults. Every settings handler checks the guard and exits early. }
  FLoadingAiSettings := True;
  try
    Ini := TMemIniFile.Create(GetAiIniPath);
    try
      { New split keys TtsEnabled / SttEnabled; the legacy coupled keys
        migrate: the old master 'Enabled' switches the whole voice stack,
        so TTS follows it alone (a former master=on + MicEnabled=off was a
        TTS-only setup and must stay that way), STT additionally required
        the old MicEnabled. }
      FTtsEnableCheck.IsChecked := Ini.ReadBool('Voice', 'TtsEnabled',
        Ini.ReadBool('Voice', 'Enabled', False));
      FSttEnableCheck.IsChecked := Ini.ReadBool('Voice', 'SttEnabled',
        Ini.ReadBool('Voice', 'Enabled', False) and
        Ini.ReadBool('Voice', 'MicEnabled', True));
      FMicLipSyncCheck.IsChecked := Ini.ReadBool('Voice', 'MicLipSyncOnly', False);
      { Model folders: exact stored path wins when it still exists, otherwise
        the first scanned entry / empty. SelectModelEntry inserts the full
        path (short display name) at the top when the scan did not know it. }
      S := Ini.ReadString('Models', 'VoskModelDir', '');
      if (S <> '') and DirectoryExists(S) and (FVoskCombo <> nil) then
        SelectModelEntry(FVoskCombo, FVoskPaths, S);
      S := Ini.ReadString('Models', 'PiperVoice', '');
      if (S <> '') and ((DirectoryExists(S)) or FileExists(S)) and (FPiperCombo <> nil) then
        SelectModelEntry(FPiperCombo, FPiperPaths, S);
      FBaseUrlEdit.Text := Ini.ReadString('AI', 'BaseUrl', 'http://localhost:11434/v1/chat/completions');
      FModelEdit.Text := Ini.ReadString('AI', 'Model', 'llama3.2');
      FApiKeyEdit.Text := Ini.ReadString('AI', 'ApiKey', '');
      { '\n' -> real line break: the INI stores the prompt with escaped
        breaks (see SaveAiSettings) so a multi-line prompt round-trips. }
      FSystemPromptEdit.Text := StringReplace(
        Ini.ReadString('AI', 'SystemPrompt',
          'You are C.H.A.O.S., a dry, witty AI living inside a 3D particle hologram. ' +
          'Start EVERY reply with exactly one gesture tag from [neutral], [nod], ' +
          '[shake], [tilt], [think], [alert], followed by a concise spoken answer ' +
          '(max 2 sentences, no markdown or emojis).'),
        '\n', sLineBreak, [rfReplaceAll]);
      I := Ini.ReadInteger('AI', 'MaxHistory', 10);
      if Assigned(GChaos) and (GChaos.AIClient <> nil) then
        GChaos.AIClient.MaxHistoryMessages := I;
    finally
      Ini.Free;
    end;
    { Startup hand-over: the loaded endpoint values go straight into the live
      avatar client (independent of the voice toggles - text chat works with
      the whole audio stack off), so the very first Ask / mic request already
      runs against the ai.ini endpoint without waiting for the first
      OnAiSettingChange. ApplyAiSettingsToChaos follows right after in
      FormCreate and covers the toggle / pipeline side. }
    if Assigned(GChaos) then
      GChaos.EnsureAIClient(FBaseUrlEdit.Text, FModelEdit.Text,
        FApiKeyEdit.Text, FSystemPromptEdit.Text);
  finally
    FLoadingAiSettings := False;
  end;
end;

procedure TForm2.SaveAiSettings;
var
  Ini: TMemIniFile;
begin
  { GUARD: never write ai.ini while LoadAiSettings is pushing values into
    the controls - the intermediate control state would hit the file. }
  if FLoadingAiSettings then
    Exit;
  Ini := TMemIniFile.Create(GetAiIniPath);
  try
    if FTtsEnableCheck <> nil then
      Ini.WriteBool('Voice', 'TtsEnabled', FTtsEnableCheck.IsChecked);
    if FSttEnableCheck <> nil then
      Ini.WriteBool('Voice', 'SttEnabled', FSttEnableCheck.IsChecked);
    if FMicLipSyncCheck <> nil then
      Ini.WriteBool('Voice', 'MicLipSyncOnly', FMicLipSyncCheck.IsChecked);
    if FVoskCombo <> nil then
      Ini.WriteString('Models', 'VoskModelDir', SelectedVoskDir);
    if FPiperCombo <> nil then
      Ini.WriteString('Models', 'PiperVoice', SelectedPiperVoice);
    if FBaseUrlEdit <> nil then
      Ini.WriteString('AI', 'BaseUrl', FBaseUrlEdit.Text);
    if FModelEdit <> nil then
      Ini.WriteString('AI', 'Model', FModelEdit.Text);
    if FApiKeyEdit <> nil then
      Ini.WriteString('AI', 'ApiKey', FApiKeyEdit.Text);
    if FSystemPromptEdit <> nil then
      { TMemo keeps real line breaks; TMemIniFile.WriteString would put RAW
        CR/LF into the .ini and corrupt the file on the next read. Escape
        to a literal '\n' token (round-tripped in LoadAiSettings). }
      Ini.WriteString('AI', 'SystemPrompt',
        StringReplace(FSystemPromptEdit.Text, sLineBreak, '\n', [rfReplaceAll]));
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
  { Persisted confirmation straight into the panel's debug log: path only,
    NEVER the API key or any other content - one line proves the write went
    to the file the user expects, and GetAiIniPath now returns one fixed
    exe-side path so this line also settles which file was hit. }
  if Assigned(GChaos) then
    GChaos.AppendDebugLog('Saved ai.ini -> ' + GetAiIniPath);
end;

function TForm2.SelectedVoskDir: string;
begin
  { Current Vosk pick: the FULL path behind the combo's short display name,
    or '' when nothing is chosen (STT simply stays off). }
  Result := PathForComboIndex(FVoskCombo, FVoskPaths);
end;

function TForm2.SelectedPiperVoice: string;
begin
  { Current piper voice pick: the FULL path (folder or .onnx file) behind
    the combo's short display name. }
  Result := PathForComboIndex(FPiperCombo, FPiperPaths);
end;

procedure TForm2.ApplyAiSettingsToChaos;
begin
  if not Assigned(GChaos) then
    Exit;
  { AI client on demand - INDEPENDENT of both voice toggles: text chat works
    with the whole audio stack off. }
  GChaos.EnsureAIClient(FBaseUrlEdit.Text, FModelEdit.Text, FApiKeyEdit.Text, FSystemPromptEdit.Text);
  { Split activation: TTS and STT are handed to the avatar separately, so
    each side lives/dies alone (TTS-only = engine + voice, no mic; STT-only =
    mic + Vosk, answers as text + gestures). }
  GChaos.VoiceTtsEnabled := FTtsEnableCheck.IsChecked;
  GChaos.VoiceSttEnabled := FSttEnableCheck.IsChecked;
  if FTtsEnableCheck.IsChecked or FSttEnableCheck.IsChecked then
    { Hand the LIVE model picks over so the pipeline loads exactly what the
    combos show (empty picks degrade to text chat + SAPI TTS). }
    GChaos.ActivatePendingVoice(SelectedVoskDir, SelectedPiperVoice);
  { OBS lip-sync mode mirrors the pipeline live when it exists. }
  if GChaos.VoicePipeline <> nil then
    GChaos.VoicePipeline.MicLipSyncOnly := FMicLipSyncCheck.IsChecked;
end;

procedure TForm2.OnTtsEnableToggle(Sender: TObject);
begin
  { GUARD: skip the echo storm while LoadAiSettings fills the controls. }
  if FLoadingAiSettings then
    Exit;
  SaveAiSettings;
  ApplyAiSettingsToChaos;
end;

procedure TForm2.OnSttEnableToggle(Sender: TObject);
begin
  { GUARD: see OnTtsEnableToggle. }
  if FLoadingAiSettings then
    Exit;
  SaveAiSettings;
  ApplyAiSettingsToChaos;
end;

procedure TForm2.OnMicLipSyncToggle(Sender: TObject);
begin
  { GUARD: see OnTtsEnableToggle. }
  if FLoadingAiSettings then
    Exit;
  SaveAiSettings;
  if Assigned(GChaos) and (GChaos.VoicePipeline <> nil) then
    GChaos.VoicePipeline.MicLipSyncOnly := FMicLipSyncCheck.IsChecked;
end;

procedure TForm2.OnVoskComboChange(Sender: TObject);
begin
  { GUARD: combo selections change while the INI pick is re-selected during
    the load - those are not user picks. }
  if FLoadingAiSettings then
    Exit;
  { Model picks are applied immediately: store AND re-apply, so a Vosk
    model switch in the combo reaches the avatar without waiting for the
    next activation (ApplyAiSettingsToChaos hands the new pick to
    ActivatePendingVoice / the live pipeline). }
  SaveAiSettings;
  ApplyAiSettingsToChaos;
end;

procedure TForm2.OnPiperComboChange(Sender: TObject);
begin
  { GUARD: see OnVoskComboChange. }
  if FLoadingAiSettings then
    Exit;
  { Same immediate re-apply for the piper voice pick. }
  SaveAiSettings;
  ApplyAiSettingsToChaos;
end;

procedure TForm2.OnBrowseVosk(Sender: TObject);
var
  Dir: string;
begin
  { Manual folder pick: ANY path / language works (the INI stores it, the
    pipeline loads it), independent of the auto-scan folders. The combo
    shows the short folder name, the parallel array keeps the full path. }
  Dir := '';
  if SelectDirectory('Select Vosk model folder', ExtractFilePath(ParamStr(0)), Dir) then
  begin
    SelectModelEntry(FVoskCombo, FVoskPaths, Dir);
    SaveAiSettings;
    ApplyAiSettingsToChaos;
  end;
end;

procedure TForm2.OnBrowsePiper(Sender: TObject);
var
  Dir: string;
begin
  Dir := '';
  if SelectDirectory('Select Piper voice folder (or .onnx parent)', ExtractFilePath(ParamStr(0)), Dir) then
  begin
    SelectModelEntry(FPiperCombo, FPiperPaths, Dir);
    SaveAiSettings;
    ApplyAiSettingsToChaos;
  end;
end;

procedure TForm2.OnReloadModels(Sender: TObject);
var
  VoskSel, PiperSel: string;
begin
  { Keep the current picks across the re-scan. }
  VoskSel := SelectedVoskDir;
  PiperSel := SelectedPiperVoice;
  FillModelCombos;
  { Re-select the previously picked full paths (re-added on top when the
    re-scan no longer lists them - e.g. an external drive vanished and the
    pick should still survive in the INI). }
  if (VoskSel <> '') and (DirectoryExists(VoskSel)) then
    SelectModelEntry(FVoskCombo, FVoskPaths, VoskSel);
  if (PiperSel <> '') and ((DirectoryExists(PiperSel)) or FileExists(PiperSel)) then
    SelectModelEntry(FPiperCombo, FPiperPaths, PiperSel);
end;

procedure TForm2.OnDownloadVoskModels(Sender: TObject);
begin
  { Exact official Vosk model download page (alphacephei.com/vosk lists
    every model archive). ShellExecute with 'open' launches the default
    browser. }
  ShellExecute(0, 'open', 'https://alphacephei.com', nil, nil, SW_SHOWNORMAL);
end;

procedure TForm2.OnDownloadPiperVoices(Sender: TObject);
begin
  { Exact official piper voices download page (the rhasspy/piper voices
    release list). ShellExecute with 'open' launches the default browser. }
  ShellExecute(0, 'open', 'https://github.com', nil, nil, SW_SHOWNORMAL);
end;

procedure TForm2.OnAskSend(Sender: TObject);
begin
  { Persist the endpoint fields before the request leaves the app: the
    user may have typed a new Base URL / Model / Key straight into the
    edits and pressed Enter or Send - without this save a crash or panel
    close right after the request would lose the freshly typed config. }
  if FVoskCombo <> nil then
    SaveAiSettings;
  if not Assigned(GChaos) then
    Exit;
  if Trim(FAskEdit.Text) = '' then
    Exit;
  { Works with or without voice: AskAI configures the client on demand. }
  GChaos.AskAI(FAskEdit.Text);
  FAskEdit.Text := '';
end;

procedure TForm2.OnAskKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  { Enter sends the question; the key is consumed so no stray
    newline/whitespace lands in the single-line edit. Only vkReturn is
    checked - vkEnter does not exist on every FMX platform version, which
    broke compilation (undefined identifier). }
  if Key = vkReturn then
  begin
    Key := 0;
    OnAskSend(Self);
  end;
end;

procedure TForm2.OnTestTts(Sender: TObject);
begin
  if not Assigned(GChaos) then
    Exit;
  { Speaks a fixed sample through piper / SAPI so the voice chain is
    testable without any AI round-trip. SpeakVoice logs the call into the
    debug log, so a missing audio shows up in the Info / Debug tab. }
  GChaos.SpeakVoice('Hello World');
end;

procedure TForm2.OnAiSettingChange(Sender: TObject);
begin
  { GUARD: LoadAiSettings assigns the edit .Text values below - those are
    programmatic writes, not user typing; without the guard each assignment
    would fire this handler and SaveAiSettings (with partly stale controls). }
  if FLoadingAiSettings then
    Exit;
  { Endpoint / prompt edits: persist and push into the live client. Fired
    per keystroke through BOTH events - OnChange (classic, fires on focus
    loss / programmatic change) and OnTyping (per keystroke on desktop FMX)
    - so every intermediate state lands in ai.ini immediately; a tray quit
    mid-typing cannot lose the config. The INI write is cheap enough. }
  SaveAiSettings;
  if Assigned(GChaos) then
    GChaos.EnsureAIClient(FBaseUrlEdit.Text, FModelEdit.Text, FApiKeyEdit.Text, FSystemPromptEdit.Text);
end;

procedure TForm2.OnAiKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  { Copy-paste net: FMX OnTyping does not fire for clipboard inserts, so
    the pasted value could sit in the edit for minutes without reaching
    ai.ini. OnKeyUp catches those (a paste releases Ctrl+V = two key-ups)
    and reuses the same persist + push path. Guard mirrors
    OnAiSettingChange. }
  if FLoadingAiSettings then
    Exit;
  SaveAiSettings;
  if Assigned(GChaos) then
    GChaos.EnsureAIClient(FBaseUrlEdit.Text, FModelEdit.Text, FApiKeyEdit.Text, FSystemPromptEdit.Text);
end;

procedure TForm2.OnCopyDebugLog(Sender: TObject);
var
  Svc: IFMXClipboardService;
begin
  { Copies the memo text to the clipboard (bug reports / sharing). Goes
    through the platform clipboard service - TClipboard / memo methods are
    kept out so it also works headless of any edit focus. Nil-safe on
    platforms without a clipboard service. }
  if (FDebugMemo = nil) or (FDebugMemo.Text = '') then
    Exit;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
    Svc.SetClipboard(FDebugMemo.Text);
end;

procedure TForm2.OnClearDebugLog(Sender: TObject);
begin
  { Clears the mirror AND asks the avatar to reset its ring buffer (the
    serial changes, so the next timer tick re-syncs the memo). }
  if FDebugMemo <> nil then
    FDebugMemo.Text := '';
  if Assigned(GChaos) then
    GChaos.ClearDebugLog;
  FLastLogSerial := -1;
end;

end.

