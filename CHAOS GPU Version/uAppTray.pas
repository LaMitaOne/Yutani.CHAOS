unit uAppTray;

{ Windows notification-area (tray) icon with a popup menu for the Yutani
  Chaos avatar.

  - Right-click opens a menu: a "Mode" submenu with the four HoloStyle modes,
    "Show controls" to surface Form2, and "Exit" to quit.
  - Left-click shows the controls form directly.

  FMX has no built-in TTrayIcon, so this wraps the Win32 Shell_NotifyIcon API
  directly. The hidden top-level tool window (WS_EX_TOOLWINDOW - no taskbar
  entry, never visible) it creates is pumped by the FMX main message loop
  (TPlatformWin dispatches every queued message), so the tray callback arrives
  on the UI thread and the menu can touch GChaos / Form2 safely.

  Auto-created in the unit's initialization section - just add uAppTray to the
  uses clause, no manual Create/Free in Unit1 needed. GChaos is auto-located
  via uControls.FindChaos when a menu command fires. }

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, Winapi.Messages,
  Winapi.ShellAPI, FMX.Forms;

type
  TAppTray = class
  private
    FWnd: HWND;
    FIcon: HICON;
    FAdded: Boolean;
    FTrayMsg: Cardinal;
    procedure HandleMessage(var Msg: TMessage);
    procedure ShowMenu(X, Y: Integer);
    procedure DoCommand(Cmd: Integer);
  public
    constructor Create;
    destructor Destroy; override;
  end;

var
  GTray: TAppTray = nil;

implementation

uses
  uControls, Yutani.Chaos.Skia.GPU;

const
  TRAYWND_CLASS = 'YutaniChaosTrayWnd';
  IDM_MODE_CLASSIC = 1001;
  IDM_MODE_CYBER = 1002;
  IDM_MODE_VOLUME = 1003;
  IDM_MODE_PHOTO = 1004;
  IDM_CONTROLS = 1010;
  IDM_EXIT = 1011;
  IDM_SPAWN = 1012;
  IDM_DESPAWN = 1013;
  IDM_MOUSEFOLLOW = 1014;
  IDM_STAYONTOP = 1015;
  IDM_CLICKTHROUGH = 1016;

function TrayWndProc(hWnd: hWnd; Msg: UINT; wParam: wParam; lParam: lParam): LRESULT; stdcall;
var
  Tray: TAppTray;
  M: TMessage;
begin
  Tray := TAppTray(Pointer(GetWindowLongPtr(hWnd, GWLP_USERDATA)));
  if Assigned(Tray) then
  begin
    M.Msg := Msg;
    M.WParam := wParam;
    M.LParam := lParam;
    M.Result := 0;
    Tray.HandleMessage(M);
    Exit(M.Result);
  end;
  Result := DefWindowProc(hWnd, Msg, wParam, lParam);
end;

constructor TAppTray.Create;
var
  WCE: TWndClassExW;
  NID: NOTIFYICONDATAW;
  Tip: string;
begin
  FTrayMsg := RegisterWindowMessageW('YutaniChaosTrayCallback');

  FillChar(WCE, SizeOf(WCE), 0);
  WCE.cbSize := SizeOf(WCE);
  WCE.lpfnWndProc := @TrayWndProc;
  WCE.hInstance := HInstance;
  WCE.lpszClassName := TRAYWND_CLASS;
  RegisterClassExW(WCE);

  { Hidden top-level tool window (no taskbar entry, never visible) hosts the
    tray callback. A message-only window can miss callbacks on some shells;
    a real hidden tool window is the reliable tray host. }
  FWnd := CreateWindowExW(WS_EX_TOOLWINDOW, TRAYWND_CLASS, '', WS_POPUP, 0, 0, 0, 0, 0, 0, HInstance, nil);
  if FWnd <> 0 then
    SetWindowLongPtr(FWnd, GWLP_USERDATA, NativeInt(Self));

  { Prefer the application's own icon resource; fall back to the system
    generic application icon if the project has no MAINICON. }
  FIcon := LoadIconW(HInstance, 'MAINICON');
  if FIcon = 0 then
    FIcon := LoadIconW(0, IDI_APPLICATION);

  FillChar(NID, SizeOf(NID), 0);
  NID.cbSize := SizeOf(NID);
  NID.Wnd := FWnd;
  NID.uID := 1;
  NID.uFlags := NIF_ICON or NIF_MESSAGE or NIF_TIP;
  NID.uCallbackMessage := FTrayMsg;
  NID.hIcon := FIcon;
  Tip := 'Yutani Chaos';
  StrLCopy(@NID.szTip[0], PWideChar(Tip), High(NID.szTip));
  FAdded := Shell_NotifyIconW(NIM_ADD, @NID);
end;

destructor TAppTray.Destroy;
var
  NID: NOTIFYICONDATAW;
begin
  if FAdded then
  begin
    FillChar(NID, SizeOf(NID), 0);
    NID.cbSize := SizeOf(NID);
    NID.Wnd := FWnd;
    NID.uID := 1;
    Shell_NotifyIconW(NIM_DELETE, @NID);
    FAdded := False;
  end;
  if (FIcon <> 0) then
    DestroyIcon(FIcon);
  if FWnd <> 0 then
    DestroyWindow(FWnd);
  inherited;
end;

procedure TAppTray.HandleMessage(var Msg: TMessage);
var
  Pt: TPoint;
begin
  if Msg.Msg = FTrayMsg then
  begin
    case Msg.LParam of
      WM_RBUTTONUP:
        begin
          GetCursorPos(Pt);
          ShowMenu(Pt.X, Pt.Y);
        end;
      WM_LBUTTONUP:
        begin
          if not Assigned(Form2) then
            Form2 := TForm2.Create(Application);
          Form2.Show;
        end;
    end;
    Msg.Result := 0;
    Exit;
  end;
  Msg.Result := DefWindowProc(FWnd, Msg.Msg, Msg.WParam, Msg.LParam);
end;

function MenuCheck(on: Boolean): Cardinal;
begin
  if on then
    Result := MF_CHECKED
  else
    Result := 0;
end;

procedure TAppTray.ShowMenu(X, Y: Integer);
var
  hXMenu, hSub: HMENU;
  Cmd: Integer;
begin
  hXMenu := CreatePopupMenu;
  hSub := CreatePopupMenu;
  AppendMenuW(hSub, MF_STRING, IDM_MODE_CLASSIC, PChar('Classic'));
  AppendMenuW(hSub, MF_STRING, IDM_MODE_CYBER, PChar('Cyber'));
  AppendMenuW(hSub, MF_STRING, IDM_MODE_VOLUME, PChar('Volumetric'));
  AppendMenuW(hSub, MF_STRING, IDM_MODE_PHOTO, PChar('Photo'));
  AppendMenuW(hXMenu, MF_POPUP or MF_STRING, hSub, PChar('Mode'));
  AppendMenuW(hXMenu, MF_STRING, IDM_CONTROLS, PChar('Show controls'));
  AppendMenuW(hXMenu, MF_SEPARATOR, 0, nil);
  AppendMenuW(hXMenu, MF_STRING, IDM_SPAWN, PChar('Spawn'));
  AppendMenuW(hXMenu, MF_STRING, IDM_DESPAWN, PChar('Despawn'));
  AppendMenuW(hXMenu, MF_SEPARATOR, 0, nil);
  AppendMenuW(hXMenu, MF_STRING or MenuCheck(Assigned(GChaos) and GChaos.MouseFollow), IDM_MOUSEFOLLOW, PChar('Mouse follow'));
  AppendMenuW(hXMenu, MF_STRING or MenuCheck(Assigned(GChaos) and GChaos.StayOnTop), IDM_STAYONTOP, PChar('Stay on top'));
  AppendMenuW(hXMenu, MF_STRING or MenuCheck(Assigned(GChaos) and GChaos.ClickThrough), IDM_CLICKTHROUGH, PChar('Click-through'));
  AppendMenuW(hXMenu, MF_SEPARATOR, 0, nil);
  AppendMenuW(hXMenu, MF_STRING, IDM_EXIT, PChar('Exit'));
  { SetForegroundWindow + a trailing WM_NULL is the documented workaround so
    the popup closes when the user clicks elsewhere (a NOTIFYICONDATA quirk). }
  SetForegroundWindow(FWnd);
  Cmd := Integer(TrackPopupMenu(hXMenu, TPM_RIGHTBUTTON or TPM_RETURNCMD, X, Y, 0, FWnd, nil));
  PostMessage(FWnd, WM_NULL, 0, 0);
  DestroyMenu(hXMenu);
  if Cmd <> 0 then
    DoCommand(Cmd);
end;

procedure TAppTray.DoCommand(Cmd: Integer);
begin
  if not Assigned(GChaos) then
    GChaos := FindChaos;
  case Cmd of
    IDM_MODE_CLASSIC:
      if Assigned(GChaos) then
        GChaos.HoloStyle := hsClassic;
    IDM_MODE_CYBER:
      if Assigned(GChaos) then
        GChaos.HoloStyle := hsCyber;
    IDM_MODE_VOLUME:
      if Assigned(GChaos) then
        GChaos.HoloStyle := hsVolumetric;
    IDM_MODE_PHOTO:
      if Assigned(GChaos) then
        GChaos.HoloStyle := hsPhoto;
    IDM_CONTROLS:
      begin
        if not Assigned(Form2) then
          Form2 := TForm2.Create(Application);
        Form2.Show;
      end;
    IDM_SPAWN:
      if Assigned(GChaos) then
        GChaos.Spawn;
    IDM_DESPAWN:
      if Assigned(GChaos) then
        GChaos.Despawn;
    IDM_MOUSEFOLLOW:
      if Assigned(GChaos) then
        GChaos.MouseFollow := not GChaos.MouseFollow;
    IDM_STAYONTOP:
      if Assigned(GChaos) then
        GChaos.StayOnTop := not GChaos.StayOnTop;
    IDM_CLICKTHROUGH:
      if Assigned(GChaos) then
        GChaos.ClickThrough := not GChaos.ClickThrough;
    { Exit plays the despawn animation first, then quits once it completes
      (see TSkChaos.QuitAfterDespawn / the csFading state machine). }
    IDM_EXIT:
      if Assigned(GChaos) then
        GChaos.QuitAfterDespawn
      else
        Application.Terminate;
  end;
end;

initialization
{ Auto-create the tray icon as soon as the unit loads, so just adding uAppTray
  to the uses clause is enough - no manual GTray := TAppTray.Create needed. }
  GTray := TAppTray.Create;


finalization
  FreeAndNil(GTray);

end.

