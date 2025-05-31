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
}
