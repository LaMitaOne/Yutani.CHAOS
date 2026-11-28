unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  Winapi.Windows, Winapi.Messages, FMX.Platform.Win, FMX.Types, FMX.Controls,
  FMX.Forms, FMX.Graphics, FMX.Dialogs, Yutani.Chaos.Skia.GPU, uControls;

type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FChaos: TSkChaos;
    { Win32 topmost stabilization: raw GWLP_WNDPROC subclass on the real HWND.
      FMX's TFormStyle.StayOnTop sets the z-order only once; the DWM, explorer
      restarts and monitor changes silently drop the topmost band again, so
      this hook re-asserts HWND_TOPMOST on the relevant window messages:
      WM_WINDOWPOSCHANGING rewrites hwndInsertAfter before the z-order is
      applied, WM_DISPLAYCHANGE / WM_ACTIVATEAPP push topmost back directly. }
    FWndProcHook: Pointer;       // original wndproc, restored on destroy
    FHookedWnd: HWND;            // HWND the subclass was installed on
    procedure InstallTopmostHook;
    procedure RemoveTopmostHook;
  public
  end;

var
  Form1: TForm1;

implementation
{$R *.fmx}

const
  { Window property atoms for the topmost subclass. SetProp stores a
    HANDLE-sized value on the HWND; the subclass reads the original proc
    back from it on every message, so no global variables are needed and
    several forms could install the hook independently. }
  YUTANI_ORIGPROC_PROP = 'YutaniOrigProc';

{------------------------------------------------------------------------------
  Win32 subclass procedure (stdcall, window thread). A plain stdcall function
  has no Self pointer, so the owning form is resolved through the Form1 global
  (the only top-level overlay host in this application) and guarded with nil
  checks - the hook is uninstalled before the form is freed.

  WM_WINDOWPOSCHANGING: while StayOnTop is active and the message actually
  changes the z-order (no SWP_NOZORDER), the requested insert-after window is
  redirected to HWND_TOPMOST before Windows applies it, so any reposition that
  would drop the overlay back into the normal band (full-screen apps, window
  managers, shell) is amended on the fly.

  WM_DISPLAYCHANGE / WM_ACTIVATEAPP: resolution switches and app activations
  commonly strip the topmost band; re-assert it immediately with a pure
  z-order-only SetWindowPos (no move, no size, no focus steal).
------------------------------------------------------------------------------}
var
  GShuttingDown: Boolean = False;

function YutaniTopmostHookProc(Wnd: HWND; Msg: UINT; WParam: WPARAM;
  LParam: LPARAM): LRESULT; stdcall;
var
  OrigProc: FARPROC;
  PPos: ^TWindowPos;
begin
 if GShuttingDown or (Msg = WM_DESTROY) or (Msg = WM_NCDESTROY) then
  begin
  OrigProc := Pointer(GetPropW(Wnd, YUTANI_ORIGPROC_PROP));
  if OrigProc <> nil then
    Result := CallWindowProc(OrigProc, Wnd, Msg, WParam, LParam)
  else
    Result := DefWindowProc(Wnd, Msg, WParam, LParam);
  Exit;
  end;

  OrigProc := FARPROC(GetPropW(Wnd, YUTANI_ORIGPROC_PROP));
  if OrigProc = nil then
    OrigProc := FARPROC(GetWindowLongPtr(Wnd, GWLP_WNDPROC));

  if (Form1 <> nil) and (Form1.FChaos <> nil) and Form1.FChaos.StayOnTop then
  begin
    case Msg of
      WM_WINDOWPOSCHANGING:
        begin
          { Amend the requested z-order before Windows applies it. }
          PPos := Pointer(LParam);
          if (PPos^.flags and SWP_NOZORDER) = 0 then
            PPos^.hwndInsertAfter := HWND_TOPMOST;
        end;
      WM_DISPLAYCHANGE, WM_ACTIVATEAPP:
        begin
          SetWindowPos(Wnd, HWND_TOPMOST, 0, 0, 0, 0,
            SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
        end;
    end;
  end;

  Result := CallWindowProc(OrigProc, Wnd, Msg, WParam, LParam);
end;

procedure TForm1.InstallTopmostHook;
var
  Wnd: HWND;
  PrevProc: Pointer;
begin
  { Idempotent: skip while a subclass is already installed. Self.Handle <> nil
    (NEVER HandleAllocated - that would create the handle as a side effect):
    only install once the platform window really exists. }
  if FWndProcHook <> nil then
    Exit;
  if not (Self.Handle <> nil) then
    Exit;
  Wnd := WindowHandleToPlatform(Self.Handle).Wnd;
  if (Wnd = 0) or (GetWindowLongPtr(Wnd, GWLP_WNDPROC) = 0) then
    Exit;
  FHookedWnd := Wnd;
  SetPropW(Wnd, YUTANI_ORIGPROC_PROP, THandle(GetWindowLongPtr(Wnd, GWLP_WNDPROC)));
  PrevProc := Pointer(SetWindowLongPtr(Wnd, GWLP_WNDPROC, NativeInt(@YutaniTopmostHookProc)));
  if PrevProc = nil then
  begin
    { SetWindowLongPtr failed (protected / already being destroyed): clean
      the property back up and leave the hook uninstalled. }
    RemovePropW(Wnd, YUTANI_ORIGPROC_PROP);
    FHookedWnd := 0;
    Exit;
  end;
  FWndProcHook := PrevProc;
end;

procedure TForm1.RemoveTopmostHook;
begin
  if FWndProcHook = nil then
    Exit;
  { Restore the original procedure BEFORE the form tears the HWND down, but
    only if our subclass is still the installed one (a later re-creation of
    the HWND by FMX would have reset GWLP_WNDPROC on its own). }
  if (FHookedWnd <> 0) and IsWindow(FHookedWnd) then
  begin
    if Pointer(GetWindowLongPtr(FHookedWnd, GWLP_WNDPROC)) = @YutaniTopmostHookProc then
      SetWindowLongPtr(FHookedWnd, GWLP_WNDPROC, NativeInt(FWndProcHook));
    RemovePropW(FHookedWnd, YUTANI_ORIGPROC_PROP);
  end;
  FWndProcHook := nil;
  FHookedWnd := 0;
end;

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
    is a live option on the tray menu and the controls panel.
    Click-through stays OFF when the startup preset restored
    DragMode = True: the preset explicitly wants mouse input for
    dragging, and forcing click-through here would fight it. }
  FChaos.MouseFollow := True;
  FChaos.StayOnTop := True;
  if not FChaos.DragMode then
    FChaos.ClickThrough := True;
  { FMX finalizes the window handle when the form is shown (Transparency /
    FormStyle recreate the HWND), which drops the raw WS_EX_TRANSPARENT flag
    applied above. Re-apply it from OnShow so click-through is live from the
    very first show, not only after the first manual toggle. }
  Self.OnShow := FormShow;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  GShuttingDown := True;
   GChaos := nil;
  RemoveTopmostHook;
  { Restore the original wndproc before the form frees the HWND so the
    subclass never fires on a half-torn-down window. }
  RemoveTopmostHook;
  { Final ai.ini save on the way down (QuitAfterDespawn -> Terminate ->
    FormDestroy): a paste into an endpoint edit that fired no OnTyping /
    OnChange event would otherwise be lost on quit. Guarded against a
    destroyed / never-built panel. }
  if Form2 <> nil then
    Form2.SaveSettingsIfBuilt;
  { Clear the global FIRST: uControls / tray still hold GChaos references,
    and any access between here and their own teardown would chase a
    dangling pointer. }
  GChaos := nil;
  { NO FreeAndNil here: FChaos was created with TSkChaos.Create(Self) and
    Parent := Self, so FMX owns and frees it in the correct order while
    tearing Form1 down. Freeing it here ourselves would leave a dangling
    entry in the form's component/children lists - the later owner destroy
    then walked into the TObject.InheritsFrom Access Violation at shutdown.
    We only detach the global and switch the render loop off; the field is
    nil-ed purely so late code can test it. }
  if FChaos <> nil then
    FChaos.Active := False;
  FChaos := nil;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  { The window handle is now finalized by FMX; re-apply click-through so it
    takes effect from the first show instead of only after a manual toggle. }
  if Assigned(FChaos) then
    FChaos.ApplyClickThrough;
  { Install the topmost stabilization hook on the final handle; an HWND
    re-creation (FormStyle / Transparency change) first hits RemoveTopmostHook
    bookkeeping through the still-valid old install, and the guard makes this
    call re-install cleanly on the new handle. }
  if FWndProcHook <> nil then
    RemoveTopmostHook;
  InstallTopmostHook;
end;

end.
