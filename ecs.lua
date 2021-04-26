local function table_encode(...)
    local node = {...}
    if #node == 1 and type(node[1]) == 'table' then
        node = node[1]
    end
    -- to make output beautiful
    local function tab(amt)
        local str = ""
        for i = 1, amt do
            str = str .. "  "
        end
        return str
    end

    local cache, stack, output = {}, {}, {}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k, v in pairs(node) do
            size = size + 1
        end

        local cur_index = 1
        for k, v in pairs(node) do
            if (cache[node] == nil) or (cur_index >= cache[node]) then

                if (string.find(output_str, "}", output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str, "\n", output_str:len())) then
                    output_str = output_str .. "\n"
                end

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output, output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "["..tostring(k) .. "]"
                else
                    key = "['"..tostring(k) .. "']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. tab(depth) .. key .. " = "..tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. tab(depth) .. key .. " = {\n"
                    table.insert(stack, node)
                    table.insert(stack, v)
                    cache[node] = cur_index + 1
                    break
                else
                    output_str = output_str .. tab(depth) .. key .. " = '"..tostring(v) .. "'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. tab(depth) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. tab(depth) .. "}"
                end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. tab(depth) .. "}"
        end

        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end

    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output, output_str)
    output_str = table.concat(output)

    --print(output_str)
    return output_str
end


local ecs = {}
local MTReadonly = {
    __newindex = function ()
    end
}
function ecs.NewManager()
    local self = {}
    local entityId = 1
    local allEntities  = {} -- map[entity][entity]
    local allSystem    = {} -- system array
    local allComponent = {} -- map[component type] map[entity] component
    local frameCount = 1
    -- system
    local addSys = {}
    local remSys = {}
    local function handleSystemRemove()
        if #remSys == 0 then return end
        local keep = {}
        for _, v1 in ipairs(allSystem) do
            local match = false
            for _, v2 in ipairs(remSys) do
                if v1 == v2 then -- match remove
                    match = true
                    break
                end
            end
            if not match then
                table.insert(keep, v1)
            end
        end
        allSystem = keep
        remSys = {}
    end
    local function handleSystemAdd()
        if #addSys == 0 then return end
        for _, value in ipairs(addSys) do
            table.insert(allSystem, value)
        end
        addSys = {}
    end
    local function handleSystemUpdate()
        for _, sys in ipairs(allSystem) do
            if sys.Update then
                sys.Update(self)
            end
        end
    end
    -- entity
    function self.Update()
        handleSystemRemove()
        handleSystemAdd()
        handleSystemUpdate()
        frameCount = frameCount + 1
    end
    
    function self.NewEntity()
        local id = entityId
        if allEntities[id] then -- id has been used
            entityId = entityId + 1
            return self.NewEntity()
        end
        allEntities[id] = id
        entityId = entityId + 1
        return id
    end
    function self.RemoveEntity(e)
        allEntities[e] = nil
    end
    function self.AddSystem(sys)
        if type(sys.Update) ~= "function" then return end
        table.insert(addSys, sys)
    end
    function self.handleRemoveSystem(sys)
        if type(sys.Update) ~= "function" then return end
        table.insert(remSys, sys)
    end
    -- component
    function self.AddComponent(e, c, t)
        local entMap = allComponent[t]
        if not entMap then
            entMap = {}
            allComponent[t] = entMap
        end
        entMap[e] = c
    end
    function self.RemoveComponent(e, t)
        local entMap = allComponent[t]
        if not entMap then
            return
        end
        entMap[e] = nil
    end
    function self.GetComponent(e, t)
        local entMap = allComponent[t]
        if not entMap then
            return nil
        end
        if not allEntities[e] then
            return nil
        end
        return entMap[e]
    end
    function self.GetAllComponent(t)
        local entMap = allComponent[t]
        if not entMap then
            return {}
        end
        local entities = {}
        local comps = {}
        for entity, comp in pairs(entMap) do
            if allEntities[entity] then -- still alive
                table.insert(entities, entity)
                table.insert(comps, comp)
            else
                entMap[entity] = nil
            end
        end
        return entities, comps
    end
    function self.GetFrameCount()
        return frameCount
    end
    function self.Encode()
        local obj = {
            frameCount   = frameCount,
            allEntities  = allEntities,
            allComponent = allComponent,
        }
        return table_encode(obj)
    end
    function self.Decode(data)
        if type(data) ~= "string" then return end
        local obj = load('return '..data)
        if not obj then return end
        obj = obj()
        allEntities  = obj.allEntities or {}
        allComponent = obj.allComponent or {}
        frameCount   = obj.frameCount or 0
    end
    setmetatable(self, MTReadonly)
    return self
    
end
return ecs
