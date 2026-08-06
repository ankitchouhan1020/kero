//
//  sora_alacritty.h
//  Sora's Alacritty backend — C ABI over the `alacritty_terminal` crate.
//
//  Hand-maintained to match `src/lib.rs`. Layouts are `#[repr(C)]` on the Rust
//  side; keep field order and types in step when either changes.
//

#ifndef SORA_ALACRITTY_H
#define SORA_ALACRITTY_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Event kinds delivered on the PTY thread. The host bounces them to the main
/// thread before touching any view state.
#define SORA_EVENT_WAKEUP 0u
#define SORA_EVENT_TITLE 1u
#define SORA_EVENT_BELL 2u
#define SORA_EVENT_EXIT 3u
#define SORA_EVENT_CLIPBOARD_STORE 4u
#define SORA_EVENT_CLIPBOARD_LOAD 5u
#define SORA_EVENT_WORKING_DIRECTORY 6u
/// Three bytes: state (0-4), percent (0-100), and whether percent is present.
#define SORA_EVENT_PROGRESS 7u
#define SORA_EVENT_NOTIFICATION 8u
/// OSC 133 semantic prompt and command lifecycle markers.
#define SORA_EVENT_SHELL_PROMPT_START 9u
#define SORA_EVENT_SHELL_COMMAND_START 10u
#define SORA_EVENT_SHELL_COMMAND_EXECUTING 11u
/// Four-byte little-endian int32 exit code; -1 when the shell omitted it.
#define SORA_EVENT_SHELL_COMMAND_FINISHED 12u
/// UTF-8 OSC 22 pointer-shape name — a CSS cursor keyword such as "pointer".
#define SORA_EVENT_MOUSE_SHAPE 13u

/// Per-cell attributes in `SoraCell.flags`.
#define SORA_CELL_INVERSE (1u << 0)
#define SORA_CELL_BOLD (1u << 1)
#define SORA_CELL_ITALIC (1u << 2)
#define SORA_CELL_UNDERLINE (1u << 3)
#define SORA_CELL_STRIKEOUT (1u << 4)
#define SORA_CELL_DIM (1u << 5)
#define SORA_CELL_HIDDEN (1u << 6)
#define SORA_CELL_WIDE (1u << 7)
#define SORA_CELL_WIDE_SPACER (1u << 8)
#define SORA_CELL_SELECTED (1u << 9)

/// Bits returned by `sora_alacritty_mode`.
#define SORA_MODE_APP_CURSOR (1u << 0)
#define SORA_MODE_APP_KEYPAD (1u << 1)
#define SORA_MODE_ALT_SCREEN (1u << 2)
#define SORA_MODE_BRACKETED_PASTE (1u << 3)
#define SORA_MODE_MOUSE (1u << 4)
#define SORA_MODE_FOCUS_REPORTING (1u << 5)
#define SORA_MODE_MOUSE_CLICK (1u << 6)
#define SORA_MODE_MOUSE_DRAG (1u << 7)
#define SORA_MODE_MOUSE_MOTION (1u << 8)
#define SORA_MODE_SGR_MOUSE (1u << 9)
#define SORA_MODE_ALTERNATE_SCROLL (1u << 10)

typedef struct SoraTerminal SoraTerminal;

typedef void (*SoraEventCallback)(void *context, uint32_t kind, const uint8_t *data, size_t len);

typedef struct {
  /// Unicode scalar; a space when the cell is empty.
  uint32_t ch;
  /// Packed 0x00RRGGBB, already resolved through the palette.
  uint32_t fg;
  uint32_t bg;
  /// UTF-8 text in `SoraSnapshot.text` when this cell has combining marks.
  uint32_t text_offset;
  uint16_t text_len;
  uint16_t flags;
} SoraCell;

typedef struct {
  /// Inclusive viewport-relative cell bounds. Lines can be outside the
  /// viewport when a soft-wrapped URL begins or ends in scrollback.
  int32_t start_line;
  size_t start_column;
  int32_t end_line;
  size_t end_column;
} SoraURLRange;

typedef struct {
  uint32_t palette[256];
  uint32_t foreground;
  uint32_t background;
  uint32_t cursor;
} SoraTheme;

typedef struct {
  /// `columns * rows` cells in row-major order. Owned by the handle and valid
  /// only until the next call on it.
  const SoraCell *cells;
  size_t columns;
  size_t rows;
  /// Viewport-relative cursor, or -1 when it should not be drawn.
  intptr_t cursor_line;
  intptr_t cursor_column;
  /// 0 block, 1 underline, 2 beam, 3 hollow block.
  uint32_t cursor_shape;
  uint32_t cursor_color;
  uint32_t background;
  bool cursor_blinking;
  /// UTF-8 backing for cells with a non-zero `text_len`.
  const uint8_t *text;
  size_t text_len;
  size_t display_offset;
  size_t total_lines;
  size_t screen_lines;
} SoraSnapshot;

typedef struct {
  uint64_t placement_serial;
  uint32_t image_id;
  uint32_t placement_id;
  /// PNG bytes owned by the terminal handle and valid until its next FFI call.
  const uint8_t *png;
  size_t png_len;
  uint32_t image_width;
  uint32_t image_height;
  uint64_t image_generation;
  int32_t viewport_row;
  size_t column;
  uint32_t source_x;
  uint32_t source_y;
  uint32_t source_width;
  uint32_t source_height;
  uint32_t display_columns;
  uint32_t display_rows;
  uint32_t occupied_columns;
  uint32_t occupied_rows;
  uint32_t x_offset;
  uint32_t y_offset;
  int32_t z_index;
} SoraKittyPlacement;

typedef struct {
  uint64_t revision;
  const SoraKittyPlacement *placements;
  size_t placements_len;
} SoraKittySnapshot;

typedef struct {
  const char *shell;
  const char *const *args;
  size_t args_len;
  const char *working_directory;
  /// `KEY=VALUE` pairs.
  const char *const *env;
  size_t env_len;
  uint16_t columns;
  uint16_t rows;
  uint16_t cell_width;
  uint16_t cell_height;
  size_t scrollback_lines;
} SoraConfig;

/// Spawns a shell on a new PTY and starts reading it. Returns NULL on failure.
/// `context` must outlive the handle.
SoraTerminal *sora_alacritty_new(const SoraConfig *config, const SoraTheme *theme,
                                 SoraEventCallback callback, void *context);

/// Stops the read loop and releases the handle.
void sora_alacritty_free(SoraTerminal *handle);

/// PID of the shell, for the process panel and teardown signals.
int32_t sora_alacritty_child_pid(SoraTerminal *handle);

/// PID of the PTY's foreground process group — the running job rather than the
/// shell that launched it. Falls back to the shell's own PID.
int32_t sora_alacritty_foreground_pid(SoraTerminal *handle);

void sora_alacritty_write(SoraTerminal *handle, const uint8_t *bytes, size_t len);
/// Writes protocol input without moving the user's scrollback viewport.
void sora_alacritty_write_control(SoraTerminal *handle, const uint8_t *bytes, size_t len);
/// Completes a pending OSC 52 clipboard read. `request_id` is the little-endian
/// UInt64 delivered with `SORA_EVENT_CLIPBOARD_LOAD`.
void sora_alacritty_resolve_clipboard(SoraTerminal *handle, uint64_t request_id,
                                      const uint8_t *bytes, size_t len, bool approved);
void sora_alacritty_resize(SoraTerminal *handle, uint16_t columns, uint16_t rows,
                           uint16_t cell_width, uint16_t cell_height);
/// Scrolls by `delta` lines, positive toward older output.
void sora_alacritty_scroll(SoraTerminal *handle, int32_t delta);
/// Puts the viewport `offset` lines above the live prompt.
void sora_alacritty_scroll_to_offset(SoraTerminal *handle, size_t offset);
void sora_alacritty_set_theme(SoraTerminal *handle, const SoraTheme *theme);

/// `kind`: 0 simple, 1 semantic (word), 2 line — single, double, triple click.
void sora_alacritty_selection_start(SoraTerminal *handle, int32_t line, size_t column,
                                    uint32_t kind, bool right_half);
void sora_alacritty_selection_update(SoraTerminal *handle, int32_t line, size_t column,
                                     bool right_half);
void sora_alacritty_selection_clear(SoraTerminal *handle);
void sora_alacritty_select_all(SoraTerminal *handle);
bool sora_alacritty_has_selection(SoraTerminal *handle);

/// Copies into `buffer`, returning bytes written — or the length required when
/// `buffer` is NULL or `capacity` is too small.
size_t sora_alacritty_selection_text(SoraTerminal *handle, uint8_t *buffer, size_t capacity);

/// Whole buffer (or scrollback alone) as a styled VT stream, same length
/// protocol. ANSI attributes, truecolor, hyperlinks and combining marks are
/// retained so Sora can restore history without flattening it.
size_t sora_alacritty_buffer_text(SoraTerminal *handle, bool scrollback_only, uint8_t *buffer,
                                  size_t capacity);

/// OSC 8 hyperlink or recognized plain-text URL under one viewport cell. Also
/// writes its inclusive cell bounds when `range` is non-NULL. The URL uses the
/// same length protocol as selection text; zero means neither kind was found.
size_t sora_alacritty_url_at(SoraTerminal *handle, int32_t line, size_t column,
                             SoraURLRange *range, uint8_t *buffer, size_t capacity);

/// Counts every literal match of `needle` in screen and scrollback. Regex
/// metacharacters are escaped, not interpreted.
size_t sora_alacritty_find(SoraTerminal *handle, const char *needle);

/// Selects and reveals the next or previous match; returns its zero-based
/// index, or -1 when there are none.
intptr_t sora_alacritty_find_step(SoraTerminal *handle, bool forward);

void sora_alacritty_find_end(SoraTerminal *handle);

/// Whether the primary screen has rows above the viewport.
bool sora_alacritty_has_scrollback(SoraTerminal *handle);

void sora_alacritty_clear(SoraTerminal *handle);

/// Nothing changed; the host can drop the frame entirely.
#define SORA_DAMAGE_NONE 0u
/// Only the listed rows changed.
#define SORA_DAMAGE_PARTIAL 1u
/// Everything changed — a resize, a screen swap, a scroll.
#define SORA_DAMAGE_FULL 2u

typedef struct {
  uint32_t kind;
  /// Viewport row indices, owned by the handle and valid only until the next
  /// call on it. Empty unless `kind` is SORA_DAMAGE_PARTIAL.
  const size_t *rows;
  size_t rows_len;
} SoraDamage;

/// Which viewport rows changed since the last call, resetting damage as it
/// goes. A wakeup only means bytes arrived — ask this before paying for a
/// snapshot, and rebuild only the rows it names.
void sora_alacritty_take_damage(SoraTerminal *handle, SoraDamage *out);

/// Whether a DEC synchronized update is still being buffered.
bool sora_alacritty_synchronized_update(SoraTerminal *handle);

/// Fills `out` with the visible grid.
void sora_alacritty_snapshot(SoraTerminal *handle, SoraSnapshot *out);

/// Fills `out` with visible Kitty image placements.
void sora_alacritty_kitty_snapshot(SoraTerminal *handle, SoraKittySnapshot *out);

/// `SORA_MODE_*` bits.
uint32_t sora_alacritty_mode(SoraTerminal *handle);

void sora_alacritty_mark_exited(SoraTerminal *handle);

#ifdef __cplusplus
}
#endif

#endif /* SORA_ALACRITTY_H */
