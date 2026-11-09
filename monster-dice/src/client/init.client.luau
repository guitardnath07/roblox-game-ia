--!strict
-- Bootstrap client : charge chaque module de Controllers/, appelle Init() sur tous, puis Start() sur tous.

type Controller = {
	Init: ((self: Controller) -> ())?,
	Start: ((self: Controller) -> ())?,
}

local controllers: { Controller } = {}
for _, module in script.Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		table.insert(controllers, (require :: any)(module))
	end
end

for _, controller in controllers do
	if controller.Init then
		controller:Init()
	end
end

for _, controller in controllers do
	if controller.Start then
		task.spawn(controller.Start, controller)
	end
end
