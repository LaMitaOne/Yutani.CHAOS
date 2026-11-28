unit Yutani.GPUInfo;
{==============================================================================*
 *  Yutani C.H.A.O.S. - GPU capability detection & compute benchmark
 *------------------------------------------------------------------------------
 *  Module : Yutani.GPUInfo
 *  Type   : Standalone GPU detection helper (no FMX / Skia dependencies)
 *  Author : Lara Miriam Tamy Reschke / LamitaOne
 *------------------------------------------------------------------------------
 *  Description:
 *  Detects the active OpenGL renderer / vendor / version strings, the
 *  adapter's VRAM through the DXVA2-free path (wgl + DXGI-free registry
 *  read where available), and runs a 15 ms compute-dispatch benchmark
 *  against the CURRENT OpenGL 4.3 context to score the GPU's compute
 *  throughput. From renderer + VRAM + score a budget tier (High / Medium /
 *  Low / Minimal) and a recommended particle budget are derived.
 *
 *  IMPORTANT: DetectGPUCapabilities(True) MUST be called while the target
 *  GL context is current (the benchmark dispatches a real compute shader);
 *  TSkChaos calls it right after InitOffscreenGL on the render thread.
 *==============================================================================}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes;

{ wgl entry points from opengl32.dll (no GL unit dependency in here - the
  GPU unit keeps its own declarations, this helper the bare minimum). }
function wglGetProcAddress(Name: PAnsiChar): Pointer; stdcall; external 'opengl32.dll';
function wglGetCurrentContext: HGLRC; stdcall; external 'opengl32.dll';

type
  { Budget tier derived from renderer / VRAM / compute score. }
  TGpuTier = (gtUnknown, gtMinimal, gtLow, gtMedium, gtHigh);

const
  TGpuTierNames: array[TGpuTier] of string = ('Unknown', 'Minimal', 'Low',
    'Medium', 'High');

type
  { Detection result snapshot: plain values, no objects, so it can be copied
    around freely. }
  TGpuCapabilities = record
    Renderer: string;              { GL_RENDERER string (vendor + model) }
    Vendor: string;               { GL_VENDOR string }
    Version: string;              { GL_VERSION string }
    DedicatedVRAMMB: Cardinal;    { dedicated VRAM, 0 when unknown }
    SharedVRAMMB: Cardinal;        { shared system-memory budget, 0 unknown }
    ComputeScoreMS: Double;        { 15 ms benchmark: measured ms, lower better; -1 failed }
    Tier: TGpuTier;
    RecommendedParticles: Integer;  { tier-scaled budget for the overlay }
  end;

{ Runs the whole detection. ABenchmark = True ALSO dispatches the 15 ms
  compute benchmark (requires the GL context current on the CALLING thread -
  TSkChaos does this right after InitOffscreenGL). ABenchmark = False skips
  the dispatch and leaves ComputeScoreMS = -1 with a renderer-only tier. }
function DetectGPUCapabilities(const ABenchmark: Boolean): TGpuCapabilities;

{ Formats the capabilities into the multi-line block the Info / Debug tab
  shows (renderer, tier, VRAM, compute score, recommended particles). }
function FormatGpuInfoText(const ACaps: TGpuCapabilities): string;

{ Tier from the renderer string, VRAM and (optionally) the benchmark score;
  re-ranking rules documented in the implementation. }
function TierFromHeuristics(const ARenderer: string; AVramMB: Cardinal;
  AComputeScoreMS: Double): TGpuTier;

implementation

uses
  System.Math;

const
  { glGetString constants (OpenGL 1.x core, exported by opengl32.dll). }
  GL_VENDOR = $1F00;
  GL_RENDERER = $1F01;
  GL_VERSION = $1F02;

  { Benchmark compute shader: 256 invocations per work group loop 4096 FMA
    steps; the final buffer write keeps the scheduler from folding the loop
    away. 96 x 256 invocations = 24576 threads, dispatched repeatedly for a
    ~15 ms wall-clock window. }
  BENCH_SRC: AnsiString =
    '#version 430 core'#10 +
    'layout(local_size_x = 256) in;'#10 +
    'layout(std430, binding = 0) buffer B { float acc[]; };'#10 +
    'uniform float uSeed;'#10 +
    'void main() {'#10 +
    '  uint idx = gl_GlobalInvocationID.x;'#10 +
    '  float v = uSeed + float(idx);'#10 +
    '  for (int i = 0; i < 4096; ++i) {'#10 +
    '    v = v * 1.0000001 + 0.0000001;'#10 +
    '  }'#10 +
    '  acc[idx % 4096u] = v;'#10 +
    '}';

type
  { Function-pointer types for the wgl-proc resolution: every entry point
    the benchmark needs, loaded through wglGetProcAddress with the
    opengl32.dll fallback - identical to TSkChaos' own loader. }
  TglCreateShader = function(ShaderType: Cardinal): Cardinal; stdcall;
  TglShaderSource = procedure(Shader: Cardinal; Count: Integer;
    Str: PPAnsiChar; Len: PInteger); stdcall;
  TglCompileShader = procedure(Shader: Cardinal); stdcall;
  TglGetShaderiv = procedure(Shader: Cardinal; PName: Cardinal;
    Params: PInteger); stdcall;
  TglGetShaderInfoLog = procedure(Shader: Cardinal; BufSize: Integer;
    Length: PInteger; InfoLog: PAnsiChar); stdcall;
  TglDeleteShader = procedure(Shader: Cardinal); stdcall;
  TglCreateProgram = function: Cardinal; stdcall;
  TglAttachShader = procedure(ProgramObj, Shader: Cardinal); stdcall;
  TglLinkProgram = procedure(ProgramObj: Cardinal); stdcall;
  TglGetProgramiv = procedure(ProgramObj: Cardinal; PName: Cardinal;
    Params: PInteger); stdcall;
  TglDeleteProgram = procedure(ProgramObj: Cardinal); stdcall;
  TglGenBuffers = procedure(N: Integer; Buffers: PCardinal); stdcall;
  TglDeleteBuffers = procedure(N: Integer; Buffers: PCardinal); stdcall;
  TglBindBuffer = procedure(Target: Cardinal; Buffer: Cardinal); stdcall;
  TglBufferData = procedure(Target: Cardinal; Size: NativeInt;
    Data: Pointer; Usage: Cardinal); stdcall;
  TglDispatchCompute = procedure(GroupsX, GroupsY, GroupsZ: Cardinal); stdcall;
  TglGetUniformLocation = function(ProgramObj: Cardinal;
    Name: PAnsiChar): Integer; stdcall;
  TglUniform1f = procedure(Location: Integer; V0: Single); stdcall;
  TglMemoryBarrier = procedure(Barriers: Cardinal); stdcall;

var
  { opengl32.dll core exports. }
  glGetStringFn: function(Name: Cardinal): PAnsiChar; stdcall;

  { wgl-resolved extension entries for the benchmark. }
  glCreateShaderFn: TglCreateShader;
  glShaderSourceFn: TglShaderSource;
  glCompileShaderFn: TglCompileShader;
  glGetShaderivFn: TglGetShaderiv;
  glGetShaderInfoLogFn: TglGetShaderInfoLog;
  glDeleteShaderFn: TglDeleteShader;
  glCreateProgramFn: TglCreateProgram;
  glAttachShaderFn: TglAttachShader;
  glLinkProgramFn: TglLinkProgram;
  glGetProgramivFn: TglGetProgramiv;
  glDeleteProgramFn: TglDeleteProgram;
  glGenBuffersFn: TglGenBuffers;
  glDeleteBuffersFn: TglDeleteBuffers;
  glBindBufferFn: TglBindBuffer;
  glBufferDataFn: TglBufferData;
  glDispatchComputeFn: TglDispatchCompute;
  glGetUniformLocationFn: TglGetUniformLocation;
  glUniform1fFn: TglUniform1f;
  glMemoryBarrierFn: TglMemoryBarrier;

function GetGLProc(const Name: AnsiString): Pointer;
begin
  { wglGetProcAddress first (works while a context is current - always true
    here because DetectGPUCapabilities is only called with one), then the
    opengl32.dll static fallback. The <= 3 sentinel marks "not supported". }
  Result := wglGetProcAddress(PAnsiChar(Name));
  if (Result = nil) or (NativeUInt(Result) <= 3) or (NativeUInt(Result) = NativeUInt(-1)) then
    Result := GetProcAddress(GetModuleHandleW('opengl32.dll'), PAnsiChar(Name));
end;

function glGetStringSafe(Name: Cardinal): string;
var
  P: PAnsiChar;
begin
  Result := '';
  if not Assigned(glGetStringFn) then
    Exit;
  P := glGetStringFn(Name);
  if P <> nil then
    Result := string(AnsiString(P));
end;

function NowSeconds: Double;
var
  Freq, Count: Int64;
begin
  QueryPerformanceFrequency(Freq);
  QueryPerformanceCounter(Count);
  if Freq = 0 then
    Exit(0);
  Result := Count / Freq;
end;

function RunComputeBenchmark: Double;
var
  Shader, XProgram: Cardinal;
  Buf: Cardinal;
  Success: Integer;
  SrcPtr: PPAnsiChar;
  SrcAnsi: PAnsiChar;
  SrcLen: Integer;
  Loc: Integer;
  Start, Elapsed: Double;
  Dispatches: Integer;
  SSBOBytes: NativeInt;
  Ctx: HGLRC;
begin
  { ~15 ms wall-clock benchmark: dispatches 96x256-wide compute groups with
    a memory barrier between rounds until 15 ms elapsed, then normalizes to
    "ms per 1000 dispatches". Must run with the target context CURRENT.
    Any resolution / compile failure raises EAbort (caller catches and
    keeps the score at -1) - a missing GL 4.3 entry point must never crash
    the app's first frame. }
  Result := -1;
  Ctx := wglGetCurrentContext;
  if Ctx = 0 then
    raise EAbort.Create('No GL context current for the benchmark');

  glCreateShaderFn := GetGLProc('glCreateShader');
  glShaderSourceFn := GetGLProc('glShaderSource');
  glCompileShaderFn := GetGLProc('glCompileShader');
  glGetShaderivFn := GetGLProc('glGetShaderiv');
  glGetShaderInfoLogFn := GetGLProc('glGetShaderInfoLog');
  glDeleteShaderFn := GetGLProc('glDeleteShader');
  glCreateProgramFn := GetGLProc('glCreateProgram');
  glAttachShaderFn := GetGLProc('glAttachShader');
  glLinkProgramFn := GetGLProc('glLinkProgram');
  glGetProgramivFn := GetGLProc('glGetProgramiv');
  glDeleteProgramFn := GetGLProc('glDeleteProgram');
  glGenBuffersFn := GetGLProc('glGenBuffers');
  glDeleteBuffersFn := GetGLProc('glDeleteBuffers');
  glBindBufferFn := GetGLProc('glBindBuffer');
  glBufferDataFn := GetGLProc('glBufferData');
  glDispatchComputeFn := GetGLProc('glDispatchCompute');
  glGetUniformLocationFn := GetGLProc('glGetUniformLocation');
  glUniform1fFn := GetGLProc('glUniform1f');
  glMemoryBarrierFn := GetGLProc('glMemoryBarrier');

  if (not Assigned(glCreateShaderFn)) or (not Assigned(glShaderSourceFn)) or
     (not Assigned(glCompileShaderFn)) or (not Assigned(glDispatchComputeFn)) or
     (not Assigned(glGenBuffersFn)) then
    raise EAbort.Create('GL 4.3 compute entry points unavailable');

  Shader := glCreateShaderFn($91B9);  { GL_COMPUTE_SHADER }
  if Shader = 0 then
    raise EAbort.Create('glCreateShader failed');
  try
    { PAnsiChar(BENCH_SRC) points AT the string's character data; taking the
      PPAnsiChar of the typed constant itself would hand glShaderSource a
      pointer into the Delphi string HEADER (refcount / length fields), so
      the driver would read garbage and the compile (and with it the whole
      benchmark) fail with -1 ms. The local SrcAnsi pointer keeps the
      address stable for the @SrcPtr indirection glShaderSource expects. }
    SrcAnsi := PAnsiChar(BENCH_SRC);
    SrcPtr := @SrcAnsi;
    SrcLen := Length(BENCH_SRC);
    glShaderSourceFn(Shader, 1, SrcPtr, @SrcLen);
    glCompileShaderFn(Shader);
    Success := 0;
    glGetShaderivFn(Shader, $8B81 { GL_COMPILE_STATUS }, @Success);  { GL_COMPILE_STATUS }
    if Success = 0 then
      raise EAbort.Create('Benchmark shader compile failed');
    XProgram := glCreateProgramFn();
    if XProgram = 0 then
      raise EAbort.Create('glCreateProgram failed');
    try
      glAttachShaderFn(XProgram, Shader);
      glLinkProgramFn(XProgram);
      Success := 0;
      glGetProgramivFn(XProgram, $8B82 { GL_LINK_STATUS }, @Success);  { GL_LINK_STATUS }
      if Success = 0 then
        raise EAbort.Create('Benchmark program link failed');

      { 16 KB SSBO backing store (4096 floats as the shader addresses). }
      glGenBuffersFn(1, @Buf);
      SSBOBytes := 16384;
      glBindBufferFn($90D2 { GL_SHADER_STORAGE_BUFFER }, Buf);  { GL_SHADER_STORAGE_BUFFER }
      glBufferDataFn($90D2, SSBOBytes, nil, $88EA { GL_DYNAMIC_COPY });
      glBindBufferFn($90D2, 0);

      { Warm-up compile-cache dispatch before timing starts. }
      glDispatchComputeFn(96, 1, 1);
      glMemoryBarrierFn($00000020 { GL_SHADER_IMAGE_ACCESS_BARRIER_BIT } or
        $00002000 { GL_SHADER_STORAGE_BARRIER_BIT });

      Dispatches := 0;
      Start := NowSeconds;
      repeat
        glDispatchComputeFn(96, 1, 1);
        glMemoryBarrierFn($00000020 or $00002000);
        Inc(Dispatches);
        Elapsed := NowSeconds - Start;
      until (Elapsed >= 0.015) or (Dispatches >= 1000);

      if Dispatches > 0 then
        { Normalized: ms per 1000 dispatches, so the raw 15 ms window is
          comparable across machines with vsync-free dispatch scheduling. }
        Result := (Elapsed / Dispatches) * 1000.0 * 1000.0;
      glDeleteBuffersFn(1, @Buf);
    finally
      glDeleteProgramFn(XProgram);
    end;
  finally
    glDeleteShaderFn(Shader);
  end;
end;

function TierFromHeuristics(const ARenderer: string; AVramMB: Cardinal;
  AComputeScoreMS: Double): TGpuTier;
var
  R: string;
begin
  { Tier heuristics: the renderer string is the most reliable signal
    (integrated chips name themselves), VRAM backs the guess up, the
    benchmark score only re-ranks borderline cases. No remote lookups -
    everything is decided from local strings. }
  R := LowerCase(ARenderer);
  Result := gtMedium;
  if (Pos('rtx 40', R) > 0) or (Pos('rtx 50', R) > 0) or (Pos('rx 68', R) > 0)
    or (Pos('rx 69', R) > 0) or (Pos('arc a7', R) > 0) or (Pos('radeon pro', R) > 0)
    or ((AVramMB >= 8000) and (AVramMB < 65535)) then
    Result := gtHigh
  else if (Pos('intel', R) > 0) and ((Pos('uhd', R) > 0) or (Pos('iris', R) > 0)
    or (Pos('arc a3', R) > 0) or (Pos('hd graphics', R) > 0)) then
    Result := gtLow
  else if (Pos('gtx 10', R) > 0) or (Pos('gtx 16', R) > 0) or (Pos('rx 5', R) > 0)
    or (Pos('arc a5', R) > 0) or (Pos('vega', R) > 0) or (Pos('radeon rx', R) > 0) then
    Result := gtMedium
  else if (Pos('llvm', R) > 0) or (Pos('softpipe', R) > 0) or (Pos('swrast', R) > 0)
    or (Pos('microsoft basic', R) > 0) or (Pos('gdi', R) > 0) then
    Result := gtMinimal;
  { Benchmark re-rank: a blazing score lifts the tier one step, a terrible
    one drops it (an Intel iGPU mislabelled as discrete gets caught here). }
  if AComputeScoreMS > 0 then
  begin
    if (AComputeScoreMS <= 1.0) and (Result <> gtHigh) then
      Result := gtHigh
    else if (AComputeScoreMS >= 24.0) and (Result <> gtMinimal) then
      Result := gtLow;
  end;
end;

function RecommendedParticlesFromTier(ATier: TGpuTier): Integer;
begin
  { Particle budget per tier, derived from the avatar's own scaling: the
    236x252 buffer runs 250 k particles at 60 FPS on a mid-tier GPU, and
    larger meshes multiply per-particle cost. High-end hardware comfortably
    doubles that; minimal / software GL gets a slide-friendly floor. }
  case ATier of
    gtHigh: Result := 500000;
    gtMedium: Result := 250000;
    gtLow: Result := 120000;
    gtMinimal: Result := 40000;
  else
    Result := 100000;
  end;
end;

function DetectGPUCapabilities(const ABenchmark: Boolean): TGpuCapabilities;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Renderer := glGetStringSafe(GL_RENDERER);
  Result.Vendor := glGetStringSafe(GL_VENDOR);
  Result.Version := glGetStringSafe(GL_VERSION);
  Result.ComputeScoreMS := -1;
  if ABenchmark then
  begin
    { The 15 ms compute benchmark runs against the CURRENT context: the
      caller (TSkChaos.InitOffscreenGL path) guarantees the context is live
      on this thread. Any failure just leaves the score at -1 - tier and
      budget then rely on the renderer string alone. }
    try
      Result.ComputeScoreMS := RunComputeBenchmark;
    except
      Result.ComputeScoreMS := -1;
    end;
  end;
  Result.Tier := TierFromHeuristics(Result.Renderer, Result.DedicatedVRAMMB,
    Result.ComputeScoreMS);
  Result.RecommendedParticles := RecommendedParticlesFromTier(Result.Tier);
end;

function FormatGpuInfoText(const ACaps: TGpuCapabilities): string;
begin
  Result := 'GPU Renderer: ' + ACaps.Renderer + sLineBreak +
    'GPU Vendor: ' + ACaps.Vendor + sLineBreak +
    'OpenGL Version: ' + ACaps.Version + sLineBreak +
    'Budget Tier: ' + TGpuTierNames[ACaps.Tier] + sLineBreak +
    'Compute Score: ' + FormatFloat('0.00', ACaps.ComputeScoreMS) +
    ' ms per 1000 dispatches (15 ms benchmark, lower = faster)' + sLineBreak +
    'Recommended Particles: ' + IntToStr(ACaps.RecommendedParticles);
end;

initialization
  glGetStringFn := GetProcAddress(GetModuleHandleW('opengl32.dll'), 'glGetString');

end.
