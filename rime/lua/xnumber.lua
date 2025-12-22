--[[
xnumber.lua: realize a yong-style number typing experience in RIME
usage:
0. this script is intended for xkjd6 but also work for other schemas (may need some custimizations)
1. place this script in `rime\lua`
2. modify `rime\rime.lua` by adding a line like `number_translator = require("numberx")`
3. modify your schema (like `xkjd6.schema.yaml`) by adding an item like `- lua_translator@number_translator` under the `engine/translators` section
4. re-deploy RIME and enjoy (the default trigger key is `=`)
change log:
v0.0.1(20201010) - initial version written by thXnder(别打脸)
--]]

local function speakLiterally(str, valMap)
	valMap = valMap or {
		[0]="零"; "一"; "二"; "三"; "四"; "五"; "六"; "七"; "八"; "九"; "十";
		["+"]="正"; ["-"]="负"; ["."]="点"; [""]=""
	}

	local tbOut = {}
	for k = 1, #str do
		local v = string.sub(str, k, k)
		v = tonumber(v) or v
		tbOut[k] = valMap[v]
	end
	return table.concat(tbOut)
end

local function speakMillitary(str)
	return speakLiterally(str, {[0]="洞"; "幺"; "两"; "三"; "四"; "五"; "六"; "拐"; "八"; "勾"; "十";["+"]="正"; ["-"]="负"; ["."]="点"; [""]=""})
end

local function splitNumStr(str)
	--[[
		split a number (or a string describing a number) into 4 parts:
		.sym: "+", "-" or ""
		.int: "0", "000", "123456", "", etc
		.dig: "." or ""
		.dec: "0", "10000", "00001", "", etc
	--]]
	local part = {}
	part.sym, part.int, part.dig, part.dec = string.match(str, "^([%+%-]?)(%d*)(%.?)(%d*)")
	return part
end

local function speakBar(str, posMap, valMap)
	posMap = posMap or {[1]="仟"; [2]="佰"; [3]="拾"; [4]=""}
	valMap = valMap or {[0]="零"; "一"; "二"; "三" ;"四"; "五"; "六"; "七"; "八"; "九"} -- the length of valMap[0] should not excess 1

	local out = ""
	local bar = string.sub("****" .. str, -4, -1) -- the integer part of a number string can be divided into bars; each bar has 4 bits
	for pos = 1, 4 do
		local val = tonumber(string.sub(bar, pos, pos))
		-- case1: place holder
		if val == nil then
			goto continue
		end
		-- case2: number 1~9
		if val > 0 then
			out = out .. valMap[val] .. posMap[pos]
			goto continue
		end
		-- case3: number 0
		local valNext = tonumber(string.sub(bar, pos+1, pos+1))
		if ( valNext==nil or valNext==0 )then
			goto continue
		else
			out = out .. valMap[0]
			goto continue
		end
	::continue::
	end
	if out == "" then out = valMap[0] end
	return out
end

local function speakIntOfficially(str, posMap, valMap)
	posMap = posMap or {[1]="千"; [2]="百"; [3]="十"; [4]=""}
	valMap = valMap or {[0]="零"; "一"; "二"; "三" ;"四"; "五"; "六"; "七"; "八"; "九"} -- the length of valMap[0] should not excess 1

	-- split the number string into bars, for example, in:str=123456789 → out:tbBar={1|2345|6789}
	local int = string.match(str, "^0*(%d+)$")
	if int=="" then int = "0" end
	local remain = #int % 4
	if remain==0 then remain = 4 end
	local tbBar = {[1] = string.sub(int, 1, remain)}
	for pos = remain+1, #int, 4 do
		local bar = string.sub(int, pos, pos+3)
		table.insert(tbBar, bar)
	end
	-- generate the suffixes of each bar, for example, tbSpeakBarSuffix={亿|万|""}
	local tbSpeakBarSuffix = {[1]=""}
	for iBar = 2, #tbBar do
		local suffix = (iBar % 2 == 0) and ("万"..tbSpeakBarSuffix[1]) or ("亿"..tbSpeakBarSuffix[2])
		table.insert(tbSpeakBarSuffix, 1, suffix)
	end
	-- speak each bar
	local tbSpeakBar = {}
	for k = 1, #tbBar do
		tbSpeakBar[k] = speakBar(tbBar[k], posMap, valMap)
	end
	-- combine the results
	local out = ""
	for k = 1, #tbBar do
		local speakBar = tbSpeakBar[k]
		if speakBar ~= valMap[0] then
			out = out .. speakBar .. tbSpeakBarSuffix[k]
		end
	end
	if out == "" then out = valMap[0] end
	return out
end

local function speakDecMoney(str, posMap, valMap)
	posMap = posMap or {[1]="角"; [2]="分"; [3]="厘"; [4]="毫"}
	valMap = valMap or {[0]="零"; "壹"; "贰"; "叁" ;"肆"; "伍"; "陆"; "柒"; "捌"; "玖"} -- the length of valMap[0] should not excess 1

	local dec = string.sub(str, 1, 4)
	dec = string.gsub(dec, "0*$", "")
	if dec == "" then
		return "整"
	end

	local out = ""
	for pos = 1, #dec do
		local val = tonumber(string.sub(dec, pos, pos))
		out = out .. valMap[val] .. posMap[pos]
	end
	return out
end

local function speakOfficially(str)
	local part = splitNumStr(str)
	local speakSym = speakLiterally(part.sym)
	local speakInt = speakIntOfficially(part.int)
	local speakDig = speakLiterally(part.dig)
	local speakDec = speakLiterally(part.dec)
	local out = speakSym .. speakInt .. speakDig .. speakDec
	return out
end

local function speakMoney(str)
	local part = splitNumStr(str)
	local speakSym = speakLiterally(part.sym)
	local speakInt = speakIntOfficially(part.int, {[1]="仟"; [2]="佰"; [3]="拾"; [4]=""}, {[0]="零"; "壹"; "贰"; "叁" ;"肆"; "伍"; "陆"; "柒"; "捌"; "玖"}) .. "元"
	local speakDec = speakDecMoney(part.dec)
	local out = speakSym .. speakInt .. speakDec
	return out
end

local function baseConverse(str, from, to)
	local str10 = str
	if from == 16 then
		str10 = string.format("%d", str)
	end
	local strout = str10
	if to == 16 then
		strout = string.format("%#x", str10)
	end
	return strout
end

local function translator(input, seg, env)
	-- env can be used for getting the state of a switch, e.g., `env.engine.context:get_option("s2tw")` returns true/false (or nil if the switch does not exist)
	if string.sub(input, 1, 1) == "=" then
		local input2 = string.sub(input, 2)
		if string.match(input2, "^[%+%-]?%d*%.?%d*$") then -- sadly, lua does not support regex like {0,4}
			-- comment or reorder following lines to adjust the effects
			yield(Candidate("number", seg.start, seg._end, speakMoney(input2), " 金额"))
			yield(Candidate("number", seg.start, seg._end, speakOfficially(input2), " 文读"))
			yield(Candidate("number", seg.start, seg._end, speakLiterally(input2), " 冷读"))
			yield(Candidate("number", seg.start, seg._end, speakMillitary(input2), " 军语"))
		else
			local ok, ret = pcall(load, "return "..input2) -- from Lua 5.3, the `loadstring` function is replaced by `load`
			if ok then yield(Candidate("number", seg.start, seg._end, tostring(ret()), " 计算")) end
		end
		if string.match(input2, "^[%+%-]?%d*$") then -- plz, i dont want to deal with base conversion with decimals
			yield(Candidate("number", seg.start, seg._end, baseConverse(input2, 10, 16), " 进制"))
		end
	end
end

return translator