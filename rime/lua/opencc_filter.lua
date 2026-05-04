-- OpenCC 兼容过滤器
-- 直接参考万象 super_replacer 的核心实现：
-- 1. 用规则驱动读取 schema
-- 2. 用 UserDb/LevelDb 重建文本映射
-- 3. emoji 走 append，简繁走 replace

local M = {}

-- 通用配置区：移植到其他方案时，通常只需要改这里和 schema 里的同名配置块。
local DEFAULT_NAMESPACE = "opencc_filter"
local DEFAULT_DB_NAME = "lua/opencc_filter"
local DEFAULT_DB_VERSION = "opencc_filter_v1"
local DEFAULT_DELIMITER = "|"
local DEFAULT_COMMENT_FORMAT = "〔%s〕"
local META_VERSION_KEY = "_opencc_filter_ver"

local insert = table.insert
local concat = table.concat
local s_match = string.match
local s_gmatch = string.gmatch
local s_format = string.format
local s_byte = string.byte
local s_sub = string.sub
local s_gsub = string.gsub
local s_upper = string.upper
local open = io.open
local type = type

local replacer_instance = nil
local fmm_cache = {}
local shared_pending = {}
local shared_comments = {}
local meta_key_prefix = "\001" .. "/"
local db_pool = setmetatable({}, { __mode = "v" })

local db_extends = {}

function db_extends:meta_fetch(key)
    return self._db:fetch(meta_key_prefix .. key)
end

function db_extends:meta_update(key, value)
    return self._db:update(meta_key_prefix .. key, value)
end

function db_extends:query_with(prefix, handler)
    local da = self._db:query(prefix)
    if da then
        for key, value in da:iter() do
            handler(key, value)
        end
    end
    da = nil
    collectgarbage("step", 50)
end

function db_extends:empty(include_metafield)
    self:query_with("", function(key, _)
        local is_meta = key:find(meta_key_prefix, 1, true) == 1
        if include_metafield or not is_meta then
            self._db:erase(key)
        end
    end)
end

local db_mt = {
    __index = function(wrapper, key)
        if db_extends[key] then
            return db_extends[key]
        end
        local real_db = wrapper._db
        local value = real_db[key]
        if type(value) == "function" then
            return function(_, ...)
                return value(real_db, ...)
            end
        end
        return value
    end,
}

local function level_db(db_name)
    local key = db_name .. ".userdb"
    local db = db_pool[key]
    if not db then
        db = UserDb(db_name, "userdb")
        db_pool[key] = db
    end
    return setmetatable({ _db = db }, db_mt)
end

local function clear_table(t)
    for i = 1, #t do
        t[i] = nil
    end
end

local function get_utf8_offsets(text)
    local offsets = {}
    local len = #text
    local i = 1
    while i <= len do
        insert(offsets, i)
        local b = s_byte(text, i)
        if b < 128 then
            i = i + 1
        elseif b < 224 then
            i = i + 2
        elseif b < 240 then
            i = i + 3
        else
            i = i + 4
        end
    end
    insert(offsets, len + 1)
    return offsets
end

local function generate_files_signature(tasks)
    local sig_parts = {}
    for _, task in ipairs(tasks) do
        local f = open(task.path, "rb")
        if f then
            local size = f:seek("end")
            local head = ""
            local mid = ""
            local tail = ""
            if size > 0 then
                f:seek("set", 0)
                head = f:read(64) or ""
                local tail_pos = size - 64
                if tail_pos < 0 then
                    tail_pos = 0
                end
                f:seek("set", tail_pos)
                tail = f:read(64) or ""
                local mid_pos = math.floor(size / 2)
                f:seek("set", mid_pos)
                mid = f:read(64) or ""
            end
            f:close()
            insert(sig_parts, (task.prefix or "") .. size .. head .. mid .. tail)
        end
    end
    return concat(sig_parts, "||")
end

local function dirname(path)
    return s_match(path or "", "^(.*[/\\])") or ""
end

local function read_text_file(path)
    local f = open(path, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
    return content
end

local function add_opencc_config_tasks(tasks, config_path, prefix, resolve_path)
    local resolved = resolve_path(config_path)
    if not resolved then
        return
    end
    local content = read_text_file(resolved)
    if not content then
        return
    end
    local base_dir = dirname(config_path)
    local seen = {}
    for file_name in s_gmatch(content, '"file"%s*:%s*"([^"]+)"') do
        if file_name ~= "" and not seen[file_name] then
            seen[file_name] = true
            local relative = file_name
            if not s_match(relative, "^[A-Za-z]:[/\\]") and not s_match(relative, "^[/\\]") then
                relative = base_dir .. relative
            end
            local p = resolve_path(relative)
            if p then
                insert(tasks, { path = p, prefix = prefix })
            end
        end
    end
end

local function rebuild(tasks, db, delimiter)
    if db.empty then
        db:empty()
    end

    for _, task in ipairs(tasks) do
        local f = open(task.path, "r")
        if f then
            for line in f:lines() do
                if line ~= "" and not s_match(line, "^%s*#") then
                    local k, v = s_match(line, "^([^\t]+)\t+(.+)")
                    if k and v then
                        v = s_match(v, "^%s*(.-)%s*$")
                        local db_key = (task.prefix or "") .. k
                        local existing_v = db:fetch(db_key)
                        if existing_v and existing_v ~= "" then
                            v = existing_v .. delimiter .. v
                        end
                        db:update(db_key, v)
                    end
                end
            end
            f:close()
        end
    end
    return true
end

local function connect_db(db_name, current_version, delimiter, tasks, config_sig)
    if replacer_instance then
        local ok = pcall(function()
            return replacer_instance:fetch("___test___")
        end)
        if ok then
            return replacer_instance
        end
        replacer_instance = nil
    end

    local db = level_db(db_name)
    if not db then
        return nil
    end

    local current_signature = generate_files_signature(tasks) .. "||" .. (config_sig or "")
    local needs_rebuild = false

    if db:open_read_only() then
        local db_ver = db:meta_fetch(META_VERSION_KEY) or ""
        local db_delim = db:meta_fetch("_delim")
        local db_sig = db:meta_fetch("_files_sig") or ""
        if db_ver ~= current_version or db_delim ~= delimiter or db_sig ~= current_signature then
            needs_rebuild = true
        end
        db:close()
    else
        needs_rebuild = true
    end

    if needs_rebuild and db:open() then
        if db.clear then
            db:clear()
        elseif db.empty then
            db:empty()
        end
        rebuild(tasks, db, delimiter)
        fmm_cache = {}
        db:meta_update(META_VERSION_KEY, current_version)
        db:meta_update("_delim", delimiter)
        db:meta_update("_files_sig", current_signature)
        db:close()
    end

    if db:open_read_only() then
        replacer_instance = db
        return db
    end

    return nil
end

local function segment_convert(text, db, prefix, split_pat)
    local offsets = get_utf8_offsets(text)
    local char_count = #offsets - 1
    local result_parts = {}
    local i = 1
    local max_lookahead = 6

    while i <= char_count do
        local start_byte = offsets[i]
        local matched = false
        local max_j = i + max_lookahead
        if max_j > char_count + 1 then
            max_j = char_count + 1
        end

        for j = max_j, i + 2, -1 do
            local end_byte = offsets[j] - 1
            local sub_text = s_sub(text, start_byte, end_byte)
            local cache_key = prefix .. sub_text
            local val = fmm_cache[cache_key]
            if val == nil then
                local db_res = db:fetch(cache_key)
                fmm_cache[cache_key] = db_res or false
                val = fmm_cache[cache_key]
            end
            if val then
                local first_val = s_match(val, split_pat)
                insert(result_parts, first_val or sub_text)
                i = j - 1
                matched = true
                break
            end
        end

        if not matched then
            local single_char = s_sub(text, start_byte, offsets[i + 1] - 1)
            local cache_key = prefix .. single_char
            local val = fmm_cache[cache_key]
            if val == nil then
                local db_res = db:fetch(cache_key)
                fmm_cache[cache_key] = db_res or false
                val = fmm_cache[cache_key]
            end
            if val then
                local first_val = s_match(val, split_pat)
                insert(result_parts, first_val or single_char)
            else
                insert(result_parts, single_char)
            end
        end

        i = i + 1
    end

    return concat(result_parts)
end

local function split_utf8_chars(text, out)
    if not text or text == "" then
        return
    end
    local offsets = get_utf8_offsets(text)
    for i = 1, #offsets - 1 do
        local item = s_sub(text, offsets[i], offsets[i + 1] - 1)
        if item ~= "" and item ~= " " then
            insert(out, item)
        end
    end
end

local function append_split_items(out, raw_value, split_pat, split_mode, source_text)
    if not raw_value or raw_value == "" then
        return
    end

    for part in s_gmatch(raw_value, split_pat) do
        if split_mode == "emoji" then
            part = s_match(part, "^%s*(.-)%s*$") or part
            if source_text and source_text ~= "" then
                local escaped_source = s_gsub(source_text, "[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%1")
                part = s_gsub(part, "^" .. escaped_source .. "%s*", "")
            end
            for chunk in s_gmatch(part, "%S+") do
                split_utf8_chars(chunk, out)
            end
        else
            insert(out, part)
        end
    end
end

local function list_size(list)
    if not list then
        return 0
    end
    local ok, value = pcall(function()
        return list.size
    end)
    if ok and type(value) == "number" then
        return value
    end
    ok, value = pcall(function()
        return list:size()
    end)
    if ok and type(value) == "number" then
        return value
    end
    return 0
end

function M.init(env)
    local ns = env.name_space or ""
    ns = s_gsub(ns, "^%*", "")
    ns = s_match(ns, "([^%.]+)$") or ns
    if ns == "" then
        ns = DEFAULT_NAMESPACE
    end

    local config = env.engine.schema.config
    local user_dir = rime_api.get_user_data_dir()
    local shared_dir = rime_api.get_shared_data_dir()

    local db_name = config:get_string(ns .. "/db_name") or DEFAULT_DB_NAME
    local delim = config:get_string(ns .. "/delimiter") or DEFAULT_DELIMITER
    env.delimiter = delim
    env.comment_format = config:get_string(ns .. "/comment_format") or DEFAULT_COMMENT_FORMAT
    env.chain = config:get_bool(ns .. "/chain")
    if env.chain == nil then
        env.chain = false
    end
    env.rules = {}

    if delim == " " then
        env.split_pattern = "%S+"
    else
        local esc = s_gsub(delim, "[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%1")
        env.split_pattern = "([^" .. esc .. "]+)"
    end

    local function resolve_path(relative)
        if not relative then
            return nil
        end
        local user_path = user_dir .. "/" .. relative
        local f = open(user_path, "r")
        if f then
            f:close()
            return user_path
        end
        local shared_path = shared_dir .. "/" .. relative
        f = open(shared_path, "r")
        if f then
            f:close()
            return shared_path
        end
        return user_path
    end

    local tasks = {}
    local rules_path = ns .. "/rules"
    local rule_list = config:get_list(rules_path)

    if rule_list then
        for i = 0, list_size(rule_list) - 1 do
            local entry_path = rules_path .. "/@" .. i
            local triggers = {}
            local opts_keys = { "option", "options" }

            for _, key in ipairs(opts_keys) do
                local key_path = entry_path .. "/" .. key
                local list = config:get_list(key_path)
                if list then
                    for k = 0, list_size(list) - 1 do
                        local val = config:get_string(key_path .. "/@" .. k)
                        if val then
                            insert(triggers, val)
                        end
                    end
                else
                    if config:get_bool(key_path) == true then
                        insert(triggers, true)
                    else
                        local val = config:get_string(key_path)
                        if val and val ~= "true" then
                            insert(triggers, val)
                        end
                    end
                end
            end

            local target_tags = nil
            local tag_keys = { "tag", "tags" }
            for _, key in ipairs(tag_keys) do
                local key_path = entry_path .. "/" .. key
                local list = config:get_list(key_path)
                if list then
                    if not target_tags then
                        target_tags = {}
                    end
                    for k = 0, list_size(list) - 1 do
                        local val = config:get_string(key_path .. "/@" .. k)
                        if val then
                            target_tags[val] = true
                        end
                    end
                else
                    local val = config:get_string(key_path)
                    if val then
                        if not target_tags then
                            target_tags = {}
                        end
                        target_tags[val] = true
                    end
                end
            end

            if #triggers > 0 then
                local prefix = config:get_string(entry_path .. "/prefix") or ""
                local mode = config:get_string(entry_path .. "/mode") or "append"
                local comment_mode = config:get_string(entry_path .. "/comment_mode")
                if not comment_mode then
                    comment_mode = "comment"
                end
                local fmm = config:get_bool(entry_path .. "/sentence")
                if fmm == nil then
                    fmm = false
                end
                local custom_cand_type = config:get_string(entry_path .. "/cand_type")
                local split_mode = config:get_string(entry_path .. "/split")

                insert(env.rules, {
                    triggers = triggers,
                    tags = target_tags,
                    prefix = prefix,
                    mode = mode,
                    comment_mode = comment_mode,
                    fmm = fmm,
                    cand_type = custom_cand_type,
                    split_mode = split_mode,
                })

                local opencc_keys = { "opencc_configs", "opencc_config" }
                for _, key in ipairs(opencc_keys) do
                    local d_path = entry_path .. "/" .. key
                    local list = config:get_list(d_path)
                    if list then
                        for j = 0, list_size(list) - 1 do
                            local config_path = config:get_string(d_path .. "/@" .. j)
                            if config_path then
                                add_opencc_config_tasks(tasks, config_path, prefix, resolve_path)
                            end
                        end
                    else
                        local config_path = config:get_string(d_path)
                        if config_path then
                            add_opencc_config_tasks(tasks, config_path, prefix, resolve_path)
                            -- Fallback: native Opencc instance for .ocd2 binary dicts.
                            -- Rime's Opencc() searches under {user_dir}/opencc/ automatically,
                            -- so strip any leading "opencc/" prefix to avoid double-path.
                            if not env.rules[#env.rules].opencc_instance then
                                local occ_name = s_gsub(config_path, "^opencc/", "")
                                local ok, inst = pcall(Opencc, occ_name)
                                if ok and inst then
                                    env.rules[#env.rules].opencc_instance = inst
                                end
                            end
                        end
                    end
                end

                local keys_to_check = { "files", "file" }
                for _, key in ipairs(keys_to_check) do
                    local d_path = entry_path .. "/" .. key
                    local list = config:get_list(d_path)
                    if list then
                        for j = 0, list_size(list) - 1 do
                            local p = resolve_path(config:get_string(d_path .. "/@" .. j))
                            if p then
                                insert(tasks, { path = p, prefix = prefix })
                            end
                        end
                    else
                        local p = resolve_path(config:get_string(d_path))
                        if p then
                            insert(tasks, { path = p, prefix = prefix })
                        end
                    end
                end
            end
        end
    end

    local config_sig_parts = {}
    for _, t in ipairs(env.rules) do
        insert(config_sig_parts,
            tostring(t.fmm or false) .. (t.cand_type or "") .. (t.prefix or "") .. (t.split_mode or ""))
    end
    local config_sig = concat(config_sig_parts, "|")

    env.db = connect_db(db_name, DEFAULT_DB_VERSION, env.delimiter, tasks, config_sig)
end

function M.fini(env)
    env.db = nil
end

function M.func(input, env)
    local ctx = env.engine.context
    local db = env.db
    local rules = env.rules
    local split_pat = env.split_pattern
    local comment_fmt = env.comment_format
    local is_chain = env.chain

    if not ctx:is_composing() or ctx.input == "" then
        fmm_cache = {}
        collectgarbage("step", 200)
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    if not rules or #rules == 0 or not db then
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    local seg = ctx.composition:back()
    local current_seg_tags = seg and seg.tags or {}

    local function process_rules(cand)
        local results = {}
        local current_text = cand.text
        local show_main = true
        local current_main_comment = cand.comment
        local matched_cand_type = nil

        clear_table(shared_pending)
        clear_table(shared_comments)

        for _, rule in ipairs(rules) do
            local is_active = false
            for _, trigger in ipairs(rule.triggers) do
                if trigger == true then
                    is_active = true
                    break
                elseif type(trigger) == "string" and ctx:get_option(trigger) then
                    is_active = true
                    break
                end
            end

            local is_tag_match = true
            if rule.tags then
                is_tag_match = false
                for req_tag, _ in pairs(rule.tags) do
                    if current_seg_tags[req_tag] then
                        is_tag_match = true
                        break
                    end
                end
            end

            if is_active and is_tag_match then
                local query_text = is_chain and current_text or cand.text
                local key = (rule.prefix or "") .. query_text
                local val = db:fetch(key)
                if not val and string.find(query_text, "%u") then
                    val = db:fetch((rule.prefix or "") .. string.lower(query_text))
                end
                if not val and rule.fmm then
                    local seg_result = segment_convert(query_text, db, rule.prefix or "", split_pat)
                    if seg_result ~= query_text then
                        val = seg_result
                    end
                end

                if not val and rule.opencc_instance then
                    local ok, converted = pcall(function()
                        return rule.opencc_instance:convert(query_text)
                    end)
                    if ok and converted and converted ~= query_text then
                        val = converted
                    end
                end

                if val then
                    matched_cand_type = rule.cand_type or matched_cand_type

                    local mode = rule.mode
                    local rule_comment = ""
                    if rule.comment_mode == "text" then
                        rule_comment = cand.text
                    elseif rule.comment_mode == "comment" then
                        rule_comment = cand.comment
                    end
                    if mode ~= "comment" and rule_comment ~= "" then
                        rule_comment = s_format(comment_fmt, rule_comment)
                    end

                    if mode == "comment" then
                        local parts = {}
                        for p in s_gmatch(val, split_pat) do
                            insert(parts, p)
                        end
                        if #parts > 0 then
                            insert(shared_comments, concat(parts, " "))
                        end
                    elseif mode == "replace" then
                        if is_chain then
                            local first = true
                            for p in s_gmatch(val, split_pat) do
                                if first then
                                    current_text = p
                                    if rule.comment_mode == "none" then
                                        current_main_comment = ""
                                    elseif rule.comment_mode == "text" then
                                        current_main_comment = cand.text
                                    end
                                    first = false
                                else
                                    insert(shared_pending, { text = p, comment = rule_comment })
                                end
                            end
                        else
                            show_main = false
                            for p in s_gmatch(val, split_pat) do
                                insert(shared_pending, { text = p, comment = rule_comment })
                            end
                        end
                    elseif mode == "append" then
                        local parts = {}
                        append_split_items(parts, val, split_pat, rule.split_mode, cand.text)
                        for _, p in ipairs(parts) do
                            insert(shared_pending, { text = p, comment = rule_comment })
                        end
                    end
                end
            end
        end

        if #shared_comments > 0 then
            current_main_comment = s_format(comment_fmt, concat(shared_comments, " "))
        end

        if show_main then
            if is_chain and current_text ~= cand.text then
                local final_type = matched_cand_type or cand.type or "kv"
                local nc = Candidate(final_type, cand.start, cand._end, current_text, current_main_comment)
                nc.preedit = cand.preedit
                nc.quality = cand.quality
                insert(results, nc)
            else
                cand.comment = current_main_comment
                insert(results, cand)
            end
        end

        for _, item in ipairs(shared_pending) do
            if not (show_main and item.text == current_text) then
                local final_type = matched_cand_type or "derived"
                local nc = Candidate(final_type, cand.start, cand._end, item.text, item.comment)
                nc.preedit = cand.preedit
                nc.quality = cand.quality
                insert(results, nc)
            end
        end

        return results
    end

    for cand in input:iter() do
        local processed = process_rules(cand)
        for _, item in ipairs(processed) do
            yield(item)
        end
    end
end

return M
