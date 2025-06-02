#include "Vtop.h"
#include <verilated.h>
#include <SDL2/SDL.h>
#include <cstdio>

// Your original VGA timings and active area
constexpr int VGA_ACTIVE_W = 640;  // Your W
constexpr int VGA_ACTIVE_H = 480;  // Your H
constexpr int VGA_H_TOTAL = 800;   // Your H_TOTAL (total horizontal pixels including blanking)
constexpr int VGA_V_TOTAL = 525;   // Your V_TOTAL (total vertical lines including blanking)

// Expand 4-bit color to 8-bit (0-15 -> 0-255)
static inline uint32_t expand4(uint8_t n4){ return uint32_t(n4)*17; }

int main(int argc,char**argv)
{
    Verilated::commandArgs(argc,argv);
    Vtop top;

    // --- SDL Initialization ---
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        fprintf(stderr, "SDL could not initialize! SDL_Error: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window  *win = SDL_CreateWindow("VGA-sim",
                     SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,
                     VGA_ACTIVE_W,VGA_ACTIVE_H,0); // Use active resolution for window size
    if (!win) {
        fprintf(stderr, "Window could not be created! SDL_Error: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    // Use SDL_RENDERER_ACCELERATED for GPU rendering and SDL_RENDERER_PRESENTVSYNC
    // to synchronize with monitor refresh rate.
    SDL_Renderer*rnd = SDL_CreateRenderer(win,-1,SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!rnd) {
        fprintf(stderr, "Renderer could not be created! SDL_Error: %s\n", SDL_GetError());
        SDL_DestroyWindow(win);
        SDL_Quit();
        return 1;
    }

    // SDL_PIXELFORMAT_RGB888 is RRGGBB.
    SDL_Texture *tex = SDL_CreateTexture(rnd,SDL_PIXELFORMAT_RGB888,
                                         SDL_TEXTUREACCESS_STREAMING,VGA_ACTIVE_W,VGA_ACTIVE_H);
    if (!tex) {
        fprintf(stderr, "Texture could not be created! SDL_Error: %s\n", SDL_GetError());
        SDL_DestroyRenderer(rnd);
        SDL_DestroyWindow(win);
        SDL_Quit();
        return 1;
    }

    // Framebuffer for active pixels only
    uint32_t *fb = new uint32_t[VGA_ACTIVE_W * VGA_ACTIVE_H]{}; // Initialize to all zeros

    // --- Verilator Reset ---
    top.rst_n = 0;
    for(int i=0;i<16;i++){ top.clk=0; top.eval(); top.clk=1; top.eval(); }
    top.rst_n = 1;
    top.btnU = top.btnD = top.btnL = top.btnR = top.btnC = top.btn1 = top.btn2 = top.btn3 = top.btn4 = 0;

    // --- Simulation State Variables ---
    int px_sim = 0; // Simulated horizontal pixel counter (0 to H_TOTAL-1)
    int py_sim = 0; // Simulated vertical pixel counter (0 to V_TOTAL-1)


    // --- Main Simulation Loop ---
    while(!SDL_QuitRequested()) {
        // --- Process SDL Events ---
        SDL_Event e;
        while(SDL_PollEvent(&e)){ // Process all events in queue
            if(e.type==SDL_KEYDOWN || e.type==SDL_KEYUP){
                bool p = (e.type==SDL_KEYDOWN);
                switch(e.key.keysym.sym){
                    case SDLK_w: top.btnU = p; break;
                    case SDLK_s: top.btnD = p; break;
                    case SDLK_a: top.btnL = p; break;
                    case SDLK_d: top.btnR = p; break;
                    case SDLK_e: top.btnC = p; break;
                    case SDLK_1: top.btn1 = p; break;
                    case SDLK_2: top.btn2 = p; break;
                    case SDLK_3: top.btn3 = p; break;
                    case SDLK_4: top.btn4 = p; break;
                }
            }
        }

        // --- Simulate an Entire Frame Before Updating Display ---
        // Loop for all pixels in a complete VGA frame timing (including blanking)
        for(int i=0; i < (VGA_H_TOTAL * VGA_V_TOTAL); ++i) {
            top.clk=0; top.eval(); // Evaluate on falling edge
            top.clk=1; top.eval(); // Evaluate on rising edge

            // --- Pixel Writing to Framebuffer ---
            // Only write pixels if within the active display area (640x480)
            // Assuming active display starts at (0,0) in your Verilog's pixel counting.
            // If your Verilog has separate 'de' signal, it's better to use that
            // for conditional writes. Since your original code didn't use 'de',
            // we'll assume px_sim/py_sim tracks the active area.
            if(px_sim < VGA_ACTIVE_W && py_sim < VGA_ACTIVE_H){
                fb[py_sim * VGA_ACTIVE_W + px_sim] =
                    (expand4(top.red)   << 16) | // Use top.red, top.green, top.blue as in your original code
                    (expand4(top.green) <<  8) |
                     expand4(top.blue);
            }

            // Advance the simulated pixel counters
            // This logic perfectly matches your original horizontal/vertical total counts
            if(++px_sim == VGA_H_TOTAL){
                px_sim = 0;
                if(++py_sim == VGA_V_TOTAL){
                    py_sim = 0; // End of frame, reset to (0,0) for next frame
                }
            }
        } // End of per-frame simulation loop

        // --- SDL Rendering (Triggered once per complete frame) ---
        // This condition will now be met *exactly once* after each full frame's simulation.
        // The framebuffer 'fb' will contain the just-completed frame's data.
        if (px_sim == 0 && py_sim == 0) {
            SDL_UpdateTexture(tex, nullptr, fb, VGA_ACTIVE_W * sizeof(uint32_t));
            SDL_RenderClear(rnd);
            SDL_RenderCopy(rnd, tex, nullptr, nullptr);
            SDL_RenderPresent(rnd); // This handles VSync waiting if SDL_RENDERER_PRESENTVSYNC was used
        }
        // No SDL_Delay(1) needed here, SDL_RENDERER_PRESENTVSYNC handles frame pacing.
    }

}
/*
#include "Vtop.h"
#include <verilated.h>
#include <SDL2/SDL.h>
#include <cstdio>

constexpr int H = 480, W = 640;
constexpr int H_TOTAL = 800;
constexpr int V_TOTAL = 525;
constexpr int PIXELS_PER_BATCH = 8;

enum { BTN_W=0, BTN_S, BTN_A, BTN_D };

static inline uint32_t expand4(uint8_t n4){ return uint32_t(n4)*17; }

int main(int argc,char**argv)
{
    Verilated::commandArgs(argc,argv);
    Vtop top;
    top.rst_n = 0;
    for(int i=0;i<16;i++){ top.clk=0; top.eval(); top.clk=1; top.eval(); }
    top.rst_n = 1;
    top.btnU = top.btnD = top.btnL = top.btnR = top.btnC = top.btn1 = top.btn2 = top.btn3 = top.btn4 = 0;
    SDL_Init(SDL_INIT_VIDEO);
    SDL_Window  *win = SDL_CreateWindow("VGA-sim",
                     SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,W,H,0);
    SDL_Renderer*rnd = SDL_CreateRenderer(win,-1,SDL_RENDERER_ACCELERATED);
    SDL_Texture *tex = SDL_CreateTexture(rnd,SDL_PIXELFORMAT_RGB888,
                                         SDL_TEXTUREACCESS_STREAMING,W,H);
    uint32_t *fb = new uint32_t[W*H]{};

    int px = 0, py = 0;

    while(!SDL_QuitRequested()) {
        for(SDL_Event e; SDL_PollEvent(&e); ){
            if(e.type==SDL_KEYDOWN||e.type==SDL_KEYUP){
                bool p = (e.type==SDL_KEYDOWN);
                switch(e.key.keysym.sym){
                    case SDLK_w: top.btnU = p; break;
                    case SDLK_s: top.btnD = p; break;
                    case SDLK_a: top.btnL = p; break;
                    case SDLK_d: top.btnR = p; break;
					case SDLK_e: top.btnC = p; break;
					case SDLK_1: top.btn1 = p; break;
					case SDLK_2: top.btn2 = p; break;
					case SDLK_3: top.btn3 = p; break;
					case SDLK_4: top.btn4 = p; break;
                }
            }
        }
        for(int i=0;i<PIXELS_PER_BATCH;++i){
            top.clk=0; top.eval();
            top.clk=1; top.eval();
            if(px < W && py < H){
                fb[py*W + px] =
                    (expand4(top.red)   << 16) |
                    (expand4(top.green) <<  8) |
                     expand4(top.blue);
            }
            if(++px == H_TOTAL){ px = 0; if(++py == V_TOTAL){ py = 0; } }
        }
        if(py == 0 && px == 0){
            SDL_UpdateTexture(tex,nullptr,fb,W*4);
            SDL_RenderClear(rnd);
            SDL_RenderCopy(rnd,tex,nullptr,nullptr);
            SDL_RenderPresent(rnd);
            SDL_Delay(1);
        }
    }
    SDL_Quit();
}*/
