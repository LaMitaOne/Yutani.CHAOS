# Yutani C.H.A.O.S. – GPU Edition  v0.41
**Complete Holographic AI Operating System**  
     
**An ultra-lightweight, GPU-accelerated 3D holographic AI desktop overlay written in Delphi (FireMonkey + Skia4Delphi + OpenGL 4.3 Compute Shaders).**  
     
Unlike heavy Electron or game-engine overlays, **Yutani C.H.A.O.S. GPU** runs natively on Windows with virtually zero system overhead—making it ideal as an **always-on AI companion** and **interactive visual desktop canvas**.  
     
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/Yutani.CHAOS)  
       
<img width="371" height="482" alt="Ussnbenannt" src="https://github.com/user-attachments/assets/9cd3a67a-36b1-4798-99f6-84b5b6610136" />
     
[Anime Head Base Mesh](https://sketchfab.com/3d-models/anime-head-base-mesh-58e291934379438584012d09faefedf6) by MarFab   
     
Sample Video v0.4: https://youtu.be/sGEjN7L1UJA       
    
---
<img width="371" height="432" alt="Unbenannt" src="https://github.com/user-attachments/assets/b52735b0-f786-4be4-8019-9972f29dcf72" />      
<img width="269" height="276" alt="6" src="https://github.com/user-attachments/assets/eaac83db-ad01-4319-b007-87f8680cc236" />
<img width="271" height="196" alt="4" src="https://github.com/user-attachments/assets/8aa2b22d-162b-4153-9fda-4e1674daa602" />
<img width="232" height="246" alt="3" src="https://github.com/user-attachments/assets/1220901b-aa54-4c08-a20c-abe9bde5d7e9" />
<img width="204" height="242" alt="2" src="https://github.com/user-attachments/assets/e9ab4dc1-cbe2-4545-b0cc-a4955bae6757" />
<img width="229" height="256" alt="1" src="https://github.com/user-attachments/assets/2fc400e7-18f9-4fc5-b3b3-47c2c4bd0a8f" />

     
## ✨ Key Features  
     
- **100% GPU Particle Simulation & Splatting:** Spring-damper physics, 3D perspective projection, normal-based rim lighting, volumetric depth shading, and soft radial glow splatting executed directly inside OpenGL 4.3 Compute Shaders (`SSBO` + coherent `imageLoad`/`imageStore`).  
- **Zero-Dependency 3D Mesh Loader (`.glb` & `.obj`):** Parses binary glTF 2.0 scene hierarchies (`nodes` + `TRS`/`matrix` transforms), extracts normals, supports interactive per-part sub-mesh filtering (hair, eyes, glasses, armor, internal parts), body-part classification, and glTF morph targets / vertex-frame animations.  
- **5 Distinct Hologram Shader Styles & 2D-to-3D Photo Mode:** Switch live between **Hologram** (classic scanlines & rim glow), **Android Circuit** (procedural circuit traces, vias & traveling data pulses), **Cyber Matrix** (vertical digital streams), **Blueprint** (topographic 3D contour grid), **Solid** (dense shaded 3D surface), and **Photo** (`PNG`/`JPG` luma-to-depth + Sobel normal estimation) modes.  
- **Dual-Mesh Inner Core / Brain System:** Load any independent `.glb` / `.obj` mesh (such as a multi-lobe brain or sci-fi energy core) inside the outer head with dedicated scale, vertical offset, particle budget, per-lobe coloring, and separate outer vs. inner shader appearance parameters (`Glow`, `Particle Size`, `Softness`, `Rim Power`).  
- **Live Per-Part Custom Coloring & Eye Dim-Blink:** Tint every outer or inner sub-mesh independently at runtime without reloading the model, paired with automatic eye sub-mesh detection for smooth eased dim-blinking and jaw-hinge speech animation.  
- **Anatomical Neck-Pivot & Rigid Head Mouse Tracking:** Smoothly tracks the global cursor position (`GetCursorPos`) with spring-damped inertia and a `smoothstep` neck pivot—turning and nodding the head naturally while keeping shoulders steady, or switching to `0.00 (OFF)` for distortion-free rigid rotation on floating heads and skulls.  
- **True Per-Pixel Desktop Transparency, Live Resize & Dragging:** Renders premultiplied-alpha frames via zero-copy dual-PBO readback onto a borderless, transparent, click-through (`WS_EX_TRANSPARENT`) FireMonkey layered window with interactive mouse dragging, corner snapping, live avatar resizing, and an integrated organic Skia screen highlighter (`uSkiaAliveHighlighter`).  
- **Per-Mesh & Startup Auto-Presets:** Automatically saves and restores complete per-head setups (`presets\<Folder>_<Mesh>.ini` + `last.ini` startup index) including outer & inner meshes, all per-part colors/visibility, hologram style, appearance settings, blink timing, avatar size, screen position, and drag mode.  
- **Full Lifecycle Scanline Animations & Adaptive FPS:** Includes holographic top-to-bottom build-up (`Spawn`), organic idle hover, gravity-driven tear-down (`Despawn`), and automatic `ActiveTargetFPS` / `IdleTargetFPS` throttling to keep laptop fans silent.  
- **Tabbed Runtime Control Panel & Native System Tray:** Features a compact, HD-screen-friendly tabbed cockpit (`uControls` with `Appearance / Shader`, `Mesh & Sources`, `Inner Core / Brain`, `Photo`, `Face / Animation`, `Desktop Overlay`, and `System / Performance` tabs) and a dependency-free Win32 `Shell_NotifyIconW` system tray menu (`uAppTray`).  
     
---     
     
## 🚧 Work in Progress / Roadmap  
     
- **LLM / MCP & TTS Integration:** Connecting an OpenAI-compatible / local LLM API + speech output so the avatar autonomously drives lip-sync (`MouthOpen`), emotions, style switches, and desktop highlights (`TAliveHighlighter`).  
- **Extended Facial Expressions:** Further refining mouth lip-separation and emotion-driven brow/cheek poses across all five shader styles.  
     
---     
     
## ⚡ Real-World Performance Benchmarks  
     
Tested in transparent desktop overlay mode on Windows:  
     
| Hardware Setup | Mode / FPS | CPU Usage | GPU Usage | Notes |
| :--- | :---: | :---: | :---: | :--- |
| **AMD Ryzen 5 4500U** (Vega 6 iGPU) | 3D Mesh (~38–60 FPS) | **~2.5 % – 5.0 %** | **~1.4 % – 2.5 %** | Thin & light laptop, completely silent / no fan spin-up |
| **AMD Ryzen 5 4500U** (Vega 6 iGPU) | 3D Mesh (120 FPS) | ~25 % | ~17 % | High-refresh stress test over transparent desktop |
| **AMD Ryzen 7 5800X + RTX 2060 Super** | 30–40 FPS | ~3.0 % | **~1.5 % avg** | GPU stays at idle clock states |

*And yes, I even tested it on my legendary **ASUS UX305CA (Intel Core m3 / HD 515)**—it runs at just **5% CPU / 4% GPU** while active (barely more than Windows Task Manager itself uses). Honestly, he wasn't very impressed lol.*
     
---     
     
## 🧩 Project Architecture  
     
- `Yutani.Chaos.Skia.GPU.pas` — Offscreen OpenGL 4.3 context, compute shaders (`PARTICLE_SRC`, `HOLO_PARTICLE_SRC`, `CLEAR_SRC`, `BLUR_SRC`), dual-PBO readback, preset serialization, and `TSkChaos` component.  
- `Yutani.MeshLoader.pas` — Zero-dependency `.glb` (glTF 2.0) and `.obj` parser with scene-graph transforms, sub-mesh filtering, normal calculation, and blend-shape support.  
- `Yutani.PhotoTo3D.pas` — 2D portrait-to-3D point-cloud pipeline with Sobel depth-gradient normals and hybrid stitching.  
- `uSkiaCustomThreadedBase.pas` — High-precision QPC background render thread with hybrid `Sleep`/spin-wait pacing, `RealFPS` counter, and Adaptive Idle-FPS controller.  
- `uSkiaAliveHighlighter.pas` — Organic Skia energy-trail screen highlighter driven directly from the overlay canvas.  
- `uControls.pas` — Runtime-generated tabbed control form (`Appearance / Shader`, `Mesh & Sources`, `Inner Core / Brain`, `Photo`, `Face / Animation`, `Desktop Overlay`, `System / Performance`).  
- `uAppTray.pas` — Standalone Win32 notification-area icon and popup menu wrapper for FireMonkey.  
- `Unit1.pas` — Transparent, click-through desktop host window.  
     
---
    
## 📝 Changelog

### v0.41 — Hologram Styles, Dual-Mesh Brain Core, Per-Part Colors & Full Preset Persistence

#### Visual Styles & Compute Shader
- **5 Distinct Hologram Styles:** Upgraded the shader pipeline to five distinct visual modes (`Hologram`, `Android Circuit` with traveling data pulses and vias, `Cyber Matrix` vertical digital streams, `Blueprint` topographic contour grid, and `Solid` dense shaded 3D surface).
- **Per-Part Custom Coloring:** Added live per-submesh color pickers in the `Parts` tab so individual mesh groups (eyes, hair, armor, brain lobes, etc.) can be tinted independently in real time without reloading the mesh.
- **Smooth Eye Dim-Blink & Configurable Timing:** Replaced coordinate-based eyelid distortion with automatic eye submesh detection and smooth eased brightness dimming, plus runtime sliders for blink interval and blink speed.
- **Refined Jaw-Hinge Kinematics:** Replaced vertical chin stretching with anatomically anchored jaw-pivot rotation and a localized speech-energy wave along the lip slit.

#### Independent Inner Core / Brain System
- **Dedicated `Inner Core / Brain` Tab:** Load any separate `.glb` / `.obj` mesh (such as a multi-lobe brain or energy core) inside the outer hologram head with adjustable scale, vertical offset, and particle budget.
- **Per-Part Inner Core Colors:** Tint individual sub-meshes of the inner core independently (e.g. separate colors per brain lobe).
- **Separate Outer vs. Inner Appearance Controls:** Added a target switcher (`Head / Outer` vs. `Brain / Inner Core`) in the `Appearance / Shader` tab so `Glow`, `Particle Size`, `Softness`, and `Rim Power` can be tuned independently without over-brightening behind the eyes.
- (sounds strange but... Brain u can find here one lol https://sketchfab.com/3d-models/brain-project-24ec03412dd8432bb0d3e750a72608e0)    

#### Desktop Overlay, Highlighter & Save/Load Presets
- **Interactive Dragging, Snapping & Live Resize:** Added a new `Desktop Overlay` tab with persistent mouse-drag positioning (`Drag avatar with mouse`), one-click `Snap Bottom-Left` / `Snap Bottom-Right` buttons, and live `Avatar size` scaling.
- **Per-Mesh & Named Presets (`Save / Load`):** Added automatic per-head preset saving/loading (`presets\<Folder>_<Mesh>.ini`) as well as `Save preset as...` and `Load preset...` dialogs—persisting outer & inner meshes, all per-part colors & visibility, hologram style, outer/inner appearance settings, blink timing, avatar size, screen position, and drag mode.


### v0.4 — Sub-Mesh Selection & Neck-Pivot *(or the "Added Mesh Sources in README 'Cause You'll Need Them" Update :D)*
    
#### Features & UI
- **Sub-Mesh Part Selection:** Added interactive per-part checkboxes in the *Mesh & Sources* tab to toggle individual sub-meshes (hair, glasses, eyes, armor, internal parts, etc.) on or off when *Automatic* mode is unchecked.
- **Smart Automatic Fallback:** Automatically falls back to loading the full mesh if default `ExcludeKeywords` would filter out 100% of a single-mesh model.
- **Neck-Pivot Controls & Rigid Head Mode:** Added a dedicated *Neck Pivot* slider to fine-tune the anatomical bending point for busts, or set it to `0.00 (OFF)` for distortion-free rigid head rotation on floating heads/skulls.
- **Dedicated Photo Tab:** Moved photo/image-to-particle settings into their own separate tab in the control panel for a cleaner layout.
    
#### Bug Fixes
- **Fixed SSBO Mesh Reloading (OpenGL Context Threading):** Deferred `glBufferSubData` uploads via a dirty flag (`FSSBODirty`) so buffer updates always execute on the background render thread where `FGLContext` is current—loading new `.glb`/`.obj` meshes and toggling parts now updates immediately.
- **Fixed Manual Part Filter Override:** Prevented manual sub-mesh selections from falling back to `nil` (Automatic mode) when all checkboxes remain ticked.
        
---
    
## 🌐 Tested Mesh Sources (Sketchfab CC-BY)
    
Want to try more heads right away? Drop any `.glb` or `.obj` into your mesh folder—screenshots were made using some of these free CC-BY models:
    
* https://sketchfab.com/3d-models/anime-head-base-mesh-58e291934379438584012d09faefedf6
* https://sketchfab.com/3d-models/mecha-04-bd307b2be9a147338810249494c54af2
* https://sketchfab.com/3d-models/girl-with-glasses-4c865c5df17741f7be87392d37fa31eb
* https://sketchfab.com/3d-models/male-head-0247a25a04ba46b99629130277fe39b7
* https://sketchfab.com/3d-models/cyborg-head-332e28983a9c476f896f3fdb8d3bd6c5
* https://sketchfab.com/3d-models/cyberpunk-head-1d4f99091619491fb45b7ecbe2b838b5
* https://sketchfab.com/3d-models/cybernetic-skull-ee97f182cb4b48e894f66ee2020bc181
* https://sketchfab.com/3d-models/futuristic-robot-head-a-futuristic-robot-head-da0a453250994ee8a9d99fd4040995f3
    
---
     
## 📜 3D Asset Credits  
     
Bundled demo `.glb` models tested with this project (see `MODEL_CREDITS.txt` for full Creative Commons license details):  
- **Angelica** by *DarkNik* (CC BY 4.0)  
- **Procedural female scifi armor test 3** by *ghostnoface* (CC BY 4.0)  
- **Scifi Girl v.01** by *patrix* (CC BY-NC-SA 4.0)
    
       
## 🕰️ Origin Story (2009 ➡️ 2026)      
      
The vision behind **Yutani C.H.A.O.S.** dates all the way back to **October 2009**, when I built an early multimodal     
AI desktop companion in **Delphi 7 (VCL)**. Even back then, it combined cursor-tracking eyes,      
**SAPI 5.1 continuous speech recognition** with wake-word detection, **Text-to-Speech**, **webcam 2D motion     
tracking** (`TVideoGrabber`), an experimental **neural network brain** powered by `FANN` (`fannfixed.dll`),     
and an `instincts` module—all running natively on Windows (and its original 2009 Win32 binary still runs on Windows 11 today).     
        
Seventeen years later, **Yutani C.H.A.O.S.** brings that exact same vision into the modern era with 100% GPU-accelerated        
OpenGL 4.3 Compute Shaders, 3D holographic point clouds, and modern LLM/MCP agent integration.     
*(That 2009 prototype used "Homer" as its avatar, so I'm probably not even allowed to post a screenshot of it :P)*
      
<img width="371" height="201" alt="Unbenannt" src="https://github.com/user-attachments/assets/4cd6a3a4-91ee-4fdb-9880-a9673669f222" />





            
-------------------------------------------------------------------------------------------------------------


     
     
**Yutani CHAOS - Complete Holographic AI Operating System Interface Skia4delphi VCL CPU version v0.2**
        
<img width="299" height="280" alt="Unbenannt" src="https://github.com/user-attachments/assets/411e6bae-544c-4537-bd01-0b3ca14cf055" />
    
https://github.com/user-attachments/assets/9e80b987-3fdb-4115-a56a-436368bf6348
    
https://youtu.be/cgioy0pwNz4     
              
A dynamic, real-time particle-based holographic AI face rendered entirely from scratch using Delphi and Skia4Delphi. Instead of standard UI controls, this module renders a 3D-projected particle system onto an off-screen Skia surface, encodes it, and pushes it directly to a borderless, click-through Windows layered window.

Perfect for assistant overlays, sci-fi UIs, or just putting a cool holographic face on your desktop.

Delphi  Skia4Delphi  Platform 
✨ Features

     Procedural Particle System: Generates a 3D face from a depth map (depthmap.png).
     Build-Up & Tear-Down: The face dynamically assembles itself (scanline build-up) and falls apart with physics-based gravity when closed.
     Interactive Tracking: The eyes and face parallax track the mouse cursor.
     Dynamic Expressions: Supports blinking, and different mouth states (Closed, Min, Mid, Full).
     Custom Rendering Pipeline: Bypasses VCL controls, manually drawing to an ISkSurface, exporting to a PNG stream, and rendering via UpdateLayeredWindow for zero-lag transparent windows.
     Glow & Circuitry: Glowing nodes with flickering hologram effects and connecting circuit lines between particles.

🚀 Getting Started
Prerequisites

     Delphi (VCL)
     Skia4Delphi
     Windows OS (due to UpdateLayeredWindow API usage)

Installation

    Clone the repo.
    Ensure Skia is in your library paths.
    Place a depthmap.png in your executable directory (or let the fallback procedural ring generate).

🎮 Sample Included

The repository includes a sample project demonstrating how to control the interface.

Available Controls in the Demo:

     Start / Stop: Triggers the build-up animation (Start) and the physics tear-down fade (Stop).
     Mouth Buttons: Closed, Min, Mid, Full (to change facial expressions).
     Eye Buttons: Open, Mid, Closed (to manually override eye states).


Part of Yutani Engine https://github.com/LaMitaOne/Yutani-Building-better-worlds      
    
