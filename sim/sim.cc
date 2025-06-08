#include "Vtop.h"
#include <verilated.h>
#include <SDL2/SDL.h>
#include <cstdio>

constexpr int VGA_ACTIVE_W = 640;
constexpr int VGA_ACTIVE_H = 480;
constexpr int VGA_H_TOTAL = 800;
constexpr int VGA_V_TOTAL = 525;

static inline uint32_t expand4(uint8_t n4){ return uint32_t(n4)*17; }

int main(int argc,char**argv)
{
    Verilated::commandArgs(argc,argv);
    Vtop top;
    if (SDL_Init(SDL_INIT_VIDEO) < 0)
        return 1;
    SDL_Window  *win = SDL_CreateWindow("VGA-sim",
                     SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,
                     VGA_ACTIVE_W,VGA_ACTIVE_H,0);
    if (!win)
        return 1;
    SDL_Renderer*rnd = SDL_CreateRenderer(win,-1,SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!rnd)
        return 1;
    SDL_Texture *tex = SDL_CreateTexture(rnd,SDL_PIXELFORMAT_RGB888,
                                         SDL_TEXTUREACCESS_STREAMING,VGA_ACTIVE_W,VGA_ACTIVE_H);
    if (!tex)
        return 1;
    uint32_t *fb = new uint32_t[VGA_ACTIVE_W * VGA_ACTIVE_H]{};
    top.rst_n = 0;
    for(int i=0;i<16;i++){ top.clk=0; top.eval(); top.clk=1; top.eval(); }
    top.rst_n = 1;
    top.btnU = top.btnD = top.btnL = top.btnR = top.btnC = top.btn1 = top.btn2 = top.btn3 = top.btn4 = 0;
    int px_sim = 0;
    int py_sim = 0;
    while(!SDL_QuitRequested()) {
        SDL_Event e;
        while(SDL_PollEvent(&e)){
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
        for(int i=0; i < (VGA_H_TOTAL * VGA_V_TOTAL); ++i) {
            top.clk=0; top.eval();
            top.clk=1; top.eval();
            if(px_sim < VGA_ACTIVE_W && py_sim < VGA_ACTIVE_H){
                fb[py_sim * VGA_ACTIVE_W + px_sim] =
                    (expand4(top.red) << 16) |
                    (expand4(top.green) <<  8) |
                     expand4(top.blue);
            }
            if(++px_sim == VGA_H_TOTAL){
                px_sim = 0;
                if(++py_sim == VGA_V_TOTAL){
                    py_sim = 0;
                }
            }
        }
        if (px_sim == 0 && py_sim == 0) {
            SDL_UpdateTexture(tex, nullptr, fb, VGA_ACTIVE_W * sizeof(uint32_t));
            SDL_RenderClear(rnd);
            SDL_RenderCopy(rnd, tex, nullptr, nullptr);
            SDL_RenderPresent(rnd);
        }
    }
}
