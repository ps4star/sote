#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>
#include <assert.h>

#include "./gfx.c"

#if defined(SOTE_PLATFORM_LINUX)
  #include "./drv_raylib.c"
  static const i32 default_sw = 1280;
  static const i32 default_sh = 720;
#elif defined(SOTE_PLATFORM_WIN32)
  #include "./drv_raylib.c"
  static const i32 default_sw = 1280;
  static const i32 default_sh = 720;
#elif defined(SOTE_PLATFORM_MACOS)
  #include "./drv_raylib.c"
  static const i32 default_sw = 1280;
  static const i32 default_sh = 720;
#elif defined(SOTE_PLATFORM_PSP)
  #include "./drv_psp.c"
  static const i32 default_sw = 480;
  static const i32 default_sh = 272;
#endif

static SOTE_RenderCommand render_commands_buffer[64] = {0};
typedef struct {
  i32 sw;
  i32 sh;
  SOTE_RenderBuffer rbuf;
  SOTE_Color *colors;
} SOTE_Globals;

static SOTE_Globals g;
int main(int argc, char **argv) {
  g = (SOTE_Globals){0};
  g.rbuf = (SOTE_RenderBuffer){ .cmds = render_commands_buffer, .length = 0, .cap = 64 };
  
  SOTE_DRV_init_video();

  g.colors = calloc(1, default_sw * default_sh * sizeof(SOTE_Color));
  
  while (1) {
    ENUM status = SOTE_DRV_begin_frame(&g.sw, &g.sh);
    if (status == SOTE_DRV_CODE_EXIT) { break; }
    if (status == SOTE_DRV_CODE_RESIZE) {
      if (g.colors != 0) { free(g.colors); }
      g.colors = calloc(1, g.sw * g.sh * sizeof(SOTE_Color));
    }

    // Clear out render buffer for this frame
    g.rbuf.length = 0;

    /// BEGIN RENDERING CALLS
    SOTE_push_render_clear(&g.rbuf);
    SOTE_push_render_fill_rect(&g.rbuf, (SOTE_Rect){ 100, 100, 200, 200 }, (SOTE_Color){ 255, 0, 0, 255 });
    /// END RENDERING CALLS

    // printf("%d :: %d\n", g.sw, g.sh);

    // Commit gfx to buffer, then from buffer to screen
    SOTE_render_commands_to_buffer(&g.rbuf, g.colors, g.sw, g.sh);
    SOTE_DRV_end_frame(g.colors);
  }
}