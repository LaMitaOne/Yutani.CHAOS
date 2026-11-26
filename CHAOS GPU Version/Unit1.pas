unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  Winapi.Windows, FMX.Platform.Win, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.Graphics, FMX.Dialogs, Yutani.Chaos.Skia.GPU, uControls,
  uSkiaCustomThreadedBase, System.Skia;

type
  { Full-desktop drawing host for the alive highlighter entity. TSkChaos is
    only avatar-sized (its render surface is the small overlay control), so
    drawing the entity there trapped it inside the avatar rect. This control
    spans the whole screen and forwards every frame to
    TSkChaos.RenderHighlighterOverlay, so the entity can travel anywhere on
    the desktop; it paints nothing else, so the rest of the frame stays
    fully transparent. }
  THighlighterOverlay = class(TSkiaCustomThreadedBase)
  private
    { Avatar whose highlighter entity this overlay advances and draws.
      Owned by the form and freed after this control, never nil during the
      render thread's lifetime. }
    FChaos: TSkChaos;
    { Last frame's monotonic time, for the per-frame delta handed to the
      entity's physics. }
    FLastTime: Double;
    { Whether the previous frame drew the entity; drives the idle pacing
      switch below. }
    FBusyFrame: Boolean;
  protected
    procedure RenderEffect(const ACanvas: ISkCanvas; const ADest: TRectF; const ATime: Double); override;
  public
    constructor Create(AOwner: TComponent; AChaos: TSkChaos); reintroduce;
  end;

  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    FChaos: TSkChaos;
    FHighlighterOverlay: THighlighterOverlay;
    { UI-thread wake hook for the full-desktop highlighter host: fired by
      TSkChaos when the highlighter is activated, shows the (sleeping,
      hidden) overlay control at once so its render loop resumes drawing
      without waiting out the 120 ms idle sleep. }
    procedure HighlighterWake(Sender: TObject);
  public
  end;

var
  Form1: TForm1;

implementation
{$R *.fmx}

constructor THighlighterOverlay.Create(AOwner: TComponent; AChaos: TSkChaos);
begin
  inherited Create(AOwner);
  FChaos := AChaos;
  FLastTime := 0;
  FBusyFrame := False;
  { Start at the idle rate: the first frames carry no entity, and the
    pacing switch in RenderEffect promotes to the full rate the moment
    TSkChaos reports the highlighter busy. }
  TargetFPS := 10;
end;

procedure THighlighterOverlay.RenderEffect(const ACanvas: ISkCanvas; const ADest: TRectF; const ATime: Double);
var
  Delta: Double;
  Cur: TPoint;
  C: TPointF;
  Busy: Boolean;
begin
  { Full idle short-circuit: with no entity on screen and mouse-follow off
    there is nothing to draw, so the frame skips the clear entirely and the
    thread just sleeps. Hiding the control (once, through TThread.Queue
    because this runs on the render thread) additionally stops the
    compositor from blending this fullscreen layer at all - a visible
    transparent fullscreen window costs DWM time even when it never
    changes, which was the residual CPU load after a despawn. The base
    loop still ticks at TargetFPS, but each tick is a Sleep(120) - a few
    cheap wake-ups per second instead of a fullscreen raster surface,
    snapshot and invalidate round-trip. }
  Busy := (FChaos <> nil) and FChaos.HighlighterBusy;
  if not Busy then
  begin
    if Visible then
      TThread.Queue(nil,
        procedure
        begin
          { Re-check on the UI thread: the wake hook may have re-activated
            the highlighter between queueing and delivery, and the form may
            already be tearing down. }
          if (csDestroying in ComponentState) then
            Exit;
          if not ((FChaos <> nil) and FChaos.HighlighterBusy) then
            Visible := False;
        end);
    Sleep(120);
    Exit;
  end;

  { Start every frame from a clean transparent surface: an entity that
    just finished its exit animation must leave the desktop clear, never a
    frozen copy of its last position. }
  ACanvas.Clear($00000000);

  { Per-frame delta from the same monotonic clock the base thread hands
    down; the first frame and long stalls (debugger pause) fall back to a
    60 Hz step, mirroring TSkChaos' own clamping. }
  if (FLastTime <= 0) or (ATime <= FLastTime) or (ATime - FLastTime > 0.25) then
    Delta := 1.0 / 60.0
  else
    Delta := ATime - FLastTime;
  FLastTime := ATime;

  { The entity's wall model mirrors this full-desktop canvas, so walls
    repel at the screen edges and the exit animation aims off-screen.
    The cursor is converted into this form's local frame - which spans
    the whole desktop - so mouse-follow can aim anywhere on screen, not
    just inside the small avatar rect. }
  FChaos.SetHighlighterBounds(Width, Height);
  if GetCursorPos(Cur) then
  begin
    C := Self.ScreenToLocal(PointF(Cur.X, Cur.Y));
    FChaos.RenderHighlighterOverlay(ACanvas, Delta, C.X, C.Y, True);
  end
  else
    FChaos.RenderHighlighterOverlay(ACanvas, Delta, 0, 0, False);

  { Pacing: the busy branch above runs at the full rate; the idle branch
    never reaches this, it sleeps. FBusyFrame keeps the switch for the
    transition frame where Busy flips to False mid-render. }
  if Busy <> FBusyFrame then
  begin
    if Busy then
      TargetFPS := 50
    else
      TargetFPS := 10;
    FBusyFrame := Busy;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  Wnd: HWND;
begin
  Wnd := WindowHandleToPlatform(Self.Handle).wnd;
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
  if not FChaos.StartupPresetLoaded then
  begin
    FChaos.Position.X := ClientWidth - 236 - 20;
    FChaos.Position.Y := ClientHeight - 252 - 50;
    FChaos.Width := 236;
    FChaos.Height := 252;
  end;

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
  { Full-desktop highlighter host, created after the avatar so it paints
    on top of it (the entity used to be the last thing TSkChaos drew).
    It only ever draws the entity itself - the rest of its frame stays
    transparent - and ignores all mouse input. It starts hidden: the
    render loop's idle branch sleeps at 120 ms and keeps Visible = False
    until the highlighter is actually used, so no fullscreen surface is
    allocated, snapshotted or composited while the entity is away. }
  FHighlighterOverlay := THighlighterOverlay.Create(Self, FChaos);
  FHighlighterOverlay.Parent := Self;
  FHighlighterOverlay.Align := TAlignLayout.Client;
  FHighlighterOverlay.HitTest := False;
  FHighlighterOverlay.Visible := False;
  { Wake hook: HighlightPoint / HighlightRect / enabling follow fire this
    on the UI thread, and the host shows itself immediately instead of
    waiting for its sleeping loop to notice. }
  FChaos.OnHighlighterWake := HighlighterWake;
  FHighlighterOverlay.Active := True;
  { FMX finalizes the window handle when the form is shown (Transparency /
    FormStyle recreate the HWND), which drops the raw WS_EX_TRANSPARENT flag
    applied above. Re-apply it from OnShow so click-through is live from the
    very first show, not only after the first manual toggle. OnClose is
    wired here for the same reason: Alt+F4 / taskbar closes must run the
    preset save below without depending on the form resource. }
  Self.OnShow := FormShow;
  Self.OnClose := FormClose;
end;

procedure TForm1.HighlighterWake(Sender: TObject);
begin
  { Fired on the UI thread from HighlightPoint / HighlightRect / the
    follow-mouse toggle: un-hide the fullscreen host immediately. The
    render loop's idle branch hid it; making it visible here lets the
    next tick draw the entity without a visible blank period. }
  if Assigned(FHighlighterOverlay) and (not FHighlighterOverlay.Visible) then
    FHighlighterOverlay.Visible := True;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  { Stop the highlighter overlay's render thread first: its frames keep
    calling into FChaos (RenderHighlighterOverlay), so the avatar control
    must outlive it. Both are form-owned, but freeing in this order makes
    the dependency explicit instead of relying on component order. }
  FreeAndNil(FHighlighterOverlay);
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

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  { Alt+F4 / taskbar close: persist the current head exactly like the
    tray's quit path (TSkChaos.QuitAfterDespawn) does, so position, size,
    auto-dim, neck pivot, custom eye part and FPS tiers survive to the
    next start without a manual "Save preset for this head". Saving again
    on the QuitAfterDespawn route is idempotent - same file, same values. }
  if Assigned(FChaos) then
  try
    FChaos.SaveCurrentMeshPreset;
  except
    { A read-only preset folder must never block closing the app. }
  end;
end;

end.
