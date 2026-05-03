local conf = {
  weekday = { "星期天", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六" },
  number = { "〇", "一", "二", "三", "四", "五", "六", "七", "八", "九" },
}

local function to_up(text)
  for i, value in ipairs(conf.number) do
    text = text:gsub(i - 1, value)
  end
  return text
end

local function get_up_date()
  local month_num = tonumber(os.date("%m"))
  local day_num = tonumber(os.date("%d"))

  local year = to_up(os.date("%Y"))
  local month = to_up(tostring(month_num))
  if month_num == 10 then
    month = "十"
  elseif month_num > 10 then
    month = month:gsub("^一", "十")
  end

  local day = to_up(tostring(day_num))
  if day_num == 10 then
    day = "十"
  elseif day_num % 10 == 0 then
    day = day:gsub("〇", "十")
  elseif day_num > 10 and day_num < 20 then
    day = "十" .. day:sub(4)
  elseif day_num > 20 then
    day = day:sub(1, 3) .. "十" .. day:sub(4)
  end

  return year .. "年" .. month .. "月" .. day .. "日"
end

local function get_weekday()
  local week = os.date("%w")
  return conf.weekday[week + 1]
end

local function get_root_dir()
  local source = debug.getinfo(1, "S").source or ""
  if source:sub(1, 1) ~= "@" then
    return nil
  end
  local file_path = source:sub(2)
  local dir = file_path:match("^(.*)[/\\][^/\\]+$")
  if not dir then
    return nil
  end
  return dir:match("^(.*)[/\\]lua$") or dir
end

local function read_version_text()
  local root_dir = get_root_dir()
  if not root_dir then
    return nil
  end

  local file = io.open(root_dir .. "/version.txt", "r")
  if not file then
    return nil
  end

  local version = file:read("*l")
  file:close()
  if not version or version == "" then
    return nil
  end
  return version
end

local function translator(input, seg)
  local version = read_version_text()

  if input == "o" then
    yield(Candidate("oboot", seg.start, seg._end, os.date("%H:%M:%S"), "(时间 ~ej)"))
    yield(Candidate("oboot", seg.start, seg._end, os.date("%Y年%m月%d日"), "(日期 ~rq)"))
    yield(Candidate("oboot", seg.start, seg._end, get_weekday(), "(星期 ~xq)"))
    if version then
      yield(Candidate("oboot", seg.start, seg._end, version, "(版本 ~bb)"))
    end
  elseif input == "oe" then
    yield(Candidate("oboot", seg.start, seg._end, os.date("%H:%M:%S"), "(时间 ~j)"))
  elseif input == "or" then
    yield(Candidate("oboot", seg.start, seg._end, os.date("%Y年%m月%d日"), "(日期 ~q)"))
  elseif input == "ox" then
    yield(Candidate("oboot", seg.start, seg._end, get_weekday(), "(星期 ~q)"))
  elseif input == "ob" and version then
    yield(Candidate("oboot", seg.start, seg._end, version, "(版本 ~b)"))
  elseif input == "oej" then
    yield(Candidate("oboot", seg.start, seg._end, os.date("%H:%M:%S"), ""))
  elseif input == "orq" then
    yield(Candidate("oboot", seg.start, seg._end, os.date("%Y年%m月%d日"), ""))
    yield(Candidate("oboot", seg.start, seg._end, os.date("%Y-%m-%d"), ""))
    yield(Candidate("oboot", seg.start, seg._end, get_up_date(), ""))
  elseif input == "oxq" then
    yield(Candidate("oboot", seg.start, seg._end, get_weekday(), ""))
  elseif input == "obb" and version then
    yield(Candidate("oboot", seg.start, seg._end, version, ""))
  end
end

return translator
