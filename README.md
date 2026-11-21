# Yutani C.H.A.O.S. – GPU Edition (`Yutani.Chaos.Skia.GPU`)      
      
**An ultra-lightweight, GPU-accelerated holographic AI desktop overlay written in Delphi (FireMonkey + Skia4Delphi + OpenGL 4.3 Compute Shaders).**      
      
Unlike heavy Electron or game-engine overlays, **Yutani C.H.A.O.S. GPU** runs natively on Windows with virtually zero system overhead—making it ideal as an **always-on AI companion** and **interactive visual desktop canvas**.      
          
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/Yutani.CHAOS)    
              
<img width="820" height="37" alt="Unbenannt" src="https://github.com/user-attachments/assets/6b3cf114-39bd-4c55-884c-c1889f257319" />      
<img width="296" height="328" alt="face" src="https://github.com/user-attachments/assets/af9a758e-5b7a-412f-bd7d-1275aeb0b713" />
             
## ✨ Key Features      
      
- **100% GPU Particle Simulation & Splatting:** Spring-damper physics, 3D perspective projection, depth-based volumetric shading, and soft radial glow splatting executed directly inside OpenGL 4.3 Compute Shaders (`SSBO` + coherent `imageLoad`/`imageStore`).
- **True Per-Pixel Desktop Transparency:** Renders premultiplied-alpha frames directly onto a borderless, transparent, click-through FireMonkey layered window—floating freely over any application or desktop wallpaper.
- **Ultra-Low Resource Footprint:** Designed for continuous background operation without spinning up fans or impacting gaming/AI workloads.
- **Full Lifecycle Animations:** Includes holographic scanline build-up (formation), organic idle hover, and gravity-driven tear-down (despawn) effects.
- **Ready for AI & Agent Integration (Roadmap):** Built around target-coordinate particle morphing (`tx, ty, tz`), allowing LLMs / AI agents via API/MCP to not only animate facial expressions and emotions, but also **draw pointers, shapes, and visual highlights directly on the user's desktop**.
      
---      
> **Note:** Currently running without a control form – my eyes are burning and I need to take a screen break after wrangling this compute shader pipeline into working (which took quite a battle :D). Controls are coming soon! (or make them yourself :P)

          
      
## ⚡ Real-World Performance Benchmarks      
      
Tested at 30–40 FPS in transparent desktop overlay mode:
      
| Hardware Setup | CPU Usage | GPU Usage | Notes |
| :--- | :---: | :---: | :--- |
| **AMD Ryzen 5 4500U** (Vega 6 iGPU) | ~4.5 % | **1.3 % – 1.7 %** | Thin & light laptop, silent / no fan spin-up |
| **AMD Ryzen 7 5800X + RTX 2060 Super** | ~3.0 % | **~1.5 % avg** | GPU stays at idle clock states |
      
*(Note: Adaptive idle FPS scaling can drop usage even further when no active speech or drawing is happening. todo...)*
      
-------------------------------------------------------------------------------------------------------------

Yutani CHAOS - Complete Holographic AI Operating System Interface Skia4delphi VCL CPU version v0.1
        
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
    
