local candidates = {}

function Candidate(kind, start, stop, text, comment)
	return { type = kind, start = start, _end = stop, text = text, comment = comment }
end

function yield(candidate)
	candidates[#candidates + 1] = candidate
end

local translator = dofile(arg[1] or "rime/lua/xnumber.lua")
local checks = 0

local function translate(input)
	candidates = {}
	local ok, err = pcall(translator, input, { start = 0, _end = #input }, {})
	assert(ok, input .. " raised: " .. tostring(err))
	local output = {}
	for _, candidate in ipairs(candidates) do
		assert(candidate.text ~= "", input .. " yielded a blank candidate")
		output[candidate.comment] = candidate.text
	end
	return output
end

local function expect(output, input, comment, expected)
	local actual = output[" " .. comment]
	assert(actual == expected, input .. " [" .. comment .. "]: expected " .. tostring(expected) .. ", got " .. tostring(actual))
	checks = checks + 1
end

for _, case in ipairs({
	{ "=10001000", "壹仟万壹仟元整", "一千万一千" },
	{ "=107000", "壹拾万柒仟元整", "一十万七千" },
	{ "=101000", "壹拾万壹仟元整", "一十万一千" },
	{ "=100001000", "壹亿零壹仟元整", "一亿零一千" },
	{ "=1000000001", "壹拾亿零壹元整", "一十亿零一" },
	{ "=1000000001000", "壹万亿零壹仟元整", "一万亿零一千" },
	{ "=1000000000001", "壹万亿零壹元整", "一万亿零一" },
	{ "=1010", "壹仟零壹拾元整", "一千零一十" },
	{ "=100000001", "壹亿零壹元整", "一亿零一" },
	{ "=123400001000", "壹仟贰佰叁拾肆亿零壹仟元整", "一千二百三十四亿零一千" },
	{ "=100010001", "壹亿零壹万零壹元整", "一亿零一万零一" },
	{ "=12341000", "壹仟贰佰叁拾肆万壹仟元整", "一千二百三十四万一千" },
	{ "=1000000000000000", "壹仟万亿元整", "一千万亿" },
	{ "=10000000000000000", "壹亿亿元整", "一亿亿" },
	{ "=12345678901234567", "壹亿亿贰仟叁佰肆拾伍万亿陆仟柒佰捌拾玖亿零壹佰贰拾叁万肆仟伍佰陆拾柒元整", "一亿亿二千三百四十五万亿六千七百八十九亿零一百二十三万四千五百六十七" },
	{ "=9223372036854775807", "玖佰贰拾贰亿亿叁仟叁佰柒拾贰万亿零叁佰陆拾捌亿伍仟肆佰柒拾柒万伍仟捌佰零柒元整", "九百二十二亿亿三千三百七十二万亿零三百六十八亿五千四百七十七万五千八百零七" },
	{ "=12345678901234567890", "壹仟贰佰叁拾肆亿亿伍仟陆佰柒拾捌万亿玖仟零壹拾贰亿叁仟肆佰伍拾陆万柒仟捌佰玖拾元整", "一千二百三十四亿亿五千六百七十八万亿九千零一十二亿三千四百五十六万七千八百九十" },
	{ "=00000000000000000123", "壹佰贰拾叁元整", "一百二十三" },
	{ "=123", "壹佰贰拾叁元整", "一百二十三" },
	{ "=12.5", "壹拾贰元伍角", "一十二点五" },
}) do
	local output = translate(case[1])
	expect(output, case[1], "金额", case[2])
	expect(output, case[1], "文读", case[3])
end

local output = translate("=123")
expect(output, "=123", "冷读", "一二三")
expect(output, "=123", "军语", "幺两三")
expect(output, "=123", "进制", "0x7b")
output = translate("=12.5")
expect(output, "=12.5", "冷读", "一二点五")
expect(output, "=12.5", "军语", "幺两点五")
expect(output, "=12.5", "进制", nil)

for _, input in ipairs({ "=", "=+", "=-", "=.", "=+.", "=()", "= + " }) do
	translate(input)
	assert(#candidates == 0, input .. " yielded " .. #candidates .. " candidates without a digit")
	checks = checks + 1
end

for _, input in ipairs({ "=12345678901234567890", "=9223372036854775808" }) do
	output = translate(input)
	assert(output[" 金额"] and output[" 文读"], input .. " lost number readings")
	checks = checks + 1
	expect(output, input, "进制", nil)
end
output = translate("=12345678901234567890")
expect(output, "=12345678901234567890", "冷读", "一二三四五六七八九零一二三四五六七八九零")
expect(output, "=12345678901234567890", "军语", "幺两三四五六拐八勾洞幺两三四五六拐八勾洞")
output = translate("=9223372036854775807")
expect(output, "=9223372036854775807", "进制", "0x7fffffffffffffff")
output = translate("=10000000000000000")
expect(output, "=10000000000000000", "进制", "0x2386f26fc10000")

for _, case in ipairs({
	{ "=1+1", "2" },
	{ "=0.1+0.2", "0.3" },
	{ "=10/2", "5" },
	{ "=2^3", "8" },
	{ "=123456789*987654321", "121932631112635269" },
	{ "=100000000*100000000", "10000000000000000" },
	{ "=9007199254740993+0", "9007199254740993" },
	{ "=12345678901234567*1", "12345678901234567" },
	{ "=1000000000000000000+1", "1000000000000000001" },
	{ "=999999999999999999*9", "8999999999999999991" },
	{ "=461168601842738790*20+7", "9223372036854775807" },
	{ "=(-461168601842738790*20-8)+0", "-9223372036854775808" },
	{ "=9007199254740993-1", "9007199254740992" },
	{ "=900000000000000000*10+900000000000000000", "9.9e+18" },
	{ "=-900000000000000000*10-900000000000000000", "-9.9e+18" },
	{ "=3037000500*3037000500", "9.22337203700025e+18" },
	{ "=9223372036854775807+1", "9.22337203685478e+18" },
	{ "=(-461168601842738790*20-8)*-1", "9.22337203685478e+18" },
	{ "=(-461168601842738790*20-8)//-1", "9.22337203685478e+18" },
	{ "=-(-461168601842738790*20-8)", "9.22337203685478e+18" },
	{ "=7//-2", "-4" },
	{ "=7%-2", "-1" },
	{ "=-2^2", "-4" },
	{ "=2^3^2", "512" },
	{ "=.5+.5", "1" },
	{ "=1.+1", "2" },
}) do
	expect(translate(case[1]), case[1], "计算", case[2])
end

print("xnumber self-check passed (" .. checks .. " checks)")
