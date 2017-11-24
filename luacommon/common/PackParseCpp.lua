require "common/class"


-- 封包类型定义
local PackFieldType = {
		UnKnowType = -1,
		UByteType = 0,
		UInt16Type = 1,
		Int32Type = 2,
		StringType = 3,
		NetDataType = 4,
		PackType = 5,
		Int16Type = 6,
		FloatType = 7,
		DoubleType = 8,
		Int64Type = 9,
}
-- 类型映射
local FieldTypeMapping = {
	string = PackFieldType.StringType,
	ubyte = PackFieldType.UByteType,
	int16 = PackFieldType.UInt16Type,
	ushort = PackFieldType.UInt16Type,
	short = PackFieldType.Int16Type,
	int32 = PackFieldType.Int32Type,
	int64 = PackFieldType.Int64Type,
	float = PackFieldType.FloatType,
	double = PackFieldType.DoubleType,
	NetData = PackFieldType.NetDataType,
	PackType = PackFieldType.PackType,
}
-- 获取读取函数映射
local FieldTypeReadFuncMapping = {
	string = "GetStringFieldValue",
	ubyte = "GetIntFieldValue",
	int16 = "GetIntFieldValue",
	ushort = "GetIntFieldValue",
	short = "GetIntFieldValue",
	int32 = "GetIntFieldValue",
	int64 = "GetLongFieldValue",
	float = "GetFloatFieldValue",
	double = "GetDoubleFieldValue",
	NetData = "GetNetDataFieldValue",
	PackType = "GetPackFieldValue",
}
local FieldTypeReadListFuncMapping = {
	string = "GetStringFieldValue",
	ubyte = "GetIntFieldValueList",
	int16 = "GetIntFieldValueList",
	ushort = "GetIntFieldValueList",
	short = "GetIntFieldValueList",
	int32 = "GetIntFieldValueList",
	int64 = "GetLongFieldValueList",
	float = "GetFloatFieldValueList",
	double = "GetDoubleFieldValueList",
	NetData = "GetNetDataFieldValue",
	PackType = "GetPackFieldValueList",
}
-- 获取cpp类型
function GetFieldType( sFieldType )
	if FieldTypeMapping[sFieldType] then
		return FieldTypeMapping[sFieldType]
	end
	return FieldTypeMapping.PackType
end
-- 获取cpp读取函数
function GetFieldTypeReadFunc( sFieldType, bArray )
	local dFuncMapping = nil
	if bArray then
		dFuncMapping = FieldTypeReadListFuncMapping
	else
		dFuncMapping = FieldTypeReadFuncMapping
	end

	if dFuncMapping[sFieldType] then
		return dFuncMapping[sFieldType]
	end
	return dFuncMapping.PackType
end

-- 初始化封包模块
sc.PackParser:InitParseMode(_G.IsServer64)


-- 封包读取元表映射
g_dPackHeadMetatableMapping = {}
g_dPackTypeMetatableMapping = {}
-- 嵌套封包头映射
g_dSubPackHeadMapping = {}

-- 注册cpp封包
lua_setPackInfo = setPackInfo
setPackInfo = function (packHead, packClass)
	if not lua_setPackInfo(packHead, packClass) then
		return false
	end

	-- 创建一个封包对象用来注册cpp
	local pPackObj = packClass.new()
	local bDymicPack = not not pPackObj._dynamic_
	if not sc.PackParser:StartPackDefine(packHead, bDymicPack) then
		com.error("StartPackDefine(0x%04X, %s) error", packHead, bDymicPack)
		return false
	end

	-- 封包字段索引映射
	local dFieldMapping = {}
	local iFieldIndex = 0
	-- 嵌套子包映射
	local dSubPackHeadInfo = {}
	-- 封包字段列表
	for _, lFieldInfo in ipairs(pPackObj._field_) do
		local sFieldName, sFieldType, pCount = unpack(lFieldInfo)
		local iFieldType = GetFieldType(sFieldType)
		-- 固定长度
		local bArray = pCount and pCount ~= 0
		if not bArray then
			if not sc.PackParser:AddPackFieldDefine(packHead, sFieldName, iFieldType) then
				com.error("AddPackFieldDefine(0x%04X, %s) error", packHead, iFieldType)
				return false
			end
		else
			-- 数组字段
			if isVailNumber(pCount) then
				if not sc.PackParser:AddPackFieldDefine(packHead, sFieldName, iFieldType, pCount) then
					com.error("AddPackFieldDefine(0x%04X, %s, %s) error", packHead, iFieldType, pCount)
					return false
				end
			else
				if not sc.PackParser:AddPackFieldDefineDymic(packHead, sFieldName, iFieldType, pCount) then
					com.error("AddPackFieldDefineDymic(0x%04X, %s, %s) error", packHead, iFieldType, pCount)
					return false
				end
			end
		end
		-- 封包字段索引映射
		iFieldIndex = iFieldIndex + 1
		dFieldMapping[sFieldName] = iFieldIndex
		-- 嵌套子包映射
		if iFieldType == PackFieldType.PackType then
			dSubPackHeadInfo[iFieldIndex] = {
				PackType = sFieldType,
				bArray = bArray,
			}
		end
	end

	if not sc.PackParser:StopPackDefine(packHead) then
		com.error("StopPackDefine(0x%04X) error", packHead)
		return false
	end

	if table.isEmpty(dSubPackHeadInfo) then
		dSubPackHeadInfo = nil
	end

	-- 记录索引映射元表
	local dMetatableDict = {
		_field_ = pPackObj._field_,
		__str__ = GetPackInfo,
		__index = function( dTable, sKey )
			-- com.info("dTable[%s], sKey[%s]", dTable, sKey)
			-- 从字段方式获取转成索引方式获取
			local iFieldIndex = dFieldMapping[sKey]
			if not iFieldIndex then
				-- com.error("packHead[0x%04X], sKey[%s] iFieldIndex[%s]", packHead, sKey, iFieldIndex)
				rawset(dTable, sKey, nil)
				return nil
			end
			local pValue = rawget(dTable, iFieldIndex)
			if not pValue then
				com.error("packHead[0x%04X], sKey[%s] iFieldIndex[%s] = %s", packHead, sKey, iFieldIndex, pValue)
				com.error("dFieldMapping = %s", dFieldMapping)
				rawset(dTable, sKey, pValue)
				return nil
			end
			-- com.info("packHead[0x%04X], sKey[%s] iFieldIndex[%s] = %s", packHead, sKey, iFieldIndex, pValue)
			-- 非封包类型
			if not dSubPackHeadInfo or not dSubPackHeadInfo[iFieldIndex] then
				-- 生成缓存
				rawset(dTable, sKey, pValue)
				-- dTable[sKey] = pValue
				return pValue
			end

			-- 封包类型先尝试转换
			local dPackInfo = dSubPackHeadInfo[iFieldIndex]
			-- 尝试获取嵌套包类型对象
			local pPackType = _G[dPackInfo.PackType]
			local dSubMetatableDict = g_dPackTypeMetatableMapping[pPackType]

			-- 数组形式需要转换内部元素
			local pTranValue = nil
			if dPackInfo.bArray then
				pTranValue = {}

				local iCount = #pValue
				for iValueIndex = 1, iCount do
					local pSubPack = pValue[iValueIndex]
					setmetatable(pSubPack, dSubMetatableDict)
					table.insert(pTranValue, pSubPack)
				end
			else
				pTranValue = pValue
				setmetatable(pTranValue, dSubMetatableDict)
			end

			-- 生成缓存
			-- dTable[sKey] = pTranValue
			rawset(dTable, sKey, pTranValue)
			return pTranValue
		end
	}
	g_dPackHeadMetatableMapping[packHead] = dMetatableDict
	g_dPackTypeMetatableMapping[packClass] = dMetatableDict

	return true
end

-- 取消封包定义注册
lua_unsetPackInfo = unsetPackInfo
unsetPackInfo = function ( packHead )
	lua_unsetPackInfo(packHead)
	
	if not sc.PackParser:ClearPackDefine(packHead) then
		com.error("StopPackDefine(0x%04X) error", packHead)
		return false
	end
end

-- 解析封包
lua_getPackObj = getPackObj
function getPackObj(packHead, recvData, nPos, bNeedCppPackObj)
	local cType = g_packDict[packHead]
	-- com.info("getPackObj(0x%04X) start in nPos(%s)", packHead, nPos)

	if not cType then
		if isNumber(packHead) then
			com.warn("packHead(0x%04X) no found", packHead)
		else
			com.error("packHead(%s) no found", packHead)
		end
		return nil, nPos
	end

	-- 解析封包
	-- local tick = os.mTimer()
	local pCppPackObj = sc.PackParser:Parse(packHead, recvData, nPos)
	if not pCppPackObj then
		com.error("PackParser.Parse(0x%04X) error in nPos(%s)", packHead, nPos)
		return nil, nPos
	end
	-- com.info("getPackObj[0x%04X, %s] Parse tick = %s", packHead, pCppPackObj:GetPackBufferLength(), os.mTimer() - tick)

	-- 字节长度
	local iBuffLen = pCppPackObj:GetPackBufferLength()
	-- 只需要cpp封包对象(接收方要自己维护对象清理)
	if bNeedCppPackObj then
		return pCppPackObj, nPos + iBuffLen
	end

	-- local tick = os.mTimer()
	-- local pTest = lua_getPackObj(packHead, recvData, nPos)
	-- com.info("getPackObj[0x%04X, %s] old Parse tick = %s", packHead, pCppPackObj:GetPackBufferLength(), os.mTimer() - tick)

	-- local tick = os.mTimer()
	-- -- 转换cpp封包到lua封包
	-- local pLuaPackObj = cType.new()
	-- if not ConvertPackObjectToLuaEx(pCppPackObj, pLuaPackObj) then
	-- 	com.error("getPackObj(0x%04X) ConvertPackObjectToLuaEx error", packHead)
	-- 	return nil, nPos
	-- end
	-- com.info("getPackObj[0x%04X, %s] Convert tick = %s", packHead, pCppPackObj:GetPackBufferLength(), os.mTimer() - tick)

	-- local tick = os.mTimer()
	-- 转换cpp封包到lua封包
	local pLuaPackObj = ConvertPackObjectToLuaDictEx(pCppPackObj, packHead)
	if not pLuaPackObj then
		com.error("getPackObj(0x%04X) ConvertPackObjectToLuaDictEx error", packHead)
		return nil, nPos
	end
	-- com.info("getPackObj[0x%04X, %s] Convert2 tick = %s", packHead, pCppPackObj:GetPackBufferLength(), os.mTimer() - tick)


	-- 清理封包对象
	sc.PackParser:ClearPackObject(pCppPackObj)

	return pLuaPackObj, nPos + iBuffLen
end

-- 转换cpp封包到lua
function ConvertPackObjectToLuaEx( pCppPackObj, pLuaPackObj )
	local dPackDict = pCppPackObj:GetLuaPackObject()
	if not dPackDict then
		com.error("ConvertPackObjectToLuaEx(0x%04X) GetLuaPackObject(false) = %s", pCppPackObj:GetPackHead(), dPackDict)
		return false
	end
	table.update(pLuaPackObj, dPackDict)
	return true
end

function ConvertPackObjectToLuaDictEx( pCppPackObj, packHead )
	local lPackInfo = pCppPackObj:GetLuaPackObject(true)
	if not lPackInfo then
		com.error("ConvertPackObjectToLuaDictEx(0x%04X) GetLuaPackObject(true) = %s", pCppPackObj:GetPackHead(), lPackInfo)
		return nil
	end
	-- com.info("lPackInfo", lPackInfo)
	local dMetatableDict = g_dPackHeadMetatableMapping[packHead]
	setmetatable(lPackInfo, dMetatableDict)
	return lPackInfo
end


-- 转换cpp封包到lua封包
function ConvertPackObjectToLua( pCppPackObj, pLuaPackObj )
	-- 创建lua封包对象
	for _, lFieldInfo in ipairs(pLuaPackObj._field_) do
		local sFieldName, sFieldType, pCount = unpack(lFieldInfo)

		-- 是否列表
		local bArray = not not pCount and pCount ~= 0

		-- 获取不到读取函数
		local sReadFuncName = GetFieldTypeReadFunc(sFieldType, bArray)
		if not pCppPackObj[sReadFuncName] then
			com.error("ConvertPackObjectToLua(0x%04X, %s) no found read func %s", pCppPackObj:GetPackHead(), sFieldName, sReadFuncName)
			return false
		end
		-- 读取字段值
		local pValue = pCppPackObj[sReadFuncName](pCppPackObj, sFieldName)
		-- com.info("%s.pValue = %s", sFieldName, pValue)

		-- 如果是嵌套包，需要做转换
		local iFieldType = GetFieldType(sFieldType)
		if iFieldType == PackFieldType.PackType then
			-- 尝试获取嵌套包类型对象
			local pPackType = _G[sFieldType]
			if not pPackType then
				com.error("ConvertPackObjectToLua(0x%04X, %s) no found field class %s", pCppPackObj:GetPackHead(), sFieldName, sFieldType)
				return false
			end
			if bArray then
				-- 转换子包列表
				local lSubPackList = {}
				for iIndex, pSubCppPack in ipairs(pValue) do
					local pSubLuaPackObj = pPackType.new()
					if not ConvertPackObjectToLua(pSubCppPack, pSubLuaPackObj) then
						com.error("getPackObj(%s) ConvertPackObjectToLua sub[%s] pack [%s] error", pLuaPackObj, iIndex, pSubLuaPackObj)
						return false
					end
					table.insert(lSubPackList, pSubLuaPackObj)
					pValue = lSubPackList
				end
			else
				local pSubLuaPackObj = pPackType.new()
				if not ConvertPackObjectToLua(pValue, pSubLuaPackObj) then
					com.error("getPackObj(%s) ConvertPackObjectToLua sub pack [%s] error", pLuaPackObj, pSubLuaPackObj)
					return false
				end
				pValue = pSubLuaPackObj
			end
		end
		pLuaPackObj[sFieldName] = pValue
	end

	-- com.info("pLuaPackObj = %s", pLuaPackObj)
	return true
end

-- RegisterTimerCall(function ( ... )

-- 	local dStatTickInfo = InitStatInfo("getPackObj.Tick")
-- 	local dStatLenInfo = InitStatInfo("getPackObj.Len")
-- 	RegisterTimer(function ( ... )
-- 		com.info(GetStatFuncInfo("getPackObj.Tick"))
-- 		com.info(GetStatFuncInfo("getPackObj.Len"))
-- 		com.info(GetStatFuncInfo("Parse"))
-- 		com.info(GetStatFuncInfo("ClearPackObject"))
-- 		com.info(GetStatFuncInfo("GetLuaPackObject"))
-- 		-- com.info(GetStatFuncInfo("ConvertPackObjectToLua"))
-- 		-- com.info(GetStatFuncInfo("ConvertPackObjectToLuaEx"))
-- 	end, 10)

-- 	BindObjectStatFunc(sc.PackParser, "Parse")
-- 	BindObjectStatFunc(sc.PackParser, "ClearPackObject")
-- 	BindObjectStatFunc(sc.PackObject, "GetLuaPackObject")
-- 	-- _G.ConvertPackObjectToLua = BindStatFunc("ConvertPackObjectToLua", ConvertPackObjectToLua)
-- 	-- _G.ConvertPackObjectToLuaEx = BindStatFunc("ConvertPackObjectToLuaEx", ConvertPackObjectToLuaEx)

-- 	_getPackObj = getPackObj
-- 	getPackObj = function ( packHead, recvData, nPos )
-- 		local tick = os.mTimer()
-- 	    local pLuaPackObj, iNewPos = _getPackObj(packHead, recvData, nPos)
-- 	    local interval = os.mTimer() - tick
-- 	    local bufflen = iNewPos - nPos
-- 	    if bufflen > 0 or pLuaPackObj then
-- 	    	-- com.info("getPackObj[0x%04X, %s] tick = %s", packHead, bufflen, interval)
-- 	    	AddStatFunc(dStatTickInfo, interval)
-- 	    	AddStatFunc(dStatLenInfo, bufflen)
-- 	    	-- com.info("pLuaPackObj", pLuaPackObj)
-- 	    else
-- 	    	com.error("getPackObj[0x%04X] error tick = %s", packHead, interval)
-- 	    end
-- 	    return pLuaPackObj, iNewPos
-- 	end

-- end, 5)