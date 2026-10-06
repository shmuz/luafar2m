local __modules, __cached = {}, {}
__modules["yaml/types"] = function()
--!YAML addon for xmake
--
-- the shared value types of the parser and the emitter
--
-- @note lua cannot store nil in a table, and an empty table is both an empty mapping
-- and an empty sequence, so we need a null value and an array mark, it's exactly the
-- same problem as json, we reuse its ones and get the json interoperability for free
--
-- @author      ruki
-- @file        types.lua
--

-- imports
local null_value = setmetatable({}, { __tostring = function() return "null" end })
local arrays = setmetatable({}, { __mode = "k" })
local mapping_data = setmetatable({}, { __mode = "k" })
local sequence_data = setmetatable({}, { __mode = "k" })
local function add_mapping_entry(map, key, value, info)
    local entries = mapping_data[map]
    if not entries then entries = {}; mapping_data[map] = entries end
    entries[#entries + 1] = { key = key, value = value, info = info or {} }
end
local function mapping_entries(map)
    return mapping_data[map] or {}
end
local function set_sequence_entry(seq, index, info)
    local entries = sequence_data[seq]
    if not entries then entries = {}; sequence_data[seq] = entries end
    entries[index] = info
end
local function sequence_entry(seq, index)
    local entries = sequence_data[seq]
    return entries and entries[index] or nil
end

-- get the null value, e.g. `yaml.decode("foo:").foo == yaml.null()`
local function null()
    return null_value
end

-- is the null value?
local function is_null(value)
    return value == null_value
end

-- mark the given table as an array, so an empty table is emitted as `[]` instead of `{}`
local function mark_as_array(luatable)
    arrays[luatable] = true
    return luatable
end

-- is the given table marked as an array?
local function is_marked_as_array(luatable)
    return arrays[luatable] == true
end

-- is the given table an array?
--
-- @note an empty table is a mapping unless it has been marked, we cannot tell them apart
--
local function is_array(luatable)
    if is_marked_as_array(luatable) then
        return true
    end
    local count = #luatable
    if count == 0 then
        return false
    end
    -- it's an array only if it has no other keys
    local total = 0
    for _ in pairs(luatable) do
        total = total + 1
        if total > count then
            return false
        end
    end
    return total == count
end


return { null = null, is_null = is_null, mark_as_array = mark_as_array, is_marked_as_array = is_marked_as_array, is_array = is_array, add_mapping_entry = add_mapping_entry, mapping_entries = mapping_entries, set_sequence_entry = set_sequence_entry, sequence_entry = sequence_entry }

end
__modules["yaml/scalar"] = function(loader)
--!YAML addon for xmake
--
-- the scalar reader, it turns a piece of yaml text into a lua value
--
-- @author      ruki
-- @file        scalar.lua
--

-- imports
local types = loader("yaml/types")

-- the hot string functions, we look them up once
local sub = string.sub
local find = string.find
local byte = string.byte
local char = string.char
local format = string.format

-- the plain scalars which are not strings
--
-- @note the null values are marked with `NULL`, we cannot store nil in this table
local NULL = "<null>"
local CONSTANTS = {
    ["~"]     = NULL,
    [""]      = NULL,
    ["null"]  = NULL,
    ["Null"]  = NULL,
    ["NULL"]  = NULL,
    ["true"]  = true,
    ["True"]  = true,
    ["TRUE"]  = true,
    ["false"] = false,
    ["False"] = false,
    ["FALSE"] = false,
    [".inf"]  = math.huge,
    [".Inf"]  = math.huge,
    [".INF"]  = math.huge,
    ["+.inf"] = math.huge,
    ["-.inf"] = -math.huge,
    ["-.Inf"] = -math.huge,
    ["-.INF"] = -math.huge,
    [".nan"]  = 0 / 0,
    [".NaN"]  = 0 / 0,
    [".NAN"]  = 0 / 0
}

-- the escape characters of the double quoted scalars
local ESCAPES = {
    ["0"] = "\0",
    a     = "\a",
    b     = "\b",
    t     = "\t",
    ["\t"] = "\t",
    n     = "\n",
    v     = "\v",
    f     = "\f",
    r     = "\r",
    e     = "\27",
    [" "] = " ",
    ["\""] = "\"",
    ["/"] = "/",
    ["\\"] = "\\",
    N     = "\133",
    _     = "\160",
    L     = "\226\128\168",
    P     = "\226\128\169"
}

-- encode the given unicode codepoint as utf8
--
-- @note we cannot use the integer division here, xmake may be built with luajit
local function _utf8(codepoint)
    local floor = math.floor
    if codepoint < 0x80 then
        return char(codepoint)
    elseif codepoint < 0x800 then
        return char(0xc0 + floor(codepoint / 0x40), 0x80 + codepoint % 0x40)
    elseif codepoint < 0x10000 then
        return char(0xe0 + floor(codepoint / 0x1000), 0x80 + floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
    end
    return char(0xf0 + floor(codepoint / 0x40000), 0x80 + floor(codepoint / 0x1000) % 0x40,
                0x80 + floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
end

-- read the escape sequence at the given position, e.g. `\n`, `é`
--
-- @return the text and the next position
local function _read_escape(text, pos)
    local c = sub(text, pos, pos)
    local escape = ESCAPES[c]
    if escape then
        return escape, pos + 1
    end
    -- the unicode escapes, e.g. \x41, é, \U0001f600
    local sizes = {x = 2, u = 4, U = 8}
    local size = sizes[c]
    if size then
        local hex = sub(text, pos + 1, pos + size)
        local codepoint = tonumber(hex, 16)
        if codepoint and #hex == size and not find(hex, "[^%da-fA-F]") and
           codepoint <= 0x10ffff and not (codepoint >= 0xd800 and codepoint <= 0xdfff) then
            return _utf8(codepoint), pos + 1 + size
        end
        return nil, "invalid Unicode escape sequence"
    end
    if c == "" then
        return nil, "incomplete escape sequence"
    end
    return nil, "unknown escape sequence \\" .. c
end

-- read a double quoted scalar, e.g. "foo\nbar"
--
-- @return the value and the next position, or nil and the error
local function read_double_quoted(text, pos)
    local parts = {}
    local index = pos + 1
    local total = #text
    while index <= total do
        local c = byte(text, index)
        if c == 34 then -- "
            return table.concat(parts), index + 1
        elseif c == 92 then -- \
            local escape, nextpos = _read_escape(text, index + 1)
            if not escape then
                return nil, nextpos
            end
            parts[#parts + 1] = escape
            index = nextpos
        else
            -- take the whole run until the next `"` or `\`, it's much faster than
            -- appending the characters one by one
            local stop = find(text, "[\"\\]", index)
            if not stop then
                break
            end
            parts[#parts + 1] = sub(text, index, stop - 1)
            index = stop
        end
    end
    return nil, "the double quoted scalar is not closed"
end

-- read a single quoted scalar, e.g. 'it''s'
--
-- @return the value and the next position, or nil and the error
local function read_single_quoted(text, pos)
    local parts = {}
    local index = pos + 1
    local total = #text
    while index <= total do
        local stop = find(text, "'", index, true)
        if not stop then
            break
        end
        parts[#parts + 1] = sub(text, index, stop - 1)
        if byte(text, stop + 1) == 39 then -- '' is an escaped quote
            parts[#parts + 1] = "'"
            index = stop + 2
        else
            return table.concat(parts), stop + 1
        end
    end
    return nil, "the single quoted scalar is not closed"
end

-- get the value of the given plain scalar, e.g. `42`, `true`, `foo`
local function from_plain(text)
    local constant = CONSTANTS[text]
    if constant ~= nil then
        return constant == NULL and types.null() or constant
    end

    -- a number? we check the first character to skip the strings quickly
    local c = byte(text)
    if (c >= 48 and c <= 57) or c == 45 or c == 43 or c == 46 then -- 0-9 - + .
        if find(text, "^[-+]?%d+$") then
            return tonumber(text)
        elseif find(text, "^[-+]?%d*%.?%d+[eE][-+]?%d+$") or find(text, "^[-+]?%d*%.%d*$") then
            return tonumber(text)
        end
        -- the based integers, e.g. 0x1f, 0o17, 0b1010
        local sign, base, digits = text:match("^([-+]?)0([xXoObB])(%w+)$")
        if sign then
            local bases = {x = 16, o = 8, b = 2}
            local value = tonumber(digits, bases[base:lower()])
            if value then
                return sign == "-" and -value or value
            end
        end
    end
    return text
end

-- apply the given tag to the value, e.g. `!!str 42`
local function from_tag(tag, value)
    if tag == "!" or tag == "!!str" or tag == "tag:yaml.org,2002:str" then
        if types.is_null(value) then
            return ""
        end
        return type(value) == "string" and value or tostring(value)
    elseif tag == "!!int" or tag == "tag:yaml.org,2002:int" then
        return math.floor(tonumber(value) or 0)
    elseif tag == "!!float" or tag == "tag:yaml.org,2002:float" then
        return tonumber(value) or 0.0
    elseif tag == "!!bool" or tag == "tag:yaml.org,2002:bool" then
        if type(value) == "boolean" then
            return value
        end
        return value == "true" or value == "yes" or value == "on"
    elseif tag == "!!null" or tag == "tag:yaml.org,2002:null" then
        return types.null()
    end
    -- we keep the value of the unknown tags, e.g. the application tags
    return value
end

-- get the error message with the line number
local function errorof(lineno, message, ...)
    local args = {...}
    if #args > 0 then
        message = format(message, ...)
    end
    return format("yaml: line %d: %s", lineno, message)
end


return { read_double_quoted = read_double_quoted, read_single_quoted = read_single_quoted, from_plain = from_plain, from_tag = from_tag, errorof = errorof }

end
__modules["yaml/parser"] = function(loader)
--!YAML addon for xmake
--
-- the yaml parser, it turns the yaml text into the lua values
--
-- it's a line based recursive descent parser: the text is scanned into the lines once,
-- and every node consumes the lines which are more indented than itself
--
-- @author      ruki
-- @file        parser.lua
--

-- imports
local parser_env = setmetatable({}, { __index = _G })
setfenv(1, parser_env)
local types  = loader("yaml/types")
local scalar = loader("yaml/scalar")
local raise = error

-- the hot string functions, we look them up once
local sub = string.sub
local find = string.find
local byte = string.byte
local rep = string.rep

-- trim the leading spaces
--
-- @note we do not allocate a new string if there is nothing to trim, the trims are
-- in the hot path of the parser and `gsub` is much slower than `find`
--
function _ltrim(text)
    local pos = find(text, "[^ \t]")
    if pos == 1 then
        return text
    end
    return pos and sub(text, pos) or ""
end

-- trim the trailing spaces
function _rtrim(text)
    local pos = find(text, "[ \t]+$")
    if not pos then
        return text
    end
    return sub(text, 1, pos - 1)
end

-- scan the text into the lines
--
-- @return {{indent = 0, text = "foo: bar", raw = "foo: bar", lineno = 1, empty = false}, ...}
--
-- @note we keep the raw text of the lines, the block scalars need it
--
function _scan_lines(text)
    local lines = {}
    local pos = 1
    local total = #text
    local lineno = 0
    while pos <= total + 1 do
        local stop = find(text, "\n", pos, true)
        local raw = sub(text, pos, (stop or total + 1) - 1)
        lineno = lineno + 1

        -- strip the carriage return of the dos line endings
        if byte(raw, #raw) == 13 then
            raw = sub(raw, 1, #raw - 1)
        end

        -- get the indentation, the tabs are not allowed in it
        local start = find(raw, "[^ ]")
        local indent = (start or #raw + 1) - 1
        local c = start and byte(raw, start)

        -- an empty line or a comment line? we skip them in the structure,
        -- but the block scalars still see them
        local empty = (c == nil) or (c == 35) -- nil or #
        lines[#lines + 1] = {indent = indent, text = empty and "" or sub(raw, start),
                             raw = raw, lineno = lineno, empty = empty}
        if not stop then
            break
        end
        pos = stop + 1
    end
    return lines
end

-- get the current line, it skips the empty and comment lines
function _current_line(state)
    local lines = state.lines
    local index = state.index
    local line = lines[index]
    while line and line.empty do
        index = index + 1
        line = lines[index]
    end
    state.index = index
    return line
end

-- is it a document marker? e.g. `---`, `...`
function _is_marker(line)
    local text = line.text
    return line.indent == 0 and (text == "---" or text == "..." or
                                 find(text, "^%-%-%- ") ~= nil or find(text, "^%.%.%. ") ~= nil)
end

-- is it a sequence entry? e.g. `- foo`, `-`
function _is_entry(text)
    if byte(text) ~= 45 then -- -
        return false
    end
    local c = byte(text, 2)
    return c == nil or c == 32
end

-- find the closing quote of the quoted text at the given position
function _find_quote_end(text, pos)
    local quote = byte(text, pos)
    local index = pos + 1
    local total = #text
    while index <= total do
        local c = byte(text, index)
        if c == 92 and quote == 34 then -- the escapes of the double quoted text
            index = index + 2
        elseif c == quote then
            -- '' is an escaped quote in the single quoted text
            if quote == 39 and byte(text, index + 1) == 39 then
                index = index + 2
            else
                return index
            end
        else
            index = index + 1
        end
    end
end

-- split the mapping key of the given text, e.g. `foo: bar` -> "foo", "bar"
--
-- @return the key text and the value text, or nil if it's not a mapping entry
--
function _split_key(text)
    local c = byte(text)
    if c == 123 or c == 91 then -- { or [, it's a flow node
        return
    end

    -- a quoted key? e.g. "foo bar": baz
    if c == 34 or c == 39 then
        local stop = _find_quote_end(text, 1)
        if stop then
            local s, e = find(text, "^%s*:", stop + 1)
            if s then
                return sub(text, 1, stop), _ltrim(sub(text, e + 1))
            end
        end
        return
    end

    -- a plain key ends with `:` at the end of the line or `: `
    local pos = 1
    while true do
        local s = find(text, ":", pos, true)
        if not s then
            return
        end
        local nextc = byte(text, s + 1)
        if nextc == nil or nextc == 32 then
            local key = _rtrim(sub(text, 1, s - 1))
            if key == "" then
                return
            end
            return key, _ltrim(sub(text, s + 1))
        end
        pos = s + 1
    end
end

-- strip the trailing comment of a plain scalar, e.g. `foo # bar` -> `foo`
function _strip_comment(text)
    local pos = 1
    while true do
        local s = find(text, "#", pos, true)
        if not s then
            return text
        end
        -- a comment starts at the beginning or after a space
        if s == 1 or byte(text, s - 1) == 32 then
            return _rtrim(sub(text, 1, s - 1))
        end
        pos = s + 1
    end
end

-- parse the flow node at the given position, e.g. `{foo: bar}`, `[1, 2]`
--
-- @return the value and the next position
--
function _parse_flow(state, text, pos, iskey)
    pos = _skip_spaces(text, pos)
    local node_start = pos
    local tag, anchor
    while true do
        local c = byte(text, pos)
        if c ~= 33 and c ~= 38 then break end
        local start = pos
        pos = pos + 1
        while pos <= #text do
            c = byte(text, pos)
            if c == 32 or c == 9 or c == 44 or c == 91 or c == 93 or c == 123 or c == 125 then break end
            pos = pos + 1
        end
        local property = sub(text, start, pos - 1)
        if byte(text, start) == 33 then
            if property == "!" then
                tag = property
            elseif property:sub(1, 2) == "!!" or property:match("^![^!][^!]*!.*$") or property:match("^!<.+>$") then
                tag = property
            else
                _raise(state, "invalid tag property")
            end
        else
            if #property < 2 or anchor then _raise(state, "invalid or duplicate anchor property") end
            anchor = sub(property, 2)
        end
        pos = _skip_spaces(text, pos)
    end

    local c = byte(text, pos)
    local value, nextpos
    if c == 123 then
        local map = {}
        pos = _skip_spaces(text, pos + 1)
        while true do
            local c2 = byte(text, pos)
            if c2 == nil then
                _raise(state, "the flow mapping is not closed")
            elseif c2 == 125 then
                value, nextpos = map, pos + 1
                break
            elseif c2 == 93 or c2 == 44 then
                _raise(state, "unexpected flow mapping delimiter")
            end

            local key_start = pos
            local key
            if c2 == 58 then
                key = types.null()
            elseif c2 == 63 and (byte(text, pos + 1) == 32 or byte(text, pos + 1) == 9) then
                pos = _skip_spaces(text, pos + 1)
                if byte(text, pos) == 44 or byte(text, pos) == 125 then key = types.null()
                else key, pos = _parse_flow(state, text, pos, true) end
            else
                key, pos = _parse_flow(state, text, pos, true)
            end
            if pos <= key_start and c2 ~= 58 then _raise(state, "flow mapping key consumed no input") end

            pos = _skip_spaces(text, pos)
            local child
            if byte(text, pos) == 58 then
                pos = _skip_spaces(text, pos + 1)
                local nextc = byte(text, pos)
                if nextc == nil or nextc == 44 or nextc == 125 then
                    child = types.null()
                else
                    local value_start = pos
                    child, pos = _parse_flow(state, text, pos, false)
                    if pos <= value_start then _raise(state, "flow mapping value consumed no input") end
                end
            elseif byte(text, pos) == 44 or byte(text, pos) == 125 then
                child = types.null()
            else
                _raise(state, "expected a colon after flow mapping key")
            end

            map[key] = child
            types.add_mapping_entry(map, key, child, { flow = true, alias = type(child) == "table" and child or nil })

            pos = _skip_spaces(text, pos)
            local separator = byte(text, pos)
            if separator == 125 then
                value, nextpos = map, pos + 1
                break
            elseif separator == 44 then
                pos = _skip_spaces(text, pos + 1)
                if byte(text, pos) == 125 then
                    value, nextpos = map, pos + 1
                    break
                elseif byte(text, pos) == 44 then
                    _raise(state, "unexpected comma in flow mapping")
                end
            else
                _raise(state, "expected comma or closing brace in flow mapping")
            end
        end
    elseif c == 91 then
        local array = types.mark_as_array({})
        pos = _skip_spaces(text, pos + 1)
        while true do
            local c2 = byte(text, pos)
            if c2 == nil then
                _raise(state, "the flow sequence is not closed")
            elseif c2 == 93 then
                value, nextpos = array, pos + 1
                break
            elseif c2 == 125 or c2 == 44 then
                _raise(state, "unexpected flow sequence delimiter")
            end

            local value_start = pos
            local child
            local first, second = byte(text, pos), byte(text, pos + 1)
            if first == 58 and (second == nil or second == 32 or second == 9 or second == 44 or second == 93) then
                -- An empty flow key is a null node. Leave the colon for the
                -- mapping-pair handling below.
                child = types.null()
            else
                child, pos = _parse_flow(state, text, pos, true)
                if pos <= value_start then _raise(state, "flow sequence item consumed no input") end
            end
            pos = _skip_spaces(text, pos)
            if byte(text, pos) == 58 then
                pos = _skip_spaces(text, pos + 1)
                local mapped
                if byte(text, pos) == 44 or byte(text, pos) == 93 then mapped = types.null()
                else mapped, pos = _parse_flow(state, text, pos, false) end
                local map = {}
                map[child] = mapped
                types.add_mapping_entry(map, child, mapped, { flow = true })
                child = map
            end
            array[#array + 1] = child

            pos = _skip_spaces(text, pos)
            local separator = byte(text, pos)
            if separator == 93 then
                value, nextpos = array, pos + 1
                break
            elseif separator == 44 then
                pos = _skip_spaces(text, pos + 1)
                if byte(text, pos) == 93 then
                    value, nextpos = array, pos + 1
                    break
                elseif byte(text, pos) == 44 then
                    _raise(state, "unexpected comma in flow sequence")
                end
            else
                _raise(state, "expected comma or closing bracket in flow sequence")
            end
        end
    else
        if c == nil or c == 44 or c == 93 or c == 125 then
            if tag or anchor then value, nextpos = types.null(), pos
            else _raise(state, "expected a flow node") end
        elseif c == 58 and iskey and (byte(text, pos + 1) == nil or byte(text, pos + 1) == 32 or byte(text, pos + 1) == 9 or byte(text, pos + 1) == 44 or byte(text, pos + 1) == 93 or byte(text, pos + 1) == 125) then
            value, nextpos = types.null(), pos
        else
            value, nextpos = _parse_flow_scalar(state, text, pos, iskey)
            if nextpos <= pos then _raise(state, "flow scalar consumed no input") end
        end
    end

    if tag then value = scalar.from_tag(tag, value) end
    if anchor then state.anchors[anchor] = value end
    return value, nextpos
end

-- skip the spaces at the given position
function _skip_spaces(text, pos)
    local c = byte(text, pos)
    while c == 32 or c == 9 do
        pos = pos + 1
        c = byte(text, pos)
    end
    return pos
end

-- parse a scalar of a flow node, it ends at `,`, `}`, `]` or `:`
--
-- @param iskey  the scalar is a mapping key, so it also ends at `:`
--
function _parse_flow_scalar(state, text, pos, iskey)
    local c = byte(text, pos)
    if c == 34 or c == 39 then
        local value, nextpos
        if c == 34 then
            value, nextpos = scalar.read_double_quoted(text, pos)
        else
            value, nextpos = scalar.read_single_quoted(text, pos)
        end
        if not value then _raise(state, nextpos) end
        return value, nextpos
    end

    local stop = pos
    local total = #text
    while stop <= total do
        local c2 = byte(text, stop)
        if c2 == 44 or c2 == 125 or c2 == 93 then
            break
        elseif iskey and c2 == 58 then
            local after = byte(text, stop + 1)
            if after == nil or after == 32 or after == 9 or after == 44 or after == 93 or after == 125 then
                break
            end
        end
        stop = stop + 1
    end

    local plain = _rtrim(sub(text, pos, stop - 1))
    if plain == "" or plain:sub(1, 1) == "#" then
        _raise(state, "invalid empty flow scalar")
    end
    local value = _parse_alias(state, plain)
    if value == nil then value = scalar.from_plain(plain) end
    return value, stop
end

-- parse the alias of the given text, e.g. `*base`
function _parse_alias(state, text)
    if byte(text) == 42 then -- *
        local name = sub(text, 2)
        local value = state.anchors[name]
        if value == nil then
            _raise(state, "the anchor(%s) is not found", name)
        end
        return value
    end
end

-- gather the text of a flow node, it may span several lines
function _gather_flow(state, text)
    local stack, parts = {}, {}
    local lines = state.lines
    while true do
        local pos, total = 1, #text
        while pos <= total do
            local c = byte(text, pos)
            if c == 34 or c == 39 then
                pos = (_find_quote_end(text, pos) or total) + 1
            elseif c == 35 and (pos == 1 or byte(text, pos - 1) == 32 or byte(text, pos - 1) == 9) then
                text = sub(text, 1, pos - 1)
                break
            else
                if c == 123 then
                    stack[#stack + 1] = 125
                elseif c == 91 then
                    stack[#stack + 1] = 93
                elseif c == 125 or c == 93 then
                    if #stack == 0 then break end
                    if stack[#stack] ~= c then _raise(state, "mismatched flow collection delimiter") end
                    stack[#stack] = nil
                    if #stack == 0 then break end
                end
                pos = pos + 1
            end
        end

        parts[#parts + 1] = text
        if #stack == 0 then break end
        local line = lines[state.index]
        if not line then _raise(state, "the flow node is not closed") end
        state.index = state.index + 1
        text = line.text
    end
    return table.concat(parts, " ")
end

-- read the block scalar of the given header, e.g. `|`, `>-`, `|2+`
function _read_block_scalar(state, header, indent)
    header = _rtrim(_strip_comment(header))
    local style = sub(header, 1, 1)
    local chomp, explicit_indent
    local seen_chomp, seen_indent = false, false
    for c in header:sub(2):gmatch(".") do
        if c == "-" or c == "+" then
            if seen_chomp then
                local line = state.lines[state.index - 1]
                raise(scalar.errorof(line and line.lineno or 0, "duplicate block scalar chomping indicator"))
            end
            seen_chomp = true
            chomp = c
        elseif c >= "1" and c <= "9" then
            if seen_indent then
                local line = state.lines[state.index - 1]
                raise(scalar.errorof(line and line.lineno or 0, "duplicate block scalar indentation indicator"))
            end
            seen_indent = true
            explicit_indent = indent + tonumber(c)
        else
            local line = state.lines[state.index - 1]
            raise(scalar.errorof(line and line.lineno or 0, "invalid block scalar header"))
        end
    end

    -- read the lines which are more indented than the parent node
    local lines = state.lines
    local parts = {}
    local blockindent = explicit_indent
    while true do
        local line = lines[state.index]
        if not line then
            break
        end
        if line.empty and line.raw == "" then
            parts[#parts + 1] = ""
            state.index = state.index + 1
        elseif line.indent > indent then
            blockindent = blockindent or line.indent
            parts[#parts + 1] = sub(line.raw, blockindent + 1)
            state.index = state.index + 1
        else
            break
        end
    end

    -- strip the trailing empty lines, the chomping decides how many of them are kept
    local count = #parts
    while count > 0 and parts[count] == "" do
        count = count - 1
    end
    local keeps = #parts - count
    for i = #parts, count + 1, -1 do
        parts[i] = nil
    end

    local text
    if style == ">" then
        -- the folded style joins the lines with a space, the empty lines are the line breaks,
        -- and the more indented lines keep their line breaks
        local folded = {}
        for i, part in ipairs(parts) do
            if i == 1 then
                folded[#folded + 1] = part
            elseif part == "" then
                folded[#folded + 1] = "\n"
            elseif byte(part) == 32 or byte(folded[#folded], 1) == 32 then
                folded[#folded + 1] = "\n" .. part
            elseif folded[#folded] == "\n" then
                folded[#folded] = "\n" .. part
            else
                folded[#folded + 1] = " " .. part
            end
        end
        text = table.concat(folded)
    else
        text = table.concat(parts, "\n")
    end

    -- clip: one trailing line break, strip: none, keep: all of them
    if #parts == 0 then
        return text
    elseif chomp == "-" then
        return text
    elseif chomp == "+" then
        return text .. rep("\n", keeps + 1)
    end
    return text .. "\n"
end

-- parse the value text of a node, e.g. `foo`, `&a 42`, `|`, `{a: 1}`
--
-- @param text      the value text, it's empty if the value is on the following lines
-- @param indent    the indentation of the node which owns this value
--
-- @note the caller has consumed the line which holds this text, we only consume
-- the following lines, e.g. a block scalar or a multi line plain scalar
--
function _require_scalar_end(state, text, pos)
    local tail = sub(text, pos)
    local first = find(tail, "[^ \t]")
    if first then
        local c = byte(tail, first)
        local nextc = byte(tail, first + 1)
        if c == 35 and first > 1 then return end
        if c == 58 and (nextc == nil or nextc == 32 or nextc == 9) then return end
        _raise(state, "unexpected content after scalar or flow node")
    end
end

function _trim_quoted_break(text)
    local trimmed = _rtrim(text)
    local index = #trimmed
    while index > 0 and byte(trimmed, index) == 92 do index = index - 1 end
    if (#trimmed - index) % 2 == 1 then
        local escaped = byte(text, #trimmed + 1)
        if escaped == 32 or escaped == 9 then
            return trimmed .. sub(text, #trimmed + 1, #trimmed + 1)
        end
    end
    return trimmed
end

function _read_quoted(state, text, indent, allow_equal_indent, quote)
    local read = quote == 34 and scalar.read_double_quoted or scalar.read_single_quoted
    local value, nextpos = read(text, 1)
    if value or (nextpos ~= "the double quoted scalar is not closed" and
                 nextpos ~= "the single quoted scalar is not closed") then
        return value, nextpos, text
    end

    local lines, parts = state.lines, {text}
    local had_empty = false
    while true do
        local line = lines[state.index]
        if not line or _is_marker(line) or line.indent < indent or
           (line.indent == indent and not allow_equal_indent) then
            return nil, nextpos, table.concat(parts)
        end
        if line.empty then
            parts[#parts] = _trim_quoted_break(parts[#parts])
            parts[#parts + 1] = "\n"
            had_empty = true
        else
            parts[#parts] = _trim_quoted_break(parts[#parts])
            local content = _ltrim(line.text)
            parts[#parts + 1] = had_empty and content or (" " .. content)
            had_empty = false
        end
        state.index = state.index + 1
        text = table.concat(parts)
        value, nextpos = read(text, 1)
        if value or (nextpos ~= "the double quoted scalar is not closed" and
                     nextpos ~= "the single quoted scalar is not closed") then
            return value, nextpos, text
        end
    end
end

function _parse_inline_block_node(state, text, indent, lineno)
    local lines, index = state.lines, state.index
    table.insert(lines, index, {indent = indent + 2, text = text, raw = text,
                                lineno = lineno, empty = false})
    local ok, node = pcall(_parse_node, state, indent + 2)
    table.remove(lines, index)
    if state.index > index then state.index = state.index - 1 end
    if not ok then error(node, 0) end
    return node
end

function _parse_value(state, text, indent, at_document_root, allow_equal_plain)

    -- the tag and the anchor, e.g. `!!str &name foo`
    local tag, anchor
    while true do
        local c = byte(text)
        if c == 33 then -- !
            local stop = find(text, " ", 1, true)
            tag = sub(text, 1, (stop or #text + 1) - 1)
            text = stop and _ltrim(sub(text, stop + 1)) or ""
        elseif c == 38 then -- &
            local stop = find(text, " ", 1, true)
            anchor = sub(text, 2, (stop or #text + 1) - 1)
            text = stop and _ltrim(sub(text, stop + 1)) or ""
        else
            break
        end
    end

    local value
    local c = byte(text)
    if c == 124 or c == 62 then -- | or >
        value = _read_block_scalar(state, text, indent)
    elseif text == "" then
        -- the value is a block node on the following lines
        value = _parse_node(state, at_document_root and indent or indent + 1)
    elseif c == 123 or c == 91 then -- { or [
        local flow = _gather_flow(state, text)
        local nextpos
        value, nextpos = _parse_flow(state, flow, 1)
        _require_scalar_end(state, flow, nextpos)
    elseif _is_entry(text) then
        value = _parse_inline_block_node(state, text, indent, state.lines[state.index - 1].lineno)
    elseif c == 42 then -- *
        value = _parse_alias(state, _strip_comment(text))
    elseif c == 34 or c == 39 then
        local quoted, nextpos, fulltext = _read_quoted(state, text, indent, allow_equal_plain, c)
        if not quoted then _raise(state, nextpos) end
        _require_scalar_end(state, fulltext, nextpos)
        value = quoted
    else
        -- a plain scalar, it may continue on the following more indented lines
        value = _parse_plain(state, _strip_comment(text), indent, allow_equal_plain)
    end

    if tag then
        value = scalar.from_tag(tag, value)
    end
    if anchor then
        state.anchors[anchor] = value
    end
    return value
end

-- parse a plain scalar, it may continue on the following more indented lines
function _parse_plain(state, text, indent, allow_equal_indent)
    local lines = state.lines
    local parts
    while true do
        local line = lines[state.index]
        if not line or line.empty or line.indent < indent or (line.indent == indent and not allow_equal_indent) or _is_marker(line) then
            break
        end
        -- a mapping or a sequence never continues a plain scalar
        if _is_entry(line.text) or _split_key(line.text) then
            break
        end
        parts = parts or (text == "" and {} or {text})
        parts[#parts + 1] = _strip_comment(line.text)
        state.index = state.index + 1
    end
    if parts then
        -- the line breaks of a multi line plain scalar are folded into the spaces
        text = table.concat(parts, " ")
    end
    return scalar.from_plain(text)
end

function _last_content_line(state, first)
    local index = math.min(state.index - 1, #state.lines)
    while index > 0 and index >= first and state.lines[index].empty do index = index - 1 end
    return state.lines[index] and state.lines[index].lineno or first
end

-- split the inline value marker from an explicit mapping key, respecting
-- quotes and flow collections (e.g. `? []: value`).
function _split_explicit_key(text)
    text = _strip_comment(text)
    local pos, depth = 1, 0
    while pos <= #text do
        local c = byte(text, pos)
        if c == 34 or c == 39 then
            local stop = _find_quote_end(text, pos)
            if not stop then return text end
            pos = stop + 1
        elseif c == 91 or c == 123 then
            depth = depth + 1
            pos = pos + 1
        elseif c == 93 or c == 125 then
            depth = depth - 1
            pos = pos + 1
        elseif c == 58 and depth == 0 then
            local nextc = byte(text, pos + 1)
            if nextc == nil or nextc == 32 or nextc == 9 then
                return _rtrim(sub(text, 1, pos - 1)), _ltrim(sub(text, pos + 1)), true
            end
            pos = pos + 1
        else
            pos = pos + 1
        end
    end
    return text, nil, false
end

function _parse_explicit_key(state, keytext, indent, entry_line)
    if keytext == "" then
        local line = _current_line(state)
        if line and line.indent > indent and not line.text:match("^:") then
            return _parse_node(state, indent + 1)
        end
        return types.null()
    end

    local c = byte(keytext)
    if c == 91 or c == 123 then
        local flow = _gather_flow(state, keytext)
        local key, nextpos = _parse_flow(state, flow, 1, true)
        _require_scalar_end(state, flow, nextpos)
        return key
    elseif _is_entry(keytext) then
        -- The node after `?` starts two columns after the mapping indent.
        -- Insert it as a temporary line so the normal sequence parser can
        -- consume compact and continued block-key sequences.
        return _parse_inline_block_node(state, keytext, indent, entry_line)
    end

    return _parse_value(state, keytext, indent)
end

-- parse a mapping at the given indentation
function _parse_mapping(state, indent)
    local map = {}
    local merges
    while true do
        local line = _current_line(state)
        if not line or line.indent < indent or _is_marker(line) then
            break
        end
        if line.indent > indent then
            _raise(state, "the indentation is not consistent")
        end

        local entry_line = line.lineno
        local keytext, valuetext = _split_key(line.text)
        local key
        local explicit_key, explicit_null_value = false, false
        if line.text:match("^%? ") then
            explicit_key = true
            keytext = _ltrim(sub(line.text, 2))
            state.index = state.index + 1
            local inline_value
            keytext, valuetext, inline_value = _split_explicit_key(keytext)
            key = _parse_explicit_key(state, keytext, indent, entry_line)
            if not inline_value then
                local value_line = _current_line(state)
                if value_line and value_line.indent == indent and
                   (value_line.text == ":" or value_line.text:match("^:%s")) then
                    valuetext = _ltrim(sub(value_line.text, 2))
                    state.index = state.index + 1
                else
                    explicit_null_value = true
                    valuetext = ""
                end
            end
        else
            if not keytext then break end
            state.index = state.index + 1
            local c = byte(keytext)
            if c == 34 then key = scalar.read_double_quoted(keytext, 1)
            elseif c == 39 then key = scalar.read_single_quoted(keytext, 1)
            elseif c == 33 or c == 38 or c == 42 then key = _parse_value(state, keytext, indent)
            else key = scalar.from_plain(keytext) end
        end

        -- the merge key, e.g. `<<: *base`
        if not explicit_key and keytext == "<<" then
            merges = merges or {}
            merges[#merges + 1] = _parse_value(state, valuetext, indent)
        else
            local child = explicit_null_value and types.null() or _parse_value(state, valuetext, indent)
            map[key] = child
            types.add_mapping_entry(map, key, child, { line = entry_line, endLine = _last_content_line(state, entry_line), flow = valuetext:match("^[%[{]") ~= nil, alias = valuetext:match("^%*%S+") ~= nil, complexKey = type(key) == "table" })
        end
    end

    -- the merged keys never override the keys of this mapping
    for _, merge in ipairs(merges or {}) do
        for _, merged in ipairs(types.is_array(merge) and merge or {merge}) do
            if type(merged) == "table" then
                for key, value in pairs(merged) do
                    if map[key] == nil then
                        map[key] = value
                        types.add_mapping_entry(map, key, value, { merged = true })
                    end
                end
            end
        end
    end
    return map
end

-- parse a sequence at the given indentation
function _parse_sequence(state, indent)
    local array = types.mark_as_array({})
    while true do
        local line = _current_line(state)
        if not line or line.indent < indent or _is_marker(line) or not _is_entry(line.text) then
            break
        end
        if line.indent > indent then
            _raise(state, "the indentation is not consistent")
        end

        local entry_line = line.lineno
        local is_flow = line.text:match("^%-%s*[%[{]") ~= nil
        local text = _ltrim(sub(line.text, 2))
        if text == "" then
            state.index = state.index + 1
            array[#array + 1] = _parse_node(state, indent + 1)
        else
            -- A block scalar after the sequence marker is indented relative to the
            -- sequence, not to the column where the scalar indicator appears.
            local header = text
            while header:sub(1, 1) == "!" or header:sub(1, 1) == "&" do
                local _, stop = header:find("^[!&]%S+")
                if not stop then break end
                header = _ltrim(sub(header, stop + 1))
            end
            if byte(header) == 124 or byte(header) == 62 then
                state.index = state.index + 1
                array[#array + 1] = _parse_value(state, text, indent)
            else
                -- the entry may hold a compact mapping or sequence; rewrite it as a node
                -- which starts at the text and parse it again
                local offset = indent + (#line.text - #text)
                line.indent = offset
                line.text = text
                line.allow_equal_plain = true
                array[#array + 1] = _parse_node(state, offset)
            end
        end
        types.set_sequence_entry(array, #array, { line = entry_line,
            endLine = _last_content_line(state, entry_line),
            flow = is_flow, alias = text:match("^%*%S+") ~= nil })
    end
    return array
end

-- parse a node at the given indentation, it's a mapping, a sequence or a scalar
function _parse_node(state, indent)
    local line = _current_line(state)
    if not line or line.indent < indent or _is_marker(line) then
        return types.null()
    end
    if byte(line.text) == 63 and byte(line.text, 2) == 9 then
        _raise(state, "tab after explicit mapping key indicator")
    end
    if _is_entry(line.text) then
        return _parse_sequence(state, line.indent)
    elseif _split_key(line.text) or line.text:match("^%? ") then
        return _parse_mapping(state, line.indent)
    end
    state.index = state.index + 1
    return _parse_value(state, line.text, line.indent, nil, line.allow_equal_plain)
end

-- raise the error of the current line
function _raise(state, message, ...)
    local line = state.lines[state.index] or state.lines[#state.lines]
    raise(scalar.errorof(line and line.lineno or 0, message, ...))
end

-- decode all the documents of the given text
--
-- @param text      the yaml text
--
-- @return          the documents, e.g. {{foo = "bar"}, {...}}
--
function decode_all(text)
    assert(type(text) == "string", "yaml: the text should be a string!")
    local state = {lines = _scan_lines(text), index = 1, anchors = {}}
    local documents = {}
    while true do
        local line = _current_line(state)
        if not line then
            break
        end


        -- a new document? e.g. `---`, `--- foo`
        if _is_marker(line) then
            local document_line = line.lineno
            state.index = state.index + 1
            local text = _ltrim(sub(line.text, 4))
            if byte(line.text) == 46 then -- ...
                if text ~= "" and byte(text) ~= 35 then
                    raise(scalar.errorof(document_line, "unexpected content after document end marker"))
                end
            else
                state.anchors = {}
                if text ~= "" then
                    documents[#documents + 1] = _parse_value(state, text, 0, true)
                else
                    documents[#documents + 1] = _parse_node(state, 0)
                end
                types.set_sequence_entry(documents, #documents, {
                    line = document_line,
                    endLine = _last_content_line(state, document_line),
                    flow = false
                })
            end
        else

            local document_line = line.lineno
            documents[#documents + 1] = _parse_node(state, 0)
            types.set_sequence_entry(documents, #documents, {
                line = document_line,
                endLine = _last_content_line(state, document_line),
                flow = false
            })
        end
    end
    return documents
end

-- decode the first document of the given text
function decode(text)
    local documents = decode_all(text)
    if #documents == 0 then
        return types.null()
    end
    return documents[1]
end


return { decode = decode, decode_all = decode_all }

end

--------------------------------------------------------------------------------
-- Portable File IO for far2m / Far Manager 3.0
--------------------------------------------------------------------------------
__modules["far/fileio"] = function()
local M = {}

function M.remove(path)
  return os.remove(path) ~= nil
end

function M.read(path, limit)
  local f, err = io.open(path, "rb")
  if not f then return nil, err or "Failed to open file" end

  local chunks = {}
  local total = 0
  local chunk_size = 65536

  while true do
    local read_bytes = limit and math.min(chunk_size, limit - total + 1) or chunk_size
    if limit and read_bytes <= 0 then break end

    local bytes = f:read(read_bytes)
    if not bytes or #bytes == 0 then break end

    total = total + #bytes
    if limit and total > limit then
      f:close()
      return nil, "file exceeds size limit"
    end
    chunks[#chunks + 1] = bytes
  end

  f:close()
  return table.concat(chunks)
end

function M.write_atomic(path, bytes)
  local rand_id = tostring(math.random(100000, 999999))
  local temp = path .. ".faryaml-" .. rand_id .. ".tmp"

  local f, err = io.open(temp, "wb")
  if not f then return nil, "Failed to open temp file: " .. tostring(err) end

  local ok, write_err = f:write(bytes)
  f:flush()
  f:close()

  if not ok then
    os.remove(temp)
    return nil, "Write failed: " .. tostring(write_err)
  end

  local ren_ok, ren_err = os.rename(temp, path)
  if not ren_ok then
    os.remove(path)
    ren_ok, ren_err = os.rename(temp, path)
  end

  if not ren_ok then
    os.remove(temp)
    return nil, "Failed to replace file: " .. tostring(ren_err)
  end

  return true
end

function M.is_file(path)
  if not path or path == "" then return false end
  local attr = win and win.GetFileAttr and win.GetFileAttr(path)
  if attr then
    return not attr:find("d")
  end
  local f = io.open(path, "rb")
  if f then
    f:close()
    return true
  end
  return false
end

function M.readonly(path)
  local attr = win and win.GetFileAttr and win.GetFileAttr(path)
  if attr then
    return attr:find("r") ~= nil
  end
  return false
end

return M
end

--------------------------------------------------------------------------------
-- Far Panel Implementation
--------------------------------------------------------------------------------
__modules["far/panel"] = function(loader)
local parser = loader("yaml/parser")
local types  = loader("yaml/types")
local fileio = loader("far/fileio")

local M = {}
local F = far.Flags
local bor = bit64 and bit64.bor or bit.bor
local band = bit64 and bit64.band or bit.band
local GUID = win.Uuid("022240C0-253C-42C9-9546-27481F9DD568")
local MAX_BYTES = 64 * 1024 * 1024
local dirsep = package.config:sub(1,1)

local function file_read(path)
  local text, err = fileio.read(path, MAX_BYTES)
  if not text then return nil, err end
  local raw = text
  if #text > MAX_BYTES then return nil, "YAML file exceeds 64 MiB" end
  if text:sub(1, 4) == "\255\254\0\0" or text:sub(1, 4) == "\0\0\254\255" then
    local little = text:byte(1) == 255
    local out, i = {}, 5
    while i + 3 <= #text do
      local a, b, c, d = text:byte(i, i + 3)
      local cp = little and (a + b * 256 + c * 65536 + d * 16777216) or (a * 16777216 + b * 65536 + c * 256 + d)
      i = i + 4
      if cp < 0x80 then out[#out + 1] = string.char(cp)
      elseif cp < 0x800 then out[#out + 1] = string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
      elseif cp < 0x10000 then out[#out + 1] = string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
      else out[#out + 1] = string.char(0xF0 + math.floor(cp / 262144), 0x80 + math.floor(cp / 4096) % 64, 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64) end
    end
    return table.concat(out), 4, raw
  end
  if text:sub(1, 3) == "\239\187\191" then return text:sub(4), 1, raw end
  if text:sub(1, 2) == "\255\254" or text:sub(1, 2) == "\254\255" then
    local little = text:byte(1) == 255
    local out, i = {}, 3
    while i + 1 <= #text do
      local a, b = text:byte(i, i + 1)
      local cp = little and (a + b * 256) or (a * 256 + b)
      i = i + 2
      if cp >= 0xD800 and cp <= 0xDBFF and i + 1 <= #text then
        local c, d = text:byte(i, i + 1)
        local low = little and (c + d * 256) or (c * 256 + d)
        if low >= 0xDC00 and low <= 0xDFFF then
          cp = 0x10000 + (cp - 0xD800) * 0x400 + (low - 0xDC00)
          i = i + 2
        end
      end
      if cp < 0x80 then out[#out + 1] = string.char(cp)
      elseif cp < 0x800 then out[#out + 1] = string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
      elseif cp < 0x10000 then out[#out + 1] = string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
      else out[#out + 1] = string.char(0xF0 + math.floor(cp / 262144), 0x80 + math.floor(cp / 4096) % 64, 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64) end
    end
    return table.concat(out), little and 2 or 3, raw
  end
  return text, 0, raw
end

local function encode_host(source, encoding)
  if encoding == 0 then return source end
  if encoding == 1 then return "\239\187\191" .. source end
  local little = encoding == 2
  local out = { little and "\255\254" or "\254\255" }
  local i = 1
  while i <= #source do
    local a, b, c = source:byte(i, i + 2)
    local cp, n
    if a < 0x80 then cp, n = a, 1
    elseif a < 0xE0 then cp, n = (a - 0xC0) * 64 + (b - 0x80), 2
    elseif a < 0xF0 then cp, n = (a - 0xE0) * 4096 + (b - 0x80) * 64 + (c - 0x80), 3
    else
      local d = source:byte(i + 3)
      cp = (a - 0xF0) * 262144 + (b - 0x80) * 4096 + (c - 0x80) * 64 + (d - 0x80)
      n = 4
    end
    i = i + n
    if cp > 0xFFFF then cp = cp - 0x10000; local hi = 0xD800 + math.floor(cp / 1024); local lo = 0xDC00 + cp % 1024; cp = { hi, lo } end
    local function put(unit)
      local lo, hi = unit % 256, math.floor(unit / 256)
      out[#out + 1] = little and string.char(lo, hi) or string.char(hi, lo)
    end
    if type(cp) == "table" then put(cp[1]); put(cp[2]) else put(cp) end
  end
  return table.concat(out)
end

local function temp_name(tag)
  local dir = win.GetEnv("TMPDIR") or win.GetEnv("TEMP") or win.GetEnv("TMP") or "/tmp"
  local sep = dir:match("[/\\]$") and "" or dirsep
  return dir .. sep .. "faryaml-" .. tag .. "-" .. tostring(math.random(100000, 999999)) .. ".tmp"
end

local function active_panel_directory()
  local directory = panel.GetPanelDirectory(nil, 1)
  return directory and directory.Name or nil
end

local function join_path(directory, name)
  return directory .. (directory:match("[/\\]$") and "" or dirsep) .. name
end

local function path_is_absolute(path)
  return path:match("^%a:[/\\]") ~= nil or path:match("^[/\\]") ~= nil
end

local function current_panel_file()
  local item = panel.GetCurrentPanelItem(nil, 1)
  if not item or not item.FileName then return nil end
  local name = item.FileName
  if name == "" or name == "." or name == ".." then return nil end
  local panel_info = panel.GetPanelInfo and panel.GetPanelInfo(nil, 1)
  local plugin_panel = panel_info and panel_info.PluginHandle ~= nil
  local flags = panel_info and panel_info.Flags
  local real_names = type(flags) == "number" and F.PFLAGS_REALNAMES
    and band(flags, F.PFLAGS_REALNAMES) ~= 0
  if plugin_panel and not real_names then return nil end
  local directory = plugin_panel and active_panel_directory() or far.GetCurrentDirectory and far.GetCurrentDirectory()
  local path = path_is_absolute(name) and name or type(directory) == "string" and join_path(directory, name)
  return path and fileio.is_file(path) and path or nil
end

local function resolve_active_path(path)
  if path_is_absolute(path) then return path end
  local directory = far.GetCurrentDirectory and far.GetCurrentDirectory()
  if type(directory) == "string" and directory ~= "" then
    return join_path(directory, path)
  end
  return path
end

local function yaml_file(path)
  return type(path) == "string" and path:lower():match("%.ya?ml$") ~= nil
end

local function load(path)
  local source, encoding_or_error, raw = file_read(path)
  if not source then return nil, encoding_or_error end
  local ok, docs = pcall(parser.decode_all, source)
  if not ok then return nil, tostring(docs), source end
  local root = docs[1]
  if #docs > 1 then
    root = types.mark_as_array(docs)
  elseif root == nil then
    root = types.null()
  end
  return { path = path, source = source, originalBytes = raw, encoding = encoding_or_error, root = root }
end

local function kind(value)
  if types.is_null(value) then return "null" end
  if type(value) == "table" then return types.is_array(value) and "seq" or "map" end
  if type(value) == "boolean" then return "bool" end
  if type(value) == "number" then return value % 1 == 0 and "int" or "float" end
  return "str"
end

local function scalar(value)
  if types.is_null(value) then return "null" end
  if type(value) == "boolean" then return value and "true" or "false" end
  if type(value) == "table" then
    if types.is_array(value) then return "[" .. #value .. "]" end
    local n = #types.mapping_entries(value)
    if n == 0 then for _ in pairs(value) do n = n + 1 end end
    return "{" .. n .. "}"
  end
  local s = tostring(value):gsub("\r?\n", " ¶ ")
  if #s > 512 then s = s:sub(1, 509) .. "..." end
  return s
end

local function safe_name(name, used)
  name = tostring(name)
  local out, i, chars = {}, 1, 0
  while i <= #name and chars < 200 do
    local b = name:byte(i)
    local n = b < 0x80 and 1 or (b < 0xE0 and 2 or (b < 0xF0 and 3 or 4))
    local c = name:sub(i, i + n - 1)
    if c == "/" then c = "\226\136\149"
    elseif c == "\\" then c = "\226\167\181"
    elseif c == ":" then c = "\234\158\137"
    elseif b < 0x20 then c = " "
    elseif c:match('^[%*%?\"<>|]$') then c = "_" end
    out[#out + 1] = c
    i = i + n
    chars = chars + 1
  end
  name = table.concat(out)
  if name == "" then name = "(empty)" end
  if name:sub(-1) == " " or name:sub(-1) == "." then name = name .. "_" end
  local stem = name:match("^([^%.]+)") or name
  if stem:upper() == "CON" or stem:upper() == "PRN" or stem:upper() == "AUX" or stem:upper() == "NUL" or stem:upper():match("^COM[1-9]$") or stem:upper():match("^LPT[1-9]$") then name = "_" .. name end
  local base, n = name, 1
  while used[name:lower()] do n = n + 1; name = base .. " (" .. n .. ")" end
  used[name:lower()] = true
  return name
end

local function description_for(doc, line_no)
  if not line_no then return "" end
  local lines = {}
  for line in (doc.source .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
  local comments = {}
  local i = line_no - 1
  while i > 0 do
    local body = lines[i]:match("^%s*#(.*)$")
    if not body then break end
    table.insert(comments, 1, (body:gsub("^%s+", "")))
    i = i - 1
  end
  local code = lines[line_no] or ""
  local quote, escaped, hash = nil, false, nil
  local p = 1
  while p <= #code do
    local c = code:sub(p, p)
    if quote == '"' then
      if escaped then escaped = false elseif c == "\\" then escaped = true elseif c == quote then quote = nil end
      p = p + 1
    elseif quote == "'" then
      if c == quote then
        if code:sub(p + 1, p + 1) == quote then p = p + 2
        else quote = nil; p = p + 1 end
      else p = p + 1 end
    elseif c == '"' or c == "'" then quote = c; p = p + 1
    elseif c == "#" and (p == 1 or code:sub(p - 1, p - 1):match("%s")) then hash = p; break
    else p = p + 1 end
  end
  if hash then comments[#comments + 1] = code:sub(hash + 1):gsub("^%s+", "") end
  return table.concat(comments, " "):sub(1, 512)
end

local function children(node)
  if node.children then return node.children end
  node.children = {}
  local v, used = node.value, {}
  if type(v) ~= "table" then return node.children end
  if types.is_array(v) then
    for i, child in ipairs(v) do
      local name = "[" .. (i - 1) .. "]"
      node.children[#node.children + 1] = { name = name, value = child, parent = node, index = i, range = types.sequence_entry(v, i) }
    end
  else
    local entries = types.mapping_entries(v)
    if #entries == 0 then
      for key, child in pairs(v) do entries[#entries + 1] = { key = key, value = child } end
    end
    for i, entry in ipairs(entries) do
      local key = type(entry.key) == "table" and "[complex key]" or tostring(entry.key)
      node.children[#node.children + 1] = { name = safe_name(key, used), value = entry.value, parent = node, index = i, key = entry.key, range = entry.info }
    end
  end
  return node.children
end

local function path_of(node)
  local parts = {}
  while node and node.parent do table.insert(parts, 1, node.name); node = node.parent end
  return table.concat(parts, dirsep)
end

local function leading_start(source, line_no)
  local lines = {}
  for line in (source .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
  local first = line_no
  while first > 1 and lines[first - 1] and lines[first - 1]:match("^%s*#") do first = first - 1 end
  return first
end

local function source_fragment(doc, node)
  local r = node.range
  if not r or not r.line or not r.endLine or r.flow then return scalar(node.value) .. "\n" end
  local lines, n = {}, 0
  local first = leading_start(doc.source, r.line)
  for line in (doc.source .. "\n"):gmatch("(.-)\n") do
    n = n + 1
    if n >= first and n <= r.endLine then lines[#lines + 1] = line end
  end
  return table.concat(lines, "\n") .. "\n"
end

local function yaml_quote(text)
  text = text:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
  return "\"" .. text .. "\""
end

local function emit_yaml(value, seen)
  if types.is_null(value) then return "null" end
  if type(value) == "string" then return yaml_quote(value) end
  if type(value) == "boolean" or type(value) == "number" then return tostring(value) end
  if type(value) ~= "table" then return "null" end
  seen = seen or {}
  if seen[value] then return "null" end
  seen[value] = true
  local parts = {}
  if types.is_array(value) then
    for i, child in ipairs(value) do parts[i] = emit_yaml(child, seen) end
    seen[value] = nil
    return "[" .. table.concat(parts, ", ") .. "]"
  end
  local entries = types.mapping_entries(value)
  if #entries == 0 then for k, v in pairs(value) do entries[#entries + 1] = { key = k, value = v } end end
  for i, entry in ipairs(entries) do
    local key = type(entry.key) == "string" and yaml_quote(entry.key) or emit_yaml(entry.key, seen)
    parts[i] = key .. ": " .. emit_yaml(entry.value, seen)
  end
  seen[value] = nil
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function copy_fragment(doc, node)
  local r = node.range
  if r and r.line and r.endLine and not r.flow and not r.alias and not r.merged then
    return source_fragment(doc, node)
  end
  local value = node.value
  if node.parent and types.is_array(node.parent.value) then
    value = types.mark_as_array({ value })
  elseif node.parent and node.key ~= nil then
    local wrapper = {}
    wrapper[node.key] = node.value
    types.add_mapping_entry(wrapper, node.key, node.value, {})
    value = wrapper
  end
  return emit_yaml(value) .. "\n"
end

local function make_panel(doc)
  return { doc = doc, current = { name = "", value = doc.root }, cache = {} }
end

function M.Analyse(data)
  local path = data.FileName
  if not yaml_file(path) then return nil end
  local doc, err, source = load(path)
  if not doc then
    local background = bor(F.OPM_FIND or 0, F.OPM_QUICKVIEW or 0, F.OPM_VIEW or 0, F.OPM_EDIT or 0)
    if band(data.OpMode or 0, background) == 0 then return { path = path, error = err, source = source } end
    return nil
  end
  return doc
end

function M.Open(open_from, guid, info)
  if open_from == F.OPEN_ANALYSE then
    local doc = info and info.Handle
    if not doc then return nil end
    if doc.error then
      local line = tonumber(doc.error:match("line (%d+)")) or 1
      local choice = far.Message(doc.path .. "\n" .. doc.error, "FarYaml", "Edit;OK", "w")
      if choice == 1 then editor.Editor(doc.path, "FarYaml", -1, -1, -1, -1, 0, line, 0, 65001) end
      return nil
    end
    return make_panel(doc)
  end
  if open_from == F.OPEN_COMMANDLINE then
    local path = tostring(info or ""):match("^%s*(.-)%s*$")
    path = path:gsub('^"(.*)"$', "%1")
    if path == "" then
      path = current_panel_file()
      if not path then
        far.Message("The active panel item is not a real file.", "FarYaml", "OK", "w")
        return nil
      end
    else
      path = resolve_active_path(path)
    end
    local doc, err = load(path)
    if not doc then far.Message(path .. "\n" .. tostring(err), "FarYaml", "OK", "w"); return nil end
    return make_panel(doc)
  end
end

function M.GetFindData(panel)
  local result = {}
  for _, node in ipairs(children(panel.current)) do
    local t = kind(node.value)
    local desc = node.range and description_for(panel.doc, node.range.line) or ""
    result[#result + 1] = {
      FileName = node.name,
      FileAttributes = (t == "map" or t == "seq") and "d" or "",
      FileSize = (t == "map" or t == "seq") and 0 or #scalar(node.value),
      Description = desc,
      CustomColumnData = { t, scalar(node.value) },
      UserData = { Data = node },
    }
  end
  return result
end

function M.GetOpenPanelInfo(panel)
  local path = panel.doc.path
  local short = path:match("[^\\/]+$") or path
  local subpath = path_of(panel.current)
  local modes = {}
  for i = 1, 10 do modes[i] = { ColumnTypes = "N,C0,C1,Z", ColumnWidths = "0,5,0,0", ColumnTitles = { "Key", "Type", "Value", "Description" }, StatusColumnTypes = "N", StatusColumnWidths = "0" } end
  return { Flags = bor(F.OPIF_ADDDOTS, F.OPIF_SHOWPRESERVECASE), HostFile = path,
    CurDir = subpath, Format = "YAML", PanelTitle = " YAML: " .. short .. (subpath ~= "" and dirsep .. subpath or "") .. " ",
    PanelModesArray = modes, PanelModesNumber = 10, StartPanelMode = string.byte("3"), StartSortMode = F.SM_UNSORTED, StartSortOrder = 0 }
end

function M.SetDirectory(panel, handle, dir)
  local node, path = panel.current, tostring(dir or "")
  if path:sub(1, 1) == "\\" or path:sub(1, 1) == "/" then node, path = { name = "", value = panel.doc.root }, path:sub(2) end
  for part in path:gmatch("[^\\/]+") do
    if part == ".." then if not node.parent then return false end; node = node.parent
    elseif part ~= "." then
      local found
      for _, child in ipairs(children(node)) do if child.name:lower() == part:lower() then found = child; break end end
      if not found or (kind(found.value) ~= "map" and kind(found.value) ~= "seq") then return false end
      node = found
    end
  end
  panel.current = node
  return true
end

function M.ClosePanel(panel) panel.cache = nil end

M.Info = { Guid = GUID, Title = "FarYaml", Description = "Browse YAML documents", Author = "FarYaml" }

function M.GetFiles(obj, handle, items, move, destpath, opmode)
  if type(items) ~= "table" or #items == 0 then return 0 end
  local dest = type(destpath) == "string" and destpath or nil
  local view_mask = bor(F.OPM_VIEW or 0, F.OPM_QUICKVIEW or 0, F.OPM_EDIT or 0)
  local is_view = band(opmode or 0, view_mask) ~= 0 or not dest
  local nodes = {}
  for i = 1, #items do
    local node = items[i].UserData and items[i].UserData.Data
    if node then nodes[#nodes + 1] = node end
  end
  if #nodes == 0 then return 0 end
  if is_view then
    for _, node in ipairs(nodes) do
      local content = type(node.value) == "table" and copy_fragment(obj.doc, node) or scalar(node.value)
      local target
      if dest then
        target = dest .. (dest:match("[/\\]$") and "" or dirsep) .. node.name
      else
        target = temp_name("view")
      end
      local ok, err = fileio.write_atomic(target, content)
      if not ok then far.Message(tostring(err), "FarYaml", "OK", "w"); return 0 end
      if not dest then viewer.Viewer(target, "YAML", 0, 0, -1, -1, F.VF_DELETEONCLOSE or 0, 65001) end
    end
    return 1
  end

  local dest = dest or (win.GetCurrentDir and win.GetCurrentDir()) or "."
  local base = #nodes == 1 and (nodes[1].name .. ".yaml") or "selection.yaml"
  local initial = dest .. (dest:match("[/\\]$") and "" or dirsep) .. base
  local target = far.InputBox(nil, "Copy", "Copy selected YAML to:", "Copy", initial, nil, nil, F.FIB_ENABLEEMPTY or 0)
  if not target or target == "" then return -1 end
  if target:lower() == obj.doc.path:lower() then
    far.Message("The file currently displayed cannot be overwritten.", "FarYaml", "OK", "w"); return 0
  end
  local pieces = {}
  for _, node in ipairs(nodes) do pieces[#pieces + 1] = copy_fragment(obj.doc, node) end
  local output = table.concat(pieces)
  if fileio.read(target, MAX_BYTES) then
    local answer = far.Message("Overwrite existing file?\n" .. target, "FarYaml", "Overwrite;Cancel", "w")
    if answer ~= 1 then return -1 end
  end
  local ok, err = fileio.write_atomic(target, output)
  if not ok then far.Message(tostring(err), "FarYaml", "OK", "w"); return 0 end
  return 1
end

local function line_offsets(text)
  local offsets = { 1 }
  for i = 1, #text do if text:byte(i) == 10 then offsets[#offsets + 1] = i + 1 end end
  return offsets
end

local function splice_source(source, first, last, edited)
  local offsets = line_offsets(source)
  local from = offsets[first]
  local after = offsets[last + 1] or (#source + 1)
  if not from or not after then return nil, "source range is outside the file" end
  local eol = source:find("\r\n", 1, true) and "\r\n" or "\n"
  edited = edited:gsub("\r\n", "\n"):gsub("\r", "\n")
  if eol == "\r\n" then edited = edited:gsub("\n", "\r\n") end
  if edited ~= "" and not edited:match("\n$") then edited = edited .. eol end
  return source:sub(1, from - 1) .. edited .. source:sub(after)
end

local function selected_node(obj, handle)
  local item = panel.GetCurrentPanelItem and panel.GetCurrentPanelItem(handle, 1)
  local node = item and item.UserData and item.UserData.Data
  if item and item.FileName == ".." then node = obj.current end
  return node
end

local function edit_entry(obj, handle, node)
  if not node then return false end
  local doc = obj.doc
  local whole = node == obj.current and not node.parent
  local range = node.range
  if not whole and (not range or range.flow or range.alias or range.merged or range.complexKey) then
    far.Message("Changes were not saved: this entry cannot be located unambiguously (alias, merge, or flow style).", "FarYaml", "OK", "w")
    return true
  end
  if doc.encoding == 4 then
    far.Message("Changes were not saved: UTF-32 files are read-only in FarYaml.", "FarYaml", "OK", "w")
    return true
  end
  if fileio.readonly(doc.path) then
    far.Message("Changes were not saved: the file is read-only.", "FarYaml", "OK", "w")
    return true
  end
  local original = whole and doc.source or source_fragment(doc, node)
  local temp = temp_name("edit")
  local ok, err = fileio.write_atomic(temp, original)
  if not ok then far.Message(tostring(err), "FarYaml", "OK", "w"); return true end
  while true do
    editor.Editor(temp, "FarYaml", -1, -1, -1, -1, F.EF_DISABLEHISTORY or 0, -1, -1, 65001)
    local edited, readerr = fileio.read(temp, MAX_BYTES)
    if not edited then far.Message(tostring(readerr), "FarYaml", "OK", "w"); break end
    if edited:sub(1, 3) == "\239\187\191" then edited = edited:sub(4) end
    if edited == original then break end
    local current = fileio.read(doc.path, MAX_BYTES)
    if current ~= doc.originalBytes then
      far.Message("Changes were not saved: the file changed on disk after opening the panel.", "FarYaml", "OK", "w")
      break
    end
    local candidate, spliceerr
    if whole then candidate = edited
    else candidate, spliceerr = splice_source(doc.source, leading_start(doc.source, range.line), range.endLine, edited) end
    local parsed, parseerr
    if candidate then parsed, parseerr = pcall(parser.decode_all, candidate) end
    if not candidate or not parsed then
      local choice = far.Message("Changes were not saved: " .. tostring(spliceerr or parseerr) .. "\nEdit again?", "FarYaml", "Edit again;Discard", "w")
      if choice == 1 then original = edited; fileio.write_atomic(temp, edited) else break end
    else
      if range and node.parent and types.is_array(node.parent.value) and node.index == 1 and edited == "" then
        far.Message("Changes were not saved: removing the first sequence item would remove the list marker.", "FarYaml", "OK", "w")
        break
      end
      local saved, why = fileio.write_atomic(doc.path, encode_host(candidate, doc.encoding))
      if not saved then far.Message("Changes were not saved: " .. tostring(why), "FarYaml", "OK", "w"); break end
      local updated, loaderr = load(doc.path)
      if updated then
        local previous = path_of(obj.current)
        obj.doc = updated
        obj.current = { name = "", value = updated.root }
        if previous ~= "" then M.SetDirectory(obj, handle, dirsep .. previous) end
        panel.UpdatePanel(handle, 0, true)
        panel.RedrawPanel(handle, 0)
      else far.Message(tostring(loaderr), "FarYaml", "OK", "w") end
      break
    end
  end
  fileio.remove(temp)
  return true
end

function M.ProcessKey (obj, handle, key, ControlState)
  if band(key, F.PKF_PREPROCESS) ~= 0 then return false end
  if ControlState ~= 0 then return false end
  local VK = win.GetVirtualKeys()
  if key == VK.F1 then
    if not (M.Info.HelpDir
        and far.ShowHelp(M.Info.HelpDir, nil, bor(F.FHELP_CUSTOMPATH, F.FHELP_USECONTENTS)))
    then
      far.Message("FarYaml 0.2.3: Enter open, F3 view, F4 edit, F5 copy.", "FarYaml", "OK", "l")
    end
    return true
  end
  if key == VK.F4 then return edit_entry(obj, handle, selected_node(obj, handle)) end
  if key ~= VK.F3 then return false end
  local node = selected_node(obj, handle)
  if not node then return false end
  if node ~= obj.current and type(node.value) ~= "table" then return false end
  local text = node == obj.current and path_of(node) == "" and obj.doc.source or copy_fragment(obj.doc, node)
  local temp = temp_name("view")
  local wrote, writeerr = fileio.write_atomic(temp, text)
  if not wrote then far.Message(tostring(writeerr), "FarYaml", "OK", "w"); return true end
  viewer.Viewer(temp, "YAML", 0, 0, -1, -1, F.VF_DELETEONCLOSE or 0, 65001)
  return true
end

function M.Compare(obj, handle, item1, item2, mode)
  if mode ~= F.SM_EXT and mode ~= F.SM_DESCR then return -2 end
  local a = item1.UserData and item1.UserData.Data
  local b = item2.UserData and item2.UserData.Data
  if not a or not b then return -2 end
  local av, bv
  if mode == F.SM_EXT then
    av = kind(a.value)
    bv = kind(b.value)
  else
    av = description_for(obj.doc, a.range and a.range.line)
    bv = description_for(obj.doc, b.range and b.range.line)
  end
  av, bv = tostring(av or ""):lower(), tostring(bv or ""):lower()
  if av < bv then return -1 elseif av > bv then return 1 end
  if (a.index or 0) < (b.index or 0) then return -1
  elseif (a.index or 0) > (b.index or 0) then return 1 end
  return 0
end

return M
end

--------------------------------------------------------------------------------
-- Bundle / Module Loader Entry Point
--------------------------------------------------------------------------------
local function __bundle_load(name)
  if __cached[name] ~= nil then return __cached[name] end
  local result = __modules[name](__bundle_load)
  __cached[name] = result == nil and true or result
  return __cached[name]
end

local loader = __bundle_load
local Info = Info or package.loaded.regscript or function(...) return ... end
local macrofile = ...
local nfo = Info { _filename or macrofile,
  name        = "FarYaml";
  description = "Browse and edit YAML files in FAR";
  version     = "0.1";
  author      = "FarYaml";
  id          = "0D6DB7B4-F7E3-4646-996C-EA9CC2BA7CFE";
}
if not nfo or nfo.disabled then return end

local function script_directory(macrofile)
  local path = Macro and macrofile or _filename or arg and arg[0]
  if not path then return nil end
  path = far and far.GetReparsePointInfo and far.GetReparsePointInfo(path) or path
  return path:match("^(.*)[\\/][^\\/]+$")
end

local function getLoader(macrofile)
  local loader_lua = "loader.lua"
  local dir = script_directory(macrofile)
  if dir then loader_lua = dir .. package.config:sub(1, 1) .. loader_lua end
  return dofile(loader_lua)(dir)
end

local loader = loader or getLoader(...)
local panel = loader("far/panel")
panel.Info.HelpDir = script_directory(macrofile)

local function faryaml(text)
  return panel.Open(far.Flags.OPEN_COMMANDLINE, panel.Info.Guid, text)
end

function nfo:execute()
  faryaml()
end

if _filename then
  return faryaml()
end

PanelModule(panel)

local guid_luamacro = far.GetPluginId()
local guid_menuitem = "DA9ACFF8-3381-42CC-8692-7F12DE34B8C6"

CommandLine {
  description = "Open a YAML file in FarYaml panel";
  prefixes = "yaml";
  action = function(_, text)
    local obj = faryaml(text)
    if obj then return panel, obj end
  end
}

Macro { description = "FarYaml";
  area = "Shell"; key = "";
  id = "550F6769-D6D4-43DC-B12B-A01E2065ED8B";
  action = function()
    Plugin.Menu(guid_luamacro, guid_menuitem)
  end;
}

MenuItem {
  guid = guid_menuitem;
  menu = "Plugins";
  area = "Shell";
  text = function() return "FarYaml" end;
  action = function()
    local obj = faryaml(APanel.Current)
    if obj then return panel, obj end
  end;
}

