
-- 数据模块
DataManager = class()

function DataManager:ctor()
	self._data = {}
end

function DataManager:__get(dataType)
	if not self._data[dataType] then
		self._data[dataType] = {}
	end
	return self._data[dataType]
end

function DataManager:__getValueByKey(value, curKey, isSetDefaultValue)
	if type(value) ~= "table" then
		return nil
	end
	if curKey == "getn" then
		return table.getn(value)
	end
   	-- com.info("value = %s curKey = %s", value, curKey)
	if not value[curKey] then
		local numKey = tonumber(curKey)
		if value[numKey] ~= nil then
			curKey = numKey
		elseif isSetDefaultValue then
			value[curKey] = {}
		else
			return nil
		end
		
	end
	return value[curKey]
end
function DataManager:__getData(dataType, key, isSetDefaultValue)
   	-- com.info("dataType = %s, key = %s, isSetDefaultValue = %s", dataType, key, isSetDefaultValue)
	local data = self:__get(dataType)
	local keyList = string.split(key, ".")
   	-- com.info("data = %s, keyList = %s", data, keyList)
	local value = data
	for index, curKey in ipairs(keyList) do
   		-- com.info("index = %s curKey = %s", index, curKey)
		value = self:__getValueByKey(value, curKey, isSetDefaultValue)
   		-- com.info("value = %s", value)
	end
	return value
end

function DataManager:__getByKey(data, key)
	local keyList = string.split(key, ".")
	local value = data
	local keyCount = table.getn(keyList)
	local endKey = nil
	for index, curKey in ipairs(keyList) do
		if index == keyCount then
			endKey = curKey
		else
			value = self:__getValueByKey(value, curKey, true)
		end
	end
	if not value[endKey] then
		local numKey = tonumber(endKey)
		if value[numKey] ~= nil then
			endKey = numKey
		end
	end
	return value, endKey
end
function DataManager:__setData(dataType, key, newValue)
	local data = self:__get(dataType)
	local value, endKey = self:__getByKey(data, key)
	if type(value) == "table" then
		value[endKey] = newValue
		return true
	else
		return false
	end
end

function DataManager:__insertData(dataType, key, newValue)
	local value = self:__getData(dataType, key, true)
	if type(value) == "table" then
		table.insert(value, newValue)
		return true
	else
		return false
	end
end

function DataManager:getGameData(key)
	return self:__getData("GameData", key)
end
function DataManager:setGameData(key, value)
	return self:__setData("GameData", key, value)
end
function DataManager:addGameData(key, value)
	return self:__insertData("GameData", key, value)
end
function DataManager:getPlayerData(key)
	return self:__getData("PlayerData", key)
end
function DataManager:setPlayerData(key, value)
	return self:__setData("PlayerData", key, value)
end
function DataManager:addPlayerData(key, value)
	return self:__insertData("PlayerData", key, value)
end
function DataManager:getClientData(key)
	return self:__getData("ClientData", key)
end
function DataManager:setClientData(key, value)
	return self:__setData("ClientData", key, value)
end
function DataManager:addClientData(key, value)
	return self:__insertData("ClientData", key, value)
end

-- 数据管理器
DataMgr = DataManager.new()
-- test
---- local lv = DataMgr:getPlayerData("hero.lv")
---- DataMgr:setPlayerData("hero.item.1", {itemid=1, atk=1})
---- local atk = DataMgr:getPlayerData("hero.item.1.atk")
---- DataMgr:addPlayerData("hero.item", {itemid=2, atk=3})
---- local atk = DataMgr:getPlayerData("hero.item.2.atk")