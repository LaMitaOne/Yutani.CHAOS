unit Yutani.Chaos.Skia.GPU;

{==============================================================================*
 *  Yutani C.H.A.O.S. Skia GPU v0.2 - Holographic AI Desktop Overlay
 *------------------------------------------------------------------------------
 *  Module : Yutani.Chaos.Skia.GPU
 *  Type   : GPU-Accelerated Holographic AI Interface & Desktop Canvas
 *  Author : Lara Miriam Tamy Reschke / LamitaOne
 *------------------------------------------------------------------------------
 *  Description:
 *  This unit renders a dynamic, holographic AI face ("Chaos") and free-form
 *  desktop projections using an OpenGL 4.3 Compute Shader pipeline. Particle
 *  spring physics, 3D perspective projection, depth-based volumetric shading,
 *  and soft radial glow splatting are executed entirely on the GPU via SSBOs
 *  and coherent image load/store operations. The resulting premultiplied-alpha
 *  frame is composited via Skia onto a transparent, click-through FireMonkey
 *  layered window with minimal CPU/GPU footprint, supporting full build-up
 *  (formation), tear-down (gravity fade), and adaptive FPS scaling.
 *==============================================================================}

interface

uses
  Winapi.Windows, System.SysUtils, System.Types, System.Classes, System.Math,
  System.UITypes, System.SyncObjs, FMX.Types, FMX.Controls, FMX.Graphics,
  FMX.Skia, System.Skia, uSkiaCustomThreadedBase;

const
  CHAOS_WIDTH = 236;
  CHAOS_HEIGHT = 252;
  PARTICLE_MAX = 500000;
  DEFAULT_PARTICLE_BUDGET = 250000;
  SSBO_PARTICLE_SIZE = 52;    // FIX: was 48, sizeof(TParticleCPU)=52
  DEPTH_MAP_STEP = 10;    // match CPU original (was 3)
  WGL_CONTEXT_MAJOR_VERSION_ARB = $2091;
  WGL_CONTEXT_MINOR_VERSION_ARB = $2092;
  WGL_CONTEXT_PROFILE_MASK_ARB = $9126;
  WGL_CONTEXT_CORE_PROFILE_BIT_ARB = $00000001;
  GL_COMPUTE_SHADER = $91B9;
  GL_SHADER_STORAGE_BUFFER = $90D2;
  GL_SHADER_STORAGE_BARRIER_BIT = $00002000;
  GL_SHADER_IMAGE_ACCESS_BARRIER_BIT = $00000020;
  GL_TEXTURE_2D = $0DE1;
  GL_TEXTURE_MIN_FILTER = $2801;
  GL_TEXTURE_MAG_FILTER = $2800;
  GL_TEXTURE_WRAP_S = $2802;
  GL_TEXTURE_WRAP_T = $2803;
  GL_CLAMP_TO_EDGE = $812F;
  GL_LINEAR = $2601;
  GL_RGBA8 = $8058;
  GL_BGRA = $80E1;
  GL_UNSIGNED_BYTE = $1401;
  GL_COMPILE_STATUS = $8B81;
  GL_LINK_STATUS = $8B82;
  GL_INFO_LOG_LENGTH = $8B84;
  GL_READ_ONLY = $88B8;
  GL_WRITE_ONLY = $88B9;
  GL_READ_WRITE = $88BA;
  GL_PIXEL_PACK_BUFFER = $88EB;
  GL_STREAM_READ = $88E1;
  GL_MAP_READ_BIT = $0001;
  GL_DYNAMIC_COPY = $88EA;

type
  TChaosState = (csIdle, csForming, csActive, csFading, csFinished);

  TMouthState = (msClosed, msMin, msMid, msFull);

  TEyeState = (esOpen, esMid, esClosed);

  TEmotionMode = (emNeutral, emThinking, emHappy, emAlert);

  TParticleCPU = packed record
    PX, PY, PZ: Single;
    VX, VY, VZ: Single;
    TX, TY, TZ: Single;
    Color: Cardinal;
    Flags: Cardinal;
    Pad0, Pad1: Cardinal;
  end;

type
  PFNGLCREATESHADERPROC = function(shaderType: Cardinal): Cardinal; stdcall;

  PFNGLDELETESHADERPROC = procedure(shader: Cardinal); stdcall;

  PFNGLSHADERSOURCEPROC = procedure(shader: Cardinal; count: Integer; str: PPAnsiChar; len: PInteger); stdcall;

  PFNGLCOMPILESHADERPROC = procedure(shader: Cardinal); stdcall;

  PFNGLGETSHADERIVPROC = procedure(shader: Cardinal; pname: Cardinal; params: PInteger); stdcall;

  PFNGLGETSHADERINFOLOGPROC = procedure(shader: Cardinal; bufSize: Integer; length: PInteger; infoLog: PAnsiChar); stdcall;

  PFNGLCREATEPROGRAMPROC = function: Cardinal; stdcall;

  PFNGLATTACHSHADERPROC = procedure(programObj: Cardinal; shader: Cardinal); stdcall;

  PFNGLLINKPROGRAMPROC = procedure(programObj: Cardinal); stdcall;

  PFNGLDELETEPROGRAMPROC = procedure(programObj: Cardinal); stdcall;

  PFNGLGETPROGRAMIVPROC = procedure(programObj: Cardinal; pname: Cardinal; params: PInteger); stdcall;

  PFNGLGETPROGRAMINFOLOGPROC = procedure(programObj: Cardinal; bufSize: Integer; length: PInteger; infoLog: PAnsiChar); stdcall;

  PFNGLUSEPROGRAMPROC = procedure(programObj: Cardinal); stdcall;

  PFNGLGETUNIFORMLOCATIONPROC = function(programObj: Cardinal; name: PAnsiChar): Integer; stdcall;

  PFNGLUNIFORM1FPROC = procedure(location: Integer; v: Single); stdcall;

  PFNGLUNIFORM2FPROC = procedure(location: Integer; x, y: Single); stdcall;

  PFNGLUNIFORM4FPROC = procedure(location: Integer; x, y, z, w: Single); stdcall;

  PFNGLUNIFORM1IPROC = procedure(location: Integer; v: Integer); stdcall;

  PFNGLUNIFORM1UIPROC = procedure(location: Integer; v: Cardinal); stdcall;

  PFNGLDISPATCHCOMPUTEPROC = procedure(gx, gy, gz: Cardinal); stdcall;

  PFNGLMEMORYBARRIERPROC = procedure(barriers: Cardinal); stdcall;

  PFNGLGENBUFFERSPROC = procedure(n: Integer; buffers: PCardinal); stdcall;

  PFNGLDELETEBUFFERSPROC = procedure(n: Integer; buffers: PCardinal); stdcall;

  PFNGLBINDBUFFERPROC = procedure(target: Cardinal; buffer: Cardinal); stdcall;

  PFNGLBUFFERDATAPROC = procedure(target: Cardinal; size: NativeInt; data: Pointer; usage: Cardinal); stdcall;

  PFNGLBUFFERSUBDATAPROC = procedure(target: Cardinal; offset: NativeInt; size: NativeInt; data: Pointer); stdcall;

  PFNGLBINDBUFFERBASEPROC = procedure(target: Cardinal; index: Cardinal; buffer: Cardinal); stdcall;

  PFNGLMAPBUFFERRANGEPROC = function(target: Cardinal; offset: NativeInt; length: NativeInt; access: Cardinal): Pointer; stdcall;

  PFNGLUNMAPBUFFERPROC = function(target: Cardinal): ByteBool; stdcall;

  PFNGLGENTEXTURESPROC = procedure(n: Integer; textures: PCardinal); stdcall;

  PFNGLDELETETEXTURESPROC = procedure(n: Integer; textures: PCardinal); stdcall;

  PFNGLBINDTEXTUREPROC = procedure(target: Cardinal; texture: Cardinal); stdcall;

  PFNGLTEXPARAMETERIPROC = procedure(target: Cardinal; pname: Cardinal; param: Integer); stdcall;

  PFNGLTEXSTORAGE2DPROC = procedure(target: Cardinal; levels: Integer; internalformat: Cardinal; width, height: Integer); stdcall;

  PFNGLACTIVETEXTUREPROC = procedure(texture: Cardinal); stdcall;

  PFNGLBINDIMAGETEXTUREPROC = procedure(unit_: Cardinal; texture: Cardinal; level: Integer; layered: Cardinal; layer: Integer; access: Cardinal; format: Cardinal); stdcall;

  PFNGLGETTEXIMAGEPROC = procedure(target: Cardinal; level: Integer; format: Cardinal; type_: Cardinal; pixels: Pointer); stdcall;

  PFNWGLCREATECONTEXTATTRIBSARBPROC = function(hdc: HDC; shareContext: HGLRC; const attribList: PInteger): HGLRC; stdcall;

function wglCreateContext(hdc: HDC): HGLRC; stdcall; external 'opengl32.dll';

function wglDeleteContext(hglrc: HGLRC): BOOL; stdcall; external 'opengl32.dll';

function wglMakeCurrent(hdc: HDC; hglrc: HGLRC): BOOL; stdcall; external 'opengl32.dll';

function wglGetProcAddress(name: PAnsiChar): Pointer; stdcall; external 'opengl32.dll';

type
  TSkChaos = class(TSkiaCustomThreadedBase)
  private
    FMouthState: TMouthState;
    FEyeState: TEyeState;
    FDummyWnd: HWND;
    FDummyDC: HDC;
    FGLContext: HGLRC;
    FGLReady: Boolean;
    FGLFailed: Boolean;
    FOutputTex: Cardinal;
    FTempTex: Cardinal;             // NEW: ping-pong target for separable blur
    FParticleSSBO: Cardinal;
    FParticleCount: Cardinal;
    FParticleCPU: TBytes;
    FParticleProgram: Cardinal;
    FClearProgram: Cardinal;        // NEW: clears output texture per frame
    FBlurProgram: Cardinal;         // NEW: separable gaussian blur (H + V)
    FLocP_DeltaTime, FLocP_Time, FLocP_Resolution: Integer;
    FLocP_ParticleCount, FLocP_BuildScanY, FLocP_DespawnScanY, FLocP_State: Integer;
    FLocP_ChaosLevel, FLocP_MouthOpen, FLocP_EyeOpeness: Integer;
    FLocP_LookX, FLocP_LookY, FLocP_EmotionMode: Integer;
    FLocP_AccentColor, FLocP_EyeColor, FLocP_MouthColor, FLocP_FaceColor: Integer;
    FLocP_HighlightRect, FLocP_HighlightPulse: Integer;
    FLocP_MinY, FLocP_MaxY: Integer;
    FLocC_Resolution: Integer;      // NEW: clear program uniforms
    FLocB_Resolution: Integer;      // NEW: blur program uniforms
    FLocB_Horizontal: Integer;
    FPBOs: array[0..1] of Cardinal;
    FPBOIndex: Integer;
    FPBOHasData: Boolean;
    FPBOSize: NativeInt;
    FPixelBuffer: TBytes;
    FState: TChaosState;
    FGlobalTime: Double;
    FLastTime: Double;              // NEW: for real DeltaTime tracking
    FBuildScanY, FDespawnScanY: Single;
    FMinY, FMaxY: Single;
    FChaosLevel, FMouthOpen, FEyeOpeness: Single;
    FLookX, FLookY: Single;
    FEmotionMode: TEmotionMode;
    FAccentColor, FEyeColor, FMouthColor, FFaceColor: TAlphaColor;
    FHighlightRect: TRect;
    FHighlightActive: Boolean;
    FDepthMap: FMX.Graphics.TBitmap;
    FParticleBudget: Cardinal;
    FTrailPersistence: Single;
    FScaleFactor: Single;
    FnCreateShader: PFNGLCREATESHADERPROC;
    FnDeleteShader: PFNGLDELETESHADERPROC;
    FnShaderSource: PFNGLSHADERSOURCEPROC;
    FnCompileShader: PFNGLCOMPILESHADERPROC;
    FnGetShaderiv: PFNGLGETSHADERIVPROC;
    FnGetShaderInfoLog: PFNGLGETSHADERINFOLOGPROC;
    FnCreateProgram: PFNGLCREATEPROGRAMPROC;
    FnAttachShader: PFNGLATTACHSHADERPROC;
    FnLinkProgram: PFNGLLINKPROGRAMPROC;
    FnDeleteProgram: PFNGLDELETEPROGRAMPROC;
    FnGetProgramiv: PFNGLGETPROGRAMIVPROC;
    FnGetProgramInfoLog: PFNGLGETPROGRAMINFOLOGPROC;
    FnUseProgram: PFNGLUSEPROGRAMPROC;
    FnGetUniformLocation: PFNGLGETUNIFORMLOCATIONPROC;
    FnUniform1f: PFNGLUNIFORM1FPROC;
    FnUniform2f: PFNGLUNIFORM2FPROC;
    FnUniform4f: PFNGLUNIFORM4FPROC;
    FnUniform1i: PFNGLUNIFORM1IPROC;
    FnUniform1ui: PFNGLUNIFORM1UIPROC;
    FnDispatchCompute: PFNGLDISPATCHCOMPUTEPROC;
    FnMemoryBarrier: PFNGLMEMORYBARRIERPROC;
    FnGenBuffers: PFNGLGENBUFFERSPROC;
    FnDeleteBuffers: PFNGLDELETEBUFFERSPROC;
    FnBindBuffer: PFNGLBINDBUFFERPROC;
    FnBufferData: PFNGLBUFFERDATAPROC;
    FnBufferSubData: PFNGLBUFFERSUBDATAPROC;
    FnBindBufferBase: PFNGLBINDBUFFERBASEPROC;
    FnMapBufferRange: PFNGLMAPBUFFERRANGEPROC;
    FnUnmapBuffer: PFNGLUNMAPBUFFERPROC;
    FnGenTextures: PFNGLGENTEXTURESPROC;
    FnDeleteTextures: PFNGLDELETETEXTURESPROC;
    FnBindTexture: PFNGLBINDTEXTUREPROC;
    FnTexParameteri: PFNGLTEXPARAMETERIPROC;
    FnTexStorage2D: PFNGLTEXSTORAGE2DPROC;
    FnActiveTexture: PFNGLACTIVETEXTUREPROC;
    FnBindImageTexture: PFNGLBINDIMAGETEXTUREPROC;
    FnGetTexImage: PFNGLGETTEXIMAGEPROC;
    FnCreateContextAttribs: PFNWGLCREATECONTEXTATTRIBSARBPROC;
    function InitOffscreenGL: Boolean;
    procedure CleanupOffscreenGL;
    procedure LoadGLFunctions;
    function CompileShader(AShaderType: Cardinal; const ASrc: AnsiString): Cardinal;
    function LinkProgram(const AShaders: array of Cardinal): Cardinal;
    procedure InitShaders;
    procedure InitGLResources;
    procedure EnsureOutputTexture(W, H: Integer);
    procedure GenerateFaceTargets;
    procedure UploadSSBO;
    procedure ApplyUniforms(ATime, ADeltaTime: Double);
    procedure DispatchClear;             // NEW
    procedure DispatchFrame(ADeltaTime, ATime: Double);
    procedure DispatchBlur(AHorizontal: Boolean);  // NEW
    procedure ReadbackToPixelBuffer;
    procedure ReinitParticlesForForming;           // NEW
    procedure SetMouthState(const Value: TMouthState);
    procedure SetEyeState(const Value: TEyeState);
    procedure SetEmotionMode(const Value: TEmotionMode);
  protected
    procedure RenderEffect(const ACanvas: ISkCanvas; const ADest: TRectF; const ATime: Double); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadDepthMap(const AFileName: string);
    property State: TChaosState read FState;
    property MouthState: TMouthState read FMouthState write SetMouthState;
    property EyeState: TEyeState read FEyeState write SetEyeState;
    property FaceColor: TAlphaColor read FFaceColor write FFaceColor;
    property EyeColor: TAlphaColor read FEyeColor write FEyeColor;
    property MouthColor: TAlphaColor read FMouthColor write FMouthColor;
    property AccentColor: TAlphaColor read FAccentColor write FAccentColor;
    property ChaosLevel: Single read FChaosLevel write FChaosLevel;
    property MouthOpen: Single read FMouthOpen write FMouthOpen;
    property EyeOpeness: Single read FEyeOpeness write FEyeOpeness;
    property EmotionMode: TEmotionMode read FEmotionMode write SetEmotionMode;
    property HighlightRect: TRect read FHighlightRect write FHighlightRect;
    property HighlightActive: Boolean read FHighlightActive write FHighlightActive;
    property ParticleBudget: Cardinal read FParticleBudget write FParticleBudget;
    property TrailPersistence: Single read FTrailPersistence write FTrailPersistence;
  end;

implementation

const
  { PARTICLE_SRC: per-particle update + single-pixel premultiplied splat.
    No more load+add+store (racy), no more max(added.a, 0.85) flooding alpha.
    State machine mirrors the CPU build-up:
      uState=0 Forming: particle visible only when tgt.y <= uBuildScanY.
      uState=1 Active:  hover drift around target.
      uState=2 Fading:  despawn scanline triggers gravity-fall. }
  PARTICLE_SRC: AnsiString = '#version 430 core'#10 + 'layout(local_size_x = 256) in;'#10 + 'struct Particle {'#10 + '  float px, py, pz;'#10 + '  float vx, vy, vz;'#10 + '  float tx, ty, tz;'#10 + '  uint  color;'#10 + '  uint  flags;'#10 + '  uint  pad0, pad1;'#10 + '};'#10 + 'layout(std430, binding = 0) buffer SSBO { Particle P[]; };'#10 + 'layout(rgba8, binding = 0) coherent uniform image2D uOutput;'#10 + ''#10 + 'uniform float uDeltaTime;'#10 + 'uniform float uTime;'#10 +
    'uniform vec2  uResolution;'#10 + 'uniform uint  uParticleCount;'#10 + 'uniform float uBuildScanY;'#10 + 'uniform float uDespawnScanY;'#10 + 'uniform int   uState;'#10 + 'uniform float uChaosLevel;'#10 + 'uniform float uMouthOpen;'#10 + 'uniform float uEyeOpeness;'#10 + 'uniform float uLookX;'#10 + 'uniform float uLookY;'#10 + 'uniform int   uEmotionMode;'#10 + 'uniform vec4  uFaceColor;'#10 + 'uniform vec4  uEyeColor;'#10 + 'uniform vec4  uMouthColor;'#10 + 'uniform vec4  uAccentColor;'#10 + ''#10 +
    'vec2 project3D(vec3 p) {'#10 + '  float rotY = -uLookX * 0.4;'#10 + '  float x = p.x * cos(rotY) - p.z * sin(rotY);'#10 + '  float z = p.x * sin(rotY) + p.z * cos(rotY);'#10 + '  float rotX = -uLookY * 0.18;'#10 + '  float y = p.y * cos(rotX) - z * sin(rotX);'#10 + '  float persp = 1.0 + (z * 0.0022);'#10 + '  return vec2(x * persp, y * persp + 15.0);'#10 + '}'#10 + ''#10 + 'vec2 toScreenFloat(vec2 p2) {'#10 + '  return vec2(p2.x + uResolution.x * 0.5,'#10 +
    '              p2.y + uResolution.y * 0.5);'#10 + '}'#10 + ''#10 + 'float rand(float s) {'#10 + '  return fract(sin(s * 12.9898) * 43758.5453);'#10 + '}'#10 + ''#10 + 'void main() {'#10 + '  uint idx = gl_GlobalInvocationID.y * (gl_NumWorkGroups.x * 256u) + gl_GlobalInvocationID.x;'#10 + '  if (idx >= uParticleCount) return;'#10 + '  float dt = clamp(uDeltaTime, 0.0, 0.033);'#10 + '  uint flags = P[idx].flags;'#10 + '  vec3 pos = vec3(P[idx].px, P[idx].py, P[idx].pz);'#10 +
    '  vec3 vel = vec3(P[idx].vx, P[idx].vy, P[idx].vz);'#10 + '  vec3 tgt = vec3(P[idx].tx, P[idx].ty, P[idx].tz);'#10 + '  bool visible = true;'#10 + '  bool falling = false;'#10 + '  if (uState == 0) {'#10 + '    if (tgt.y > uBuildScanY) visible = false;'#10 + '  } else if (uState == 2) {'#10 + '    if (pos.y <= uDespawnScanY) {'#10 + '      if (vel.y < 1.0) vel.y = 150.0 + 100.0 * rand(float(idx));'#10 + '      falling = true;'#10 + '    }'#10 + '  }'#10 + '  if (falling) {'#10 +
    '    vel.y += 500.0 * dt;'#10 + '    pos += vel * dt;'#10 + '  } else if (visible) {'#10 + '    vec3 d = tgt - pos;'#10 + '    float stiff = 220.0;'#10 + '    float damp = 18.0;'#10 + '    vel += (d * stiff - vel * damp) * dt;'#10 + '    pos += vel * dt;'#10 + '    if (uState == 1) {'#10 + '      vec3 hover = vec3(sin(uTime * 1.3 + float(idx) * 0.37),'#10 + '                        cos(uTime * 1.1 + float(idx) * 0.53), 0.0) * 0.4;'#10 + '      pos += hover * dt;'#10 + '    }'#10 + '  }'#10 +
    '  P[idx].px = pos.x; P[idx].py = pos.y; P[idx].pz = pos.z;'#10 + '  P[idx].vx = vel.x; P[idx].vy = vel.y; P[idx].vz = vel.z;'#10 + '  if (!visible) return;'#10 + ''#10 + '  // Augen- und Mundringe ausduennen, damit einzelne Leuchtpunkte entstehen'#10 + '  if ((flags == 2u || flags == 3u || flags == 4u) && ((idx % 2u) != 0u)) return;'#10 + ''#10 + '  vec2 p2 = project3D(pos);'#10 + '  vec2 center = toScreenFloat(p2);'#10 + '  ivec2 basePx = ivec2(round(center));'#10 +
    '  int resX = int(uResolution.x);'#10 + '  int resY = int(uResolution.y);'#10 + '  if (basePx.x < -5 || basePx.x >= resX + 5 ||'#10 + '      basePx.y < -5 || basePx.y >= resY + 5) return;'#10 + ''#10 + '  float rawDepth = clamp(pos.z / 110.0, 0.0, 1.0);'#10 + '  float depth = pow(rawDepth, 1.8);'#10 + '  float radialFade = clamp(1.0 - length(pos.xy) * 0.0045, 0.35, 1.0);'#10 + ''#10 + '  vec4 col;'#10 + '  float typeBoost = 1.0;'#10 + '  float coreRadius = mix(0.75, 1.35, depth);'#10 +
    '  float glowRadius = mix(2.2, 3.8, depth);'#10 + ''#10 + '  if (flags == 2u || flags == 3u) {'#10 + '    col = uEyeColor;'#10 + '    typeBoost = 0.90;'#10 + '    depth = 0.78;'#10 + '    coreRadius = 0.95;'#10 + '    glowRadius = 2.8;'#10 + '  } else if (flags == 4u) {'#10 + '    col = uMouthColor;'#10 + '    typeBoost = 0.90;'#10 + '    depth = 0.75;'#10 + '    coreRadius = 0.90;'#10 + '    glowRadius = 2.6;'#10 + '  } else {'#10 + '    col = uFaceColor;'#10 + '    typeBoost = 1.0;'#10 + '  }'#10 +
    ''#10 + '  float flick = 0.90 + 0.10 * sin(uTime * 14.0 + float(idx) * 1.31);'#10 + '  float baseIntensity = mix(0.14, 1.05, depth) * radialFade * flick * typeBoost;'#10 + ''#10 + '  for (int dy = -4; dy <= 4; ++dy) {'#10 + '    for (int dx = -4; dx <= 4; ++dx) {'#10 + '      ivec2 px = basePx + ivec2(dx, dy);'#10 + '      if (px.x < 0 || px.x >= resX || px.y < 0 || px.y >= resY) continue;'#10 + '      float dist = length(vec2(px) + 0.5 - center);'#10 + '      if (dist > glowRadius) continue;'#10 +
    '      float core = exp(-(dist * dist) / (coreRadius * coreRadius));'#10 + '      float glow = exp(-(dist * dist) / (glowRadius * glowRadius * 0.4)) * 0.35;'#10 + '      float a = clamp((core + glow) * baseIntensity, 0.0, 1.0);'#10 + '      if (a <= 0.004) continue;'#10 + '      // Strenges Premultiplied Alpha (rgb <= a) fuer saubere Desktop-Transparenz'#10 + '      vec4 src = vec4(col.rgb * a, a);'#10 + '      vec4 dst = imageLoad(uOutput, px);'#10 + '      float outA = clamp(max(dst.a, src.a) + min(dst.a, src.a) * 0.25, 0.0, 1.0);'#10 + '      vec3 outRGB = clamp(max(dst.rgb, src.rgb) + min(dst.rgb, src.rgb) * 0.25, 0.0, outA);'#10 + '      imageStore(uOutput, px, vec4(outRGB, outA));'#10 + '    }'#10 + '  }'#10 + '}';
  CLEAR_SRC: AnsiString = '#version 430 core'#10 + 'layout(local_size_x = 16, local_size_y = 16) in;'#10 + 'layout(rgba8, binding = 0) writeonly uniform image2D uOutput;'#10 + 'uniform vec2 uResolution;'#10 + 'void main() {'#10 + '  ivec2 px = ivec2(gl_GlobalInvocationID.xy);'#10 + '  if (px.x >= int(uResolution.x) || px.y >= int(uResolution.y)) return;'#10 + '  imageStore(uOutput, px, vec4(0.0));'#10 + '}';
  BLUR_SRC: AnsiString = '#version 430 core'#10 + 'layout(local_size_x = 16, local_size_y = 16) in;'#10 + 'layout(rgba8, binding = 0) readonly  uniform image2D uInput;'#10 + 'layout(rgba8, binding = 1) writeonly uniform image2D uOutput;'#10 + 'uniform vec2 uResolution;'#10 + 'uniform int   uHorizontal;'#10 + 'void main() {'#10 + '  ivec2 px = ivec2(gl_GlobalInvocationID.xy);'#10 + '  if (px.x >= int(uResolution.x) || px.y >= int(uResolution.y)) return;'#10 + '  const int RADIUS = 2;'#10 +
    '  const float SIGMA = 1.2;'#10 + '  vec4 centerCol = imageLoad(uInput, px);'#10 + '  vec4 sum = vec4(0.0);'#10 + '  float wsum = 0.0;'#10 + '  for (int i = -RADIUS; i <= RADIUS; ++i) {'#10 + '    float w = exp(-float(i*i) / (2.0 * SIGMA * SIGMA));'#10 + '    ivec2 sp = px;'#10 + '    if (uHorizontal == 1) sp.x += i; else sp.y += i;'#10 + '    if (sp.x < 0 || sp.x >= int(uResolution.x) ||'#10 + '        sp.y < 0 || sp.y >= int(uResolution.y)) continue;'#10 + '    sum += imageLoad(uInput, sp) * w;'#10 +
    '    wsum += w;'#10 + '  }'#10 + '  vec4 blurred = sum / wsum;'#10 + '  float outA = clamp(max(centerCol.a, blurred.a * 1.15), 0.0, 1.0);'#10 + '  vec3 outRGB = clamp(max(centerCol.rgb, blurred.rgb * 1.15), 0.0, outA);'#10 + '  imageStore(uOutput, px, vec4(outRGB, outA));'#10 + '}';


//==============================================================================
// Construct / Destroy
//==============================================================================
constructor TSkChaos.Create(AOwner: TComponent);
var
  ExePath, DepthFile: string;
begin
  inherited Create(AOwner);
  Width := CHAOS_WIDTH;
  Height := CHAOS_HEIGHT;
  FState := csIdle;
  FScaleFactor := 0.75;   // match CPU original (was 0.45)
  FMouthOpen := 0.15;
  FEyeOpeness := 1.0;
  FEmotionMode := emNeutral;
  FAccentColor := $FF00BFFF;
  FFaceColor := $FF00BFFF;
  FEyeColor := $FF00BFFF;
  FMouthColor := $FF00BFFF;
  FMouthState := msMin;
  FEyeState := esOpen;
  FHighlightRect := Rect(-1, -1, -1, -1);
  FHighlightActive := False;
  FParticleBudget := DEFAULT_PARTICLE_BUDGET;
  FTrailPersistence := 0.85;   // kept for API compat; no longer used as decay
  FChaosLevel := 0.0;          // 0 = no drift (matches CPU look)
  FParticleCount := 0;
  FPBOIndex := 0;
  FPBOHasData := False;
  FGLReady := False;
  FGLFailed := False;
  FDepthMap := nil;
  FLastTime := 0;
  FTempTex := 0;
  FClearProgram := 0;
  FBlurProgram := 0;
  ExePath := ExtractFilePath(ParamStr(0));
  DepthFile := ExePath + 'depthmap.png';
  if FileExists(DepthFile) then
    LoadDepthMap(DepthFile);
end;

destructor TSkChaos.Destroy;
begin
  inherited;
  FreeAndNil(FDepthMap);
end;

procedure TSkChaos.LoadDepthMap(const AFileName: string);
begin
  FreeAndNil(FDepthMap);
  if not FileExists(AFileName) then
    Exit;
  FDepthMap := FMX.Graphics.TBitmap.Create;
  try
    FDepthMap.LoadFromFile(AFileName);
  except
    FreeAndNil(FDepthMap);
  end;
end;
//==============================================================================
// GL Setup
//==============================================================================

function TSkChaos.InitOffscreenGL: Boolean;
var
  PFD: TPixelFormatDescriptor;
  PixFmt: Integer;
  WndClass: TWndClassW;
  Attribs: array[0..4] of Integer;
  DC: HDC;
begin
  Result := False;
  if FGLReady then
    Exit(True);
  if FGLFailed then
    Exit(False);
  FillChar(WndClass, SizeOf(WndClass), 0);
  WndClass.lpfnWndProc := @DefWindowProcW;
  WndClass.hInstance := HInstance;
  WndClass.lpszClassName := 'ChaosGPUOffscreen';
  RegisterClassW(WndClass);
  FDummyWnd := CreateWindowExW(0, WndClass.lpszClassName, '', WS_POPUP, 0, 0, 16, 16, 0, 0, HInstance, nil);
  if FDummyWnd = 0 then
  begin
    FGLFailed := True;
    Exit;
  end;
  FDummyDC := GetDC(FDummyWnd);
  ZeroMemory(@PFD, SizeOf(PFD));
  PFD.nSize := SizeOf(PFD);
  PFD.nVersion := 1;
  PFD.dwFlags := PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER;
  PFD.iPixelType := PFD_TYPE_RGBA;
  PFD.cColorBits := 32;
  PFD.cAlphaBits := 8;
  PixFmt := ChoosePixelFormat(FDummyDC, @PFD);
  if PixFmt = 0 then
  begin
    FGLFailed := True;
    Exit;
  end;
  SetPixelFormat(FDummyDC, PixFmt, @PFD);
  FGLContext := wglCreateContext(FDummyDC);
  if FGLContext = 0 then
  begin
    FGLFailed := True;
    Exit;
  end;
  wglMakeCurrent(FDummyDC, FGLContext);
  LoadGLFunctions;
  if not Assigned(FnCreateContextAttribs) then
  begin
    FGLFailed := True;
    Exit;
  end;
  Attribs[0] := WGL_CONTEXT_MAJOR_VERSION_ARB;
  Attribs[1] := 4;
  Attribs[2] := WGL_CONTEXT_MINOR_VERSION_ARB;
  Attribs[3] := 3;
  Attribs[4] := 0;
  DC := FDummyDC;
  wglMakeCurrent(0, 0);
  wglDeleteContext(FGLContext);
  FGLContext := FnCreateContextAttribs(DC, 0, @Attribs[0]);
  if FGLContext = 0 then
  begin
    FGLFailed := True;
    Exit;
  end;
  wglMakeCurrent(DC, FGLContext);
  InitShaders;
  InitGLResources;
  FGLReady := True;
  Result := True;
end;

procedure TSkChaos.CleanupOffscreenGL;
begin
  if FGLContext <> 0 then
  begin
    wglMakeCurrent(0, 0);
    wglDeleteContext(FGLContext);
    FGLContext := 0;
  end;
  if FDummyDC <> 0 then
  begin
    ReleaseDC(FDummyWnd, FDummyDC);
    FDummyDC := 0;
  end;
  if FDummyWnd <> 0 then
  begin
    DestroyWindow(FDummyWnd);
    FDummyWnd := 0;
  end;
  FGLReady := False;
end;

procedure TSkChaos.LoadGLFunctions;

  function GetProc(const Name: AnsiString): Pointer;
  begin
    Result := wglGetProcAddress(PAnsiChar(Name));
    if (Result = nil) or (NativeUInt(Result) <= 3) or (NativeUInt(Result) = NativeUInt(-1)) then
      Result := GetProcAddress(GetModuleHandle('opengl32.dll'), PAnsiChar(Name));
  end;

begin
  FnCreateShader := GetProc('glCreateShader');
  FnDeleteShader := GetProc('glDeleteShader');
  FnShaderSource := GetProc('glShaderSource');
  FnCompileShader := GetProc('glCompileShader');
  FnGetShaderiv := GetProc('glGetShaderiv');
  FnGetShaderInfoLog := GetProc('glGetShaderInfoLog');
  FnCreateProgram := GetProc('glCreateProgram');
  FnAttachShader := GetProc('glAttachShader');
  FnLinkProgram := GetProc('glLinkProgram');
  FnDeleteProgram := GetProc('glDeleteProgram');
  FnGetProgramiv := GetProc('glGetProgramiv');
  FnGetProgramInfoLog := GetProc('glGetProgramInfoLog');
  FnUseProgram := GetProc('glUseProgram');
  FnGetUniformLocation := GetProc('glGetUniformLocation');
  FnUniform1f := GetProc('glUniform1f');
  FnUniform2f := GetProc('glUniform2f');
  FnUniform4f := GetProc('glUniform4f');
  FnUniform1i := GetProc('glUniform1i');
  FnUniform1ui := GetProc('glUniform1ui');
  FnDispatchCompute := GetProc('glDispatchCompute');
  FnMemoryBarrier := GetProc('glMemoryBarrier');
  FnGenBuffers := GetProc('glGenBuffers');
  FnDeleteBuffers := GetProc('glDeleteBuffers');
  FnBindBuffer := GetProc('glBindBuffer');
  FnBufferData := GetProc('glBufferData');
  FnBufferSubData := GetProc('glBufferSubData');
  FnBindBufferBase := GetProc('glBindBufferBase');
  FnMapBufferRange := GetProc('glMapBufferRange');
  FnUnmapBuffer := GetProc('glUnmapBuffer');
  FnGenTextures := GetProc('glGenTextures');
  FnDeleteTextures := GetProc('glDeleteTextures');
  FnBindTexture := GetProc('glBindTexture');
  FnTexParameteri := GetProc('glTexParameteri');
  FnTexStorage2D := GetProc('glTexStorage2D');
  FnActiveTexture := GetProc('glActiveTexture');
  FnBindImageTexture := GetProc('glBindImageTexture');
  FnGetTexImage := GetProc('glGetTexImage');
  FnCreateContextAttribs := GetProc('wglCreateContextAttribsARB');
  if not Assigned(FnDispatchCompute) or not Assigned(FnBindImageTexture) then
    raise Exception.Create('OpenGL 4.3 Compute Shaders nicht verfuegbar');
end;

function TSkChaos.CompileShader(AShaderType: Cardinal; const ASrc: AnsiString): Cardinal;
var
  SrcPtr: PAnsiChar;
  Len, Status, LogLen: Integer;
  Log: AnsiString;
begin
  Result := FnCreateShader(AShaderType);
  SrcPtr := PAnsiChar(ASrc);
  Len := Length(ASrc);
  FnShaderSource(Result, 1, @SrcPtr, @Len);
  FnCompileShader(Result);
  FnGetShaderiv(Result, GL_COMPILE_STATUS, @Status);
  if Status = 0 then
  begin
    FnGetShaderiv(Result, GL_INFO_LOG_LENGTH, @LogLen);
    SetLength(Log, LogLen);
    if LogLen > 0 then
      FnGetShaderInfoLog(Result, LogLen, nil, PAnsiChar(Log));
    FnDeleteShader(Result);
    raise Exception.Create('Shader compile error: ' + string(Log));
  end;
end;

function TSkChaos.LinkProgram(const AShaders: array of Cardinal): Cardinal;
var
  I, Status, LogLen: Integer;
  Log: AnsiString;
begin
  Result := FnCreateProgram;
  for I := Low(AShaders) to High(AShaders) do
    FnAttachShader(Result, AShaders[I]);
  FnLinkProgram(Result);
  FnGetProgramiv(Result, GL_LINK_STATUS, @Status);
  if Status = 0 then
  begin
    FnGetProgramiv(Result, GL_INFO_LOG_LENGTH, @LogLen);
    SetLength(Log, LogLen);
    if LogLen > 0 then
      FnGetProgramInfoLog(Result, LogLen, nil, PAnsiChar(Log));
    FnDeleteProgram(Result);
    raise Exception.Create('Program link error: ' + string(Log));
  end;
  for I := Low(AShaders) to High(AShaders) do
    FnDeleteShader(AShaders[I]);
end;

procedure TSkChaos.InitShaders;
var
  PS, CS, BS: Cardinal;
begin
  PS := CompileShader(GL_COMPUTE_SHADER, PARTICLE_SRC);
  CS := CompileShader(GL_COMPUTE_SHADER, CLEAR_SRC);
  BS := CompileShader(GL_COMPUTE_SHADER, BLUR_SRC);
  FParticleProgram := LinkProgram([PS]);
  FClearProgram := LinkProgram([CS]);
  FBlurProgram := LinkProgram([BS]);
  FnUseProgram(FParticleProgram);
  FLocP_DeltaTime := FnGetUniformLocation(FParticleProgram, 'uDeltaTime');
  FLocP_Time := FnGetUniformLocation(FParticleProgram, 'uTime');
  FLocP_Resolution := FnGetUniformLocation(FParticleProgram, 'uResolution');
  FLocP_ParticleCount := FnGetUniformLocation(FParticleProgram, 'uParticleCount');
  FLocP_BuildScanY := FnGetUniformLocation(FParticleProgram, 'uBuildScanY');
  FLocP_DespawnScanY := FnGetUniformLocation(FParticleProgram, 'uDespawnScanY');
  FLocP_State := FnGetUniformLocation(FParticleProgram, 'uState');
  FLocP_ChaosLevel := FnGetUniformLocation(FParticleProgram, 'uChaosLevel');
  FLocP_MouthOpen := FnGetUniformLocation(FParticleProgram, 'uMouthOpen');
  FLocP_EyeOpeness := FnGetUniformLocation(FParticleProgram, 'uEyeOpeness');
  FLocP_LookX := FnGetUniformLocation(FParticleProgram, 'uLookX');
  FLocP_LookY := FnGetUniformLocation(FParticleProgram, 'uLookY');
  FLocP_EmotionMode := FnGetUniformLocation(FParticleProgram, 'uEmotionMode');
  FLocP_FaceColor := FnGetUniformLocation(FParticleProgram, 'uFaceColor');
  FLocP_EyeColor := FnGetUniformLocation(FParticleProgram, 'uEyeColor');
  FLocP_MouthColor := FnGetUniformLocation(FParticleProgram, 'uMouthColor');
  FLocP_AccentColor := FnGetUniformLocation(FParticleProgram, 'uAccentColor');
  FLocP_HighlightRect := FnGetUniformLocation(FParticleProgram, 'uHighlightRect');
  FLocP_HighlightPulse := FnGetUniformLocation(FParticleProgram, 'uHighlightPulse');
  FLocP_MinY := FnGetUniformLocation(FParticleProgram, 'uMinY');
  FLocP_MaxY := FnGetUniformLocation(FParticleProgram, 'uMaxY');
  FnUseProgram(FClearProgram);
  FLocC_Resolution := FnGetUniformLocation(FClearProgram, 'uResolution');
  FnUseProgram(FBlurProgram);
  FLocB_Resolution := FnGetUniformLocation(FBlurProgram, 'uResolution');
  FLocB_Horizontal := FnGetUniformLocation(FBlurProgram, 'uHorizontal');
  FnUseProgram(0);
end;

procedure TSkChaos.InitGLResources;
var
  SSBOSize: NativeInt;
begin
  FnGenBuffers(1, @FParticleSSBO);
  SSBOSize := NativeInt(PARTICLE_MAX) * SSBO_PARTICLE_SIZE;
  FnBindBuffer(GL_SHADER_STORAGE_BUFFER, FParticleSSBO);
  FnBufferData(GL_SHADER_STORAGE_BUFFER, SSBOSize, nil, GL_DYNAMIC_COPY);
  FnBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
  SetLength(FParticleCPU, SSBOSize);
  FillChar(FParticleCPU[0], SSBOSize, 0);
end;

procedure TSkChaos.EnsureOutputTexture(W, H: Integer);
var
  I: Integer;

  procedure SetupTex(Tex: Cardinal);
  begin
    FnBindTexture(GL_TEXTURE_2D, Tex);
    FnTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    FnTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    FnTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    FnTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    FnTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, W, H);
  end;

begin
  if FOutputTex <> 0 then
    FnDeleteTextures(1, @FOutputTex);
  if FTempTex <> 0 then
    FnDeleteTextures(1, @FTempTex);
  FnGenTextures(1, @FOutputTex);
  FnGenTextures(1, @FTempTex);
  SetupTex(FOutputTex);
  SetupTex(FTempTex);
  SetLength(FPixelBuffer, W * H * 4);
  FillChar(FPixelBuffer[0], Length(FPixelBuffer), 0);
  FPBOSize := W * H * 4;
  for I := 0 to 1 do
    if FPBOs[I] <> 0 then
      FnDeleteBuffers(1, @FPBOs[I]);
  FnGenBuffers(2, @FPBOs[0]);
  for I := 0 to 1 do
  begin
    FnBindBuffer(GL_PIXEL_PACK_BUFFER, FPBOs[I]);
    FnBufferData(GL_PIXEL_PACK_BUFFER, FPBOSize, nil, GL_STREAM_READ);
  end;
  FnBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
  FPBOIndex := 0;
  FPBOHasData := False;
end;
//==============================================================================
// Face-Targets
//==============================================================================

procedure TSkChaos.GenerateFaceTargets;
var
  X, Y, Step, OffsetY, Idx, BudgetUsed: Integer;
  BitmapData: FMX.Graphics.TBitmapData;
  PixelColor: TAlphaColor;
  R: Byte;
  Helligkeit: Single;
  P: ^TParticleCPU;
  CenterX, CenterY: Single;
  DepthW, DepthH: Integer;

  procedure AddParticle(AFlag: Cardinal; AX, AY, AZ: Single);
  begin
    if BudgetUsed >= Integer(FParticleBudget) then
      Exit;
    P := @FParticleCPU[BudgetUsed * SSBO_PARTICLE_SIZE];
    FillChar(P^, SSBO_PARTICLE_SIZE, 0);
    P.PX := AX;
    P.PY := AY;
    P.PZ := AZ;
    P.TX := AX;
    P.TY := AY;
    P.TZ := AZ;
    P.Color := $FF00BFFF;
    P.Flags := AFlag;
    Inc(BudgetUsed);
  end;

  function GetPixel(X, Y: Integer): TAlphaColor;
  var
    PixPtr: PCardinal;
  begin
    PixPtr := PCardinal(PByte(BitmapData.Data) + (Y * BitmapData.Pitch) + (X * 4));
    Result := PixPtr^;
  end;

begin
  if not Assigned(FDepthMap) then
    Exit;
  if not FDepthMap.Map(TMapAccess.Read, BitmapData) then
    Exit;
  try
    DepthW := FDepthMap.Width;
    DepthH := FDepthMap.Height;
    BudgetUsed := 0;
    CenterX := DepthW / 2;
    CenterY := (DepthH - 28) / 2;
    FMinY := 10000;
    FMaxY := -10000;
    Step := DEPTH_MAP_STEP;
    OffsetY := 28;
    for Y := OffsetY to DepthH - 1 do
    begin
      if ((Y - OffsetY) mod Step) <> 0 then
        Continue;
      for X := 0 to DepthW - 1 do
      begin
        if (X mod Step) <> 0 then
          Continue;
        PixelColor := GetPixel(X, Y);
        R := (PixelColor shr 16) and $FF;
        if R > 5 then
        begin
          Helligkeit := R / 255.0;
          AddParticle(1, (X - CenterX) * FScaleFactor, ((Y - OffsetY) - CenterY) * FScaleFactor, Helligkeit * 112.5);
          if P.PY < FMinY then
            FMinY := P.PY;
          if P.PY > FMaxY then
            FMaxY := P.PY;
        end;
      end;
    end;
    for Idx := 0 to 49 do
      AddParticle(2, (-45 + Cos((Idx / 50) * 2 * Pi) * 22), (-50 + Sin((Idx / 50) * 2 * Pi) * 8), 40.0);
    for Idx := 0 to 49 do
      AddParticle(3, (45 + Cos((Idx / 50) * 2 * Pi) * 22), (-50 + Sin((Idx / 50) * 2 * Pi) * 8), 40.0);
    for Idx := 0 to 39 do
      AddParticle(4, Cos((Idx / 40) * 2 * Pi) * 35, (65 + Sin((Idx / 40) * 2 * Pi) * 4), 35.0);
    FParticleCount := BudgetUsed;
  finally
    FDepthMap.Unmap(BitmapData);
  end;
end;

procedure TSkChaos.UploadSSBO;
begin
  if FParticleSSBO = 0 then
    Exit;
  FnBindBuffer(GL_SHADER_STORAGE_BUFFER, FParticleSSBO);
  FnBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, NativeInt(FParticleCount) * SSBO_PARTICLE_SIZE, @FParticleCPU[0]);
  FnBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
end;

procedure TSkChaos.ReinitParticlesForForming;
var
  I: Integer;
  P: ^TParticleCPU;
begin
  // Scatter every particle to a random start offset near the vertical centre
  // so the forming animation lerps them toward their target (zoom-in effect
  // matching the CPU version's "Pos3D := Target + Random(30)-15, -15+Random(15)").
  for I := 0 to Integer(FParticleCount) - 1 do
  begin
    P := @FParticleCPU[I * SSBO_PARTICLE_SIZE];
    P^.PX := P^.TX + (Random(30) - 15);
    P^.PY := -15 + Random(15);
    P^.PZ := P^.TZ;
    P^.VX := 0;
    P^.VY := 0;
    P^.VZ := 0;
  end;
  UploadSSBO;
end;
//==============================================================================
// Uniforms / Dispatch
//==============================================================================

procedure ColorToVec4(C: TAlphaColor; out R, G, B, A: Single);
begin
  R := (C shr 16 and $FF) / 255;
  G := (C shr 8 and $FF) / 255;
  B := (C and $FF) / 255;
  A := (C shr 24 and $FF) / 255;
end;

procedure TSkChaos.ApplyUniforms(ATime, ADeltaTime: Double);
var
  R, G, B, A: Single;
  StateInt, OrdEmo: Integer;
begin
  FnUseProgram(FParticleProgram);
  case FState of
    csForming:
      StateInt := 0;
    csActive:
      StateInt := 1;
    csFading:
      StateInt := 2;
  else
    StateInt := 0;
  end;
  FnUniform1f(FLocP_DeltaTime, ADeltaTime);
  FnUniform1f(FLocP_Time, ATime);
  FnUniform2f(FLocP_Resolution, CHAOS_WIDTH, CHAOS_HEIGHT);
  FnUniform1ui(FLocP_ParticleCount, FParticleCount);
  FnUniform1f(FLocP_BuildScanY, FBuildScanY);
  FnUniform1f(FLocP_DespawnScanY, FDespawnScanY);
  FnUniform1i(FLocP_State, StateInt);
  FnUniform1f(FLocP_ChaosLevel, FChaosLevel);
  FnUniform1f(FLocP_MouthOpen, FMouthOpen);
  FnUniform1f(FLocP_EyeOpeness, FEyeOpeness);
  FnUniform1f(FLocP_LookX, FLookX);
  FnUniform1f(FLocP_LookY, FLookY);
  OrdEmo := Ord(FEmotionMode);
  FnUniform1i(FLocP_EmotionMode, OrdEmo);
  ColorToVec4(FFaceColor, R, G, B, A);
  FnUniform4f(FLocP_FaceColor, R, G, B, A);
  ColorToVec4(FEyeColor, R, G, B, A);
  FnUniform4f(FLocP_EyeColor, R, G, B, A);
  ColorToVec4(FMouthColor, R, G, B, A);
  FnUniform4f(FLocP_MouthColor, R, G, B, A);
  ColorToVec4(FAccentColor, R, G, B, A);
  FnUniform4f(FLocP_AccentColor, R, G, B, A);
end;

procedure TSkChaos.DispatchClear;
var
  GX, GY: Cardinal;
begin
  FnUseProgram(FClearProgram);
  FnUniform2f(FLocC_Resolution, CHAOS_WIDTH, CHAOS_HEIGHT);
  FnBindImageTexture(0, FOutputTex, 0, 0, 0, GL_WRITE_ONLY, GL_RGBA8);
  GX := (Cardinal(CHAOS_WIDTH) + 15) div 16;
  GY := (Cardinal(CHAOS_HEIGHT) + 15) div 16;
  FnDispatchCompute(GX, GY, 1);
  FnMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
  FnUseProgram(0);
end;

procedure TSkChaos.DispatchFrame(ADeltaTime, ATime: Double);
var
  TotalGroups, GX, GY: Cardinal;
begin
  FnUseProgram(FParticleProgram);
  ApplyUniforms(ATime, ADeltaTime);
  FnBindImageTexture(0, FOutputTex, 0, 0, 0, GL_READ_WRITE, GL_RGBA8);
  FnBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, FParticleSSBO);
  TotalGroups := (FParticleCount + 255) div 256;
  GX := TotalGroups;
  GY := 1;
  if GX > 65535 then
  begin
    GX := 65535;
    GY := (TotalGroups + 65534) div 65535;
  end;
  FnDispatchCompute(GX, GY, 1);
  FnMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT or GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
  FnUseProgram(0);
end;

procedure TSkChaos.DispatchBlur(AHorizontal: Boolean);
var
  GX, GY, InputTex, OutputTex: Cardinal;
begin
  FnUseProgram(FBlurProgram);
  FnUniform2f(FLocB_Resolution, CHAOS_WIDTH, CHAOS_HEIGHT);
  if AHorizontal then
  begin
    FnUniform1i(FLocB_Horizontal, 1);
    InputTex := FOutputTex;
    OutputTex := FTempTex;
  end
  else
  begin
    FnUniform1i(FLocB_Horizontal, 0);
    InputTex := FTempTex;
    OutputTex := FOutputTex;
  end;
  FnBindImageTexture(0, InputTex, 0, 0, 0, GL_READ_ONLY, GL_RGBA8);
  FnBindImageTexture(1, OutputTex, 0, 0, 0, GL_WRITE_ONLY, GL_RGBA8);
  GX := (Cardinal(CHAOS_WIDTH) + 15) div 16;
  GY := (Cardinal(CHAOS_HEIGHT) + 15) div 16;
  FnDispatchCompute(GX, GY, 1);
  FnMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
  FnUseProgram(0);
end;

procedure TSkChaos.ReadbackToPixelBuffer;
var
  ReadPBO, WritePBO: Cardinal;
  Mapped: Pointer;
begin
  if FPBOHasData then
  begin
    ReadPBO := FPBOs[FPBOIndex xor 1];
    FnBindBuffer(GL_PIXEL_PACK_BUFFER, ReadPBO);
    Mapped := FnMapBufferRange(GL_PIXEL_PACK_BUFFER, 0, FPBOSize, GL_MAP_READ_BIT);
    if Mapped <> nil then
    begin
      System.Move(Mapped^, Pointer(FPixelBuffer)^, FPBOSize);
      FnUnmapBuffer(GL_PIXEL_PACK_BUFFER);
    end;
    FnBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
  end;
  WritePBO := FPBOs[FPBOIndex];
  FnBindBuffer(GL_PIXEL_PACK_BUFFER, WritePBO);
  FnBindTexture(GL_TEXTURE_2D, FOutputTex);
  FnGetTexImage(GL_TEXTURE_2D, 0, GL_BGRA, GL_UNSIGNED_BYTE, nil);
  FnBindTexture(GL_TEXTURE_2D, 0);
  FnBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
  FPBOIndex := FPBOIndex xor 1;
  FPBOHasData := True;
end;
//==============================================================================
// RenderEffect
//==============================================================================

procedure TSkChaos.RenderEffect(const ACanvas: ISkCanvas; const ADest: TRectF; const ATime: Double);
var
  ImgInfo: TSkImageInfo;
  GPUImg: ISkImage;
  DeltaTime: Double;
  ScanSpeed: Single;
begin
  if not Active then
  begin
    inherited RenderEffect(ACanvas, ADest, ATime);
    Exit;
  end;
  if not FGLReady then
  begin
    wglMakeCurrent(0, 0);
    if not InitOffscreenGL then
      Exit;
    EnsureOutputTexture(CHAOS_WIDTH, CHAOS_HEIGHT);
    GenerateFaceTargets;
    UploadSSBO;
    FLastTime := 0;
  end;
  wglMakeCurrent(FDummyDC, FGLContext);

  // Real DeltaTime from the monotonic ATime the base thread passes in.
  if FLastTime = 0 then
    DeltaTime := 1.0 / 60.0
  else
    DeltaTime := ATime - FLastTime;
  FLastTime := ATime;
  if (DeltaTime <= 0) or (DeltaTime > 0.25) then
    DeltaTime := 1.0 / 60.0;

  FGlobalTime := ATime;

  // First activation: kick off the forming animation.
  if FState = csIdle then
  begin
    ReinitParticlesForForming;
    FState := csForming;
    FBuildScanY := FMinY;
    FDespawnScanY := FMinY;
  end;

  // Advance the build-up scanline; transition to Active when it passed the
  // lowest particle. Matches CPU BUILD_TIME = 1.5s.
  if FState = csForming then
  begin
    ScanSpeed := (FMaxY - FMinY + 50) / 1.5;
    FBuildScanY := FBuildScanY + ScanSpeed * DeltaTime;
    if FBuildScanY >= FMaxY + 50 then
      FState := csActive;
  end;

  // Per-frame pipeline: clear -> particles -> blur H -> blur V -> readback.
  DispatchClear;
  DispatchFrame(DeltaTime, ATime);
 // DispatchBlur(True);    // output -> temp
 // DispatchBlur(False);   // temp   -> output
  ReadbackToPixelBuffer;

  ACanvas.Clear($00000000);
  if FPBOHasData and (Length(FPixelBuffer) > 0) then
  begin
    ImgInfo := TSkImageInfo.Create(CHAOS_WIDTH, CHAOS_HEIGHT, TSkColorType.BGRA8888, TSkAlphaType.Premul);
    GPUImg := TSkImage.MakeFromRaster(ImgInfo, PByte(FPixelBuffer), CHAOS_WIDTH * 4);
    if Assigned(GPUImg) then
      ACanvas.DrawImageRect(GPUImg, RectF(0, 0, CHAOS_WIDTH, CHAOS_HEIGHT), RectF(0, 0, CHAOS_WIDTH, CHAOS_HEIGHT), TSkSamplingOptions.Medium);
  end;
end;
//==============================================================================
// Properties
//==============================================================================

procedure TSkChaos.SetMouthState(const Value: TMouthState);
begin
  FMouthState := Value;
  case Value of
    msClosed:
      FMouthOpen := 0.0;
    msMin:
      FMouthOpen := 0.15;
    msMid:
      FMouthOpen := 0.55;
    msFull:
      FMouthOpen := 1.0;
  end;
end;

procedure TSkChaos.SetEyeState(const Value: TEyeState);
begin
  FEyeState := Value;
  case Value of
    esOpen:
      FEyeOpeness := 1.0;
    esMid:
      FEyeOpeness := 0.4;
    esClosed:
      FEyeOpeness := 0.05;
  end;
end;

procedure TSkChaos.SetEmotionMode(const Value: TEmotionMode);
begin
  FEmotionMode := Value;
  case Value of
    emAlert:
      FAccentColor := $FFFF4040;
    emHappy:
      FAccentColor := $FF40FF80;
    emThinking:
      FAccentColor := $FFC040FF;
  else
    FAccentColor := $FF00BFFF;
  end;
end;

end.

