local socket = require("socket")
local mime = require("mime")
local binser = require("binser")

local luarpc = {}
local servants = {}
local socket_list = {}
local client_servants = {}

TIMEOUT = 3

local error_message = function(msg)
	return {false, msg}
end


local error_message_type = function(value, expected_type)
	return "Expected type: " .. tostring(expected_type) .. ", got: " .. tostring(type(value)) .." instead"
end


-- Parse of interface.
-- Return an object to interface and another one to 
-- the struct 
interface = function(file_name)
	io.input(file_name)
	local input = io.read("*all")
	
	local startI, endI = string.find(input, "interface", 1)
	local minterface = string.sub(input, startI)
	
	local f2 = nil
	local startS = string.find(input, "struct") 
	if startS ~= nil then
		local mstruct = string.sub(input, startS, startI - 1)
		mstruct = string.gsub(mstruct, "^struct", "return")
		f2 = load(mstruct)
		f2 = f2()
	end

	minterface = string.gsub(minterface, "^interface", "return")
	local f1 = load(minterface)
	
	return f1(), f2
end


-- Validates the struct fields based on the keys
local validate_struct_fields = function(struct, struct_fields)

	local ret = {true}
	for _, fields in pairs(struct_fields) do
		if not struct[fields.name] then
			ret = error_message("Wrong struct fields")
			break
		end
	end	

	return ret
end


-- Function used to validate the arguments passed to the validate_params function 
local check_type = function(value, expected_type, struct_interface)
	
	if expected_type == "double" and type(value) ~= "number" then
		return error_message(error_message_type(value, expected_type))

	elseif expected_type == "string" and type(value) ~= "string" then
		return error_message(error_message_type(value, expected_type))

	elseif expected_type == "char" and (#value ~= 1 or type(value) ~= "string") then
		return error_message(error_message_type(value, expected_type))

	elseif expected_type == "void" and type(value) ~= nil then
		return error_message(error_message_type(value, expected_type))
	elseif type(value) == "table" then

		if struct_interface == nil then
                	return error_message("Struct not specified in the interface")
        	
		elseif value["name"] ~= expected_type then
			local msg = "Expected type: " .. tostring(expected_type) .. ", got: " .. tostring(value["name"]) .." instead"
                        return error_message(msg)
		else
			return validate_struct_fields(value["fields"], struct_interface.fields)
		end
	end
	return {true}
end


-- Computes the number of parameters expected by a function 
-- specified by the interface
local count_parameter = function(args_interface, direction)
	local count = 0

	for _, arg in pairs(args_interface) do

		if direction == "input" then 
                	if (arg.direction == "in" or arg.direction == "inout") and
				arg.type ~= "void" then 
				count = count + 1 
			end
		else 
			if (arg.direction == "out" or arg.direction == "inout") then
                         count = count + 1
		 	end
		end

	end

	return count
end


-- Validates arguments passed to a function
local validate_params = function(args, args_interface, struct_interface)

	n = count_parameter(args_interface, "input")
	if #args ~= n then
		local msg = tostring(#args) .. " arguments passed to function which requires " .. tostring(n)
		return error_message(msg)
	end

	local ret 
	for index, arg in pairs(args_interface) do

		if arg.direction == "in" or arg.direction == "inout" then
	
			ret = check_type(args[index], arg.type, struct_interface)			
			if  #ret > 1 then
				break
			end	
		end
	end

	return ret
end


-- Validates the response returned by the remote call service
local validate_response = function(resp, args_interface, resp_type)

	n = count_parameter(args_interface, "output")

	if resp_type ~= "void" then n = n + 1 end
	
	if #resp ~= n then 
		local msg = tostring(#resp).." results returned instead of "..tostring(n)
		return {false, msg}
	end

	return {true}
end


luarpc.pack = function(data)
	return mime.b64(binser.serialize(table.unpack(data)))
end


luarpc.unpack = function(data)
	return binser.deserialize(mime.unb64(data))
end


-- Dynamic function creation
local proxy_function = function(proxy, func_name)


	proxy[func_name] = function(...)
		local func = proxy.interface.methods[func_name]
		if func == nil then 
			error("Function '" ..func_name .. "' does not existe")
		end

		-- Gets arguments passed by the function call
		local args = {...}

          	-- Validates arguments      
                local ret = validate_params(args, proxy.interface.methods[func_name].args, proxy.struct)
                
		if #ret > 1 then error(ret[2]) end

                data = args
                table.insert(data, 1, func_name)
                local request = luarpc.pack(data)

		-- Creates a socket to require a service
                local client = assert(socket.tcp())
		client:settimeout(TIMEOUT) 

		print("Trying to connect at ", proxy.ip, proxy.port)
                local ok, err = client:connect(proxy.ip, proxy.port)
	
		if not ok then 
			local msg = ": Could not open a connection to "..tostring(proxy.ip).." on port "..tostring(proxy.port)
			error(err .. msg) 
		end

		-- Sends the request to the specified port	
                client:send(request .. '\n')
        

       		local msg, err = client:receive()

		local resp = nil

		if not err then
		
			resp = luarpc.unpack(msg)

			if not resp[1] then error(resp[2]) end
			table.remove(resp,1)
		
			return table.unpack(resp)
		
		else
			if err == "closed" then
				client:close()
				remove_client(client)
			end
		end

		return resp
	end 
	return proxy[func_name]
end 	


luarpc.createProxy = function(file_interface, ip, port)

	-- Validates function arguments
	if type(file_interface) ~= "string" or ip == nil or port == nil  then
		error("Invalid arguments: \nIP: " .. tostring(ip) .. "\nPORT: "..tostring(port)..
		"\nFile interface: "..tostring(file_interface))
	end

	local myinterface, mystruct = interface(file_interface)

	-- proxy object 
	local pobj = {
		ip = ip,
		port = port,
		interface = myinterface,
		struct = mystruct
	}	
  		
	setmetatable(pobj, {__index = proxy_function})

	return pobj
end

port = 5500
luarpc.createServant = function(file_interface, obj)

	-- Validates function arguments
	if type(file_interface) ~= "string" or type(obj) ~= "table" then
		error("Invalid arguments")
	end
	
    -- Comment this to use
	-- Fixed port to test		
	if port >= 5500 and port < 5509 then 
		port = port + 1
	end

	-- Obtem o ip atraves do hostname da maquina
	local IP = socket.dns.toip(socket.dns.gethostname())
	local server = assert(socket.bind(IP, port))  

	server:setoption("keepalive", true)
	server:settimeout(TIMEOUT)

	-- Obtem o ip e a porta do servico gerado
	local ip, port = server:getsockname()

	local myinterface, mystruct = interface(file_interface)
	
	local servant = {
		interface = myinterface,
		struct = mystruct,
		functions = obj,
		server = server,
		ip = ip,
		port = port,
		pool_clients = {}
	}

	servants[servant.server] = servant
	table.insert(socket_list, servant.server)

	return servant.ip, servant.port
end


local free_oldest_connection = function(servant)

	local client = servant.pool_clients[1]
	client:close()
	remove_client(client)
end 


local remove_element = function(mytable, element)
	local ret = false
	for i, v in pairs(mytable) do
		if v == element then
			ret = true
			table.remove(mytable, i)
			
			break
		end
	end
	return ret
end

remove_client = function(client) 

	servant = client_servants[client]

	print("Removes client from server IP:", 
		tostring(servant.ip), "and PORT: ", tostring(servant.port))

	if remove_element(socket_list, client) then
		print("Client removed from socket_list")
	end	
	if remove_element(servant.pool_clients, client) then
		print("Client removed from pool")
	end	

	client_servants[client] = nil
end 


luarpc.waitIncoming = function()

	while 1 do
		-- Aguarda por um novo cliente
		canread = socket.select(socket_list)
		for _, socket in ipairs(canread) do	
	
			servant = servants[socket]

			-- Verifica se o pedido eh um accept ou um receive 
			if servant then
				client = servant.server:accept()

				if client then
				
					if #servant.pool_clients == 3 then
						free_oldest_connection(servant)
					end 

					table.insert(socket_list, client)
					table.insert(servant.pool_clients, client)
					print("table size pool:", #servant.pool_clients)
					client_servants[client] = servant
				end
			else
				local client = socket

				local msg, err = client:receive()
				
				if not err then 

					local data = luarpc.unpack(msg)
					local func_name = data[1]
					local servant = client_servants[client]

					if servant.functions[func_name] == nil then
						local msg = "Requested function ".. func_name.." is not available"
						local resp = luarpc.pack({false, msg})
                                                client:send(resp .. "\n")

					else
						local func = servant.functions[func_name]	
					
						-- remove o nome da funcao	
						table.remove(data,1)
											
						-- executa o metodo passando os parametros recebidos
						local response = {func(table.unpack(data))}

						-- Valida a resposta
						local args = servant.interface.methods[func_name].args
						local result_type = servant.interface.methods[func_name].resulttype
						local ret = validate_response(response, args, result_type)
					
						if #ret > 1 then
							response = ret
						else
							table.insert(response, 1, true)
						end
				
						-- Empacota o resultado 
						local resp = luarpc.pack(response)

						-- Envia a resposta ao stub cliente
						client:send(resp .. "\n")
				
					end
				end
					-- Remove clientes com conexao fechada
					for idClient, v in pairs(client_servants) do
						
						local client_info = idClient:getpeername()
						if not client_info then
							remove_client(idClient)
						end
					end
			end
		end
	end
end



return luarpc
