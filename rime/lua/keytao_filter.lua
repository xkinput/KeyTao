local function startswith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

local function find_short(lookup, pattern)
    return string.match(lookup, "^" .. pattern .. "%s") or
        string.match(lookup, "%s" .. pattern .. "%s") or
        string.match(lookup, "%s" .. pattern .. "$") or
        string.match(lookup, "^" .. pattern .. "$")
end

local function ensure_reverse(env)
    if not env.reverse then
        env.reverse = ReverseDb("build/keytao.extended.reverse.bin")
    end
    return env.reverse
end

local function close_reverse(env)
    if env.reverse and env.reverse.close then
        pcall(function()
            env.reverse:close()
        end)
    end
    env.reverse = nil
end

local function hint(cand, input_text, input_len, env)
    if utf8.len(cand.text) < 2 then
        return false
    end

    local reverse = ensure_reverse(env)
    if not reverse then
        return false
    end

    local lookup = reverse:lookup(cand.text)
    local short = find_short(lookup, env.pat_short_vowel) or
        find_short(lookup, env.pat_short_cons)
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
    local reverse_used = false

    if not is_on or input_len == 0 then
        close_reverse(env)
    end

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
                reverse_used = reverse_used or env.reverse ~= nil
            end
            if not has_630 or not disable_full then
                yield(cand)
            end
        end
    end

    if reverse_used then
        close_reverse(env)
        collectgarbage("step", 64)
    end
end

local function init(env)
    env.reverse         = nil
    env.hint_text       = env.engine.schema.config:get_string('hint_text') or '🚫'
    env.pat_short_vowel = "([bcdefghjklmnpqrstwxyz][auiov]+)"
    env.pat_short_cons  = "([bcdefghjklmnpqrstwxyz][bcdefghjklmnpqrstwxyz])"
    env.pat_no_commit   = "^[bcdefghjklmnpqrstwxyz]+$"

    -- Force full GC after each commit and when idle: Lua cannot see C++ object
    -- sizes (ReverseDb), so without explicit GC the runtime underestimates
    -- live memory and collects too infrequently. See librime-lua issue #206/#307.
    local ctx           = env.engine.context
    env._commit_conn    = ctx.commit_notifier:connect(function()
        close_reverse(env)
        collectgarbage()
    end)
    env._update_conn    = ctx.update_notifier:connect(function(context)
        if not context:is_composing() then
            close_reverse(env)
            collectgarbage()
        end
    end)
end

local function fini(env)
    close_reverse(env)
    if env._commit_conn then
        env._commit_conn:disconnect()
        env._commit_conn = nil
    end
    if env._update_conn then
        env._update_conn:disconnect()
        env._update_conn = nil
    end
end

return { init = init, func = filter, fini = fini }
