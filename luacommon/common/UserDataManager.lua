require "common/class"

----------------------------------------------------------
-- 用户数据储存管理器
UserDataManager = class()
----------------------------------------------------------
function UserDataManager:ctor( name, checkKey, bNotBase64 )
	self._isImmediately = true
	self._data = {}

	self._name = name
	self._isError = false
	self._bNotBase64 = bNotBase64

	self._path = string.format("%sUser_%s.data", os.getCachePath(), name)

	self._checkKey = checkKey
	self:Load()
end
-- 设置 flush 模式，是否立刻写入
function UserDataManager:SetFlushMode( isImmediately )
	self._isImmediately = isImmediately
end
function UserDataManager:IsError( ... )
	return self._isError
end
function UserDataManager:__str__( ... )
	return string.format("UserData(%s)", self._name)
end
------------------------------------------------------
-- 加载数据
function UserDataManager:Load(  )
	com.debug("%s.Load = %s", self, self._path)
	-- rw 会直接崩溃
	local fp, e = io.open(self._path, "r")
	if not fp then
		com.warn("文件(%s)打开失败 = %s", self._path, e)
		return false
	end

	local checkNum = fp:read("*l")
	local dataStr = fp:read("*a")
	fp:close()

	local curCheckNum = GetClientUserDataChecknum( dataStr, self._checkKey )
	if curCheckNum ~= checkNum then
		com.warn("文件(%s)校验失败", self._path)
		return false
	else
		com.warn("文件(%s)校验成功", self._path)
	end

	if not self._bNotBase64 then
		dataStr = sc.CCCrypto:decodeBase64(dataStr)
		com.debug("%s.dataStr = %s", self._path, dataStr)
	end

	self._data = eval(dataStr) or {}
	com.debug("%s.dataStr = %s", self._path, self._data)
	return true
end
-- 创建新数据
function UserDataManager:Create( ... )
	self._isError = false
	self._data = {}
end
------------------------------------------------------
-- 写入数据
function UserDataManager:Flush( ... )
	local tick = getMillisecondNow()

	local dataStr = string.getLuaStr(self._data)
	com.debug("%s.Flush getLuaStr = %s", self, getMillisecondNow() - tick)

	if not self._bNotBase64 then
		dataStr = sc.CCCrypto:encodeBase64(dataStr)
	end
	
	local curCheckNum = GetClientUserDataChecknum( dataStr, self._checkKey )

	local fp = io.open(self._path, "w")
	
	fp:seek("set")
	fp:write(curCheckNum .. "\n")
	fp:write(dataStr)

	fp:flush()
	fp:close()
	com.debug("%s.Flush flush = %s", self, getMillisecondNow() - tick)
end

------------------------------------------------------
-- 读取数据
function UserDataManager:GetData( key )
	if not self._data then
		return nil
	end
	return self._data[key]
end
-- 设置数据
function UserDataManager:SetData( key, value )
	self._data[key] = value

	if self._isImmediately then
		self:Flush()
	end
end