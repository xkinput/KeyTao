local KEY       = "apostrophe"
local kRejected = 0 -- do the OS default processing
local kAccepted = 1 -- consume it
local kNoop     = 2 -- leave it to other processors

local function processor(key_event, env)
    -- 尽早返回以节省开销
    if key_event:release() or key_event:repr() ~= KEY then
        return kNoop
    end

    local engine = env.engine
    local schema = engine.schema
    local context = engine.context
    local page_size = schema.page_size
    local segment = context.composition:back()
    if not segment then
        context:clear()
        return kAccepted
    end
    local selected_index = segment.selected_index
    local page_start = math.floor(selected_index / page_size) * page_size

    if context:select(page_start + 1) then
        context:commit()
        return kAccepted
    end

    if not env.engine.context:get_selected_candidate() then
        context:clear()
    else
        context:commit()
    end
    return kAccepted
end

return { func = processor }
