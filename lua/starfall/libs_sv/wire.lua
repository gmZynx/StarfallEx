local checkluatype = SF.CheckLuaType
local registerprivilege = SF.Permissions.registerPrivilege
local debug_getmetatable = debug.getmetatable
local ENT_META = FindMetaTable("Entity")

-- Register privileges
registerprivilege("wire.setOutputs", "Set outputs", "Allows the user to specify the set of outputs")
registerprivilege("wire.setInputs", "Set inputs", "Allows the user to specify the set of inputs")
registerprivilege("wire.wirelink", "Wirelink", "Allows the user to create a wirelink", { entities = {} })
registerprivilege("wire.wirelink.read", "Wirelink Read", "Allows the user to read from wirelink")
registerprivilege("wire.wirelink.write", "Wirelink Write", "Allows the user to write to wirelink")
registerprivilege("wire.createWire", "Create Wire", "Allows the user to create a wire between two entities", { entities = {} })
registerprivilege("wire.deleteWire", "Delete Wire", "Allows the user to delete a wire between two entities", { entities = {} })
registerprivilege("wire.trigger", "Direct Trigger", "Allows the user to directly trigger inputs", { entities = {} })
registerprivilege("wire.read", "Direct Read", "Allows the user to directly read inputs", { entities = {} })
registerprivilege("wire.getInputs", "Get Inputs", "Allows the user to get Inputs of an entity")
registerprivilege("wire.getOutputs", "Get Outputs", "Allows the user to get Outputs of an entity")

--- Wire library. Handles wire inputs/outputs, wirelinks, etc.
-- @name wire
-- @class library
-- @libtbl wire_library
SF.RegisterLibrary("wire")

--- Wirelink type
-- @name Wirelink
-- @class type
-- @libtbl wirelink_methods
-- @libtbl wirelink_meta
SF.RegisterType("Wirelink", false, true)

--- Vector2 type for wire xv2
-- @name Vector2
-- @class type
-- @libtbl vec2_meta
SF.RegisterType("Vector2", nil, nil, nil, "Vector", function(checktype, vec2_meta)
	return function(vec)
		return setmetatable({tonumber(vec[1]) or 0 , tonumber(vec[2]) or 0 , 0}, vec2_meta)
	end,
	function(obj)
		checktype(obj, vec2_meta, 2)
		return {tonumber(obj[1]) or 0, tonumber(obj[2]) or 0}
	end
end)

return function(instance)
if not (WireLib and WireLib.CreateInputs) then return end
local checkpermission = instance.player ~= SF.Superuser and SF.Permissions.check or function() end
local Ent_GetTable,Ent_IsValid = ENT_META.GetTable,ENT_META.IsValid

local wire_library = instance.Libraries.wire

local owrap, ounwrap = instance.WrapObject, instance.UnwrapObject
local ents_methods, ent_meta, ewrap, eunwrap = instance.Types.Entity.Methods, instance.Types.Entity, instance.Types.Entity.Wrap, instance.Types.Entity.Unwrap
local wirelink_methods, wirelink_meta, wlwrap, wlunwrap = instance.Types.Wirelink.Methods, instance.Types.Wirelink, instance.Types.Wirelink.Wrap, instance.Types.Wirelink.Unwrap
local vec_meta, vwrap, vunwrap = instance.Types.Vector, instance.Types.Vector.Wrap, instance.Types.Vector.Unwrap
local vec2_meta, v2wrap, v2unwrap = instance.Types.Vector2, instance.Types.Vector2.Wrap, instance.Types.Vector2.Unwrap
local ang_meta, awrap, aunwrap = instance.Types.Angle, instance.Types.Angle.Wrap, instance.Types.Angle.Unwrap
local col_meta, cwrap, cunwrap = instance.Types.Color, instance.Types.Color.Wrap, instance.Types.Color.Unwrap
local wirelink_meta, wlwrap, wlunwrap = instance.Types.Wirelink, instance.Types.Wirelink.Wrap, instance.Types.Wirelink.Unwrap
local COLOR_WHITE = Color(255, 255, 255)

local getent
instance:AddHook("initialize", function()
	getent = ent_meta.GetEntity

	local ent = instance.entity
	if ent.Inputs == nil then
		WireLib.CreateInputs(ent, {})
	end
	if ent.Outputs == nil then
		WireLib.CreateOutputs(ent, {})
	end

	function ent:TriggerInput(key, value)
		local tbl = Ent_GetTable(self)
		local instance = tbl.instance
		if instance then
			instance:runScriptHook("input", key, instance.WireToSF[tbl.Inputs[key].Type](value))
		end
	end

	function ent:ReadCell(address)
		local instance = Ent_GetTable(self).instance
		if instance then
			local tbl = instance:runScriptHookForResult("readcell", address)
			return tbl[1] and tonumber(tbl[2]) or 0
		end
		return 0
	end

	function ent:WriteCell(address, data)
		local instance = Ent_GetTable(self).instance
		if instance then
			local tbl = instance:runScriptHookForResult("writecell", address, data)
			return tbl[1] and (tbl[2]==nil or tbl[2]==true)
		end
		return false
	end
end)

local function getwl(self)
	local wl = wlunwrap(self)
	if Ent_IsValid(wl) then
		return wl
	else
		SF.Throw("Wirelink is not valid", 3)
	end
end

--#region Vector2 metaevents
local table_concat = table.concat
function vec2_meta.__tostring(a)
	return table_concat(a, ' ', 1, 2)
end

function vec2_meta.__mul(a, b)
	if isnumber(b) then
		return v2wrap({ a[1] * b, a[2] * b })
	elseif isnumber(a) then
		return v2wrap({ b[1] * a, b[2] * a })
	elseif debug_getmetatable(a) == vec2_meta and debug_getmetatable(b) == vec2_meta then
		return v2wrap({ a[1] * b[1], a[2] * b[2] })
	elseif debug_getmetatable(a) == vec2_meta then
		checkluatype(b, TYPE_NUMBER)
	else
		checkluatype(a, TYPE_NUMBER)
	end
end

function vec2_meta.__div(a, b)
	if isnumber(b) then
		return v2wrap({ a[1] / b, a[2] / b })
	elseif isnumber(a) then
		return v2wrap({ a / b[1], a / b[2] })
	elseif debug_getmetatable(a) == vec2_meta and debug_getmetatable(b) == vec2_meta then
		return v2wrap({ a[1] / b[1], a[2] / b[2] })
	elseif debug_getmetatable(a) == vec2_meta then
		checkluatype(b, TYPE_NUMBER)
	else
		checkluatype(a, TYPE_NUMBER)
	end
end

function vec2_meta.__add(a, b)
	return v2wrap({ a[1] + b[1], a[2] + b[2] })
end

function vec2_meta.__sub(a, b)
	return v2wrap({ a[1] - b[1], a[2] - b[2] })
end

function vec2_meta.__unm(a)
	return v2wrap({ -a[1], -a[2] })
end

function vec2_meta.__eq(a, b)
	return a[1] == b[1] and a[2] == b[2]
end
--#endregion

--- Creates a Vector2 struct for use with wire xv2 type
-- @name builtins_library.Vector2
-- @class function
-- @param number? x X value
-- @param number? y Y value
-- @return Vector2 Vector2
function instance.env.Vector2(x, y)
	if x ~= nil then checkluatype(x, TYPE_NUMBER) else x = 0 end
	if y ~= nil then checkluatype(y, TYPE_NUMBER) else y = x end
	return v2wrap({ x, y })
end

local typeToE2Type -- Assign next line since some funcs need it
typeToE2Type = {
	[TYPE_NUMBER] = function(x) return x, "n" end,
	[TYPE_STRING] = function(x) return x, "s" end,
	[vec_meta] = function(x) return vunwrap(x), "v" end,
	[vec2_meta] = function(v) return v2unwrap(v), "xv2" end,
	[ang_meta] = function(x) return aunwrap(x), "a" end,
	[TYPE_TABLE] = function(x)
		local meta = debug_getmetatable(x)
		if typeToE2Type[meta] then return typeToE2Type[meta](x) end
		x = ounwrap(x)
		if isentity(x) then return x, "e" end
	end
}

local WireToSF
WireToSF =
{
	NORMAL = function(x) return isnumber(x) and x or 0 end,
	STRING = function(x) return isstring(x) and x or "" end,
	VECTOR = function(vec) return setmetatable({ tonumber(vec[1] or vec.x), tonumber(vec[2] or vec.y), tonumber(vec[3] or vec.z) }, vec_meta) end,
	VECTOR2 = function(vec) return setmetatable({ tonumber(vec[1] or vec.x), tonumber(vec[2] or vec.y) }, vec2_meta) end,
	ANGLE = function(ang) return setmetatable({ tonumber(ang[1] or ang.p), tonumber(ang[2] or ang.y), tonumber(ang[3] or ang.r) }, ang_meta) end,
	WIRELINK = wlwrap,
	ENTITY = owrap,

	TABLE = function(data)
		local completed_tables = {}
		local function recursiveConvert(tbl)
			if not tbl.s or not tbl.stypes or not tbl.n or not tbl.ntypes or not tbl.size then return {} end
			if tbl.size == 0 then return {} end
			local conv = {}
			completed_tables[tbl] = conv

			-- Key-numeric part of table
			for key, typ in pairs(tbl.ntypes) do
				local val = tbl.n[key]
				if typ=="t" then
					conv[key] = completed_tables[val] or recursiveConvert(val)
				else
					conv[key] = WireToSF[typ] and WireToSF[typ](val)
				end
			end

			-- Key-string part of table
			for key, typ in pairs(tbl.stypes) do
				local val = tbl.s[key]
				if typ=="t" then
					conv[key] = completed_tables[val] or recursiveConvert(val)
				else
					conv[key] = WireToSF[typ] and WireToSF[typ](val)
				end
			end

			return conv
		end
		return recursiveConvert(data)
	end,
	ARRAY = function(tbl)
		local ret = {}
		for i, v in ipairs(tbl) do
			if istable(v) and isnumber(v[1] or v.x or v.p) and isnumber(v[2] or v.y) then
				if isnumber(v[3] or v.z or v.r) then
					ret[i] = WireToSF.VECTOR(v)
				else
					ret[i] = WireToSF.VECTOR2(v)
				end
			else
				ret[i] = owrap(v)
			end
		end
		return ret
	end
}
WireToSF.n = WireToSF.NORMAL
WireToSF.s = WireToSF.STRING
WireToSF.v = WireToSF.VECTOR
WireToSF.xv2 = WireToSF.VECTOR2
WireToSF.a = WireToSF.ANGLE
WireToSF.xwl = WireToSF.WIRELINK
WireToSF.e = WireToSF.ENTITY
WireToSF.t = WireToSF.TABLE
WireToSF.r = WireToSF.ARRAY
instance.WireToSF = WireToSF

local SFToWire =
{
	NORMAL = function(data) checkluatype(data, TYPE_NUMBER, 2) return data end,
	STRING = function(data) checkluatype(data, TYPE_STRING, 2) return data end,
	VECTOR = function(data) return vunwrap(data) end,
	VECTOR2 = function(data) return v2unwrap(data) end,
	ANGLE = function(data) return aunwrap(data) end,
	ENTITY = function(data) return getent(data) end,
	TABLE = function(data)
		checkluatype(data, TYPE_TABLE, 2)
		local completed_tables = {}

		local function recursiveConvert(tbl)
			local ret = { istable = true, size = 0, n = {}, ntypes = {}, s = {}, stypes = {} }
			completed_tables[tbl] = ret
			for key, value in pairs(tbl) do

				local ktyp = TypeID(key)
				local valueList, typeList
				if ktyp == TYPE_NUMBER then
					valueList, typeList = ret.n, ret.ntypes
				elseif ktyp == TYPE_STRING then
					valueList, typeList = ret.s, ret.stypes
				else
					continue
				end

				local vtyp = TypeID(value)
				local convertVal, convertType
				if typeToE2Type[vtyp] then
					convertVal, convertType = typeToE2Type[vtyp](value)
				end

				if convertVal then
					valueList[key], typeList[key] = convertVal, convertType
					ret.size = ret.size + 1
				elseif vtyp == TYPE_TABLE then
					valueList[key] = completed_tables[value] or recursiveConvert(value)
					typeList[key] = "t"
					ret.size = ret.size + 1
				end
			end

			return ret
		end
		return recursiveConvert(data)
	end,
	ARRAY = function(data)
		local ret = {}
		for i, v in ipairs(data) do
			local typ = typeToE2Type[TypeID(v)]
			ret[i] = typ and (typ(v)) or SF.Throw("Invalid type in array at index: " .. i, 3)
		end
		return ret
	end
}
instance.SFToWire = SFToWire


-- ------------------------- Basic Wire Functions ------------------------- --

local sfTypeToWireTypeTable = {
	N = "NORMAL",
	S = "STRING",
	V = "VECTOR",
	XV2 = "VECTOR2",
	A = "ANGLE",
	XWL = "WIRELINK",
	E = "ENTITY",
	T = "TABLE",
	NUMBER = "NORMAL"
}

--- Creates/Modifies wire inputs. All wire ports must begin with an uppercase
-- letter and contain only alphabetical characters or numbers but may not begin with a number.
-- @param table names An array of input names. May be modified by the function.
-- @param table types An array of input types. Can be shortcuts. May be modified by the function.
-- @param table? descriptions An optional array of input descriptions. 
function wire_library.adjustInputs(names, types, descriptions)
	checkpermission(instance, nil, "wire.setInputs")

	checkluatype(names, TYPE_TABLE)
	checkluatype(types, TYPE_TABLE)
	if descriptions ~= nil then
		checkluatype(descriptions, TYPE_TABLE)
	end

	local ent = instance.entity
	if not Ent_IsValid(ent) then SF.Throw("No entity to create inputs on", 2) end
	if #names ~= #types then SF.Throw("Table lengths not equal", 2) end

	local names_out, types_out, descriptions_out = {}, {}, {}

	for i = 1, #names do
		local name = names[i]
		if not isstring(name) then SF.Throw("Non-string input name at index " .. i, 2) end
		if not string.match(name, "^[%u][%a%d_]*$") then SF.Throw("Invalid input name: " .. name, 2) end
		names_out[i] = name

		local porttype = types[i]
		if not isstring(porttype) then SF.Throw("Non-string input type at index " .. i, 2) end
		porttype = string.upper(porttype)
		porttype = sfTypeToWireTypeTable[porttype] or porttype
		if not WireToSF[porttype] then SF.Throw("Invalid/unsupported input type: " .. porttype, 2) end
		types_out[i] = porttype

		if descriptions and descriptions[i] then
			local desc = descriptions[i]
			if not isstring(desc) then SF.Throw("Non-string input description at index " .. i, 2) end
			descriptions_out[i] = desc
		end
	end

	ent._inputs = { names_out, types_out, descriptions_out }
	WireLib.AdjustSpecialInputs(ent, names_out, types_out, descriptions_out)
end

--- Creates/Modifies wire outputs. All wire ports must begin with an uppercase
-- letter and contain only alphabetical characters or numbers but may not begin with a number.
-- @param table names An array of output names. May be modified by the function.
-- @param table types An array of output types. Can be shortcuts. May be modified by the function.
-- @param table? descriptions An optional array of output descriptions. 
function wire_library.adjustOutputs(names, types, descriptions)
	checkpermission(instance, nil, "wire.setOutputs")

	checkluatype(names, TYPE_TABLE)
	checkluatype(types, TYPE_TABLE)
	if descriptions ~= nil then
		checkluatype(descriptions, TYPE_TABLE)
	end

	local ent = instance.entity
	if not Ent_IsValid(ent) then SF.Throw("No entity to create outputs on", 2) end
	if #names ~= #types then SF.Throw("Table lengths not equal", 2) end

	local names_out, types_out, descriptions_out = {}, {}, {}

	for i = 1, #names do
		local name = names[i]
		if not isstring(name) then SF.Throw("Non-string output name at index " .. i, 2) end
		if not string.match(name, "^[%u][%a%d_]*$") then SF.Throw("Invalid output name: " .. name, 2) end
		names_out[i] = name

		local porttype = types[i]
		if not isstring(porttype) then SF.Throw("Non-string output type at index " .. i, 2) end
		porttype = string.upper(porttype)
		porttype = sfTypeToWireTypeTable[porttype] or porttype
		if not SFToWire[porttype] then SF.Throw("Invalid/unsupported output type: " .. porttype, 2) end
		types_out[i] = porttype

		if descriptions and descriptions[i] then
			local desc = descriptions[i]
			if not isstring(desc) then SF.Throw("Non-string input description at index " .. i, 2) end
			descriptions_out[i] = desc
		end
	end

	-- Restore wirelink and entity output if present, because these outputs are created by the Wire ToolGun
	-- and breaks on every code update.
	for k,v in pairs( ent.Outputs ) do
		if v.Name == "wirelink" or v.Name == "entity" then
			table.insert(names_out, v.Name)
			table.insert(types_out, v.Type)
		end
	end

	ent._outputs = { names_out, types_out, descriptions_out }
	WireLib.AdjustSpecialOutputs(ent, names_out, types_out, descriptions_out)
end

--- Creates/Modifies wire inputs/outputs. All wire ports must begin with an uppercase
-- letter and contain only alphabetical characters or numbers but may not begin with a number.
-- @param table? inputs (Optional) A key-value table with input port names as keys and types as values. e.g. {MyInput="number"} or {MyInput={type="number"}}. If nil, input ports won't be changed. If you use the latter syntax for defining ports, you can also specify description alongside the type, ex. {MyInput={type="number", description="Description for this input."}}
-- @param table? outputs (Optional) A key-value table with output port names as keys and types as values. The above behavior for inputs also applies for outputs.
function wire_library.adjustPorts(inputs, outputs)
	if inputs ~= nil then
		checkluatype(inputs, TYPE_TABLE)

		local ports, names, types, descs = {}, {}, {}, {}

		for n,t in pairs( inputs ) do
			local d = nil
			if istable(t) then
				d = t.description
				t = t.type
			end
			if not isstring(n) or not isstring(t) then SF.Throw("Inputs Error: Expected string string key value pairs, got a " .. SF.GetType(n) .. " " .. SF.GetType(t) .. " pair.", 2) end
			if d ~= nil and not isstring(d) then SF.Throw("Inputs Error: Expected IO description to be a string, got " .. SF.GetType(d)) end
			ports[#ports+1] = {string.lower(n),n,t,d}
		end
		table.sort(ports, function(a,b) return a[1]<b[1] end)
		for k, v in ipairs(ports) do
			names[k] = v[2]
			types[k] = v[3]
			descs[k] = v[4]
		end

		wire_library.adjustInputs(names, types, descs)
	end

	if outputs ~= nil then
		checkluatype(outputs, TYPE_TABLE)

		local ports, names, types, descs = {}, {}, {}, {}

		for n,t in pairs( outputs ) do
			local d = nil
			if istable(t) then
				d = t.description
				t = t.type
			end
			if not isstring(n) or not isstring(t) then SF.Throw("Outputs Error: Expected string string key value pairs, got a " .. SF.GetType(n) .. " " .. SF.GetType(t) .. " pair.", 2) end
			if d ~= nil and not isstring(d) then SF.Throw("Outputs Error: Expected IO description to be a string, got " .. SF.GetType(d)) end
			ports[#ports+1] = {string.lower(n),n,t, d}
		end
		table.sort(ports, function(a,b) return a[1]<b[1] end)
		for k, v in ipairs(ports) do
			names[k] = v[2]
			types[k] = v[3]
			descs[k] = v[4]
		end

		wire_library.adjustOutputs(names, types, descs)
	end
end

--- Returns the wirelink representing this entity.
-- @return Wirelink Wirelink representing this entity
function wire_library.self()
	local ent = instance.entity
	if not ent then SF.Throw("No entity", 2) end
	return wlwrap(ent)
end

--- Returns the server's UUID.
-- @return string Server UUID
function wire_library.serverUUID()
	return WireLib.GetServerUUID()
end

local ValidWireMat = { 	["cable/rope"] = true, ["cable/cable2"] = true, ["cable/xbeam"] = true, ["cable/redlaser"] = true, ["cable/blue_elec"] = true, ["cable/physbeam"] = true, ["cable/hydra"] = true, ["arrowire/arrowire"] = true, ["arrowire/arrowire2"] = true }
--- Wires two entities together
-- @param Entity entI Entity with input
-- @param Entity entO Entity with output
-- @param string inputname Input to be wired
-- @param string outputname Output to be wired
-- @param number? width Width of the wire(optional)
-- @param Color? color Color of the wire(optional)
-- @param string? materialName Material of the wire(optional), Valid materials are cable/rope, cable/cable2, cable/xbeam, cable/redlaser, cable/blue_elec, cable/physbeam, cable/hydra, arrowire/arrowire, arrowire/arrowire2
function wire_library.create(entI, entO, inputname, outputname, width, color, material)
	checkluatype(inputname, TYPE_STRING)
	checkluatype(outputname, TYPE_STRING)

	if width ~= nil then
		checkluatype (width, TYPE_NUMBER)
		width = math.Clamp(width, 0, 5)
	else
		width = 0
	end
	if color ~= nil then
		color = cunwrap(color)
	else
		color = COLOR_WHITE
	end
	material = ValidWireMat[material] and material or "cable/rope"

	entI = eunwrap(entI)
	entO = eunwrap(entO)

	if not Ent_IsValid(entI) then SF.Throw("Invalid target") end
	if not Ent_IsValid(entO) then SF.Throw("Invalid source") end

	checkpermission(instance, entI, "wire.createWire")
	checkpermission(instance, entO, "wire.createWire")

	if not entI.Inputs then SF.Throw("Target has no valid inputs") end
	if not entO.Outputs then SF.Throw("Source has no valid outputs") end

	if inputname == "" or not entI.Inputs[inputname] then SF.Throw("Invalid target input: " .. inputname) end
	if outputname == "entity" then WireLib.CreateEntityOutput( nil, entO, {true} )
	elseif outputname == "wirelink" then WireLib.CreateWirelinkOutput( nil, entO, {true} )
	elseif outputname == "" or not entO.Outputs[outputname] then SF.Throw("Invalid source output: " .. outputname)
	end

	WireLib.Link_Start(instance.player:UniqueID(), entI, entI:WorldToLocal(entI:GetPos()), inputname, material, color, width)
	WireLib.Link_End(instance.player:UniqueID(), entO, entO:WorldToLocal(entO:GetPos()), outputname, instance.player)
end

--- Unwires an entity's input
-- @param Entity entI Entity with input
-- @param string inputname Input to be un-wired
function wire_library.delete(entI, inputname)
	checkluatype(inputname, TYPE_STRING)

	entI = getent(entI)

	checkpermission(instance, entI, "wire.deleteWire")

	if not entI.Inputs or not entI.Inputs[inputname] then SF.Throw("Entity does not have input: " .. inputname) end
	if not entI.Inputs[inputname].Src then SF.Throw("Input \"" .. inputname .. "\" is not wired") end

	WireLib.Link_Clear(entI, inputname)
end

local function parseEntity(ent, io)

	if ent then
		ent = getent(ent)
		checkpermission(instance, ent, "wire.get" .. io)
	else
		ent = instance.entity
	end

	local names, types = {}, {}
	for k, v in pairs(ent[io]) do
		if isstring(k) and isstring(v.Type) and k ~= "" then
			table.insert(names, k)
			table.insert(types, v.Type)
		end
	end

	return names, types
end

--- Returns a table of entity's inputs
-- @param Entity entI Entity with input(s)
-- @return table Table of entity's input names
-- @return table Table of entity's input types
function wire_library.getInputs(entI)
	return parseEntity(entI, "Inputs")
end

--- Returns a table of entity's outputs
-- @param Entity entO Entity with output(s)
-- @return table Table of entity's output names
-- @return table Table of entity's output types
function wire_library.getOutputs(entO)
	return parseEntity(entO, "Outputs")
end

--- Returns a wirelink to a wire entity
-- @param Entity ent Wire entity
-- @return Wirelink Wirelink of the entity
function wire_library.getWirelink(ent)
	ent = getent(ent)
	checkpermission(instance, ent, "wire.wirelink")

	if not ent.extended then
		WireLib.CreateWirelinkOutput(instance.player, ent, { true })
	end

	return wlwrap(ent)
end

local function checkinput(inputs, k, converters)
	if not inputs then SF.Throw("Entity has no inputs", 4) end
	local input = inputs[k] or SF.Throw("Invalid input: "..k, 4)
	local convert = converters[input.Type] or SF.Throw("Invalid input type: "..input.Type, 4)
	return input, convert
end
local function checkoutput(outputs, k, converters)
	if not outputs then SF.Throw("Entity has no outputs", 4) end
	local output = outputs[k] or SF.Throw("Invalid output: "..k, 4)
	local convert = converters[output.Type] or SF.Throw("Invalid output type: "..output.Type, 3)
	return output, convert
end

local function triggerInput(ent, k, v)
	local input, convert = checkinput(Ent_GetTable(ent).Inputs, k, SFToWire)
	instance:runExternal(WireLib.TriggerInput, ent, k, convert(v))
end
local function triggerOutput(ent, k, v)
	local output, convert = checkoutput(Ent_GetTable(ent).Outputs, k, SFToWire)
	instance:runExternal(Wire_TriggerOutput, ent, k, convert(v))
end
local function triggerCell(ent, k, v)
	local WriteCell = Ent_GetTable(ent).WriteCell or SF.Throw("Entity does not have WriteCell capability", 3)
	instance:runExternal(WriteCell, ent, k, v)
end

local function readInput(ent, k)
	local input, convert = checkinput(Ent_GetTable(ent).Inputs, k, WireToSF)
	return convert(input.Value)
end
local function readOutput(ent, k)
	local output, convert = checkoutput(Ent_GetTable(ent).Outputs, k, WireToSF)
	return convert(output.Value)
end
local function readCell(ent, k)
	local ReadCell = Ent_GetTable(ent).ReadCell or SF.Throw("Entity does not have ReadCell capability", 3)
	local ok, n = instance:runExternal(ReadCell, ent, k)
	return ok and tonumber(n) or 0
end

--- Sets the value of an entity's input, triggering it as well
-- @param Entity ent Entity with input
-- @param string inputname Input name
-- @param any value The value to set the input to (must match the input type)
function wire_library.triggerInput(ent, inputname, value)
	checkluatype(inputname, TYPE_STRING)
	ent = getent(ent)
	checkpermission(instance, ent, "wire.trigger")
	triggerInput(ent, inputname, value)
end

--- Sets the value of an entity's output, triggering it as well
-- @param Entity ent Entity with output
-- @param string outputname Output name
-- @param any value The value to set the output to (must match the output type)
function wire_library.triggerOutput(ent, outputname, value)
	checkluatype(outputname, TYPE_STRING)
	ent = getent(ent)
	checkpermission(instance, ent, "wire.trigger")
	triggerOutput(ent, outputname, value)
end

--- Sets the value of an entity's wire memory, triggering it as well
-- @param Entity ent Entity with wire memory
-- @param number index The cell address
-- @param number value The value to set the cell
function wire_library.triggerCell(ent, index, value)
	checkluatype(index, TYPE_NUMBER)
	checkluatype(value, TYPE_NUMBER)
	ent = getent(ent)
	checkpermission(instance, ent, "wire.trigger")
	triggerCell(ent, index, value)
end

--- Gets the value of an entity's input
-- @param Entity ent Entity with input
-- @param string inputname Input name
-- @return any value The value to set the input to (must match the input type)
function wire_library.readInput(ent, inputname)
	checkluatype(inputname, TYPE_STRING)
	ent = getent(ent)
	checkpermission(instance, ent, "wire.read")
	return readInput(ent, inputname)
end

--- Gets the value of an entity's output
-- @param Entity ent Entity with output
-- @param string outputname Output name
-- @return any value The value to set the output to (must match the output type)
function wire_library.readOutput(ent, outputname)
	checkluatype(outputname, TYPE_STRING)
	ent = getent(ent)
	checkpermission(instance, ent, "wire.read")
	return readOutput(ent, outputname)
end

--- Gets a value from an entity's wire memory
-- @param Entity ent Entity with wire memory
-- @param number index The cell address
-- @return number The value at the address
function wire_library.readCell(ent, index)
	checkluatype(index, TYPE_NUMBER)
	ent = getent(ent)
	checkpermission(instance, ent, "wire.read")
	return readCell(ent, index)
end

--- Returns an entities wirelink
-- @class function
-- @return Wirelink Wirelink of the entity
ents_methods.getWirelink = wire_library.getWirelink

-- ------------------------- Wirelink ------------------------- --

--- Retrieves an output value or highspeed cell address value
-- @param string|number k Name of output or index of cell
-- @return any Value of the output or cell
wirelink_meta.__index = function(self, k)
	local method = wirelink_methods[k]
	if method then return method end
	checkpermission(instance, nil, "wire.wirelink.read")
	if isstring(k) then
		return readOutput(getwl(self), k)
	elseif isnumber(k) then
		return readCell(getwl(self), k)
	else
		SF.ThrowTypeError("string or number", SF.GetType(k), 3)
	end
end

--- Writes to an input or highspeed cell address
-- @param string|number k Name of input or index of cell
-- @param any v Value to set input or cell
wirelink_meta.__newindex = function(self, k, v)
	checkpermission(instance, nil, "wire.wirelink.write")
	if isstring(k) then
		triggerInput(getwl(self), k, v)
	elseif isnumber(k) then
		checkluatype(v, TYPE_NUMBER)
		triggerCell(getwl(self), k, v)
	else
		SF.ThrowTypeError("string or number", SF.GetType(k), 3)
	end
end

--- Checks if a wirelink is valid. (ie. doesn't point to an invalid entity)
-- @return boolean Whether the wirelink is valid
function wirelink_methods:isValid()
	return Ent_IsValid(wlunwrap(self))
end

--- Returns current state of the specified input
-- @param string name Input name
-- @return any Input value
function wirelink_methods:inputValue(name)
	checkluatype(name, TYPE_STRING)
	return readInput(getwl(self), name)
end

--- Returns the type of input name, or nil if it doesn't exist
-- @param string name Input name to search for
-- @return string Type of input
function wirelink_methods:inputType(name)
	checkluatype(name, TYPE_STRING)
	local wl = getwl(self)
	local input = wl.Inputs[name]
	if input then
		return tostring(input.Type)
	end
end

--- Returns the type of output name, or nil if it doesn't exist
-- @param string name Output name to search for
-- @return string Type of output
function wirelink_methods:outputType(name)
	checkluatype(name, TYPE_STRING)
	local wl = getwl(self)
	local output = wl.Outputs[name]
	if output then
		return tostring(output.Type)
	end
end

--- Returns the entity that the wirelink represents
-- @return Entity Entity the wirelink represents
function wirelink_methods:entity()
	return owrap(getwl(self))
end

--- Returns a table of all of the wirelink's inputs
-- @return table All of the wirelink's inputs
function wirelink_methods:inputs()
	local wl = getwl(self)
	local Inputs = wl.Inputs
	if not Inputs then return {} end

	local inputNames = {}
	for name, port in pairs(Inputs) do
		if isstring(name) then inputNames[#inputNames + 1] = name end
	end

	local function portsSorter(a, b)
		return Inputs[a].Num < Inputs[b].Num
	end
	table.sort(inputNames, portsSorter)

	return inputNames
end

--- Returns a table of all of the wirelink's outputs
-- @return table All of the wirelink's outputs
function wirelink_methods:outputs()
	local wl = getwl(self)
	local Outputs = wl.Outputs
	if not Outputs then return {} end

	local outputNames = {}
	for name, port in pairs(Outputs) do
		if isstring(name) then outputNames[#outputNames + 1] = name end
	end

	local function portsSorter(a, b)
		return Outputs[a].Num < Outputs[b].Num
	end
	table.sort(outputNames, portsSorter)

	return outputNames
end

--- Checks if an input is wired.
-- @param string name Name of the input to check
-- @return boolean Whether it is wired
function wirelink_methods:isWired(name)
	checkluatype(name, TYPE_STRING)
	local wl = getwl(self)
	local input = wl.Inputs[name]
	if input and Ent_IsValid(input.Src) then return true else return false end
end

--- Returns what an input of the wirelink is wired to.
-- @param string name Name of the input
-- @return Entity The entity the wirelink is wired to
function wirelink_methods:getWiredTo(name)
	checkluatype(name, TYPE_STRING)
	local wl = getwl(self)
	local input = wl.Inputs[name]
	if input and Ent_IsValid(input.Src) then
		return owrap(input.Src)
	end
end

--- Returns the name of the output an input of the wirelink is wired to.
-- @param string name Name of the input of the wirelink.
-- @return string String name of the output that the input is wired to.
function wirelink_methods:getWiredToName(name)
	checkluatype(name, TYPE_STRING)
	local wl = getwl(self)
	local input = wl.Inputs[name]
	if input and Ent_IsValid(input.Src) then
		return tostring(input.SrcId)
	end
end

--- Ports table. Reads from this table will read from the wire input
-- of the same name. Writes will write to the wire output of the same name.
-- @class table
-- @name wire_library.ports
wire_library.ports = setmetatable({}, {
	__index = function(self, k)
		checkluatype(k, TYPE_STRING)
		return readInput(instance.entity, k)
	end,
	__newindex = function(self, k, v)
		checkluatype(k, TYPE_STRING)
		triggerOutput(instance.entity, k, v)
	end
})

-- ------------------------- Hook Documentation ------------------------- --

--- Called when an input on a wired SF chip is written to
-- @name Input
-- @class hook
-- @param string input The input name
-- @param any value The value of the input

--- Called when a high speed device reads from a wired SF chip
-- @name ReadCell
-- @class hook
-- @server
-- @param any address The address requested
-- @return any The value read

--- Called when a high speed device writes to a wired SF chip
-- @name WriteCell
-- @class hook
-- @param any address The address written to
-- @param table data The data being written

end
