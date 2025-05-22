#pragma once

#include "./common.h"
#include "./gfx.c"
#include "./rl55/include/raylib.h"

void SOTE_DRV_init_video(void) {
  SetTargetFPS(60);
  SetConfigFlags(FLAG_WINDOW_RESIZABLE | FLAG_WINDOW_HIDDEN);
  InitWindow(1280, 720, "~ Song of The Earth ~");
  MaximizeWindow();
  HideCursor();
  ClearWindowState(FLAG_WINDOW_HIDDEN);
}

static i32 last_sw = -1;
static i32 last_sh = -1;
ENUM SOTE_DRV_begin_frame(i32 *ret_sw, i32 *ret_sh) {
  if (WindowShouldClose()) { return SOTE_DRV_CODE_EXIT; }
  resized_this_frame = 0;
  if (last_sw != GetScreenWidth() || last_sh != GetScreenHeight()) {
    resized_this_frame = 1;
  }
  last_sw = GetScreenWidth(); last_sh = GetScreenHeight();
  if (ret_sw != 0) { *ret_sw = GetScreenWidth(); }
  if (ret_sh != 0) { *ret_sh = GetScreenHeight(); }
  BeginDrawing();
  ClearBackground(BLACK);
  
  if (resized_this_frame) { return SOTE_DRV_CODE_RESIZE; }
  return SOTE_DRV_CODE_NORMAL;
}

static Texture2D stex = (Texture2D){0};
void SOTE_DRV_end_frame(SOTE_Color *colors) {
  SOTE_Color c = (SOTE_Color){ 255, 0, 0, 255 };
  Image frame = (Image){
    .data = colors,
    .width = last_sw,
    .height = last_sh,
    .mipmaps = 1,
    .format = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
  };
  if (resized_this_frame) {
    if (IsTextureValid(stex)) { UnloadTexture(stex); }
    stex = LoadTextureFromImage(frame);
  } else {
    if (!IsTextureValid(stex)) { stex = LoadTextureFromImage(frame); }
    else { UpdateTexture(stex, colors); }
  }
  DrawTexture(stex, 0, 0, WHITE);
  EndDrawing();
}