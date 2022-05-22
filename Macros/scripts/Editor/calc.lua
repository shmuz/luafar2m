local function GetText()
  local text = Editor.SelValue
  return (text ~= "") and text or Editor.GetStr()
end

local function EvalExpression()
  local f,err = loadstring("return "..GetText())
  if f then
    local env = setmetatable({},{__index=function(t,c) return math[c] or _G[c] end})
    local res = setfenv(f,env)()
    return tostring(res)
  else
    far.Message(err,"Compilation error", nil, "wl")
    return nil
  end
end

Macro {
  description="Calculate Sum and Average";
  area="Editor"; key="CtrlF9"; sortpriority=60;
  action=function()
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
  end;
}

Macro {
  description="Calculate Lua Expression";
  area="Editor"; key="CtrlF9";
  action=function()
    local res = EvalExpression()
    if res then
      local choice = far.Message(res, "Lua expression", "OK;&Insert;&Copy")
      if choice==2 then print("="..res..";")
      elseif choice==3 then far.CopyToClipboard(res)
      end
    end
  end;
}

Macro {
  description="Insert Lua Expression";
  area="Editor"; key="CtrlF9";
  action=function()
    local res = EvalExpression()
    if res then print("="..res..";") end
  end;
}
