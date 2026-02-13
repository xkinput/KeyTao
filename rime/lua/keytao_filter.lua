local function startswith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

local function hint(cand, context, reverse)
    if utf8.len(cand.text) < 2 then
        return false
    end

    local lookup = " " .. reverse:lookup(cand.text) .. " "
    local short = string.match(lookup, " ([bcdefghjklmnpqrstwxyz][auiov]+) ") or
        string.match(lookup, " ([bcdefghjklmnpqrstwxyz][bcdefghjklmnpqrstwxyz]) ")
    local input = context.input
    if short and utf8.len(input) > utf8.len(short) and not startswith(short, input) then
        cand:get_genuine().comment = cand.comment .. "〔" .. short .. "〕"
        return true
    end

    return false
end

local function danzi(cand)
    if utf8.len(cand.text) < 2 then
        return true
    end
    return false
end

local function commit_hint(cand, hint_text)
    cand:get_genuine().comment = hint_text .. cand.comment
end

local function filter(input, env)
    local is_danzi = env.engine.context:get_option('danzi_mode')
    local is_on = env.engine.context:get_option('sbb_hint')
    local disable_full = env.engine.context:get_option('sbb_disable_full')
    local topup_hint_on = env.engine.context:get_option('topup_hint')
    local hint_text = env.engine.schema.config:get_string('hint_text') or '🚫'
    local first = true
    local input_text = env.engine.context.input
    local no_commit = topup_hint_on and input_text:len() < 4 and input_text:match("^[bcdefghjklmnpqrstwxyz]+$")
    for cand in input:iter() do
        if first and no_commit and cand.type ~= 'completion' then
            commit_hint(cand, hint_text)
        end
        first = false
        if not is_danzi or danzi(cand) then
            local has_630 = false
            if is_on then
                has_630 = hint(cand, env.engine.context, env.reverse)
            end
            if not has_630 or not disable_full then
                yield(cand)
            end
        end
    end
end

local function init(env)
    env.reverse = ReverseDb("build/keytao.extended.reverse.bin")
end

return { init = init, func = filter }
