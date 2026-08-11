local __modules, __cached = {}, {}
__modules["lib/constants"] = function()
-- Pure numeric/tuning constants.
local M = {}

-- Game rules: these values define the board contract and spawn behavior.
M.BOARD_SIZE = 4
M.WIN_VALUE = 2048
M.SPAWN_FOUR_PROBABILITY = 0.1
-- Shared board geometry defaults. geometry.lua derives cell/gap dimensions.
M.GEOMETRY_CHAR_ASPECT = 2.6
M.GEOMETRY_UNIT = 3

M.ANIM_FRAMES = 7
M.ANIM_FRAME_DELAY = 0.016
M.SLIDE_DURATION_SECONDS = 0.250
M.HALF_STEP_ANIMATION = true
M.MERGE_POP_FRAMES = 6
M.MERGE_POP_DELAY = 0.02
M.SPAWN_FADE_FRAMES = 4
M.SPAWN_FADE_DELAY = 0.016
M.UNDO_HISTORY_LIMIT = 50
M.STATUS_EFFECT_INTERVAL_SECONDS = 0.10

return M
end
__modules["lib/board"] = function(loader)
-- Pure 2048 board/game logic. No I/O, no FFI.
local M = {}
local constants = loader("lib/constants")

M.BOARD_SIZE = constants.BOARD_SIZE
M.WIN_VALUE = constants.WIN_VALUE

local BOARD_SIZE = M.BOARD_SIZE

function M.new_empty_board()
  local b = {}
  for r = 1, BOARD_SIZE do
    b[r] = {}
    for c = 1, BOARD_SIZE do
      b[r][c] = 0
    end
  end
  return b
end

function M.copy_board(board)
  local b = {}
  for r = 1, BOARD_SIZE do
    b[r] = {}
    for c = 1, BOARD_SIZE do
      b[r][c] = board[r][c]
    end
  end
  return b
end

function M.boards_equal(a, b)
  for r = 1, BOARD_SIZE do
    for c = 1, BOARD_SIZE do
      if a[r][c] ~= b[r][c] then return false end
    end
  end
  return true
end

local function coord(direction, line_index, k)
  local flip = BOARD_SIZE + 1 - k
  if direction == "left" then
    return line_index, k
  elseif direction == "right" then
    return line_index, flip
  elseif direction == "up" then
    return k, line_index
  elseif direction == "down" then
    return flip, line_index
  else
    error("unknown direction: " .. tostring(direction))
  end
end
M._coord = coord

local function process_line(values)
  local result = {}
  local moves = {}
  local score = 0
  local i, n = 1, #values
  while i <= n do
    local v, k = values[i].value, values[i].k
    if i + 1 <= n and values[i + 1].value == v then
      local v2, k2 = values[i + 1].value, values[i + 1].k
      local new_val = v * 2
      local target = #result + 1
      moves[#moves + 1] = { from_k = k, to_k = target, value = v, merged = false }
      moves[#moves + 1] = { from_k = k2, to_k = target, value = v2, merged = true }
      result[#result + 1] = new_val
      score = score + new_val
      i = i + 2
    else
      local target = #result + 1
      moves[#moves + 1] = { from_k = k, to_k = target, value = v, merged = false }
      result[#result + 1] = v
      i = i + 1
    end
  end
  return result, moves, score
end
M._process_line = process_line

function M.move_board(board, direction)
  local new_board = M.new_empty_board()
  local all_moves = {}
  local total_score = 0

  for line_index = 1, BOARD_SIZE do
    local vals = {}
    for k = 1, BOARD_SIZE do
      local r, c = coord(direction, line_index, k)
      local v = board[r][c]
      if v ~= 0 then
        vals[#vals + 1] = { value = v, k = k }
      end
    end

    local result, moves, score = process_line(vals)
    total_score = total_score + score

    for k, v in ipairs(result) do
      local r, c = coord(direction, line_index, k)
      new_board[r][c] = v
    end

    for _, mv in ipairs(moves) do
      local fr, fc = coord(direction, line_index, mv.from_k)
      local tr, tc = coord(direction, line_index, mv.to_k)
      all_moves[#all_moves + 1] = {
        fr = fr, fc = fc, tr = tr, tc = tc,
        value = mv.value, merged = mv.merged,
      }
    end
  end

  local changed = not M.boards_equal(new_board, board)
  return new_board, all_moves, total_score, changed
end

function M.spawn_tile(board)
  local empties = {}
  for r = 1, BOARD_SIZE do
    for c = 1, BOARD_SIZE do
      if board[r][c] == 0 then
        empties[#empties + 1] = { r, c }
      end
    end
  end
  if #empties == 0 then return nil end
  local pick = empties[math.random(#empties)]
  local r, c = pick[1], pick[2]
  board[r][c] = (math.random() < constants.SPAWN_FOUR_PROBABILITY) and 4 or 2
  return { r = r, c = c, value = board[r][c] }
end

function M.any_move_possible(board)
  for _, d in ipairs({ "left", "right", "up", "down" }) do
    local _, _, _, changed = M.move_board(board, d)
    if changed then return true end
  end
  return false
end

function M.has_won(board)
  for r = 1, BOARD_SIZE do
    for c = 1, BOARD_SIZE do
      if board[r][c] >= M.WIN_VALUE then return true end
    end
  end
  return false
end

function M.compute_status(board)
  if M.has_won(board) then return "won" end
  if not M.any_move_possible(board) then return "game_over" end
  return ""
end

return M
end
__modules["lib/util"] = function()
-- Small color/number helpers.
local M = {}

function M.clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function M.round(x)
  if x >= 0 then
    return math.floor(x + 0.5)
  end
  return -math.floor(-x + 0.5)
end

function M.trunc(x)
  return math.floor(x)
end

function M.bit_length(v)
  local n = 0
  while v > 0 do
    v = math.floor(v / 2)
    n = n + 1
  end
  return n
end

function M.blend(c1, c2, t)
  t = M.clamp(t, 0.0, 1.0)
  return {
    M.trunc(c1[1] + (c2[1] - c1[1]) * t),
    M.trunc(c1[2] + (c2[2] - c1[2]) * t),
    M.trunc(c1[3] + (c2[3] - c1[3]) * t),
  }
end

function M.lighten(c, amount)
  local out = {}
  for i = 1, 3 do
    local v = math.min(1.0, c[i] / 255 + amount)
    out[i] = M.trunc(v * 255)
  end
  return out
end

function M.format_duration(seconds)
  seconds = math.floor(math.max(0, seconds))
  local h = math.floor(seconds / 3600)
  local rem = seconds % 3600
  local m = math.floor(rem / 60)
  local s = rem % 60
  if h > 0 then
    return string.format("%02d:%02d:%02d", h, m, s)
  end
  return string.format("%02d:%02d", m, s)
end

function M.rgb_to_hsv(r, g, b)
  local maxc = math.max(r, g, b)
  local minc = math.min(r, g, b)
  local v = maxc
  if minc == maxc then
    return 0.0, 0.0, v
  end
  local s = (maxc - minc) / maxc
  local rc = (maxc - r) / (maxc - minc)
  local gc = (maxc - g) / (maxc - minc)
  local bc = (maxc - b) / (maxc - minc)
  local h
  if r == maxc then
    h = bc - gc
  elseif g == maxc then
    h = 2.0 + rc - bc
  else
    h = 4.0 + gc - rc
  end
  h = (h / 6.0) % 1.0
  return h, s, v
end

function M.hsv_to_rgb(h, s, v)
  if s == 0.0 then
    return v, v, v
  end
  local i = math.floor(h * 6.0)
  local f = (h * 6.0) - i
  local p = v * (1.0 - s)
  local q = v * (1.0 - s * f)
  local t = v * (1.0 - s * (1.0 - f))
  i = i % 6
  if i == 0 then return v, t, p end
  if i == 1 then return q, v, p end
  if i == 2 then return p, v, t end
  if i == 3 then return p, q, v end
  if i == 4 then return t, p, v end
  return v, p, q
end

return M
end
__modules["lib/color"] = function(loader)
-- Color palettes and tile/text color helpers.
local util = loader("lib/util")

local M = {}

M.PALETTES = {
  classic = {
    board_bg = { 187, 173, 160 },
    empty = { 205, 193, 180 },
    tiles = {
      [2] = { 238, 228, 218 },
      [4] = { 237, 224, 200 },
      [8] = { 242, 177, 121 },
      [16] = { 245, 149, 99 },
      [32] = { 246, 124, 95 },
      [64] = { 246, 94, 59 },
      [128] = { 237, 207, 114 },
      [256] = { 237, 204, 97 },
      [512] = { 237, 200, 80 },
      [1024] = { 237, 197, 63 },
      [2048] = { 237, 194, 46 },
    },
  },
  gradient = {
    board_bg = { 48, 52, 63 },
    empty = { 58, 62, 74 },
    tiles = {
      [2] = { 238, 228, 218 },
      [4] = { 223, 209, 168 },
    },
  },
  ocean = {
    board_bg = { 24, 62, 79 },
    empty = { 34, 78, 97 },
    tiles = {
      [2] = { 224, 247, 250 },
      [4] = { 178, 235, 242 },
    },
  },
}

M._PALETTE_NAMES = { "classic", "gradient", "ocean" }

function M.cycle_palette(current)
  local names = M._PALETTE_NAMES
  current = current or "classic"
  local idx
  for i, name in ipairs(names) do
    if name == current then idx = i break end
  end
  idx = idx or 1
  local next_idx = (idx % #names) + 1
  local next_name = names[next_idx]
  return next_name
end

local function resolve_palette(name)
  name = name or "classic"
  return M.PALETTES[name] or M.PALETTES.classic
end

local function tiles_min_key(tiles)
  local m = nil
  for k in pairs(tiles) do
    if m == nil or k < m then m = k end
  end
  return m
end

local function tiles_max_key(tiles)
  local m = nil
  for k in pairs(tiles) do
    if m == nil or k > m then m = k end
  end
  return m
end

local function extrapolate_color(value, palette)
  local tiles = palette.tiles
  local max_key = tiles_max_key(tiles)
  local max_power = util.bit_length(max_key) - 1
  local power = util.bit_length(value) - 1
  local extra = power - max_power
  local base = tiles[max_key]
  local hue_base, sat_base, val_base = util.rgb_to_hsv(base[1] / 255, base[2] / 255, base[3] / 255)
  local hue = (hue_base - 0.045 * extra) % 1.0
  local sat = math.min(1.0, sat_base + 0.05 * extra)
  local val = math.max(0.25, val_base - 0.05 * extra)
  local r, g, b = util.hsv_to_rgb(hue, sat, val)
  return { util.trunc(r * 255), util.trunc(g * 255), util.trunc(b * 255) }
end

function M.tile_color(value, palette_name)
  local palette = resolve_palette(palette_name)
  local tiles = palette.tiles
  if tiles[value] then return tiles[value] end
  local min_key = tiles_min_key(tiles)
  if value < min_key then return tiles[min_key] end
  return extrapolate_color(value, palette)
end

function M.board_bg_color(palette_name)
  return resolve_palette(palette_name).board_bg
end

function M.empty_color(palette_name)
  return resolve_palette(palette_name).empty
end

function M.text_color(bg)
  local r, g, b = bg[1], bg[2], bg[3]
  local luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
  if luminance > 150 then
    return { 60, 56, 50 }
  end
  return { 249, 246, 242 }
end

return M
end
__modules["lib/game_session"] = function(loader)
-- Shared game state and commands used by both the console and FAR frontends.
-- This module owns game rules around a move (history, score, time and status),
-- while frontends remain responsible for input, rendering and animation.
local board_mod = loader("lib/board")
local color = loader("lib/color")
local constants = loader("lib/constants")

local M = {}
local Session = {}
Session.__index = Session

local function default_new_game(spawn_tile)
  local board = board_mod.new_empty_board()
  spawn_tile(board)
  spawn_tile(board)
  return board
end

local function copy_history_entry(entry)
  return {
    board = board_mod.copy_board(entry.board),
    score = entry.score,
    moves_count = entry.moves_count,
    elapsed_seconds = entry.elapsed_seconds,
    status = entry.status,
    paused = entry.paused,
  }
end

local function normalize_palette(name)
  return color.PALETTES[name] and name or "classic"
end

function M.new(options)
  options = options or {}
  local clock = options.clock or os.clock
  local spawn_tile = options.spawn_tile or board_mod.spawn_tile
  local saved = options.state
  local board = saved and board_mod.copy_board(saved.board) or default_new_game(spawn_tile)

  local self = setmetatable({
    board = board,
    score = saved and (saved.score or 0) or 0,
    best = saved and (saved.best or 0) or 0,
    moves_count = saved and (saved.moves_count or 0) or 0,
    elapsed_seconds = saved and (saved.elapsed_seconds or 0) or 0,
    status = board_mod.compute_status(board),
    palette = normalize_palette(saved and saved.palette),
    history = {},
    paused = false,
    time_segment_start = clock(),
    clock = clock,
    spawn_tile = spawn_tile,
    new_game = options.new_game,
    pending_score = 0,
  }, Session)

  if options.history then
    for _, entry in ipairs(options.history) do
      self.history[#self.history + 1] = copy_history_entry(entry)
    end
  end
  return self
end

function Session:_snapshot_for_history()
  return {
    board = board_mod.copy_board(self.board),
    score = self.score,
    moves_count = self.moves_count,
    elapsed_seconds = self:current_elapsed(),
    status = self.status,
    paused = self.paused,
  }
end

function Session:_push_history()
  self.history[#self.history + 1] = self:_snapshot_for_history()
  if #self.history > constants.UNDO_HISTORY_LIMIT then
    table.remove(self.history, 1)
  end
end

function Session:current_elapsed()
  if self.paused or not self.time_segment_start then
    return self.elapsed_seconds
  end
  return self.elapsed_seconds + (self.clock() - self.time_segment_start)
end

function Session:freeze_time()
  self.elapsed_seconds = self:current_elapsed()
  self.time_segment_start = nil
  return self.elapsed_seconds
end

function Session:resume_time()
  if self.status == "" and not self.paused then
    self.time_segment_start = self.clock()
  end
end

function Session:move(direction)
  if self.paused or self.status ~= "" or self.pending_score > 0 then
    return { changed = false, reason = "inactive" }
  end

  local new_board, moves, gained, changed = board_mod.move_board(self.board, direction)
  if not changed then
    return { changed = false, reason = "unchanged" }
  end

  self:_push_history()
  local spawned_board = board_mod.copy_board(new_board)
  local spawned = self.spawn_tile(spawned_board)

  self.board = spawned_board
  self.pending_score = gained
  self.moves_count = self.moves_count + 1
  self.status = board_mod.compute_status(self.board)
  if self.status ~= "" then
    self:freeze_time()
  end

  return {
    changed = true,
    new_board = new_board,
    spawned_board = spawned_board,
    spawned = spawned,
    moves = moves,
    gained = gained,
    status = self.status,
  }
end

function Session:settle_score()
  local gained = self.pending_score
  if gained > 0 then
    self.score = self.score + gained
    self.best = math.max(self.best, self.score)
    self.pending_score = 0
  end
  return gained
end

function Session:has_pending_score()
  return self.pending_score > 0
end

function Session:restart()
  if self:has_pending_score() then return false end
  self:_push_history()
  self.board = self.new_game and self.new_game() or default_new_game(self.spawn_tile)
  self.score = 0
  self.pending_score = 0
  self.moves_count = 0
  self.elapsed_seconds = 0
  self.status = board_mod.compute_status(self.board)
  self.paused = false
  self.time_segment_start = self.clock()
end

function Session:undo()
  if self:has_pending_score() then return false end
  local entry = table.remove(self.history)
  if not entry then return false end

  self.board = board_mod.copy_board(entry.board)
  self.score = entry.score
  self.pending_score = 0
  self.moves_count = entry.moves_count
  self.elapsed_seconds = entry.elapsed_seconds
  self.status = board_mod.compute_status(self.board)
  self.paused = entry.paused or false
  self.time_segment_start = nil
  if self.status == "" and not self.paused then
    self.time_segment_start = self.clock()
  end
  return true
end

function Session:set_paused(paused)
  paused = not not paused
  if self.paused == paused then return end
  if paused then
    self:freeze_time()
    self.paused = true
  else
    self.paused = false
    self:resume_time()
  end
end

function Session:cycle_palette()
  self.palette = color.cycle_palette(self.palette)
  return self.palette
end

function Session:snapshot()
  return {
    board = board_mod.copy_board(self.board),
    score = self.score,
    best = self.best,
    moves_count = self.moves_count,
    status = self.status,
    palette = self.palette,
    elapsed_seconds = self:current_elapsed(),
  }
end

function Session:can_undo()
  return #self.history > 0
end

M.Session = Session
return M
end
__modules["lib/geometry"] = function(loader)
-- Board layout geometry.
local util = loader("lib/util")
local constants = loader("lib/constants")

local M = {}

M.CHAR_ASPECT = constants.GEOMETRY_CHAR_ASPECT
M.UNIT = constants.GEOMETRY_UNIT

function M.compute_cell_dimensions(unit, char_aspect)
  local h = unit
  local w = math.max(3, util.round(h * char_aspect))
  if h % 2 == 0 then h = h + 1 end
  return w, h
end

function M.compute_gaps(unit)
  -- Keep the visual separation between tiles fixed when tile size changes.
  local gap_y = unit % 2 == 0 and 0 or 1
  return 2, gap_y
end

M.CELL_W, M.CELL_H = M.compute_cell_dimensions(M.UNIT, M.CHAR_ASPECT)
M.GAP_X, M.GAP_Y = M.compute_gaps(M.UNIT)

M.BOARD_W = constants.BOARD_SIZE * M.CELL_W + (constants.BOARD_SIZE + 1) * M.GAP_X
M.BOARD_H = constants.BOARD_SIZE * M.CELL_H + (constants.BOARD_SIZE + 1) * M.GAP_Y

return M
end
__modules["lib/tile_canvas"] = function(loader)
-- Platform-neutral tile rasterizer.
--
-- The console and FAR backends consume the same 2D cell buffer.  This module
-- owns board geometry and tile painting; platform backends only serialize or
-- blit the resulting cells.
local geometry = loader("lib/geometry")
local color = loader("lib/color")
local util = loader("lib/util")

local constants = loader("lib/constants")
local BOARD_SIZE = constants.BOARD_SIZE
local CELL_W, CELL_H = geometry.CELL_W, geometry.CELL_H
local GAP_X, GAP_Y = geometry.GAP_X, geometry.GAP_Y
local BOARD_W, BOARD_H = geometry.BOARD_W, geometry.BOARD_H
local LOWER_HALF = "\xe2\x96\x84"
local UPPER_HALF = "\xe2\x96\x80"

local M = {}

local BLACK = { 0, 0, 0 }

local function same_color(a, b)
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

local function cell_halves(cell)
  if cell[1] == UPPER_HALF then return cell[2], cell[3] end
  if cell[1] == LOWER_HALF then return cell[3], cell[2] end
  return cell[3], cell[3]
end

local function paint_half(buf, half_y, x, bg)
  local y = math.floor(half_y / 2)
  local cell = buf[y + 1][x + 1]
  local top, bottom = cell_halves(cell)
  if half_y % 2 == 0 then top = bg else bottom = bg end
  buf[y + 1][x + 1] = same_color(top, bottom) and { " ", nil, top } or { UPPER_HALF, top, bottom }
end

function M.new_buffer(bg)
  local buf = {}
  for y = 1, BOARD_H do
    local row = {}
    for x = 1, BOARD_W do
      row[x] = { " ", nil, bg }
    end
    buf[y] = row
  end
  return buf
end

function M.fill_empty_cells(buf, empty_bg)
  for r = 0, BOARD_SIZE - 1 do
    for c = 0, BOARD_SIZE - 1 do
      local x0 = GAP_X + c * (CELL_W + GAP_X)
      local y0 = GAP_Y + r * (CELL_H + GAP_Y)
      for yy = 0, CELL_H - 1 do
        for xx = 0, CELL_W - 1 do
          buf[y0 + yy + 1][x0 + xx + 1] = { " ", nil, empty_bg }
        end
      end
    end
  end
end

function M.draw_tile(buf, tile, empty_bg, palette, fade)
  local alpha = tile.alpha or 1.0
  local bg = tile.bg or color.tile_color(tile.value, palette)
  if alpha < 1.0 then
    bg = util.blend(empty_bg, bg, alpha)
  end
  local fg = tile.fg or color.text_color(bg)
  if fade and fade > 0 then
    bg = util.blend(bg, { 0, 0, 0 }, fade)
    fg = util.blend(fg, { 0, 0, 0 }, fade)
  end

  local x = GAP_X + tile.col * (CELL_W + GAP_X)
  local y = GAP_Y + tile.row * (CELL_H + GAP_Y)
  local ix = math.max(0, math.min(BOARD_W - CELL_W, util.round(x)))
  local iy = math.max(0, math.min(BOARD_H - CELL_H, util.round(y)))
  local text_row
  if constants.HALF_STEP_ANIMATION then
    local start_half = math.max(0, math.min(BOARD_H * 2 - CELL_H * 2, util.round(2 * y)))
    for half_y = start_half, start_half + CELL_H * 2 - 1 do
      for xx = 0, CELL_W - 1 do paint_half(buf, half_y, ix + xx, bg) end
    end
    text_row = math.floor((start_half + CELL_H) / 2)
  else
    for yy = 0, CELL_H - 1 do
      for xx = 0, CELL_W - 1 do buf[iy + yy + 1][ix + xx + 1] = { " ", nil, bg } end
    end
    text_row = iy + math.floor(CELL_H / 2)
  end

  local text = tostring(tile.value)
  local text_col = ix + math.max(0, math.floor((CELL_W - #text) / 2))
  for i = 1, #text do
    local col = text_col + (i - 1)
    if col >= 0 and col < BOARD_W then
      buf[text_row + 1][col + 1] = { text:sub(i, i), fg, bg }
    end
  end
end

-- Rasterizes a logical tile list into the shared 2D cell buffer. Platform
-- backends call this once, then serialize or blit the returned cells.
function M.rasterize(tiles, opts)
  opts = opts or {}
  local palette = opts.palette
  local fade = opts.fade or 0
  local board_bg = opts.board_tint or color.empty_color(palette)
  local empty_bg = board_bg
  if fade > 0 then
    empty_bg = util.blend(board_bg, BLACK, fade)
  end

  local buf = M.new_buffer(empty_bg)
  M.fill_empty_cells(buf, empty_bg)
  for _, tile in ipairs(tiles or {}) do
    M.draw_tile(buf, tile, empty_bg, palette, fade)
  end
  return buf
end

return M
end
__modules["console/render"] = function(loader)
-- ANSI-truecolor rendering of the board to a string, built to stdout.
local geometry = loader("lib/geometry")
local color = loader("lib/color")
local util = loader("lib/util")
local canvas = loader("lib/tile_canvas")

local CELL_W, CELL_H = geometry.CELL_W, geometry.CELL_H
local GAP_X, GAP_Y = geometry.GAP_X, geometry.GAP_Y
local BOARD_W, BOARD_H = geometry.BOARD_W, geometry.BOARD_H

local M = {}
M.OUTER_RESET = "\x1b[0m"

-- U+23F8 PAUSE SYMBOL as raw UTF-8 bytes (LuaJIT has no \uXXXX escape).
local PAUSE_SYMBOL = "\xe2\x8f\xb8"

local function render_buffer(buf)
  local lines = {}
  for y = 1, BOARD_H do
    local row = buf[y]
    local parts = {}
    local run_chars = {}
    local cur_fg, cur_bg = "__unset__", "__unset__"

    local function flush_run()
      if #run_chars > 0 then
        parts[#parts + 1] = table.concat(run_chars)
        run_chars = {}
      end
    end

    for x = 1, BOARD_W do
      local ch, fg, bg = row[x][1], row[x][2], row[x][3]
      local fg_key = fg and table.concat(fg, ",") or "nil"
      local bg_key = bg and table.concat(bg, ",") or "nil"
      if fg_key ~= cur_fg or bg_key ~= cur_bg then
        flush_run()
        local code = "\x1b[0m"
        if bg then
          code = code .. string.format("\x1b[48;2;%d;%d;%dm", bg[1], bg[2], bg[3])
        end
        if fg then
          code = code .. string.format("\x1b[38;2;%d;%d;%dm", fg[1], fg[2], fg[3])
        end
        parts[#parts + 1] = code
        cur_fg, cur_bg = fg_key, bg_key
      end
      run_chars[#run_chars + 1] = ch
    end
    flush_run()
    parts[#parts + 1] = "\x1b[0m\x1b[K"
    lines[#lines + 1] = table.concat(parts)
  end
  return table.concat(lines, "\n")
end

local function center_text(text, width)
  local pad = math.max(0, width - #text)
  local left = math.floor(pad / 2)
  local right = pad - left
  return string.rep(" ", left) .. text .. string.rep(" ", right)
end

local function centered_styled_line(parts, width)
  local visible = {}
  for _, part in ipairs(parts) do
    visible[#visible + 1] = part.text
  end
  local text = table.concat(visible)
  local pad = math.max(0, width - #text)
  local left = math.floor(pad / 2)
  local right = pad - left
  local out = { string.rep(" ", left) }
  for _, part in ipairs(parts) do
    out[#out + 1] = part.style or ""
    out[#out + 1] = part.text
    out[#out + 1] = "\x1b[0m"
  end
  out[#out + 1] = string.rep(" ", right)
  out[#out + 1] = "\x1b[K"
  return table.concat(out)
end

function M.render_frame(opts)
  local tiles = opts.tiles
  local score = opts.score
  local score_delta = opts.score_delta or 0
  if score_delta > 0 then score = string.format("%d +%d", score, score_delta) end
  local best = opts.best
  local moves_count = opts.moves_count
  local elapsed_seconds = opts.elapsed_seconds
  local status_text = opts.status_text or ""
  local status_color = opts.status_color
  local board_tint = opts.board_tint
  local fade = opts.fade or 0
  local blink = opts.blink or false
  local sparkles = opts.sparkles
  local paused = opts.paused or false
  local palette = opts.palette
  local empty_bg = board_tint or color.empty_color(palette)

  local buf = canvas.rasterize(tiles, {
    board_tint = board_tint,
    fade = fade,
    palette = palette,
  })

  if sparkles then
    for _, sp in ipairs(sparkles) do
      local r, c = sp.rc[1], sp.rc[2]
      local sp_color, ch = sp.color, sp.ch
      local x0 = GAP_X + c * (CELL_W + GAP_X)
      local y0 = GAP_Y + r * (CELL_H + GAP_Y)
      local cx = x0 + math.floor(CELL_W / 2)
      local cy = y0 + math.floor(CELL_H / 2)
      buf[cy + 1][cx + 1] = { ch, sp_color, empty_bg }
    end
  end

  local board_str = render_buffer(buf)

  local time_label = util.format_duration(elapsed_seconds) .. (paused and (" " .. PAUSE_SYMBOL) or "")
  local dim = "\x1b[38;2;150;150;150m"
  local header_lines = {
    centered_styled_line({
      { text = "2 0 4 8", style = "\x1b[1m\x1b[38;2;90;200;250m" },
      { text = "   Score: ", style = dim },
      { text = tostring(score), style = "\x1b[1m\x1b[38;2;255;215;0m" },
      { text = "   Best: ", style = dim },
      { text = tostring(best), style = "\x1b[38;2;180;180;180m" },
    }, BOARD_W),
    centered_styled_line({
      { text = "Moves: ", style = dim },
      { text = tostring(moves_count), style = "\x1b[38;2;150;200;150m" },
      { text = "   Time: ", style = dim },
      { text = time_label, style = "\x1b[38;2;180;200;255m" },
      { text = "   Palette: ", style = dim },
      { text = palette or "classic", style = "\x1b[38;2;150;170;220m" },
    }, BOARD_W),
  }

  local footer_lines = {
    centered_styled_line({
      { text = "Arrows/WASD: move", style = dim },
      { text = "   U: undo", style = dim },
      { text = "   P: palette", style = dim },
    }, BOARD_W),
    centered_styled_line({
      { text = "Space: pause", style = dim },
      { text = "   R: restart", style = dim },
      { text = "   Q: quit", style = dim },
    }, BOARD_W),
  }

  if status_text ~= "" then
    local sc = status_color or { 255, 80, 80 }
    footer_lines[#footer_lines + 1] = string.format(
      "\x1b[1m%s\x1b[38;2;%d;%d;%dm%s\x1b[0m\x1b[K",
      blink and "\x1b[5m" or "", sc[1], sc[2], sc[3], center_text(status_text, BOARD_W))
  else
    footer_lines[#footer_lines + 1] = "\x1b[K"
  end

  local out = {
    "\x1b[H", header_lines[1], header_lines[2], "\x1b[K", board_str, "",
  }
  for _, l in ipairs(footer_lines) do out[#out + 1] = l end
  out[#out + 1] = "\x1b[J"

  io.write(table.concat(out, "\n"))
  io.flush()
end

return M
end
__modules["lib/tiles"] = function(loader)
-- Platform-neutral conversion from a board matrix to renderable tile records.
local board_mod = loader("lib/board")

local M = {}

function M.board_to_tiles(board)
  local tiles = {}
  for r = 1, board_mod.BOARD_SIZE do
    for c = 1, board_mod.BOARD_SIZE do
      if board[r][c] ~= 0 then
        tiles[#tiles + 1] = { row = r - 1, col = c - 1, value = board[r][c] }
      end
    end
  end
  return tiles
end

return M
end
__modules["lib/animation_fsm"] = function(loader)
-- Frame-advancing state machines for slide/merge/spawn animations.
--
-- Unlike console/animation.lua (which owns a blocking loop calling render+sleep
-- itself -- fine for the console backend, which owns its own main loop),
-- these state machines do neither rendering nor sleeping. They only compute
-- "what should the tile list look like at frame N" and let the CALLER
-- decide when to advance and when/how to render.
--
-- This split exists specifically for platforms where WE do not own the
-- main loop -- e.g. FAR Manager, where far.DialogRun() owns it and our
-- code only runs reactively (DN_DRAWDLGITEM, a far.Timer callback, or
-- DN_INPUT). The FAR frontend configures how many frames one external
-- "tick" advances.

local color = loader("lib/color")
local util = loader("lib/util")
local constants = loader("lib/constants")
local geometry = loader("lib/geometry")

local BOARD_SIZE = constants.BOARD_SIZE
local ROW_STEPS_PER_CELL = geometry.CELL_H + geometry.GAP_Y

local M = {}

local function ease_out_cubic(t)
  return 1 - (1 - t) ^ 3
end
M.ease_out_cubic = ease_out_cubic

function M.next_frame_delay(deadline, now, remaining_steps, render_seconds)
  if remaining_steps <= 0 then return 0 end
  return math.max(0, (deadline - now) / remaining_steps - (render_seconds or 0))
end

-- ---------------------------------------------------------------------
-- Slide phase state machine
-- ---------------------------------------------------------------------

local SlideFSM = {}
SlideFSM.__index = SlideFSM

-- moves: array of {fr, fc, tr, tc, value, merged} with 1-based board coords.
function M.new_slide(moves)
  local max_vertical_distance = 0
  for _, mv in ipairs(moves) do
    max_vertical_distance = math.max(max_vertical_distance, math.abs(mv.tr - mv.fr))
  end
  local vertical_steps = constants.HALF_STEP_ANIMATION and ROW_STEPS_PER_CELL * 2 or ROW_STEPS_PER_CELL
  return setmetatable({
    moves = moves,
    step = 0,
    vertical = max_vertical_distance > 0,
    vertical_steps = vertical_steps,
    total_steps = max_vertical_distance > 0 and max_vertical_distance * vertical_steps or constants.ANIM_FRAMES,
    done = (#moves == 0),
  }, SlideFSM)
end

-- Advance by n frames (default 1). Returns self for chaining.
function SlideFSM:advance(n)
  n = n or 1
  if self.done then return self end
  self.step = math.min(self.total_steps, self.step + n)
  if self.step >= self.total_steps then
    self.done = true
  end
  return self
end

-- Returns the tile list to render for the current frame (0-based row/col).
function SlideFSM:tiles()
  local out = {}
  for _, mv in ipairs(self.moves) do
    local row, col
    if self.vertical then
      local distance = math.abs(mv.tr - mv.fr) * self.vertical_steps
      local direction = mv.tr >= mv.fr and 1 or -1
      row = (mv.fr - 1) + direction * math.min(self.step, distance) / self.vertical_steps
      col = mv.fc - 1
    else
      local t = ease_out_cubic(self.step / self.total_steps)
      row = (mv.fr - 1) + ((mv.tr - 1) - (mv.fr - 1)) * t
      col = (mv.fc - 1) + ((mv.tc - 1) - (mv.fc - 1)) * t
    end
    out[#out + 1] = { row = row, col = col, value = mv.value }
  end
  return out
end

function SlideFSM:is_done()
  return self.done
end

-- ---------------------------------------------------------------------
-- Merge-pop phase state machine
-- ---------------------------------------------------------------------

local MergePopFSM = {}
MergePopFSM.__index = MergePopFSM

local FLASH_COLOR = { 255, 255, 255 }

-- board: post-move board (1-based). moves: same shape as above.
function M.new_merge_pop(board, moves, palette)
  local merge_targets = {}
  local merge_target_coords = {}
  for _, mv in ipairs(moves) do
    if mv.merged then
      local key = mv.tr .. "," .. mv.tc
      if not merge_targets[key] then
        merge_target_coords[#merge_target_coords + 1] = { mv.tr, mv.tc }
      end
      merge_targets[key] = mv.value
    end
  end

  local static_tiles = {}
  for r = 1, BOARD_SIZE do
    for c = 1, BOARD_SIZE do
      local key = r .. "," .. c
      if board[r][c] ~= 0 and merge_targets[key] == nil then
        static_tiles[#static_tiles + 1] = { row = r - 1, col = c - 1, value = board[r][c] }
      end
    end
  end

  return setmetatable({
    board = board,
    palette = palette,
    merge_targets = merge_targets,
    merge_target_coords = merge_target_coords,
    static_tiles = static_tiles,
    step = 0,
    total_steps = constants.MERGE_POP_FRAMES,
    done = (#merge_target_coords == 0),
  }, MergePopFSM)
end

function MergePopFSM:advance(n)
  n = n or 1
  if self.done then return self end
  self.step = math.min(self.total_steps, self.step + n)
  if self.step >= self.total_steps then
    self.done = true
  end
  return self
end

function MergePopFSM:tiles()
  local t = self.step / self.total_steps
  local bump = math.sin(math.pi * t) * 0.18
  local out = {}
  for _, tile in ipairs(self.static_tiles) do out[#out + 1] = tile end

  for _, rc in ipairs(self.merge_target_coords) do
    local r, c = rc[1], rc[2]
    local old_value = self.merge_targets[r .. "," .. c]
    local new_value = self.board[r][c]
    local old_bg = color.tile_color(old_value, self.palette)
    local new_bg = color.tile_color(new_value, self.palette)
    local bg = util.blend(old_bg, new_bg, t)
    bg = util.lighten(bg, bump)
    local normal_fg = color.text_color(bg)
    local fg = util.blend(FLASH_COLOR, normal_fg, t)
    out[#out + 1] = { row = r - 1, col = c - 1, value = new_value, bg = bg, fg = fg }
  end
  return out
end

function MergePopFSM:is_done()
  return self.done
end

-- ---------------------------------------------------------------------
-- Spawn fade-in phase state machine
-- ---------------------------------------------------------------------

local SpawnFadeFSM = {}
SpawnFadeFSM.__index = SpawnFadeFSM

-- board: post-move+spawn board (1-based). spawned: {r, c, value} (1-based).
function M.new_spawn_fade(board, spawned, palette)
  return setmetatable({
    board = board,
    spawned = spawned,
    palette = palette,
    step = 0,
    total_steps = constants.SPAWN_FADE_FRAMES,
    done = false,
  }, SpawnFadeFSM)
end

function SpawnFadeFSM:advance(n)
  n = n or 1
  if self.done then return self end
  self.step = math.min(self.total_steps, self.step + n)
  if self.step >= self.total_steps then
    self.done = true
  end
  return self
end

function SpawnFadeFSM:tiles()
  local alpha = self.step / self.total_steps
  local sr, sc, sval = self.spawned.r, self.spawned.c, self.spawned.value
  local out = {}
  for r = 1, BOARD_SIZE do
    for c = 1, BOARD_SIZE do
      if self.board[r][c] ~= 0 then
        if r == sr and c == sc then
          out[#out + 1] = { row = r - 1, col = c - 1, value = sval, alpha = alpha }
        else
          out[#out + 1] = { row = r - 1, col = c - 1, value = self.board[r][c] }
        end
      end
    end
  end
  return out
end

function SpawnFadeFSM:is_done()
  return self.done
end

-- ---------------------------------------------------------------------
-- Sequence helper: chain slide -> merge_pop -> spawn_fade as one object,
-- so callers (e.g. the FAR timer handler) can advance a single "move
-- animation" without caring which phase is currently active.
-- ---------------------------------------------------------------------

local MoveAnimation = {}
MoveAnimation.__index = MoveAnimation

-- new_board: board after the move (pre-spawn). moves: from move_board().
-- spawned_board/spawned: board+tile after spawn_tile() was applied.
function M.new_move_animation(new_board, moves, spawned_board, spawned, palette)
  local phases = {}
  phases[#phases + 1] = M.new_slide(moves)
  phases[#phases + 1] = M.new_merge_pop(new_board, moves, palette)
  if spawned then
    phases[#phases + 1] = M.new_spawn_fade(spawned_board, spawned, palette)
  end
  return setmetatable({
    phases = phases,
    phase_idx = 1,
  }, MoveAnimation)
end

-- Advances the currently-active phase by n frames. If that phase
-- finishes mid-advance, does NOT automatically spill remaining frames
-- into the next phase -- keeps frame accounting simple and predictable
-- (one external tick advances at most one phase's worth of progress).
function MoveAnimation:advance(n)
  local phase = self.phases[self.phase_idx]
  if not phase then return self end
  phase:advance(n)
  while phase:is_done() and self.phase_idx < #self.phases do
    self.phase_idx = self.phase_idx + 1
    phase = self.phases[self.phase_idx]
  end
  return self
end

function MoveAnimation:tiles()
  local phase = self.phases[self.phase_idx]
  if not phase then return {} end
  return phase:tiles()
end

function MoveAnimation:is_done()
  local last = self.phases[#self.phases]
  return self.phase_idx == #self.phases and last:is_done()
end

return M
end
__modules["console/winapi"] = function()
-- Windows console backend: FFI bindings, timing, and raw keyboard bytes.
local ffi = require("ffi")
local bit = require("bit")

if ffi.os ~= "Windows" then
  error("winapi.lua only supports Windows (ffi.os == '" .. ffi.os .. "')")
end

ffi.cdef([[
typedef int BOOL;
typedef unsigned long DWORD;
typedef void *HANDLE;

BOOL GetConsoleMode(HANDLE hConsoleHandle, DWORD *lpMode);
BOOL SetConsoleMode(HANDLE hConsoleHandle, DWORD dwMode);
BOOL SetConsoleOutputCP(unsigned int wCodePageID);
HANDLE GetStdHandle(DWORD nStdHandle);
void Sleep(DWORD dwMilliseconds);
BOOL QueryPerformanceCounter(int64_t *lpPerformanceCount);
BOOL QueryPerformanceFrequency(int64_t *lpFrequency);
int _kbhit(void);
int _getch(void);
]])

local C = ffi.C
local M = { is_windows = true }
local STD_OUTPUT_HANDLE = -11
local ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004

function M.prepare()
  C.SetConsoleOutputCP(65001)
  local handle = C.GetStdHandle(STD_OUTPUT_HANDLE)
  local mode = ffi.new("DWORD[1]")
  if C.GetConsoleMode(handle, mode) == 0 then return end
  C.SetConsoleMode(handle, bit.bor(mode[0], ENABLE_VIRTUAL_TERMINAL_PROCESSING))
end

function M.restore() return true end

function M.sleep(seconds)
  C.Sleep(math.floor(seconds * 1000 + 0.5))
end

local qpc_freq = ffi.new("int64_t[1]")
C.QueryPerformanceFrequency(qpc_freq)
local freq = tonumber(qpc_freq[0])

function M.now()
  local counter = ffi.new("int64_t[1]")
  C.QueryPerformanceCounter(counter)
  return tonumber(counter[0]) / freq
end

function M.kbhit()
  return C._kbhit() ~= 0
end

function M.flush_input()
  while C._kbhit() ~= 0 do C._getch() end
end

function M.read_byte(_)
  return C._getch()
end

return M
end
__modules["console/linuxapi"] = function()
-- Linux console backend: libc timing, polling, and terminal raw mode.
local ffi = require("ffi")

if ffi.os ~= "Linux" then
  error("linuxapi.lua only supports Linux (ffi.os == '" .. ffi.os .. "')")
end

ffi.cdef([[
typedef unsigned long nfds_t;
typedef long ssize_t;
struct pollfd { int fd; short events; short revents; };
struct timespec { long tv_sec; long tv_nsec; };
int poll(struct pollfd *fds, nfds_t nfds, int timeout);
ssize_t read(int fd, void *buf, size_t count);
int usleep(unsigned int usec);
int clock_gettime(int clk_id, struct timespec *tp);
]])

local C = ffi.C
local M = { is_windows = false }
local POLLIN = 0x0001
local CLOCK_MONOTONIC = 1
local pollfd = ffi.new("struct pollfd[1]")
local buffer = ffi.new("uint8_t[1]")
pollfd[0].fd = 0
pollfd[0].events = POLLIN
local saved_state

local function succeeded(result)
  return result == true or result == 0
end

function M.prepare()
  local pipe = io.popen("stty -g 2>/dev/null")
  local state = pipe and pipe:read("*l")
  if pipe then pipe:close() end
  if not state or not state:match("^[%da-fA-F:]+$") then
    error("console frontend requires an interactive TTY (stty -g failed)")
  end
  saved_state = state
  if not succeeded(os.execute("stty -echo -icanon min 0 time 0 2>/dev/null")) then
    error("console frontend could not enable raw terminal input")
  end
end

function M.restore()
  if not saved_state then return true end
  local state = saved_state
  saved_state = nil
  if not succeeded(os.execute("stty " .. state .. " 2>/dev/null")) then
    return nil, "could not restore terminal settings"
  end
  return true
end

function M.sleep(seconds)
  C.usleep(math.floor(math.max(seconds, 0) * 1000000 + 0.5))
end

function M.now()
  local ts = ffi.new("struct timespec[1]")
  assert(C.clock_gettime(CLOCK_MONOTONIC, ts) == 0, "clock_gettime failed")
  return tonumber(ts[0].tv_sec) + tonumber(ts[0].tv_nsec) / 1000000000
end

function M.kbhit()
  return C.poll(pollfd, 1, 0) > 0
end

function M.flush_input()
  while M.kbhit() do
    if C.read(0, buffer, 1) ~= 1 then break end
  end
end

function M.read_byte(timeout_ms)
  if C.poll(pollfd, 1, timeout_ms) <= 0 then return nil end
  if C.read(0, buffer, 1) ~= 1 then return nil end
  return tonumber(buffer[0])
end

return M
end
__modules["console/platform"] = function(loader)
-- Shared console facade: ANSI screen control and key decoding stay portable.
local ffi = require("ffi")

local backend
if ffi.os == "Windows" then
  backend = loader("console/winapi")
elseif ffi.os == "Linux" then
  backend = loader("console/linuxapi")
else
  error("console frontend supports only Windows and Linux (ffi.os == '" .. ffi.os .. "')")
end

local M = {}
local KEY_MAP = {
  [string.byte("w")] = "up", [string.byte("W")] = "up",
  [string.byte("a")] = "left", [string.byte("A")] = "left",
  [string.byte("s")] = "down", [string.byte("S")] = "down",
  [string.byte("d")] = "right", [string.byte("D")] = "right",
  [string.byte("u")] = "undo", [string.byte("U")] = "undo",
  [string.byte("p")] = "palette", [string.byte(" ")] = "pause",
  [string.byte("r")] = "restart", [string.byte("R")] = "restart",
  [string.byte("q")] = "quit", [string.byte("Q")] = "quit", [0x1b] = "quit",
}
local WINDOWS_ARROWS = { [0x48] = "up", [0x50] = "down", [0x4b] = "left", [0x4d] = "right" }
local LINUX_ARROWS = { [0x41] = "up", [0x42] = "down", [0x43] = "right", [0x44] = "left" }

function M.prepare_console() return backend.prepare() end
function M.restore_console() return backend.restore() end

function M.enter_alternate_screen()
  io.write("\x1b[?1049h\x1b[H")
  io.flush()
end

function M.leave_alternate_screen()
  io.write("\x1b[?1049l")
  io.flush()
end

function M.sleep(seconds) return backend.sleep(seconds) end
function M.now() return backend.now() end
function M.now() return backend.now() end
function M.now() return backend.now() end
function M.kbhit() return backend.kbhit() end
function M.flush_input() return backend.flush_input() end
function M.read_byte(timeout_ms) return backend.read_byte(timeout_ms == nil and -1 or timeout_ms) end

function M._decode_key(first_byte, read_next)
  if first_byte == nil then return nil end
  if backend.is_windows and (first_byte == 0xe0 or first_byte == 0x00) then
    return WINDOWS_ARROWS[read_next(-1)]
  end
  if not backend.is_windows and first_byte == 0x1b then
    local prefix = read_next(25)
    if prefix ~= 0x5b and prefix ~= 0x4f then return "quit" end
    return LINUX_ARROWS[read_next(25)] or "quit"
  end
  return KEY_MAP[first_byte]
end

function M.read_key()
  return M._decode_key(backend.read_byte(-1), backend.read_byte)
end

return M
end
__modules["console/animation"] = function(loader)
-- Blocking console driver for animation_fsm.lua.
-- The FSM owns frame calculation; this module only advances it and renders.
local animation_fsm = loader("lib/animation_fsm")
local render = loader("console/render")
local platform = loader("console/platform")
local constants = loader("lib/constants")

local M = {}

local function play_phase(phase, stats, palette, delay, duration)
  local deadline = duration and platform.now() + duration
  while not phase:is_done() do
    phase:advance(1)
    local tiles = phase:tiles()
    local render_started = platform.now()
    render.render_frame({
      tiles = tiles,
      score = stats.score,
      score_delta = stats.score_delta,
      best = stats.best,
      moves_count = stats.moves_count,
      elapsed_seconds = stats.elapsed_seconds,
      palette = palette,
    })
    local remaining = phase.total_steps - phase.step
    if duration and remaining > 0 then
      platform.sleep(animation_fsm.next_frame_delay(deadline, platform.now(), remaining,
        platform.now() - render_started))
    elseif not duration then
      platform.sleep(delay)
    end
  end
end

function M.play_move(new_board, moves, spawned_board, spawned, stats, palette)
  local animation = animation_fsm.new_move_animation(
    new_board, moves, spawned_board, spawned, palette
  )
  local delays = {
    constants.ANIM_FRAME_DELAY,
    constants.MERGE_POP_DELAY,
    constants.SPAWN_FADE_DELAY,
  }
  while not animation:is_done() do
    local phase = animation.phases[animation.phase_idx]
    play_phase(phase, stats, palette, delays[animation.phase_idx],
      animation.phase_idx == 1 and constants.SLIDE_DURATION_SECONDS or nil)
    animation:advance(0)
  end
end

function M.animate_slide(moves, score, best, moves_count, elapsed_seconds, palette)
  local phase = animation_fsm.new_slide(moves)
  play_phase(phase, {
    score = score, best = best, moves_count = moves_count,
    elapsed_seconds = elapsed_seconds,
  }, palette, constants.ANIM_FRAME_DELAY, constants.SLIDE_DURATION_SECONDS)
end

function M.animate_merge_pop(board, moves, score, best, moves_count, elapsed_seconds, palette)
  local phase = animation_fsm.new_merge_pop(board, moves, palette)
  play_phase(phase, {
    score = score, best = best, moves_count = moves_count,
    elapsed_seconds = elapsed_seconds,
  }, palette, constants.MERGE_POP_DELAY)
end

function M.animate_spawn_fadein(board, spawned, score, best, moves_count, elapsed_seconds, palette)
  local phase = animation_fsm.new_spawn_fade(board, spawned, palette)
  play_phase(phase, {
    score = score, best = best, moves_count = moves_count,
    elapsed_seconds = elapsed_seconds,
  }, palette, constants.SPAWN_FADE_DELAY)
end

return M
end
__modules["console/config"] = function(loader)
local M = {}
local constants = loader("lib/constants")

M.END_SCREEN_TICK = constants.STATUS_EFFECT_INTERVAL_SECONDS
M.IDLE_POLL_DELAY = 0.05

return M
end
__modules["lib/status_effect"] = function(loader)
-- Shared visual effects for terminal states and pause.
local color = loader("lib/color")
local util = loader("lib/util")

local M = {}

function M.compute(status, paused, palette, time)
  time = time or 0
  if status == "game_over" then
    local board_bg = color.board_bg_color(palette)
    local pulse = 0.20 + 0.15 * (0.5 + 0.5 * math.sin(time * 3.0))
    return { board_tint = util.blend(board_bg, { 140, 25, 25 }, pulse), fade = 0, blink = true }
  end
  if status == "won" then
    local board_bg = color.board_bg_color(palette)
    local pulse = 0.10 + 0.10 * (0.5 + 0.5 * math.sin(time * 2.0))
    return { board_tint = util.blend(board_bg, { 255, 200, 60 }, pulse), fade = 0, blink = true }
  end
  if paused then
    return { board_tint = nil, fade = 0.55, blink = true }
  end
  return { board_tint = nil, fade = 0, blink = false }
end

return M
end
__modules["console/screens"] = function(loader)
-- End-of-game / pause screens (console backend, blocking loops).
local render = loader("console/render")
local tiles_mod = loader("lib/tiles")
local util = loader("lib/util")
local platform = loader("console/platform")
local constants = loader("lib/constants")
local config = loader("console/config")
local status_effect = loader("lib/status_effect")

local M = {}

local function read_key()
  local key = platform.read_key()
  platform.flush_input()
  return key
end

function M.game_over_screen(board, score, best, moves_count, elapsed_seconds, can_undo, palette)
  local tiles = tiles_mod.board_to_tiles(board)
  local start = platform.now()
  while true do
    if platform.kbhit() then
      local key = read_key()
      if key == "undo" and can_undo then return "undo" end
      if key == "restart" or key == "quit" then return key end
    end
    local t = platform.now() - start
    local effect = status_effect.compute("game_over", false, palette, t)
    render.render_frame({
      tiles = tiles, score = score, best = best, moves_count = moves_count,
      elapsed_seconds = elapsed_seconds, status_text = "GAME OVER",
      status_color = { 255, 90, 90 }, board_tint = effect.board_tint, fade = effect.fade,
      blink = effect.blink,
      palette = palette,
    })
    platform.sleep(config.END_SCREEN_TICK)
  end
end

function M.win_screen(board, score, best, moves_count, elapsed_seconds, can_undo, palette)
  local tiles = tiles_mod.board_to_tiles(board)
  local BOARD_SIZE = constants.BOARD_SIZE
  local empties = {}
  for r = 1, BOARD_SIZE do
    for c = 1, BOARD_SIZE do
      if board[r][c] == 0 then empties[#empties + 1] = { r - 1, c - 1 } end
    end
  end
  local sparkle_chars = { "*", "+", "." }
  local start = platform.now()
  while true do
    if platform.kbhit() then
      local key = read_key()
      if key == "undo" and can_undo then return "undo" end
      if key == "restart" or key == "quit" then return key end
    end
    local t = platform.now() - start
    local effect = status_effect.compute("won", false, palette, t)
    local hue = (t * 0.25) % 1.0
    local r, g, b = util.hsv_to_rgb(hue, 0.75, 1.0)
    local msg_color = { util.trunc(r * 255), util.trunc(g * 255), util.trunc(b * 255) }

    local sparkles = {}
    for _, rc in ipairs(empties) do
      if math.random() < 0.35 then
        local hue_s = math.random()
        local sr, sg, sb = util.hsv_to_rgb(hue_s, 0.6, 1.0)
        local sp_color = { util.trunc(sr * 255), util.trunc(sg * 255), util.trunc(sb * 255) }
        local ch = sparkle_chars[math.random(#sparkle_chars)]
        sparkles[#sparkles + 1] = { rc = rc, color = sp_color, ch = ch }
      end
    end

    render.render_frame({
      tiles = tiles, score = score, best = best, moves_count = moves_count,
      elapsed_seconds = elapsed_seconds, status_text = "YOU WIN! 2048",
      status_color = msg_color, board_tint = effect.board_tint, fade = effect.fade,
      blink = effect.blink,
      sparkles = sparkles, palette = palette,
    })
    platform.sleep(config.END_SCREEN_TICK)
  end
end

function M.pause_screen(board, score, best, moves_count, elapsed_seconds, palette)
  local tiles = tiles_mod.board_to_tiles(board)
  local start = platform.now()
  while true do
    if platform.kbhit() then
      local key = read_key()
      if key == "pause" or key == "quit" then return key end
    end
    local t = platform.now() - start
    local effect = status_effect.compute("", true, palette, t)
    render.render_frame({
      tiles = tiles, score = score, best = best, moves_count = moves_count,
      elapsed_seconds = elapsed_seconds, status_text = "PAUSED",
      status_color = { 150, 190, 255 }, blink = effect.blink, paused = true,
      board_tint = effect.board_tint, fade = effect.fade, palette = palette,
    })
    platform.sleep(config.END_SCREEN_TICK)
  end
end

return M
end
__modules["lib/save"] = function(loader)
-- Save/load persistence for game state as a small Lua table.
local board_mod = loader("lib/board")

local M = {}

local function save_dir()
  local profile = win and win.GetEnv("FARLOCALPROFILE") or os.getenv("FARLOCALPROFILE")
  if profile and profile ~= "" then
    return profile
  end
  return "."
end

M.SAVE_PATH = save_dir() .. "/2048.save"

local function serialize(value)
  local kind = type(value)
  if kind == "number" or kind == "boolean" then return tostring(value) end
  if kind == "string" then return string.format("%q", value) end
  if kind ~= "table" then error("unsupported value: " .. kind) end

  local fields = {}
  if #value > 0 then
    for _, item in ipairs(value) do
      fields[#fields + 1] = serialize(item)
    end
    return "{" .. table.concat(fields, ",") .. "}"
  end
  for key, item in pairs(value) do
    fields[#fields + 1] = key .. "=" .. serialize(item)
  end
  return "{" .. table.concat(fields, ",") .. "}"
end

function M.save_state(state)
  if type(state) ~= "table" or type(state.board) ~= "table" then
    return false
  end
  local data = {
    board = state.board,
    score = state.score,
    best = state.best,
    moves_count = state.moves_count,
    palette = state.palette or "classic",
    elapsed_seconds = state.elapsed_seconds,
  }
  local f = io.open(M.SAVE_PATH, "w")
  if not f then return false end
  local ok, encoded = pcall(serialize, data)
  if not ok then f:close(); return false end
  f:write(encoded)
  f:close()
  return true
end

function M.load_state()
  local f = io.open(M.SAVE_PATH, "r")
  if not f then return nil end
  local contents = f:read("*a")
  f:close()

  local chunk = loadstring("return " .. contents)
  if chunk then setfenv(chunk, {}) end
  local ok, data = false, nil
  if chunk then ok, data = pcall(chunk) end
  if not ok or type(data) ~= "table" then return nil end

  local b = data.board
  if type(b) ~= "table" or #b ~= board_mod.BOARD_SIZE then return nil end
  for _, row in ipairs(b) do
    if type(row) ~= "table" or #row ~= board_mod.BOARD_SIZE then return nil end
  end
  return data
end

function M.clear_save()
  os.remove(M.SAVE_PATH)
end

return M
end
__modules["console/main"] = function(loader)
-- Console entry point. The game rules and mutable state live in lib/.
local isMain = not loader
loader = loader or dofile("loader.lua")() --luacheck: globals loader

local game_session = loader("lib/game_session")
local board_mod = loader("lib/board")
local render = loader("console/render")
local tiles_mod = loader("lib/tiles")
local animation = loader("console/animation")
local screens = loader("console/screens")
local save = loader("lib/save")
local platform = loader("console/platform")
local config = loader("console/config")
local status_effect = loader("lib/status_effect")

math.randomseed(os.time())

local function main()
  local prepared, prepare_err = pcall(platform.prepare_console)
  if not prepared then
    local _, restore_err = platform.restore_console()
    if restore_err then prepare_err = prepare_err .. "\n" .. restore_err end
    error(prepare_err, 0)
  end

  local alternate = false
  local ok, err = xpcall(function()
    platform.enter_alternate_screen()
    alternate = true

    local saved = save.load_state()
    local session
    if saved and board_mod.compute_status(saved.board) == "" then
      session = game_session.new({ state = saved, clock = platform.now })
    elseif saved then
      save.clear_save()
    end
    session = session or game_session.new({ clock = platform.now })

    local function save_current()
      return save.save_state(session:snapshot())
    end

    local function do_render()
      local visual_status = session:has_pending_score() and "" or session.status
      local effect = status_effect.compute(visual_status, session.paused, session.palette,
        session:current_elapsed())
      render.render_frame({
        tiles = tiles_mod.board_to_tiles(session.board),
        score = session.score,
        score_delta = session.pending_score,
        best = session.best,
        moves_count = session.moves_count,
        elapsed_seconds = session:current_elapsed(),
        status_text = visual_status,
        palette = session.palette,
        paused = session.paused,
        board_tint = effect.board_tint,
        fade = effect.fade,
        blink = effect.blink,
      })
    end

    io.write("\x1b[2J\x1b[H\x1b[?25l")
    io.flush()
    do_render()
    local last_shown_second = math.floor(session:current_elapsed())

    while true do
      if session.status == "game_over" or session.status == "won" then
        session:freeze_time()
        local screen = session.status == "won" and screens.win_screen or screens.game_over_screen
        local outcome = screen(
          session.board, session.score, session.best, session.moves_count,
          session:current_elapsed(), session:can_undo(), session.palette
        )
        if outcome == "quit" then
          save_current()
          return
        elseif outcome == "undo" and session:undo() then
          do_render()
          goto continue
        end
        session:restart()
        save.clear_save()
        save_current()
        do_render()
        goto continue
      end

      local key
      if platform.kbhit() then
        key = platform.read_key()
      else
        platform.sleep(config.IDLE_POLL_DELAY)
      end

      if key == nil then
        local sec = math.floor(session:current_elapsed())
        if sec ~= last_shown_second then
          last_shown_second = sec
          do_render()
        end
        goto continue
      end

      if key == "quit" then
        session:freeze_time()
        save_current()
        return
      elseif key == "restart" then
        session:restart()
        save.clear_save()
        save_current()
        do_render()
      elseif key == "pause" then
        session:set_paused(true)
        local outcome = screens.pause_screen(
          session.board, session.score, session.best, session.moves_count,
          session:current_elapsed(), session.palette
        )
        if outcome == "quit" then
          save_current()
          return
        end
        session:set_paused(false)
        do_render()
      elseif key == "palette" then
        session:cycle_palette()
        save_current()
        do_render()
      elseif key == "undo" then
        if session:undo() then
          save_current()
          do_render()
        end
      elseif key == "up" or key == "down" or key == "left" or key == "right" then
        local result = session:move(key)
        if result.changed then
          -- Discard keys queued before this move. Keys pressed while the
          -- blocking animation is running are intentionally kept for the
          -- next loop iteration.
          platform.flush_input()
          animation.play_move(
            result.new_board, result.moves, result.spawned_board, result.spawned,
            {
              score = session.score,
              best = session.best,
              moves_count = session.moves_count,
              elapsed_seconds = session:current_elapsed(),
              score_delta = session.pending_score,
            }, session.palette
          )
          if session:has_pending_score() then
            session:settle_score()
          end
          save_current()
          do_render()
          last_shown_second = math.floor(session:current_elapsed())
        end
      end

      if key ~= nil and not (key == "up" or key == "down"
          or key == "left" or key == "right") then
        platform.flush_input()
      end
      ::continue::
    end
  end, debug.traceback)

  local restored, restore_err = platform.restore_console()
  io.write("\x1b[?25h" .. render.OUTER_RESET)
  if alternate then platform.leave_alternate_screen() end
  io.write("\n")
  io.flush()
  if not ok then
    if restore_err then err = err .. "\nTerminal restore failed: " .. restore_err end
    error(err, 0)
  end
  if not restored then error(restore_err, 0) end
end

if isMain then
  return main()
end

return main
end
__modules["far/config"] = function(loader)
local M = {}
local constants = loader("lib/constants")

-- Keep the FAR driver on the same one-frame cadence as console/animation.lua.
-- The interval is changed per FSM phase below because merge-pop intentionally
-- has a different delay from slide and spawn-fade.
M.FRAMES_PER_TICK = 1
M.DEBUG = false
M.TIMER_INTERVAL_MS = math.floor(constants.ANIM_FRAME_DELAY * 1000 + 0.5)
M.PHASE_DELAYS = {
  constants.ANIM_FRAME_DELAY,
  constants.MERGE_POP_DELAY,
  constants.SPAWN_FADE_DELAY,
}
M.CLOCK_INTERVAL_MS = 1000
M.STATUS_EFFECT_INTERVAL_MS = math.floor(constants.STATUS_EFFECT_INTERVAL_SECONDS * 1000 + 0.5)
M.DIALOG_TITLE = "2048"
M.INNER_MARGIN_X = 1
M.INNER_MARGIN_Y = 0
M.OUTER_MARGIN_X = 3
M.OUTER_MARGIN_Y = 1
M.STATS_LABEL_WIDTH = 12
M.STATS_VALUE_WIDTH = 10
M.BUTTON_WIDTH = 12

return M
end
__modules["far/backend"] = function(loader)
-- FAR Manager rendering + input backend for DI_USERCONTROL.
--
-- This module is the FAR counterpart to console/render.lua + console/winapi.lua (which
-- target a Windows console via ANSI escapes + msvcrt). It draws into a
-- far.CreateUserControl() buffer instead of stdout, and reads FAR's
-- INPUT_RECORD tables instead of msvcrt._getch().
--
-- Requires the global `far` and `F` tables that LuaMacro injects into
-- every macro's environment -- this file only runs inside FAR, not under
-- plain luajit.exe.
-- luacheck: globals far F

local geometry = loader("lib/geometry")
local color = loader("lib/color")
local canvas = loader("lib/tile_canvas")

local M = {}

local BOARD_W, BOARD_H = geometry.BOARD_W, geometry.BOARD_H

-- ---------------------------------------------------------------------
-- Buffer creation / color conversion
-- ---------------------------------------------------------------------

-- far.CreateUserControl(width, height) returns a buffer indexable 1..W*H,
-- row-major, one CHAR_INFO-like cell per character position -- the exact
-- same logical shape as render.lua's `buf[y][x]` 2D table, just flattened
-- and 1-indexed differently. We keep our own 2D Lua table as the "source
-- of truth" and flush it into the FAR buffer on demand, mirroring how
-- render.lua's make_buffer()/render_buffer() split concerns.
function M.create_buffer()
  return far.CreateUserControl(BOARD_W, BOARD_H)
end

-- FAR stores true-color fields as Windows COLORREF values. COLORREF is
-- 0x00BBGGRR, while the shared palette uses { red, green, blue } arrays.
-- Flags=0 keeps the values in true-color mode (no palette reduction).
local function rgb_to_farcolor(c)
  return c[1] + c[2] * 0x100 + c[3] * 0x10000
end
M._rgb_to_farcolor = rgb_to_farcolor

local function far_color_attributes(fg, bg)
  return {
    Flags = 0,
    ForegroundColor = rgb_to_farcolor(fg),
    BackgroundColor = rgb_to_farcolor(bg),
  }
end
M._far_color_attributes = far_color_attributes

-- ---------------------------------------------------------------------
-- Drawing: same 2D scratch-buffer approach as render.lua, so tile-layout
-- math (draw_tile positions, cell/gap sizes) is not duplicated -- only
-- the final "blit to the real output" step differs (FAR buffer vs ANSI).
-- ---------------------------------------------------------------------

-- Renders `tiles` (0-based row/col, same shape render.lua/animation_fsm.lua
-- produce) into the FAR buffer object. Call this from DN_DRAWDLGITEM, not
-- from a timer -- FAR owns *when* drawing actually happens; we only own
-- *what* the buffer should contain at that moment.
function M.draw_to_far_buffer(far_buffer, opts)
  local tiles = opts.tiles
  local board_tint = opts.board_tint
  local fade = opts.fade or 0
  local palette = opts.palette
  local buf = canvas.rasterize(tiles, {
    board_tint = board_tint,
    fade = fade,
    palette = palette,
  })

  for y = 1, BOARD_H do
    for x = 1, BOARD_W do
      local ch, fg, bg = buf[y][x][1], buf[y][x][2], buf[y][x][3]
      local idx = (y - 1) * BOARD_W + x
      far_buffer[idx] = {
        Char = ch,
        Attributes = far_color_attributes(fg or color.text_color(bg), bg),
      }
    end
  end
end

return M
end
__modules["far/dialog_layout"] = function(loader)
-- FAR dialog geometry and item construction. No game state lives here.
local geometry = loader("lib/geometry")
local config = loader("far/config")

local M = {}

function M.calculate()
  local board_w, board_h = geometry.BOARD_W, geometry.BOARD_H
  local stats_label_width = config.STATS_LABEL_WIDTH
  local stats_value_width = config.STATS_VALUE_WIDTH
  local stats_total_width = stats_label_width + stats_value_width
  local board_x1 = config.OUTER_MARGIN_X + config.INNER_MARGIN_X + 1
  local board_y1 = config.OUTER_MARGIN_Y + config.INNER_MARGIN_Y + 1
  local board_x2 = board_x1 + board_w - 1
  local board_y2 = board_y1 + board_h - 1
  local stats_x1 = board_x2 + config.INNER_MARGIN_X + 2
  local stats_x2 = stats_x1 + stats_total_width - 1
  local doublebox_x1 = config.OUTER_MARGIN_X
  local doublebox_x2 = stats_x2 + config.INNER_MARGIN_X + 1
  local doublebox_y1 = config.OUTER_MARGIN_Y
  local doublebox_y2 = board_y2 + config.INNER_MARGIN_Y + 1

  return {
    board_w = board_w, board_h = board_h,
    doublebox_x1 = doublebox_x1, doublebox_x2 = doublebox_x2,
    doublebox_y1 = doublebox_y1, doublebox_y2 = doublebox_y2,
    doublebox_w = doublebox_x2 - doublebox_x1 + 1,
    doublebox_h = doublebox_y2 - doublebox_y1 + 1,
    dialog_w = doublebox_x2 + config.OUTER_MARGIN_X + 1,
    dialog_h = doublebox_y2 + config.OUTER_MARGIN_Y + 1,
    board_x1 = board_x1, board_y1 = board_y1,
    board_x2 = board_x2, board_y2 = board_y2,
    stats_x1 = stats_x1, stats_x2 = stats_x2,
    stats_label_width = stats_label_width,
    stats_value_width = stats_value_width,
    stats_total_width = stats_total_width,
  }
end

function M.build_items(F, geom, far_buffer)
  local items, ids = {}, {}
  local function add_item(name, item)
    items[#items + 1] = item
    ids[name] = #items
  end

  add_item("doublebox", {
    "DI_DOUBLEBOX", geom.doublebox_x1, geom.doublebox_y1,
    geom.doublebox_x2, geom.doublebox_y2, 0, 0, 0, 0, "2048",
  })
  add_item("usercontrol", {
    "DI_USERCONTROL", geom.board_x1, geom.board_y1,
    geom.board_x2, geom.board_y2, far_buffer, 0, 0, 0, "",
  })

  local stats_y = geom.board_y1
  for index, name in ipairs({ "score", "best", "moves" }) do
    local y = stats_y + index - 1
    add_item(name, {
      "DI_TEXT", geom.stats_x1, y,
      geom.stats_x1 + geom.stats_total_width - 1, y, 0, 0, 0, 0, "",
    })
  end

  local action_y = stats_y + 3
  for index, button in ipairs({ { "undo_button", "&Undo" }, { "new_button", "&New" } }) do
    local y = action_y + index - 1
    add_item(button[1], {
      "DI_BUTTON", geom.stats_x1, y,
    geom.stats_x1 + config.BUTTON_WIDTH - 1, y,
    0, 0, 0, F.DIF_BTNNOCLOSE, button[2],
    })
  end

  local time_y = action_y + 3
  add_item("time", {
    "DI_TEXT", geom.stats_x1, time_y,
    geom.stats_x1 + geom.stats_total_width - 1, time_y, 0, 0, 0, 0, "",
  })
  local pause_y = time_y + 1
  add_item("pause_button", {
    "DI_BUTTON", geom.stats_x1, pause_y,
    geom.stats_x1 + config.BUTTON_WIDTH - 1, pause_y,
    0, 0, 0, F.DIF_BTNNOCLOSE, "&Pause",
  })

  local switch_y = geom.board_y2
  add_item("status", {
    "DI_TEXT", geom.stats_x1, pause_y + 2,
    geom.stats_x1 + geom.stats_total_width - 1, pause_y + 2, 0, 0, 0, 0, "",
  })
  add_item("palette", {
    "DI_TEXT", geom.stats_x1, switch_y - 1,
    geom.stats_x1 + geom.stats_total_width - 1, switch_y - 1, 0, 0, 0, 0, "",
  })
  add_item("switch_button", {
    "DI_BUTTON", geom.stats_x1, switch_y,
    geom.stats_x1 + config.BUTTON_WIDTH - 1, switch_y,
    0, 0, 0, F.DIF_BTNNOCLOSE, "&Switch",
  })
  return items, ids
end

return M
end
__modules["far/dialog_view"] = function(loader)
-- FAR dialog text and status presentation.
local util = loader("lib/util")

local M = {}

local function make_stat_label(label, width)
  return label .. string.rep(" ", math.max(0, width - #label))
end

function M.format_status(status)
  if status == "won" then return "Won" end
  if status == "game_over" then return "Game over" end
  return ""
end

function M.update(far, hdlg, ids, geom, session)
  if not hdlg then return end
  local width = geom.stats_label_width
  local score_text = string.format("%d", session.score)
  if session:has_pending_score() then
    score_text = score_text .. string.format(" +%d", session.pending_score)
  end
  far.SendDlgMessage(hdlg, "DM_SETTEXTPTR", ids.score,
    make_stat_label("Score: ", width) .. score_text)
  far.SendDlgMessage(hdlg, "DM_SETTEXTPTR", ids.best,
    make_stat_label("Best: ", width) .. string.format("%d", session.best))
  far.SendDlgMessage(hdlg, "DM_SETTEXTPTR", ids.moves,
    make_stat_label("Moves: ", width) .. string.format("%d", session.moves_count))
  far.SendDlgMessage(hdlg, "DM_SETTEXTPTR", ids.time,
    make_stat_label("Time: ", width) .. util.format_duration(session:current_elapsed()))
  far.SendDlgMessage(hdlg, "DM_SETTEXTPTR", ids.palette, "Palette: " .. session.palette)
  far.SendDlgMessage(hdlg, "DM_SETTEXTPTR", ids.pause_button,
    session.paused and "Un&pause" or "&Pause")
  far.SendDlgMessage(hdlg, "DM_ENABLE", ids.undo_button, session:can_undo())
  far.SendDlgMessage(hdlg, "DM_SETTEXTPTR", ids.status,
    session:has_pending_score() and "" or M.format_status(session.status))
end

function M.apply_status_colors(F, bor, status, colors)
  local base_flags = colors[1].Flags
  if status == "game_over" then
    colors[1].ForegroundColor = 4
    colors[1].Flags = bor(base_flags, F.FCF_FG_INDEX, F.FCF_FG_BLINK)
  elseif status == "won" then
    colors[1].ForegroundColor = 2
    colors[1].Flags = bor(base_flags, F.FCF_FG_INDEX, F.FCF_FG_BLINK)
  else
    colors[1].Flags = base_flags
  end
  return colors
end

return M
end
__modules["far/main"] = function(loader)
-- FAR frontend. Game state is shared with the console through game_session;
-- this file owns FAR lifecycle, timers and event dispatch only.
local F = far.Flags
local bor = bit64.bor

local isMain = not loader
loader = loader or dofile("loader.lua")() --luacheck: globals loader

local board_mod = loader("lib/board")
local game_session = loader("lib/game_session")
local constants = loader("lib/constants")
local config = loader("far/config")
local far_backend = loader("far/backend")
local animation_fsm = loader("lib/animation_fsm")
local tiles_mod = loader("lib/tiles")
local save = loader("lib/save")
local layout = loader("far/dialog_layout")
local view = loader("far/dialog_view")
local status_effect = loader("lib/status_effect")
local arrow_glyphs = { up = "↑", down = "↓", left = "←", right = "→" }

local function main()
  local now
  if far.FarClock then
    now = function() return far.FarClock() / 1000000 end
  else
    now = win.Clock --luacheck: read_globals win.Clock
  end

  local saved = save.load_state()
  local initial_state = saved and board_mod.compute_status(saved.board) == "" and saved or nil
  local session = game_session.new({ state = initial_state, clock = now })
  local geom = layout.calculate()
  local far_buffer = far_backend.create_buffer()
  local items, item_ids = layout.build_items(F, geom, far_buffer)

  local hdlg
  local closed = false
  local timer
  local clock_timer
  local active_animation
  local current_focus
  local previous_focus
  local slide_deadline
  local slide_render_seconds = 0
  local pending_key

  local function set_animation_timer_interval()
    if not timer or not active_animation or active_animation:is_done() then return end
    local phase = active_animation.phases[active_animation.phase_idx]
    if active_animation.phase_idx == 1 and slide_deadline then
      local remaining = phase.total_steps - phase.step
      local delay = animation_fsm.next_frame_delay(slide_deadline, now(), remaining, slide_render_seconds)
      timer.Interval = math.max(1, math.floor(delay * 1000 + 0.5))
      return
    end
    local delay = config.PHASE_DELAYS[active_animation.phase_idx]
      or constants.ANIM_FRAME_DELAY
    timer.Interval = math.floor(delay * 1000 + 0.5)
  end

  local function current_tiles()
    if active_animation and not active_animation:is_done() then
      return active_animation:tiles()
    end
    return tiles_mod.board_to_tiles(session.board)
  end

  local function request_board_redraw()
    if hdlg and not closed then
      -- FAR implements DM_SHOWITEM by sending DM_REDRAW for the dialog.
      far.SendDlgMessage(hdlg, "DM_SHOWITEM", item_ids.usercontrol, 1)
    end
  end

  local function sync_clock_timer_interval()
    if clock_timer then
      clock_timer.Interval = session.status ~= "" and not session:has_pending_score()
        and config.STATUS_EFFECT_INTERVAL_MS
        or config.CLOCK_INTERVAL_MS
    end
  end

  local function update_view()
    view.update(far, hdlg, item_ids, geom, session)
  end

  local function save_current()
    return save.save_state(session:snapshot())
  end

  local function begin_move(direction)
    if active_animation then return end
    local result = session:move(direction)
    if not result.changed then return false end
    sync_clock_timer_interval()
    active_animation = animation_fsm.new_move_animation(
      result.new_board, result.moves, result.spawned_board, result.spawned,
      session.palette
    )
    slide_deadline = now() + constants.SLIDE_DURATION_SECONDS
    update_view()
    set_animation_timer_interval()
    if timer then timer.Enabled = true end
    return true
  end

  local function start_pending_move()
    local key = pending_key
    pending_key = nil
    if key and session.status == "" and not session.paused then begin_move(key) end
  end

  local function on_timer(handle)
    if closed then
      handle.Enabled = false
      return
    end
    if active_animation and not active_animation:is_done() then
      active_animation:advance(config.FRAMES_PER_TICK)
      local render_started = now()
      -- DM_SHOWITEM is equivalent to a full DM_REDRAW in FAR.
      request_board_redraw()
      slide_render_seconds = now() - render_started
      if active_animation.phase_idx ~= 1 then slide_deadline = nil end
      if active_animation:is_done() then
        handle.Enabled = false
        session:settle_score()
        active_animation = nil
        sync_clock_timer_interval()
        save_current()
        update_view()
        start_pending_move()
      else
        set_animation_timer_interval()
      end
    else
      handle.Enabled = false
    end
  end

  local function reset_to_new_game()
    if active_animation then return end
    pending_key = nil
    session:restart()
    sync_clock_timer_interval()
    active_animation = nil
    if timer then timer.Enabled = false end
    save.clear_save()
    save_current()
    update_view()
  end

  local function undo_last_move()
    if active_animation then return end
    pending_key = nil
    if not session:undo() then return end
    sync_clock_timer_interval()
    active_animation = nil
    if timer then timer.Enabled = false end
    save_current()
    update_view()
  end

  local function cycle_palette()
    if active_animation then return end
    session:cycle_palette()
    save_current()
    update_view()
  end

  local function toggle_pause()
    if active_animation then return end
    session:set_paused(not session.paused)
    if timer then
      timer.Enabled = active_animation ~= nil and not active_animation:is_done()
    end
    save_current()
    update_view()
  end

  local function close_timers()
    if timer then
      timer.Enabled = false
      timer:Close()
      timer = nil
    end
    if clock_timer then
      clock_timer.Enabled = false
      clock_timer:Close()
      clock_timer = nil
    end
  end

  local function restore_usercontrol_focus(should_restore)
    if should_restore then
      far.SendDlgMessage(hdlg, 'DM_SETFOCUS', item_ids.usercontrol, nil)
    end
  end

  local button_actions = {
    [item_ids.new_button] = reset_to_new_game,
    [item_ids.switch_button] = cycle_palette,
    [item_ids.undo_button] = undo_last_move,
    [item_ids.pause_button] = toggle_pause,
  }

  local function draw_key_marker(key)
    local dialog_rect = far.SendDlgMessage(hdlg, F.DM_GETDLGRECT, 0)
    local moves_rect = far.SendDlgMessage(hdlg, F.DM_GETITEMPOSITION, item_ids.moves)
    local color = far.AdvControl(F.ACTL_GETCOLOR, far.Colors.COL_DIALOGHIGHLIGHTTEXT)
    local arrow = arrow_glyphs[key]
    if dialog_rect and moves_rect and color and arrow then
      far.Text(dialog_rect.Left + moves_rect.Left - 1,
        dialog_rect.Top + moves_rect.Top, color, arrow)
      far.Text()
    end
  end

  local function dispatch_key(key)
    local is_arrow = arrow_glyphs[key] ~= nil
    if config.DEBUG and is_arrow then
      draw_key_marker(key)
    end
    if active_animation then
      if is_arrow then
        if not pending_key then pending_key = key end
        return true
      end
      return false
    end
    if is_arrow then
      if session.status == "" and not session.paused then
        if begin_move(key) then return true end
      end
    elseif key == "pause" and current_focus == item_ids.usercontrol and session.status == "" then
      toggle_pause()
      return true
    end
    return false
  end

  local function normalize_key(name)
    name = tostring(name or ""):lower()
    return ({
      left = "left", up = "up", right = "right", down = "down",
      space = "pause",
    })[name]
  end

  local function dlg_proc(dialog, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      hdlg = dialog
      timer = far.Timer(config.TIMER_INTERVAL_MS, on_timer)
      timer.Enabled = false
      clock_timer = far.Timer(config.CLOCK_INTERVAL_MS, function()
        if not closed then
          if session.status == "won" or session.status == "game_over" then
            -- DM_SHOWITEM is equivalent to a full DM_REDRAW in FAR.
            request_board_redraw()
          else
            update_view()
          end
        end
      end)
      clock_timer.Enabled = true
      update_view()
      return true
    end

    if msg == F.DN_DRAWDLGITEM and param1 == item_ids.usercontrol then
      local visual_status = session:has_pending_score() and "" or session.status
      local effect = status_effect.compute(visual_status, session.paused, session.palette, now())
      far_backend.draw_to_far_buffer(far_buffer, {
        tiles = current_tiles(), board_tint = effect.board_tint, fade = effect.fade,
        palette = session.palette,
      })
      return true
    end

    if msg == F.DN_BTNCLICK then
      if active_animation then return true end
      local action = button_actions[param1]
      if not action then return nil end

      local restore_focus = current_focus == item_ids.usercontrol
        or previous_focus == item_ids.usercontrol
      if session.paused and param1 ~= item_ids.pause_button then toggle_pause() end
      action()
      restore_usercontrol_focus(restore_focus)
      return true
    end

    if msg == F.DN_GOTFOCUS then
      previous_focus, current_focus = current_focus, param1
      return nil
    end

    if msg == F.DN_CTLCOLORDLGITEM and param1 == item_ids.status then
      return view.apply_status_colors(F, bor,
        session:has_pending_score() and "" or session.status, param2)
    end

    if not F.DN_KEY and msg == F.DN_CONTROLINPUT and param2.KeyDown ~= false then
      return dispatch_key(normalize_key(far.InputRecordToName(param2))) or nil
    end

    if F.DN_KEY and msg == F.DN_KEY then
      return dispatch_key(normalize_key(far.KeyToName(param2))) or nil --luacheck: read_globals far.KeyToName
    end

    if msg == F.DN_CLOSE then
      if closed then return true end
      closed = true
      hdlg = nil
      pending_key = nil
      session:settle_score()
      active_animation = nil
      save_current()
      close_timers()
      return true
    end
    return nil
  end

  far.Dialog(nil, -1, -1, geom.dialog_w, geom.dialog_h,
    config.DIALOG_TITLE, items, 0, dlg_proc)
end

if isMain then
  return main()
end

return main
end
local function __bundle_load(name)
  if __cached[name] ~= nil then return __cached[name] end
  local result = __modules[name](__bundle_load)
  __cached[name] = result == nil and true or result
  return __cached[name]
end
local loader = __bundle_load
local Info = Info or package.loaded.regscript or function(...) return ... end --luacheck: ignore 113/Info
local nfo = Info { _filename or ...,
  name        = "2048";
  description = "Classic 2048 game implementation";
  version     = "0.2"; --https://semver.org/lang/ru/
  author      = "jd";
  url         = "https://forum.farmanager.com/viewtopic.php?t=13979";
  id          = "79CC0BD9-0AAB-4714-92BE-2E92C3C54DC0";
  --minfarversion = {3,0,0,4744,0};
  --execute     = function(nfo,name) end;
  --options     = {
  --};
  --disabled    = true;
}
if not nfo or nfo.disabled then return end
--local O = nfo.options

local function getLoader(macrofile)
  local loader_lua = "loader.lua"
  local arg0 = Macro and macrofile or _filename or arg and arg[0]
  local dir
  if arg0 then
    arg0 = far and far.GetReparsePointInfo(arg0) or arg0
    dir = arg0:match("(.+)[\\/]")
    if dir then loader_lua = dir..package.config:sub(1,1)..loader_lua end
  end
  return dofile(loader_lua)(dir)
end

local loader = loader or getLoader(...) --luacheck: read_globals loader, ignore 411/loader

if not far then
  return loader("console/main")()
end

local game = loader("far/main")

if _filename then
  return game()
end

function nfo:execute() --luacheck: ignore 212/self
  game()
end

Macro { description="2048";
  area="Common"; key="";
  id="E670234E-AFCC-49E9-A2A7-C8DDC5DA3102";
  action=function()
    game()
  end;
}

MenuItem{
  guid="A49F8EBD-FB64-47EA-B753-55688ECF5876";
  menu="Plugins";
  area="Common";
  text=function() return"2048" end;
  action=function()
    game()
  end;
}
