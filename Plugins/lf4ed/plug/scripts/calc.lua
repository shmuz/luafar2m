local F = far.Flags

local function GetSelectedText()
  local ei = editor.GetInfo()
  if ei and ei.BlockType ~= F.BTYPE_NONE then
    local t = {}
    local n = ei.BlockStartLine
    while true do
      local s = editor.GetString(nil,n, 1)
      if not s or s.SelStart == 0 then
        break
      end
      local sel = s.StringText:sub (s.SelStart, s.SelEnd)
      table.insert(t, sel)
      n = n + 1
    end
    editor.SetPosition(nil,ei)
    return table.concat(t, "\n"), n-1
  end
end

local function GetText()
  local text = GetSelectedText()
  return (text ~= "") and text or editor.GetString(nil,nil,2)
end

local function ShowSumAndAverage()
  local sum = 0
  local min, max
  local n = 0
  local t = {}

  for num in regex.gmatch(GetText(), [[ \-? \b \d+ (?: \.\d+ )? \b ]], "x") do
    num = tonumber(num)
    n = n + 1
    t[n] = num
    sum = sum + num
    if n == 1 then
      min, max = num, num
    else
      if min > num then min = num end
      if max < num then max = num end
    end
  end

  local avr, std_dev, abs_dev
  if n > 0 then
    avr = sum / n
    std_dev, abs_dev = 0, 0
    for _,v in ipairs(t) do
      v = v - avr
      std_dev = std_dev + v*v
      abs_dev = abs_dev + (v>=0 and v or -v)
    end
    std_dev = math.sqrt(std_dev / n)
    abs_dev = abs_dev / n
  end

  local s = [[
Quantity:             %d
Sum:                  %s
Average:              %s
Minimum:              %s
Maximum:              %s
Standard deviation:   %s
Aver. abs. deviation: %s]]

  local choice = far.Message(
    s:format(n, sum, avr or "n/a", min or "n/a", max or "n/a", std_dev or "n/a", abs_dev or "n/a"),
    "Sum and Average", n==0 and "OK" or "OK;Copy &sum;Copy &average", "l")
  if choice==2 then far.CopyToClipboard(sum)
  elseif choice==3 then far.CopyToClipboard(avr)
  end
end

AddToMenu ("e", nil, "Ctrl+F9", ShowSumAndAverage)
