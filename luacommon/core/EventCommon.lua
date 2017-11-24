
-----------------------------------------------------------

-----------------------------------------------------------
-- 事件管理器
EventManager = class()
-----------------------------------------------------------
function EventManager:ctor()
	self:Init()
end

function EventManager:Init()
	com.debug("EventCommon.Init")
	self._eventDict = {}
end

-- 取消注册事件(onFunc使用传递RegisterEvent返回的key来反注册)
function EventManager:UnRegisterEvent(eventName, onFunc)
	com.debug("UnRegisterEvent(%s)", eventName)
	if not self._eventDict[eventName] then
		return
	end
	local eventCallList = self._eventDict[eventName]
	-- if not eventCallList[onFunc] then
	-- 	return
	-- end
	-- 事件处理优先级，越低越高
	local priority = 1
	if type(onFunc) == "table" then
		_, priority = unpack(onFunc)
	end
	if not eventCallList[priority] then
		return
	end
	eventCallList[priority][onFunc] = nil
end
function EventManager:UnRegisterEventAll( eventName )
	com.debug("UnRegisterEventAll(%s)", eventName)
	self._eventDict[eventName] = nil
end
-- 注册事件(return 事件key)
function EventManager:RegisterEvent(eventName, onFunc, ...)
	if not onFunc then
		com.error("RegisterEvent(%s), 注册回调函数不存在", eventName)
		return nil
	end
	com.debug("RegisterEvent(%s) = %s", eventName, onFunc)
	if not self._eventDict[eventName] then
		self._eventDict[eventName] = {}
	end
	local eventCallList = self._eventDict[eventName]
	-- 事件处理优先级，越低越高
	local priority = 1
	if type(onFunc) == "table" then
		_, priority = unpack(onFunc)
	end
	if not eventCallList[priority] then
		eventCallList[priority] = {}
	end
	eventCallList[priority][onFunc] = com.getVarArgs(...)
	-- com.debug("eventCallList = %s", eventCallList)

	return onFunc
end

-- 分发事件
function EventManager:OnEvent( eventName, ... )
	if config.IsDebug then
		com.debug("OnEvent( ", eventName, ...)
	end
	if not self._eventDict then
		return
	end
	
	local eventCallList = self._eventDict[eventName]
	if config.IsDebug then
		-- com.debug("OnEvent(%s)", eventCallList)
	end
	if not eventCallList then
		return
	end
	local args = com.getVarArgs(...)
	for priority, curEventCallList in table.pairsByKeys(eventCallList) do
		for callFunc, argList in pairs(curEventCallList) do
			if type(callFunc) == "table" then
				callFunc = unpack(callFunc)
			end
			-- 事件回调，返回true 阻断后续处理
			argList = table.copy(argList)
			table.expand(argList, args)

			local bResult = false
			local function func( ... )
				bResult = callFunc(unpack(argList))
			end
			local bSuccess = xpcall(func, __G__TRACKBACK__)
			if bSuccess then
				if bResult then
					return
				end
			end
		end
	end
end
-----------------------------------------------------------
-- 事件管理器
EventCommon = EventManager.new()