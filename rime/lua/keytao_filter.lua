local consonant = "[bcdefghjklmnpqrstwxyz]"
local short_vowel = "%s(" .. consonant .. "[auiov]+)%s"
local short_cons = "%s(" .. consonant .. consonant .. ")%s"

local function find_short(lookup)
    local padded = " " .. lookup .. " "
    return padded:match(short_vowel) or padded:match(short_cons)
end

local function ensure_reverse(env)
    if not env.reverse then
        env.reverse = ReverseDb(env.reverse_path)
    end
    return env.reverse
end

local function short_code(text, env)
    local cache = env.short_codes
    local short = cache[text]
    if short == nil then
        local reverse = ensure_reverse(env)
        if not reverse then
            return false
        end
        short = find_short(reverse:lookup(text)) or false
        cache[text] = short
    end
    return short
end

local function filter(input, env)
    local context = env.engine.context
    local is_danzi = context:get_option('danzi_mode')
    local is_on = context:get_option('sbb_hint')
    local disable_full = context:get_option('sbb_disable_full')
    local topup_hint_on = context:get_option('topup_hint')
    local input_text = context.input
    local input_len = is_on and not is_danzi and utf8.len(input_text) or 0
    -- A 630 code is at least two ASCII characters and must be shorter than the input.
    local show_630 = input_len > 2

    if show_630 then
        env.short_codes = env.short_codes or {}
    elseif not is_on or input_text == "" then
        env.reverse = nil
    end

    local no_commit = topup_hint_on and input_text:len() < 4 and input_text:match(env.pat_no_commit)
    for cand in input:iter() do
        local text = (is_danzi or show_630) and cand.text
        local text_len = text and utf8.len(text)
        if not is_danzi or text_len < 2 then
            local has_630 = false
            if show_630 and text_len >= 2 then
                local short = short_code(text, env)
                if short and input_len > #short then
                    cand:get_genuine().comment = cand.comment .. "〔" .. short .. "〕"
                    has_630 = true
                end
            end
            if not has_630 or not disable_full then
                if no_commit and cand.type ~= 'completion' then
                    cand:get_genuine().comment = env.hint_text .. cand.comment
                    no_commit = false
                end
                yield(cand)
            end
        end
    end

    if env.reverse then
        env.reverse = nil
        collectgarbage("step", 64)
    end
end

local function init(env)
    local dict = env.engine.schema.config:get_string("translator/dictionary")
    if not dict or dict == "" then
        dict = "keytao.extended"
    end

    env.reverse         = nil
    env.reverse_path    = "build/" .. dict .. ".reverse.bin"
    env.hint_text       = env.engine.schema.config:get_string('hint_text') or '⎵'
    env.pat_no_commit   = "^" .. consonant .. "+$"

    -- Force full GC when idle (also fires after every commit via Context::Clear):
    -- Lua cannot see C++ object sizes (ReverseDb), so without explicit GC the
    -- runtime underestimates live memory and collects too infrequently.
    -- See librime-lua issue #206/#307.
    local ctx           = env.engine.context
    env._update_conn    = ctx.update_notifier:connect(function(context)
        if not context:is_composing() then
            env.reverse = nil
            env.short_codes = nil
            collectgarbage()
        end
    end)
end

local function fini(env)
    env.reverse = nil
    env.short_codes = nil
    if env._update_conn then
        env._update_conn:disconnect()
        env._update_conn = nil
    end
end

return { init = init, func = filter, fini = fini }
