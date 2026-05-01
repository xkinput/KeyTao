local function startswith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

local function hint(cand, input_text, input_len, env)
    if utf8.len(cand.text) < 2 then
        return false
    end

    local lookup = " " .. env.reverse:lookup(cand.text) .. " "
    local short = string.match(lookup, env.pat_short_vowel) or
        string.match(lookup, env.pat_short_cons)
    if short and input_len > utf8.len(short) and not startswith(short, input_text) then
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
    local context = env.engine.context
    local is_danzi = context:get_option('danzi_mode')
    local is_on = context:get_option('sbb_hint')
    local disable_full = context:get_option('sbb_disable_full')
    local topup_hint_on = context:get_option('topup_hint')
    local first = true
    local input_text = context.input
    local input_len = utf8.len(input_text)
    local no_commit = topup_hint_on and input_text:len() < 4 and input_text:match(env.pat_no_commit)
    for cand in input:iter() do
        if first and no_commit and cand.type ~= 'completion' then
            commit_hint(cand, env.hint_text)
        end
        first = false
        if not is_danzi or danzi(cand) then
            local has_630 = false
            if is_on then
                has_630 = hint(cand, input_text, input_len, env)
            end
            if not has_630 or not disable_full then
                yield(cand)
            end
        end
    end
end

local function init(env)
    if not keytao_reverse_db then
        keytao_reverse_db = ReverseDb("build/keytao.extended.reverse.bin")
    end
    env.reverse         = keytao_reverse_db
    env.hint_text       = env.engine.schema.config:get_string('hint_text') or '🚫'
    env.pat_short_vowel = " ([bcdefghjklmnpqrstwxyz][auiov]+) "
    env.pat_short_cons  = " ([bcdefghjklmnpqrstwxyz][bcdefghjklmnpqrstwxyz]) "
    env.pat_no_commit   = "^[bcdefghjklmnpqrstwxyz]+$"
end

return { init = init, func = filter }
