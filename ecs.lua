local ecs = {}
-- System
function ecs.NewSystem( self )
    self = self or {}
    return self
end

-- World
function ecs.NewWorld(...)
    local self = {
        -- system
        systems         = {},
        systemsToAdd    = {},
        systemsToRemove = {},
        -- entity
        entities         = {},
        entitiesToAdd    = {},
        entitiesToRemove = {},
    }
    local function handleSystem()
        local toRemove = self.systemsToRemove
        local toAdd    = self.systemsToAdd
        local container= self.systems
        if #toRemove == 0 and #toAdd == 0 then
            return
        end
        self.systemsToAdd = {}
        self.systemsToRemove = {}
        -- do remove
        for i,sys in ipairs(toRemove) do
            local index = sys.index
            table.remove(container, index)
            -- reset array tail system's index
            for j=index,#container do
                container[j].index = j
            end
            if self.OnRemoveSystem then
                self.OnRemoveSystem( sys )
            end
        end
        -- do add
        for i,sys in ipairs(toAdd) do
            local index = #container + 1
            sys.world = self
            sys.index = index
            if sys.active == nil then
                sys.active = true
            end
            container[index] = sys
            if self.OnAddSystem then
                self.OnAddSystem( sys )
            end
        end
    end

    local function handleEntity()
        local toRemove = self.entitiesToRemove
        local toAdd    = self.entitiesToAdd
        local container= self.entities
        if #toRemove == 0 and #toAdd == 0 then
            return
        end
        self.entitiesToAdd = {}
        self.entitiesToRemove = {}
        -- do remove
        for i,entity in ipairs(toRemove) do
            for j,v in ipairs(container) do
                if entity == v then
                    table.remove(container, j)
                    break
                end
            end
        end
        -- do add
        for i,entity in ipairs(toAdd) do
            local index = #container + 1
            container[index] = entity
            if self.OnAddEntity then
                self.OnAddEntity( entity )
            end
        end
    end

    local function updateSystem( system, dt )
        system.entities = {}
        local filter = system.Filter
        if filter then
            local entities = system.world.entities
            for i,entity in ipairs(entities) do
                if filter( entity ) then
                    table.insert(system.entities, entity)
                end
            end
        end

        system.Update( dt )
    end

    local function invokeUpdate( dt )
        local systems = self.systems

        -- PreUpdate
        for _,system in ipairs(systems) do
            if system.active and system.PreUpdate then
                system.PreUpdate( dt )
            end
        end
        -- Update
        for _,system in ipairs(systems) do
            if system.active and system.Update then
                updateSystem(system, dt)
            end
        end
        -- PostUpdate
        for _,system in ipairs(systems) do
            if system.active and system.PostUpdate then
                system.PostUpdate( dt )
            end
        end
    end

    function self.AddSystem( sys )
        local i = #self.systemsToAdd
        self.systemsToAdd[i+1] = sys
        sys.world = self
        return sys
    end
    function self.RemoveSystem( sys )
        local i = #self.systemsToRemove
        self.systemsToRemove[i+1] = sys
        return sys
    end
    function self.AddEntity( e )
        local i = #self.entitiesToAdd
        self.entitiesToAdd[i+1] = e
        return e
    end
    function self.RemoveEntity( e )
        local i = #self.entitiesToRemove
        self.entitiesToRemove[i+1] = e
        return e
    end

    function self.Update( dt )
        handleSystem()
        handleEntity()
        --
        invokeUpdate( dt )
    end

    function self.SetSystemIndex( system, index )
        local oldIndex = system.index
        table.remove(self.systems, oldIndex)
        table.insert(self.systems, index, system)
        for i = oldIndex, index, index >= oldIndex and 1 or -1 do
            self.systems[i].index = i
        end
    end

    for i = 1, select('#', ...) do
        local sys = select(i, ...)
        self.AddSystem(sys)
    end
    return self
end

return ecs
