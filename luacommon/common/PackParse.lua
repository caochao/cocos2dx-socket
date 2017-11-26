require "common/class"


-- 是否64位服务端
IsServer64 = GetDefineVariable(config, "IsServer64") or false

-- 是否调试封包解析
IsDebugPackParse = false


g_packDict = {}
function setPackInfo(packHead, packClass)
	if g_packDict[packHead] then
		com.error("封包(0x%04X) 重复注册", packHead)
		return false
	end
	g_packDict[packHead] = packClass

    rawset(packClass, "_head_", packHead)
	return true
end
-- 取消封包定义注册
function unsetPackInfo( packHead )
	if not g_packDict[packHead] then
		return
	end
	g_packDict[packHead] = nil
end
function getPackObj(packHead,recvData, nPos)
	local cType = g_packDict[packHead]
	com.debug("getPackObj(0x%04X) start in nPos(%s)", packHead, nPos)
	if not cType then
		if isNumber(packHead) then
			com.warn("packHead(0x%04X) no found", packHead)
		else
			com.error("packHead(%s) no found", packHead)
		end
		return nil, nPos
	end
	local obj = cType.new()
	return obj:GetPack(recvData, nPos)
end


function ReadUBYTE( pRecvData, iCurPos )
	local bRet, pValue, iNewPos = __checkReadDataByPos(pRecvData, "ReadUBYTE", iCurPos, 1 )
	if bRet then
		return pValue, iNewPos
	end
	return nil, iCurPos
end
function ReadUINT16( pRecvData, iCurPos )
	local bRet, pValue, iNewPos = __checkReadDataByPos(pRecvData, "ReadUINT16", iCurPos, 2 )
	if bRet then
		return pValue, iNewPos
	end
	return nil, iCurPos
end

function ReadINT16( pRecvData, iCurPos )
	local bRet, pValue, iNewPos = __checkReadDataByPos(pRecvData, "ReadINT16", iCurPos, 2 )
	if bRet then
		return pValue, iNewPos
	end
	return nil, iCurPos
end

function ReadINT32( pRecvData, iCurPos )
	local bRet, pValue, iNewPos = __checkReadDataByPos(pRecvData, "ReadINT32", iCurPos, 4 )
	if bRet then
		return pValue, iNewPos
	end
	return nil, iCurPos
end

function ReadINT64( pRecvData, iCurPos )
	local bRet, pValue, iNewPos = __checkReadDataByPos(pRecvData, "ReadINT64", iCurPos, 8 )
	if bRet then
		return pValue, iNewPos
	end
	return nil, iCurPos
end

function ReadFloat( pRecvData, iCurPos )
	local bRet, pValue, iNewPos = __checkReadDataByPos(pRecvData, "ReadFloat", iCurPos, 4 )
	if bRet then
		return pValue, iNewPos
	end
	return nil, iCurPos
end

function ReadDouble( pRecvData, iCurPos )
	local bRet, pValue, iNewPos = __checkReadDataByPos(pRecvData, "ReadDouble", iCurPos, 8 )
	if bRet then
		return pValue, iNewPos
	end
	return nil, iCurPos
end

function ReadString( pRecvData, iCurPos, iReadLength )
	local bRet, pValue, iNewPos = __checkReadDataByPos(pRecvData, "ReadString", iCurPos, iReadLength, true )
	if bRet then
		return pValue, iNewPos
	end
	return nil, iCurPos
end

-- 检测读取数据
function __checkReadDataByPos( pRecvData, sReadType, iCurPos, iReadLength, bReadString)
	local iAllLen = pRecvData:GetLength()
	if iCurPos >= iAllLen then
		com.error("%s error, iAllLen(%s) <= iCurPos(%s)", sReadType, iAllLen, iCurPos)
		return false
	end

	local iNewPos = iCurPos + iReadLength
	if iNewPos > iAllLen then
		com.error("%s error, iAllLen(%s) < iNewPos(%s)", sReadType, iAllLen, iNewPos)
		return false
	end

	local fReadDataFunc = pRecvData[sReadType]
	if not fReadDataFunc then
		com.error("%s error, fReadDataFunc no found", sReadType)
		return false
	end
	local pValue
	if bReadString then
		pValue = fReadDataFunc(pRecvData, iReadLength, iCurPos)
	else
		pValue = fReadDataFunc(pRecvData, iCurPos)
	end

	return true, pValue, iNewPos
end


function ReadNetData( pRecvData, iCurPos, iReadLength )
	local sReadType = "ReadNetData"
	local iAllLen = pRecvData:GetLength()
	if iCurPos >= iAllLen then
		com.error("%s error, iAllLen(%s) <= iCurPos(%s)", sReadType, iAllLen, iCurPos)
		return nil, iCurPos
	end

	local iNewPos = iCurPos + iReadLength
	if iNewPos > iAllLen then
		com.error("%s error, iAllLen(%s) < iNewPos(%s)", sReadType, iAllLen, iNewPos)
		return nil, iCurPos
	end

	local pValue = sc.CNetData:new()
	pValue:SetNoDelByClear()
	pValue:AddObj(pRecvData, iCurPos, iReadLength)

	return pValue, iNewPos
	-- body
end


--封包信息
function GetPackInfo(pack)
	local sign = pack:GetPackSign()
	local info = string.format("{(Head=0x%04X)[Sign:%s]", pack._head_, sign)
    if pack._field_ then
		local tab = {}
		local name, value
        for _, prop in pairs(pack._field_) do
            name = prop[1]
            value = pack[name]
			tab[name] = value
		end
		info = info .. ":" .. string.getStr(tab) .. "}"
	end
    return info
end

function SetStaticBuffer(pack, pNetPackData)
	pNetPackData:AddUINT16(pack._head_)
	for i, prop in pairs(pack._field_) do
		local propName, propType, propCount = unpack(prop)
		if propType == "string" then
			if propCount and type(propCount) == "number" then
				pNetPackData:AddString(pack[propName] or "", propCount)
			elseif propCount == pack._field_[i-1][1] then
				pNetPackData:AddINT32(0)
				if IsServer64 then
					pNetPackData:AddINT32(0)
				end
			else
				com.error("propCount(%s) error", propCount)
			end
		elseif propType == "NetData" then
			if propCount and type(propCount) == "number" then
				pNetPackData:AddObj(pack[propName] or "", 0, propCount)
			elseif propCount == pack._field_[i-1][1] then
				pNetPackData:AddINT32(0)
				if IsServer64 then
					pNetPackData:AddINT32(0)
				end
			else
				com.error("propCount(%s) error", propCount)
			end
		elseif propType == "ubyte" then
			local field, fieldType, num = unpack(prop)
			local value = pack[field]
			if num and type(num) ~= "number" and pack._fieldType[num] then
				-- 指针占位
				-- com.debug("指针占位 = %s", 0)
				pNetPackData:AddINT32(0)
				if IsServer64 then
					pNetPackData:AddINT32(0)
				end
			elseif num and num > 0 then
				for index = 1, num do
					pNetPackData:AddUBYTE(value[index])
				end
			else
				pNetPackData:AddUBYTE(value)
			end
		elseif propType == "int16" or propType == "ushort" then
			local field, fieldType, num = unpack(prop)
			local value = pack[field]
			if num and type(num) ~= "number" and pack._fieldType[num] then
				-- 指针占位
				-- com.debug("指针占位 = %s", 0)
				pNetPackData:AddINT32(0)
				if IsServer64 then
					pNetPackData:AddINT32(0)
				end
			elseif num and num > 0 then
				for index = 1, num do
					pNetPackData:AddUINT16(value[index])
				end
			else
				pNetPackData:AddUINT16(value)
			end
		elseif propType == "short" then
			local field, fieldType, num = unpack(prop)
			local value = pack[field]
			if num and type(num) ~= "number" and pack._fieldType[num] then
				-- 指针占位
				-- com.debug("指针占位 = %s", 0)
				pNetPackData:AddINT32(0)
				if IsServer64 then
					pNetPackData:AddINT32(0)
				end
			elseif num and num > 0 then
				for index = 1, num do
					pNetPackData:AddINT16(value[index])
				end
			else
				pNetPackData:AddINT16(value)
			end
		elseif propType == "int32" then
			local field, fieldType, num = unpack(prop)
			local value = pack[field]
			-- com.debug("field = %s", field)
			-- com.debug("fieldType = %s", fieldType)
			-- com.debug("num = %s", num)
			-- com.debug("value = %s", value)
			-- com.debug("pack._fieldType[num] = %s", pack._fieldType[num])
			if num and type(num) ~= "number" and pack._fieldType[num] then
				-- 指针占位
				-- com.debug("指针占位 = %s", 0)
				pNetPackData:AddINT32(0)
				if IsServer64 then
					pNetPackData:AddINT32(0)
				end
			elseif num and num > 0 then
				-- com.debug("for = %s", num)
				for index = 1, num do
					pNetPackData:AddINT32(value[index])
				end
			else
				-- com.debug("AddINT32 = %s", value)
				pNetPackData:AddINT32(value)
			end
		elseif propType == "int64" then
			local field, fieldType, num = unpack(prop)
			local value = pack[field]

			if num and type(num) ~= "number" and pack._fieldType[num] then
				-- 指针占位
				pNetPackData:AddINT32(0)
				if IsServer64 then
					pNetPackData:AddINT32(0)
				end
			elseif num and num > 0 then
				for index = 1, num do
					pNetPackData:AddINT64(value[index])
				end
			else
				pNetPackData:AddINT64(value)
			end

		elseif propType == "float" then
			local field, fieldType, num = unpack(prop)
			local value = pack[field]

			if num and type(num) ~= "number" and pack._fieldType[num] then
				-- 指针占位
				pNetPackData:AddINT32(0)
				if IsServer64 then
					pNetPackData:AddINT32(0)
				end
			elseif num and num > 0 then
				for index = 1, num do
					pNetPackData:AddFloat(value[index])
				end
			else
				pNetPackData:AddFloat(value)
			end
		elseif propType == "double" then
			local field, fieldType, num = unpack(prop)
			local value = pack[field]

			if num and type(num) ~= "number" and pack._fieldType[num] then
				-- 指针占位
				pNetPackData:AddINT32(0)
				if IsServer64 then
					pNetPackData:AddINT32(0)
				end
			elseif num and num > 0 then
				for index = 1, num do
					pNetPackData:AddDouble(value[index])
				end
			else
				pNetPackData:AddDouble(value)
			end

		elseif propType then
			if propCount and type(propCount) == "number" then
				if #pack[propName] ~= propCount then
					error(propName .. " length error")
				end
				local objList
				if propCount == 0 then
					objList = {pack[propName]}
				else 
					objList = pack[propName]
				end
				for _, obj in pairs(objList) do
					obj:SetBuffer(pNetPackData)
					-- pNetPackData:AddObj(obj:GetBuffer())
				end
			elseif propCount == pack._field_[i-1][1] then
				pNetPackData:AddINT32(0)
				if IsServer64 then
					pNetPackData:AddINT32(0)
				end
			else
				com.error("propCount(%s) error", propCount)
			end
		end
	end
end

function SetDynamicBuffer(pack, pNetPackData)
	SetStaticBuffer(pack, pNetPackData)
	-- com.debug("SetDynamicBuffer = %s", pack)
	if pack._dynamic_ ~= nil then
		for _, prop in pairs(pack._dynamic_) do
			local field, countField = unpack(prop)
			local num = pack[countField]
			local fieldType = pack._fieldType[field]
			-- com.debug("field = %s", field)
			-- com.debug("countField = %s", countField)
			-- com.debug("num = %s", num)
			-- com.debug("fieldType = %s", fieldType)
			if fieldType == "int32" then
				-- com.debug("for = %s", num)
				for index = 1, num do
					local obj = pack[field][index]
					pNetPackData:AddINT32(obj)
				end
			elseif fieldType == "ubyte" then
				-- com.debug("for = %s", num)
				for index = 1, num do
					local obj = pack[field][index]
					pNetPackData:AddUBYTE(obj)
				end
			elseif fieldType == "int64" then
				for index = 1, num do
					local obj = pack[field][index]
					pNetPackData:AddINT64(obj)
				end
			elseif fieldType == "float" then
				for index = 1, num do
					local obj = pack[field][index]
					pNetPackData:AddFloat(obj)
				end
			elseif fieldType == "double" then
				for index = 1, num do
					local obj = pack[field][index]
					pNetPackData:AddDouble(obj)
				end
			elseif fieldType == "short" then
				for index = 1, num do
					local obj = pack[field][index]
					pNetPackData:AddINT16(obj)
				end
			-- 如果是字符串 没有判断会出错
			elseif fieldType == "string" then
				pNetPackData:AddString(pack[field] or "", num)

			elseif fieldType == "NetData" then
				pNetPackData:AddObj(pack[field] or "", 0, num)

			else
				for index = 1, num do
					local obj = pack[field][index]
					obj:SetBuffer(pNetPackData)
					-- pNetPackData:AddObj(obj:GetBuffer())
				end
			end
		end
	end
end



--普通封包
BasePack = class()
function BasePack:ctor(...)
	-- self._netData = nil
	self.args = com.getVarArgs(...)
	self._head_ = 0x7890
	self._field_ = {"Head", "int16"}
	self.SetBuffer = SetStaticBuffer

	self._packSign = 0
	self._sendTryCount = 0
end

-- 获取封包标识
function BasePack:GetPackSign( ... )
	return self._packSign
end
-- 设置封包标识
function BasePack:SetPackSign( value )
	self._packSign = value
end
-- 获取封包尝试发送次数
function BasePack:GetSendTryCount( )
	return self._sendTryCount
end
-- 设置封包尝试发送次数
function BasePack:SetSendTryCount( value )
	self._sendTryCount = value
end

-- 获取封包头
function BasePack:GetHead( ... )
	return self._head_
end

function BasePack:InitField()

	self._fieldType = {}
	-- for _, prop in pairs(self._field_) do
	-- 	local field, fieldType = unpack(prop)
	-- 	self._fieldType[field] = fieldType
	-- end

	for i,prop in pairs(self._field_) do
		local field, fieldType, propCount = unpack(prop)
		local defaultValue = self.args[i]
		if not defaultValue then
			if fieldType == "string" then
				defaultValue = ""
			elseif fieldType == "ubyte" then
				defaultValue = 0
			elseif fieldType == "int16" then
				defaultValue = 0
			elseif fieldType == "ushort" then
				defaultValue = 0
			elseif fieldType == "short" then
				defaultValue = 0
			elseif fieldType == "int32" then
				defaultValue = 0
			elseif fieldType == "int64" then
				defaultValue = 0
			elseif fieldType == "float" then
				defaultValue = 0
			elseif fieldType == "double" then
				defaultValue = 0
			elseif fieldType == "NetData" then
				defaultValue = nil
			elseif propCount and type(propCount) == "number" then
				defaultValue = {}
			end
		end
		self[field] = defaultValue
		self._fieldType[field] = fieldType
	end
end


function BasePack:__getFieldValue(recvData, nPos, fieldType, num)
	local value, subValue
	if num and type(num) ~= "number" and self._fieldType[num] then
		-- num = self[num]
		-- 获取指针数据
		_, nPos = ReadINT32( recvData, nPos )
		if IsServer64 then
			_, nPos = ReadINT32( recvData, nPos )
		end
		return value, nPos
	end
	-- com.debug("nPos(%s) fieldType = %s, num = %s", nPos, fieldType, num)

	if fieldType == "ubyte" then
		if num and num > 0 then
			value = {}
			for index = 1, num do
				subValue, nPos = ReadUBYTE(recvData, nPos)
				table.insert(value, subValue)
			end
		else
			value, nPos = ReadUBYTE(recvData, nPos)
		end
	elseif fieldType == "int16" or fieldType == "ushort" then
		if num and num > 0 then
			value = {}
			for index = 1, num do
				subValue, nPos = ReadUINT16( recvData, nPos )
				table.insert(value, subValue)
			end
		else
			value, nPos = ReadUINT16( recvData, nPos )
		end
	elseif fieldType == "short" then
		if num and num > 0 then
			value = {}
			for index = 1, num do
				subValue, nPos = ReadINT16( recvData, nPos )
				table.insert(value, subValue)
			end
		else
			value, nPos = ReadINT16( recvData, nPos )
		end
	elseif fieldType == "int32" then
		if num and num > 0 then
			value = {}
			for index = 1, num do
				subValue, nPos = ReadINT32( recvData, nPos )
				table.insert(value, subValue)
			end
		else
			value, nPos = ReadINT32( recvData, nPos )
		end
	elseif fieldType == "int64" then
		if num and num > 0 then
			value = {}
			for index = 1, num do
				subValue, nPos = ReadINT64( recvData, nPos )
				table.insert(value, subValue)
			end
		else
			value, nPos = ReadINT64( recvData, nPos )
		end
	elseif fieldType == "float" then
		if num and num > 0 then
			value = {}
			for index = 1, num do
				subValue, nPos = ReadFloat( recvData, nPos )
				table.insert(value, subValue)
			end
		else
			value, nPos = ReadFloat( recvData, nPos )
		end
	elseif fieldType == "double" then
		if num and num > 0 then
			value = {}
			for index = 1, num do
				subValue, nPos = ReadDouble( recvData, nPos )
				table.insert(value, subValue)
			end
		else
			value, nPos = ReadDouble( recvData, nPos )
		end
	elseif fieldType == "string" then
		if num and num > 0 then
			value, nPos = ReadString( recvData, nPos, num )
		else
			value = ""
			-- com.error("num(%s) nil", num)
		end
	elseif fieldType == "NetData" then
		if num and num > 0 then
			value, nPos = ReadNetData( recvData, nPos, num )
		else
			value = nil
			-- com.error("num(%s) nil", num)
		end
	else
		if num and num > 0 then
			value = {}
			for index = 1, num do
				local packHead
				packHead, nPos = ReadUINT16( recvData, nPos )
				subValue, nPos = getPackObj(packHead, recvData, nPos)
				table.insert(value, subValue)
			end
		else
			local packHead
			packHead, nPos = ReadUINT16( recvData, nPos )
			value, nPos = getPackObj(packHead, recvData, nPos)
		end
	end
	return value, nPos
end

function BasePack:__getStaticPack(recvData, nPos)
	-- com.debug("BasePack.__getStaticPack")
	local value
	for i, prop in pairs(self._field_) do
		local field, fieldType, countField = unpack(prop)
		-- com.info("__getFieldValue", recvData, nPos, fieldType, countField)
		value, nPos = self:__getFieldValue(recvData, nPos, fieldType, countField)
		self[field] = value
		-- com.debug("%s = %s", field, value)

		if IsDebugPackParse then
			com.debug("_field_.field = ", field)
			com.debug("_field_.fieldType = ", fieldType)
			com.debug("_field_.countField = ", countField)
			com.debug("_field_.value = ", value)
		end
	end
	return nPos
end
function BasePack:GetPack(recvData, nPos)
	-- com.debug("BasePack.GetPack")
	nPos = self:__getStaticPack(recvData, nPos)
	return self, nPos
end

function BasePack:GetBuffer()
	-- return self._netData
	return nil
end

function BasePack:GetLength()
	-- return self._netData:GetLength()
	return nil
end
function BasePack:Clear()
	-- return self._netData:Clear()
end
function BasePack:GetPackInfo()
	return GetPackInfo(self)
end
function BasePack:__str__()
	return self:GetPackInfo()
end

function BasePack:ToLuaObject()
    local ret = {}
    for _, args in pairs(self._field_) do
        local key, type = unpack(args)
        local value = self[key]

        if type ~= "int16" and type ~= "ushort" and type ~= "int32" and type ~= "int64" and type ~= "float" and type ~= "double" 
        		and type ~= "ubyte" and type ~= "string" and type ~= "short" then
            if "table" == type(value) then
                for _, innerValue in pairs(value) do
                    innerValue = innerValue:ToLuaObject()
                end
            else
                value = value:ToLuaObject()
            end
        end

        ret[key] = value
    end
    return ret
end


--动态封包
BaseDynamicPack = class(BasePack)
function BaseDynamicPack:ctor(...)
	-- self._netData = nil
	self.args = com.getVarArgs(...)
	self._dynamic_ = nil
	self.SetBuffer = SetDynamicBuffer
end

function BaseDynamicPack:GetPack(recvData, nPos)
	nPos = self:__getStaticPack(recvData, nPos)
	-- com.debug("BaseDynamicPack.GetPack")
	if self._dynamic_ ~= nil then
		for _, prop in pairs(self._dynamic_) do
			local field, countField = unpack(prop)
			local num = self[countField]
			local fieldType = self._fieldType[field]


			local value, subValue
			if fieldType == "string" then
				value, nPos = self:__getFieldValue(recvData, nPos, fieldType, num)
			elseif fieldType == "NetData" then
				value, nPos = self:__getFieldValue(recvData, nPos, fieldType, num)
			else
				value = {}
				for index = 1, num do
					subValue, nPos = self:__getFieldValue(recvData, nPos, fieldType)
					table.insert(value, subValue)
				end
			end
			self[field] = value
			
			if IsDebugPackParse then
				com.debug("_dynamic_.field = ", field)
				com.debug("_dynamic_.countField = ", countField)
				com.debug("_dynamic_.num = ", num)
				com.debug("_dynamic_.fieldType = ", fieldType)
				com.debug("_dynamic_.value = ", value)
			end
		end
	end
	return self, nPos
end

-- 压缩封包 
ZlibCompressContent = class(BaseDynamicPack)
function ZlibCompressContent:ctor()
	self._head_ = 0xFFFD
	self._field_ = {
		-- 封包内容长度 
		{"CompressLength", "int32", 0},
		-- 压缩内容 
		{"CompressContent", "NetData", "CompressLength"},
		-- 是否多包压缩 
		{"IsMultiPack", "ubyte", 0},
	}
	self._dynamic_ = {
		{"CompressContent", "CompressLength"},
	}
	self:InitField()
end
-- 带原始长度的压缩封包 
ZlibCompressContentEx = class(ZlibCompressContent)
function ZlibCompressContentEx:ctor()
	self._head_ = 0xFFFC
	table.expand(self._field_, {
		-- 原始内容长度 
		{"SourceLength", "int32", 0},
	})
	self:InitField()
end

-- 客户端请求压缩通信 
RequestZlibCompressContent = class(BasePack)
function RequestZlibCompressContent:ctor()
	self._head_ = 0xFFF2
	self._field_ = {
	}
	self:InitField()
end
-- 客户端请求带原始长度的压缩通信 
RequestZlibCompressContentEx = class(BasePack)
function RequestZlibCompressContentEx:ctor()
	self._head_ = 0xFFF1
	self._field_ = {
	}
	self:InitField()
end
-- 服务端通知客户端收到压缩封包请求 
NotifyRequestZlibCompressContentSuccess = class(BasePack)
function NotifyRequestZlibCompressContentSuccess:ctor()
	self._head_ = 0xFFF0
	self._field_ = {
	}
	self:InitField()
end




if sc.PackParser then
	require("common/PackParseCpp")
end

setPackInfo(0xFFFD, ZlibCompressContent)
setPackInfo(0xFFFC, ZlibCompressContentEx)
setPackInfo(0xFFF2, RequestZlibCompressContent)
setPackInfo(0xFFF1, RequestZlibCompressContentEx)
setPackInfo(0xFFF0, NotifyRequestZlibCompressContentSuccess)