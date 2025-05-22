#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "./common.h"

// SOTE_DRV_begin_frame status codes
static const ENUM SOTE_DRV_CODE_NORMAL = 0;
static const ENUM SOTE_DRV_CODE_EXIT = 1;
static const ENUM SOTE_DRV_CODE_RESIZE = 2;

static const ENUM SOTE_RENDER_CLEAR = 1;
static const ENUM SOTE_RENDER_SET_ALPHA = 2;
static const ENUM SOTE_RENDER_FILL_RECT = 3;

// Shared b/t this and drv_*.c
static b32 resized_this_frame = 0;

typedef struct { u8 r, g, b, a; } SOTE_Color;
typedef struct { i32 x, y, w, h; } SOTE_Rect;

// Pixel buffer format
// static const ENUM SOTE_FMT_RGBA8888 = 1;

typedef struct {
  ENUM type;
  SOTE_Color user_color;
  i32 user_int;
  SOTE_Rect user_rect;
  void *user_ptr;
} SOTE_RenderCommand;

typedef struct {
  SOTE_RenderCommand *cmds;
  i32 length;
  i32 cap;
} SOTE_RenderBuffer;

static void push_cmd(SOTE_RenderBuffer *rbuf, ENUM type, SOTE_Color color, SOTE_Rect rect, i32 user_int, void *user) {
  if (rbuf->length + 1 > rbuf->cap) {
    printf("Could not push render cmd: out of memory\n");
    * (u8 *)0 = 1;
  }
  rbuf->cmds[rbuf->length] = (SOTE_RenderCommand){
    .type = type,
    .user_color = color,
    .user_int = user_int,
    .user_rect = rect,
    .user_ptr = user,
  }; rbuf->length++;
}

void SOTE_push_render_clear(SOTE_RenderBuffer *rbuf) {
  push_cmd(rbuf, (ENUM)SOTE_RENDER_CLEAR, (SOTE_Color){0}, (SOTE_Rect){0}, 0, 0);
}

void SOTE_push_render_set_alpha(SOTE_RenderBuffer *rbuf, u8 alpha) {
  push_cmd(rbuf, (ENUM)SOTE_RENDER_SET_ALPHA, (SOTE_Color){0}, (SOTE_Rect){0}, (i32)alpha, (void *)0);
}

void SOTE_push_render_fill_rect(SOTE_RenderBuffer *rbuf, SOTE_Rect rect, SOTE_Color color) {
  push_cmd(rbuf, (ENUM)SOTE_RENDER_FILL_RECT, color, rect, 0, (void *)0);
}

static SOTE_RenderCommand *last_commands = 0;
static i32 last_length = -1;

static b32 same_as_last(SOTE_RenderBuffer *rbuf) {
  if (resized_this_frame) { return 0; }
  if (last_commands == 0 || last_length < 0 || rbuf->length != last_length) { return 0; }
  assert(rbuf->length == last_length && rbuf->cmds != 0 && last_commands != 0);
  return (b32)(memcmp(rbuf->cmds, last_commands, rbuf->length * sizeof(SOTE_RenderCommand)) == 0);
}

static void update_last(SOTE_RenderBuffer *rbuf) {
  if (last_commands != 0) { free(last_commands); }
  last_commands = malloc(sizeof(SOTE_RenderCommand) * rbuf->length);
  memcpy(last_commands, rbuf->cmds, sizeof(SOTE_RenderCommand) * rbuf->length);
  last_length = rbuf->length;
}

void memset_word(void *dst, i32 word, i32 length) {
  for (i32 i = 0; i < length; i++) {
    ((i32 *)dst)[i] = word;
  }
}

void SOTE_render_commands_to_buffer(SOTE_RenderBuffer *rbuf, SOTE_Color *color_buffer, i32 sw, i32 sh) {
  if (same_as_last(rbuf)) { return; } // do not re-render if it's exactly the same shit we did last frame
  for (i32 i = 0; i < rbuf->length; i++) {
    if (rbuf->cmds[i].type == SOTE_RENDER_CLEAR) {
      memset(color_buffer, 0, sw * sh * sizeof(SOTE_Color));
    } else if (rbuf->cmds[i].type == SOTE_RENDER_FILL_RECT) {
      // Fill rect
      SOTE_Color color = rbuf->cmds[i].user_color;
      SOTE_Rect rect = rbuf->cmds[i].user_rect;
      i32 irect[4] = { (i32)rect.x, (i32)rect.y, (i32)rect.w, (i32)rect.h };

      i32 cur_color = irect[0] + (irect[1]*sw);
      for (i32 j = 0; j < irect[3]; j++) {
        memset_word((void *)&color_buffer[cur_color], * (i32 *)&color, irect[2]);
        cur_color += sw;
      }
    }
  }
  update_last(rbuf);
}