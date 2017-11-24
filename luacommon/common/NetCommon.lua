-- package
module("Net", package.seeall)
require "common/comlib"
require "common/timelib"
require "common/PackParse"
require "common/ClientPack"

local Pack_Head = 0x1234
local Pack_Head_Len = 2
local Pack_Head_Type = "ushort"

-- 自定义封包头
if GetDefineVariable(config, "Custom_Client_Pack_Head") then
	Pack_Head = config.Custom_Client_Pack_Head
end
if GetDefineVariable(config, "Custom_Client_Pack_Head_Type") then
	Pack_Head_Type = config.Custom_Client_Pack_Head_Type
end

if Pack_Head_Type == "ushort" then
	Pack_Head_Len = 2
else
	Pack_Head_Len = 4
end


local Pack_Len_Len = 4
local Pack_Min_Len = Pack_Head_Len + Pack_Len_Len


--客户端心跳包频率
ClientHeartbeatInterval = 60

-- 超时
NetError_WSAETIMEDOUT = 10060

--------------------------------------------------------------------------
-- 是否支持解压缩封包
local g_bCanUnCompressPack = sc.CNetData.UnCompress ~= nil
-- 压缩封包头
local Def_CompressPackHeadMapping = { [0xFFFD] = true, [0xFFFC] = true}
-- 请求压缩封包间隔
local ReRequestPackCompressInterval = 3
-- 最小压缩封包长度
local Def_MinZlibCompressBufferLength = 128
--------------------------------------------------------------------------
-- 是否开启封包解析帧率限制
local g_bEnablePackParseLimitTime = GetDefineVariable(config, "bEnablePackParseFpsLimitTime") or false
-- 单次封包解析时间
local g_lSinglePackParseTickList = GetDefineVariable(config, "SinglePackParseTickList") or {
	{0, 0.01},
	{15, 0.02},
	{20, 0.05},
	{50, 0.1},
	{100, 1},
	{150, 10},
}
local g_iSinglePackParseTickConfigCount = #g_lSinglePackParseTickList
--------------------------------------------------------------------------
-- 获取单次封包解析时间(iPackProcessCount 需要处理封包数)
function GetSinglePackParseTick( iPackProcessCount )
	local iSinglePackParseTick = nil
	for iIndex = 1, g_iSinglePackParseTickConfigCount do
		if g_lSinglePackParseTickList[iIndex][1] > iPackProcessCount then
			break
		end
		iSinglePackParseTick = g_lSinglePackParseTickList[iIndex][2]
	end
	return iSinglePackParseTick
end
--------------------------------------------------------------------------
-- 客户端网络接口
NetClient = class()
--------------------------------------------------------------------------
-- isNotSendHeartbeat 是否不发送心跳包
function NetClient:ctor( netName, isNotSendHeartbeat )
	self._netName = netName

	-- 是否显示发包信息
	self._bShowSendPackInfo = not GetDefineVariable(config, "bCloseSendPackInfo")

	-- 初始化网络对象
	self:__initNetClient()
	-- 初始化封包解析
	self:__initPackParser()
	-- 初始化封包钩子
	self:__initPackHook()
	-- 初始化连接钩子
	self:__initNetHook()

	-- 初始化心跳包
	if not isNotSendHeartbeat then
		self:__initHeartbeatPack()
	end
	
	-- 开启封包解析帧率限制
	if g_bEnablePackParseLimitTime then
		-- 封包处理队列
		self._lPackProcessList = {}
		-- 当前队列处理数
		self._iPackProcessCount = 0
		-- 封包处理队列计时器
		self._pPackProcessTimer = nil
	end
end
-- 清理状态
function NetClient:__str__( ... )
	return string.format("NetClient(%s){%s:%s}[%s]", self._netName, tostring(self._server), tostring(self._port), tostring(self._sHostIp))
end
-------------------------------------------
-- 清理状态
function NetClient:Clear( ... )
	self._isInit = false

    -- 清空封包注册
    self._packCallDict = {}
	-- 封包解析模式，是否需要cpp封包
	self._dNeedCppPack = {}

	self:InitEvent()

	self:StopConnect()
	self._client = nil
end
-- 是否初始化
function NetClient:IsInit( ... )
	return self._isInit
end
-------------------------------------------
-- 初始化网络对象
function NetClient:__initNetClient()
	self._isConnect = false
	-- 地址
	self._server = nil
	self._port = nil
	-- 实际连接地址
	self._sHostIp = nil

	-- 是否在尝试连接
	self._isStartConnect = false
	--是否需要重连
	self._needReConnect = false
	-- 连接和断开回调
	self._onConnectFunc = nil
	self._onErrorFunc = nil

	-- 连接超时计时器
	self._connectTimer = nil
	-- 连接超时重试次数
	self._connectTryCount = 0
	-- 超时重连等待时间
	self._fWaitConnectTick = config.NetConnectTimeOut

	-- 默认开启重连
	self._bEnableReconnect = true

	-- 自定义重连函数
	self._reConnectFunc = nil
	-- 自定义重连函数参数
	self._reConnectArg = nil
	self._isClose = false

	-- socket对象
	self._client = sc.CLuaClient:new()
	com.debug("self._client = ", self._client)
	self._fConnectFunc = self._client.Connect

	-- 是否支持同步socket
	self._bSyncConnect = self._client.SyncConnect ~= nil
	-- self._bSyncConnect = false
	com.debug("self._bSyncConnect = ", self._bSyncConnect)
	
	if self._bSyncConnect then
		self._fConnectFunc = self._client.SyncConnect
	end

	-- 开始网络通信轮询

	self:__startNetTick()
end
------------------------------------------------------
-- 设置连接超时
function NetClient:__initConnectTimeout( ... )
	if not self._client.SetSendTimeout then
		return
	end
	local iConnectTimeoutTick = config.NetConnectTimeOut * 1000
	self._client:SetSendTimeout(iConnectTimeoutTick)
	-- self._client:SetRecvTimeout(iConnectTimeoutTick)
end
-- 设置发包超时
function NetClient:__initSendTimeout( ... )
	if not self._client.SetSendTimeout then
		return
	end
	local iSendTimeoutTick = config.NetConnectTimeOut * 1000
	self._client:SetSendTimeout(iSendTimeoutTick)
	-- self._client:SetRecvTimeout(iSendTimeoutTick)
end

------------------------------------------------------
-- 网络通信轮询
function NetClient:__netTick()
	if not self._isStartConnect then
		return 
	end
	if self._isClose then
		com.info("%s.__netTick _isClose", self)
		self:__stopNetTick()
		self:__onError(NetError_WSAETIMEDOUT)
		return
	end
	if self._bSyncConnect then
		return
	end

    if not self._client:Process()then
        -- com.error( 'process error!' ) 
    end
end
-- 开始网络通信轮询
function NetClient:__startNetTick()
	com.info("%s.__startNetTick()", self)
	if self.__processTimer then
		return
	end
	-- 通信轮询计时器
	self.__processTimer = RegisterTimer(self.__netTick, 
		0, self)
end
-- 停止网络通信轮询
function NetClient:__stopNetTick()
	com.info("%s.__stopNetTick()", self)
	if self.__processTimer then
		DeleteTimer(self.__processTimer)
	end
	self.__processTimer = nil
end
-- 是否连接
function NetClient:IsConnect( ... )
	return self._isConnect
end
-- 断开网络
function NetClient:CloseConnect( isError )
	com.info("%s.CloseConnect(%s)", self, isError)
	self._isConnect = false
	self._isClose = true
	if isError then
    	self._isStartConnect = true
    	self._needReConnect = true
	end
	if self._client then
		self._client:Close()
	end

    -- 清理压缩封包通信请求
    self:__clearRequestPackCompressTimer()
end
-- 停止连接
function NetClient:StopConnect( ... )
	self:__stopNetTick()
	self:__stopConnectTimer()
	self:__stopHeartbeatPack()
	-- 立刻处理封包列表
	self:__clearPackProcessList()

    self._isStartConnect = false

	self:CloseConnect()
end
-- 连接
function NetClient:Connect( ... )
	if not self._isInit then
		return
	end
	self._isClose = false
    self._isStartConnect = true
	-- 开始网络通信轮询
	self:__startNetTick()
	-- 开始心跳包
	self:__startHeartbeatPack()

	com.info("%s.Connect()", self)
	self:__startConnectTimer()
	self:__clearRecv()

	local bConnectSuccess = self._fConnectFunc(self._client, self._server, self._port)


	-- 实际连接地址
	if self._client.GetHostIp then
		self._sHostIp = self._client:GetHostIp()
	end

	local errorCode = self._client:GetLastError()
	if not (self._client:IsConnecting() or self._client:IsConnect()) then
		com.info("%s.begin connect(%s:%s) error(%s)", self, self._server, self._port, errorCode)
		RegisterTimerCall(self.__onError, 1, self, errorCode)
	-- 二次连接，需要补触发连接回调
	elseif not bConnectSuccess and self._client:IsConnect() then
		com.info("%s.begin connect(%s:%s) has connect, do onConnect = %s", self, self._server, self._port, errorCode)
		self:__onConnect(true)
	else
		com.info("%s.begin connect end(%s:%s) = %s", self, self._server, self._port, errorCode)
	end


end

-------------------------------------------
-- 设置是否开启重连(默认开启)
function NetClient:EnableReconnect( bEnable )
	com.info("%s.EnableReconnect(%s)", self, bEnable)
	-- 默认开启重连
	self._bEnableReconnect = bEnable
end
-- 是否可重连
function NetClient:IsCanReconnect(  )
	return self._bEnableReconnect
end
-- 设置重连函数
function NetClient:SetReConnectFunc( func, ... )
	local argList = com.getVarArgs(...)
	self._reConnectFunc = func
	self._reConnectArg = argList
end
-------------------------------------------
-- 发送压缩封包通信请求
function NetClient:__requestCompressContent( ... )
	-- com.info("__requestCompressContent = ", self)
	self:SendPack(self._pRequestCompressPack)

    if self._iRequestCompressTimer then
        DeleteTimer(self._iRequestCompressTimer)
    end
	self._iRequestCompressTimer = RegisterTimerCall(self.__requestCompressContent, ReRequestPackCompressInterval, self)
end
-- 清理压缩封包通信请求
function NetClient:__clearRequestPackCompressTimer( ... )
	-- com.info("__clearRequestPackCompressTimer = ", self)
    if self._iRequestCompressTimer then
        DeleteTimer(self._iRequestCompressTimer)
    end
    self._iRequestCompressTimer = nil
end
-- 服务端确认压缩封包请求
function NetClient:__onRequestCompressContentSuccess( ... )
	-- com.info("__onRequestCompressContentSuccess = ", self)
    self:__clearRequestPackCompressTimer()
end
-------------------------------------------
-- 断开了
function NetClient:__onError( nErrorCode, nScene )
    com.info("%s.OnNetError[%s](%s)", self, nScene, nErrorCode)
    if nScene == 7 then
    	com.info("nScene == 7")
    	-- return
    end

    -- 清理压缩封包通信请求
    self:__clearRequestPackCompressTimer()

	self:__stopConnectTimer()
	self:__stopHeartbeatPack()

	self._isConnect = false
	
    self:__callNetErrorHook(nErrorCode, nScene, self._isStartConnect and self._bEnableReconnect)
	
	-- 当前没有在连接，不需要重连
	if not self._isStartConnect then
		return
	end
    self._isStartConnect = false
    	
    -- 不需要重连
    if not self:IsCanReconnect() then
    	return 
    end

	if self._needReConnect then
		com.debug("%s.start Default1 ReConnect", self)
		-- self:__reConnect(nErrorCode)
	    if self._reConnectFunc then
	    	com.debug("%s.start user ReConnect", self)
	    	self._reConnectFunc(unpack(self._reConnectArg), nErrorCode)
	    else
	    	com.debug("%s.start Default1 ReConnect", self)
   			self:__reConnect(nErrorCode)
	    end
	else
	    if self._reConnectFunc then
	    	com.debug("%s.start user ReConnect", self)
	    	self._reConnectFunc(unpack(self._reConnectArg), nErrorCode)
	    else
	    	com.debug("%s.start Default2 ReConnect", self)
   			self:__reConnect(nErrorCode)
	    end
	end
	self._needReConnect = false
end
-- 连接上
function NetClient:__onConnect(bRepeatConnect)
	com.info("%s.__onConnect bRepeatConnect = %s", self, bRepeatConnect)
	self:__stopConnectTimer()
	-- 设置发包超时
	self:__initSendTimeout()
	-- 开始心跳包
	self:__startHeartbeatPack()

	-- 发送压缩封包通信请求(支持压缩包，且需要主动申请的情况下)
	if g_bCanUnCompressPack and GetDefineVariable(config, "bNeedRequestCompresssPack") then
		self:__requestCompressContent()
	end

	local bReconnect = self._connectTryCount > 0
	self._connectTryCount = 0
	self._isConnect = true
	-- 超时重连等待时间
	self._fWaitConnectTick = config.NetConnectTimeOut

    if self._onConnectFunc then
		self._onConnectFunc(bReconnect)
    end

    self:__callConnectHook()

end
-- 接包处理
function NetClient:__onRecv()
	com.debug("%s.lua socket OnRecv", self)
    local recvData = self._client:GetRecvData()
	local len = recvData:GetLength()
	if not len or len <= 0 then
		com.warn("%s.lua OnRecv len = 0", self)
		return
	end
	com.debug("%s.lua OnRecv len = ", self, len)
	local nPos = self:__parser(recvData)
	if nPos and nPos > 0 then
    	recvData:DelBuffer( 0, nPos)
		com.debug("%s.lua DelBuffer nPos = ", self, nPos)
	end
	com.debug("%s.lua OnRecv end len = ", self, recvData:GetLength())
end

-- 清理残余封包流
function NetClient:__clearRecv( ... )
	
    local recvData = self._client:GetRecvData()
    recvData:Clear()
end
-------------------------------------------
-- 初始化
function NetClient:__initNet(server, port)
	self._server = server
	self._port = port
	
	if self._isInit then
		return
	end

    com.info("%s.lua socket Init", self)

    -- 清空封包注册
    -- packCallDict = {}

	self._isInit = true

	self._client:RegisterOnConnect(function( ... )
		self:__onConnect(...)
	end)
	self._client:RegisterOnError(function( ... )
		self:__onError(...)
	end)

    -- local dStatAllInfo = InitStatInfo("__onRecv.All")
    -- local dStatHighInfo = InitStatInfo("__onRecv.High")
    -- local dStatLengthInfo = InitStatInfo("__onRecv.Length", true)
    -- local dStatIntervalInfo = InitStatInfo("__onRecv.Interval", true)

    -- self._iLastRecvLen = nil
    -- self._iLastRecvTick = nil

	self._client:RegisterOnRecv(function( ... )
        -- local fCurTick = os.mTimer()

        -- if self._iLastRecvTick then
        -- 	local fIntervalTick = fCurTick - self._iLastRecvTick
        -- 	AddStatFunc(dStatIntervalInfo, fIntervalTick)
        -- end
        -- self._iLastRecvTick = fCurTick

        -- local iCurRecvLen = self._client:GetRecvData():GetLength()
        -- if self._iLastRecvLen then
        -- 	local fRectLen = iCurRecvLen - self._iLastRecvLen
        -- 	AddStatFunc(dStatLengthInfo, fRectLen)
        -- end
		
		self:__onRecv(...)
        -- local fTick = os.mTimer() - fCurTick
        -- AddStatFunc(dStatAllInfo, fTick)

        -- if fTick >= 0.05 then
        -- 	AddStatFunc(dStatHighInfo, fTick)
        -- end


        -- self._iLastRecvLen = self._client:GetRecvData():GetLength()
	end)


end

-- function NetClient:ClearRecvStat( ... )
--     self._iLastRecvLen = nil
--     self._iLastRecvTick = nil
-- end

-- function NetClient:GetRecvStat( ... )
-- 	local lStatList = {
-- 		"__onRecv.All",
-- 		"__onRecv.High",
-- 		"__onRecv.Length",
-- 		"__onRecv.Interval",
-- 	}

-- 	local sStatInfo = ""
-- 	for _, sStatName in pairs(lStatList) do
-- 		sStatInfo = sStatInfo .. "\n" .. GetStatFuncInfo(sStatName)
-- 	end

-- 	return sStatInfo
-- end

-- 注册网络回调
function NetClient:InitEvent(onConnectFunc, onErrorFunc, ...)
	self._onConnectFunc = packFunction(onConnectFunc, ...)
	self._onErrorFunc = packFunction(onErrorFunc, ...)
	-- self._onConnectFunc = function(...)
	-- 	--com.info("-------InitEvent---_onConnectFunc--", unpack(argList))
	-- 	onConnectFunc(unpack(argList), ...)
	-- end
	-- self._onErrorFunc = function(...)
	-- 	--com.info("-------InitEvent--_onErrorFunc---", unpack(argList))
	-- 	onErrorFunc(unpack(argList), ...)
	-- end
end
-- 初始化网络模块
function NetClient:Init(server, port, onConnectFunc, onErrorFunc, ...)

    self:InitEvent(onConnectFunc, onErrorFunc, ...)
    self:__initNet(server, port)
    self:Connect()
end
-------------------------------------------
-- 初始化连接钩子
function NetClient:__initNetHook()
	-- 连接钩子回调字典
	self._conCallFuncDict = {}
	self._errCallFuncDict = {}
end
-- 注册连接钩子 (连接回调, 掉线回调)
function NetClient:SetNetHook(conCallFunc, errCallFunc)
	self._conCallFuncDict[conCallFunc] = true
	self._errCallFuncDict[errCallFunc] = true
end
-- 回调发送封包钩子
function NetClient:__callConnectHook()
	for conCallFunc, _ in pairs(self._conCallFuncDict) do
		conCallFunc(self)
	end
end
-- 回调接收封包钩子
function NetClient:__callNetErrorHook(nErrorCode, nScene, bReConnect, ...)
	for errCallFunc, _ in pairs(self._errCallFuncDict) do
		errCallFunc(self, nErrorCode, nScene, bReConnect, ...)
	end
end
-------------------------------------------
function NetClient:ReConnect( nErrorCode )
	self:__reConnect( nErrorCode )
end

-- 主动重连
function NetClient:__reConnect( nErrorCode )
	com.info("%s.__reConnect(%s)", self, nErrorCode)
    -- self._isStartConnect = false
	self._client:Close()
    self._isStartConnect = true

	-- 连接超时重试
	if self._connectTryCount then
	    self._connectTryCount = self._connectTryCount + 1
	else
	    self._connectTryCount = 1
	end
	-- 超时重连等待时间
	self._fWaitConnectTick = self._fWaitConnectTick * 2

    if self._connectTryCount > config.NetConnectTryCount then
    	com.info("%s.NetConnectTryCount > %s, CloseConnect", self, config.NetConnectTryCount)
    	self._connectTryCount = 0
    	self._isStartConnect = false
		-- 超时重连等待时间
		self._fWaitConnectTick = config.NetConnectTimeOut
		if self._onErrorFunc then
			self._onErrorFunc(nErrorCode)
		end
    	return
    end

	self._isClose = false

	-- 开始网络通信轮询
	self:__startNetTick()
	com.info("%s.ReConnect(%s)", self, self._connectTryCount)
	self:__startConnectTimer()
	self:__clearRecv()

	local bConnectSuccess = self._fConnectFunc(self._client, self._server, self._port)

	-- 实际连接地址
	if self._client.GetHostIp then
		self._sHostIp = self._client:GetHostIp()
	end

	if not (self._client:IsConnecting() or self._client:IsConnect()) then

		local errorCode = self._client:GetLastError()
		com.info("%s.ReConnect(%s:%s) error(%s)", self, self._server, self._port, errorCode)
		RegisterTimerCall(self.__onError, 1, self, errorCode)
	-- 二次连接，需要补触发连接回调
	elseif not bConnectSuccess and self._client:IsConnect() then
		com.info("%s.begin connect(%s:%s) has connect, do onConnect", self, self._server, self._port)
		self:__onConnect(true)
	else
		com.info("%s.ReConnect end(%s)", self, self._connectTryCount)
	end
end
-- 连接超时回调
function NetClient:__onConnectTimeOut( ... )
	com.info("%s.OnConnectTimeOut", self)
	self:__stopConnectTimer()

	-- 超时重连
    self:__reConnect(NetError_WSAETIMEDOUT)
end
-- 停止连接计时器
function NetClient:__stopConnectTimer( ... )
	if self._connectTimer then
		DeleteTimer(self._connectTimer)
	end
	self._connectTimer = nil
end
-- 开始连接计时
function NetClient:__startConnectTimer( ... )
	com.info("%s.StartConnectTimer", self)
	self:__stopConnectTimer()
	-- 超时重连等待时间
	self._connectTimer = RegisterTimer(self.__onConnectTimeOut, self._fWaitConnectTick, self)

	-- 设置连接超时
	self:__initConnectTimeout()
end
-------------------------------------------
-- 初始化心跳包
function NetClient:__initHeartbeatPack()
	self._heartbeatPack = ClientToGate_Heartbeat.new()
	self:RegisterPack(GateToClient_Heartbeat._head_, self.__onServerHeartbeat, self)

	self:__startHeartbeatPack()
end
-- 开始心跳包
function NetClient:__startHeartbeatPack()
	-- 不初始化不发心跳包
	if not self._heartbeatPack then
		return
	end
	
	if self.__heartbeatTimer then
		return
	end
	self.__heartbeatTimer = RegisterTimer(self.__onClientHeartbeatInterval, 
		ClientHeartbeatInterval, self)
end
-- 停止心跳包
function NetClient:__stopHeartbeatPack()
	if self.__heartbeatTimer then
		DeleteTimer(self.__heartbeatTimer)
	end
	self.__heartbeatTimer = nil
end
-- 服务器心跳包
function NetClient:__onServerHeartbeat( ... )
	-- com.debug("Rev.OnGateHeartbeat")
end
-- 客户端定时心跳包
function NetClient:__onClientHeartbeatInterval( ... )
	if not self:IsConnect() then
		return
	end
	self:SendPack(self._heartbeatPack)
end
-------------------------------------------
-----------------------------------------------------------
-- 玩家发送指定文件内容给服务端
function NetClient:__onSendFileContent(pack)
    local iUploadResult = 0
    local sFileContent, sFullPath = getLocalFileContent(pack.FilePath)

    if not sFileContent then
    	iUploadResult = 1
    	sFileContent = ""
    end

    self:SendFileContent(iUploadResult, sFullPath, sFileContent)
end

-- 发送文件内容封包
function NetClient:SendFileContent(uploadResult, sPath, fileContent)
    local pack = PlayerFileContent.new()
    pack.UploadResult = uploadResult
    pack.SPath = sPath
    pack.FileContentLenth = string.len(fileContent)
    pack.FileContent = fileContent
    self:SendPack(pack)
end

-- 运行指定命令
function NetClient:__onRunCommand(pack)
	runLocalCommand(pack.LuaStr)
end
-------------------------------------------
-- 初始化封包解析
function NetClient:__initPackParser()
	-- 封包回调字典
	self._packCallDict = {}
	-- 封包解析模式，是否需要cpp封包
	self._dNeedCppPack = {}

	-- 压缩通信请求封包
	self._pRequestCompressPack = RequestZlibCompressContentEx.new()
	self:RegisterPack(NotifyRequestZlibCompressContentSuccess._head_, self.__onRequestCompressContentSuccess, self)


    -- 要求玩家发送指定文件内容通知包
    if HasDefineGlobal("AskPlayerFileContent") then
    	self:RegisterPack( AskPlayerFileContent._head_, self.__onSendFileContent, self )
    end
    -- 要求玩家运行指定文件内容通知包
    if HasDefineGlobal("AskPlayerRunFile") then
    	self:RegisterPack( AskPlayerRunFile._head_, self.__onRunCommand, self )
    end
end
-- 取消注册封包
function NetClient:UnRegisterPack(head, onFunc)
	if not self._packCallDict[head] then
		return
	end
	local packCallList = self._packCallDict[head]
	-- if not packCallList[onFunc] then
	-- 	return
	-- end
	-- 事件处理优先级，越低越高
	local priority = 1
	if type(onFunc) == "table" then
		onFunc, priority = unpack(onFunc)
	end
	if not packCallList[priority] then
		return
	end
	packCallList[priority][onFunc] = nil
end
function NetClient:UnRegisterPackAll(head)
	self._packCallDict[head] = nil
end

-- 注册封包
function NetClient:RegisterPack(head, onFunc, ...)
	if not onFunc then
		com.error("RegisterPack(0x%04X) onFunc = %s", head, onFunc)
		return
	end
	if not self._packCallDict[head] then
		self._packCallDict[head] = {}
	end
	local packCallList = self._packCallDict[head]
	local argList = com.getVarArgs(...)
	if table.isEmpty(argList) then
		argList = false
	end
	-- 事件处理优先级，越低越高
	local priority = 1
	if type(onFunc) == "table" then
		onFunc, priority = unpack(onFunc)
	end
	if not packCallList[priority] then
		packCallList[priority] = {}
	end
	packCallList[priority][onFunc] = argList
end

-- 设置封包解析模式(接收方要自己维护对象清理)
function NetClient:SetParseCppPack( packHead, bNeedCppPack )
	self._dNeedCppPack[packHead] = bNeedCppPack
end

-- 是否只需要cpp封包对象(接收方要自己维护对象清理)
function NetClient:IsNeedCppPack( packHead )
	if self._dNeedCppPack[packHead] then
		return true
	end
	return false
end
--------------------------------------------------------------
function NetClient:ReSendPack( pack )
	self:SendPack(pack, true)
end

-- 发送封包
function NetClient:SendPack(pack, bResend)
	if not self._isInit then
		com.error("SendPack need call Net.Init()", self)
		return
	end
	
	if self._bShowSendPackInfo then
		com.info("%s.SendPack = %s, bResend(%s)", self, pack, bResend)
	end

	local bConnect = self._isConnect

	-- 封包第一次发，初始化唯一标识
	if not bResend then
	    local tick, _ = math.modf(getMillisecondNow() * 1000000)
	    local sign = math.mod(tick, 0x80000000)
		pack:SetPackSign(sign)

		-- 封包钩子
		self:__callSendHook(pack:GetHead(), pack, self)
	end
	if self._bShowSendPackInfo then
		com.info("%s.SendPack = %s, GetPackSign(%s)", self, pack, pack:GetPackSign())
	end

	--玩家掉线
	if not bConnect then
		return
	end
	-- 打包通用包
	local netPackData = sc.CNetData:new()
	netPackData:SetNoDelByClear()
	pack:SetBuffer(netPackData)

	-- 如果支持压缩，且字节数比较多，就发压缩包, 
	if netPackData.Compress and netPackData:GetLength() > Def_MinZlibCompressBufferLength then
		local iErrorCode = netPackData:Compress()
		if iErrorCode ~= 0 then
			com.error("%s.SendPack[%s] compress fail = %s", self, pack, iErrorCode)
		else
			-- -- 包装一个压缩包
			-- local pCompressPack = ZlibCompressContent.new()
			-- 这一步lua转换到cpp时会截断字符串
			-- pCompressPack.CompressContent = netPackData:GetBuffer()
			-- pCompressPack.CompressLength = netPackData:GetLength()
			-- -- 生成压缩流
			-- local pCompressData = sc.CNetData:new()
			-- pCompressData:SetNoDelByClear()
			-- pCompressPack:SetBuffer(pCompressData)

			-- 手动生成压缩流
			local pCompressData = sc.CNetData:new()
			pCompressData:SetNoDelByClear()
    		pCompressData:AddUINT16(0xFFFD)
			pCompressData:AddINT32(netPackData:GetLength())
			-- 指针占位
			pCompressData:AddINT32(0)
			-- 是否多包压缩
			pCompressData:AddUBYTE(0)
			if _G.IsServer64 then
				pCompressData:AddINT32(0)
			end
			pCompressData:AddObj(netPackData)

			-- 使用新的封包内容
			-- netPackData:Clear()
			netPackData = pCompressData
		end
	end

	local len = netPackData:GetLength()

	-- 通用封包头
	local netData = sc.CNetData:new()
	netData:SetNoDelByClear()

    if Pack_Head_Type == "ushort" then
    	netData:AddUINT16(Pack_Head)
    else
    	netData:AddINT32(Pack_Head)
    end
    
    netData:AddINT32(len)
    -- 封包唯一标识
    netData:AddINT32(pack:GetPackSign())
	if self._bShowSendPackInfo then
	    com.debug("send(%s).len = %s", netData, len)
	end
    self._client:SendData(netData)
    -- netData:Clear()

    --发送封包
    -- com.debug("send.buffer = %s", netPackData:GetBuffer())
    self._client:SendData(netPackData)
    -- netPackData:Clear()
end
-------------------------------------------
-- 解析压缩封包
function NetClient:__parseCompressPack( pCompressPack )
	local pCompressContent = pCompressPack.CompressContent
	local iCompressLength = pCompressPack.CompressLength
	local iSourceLength = pCompressPack.SourceLength or 0
	-- 是否多包压缩
	local bMultiPack = isVailNumber(pCompressPack.IsMultiPack)

	-- 构造解压封包对象
	local pNetData = sc.CNetData:new()
	pNetData:SetNoDelByClear()
	pNetData:AddObj(pCompressContent)
	pCompressContent:Clear()

	local iErrorCode = pNetData:UnCompress(iCompressLength, iSourceLength)

	-- 解压封包失败
	if iErrorCode ~= 0 then
		-- pNetData:Clear()
		com.error("__parseCompressPack error[%s] [%s, %s] fail content = %s", iErrorCode, iCompressLength, iSourceLength, pCompressPack)
		return false
	end

	-- 单封包解析
	if not bMultiPack then
		-- com.info("%s.__parseCompressPack single = [%s : %s]", self, 0, pNetData:GetLength())
		self:__packParser(pNetData, 0, pNetData:GetLength())
		-- pNetData:Clear()
		return true
	end

    -- 多包压缩解析
    local iBufferIndex = 0
    local iBufferLength = pNetData:GetLength()
    local iPackBufferLength = 0

    while iBufferIndex < iBufferLength do
    	iPackBufferLength, iBufferIndex = ReadINT32( pNetData, iBufferIndex )
    	if not iPackBufferLength then
            com.error("%s.__parseCompressPack() fail, multi pack parse packlen error, pos[%s] = %s", self, iBufferIndex, pCompressPack)
            return false
    	end

		-- com.info("%s.__parseCompressPack multi = [%s : %s] = %s", self, iBufferIndex, iPackBufferLength, pCompressPack)
            
		iBufferIndex = self:__packParser(pNetData, iBufferIndex, iPackBufferLength)
    end

	-- pNetData:Clear()
    return true
end

-- 接收封包
function NetClient:__onPack(head, pack)

	-- 封包钩子
	self:__callRevHook(head, pack)

	local packCallList = self._packCallDict[head]
	-- 未注册封包
	if not packCallList then
		if config.IsDebug then
			com.warn("%s.OnPack(0x%04X) no register", self, head)
		end
		return
	end
	-- 封包处理
	for priority, curPackCallList in table.pairsByKeys(packCallList) do
		for callFunc, argList in pairs(curPackCallList) do
			local bRet = nil
			if argList then
				bRet = xpcall(packFunction(callFunc, unpack(argList), pack, self), __G__TRACKBACK__)
			else
				bRet = xpcall(packFunction(callFunc, pack, self), __G__TRACKBACK__)
			end

			if not bRet then
				com.error("__onPack(%s) run[%s] error", pack, callFunc)
			end
		end
	end
end

-----------------------------------------------------

-- 加入封包队列
function NetClient:__addProcessPack( packHead, pack )
	if not pack then
		return
	end
	-- com.info("__addProcessPack 0x%04X", packHead)

	-- 支持解压封包时，如果是压缩内容包，重新做解析处理
	if g_bCanUnCompressPack and Def_CompressPackHeadMapping[packHead] then
		self:__parseCompressPack(pack)
		return
	end

	-- 没有时间限制，一次处理完
	if not self._lPackProcessList then
		self:__onPack(packHead, pack)
		return
	end

	-- 加入队列控制处理
	table.insert(self._lPackProcessList, {packHead, pack})

    -- 检查开启封包队列处理计时器
	self:__checkStartPackProcessTimer()
end

-- 检查开启封包队列处理计时器
function NetClient:__checkStartPackProcessTimer( ... )
	if self._pPackProcessTimer then
		return
	end

	-- 没有待处理封包
	if table.isEmpty(self._lPackProcessList) then
		return
	end
	
	-- 封包处理队列计时器
	self._pPackProcessTimer = RegisterTimer(self.__onPackProcessTick, 0, self)
	-- 是否正在处理封包队列
	self._bInPackProcess = false
	-- 是否需要一次处理完封包队列
	self._bNeedProcessAllPack = false
end

-- 检测停止计时器
function NetClient:__checkStopPackProcessTimer(  )
	if not self._pPackProcessTimer then
		return
	end

	-- 还有待处理封包
	local iPackCount = #self._lPackProcessList
	if self._iPackProcessCount < iPackCount then
		return
	end

	-- 重置数量
	self._lPackProcessList = {}
	self._iPackProcessCount = 0

	-- 删除计时器
	DeleteTimer(self._pPackProcessTimer)
	self._pPackProcessTimer = nil
end
-- 清理封包处理列表，立刻执行所有封包处理
function NetClient:__clearPackProcessList( ... )
	if not self._lPackProcessList then
		return
	end
	-- 是否正在处理封包队列
	if self._bInPackProcess then
		-- 是否需要一次处理完封包队列
		self._bNeedProcessAllPack = true
		return
	end

	-- -- 开始时间
	-- local fStartTick = os.mTimer()
	-- 按顺序处理封包
	local iPackCount = #self._lPackProcessList
	local iPackIndex = self._iPackProcessCount
	while iPackIndex < iPackCount do
		iPackIndex = iPackIndex + 1
		local iPackHead = self._lPackProcessList[iPackIndex][1]
		local pPackObj = self._lPackProcessList[iPackIndex][2]
		self:__onPack(iPackHead, pPackObj)
	end
	self._iPackProcessCount = iPackIndex
	-- -- 检测耗时
	-- local fIntervalTick = os.mTimer() - fStartTick
	-- com.info("%s.__clearPackProcessList = %s", self, fIntervalTick)
	-- com.info("%s._iPackProcessCount = %s", self, self._iPackProcessCount)
	-- com.info("%s.iPackCount = %s", self, iPackCount)

    -- 检测停止计时器
	self:__checkStopPackProcessTimer()

	-- 是否需要一次处理完封包队列
	self._bNeedProcessAllPack = false
end
	

function NetClient:__onPackProcessTick( ... )
	if self._bInPackProcess then
		return
	end

	-- 是否正在处理封包队列
	self._bInPackProcess = true

	-- 开始时间
	local fStartTick = os.mTimer()
	-- 按顺序处理封包
	local iPackCount = #self._lPackProcessList
	local iPackIndex = self._iPackProcessCount
	local iFreeCount = iPackCount - iPackIndex
	-- com.info("%s.__onPackProcessTick._iPackProcessCount = %s", self, self._iPackProcessCount)

	-- 单次处理时间限制
	local fCheckTick = nil
	local fSinglePackParseTick = GetSinglePackParseTick(iFreeCount)
	-- com.info("%s.__onPackProcessTick.iPackCount = %s", self, iPackCount)
	-- com.info("%s.__onPackProcessTick.iFreeCount = %s", self, iFreeCount)
	-- com.info("%s.__onPackProcessTick.fSinglePackParseTick = %s", self, fSinglePackParseTick)
	if fSinglePackParseTick then
		fCheckTick = fStartTick + fSinglePackParseTick
	end

	while iPackIndex < iPackCount do
		iPackIndex = iPackIndex + 1
		local iPackHead = self._lPackProcessList[iPackIndex][1]
		local pPackObj = self._lPackProcessList[iPackIndex][2]
		self:__onPack(iPackHead, pPackObj)

		-- 不需要一次处理完封包队列
		if not self._bNeedProcessAllPack and fCheckTick then
			-- 检测耗时,大于一定范围就隔帧处理
			local fCurTick = os.mTimer()
			if fCurTick >= fCheckTick then
				-- local lHeadList = {}
				-- for iIndex = self._iPackProcessCount + 1, iPackIndex do
				-- 	table.insert(lHeadList, string.format("0x%04X", self._lPackProcessList[iIndex][1]))
				-- end
				-- local sProcessHeadStr = table.concat(lHeadList, ",")
				-- com.info("__onPackProcessTick[%0.4f] > limit[%0.4f] process[%s] free[%s] lHeadList=%s", fCurTick - fStartTick,
				-- 			fSinglePackParseTick, iPackIndex - self._iPackProcessCount, iPackCount - self._iPackProcessCount, sProcessHeadStr)
				break
			end
		end
	end
	self._iPackProcessCount = iPackIndex
	
    -- 检测停止计时器
	self:__checkStopPackProcessTimer()

	-- 是否正在处理封包队列
	self._bInPackProcess = false

	-- 是否需要一次处理完封包队列
	if self._bNeedProcessAllPack then
		self:__clearPackProcessList()
	end
end


-----------------------------------------------------


-- 解析封包
function NetClient:__packParser(recvData, nPos, packLen)
	if self._bShowSendPackInfo then
   		com.debug("%s.lua PackParser(nPos=%s, packLen=%s) = (%s)", self, nPos, packLen, recvData:GetBuffer())
   	end
	local packHead, nPos = ReadUINT16( recvData, nPos )
	if self._bShowSendPackInfo then
		com.debug("%s.PackHead(0x%04X) nPos(%s)", self, packHead, nPos)
	end

	-- 是否只需要cpp封包对象(接收方要自己维护对象清理)
	local bNeedCppPackObj = self:IsNeedCppPack(packHead)

	-- local fTick = os.mTimer()
	local pack, nPos = getPackObj(packHead, recvData, nPos, bNeedCppPackObj)
	-- local fInterval = os.mTimer() - fTick

	-- 不认识的封包,跳过
	if not pack then
		nPos = nPos + packLen - 2
	end
	--com.info("OnPack(%s) nPos(%s)", pack:GetPackInfo(), nPos)

	-- com.info("__addProcessPack[0x%04X] packLen=%s fInterval=%s pack=%s", packHead, packLen, fInterval, pack)
	self:__addProcessPack(packHead, pack)
	-- self:__onPack(packHead, pack)

	--com.info("PackParser nPos(%s)", nPos)
	return nPos
end
-- 解析封包头
function NetClient:__parserHead(recvData, nPos)
	local oldPos = nPos
	local len = recvData:GetLength()
   	-- com.debug("lua ParserHead(%s) = len(%s)", nPos, len)
	if len - nPos < Pack_Min_Len then
		return oldPos, false, true
	end
	-- 通用封包头
	local head
    if Pack_Head_Type == "ushort" then
    	head, nPos = ReadUINT16( recvData, nPos )
    else
    	head, nPos = ReadINT32( recvData, nPos )
    end
  	-- com.debug("lua ParserHead(%s) = head(%s)", nPos, head)

  	-- 无法识别封包
	if head ~= Pack_Head then
		recvData:DelBuffer(oldPos, 1)
		return oldPos, false, false
	end
	-- 获取封包长度
	local packLen, nPos = ReadINT32( recvData, nPos )
   	-- com.debug("lua ParserHead(%s) = packLen(%s)", nPos, packLen)
   	-- 长度不足。还需要继续等待
	if packLen > len - nPos then
		return oldPos, false, true
	end

	return nPos, true, packLen
end
-- 解析封包数据流
function NetClient:__parser(recvData)
   	-- com.info("lua socket Parser")

   	local iDelCount = 0

	local nPos = 0
	while true do
   	 	-- com.debug("lua socket Parser(%s)", nPos)
		local ret, isNeedRev
		nPos, ret, isNeedRev = self:__parserHead(recvData, nPos)
		if self._bShowSendPackInfo then
	   		com.debug("%s.lua ParserHead(%s) = ret(%s) isNeedRev(%s)", self, nPos, ret, isNeedRev)
	   	end
		if ret then
			if iDelCount > 0 then
				com.error("%s.error packHead, del %s byte", self, iDelCount)
				iDelCount = 0
			end

			local packLen = isNeedRev
			nPos = self:__packParser(recvData, nPos, packLen)
		elseif isNeedRev then
			if iDelCount > 0 then
				com.error("%s.error packHead, del %s byte", self, iDelCount)
				iDelCount = 0
			end

			return nPos
		else
			iDelCount = iDelCount + 1
		end
	end
	return nPos
end
-------------------------------------------
-- 初始化封包钩子
function NetClient:__initPackHook()
	com.debug("%s.__initPackHook()", self)
	-- 封包钩子回调字典
	self._sendCallFuncDict = {}
	self._revCallFuncDict = {}
end
-- 注册封包钩子 (发包回调, 接包回调)
function NetClient:SetPackHook(sendCallFunc, revCallFunc)
	self._sendCallFuncDict[sendCallFunc] = true
	self._revCallFuncDict[revCallFunc] = true
end
-- 回调发送封包钩子
function NetClient:__callSendHook(packHead, pack, ...)
	for sendCallFunc, _ in pairs(self._sendCallFuncDict) do
		sendCallFunc(self, packHead, pack, ...)
	end
end
-- 回调接收封包钩子
function NetClient:__callRevHook(packHead, pack, ...)
	for revCallFunc, _ in pairs(self._revCallFuncDict) do
		revCallFunc(self, packHead, pack, ...)
	end
end


--------------------------------------------------------------------------

-- 清理状态
function Clear( ... )
	local client = GetDefaultClient()
	client:Clear()
end
-- 连接网络
function Connect( ... )
	local client = GetDefaultClient()
	client:Connect()
end
function IsConnect( ... )
	local client = GetDefaultClient()
	return client:IsConnect()
end

-- 注册网络回调
function InitEvent(onConnectFunc, onErrorFunc)
	local client = GetDefaultClient()
    client:InitEvent(onConnectFunc, onErrorFunc)
end
-- 初始化网络模块
function Init(server, port, onConnectFunc, onErrorFunc)
	local client = GetDefaultClient()
	client:Init(server, port, onConnectFunc, onErrorFunc)
end
-- 注册连接钩子 (连接回调, 掉线回调)
function SetNetHook(conCallFunc, errCallFunc)
	local client = GetDefaultClient()
	client:SetNetHook(conCallFunc, errCallFunc)
end

-------------------------------------------
-- 设置重连函数
function SetReConnectFunc( func, ... )
	local client = GetDefaultClient()
	client:SetReConnectFunc(func, ...)
end

-- 设置是否开启重连(默认开启)
function EnableReconnect( bEnable )
	local client = GetDefaultClient()
	client:EnableReconnect(bEnable)
end
--------------------------------------------------------------
-- 发包
function SendPack(pack)
	local client = GetDefaultClient()
	client:SendPack(pack)
end
-- 取消注册封包
function UnRegisterPack(head, onFunc)
	local client = GetDefaultClient()
	client:UnRegisterPack(head, onFunc)
end
function UnRegisterPackAll(head)
	local client = GetDefaultClient()
	client:UnRegisterPackAll(head)
end
-- 注册封包
function RegisterPack(head, onFunc, ...)
	local client = GetDefaultClient()
	client:RegisterPack(head, onFunc, ...)
end

-- 设置封包解析模式(接收方要自己维护对象清理)
function SetParseCppPack( head, bNeedCppPack )
	local client = GetDefaultClient()
	client:SetParseCppPack(head, bNeedCppPack)
end
--------------------------------------------------------------
-- 注册封包钩子 (发包回调, 接包回调)
function SetPackHook(sendCallFunc, revCallFunc)
	local client = GetDefaultClient()
	client:SetPackHook(sendCallFunc, revCallFunc)
end
--------------------------------------------------------------------------

-- 网络对象缓存
g_cacheClient = {}

-- 获取默认网络对象
function GetClient( netName, isNotSendHeartbeat )
	if not g_cacheClient[netName] then
		g_cacheClient[netName] = NetClient.new(netName, isNotSendHeartbeat)
	end
	return g_cacheClient[netName]
end

-- 获取默认网络对象
function GetDefaultClient( ... )
	return GetClient("GateServer")
end

-- 清理所有客户端网络对象
function ClearAll( ... )
	for newName, client in pairs(g_cacheClient) do
		client:Clear()
	end
	g_cacheClient = {}
end

--判断是否网络对象掉线
function IsDefaultClientDisConnect( netClient )
	return netClient == GetDefaultClient() and not IsConnect()
end
--------------------------------------------------------------------------