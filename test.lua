local ecs = require('ecs')
local mgr = ecs.NewManager()

local e1 = mgr.NewEntity()
mgr.AddComponent(e1, {
    Name='A1',
    X = 1,
    HP = 2,
}, 1)

local e2 = mgr.NewEntity()
mgr.AddComponent(e2, {
    Name='A2',
    X = 10,
    HP = 5,
}, 1)

local sys = {}
function sys.Update(mgr)
    print('Frame:', mgr.GetFrameCount())
    local ents, comps = mgr.GetAllComponent(1)
    for index, value in ipairs(comps) do
        local entity = ents[index]
        value.X = value.X + 1
        value.HP = value.HP - 1
        if value.HP <= 0 then
            mgr.RemoveEntity(entity)
        end
        print(string.format('%d name:%s position:%s hp:%d', entity, value.Name, value.X, value.HP))
    end
end
mgr.AddSystem(sys)

mgr.Update()
mgr.Update()
mgr.Update()

local bin = mgr.Encode()
mgr.Decode(bin)

mgr.Update()
mgr.Update()
