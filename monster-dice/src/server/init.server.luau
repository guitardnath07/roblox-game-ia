--!strict
-- Bootstrap serveur : charge chaque module de Services/, appelle Init() sur tous, puis Start() sur tous.
-- Init = préparer (aucun yield), Start = démarrer (peut yield, lancé dans son propre thread).

type Service = {
	Init: ((self: Service) -> ())?,
	Start: ((self: Service) -> ())?,
}

local services: { Service } = {}
for _, module in script.Services:GetChildren() do
	if module:IsA("ModuleScript") then
		table.insert(services, (require :: any)(module))
	end
end

for _, service in services do
	if service.Init then
		service:Init()
	end
end

for _, service in services do
	if service.Start then
		task.spawn(service.Start, service)
	end
end
