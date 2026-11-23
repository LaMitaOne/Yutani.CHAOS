# Yutani C.H.A.O.S. – GPU Edition  
**Complete Holographic AI Operating System**  
     
**An ultra-lightweight, GPU-accelerated 3D holographic AI desktop overlay written in Delphi (FireMonkey + Skia4Delphi + OpenGL 4.3 Compute Shaders).**  
     
Unlike heavy Electron or game-engine overlays, **Yutani C.H.A.O.S. GPU** runs natively on Windows with virtually zero system overhead—making it ideal as an **always-on AI companion** and **interactive visual desktop canvas**.  
     
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/Yutani.CHAOS)  
       
<img width="821" height="33" alt="Unbenannt" src="https://github.com/user-attachments/assets/ca98dbe8-8cc6-4080-a9e2-919dff901072" />
         
<img width="482" height="372" alt="Unbenannt" src="https://github.com/user-attachments/assets/e6797fc1-912d-4f6e-925f-0cbb897d06f9" />
      
---
https://github.com/user-attachments/assets/334296a3-af78-49e6-afdd-ef5be7555137
      
Sample Video: https://youtu.be/Qf8PRYuqDEg      

     
## ✨ Key Features  
     
- **100% GPU Particle Simulation & Splatting:** Spring-damper physics, 3D perspective projection, normal-based rim lighting, volumetric depth shading, and soft radial glow splatting executed directly inside OpenGL 4.3 Compute Shaders (`SSBO` + coherent `imageLoad`/`imageStore`).  
- **Zero-Dependency 3D Mesh Loader (`.glb` & `.obj`):** Parses binary glTF 2.0 scene hierarchies (`nodes` + `TRS`/`matrix` transforms), extracts normals, supports mesh/keyword filtering, body-part classification, and glTF morph targets / vertex-frame animations.  
- **Anatomical Neck-Pivot Mouse Tracking:** Smoothly tracks the global cursor position (`GetCursorPos`) with spring-damped inertia and a `smoothstep` neck pivot—turning and nodding the head naturally while keeping the shoulders steady.  
- **Switchable Hologram Styles:** Live switching between **Classic**, **Cyber** (accent rim-lighting), **Volumetric** (optional pulsating inner brain-core), and **Photo** modes.  
- **True Per-Pixel Desktop Transparency:** Renders premultiplied-alpha frames via zero-copy PBO readback onto a borderless, transparent, click-through (`WS_EX_TRANSPARENT`) FireMonkey layered window with optional `StayOnTop` toggle.  
- **Full Lifecycle Scanline Animations:** Includes holographic top-to-bottom build-up (`Spawn`), organic idle hover, and gravity-driven tear-down (`Despawn` + graceful `QuitAfterDespawn` on exit).  
- **Tabbed Runtime Control Panel & Native System Tray:** Features a compact, HD-screen-friendly tabbed cockpit (`uControls`) and a dependency-free Win32 `Shell_NotifyIconW` system tray menu (`uAppTray`) for quick style switching, spawn/despawn, and window toggles.  
- **Adaptive Idle-FPS Pacing:** Automatically runs at high frame rates during speech, morphing, or animation (`ActiveTargetFPS`) and throttles down after a configurable silence timeout (`IdleTargetFPS`) to keep laptop fans silent.  
- **Ready for AI & Agent Integration (Roadmap):** Built around target-coordinate particle morphing (`tx, ty, tz`), allowing LLMs / AI agents via API/MCP to control expressions, look in a "mirror" (`look_in_mirror`), and **draw pointers, shapes, and visual highlights directly on the user's desktop**.  
     
---     
     
## 🚧 Work in Progress / Experimental  
     
- **`Yutani.PhotoTo3D` & Full-Body Meshes:** Implemented in code (`PNG`/`JPG` luma-to-depth + Sobel normal estimation and hybrid stitching), currently untested in live production.  
- **Holo-Shader Facial Controls:** `Mouth Open`, `Eye Openness`, `Chaos Level`, and `Trail Persistence` sliders are wired in the UI (`Face / Animation` tab) but not yet connected inside the `HOLO_PARTICLE_SRC` mesh shader (currently active in the legacy depth-map shader).  
- **LLM / MCP Bridge:** Planned next step for autonomous AI expression, shape projection, and self-reflection.  
     
---     
     
## ⚡ Real-World Performance Benchmarks  
     
Tested in transparent desktop overlay mode on Windows:  
     
| Hardware Setup | Mode / FPS | CPU Usage | GPU Usage | Notes |
| :--- | :---: | :---: | :---: | :--- |
| **AMD Ryzen 5 4500U** (Vega 6 iGPU) | 3D Mesh (~38 FPS) | **~2.5 % – 4.5 %** | **~1.4 % – 2.5 %** | Thin & light laptop, completely silent / no fan spin-up |
| **AMD Ryzen 5 4500U** (Vega 6 iGPU) | 3D Mesh (120 FPS) | ~25 % | ~17 % | High-refresh stress test over transparent desktop |
| **AMD Ryzen 7 5800X + RTX 2060 Super** | 30–40 FPS | ~3.0 % | **~1.5 % avg** | GPU stays at idle clock states |

And yes, I even tested it on my legendary ASUS UX305CA (Intel Core m3 / HD 515) it runs at just 5% CPU / 4% GPU while active. Honestly, it's barely breaking a sweat lol.     
         
---     
     
## 🧩 Project Architecture  
     
- `Yutani.Chaos.Skia.GPU.pas` — Offscreen OpenGL 4.3 context, compute shaders (`PARTICLE_SRC`, `HOLO_PARTICLE_SRC`, `CLEAR_SRC`, `BLUR_SRC`), dual-PBO readback, and `TSkChaos` component.  
- `Yutani.MeshLoader.pas` — Zero-dependency `.glb` (glTF 2.0) and `.obj` parser with scene-graph transforms, normal calculation, and blend-shape support.  
- `Yutani.PhotoTo3D.pas` — Experimental 2D portrait-to-3D point-cloud pipeline with Sobel depth-gradient normals.  
- `uSkiaCustomThreadedBase.pas` — High-precision QPC background render thread with hybrid `Sleep`/spin-wait pacing, `RealFPS` counter, and Adaptive Idle-FPS controller.  
- `uControls.pas` — Runtime-generated tabbed control form (`Appearance / Shader`, `Mesh & Sources`, `Face / Animation`, `System / Performance`).  
- `uAppTray.pas` — Standalone Win32 notification-area icon and popup menu wrapper for FireMonkey.  
- `Unit1.pas` — Transparent, click-through desktop host window.  
     
---
     
## 📜 3D Asset Credits  
     
Demo `.glb` models tested with this project (see `MODEL_CREDITS.txt` for full Creative Commons license details):  
- **Angelica** by *DarkNik* (CC BY 4.0)  
- **Procedural female scifi armor test 3** by *ghostnoface* (CC BY 4.0)  
- **Scifi Girl v.01** by *patrix* (CC BY-NC-SA 4.0)  
     
           
-------------------------------------------------------------------------------------------------------------
     
     
**Yutani CHAOS - Complete Holographic AI Operating System Interface Skia4delphi VCL CPU version v0.1**
        
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
    
