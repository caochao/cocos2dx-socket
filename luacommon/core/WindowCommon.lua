module("WindowCommon", package.seeall)
---------------------------------------------------------------------
require "core/SceneCommon"
require "common/LanguageCommon"
require "common/UICommon"
require "common/ConfigCommon"
-------------------------------------------------------------------
-- 默认按钮点击间隔
local Def_ButtonClickInterval = 0.5
local Def_Windows_Config_Path = "config/window.txt"
-------------------------------------------------------------------

-- 动作节点 界面对象 映射
local g_TimeLineAndWindowtMap ={}


--  设置坐标类型
-- {
-- 	kPositionTypeRelativeBottomLeft = 1,
-- 	kPositionTypeRelativeTopLeft,
-- 	kPositionTypeRelativeTopRight,
-- 	kPositionTypeRelativeBottomRight,
-- 	kPositionTypePercent,
-- }

-- 界面log开关
local g_bEnableWindowOperLog = not GetDefineVariable(config, "bCloseWindowOperInfo")

--界面管理
local g_windowCache = {}

-- 扩展界面管理
local g_dCustomWindowInfoDict = {}

-------------------------------------------------------------------
function getSceneWinList(sceneName, sGameConfigType)
	if sGameConfigType then
		sceneName = string.format("%s_%s", sGameConfigType, sceneName)
	end
	if g_windowCache[sceneName] then
		return g_windowCache[sceneName]
	end
	return {}
end

--设置层缓存
local function setWinCache(sceneName, window, sGameConfigType)
	if sGameConfigType then
		sceneName = string.format("%s_%s", sGameConfigType, sceneName)
	end

	local name = window:GetName()
	if not g_windowCache[sceneName] then
		 g_windowCache[sceneName] = {}
	end
	g_windowCache[sceneName][name] = window

	com.debug("setWinCache(%s) = %s", sceneName, name)
end

-- 删除界面缓存
function delWinCache( pWinObj )
	local sSceneName = pWinObj:GetScene()
	local dWinDict = g_windowCache[sSceneName]
	if not dWinDict then
		return
	end
	local sName = window:GetName()
	dWinDict[sName] = nil
end

-------------------------------------------------------------------
--通过名字获取层对象
function GetWinByName(name)
	local curScene = SceneCommon:GetCurScene()
	if not curScene then
		com.error("curScene no found = %s", curScene)
		return nil
	end
	local sceneName = curScene:getName()
	if not g_windowCache[sceneName] then
		return nil
	end

	if g_windowCache[sceneName][name] then
		return g_windowCache[sceneName][name]
	end
	return nil
end

-- 是否存在界面
function HasWindow( winName )
	local layerObj = GetWinByName(winName)
	if layerObj then
		return true
	end
	return false
end

--显示窗口
function ShowWindow(winName, ...)
	if g_bEnableWindowOperLog then
		com.info("ShowWindow = ", winName, ...)
	end
		
	local layerObj = GetWinByName(winName)
	if layerObj then	
       	layerObj:Show(...)
    else
    	com.warn("ShowWindow(%s) fail, no found", winName)
	end
end
--隐藏窗口
function HideWindow(winName, bDestroy)
	if g_bEnableWindowOperLog then
		com.info("HideWindow = ", winName)
	end

	local layerObj = GetWinByName(winName)
	if layerObj then	
       	layerObj:Hide(bDestroy)
    else
    	com.warn("HideWindow(%s) fail, no found", winName)
	end
end

--窗口是否显示着
function IsShowWindow(winName)
	local layerObj = GetWinByName(winName)
	if layerObj then	
       	return layerObj:IsShow()
	end
	return false
end

--获取当前场景所有的显示中界面
function GetCurSceneShowWindows()
	local curScene = SceneCommon:GetCurScene()
	local sceneName = curScene:getName()
	local showingWindowList = {}
	if not g_windowCache[sceneName] then
		return showingWindowList
	end
	
	for windowName, windowObj in pairs(g_windowCache[sceneName]) do
		if windowObj:IsShow() then
			table.insert(showingWindowList, windowObj)
		end
	end
	return showingWindowList
end
-----------------------------------------------------------
-- 界面基类
BaseWindow = class()
function BaseWindow:ctor(arg, sGameConfigType)
	self._initArg = arg
	self._sGameConfigType = sGameConfigType

	self.name = self._initArg.name or "BaseWindow"
	self._scene = self._initArg.scene

	if self._sGameConfigType then
		self._scene = string.format("%s_%s", self._sGameConfigType, self._scene)
	end
	
	self._config = self._initArg.config
	self._type = self._config.type
	self._subType = self._config.SubType
	self._zOrder = self._config.zOrder
	self._isAutoOpen = isVailNumber(self._config.IsOpen)
	self._isLogPageView = isVailNumber(self._config.IsLogPageView)
	self._isDestroyWhenHide = isVailNumber(self._config.IsDestroyWhenHide)
	self._bDefaultCreate = isVailNumber(self._config.IsDefaultCreate)
	self._bIsReShow = isVailNumber(self._config.IsReShow)

	self._isCreate = false

	self._bMultiShow = false

	self._fHideCallFunc = nil

	self._buttonTimerList = {}

	-- 时间线列表（隐藏或销毁时释放对应的BaseWindow引用，防止内存泄露）
	self._lTimelineList = {}

	-- 注册回调控件列表（隐藏或销毁时释放对应的BaseWindow引用，防止内存泄露）
	self._lRegisterControlList = {}

	-- 客户端重连
	self:__initPlayerLoginEvent()

	-- 是否整个界面固定不翻转
	self._bFixedWindow = false

	com.debug("%s ctor", self)
	self:OnCreateBefore()
	self:RegisterWindowViewEvent("ChangeLanguageRefreshText", self.__reApplylocalization, self)
end

function BaseWindow:__initPlayerLoginEvent()
	if not self:IsLoginReShow() then
		return
	end

	local winScene = self:GetScene()
	if winScene ~= "MainScene" then
		return
	end
	self:RegisterWindowViewEvent("PlayerLoginSuccess", self.OnLogin, self)
	-- EventCommon:RegisterEvent("PlayerLoginSuccess", self.OnLogin, self)

end

-- 登录事件
function BaseWindow:OnLogin( ... )
	self:ReShow()
end

function BaseWindow:ReShow( ... )
	-- self:Hide()
	self:Show(unpack(self:GetCurShowArg()))
end

function BaseWindow:GetCurShowArg()
	return self._curShowArg
end


function BaseWindow:Destroy( bNowRelease, bNotNowClearTexture )
	com.debug("%s Destroy", self)
	if not self:IsCreate() then
		return
	end

	-- 帧回调映射去除
	if g_TimeLineAndWindowtMap and self._lTimelineList then
		for _, pTimeLine in pairs( self._lTimelineList ) do
			g_TimeLineAndWindowtMap[pTimeLine] = nil
		end
	end

	-- 按钮回调映射界面去除
	for _, pControl in pairs( self._lRegisterControlList ) do
		ScriptHandlerMgr:getInstance():removeObjectAllHandlers( pControl )
	end
	self._lRegisterControlList = {}

	
	--销毁遮罩层
	if self._baseDustLayerTimer then
		self:DeleteTimer(self._baseDustLayerTimer)
		self._baseDustLayerTimer = nil
	end
	self._baseDustLayer = nil
	self._baseDustEventDispatcher:removeEventListener(self._baseDustListener)

	for _, buttonTimerList in pairs(self._buttonTimerList) do
		for _, buttonTimer in pairs(buttonTimerList) do 
			self:DeleteTimer(buttonTimer)
		end
	end

	self._buttonTimerList = {}

	self:OnDestroy(bNowRelease)
	self:OnBaseDestroy(bNowRelease, bNotNowClearTexture)

	--注册触摸函数  
	--self.layer:unregisterScriptTouchHandler()
	--self.layer:removeFromParent()

	self._isCreate = false

end


----------------------------------------------------------
function BaseWindow:__str__( ... )
	return string.format("Window(%s|%s)[IsCreate:%s]", self._scene, self.name, tostring(self._isCreate))
end
-----------------------------------------------------------
function BaseWindow:IsCreate( ... )
	return self._isCreate
end
function BaseWindow:IsDefaultCreate(  )
	return self._bDefaultCreate
end

function BaseWindow:IsLoginReShow()
	return self._bIsReShow
end

function BaseWindow:CreateWindow( ... )
	if self._isCreate then
		return
	end
	com.debug("%s CreateWindow", self)
	self:OnCreateWindow()


	-- 应用文本多语言本地化
	self:__applylocalization()

	-- 获取场景类
	local sceneObj = SceneCommon:GetScene(self._scene)
	self.layer:setVisible(false)

	-- 添加到场景对象上	
	sceneObj:addLayer(self.layer, self._zOrder)	
	-- 防止同一帧内多次点击，触摸响应顺序异常bug
    sceneObj:getScene():sortAllChildren()	

	self:OnCreate()  
	self._isCreate = true

	self._baseDustLayer, self._baseDustEventDispatcher, self._baseDustListener = UI.createDustLayer(cc.rect(0,0,640,1136),nil,nil,self)
	self.layer:addChild(self._baseDustLayer, 999)
	self._baseDustListener:setEnabled(false)
	self._baseDustLayer:setVisible(false)
end

function BaseWindow:OnCreateWindow( ... )

end

----------------------------------------------------------
-- 注册界面全局事件， 不考虑界面是否创建都会执行
function BaseWindow:RegisterWindowGlobalEvent( eventType, func, ... )
	if not func then
		com.error("%s.RegisterWindowGlobalEvent error, func = nil")
		return
	end
	local pEventKey = EventCommon:RegisterEvent(eventType, {self.__onWindowGlobalEvent, 1, func}, self, func, ...)
	-- 反注册用到的事件key
	return pEventKey
end
-- 界面全局事件， 不考虑界面是否创建都会执行
function BaseWindow:__onWindowGlobalEvent( func, ... )
	local result = func(...)
	return result
end
-- 注册界面渲染事件，如果事件触发时，界面未创建会自动初始化
function BaseWindow:RegisterWindowDrawEvent( eventType, func, ... )
	if not func then
		com.error("%s.RegisterWindowDrawEvent error, func = nil")
		return
	end
	local pEventKey = EventCommon:RegisterEvent(eventType, {self.__onWindowDrawEvent, 1, func}, self, func, ...)
	-- 反注册用到的事件key
	return pEventKey
end
-- 界面渲染事件，如果界面未创建会自动初始化
function BaseWindow:__onWindowDrawEvent( func, ... )
	if not self:IsCreate() then
		com.debug("%s.__onWindowGlobalEvent CreateWindow", self)
		self:CreateWindow()
	end
	local result = func(...)
	return result
end
----------------------------------------------------------
-- 注册界面刷新事件，如果事件触发时，界面未创建或隐藏 不会执行
function BaseWindow:RegisterWindowViewEvent( eventType, func, ... )
	if not func then
		com.error("%s.RegisterWindowViewEvent error, func = nil", eventType)
		return
	end
	local pEventKey = EventCommon:RegisterEvent(eventType, {self.__onWindowViewEvent, 1, func}, self, func, ...)
	-- 反注册用到的事件key
	return pEventKey
end
-- 界面刷新事件，如果界面未创建或隐藏 不会执行
function BaseWindow:__onWindowViewEvent( func, ... )
	if not self:IsShow() then
		return
	end
	local result = func(...)
	return result
end
----------------------------------------------------------
function BaseWindow:GetIsAutoOpen( ... )
	return self._isAutoOpen
end

function BaseWindow:GetType()
	return self._type
end

function BaseWindow:GetSubType( ... )
	return self._subType
end

function BaseWindow:GetZOrder()
	return self._zOrder
end
function BaseWindow:GetName()
	return self.name
end
function BaseWindow:GetScene()
	return self._scene
end
----------------------------------------------------------
function BaseWindow:GetOperLock()
	return self._operLock
end
function BaseWindow:SetOperLock(isLock)
	self._operLock = isLock
end
----------------------------------------------------------

function BaseWindow:RegisterTimer(func, fInterval, ...)
	return RegisterTimer(func, fInterval, ...)
end
function BaseWindow:DeleteTimer(timer)
	return DeleteTimer(timer)
end
-----------------------------------------------------------

function BaseWindow:addChild(control, zOrder)
	zOrder = zOrder or 0
	self.layer:addChild(control, zOrder)
end

function BaseWindow:AddControl(control, zOrder)
	-- = zOrder or 0
	--self.layer:addChild(control:GetControl(), zOrder)
end

function BaseWindow:getLayer()
	return self.layer
end

function BaseWindow:IsShow()

	if not self:IsCreate() then
		return false
	end
	return self.layer:isVisible()
end

function BaseWindow:IsMultiShow(  )
	return self._bMultiShow
end
-----------------------------------------------------------


function BaseWindow:Show(...)

    self._curShowArg = getVarArgs(...)

	if not self:IsCreate() then
		self:CreateWindow()
	end

	local winScene = self:GetScene()
	local curScene = SceneCommon:GetCurScene()
	if curScene:getName() ~= winScene then
		com.error("show window(%s, %s)fail！cur in %s scene, but window in %s scene", self, self._curShowArg, curScene:getName(), winScene)
		return 
	end

	-- 界面类型为0不互斥
	if self:GetType() ~= 0 then
		local curScene = SceneCommon:GetCurScene()
		local sceneName = curScene:getName()
		local windowList = getSceneWinList(sceneName)
		for windowName, window in pairs(windowList) do
			if window ~= self then
				if window:GetType() ~= 0 and window:GetType() ~= self:GetType() then
					window:Hide()
				else
					if window:GetSubType() ~= 0 and window:GetSubType() ~= self:GetSubType() then
						window:Hide()
					end
				end
			end
		end
	end

	--检测是否需要繁体切换字体
	self:__checkZhHantChangeFont()

	--重置多语言本地化
	self:__reApplylocalization()

	self:__onBaseActionInit()

	-- 当前是否连续多次显示
	self._bMultiShow = self:IsShow()
	if not self._bMultiShow then
		self._fHideCallFunc = nil
	end
	
	self.layer:setVisible(true)
	self:OnShow(...)

	-- 友盟统计
	if self._isLogPageView then
		sc.MobClickCpp:beginLogPageView(self:GetName())

		sc.MobClickCpp:beginEventWithLabel("ShowWindow", self:GetName())
	end

	OnWindowShowChangeUIWebViewStatus()

	EventCommon:OnEvent("EnterWindow", self:GetName())
	
	self:OnBaseShow(self._bMultiShow)

	if self._baseDustLayer then
		self._baseDustLayer:setVisible(true)
		self._baseDustListener:setEnabled(true)
		local function onDustHide( ... )
			if self._baseDustLayer then
				self._baseDustLayer:setVisible(false)
				self._baseDustListener:setEnabled(false)
			end
		end
		self._baseDustLayerTimer = RegisterTimerCall(onDustHide, 0)
	end
end

function BaseWindow:OnBaseShow( bOldShow )

end

function BaseWindow:__onBaseActionInit( ... )
	-- body
end

function BaseWindow:__onBaseActionRemove( ... )
	-- body
end

--设置关闭时的回调函数
function BaseWindow:SetHideCallFunc( fCallFunc )
	self._fHideCallFunc = fCallFunc
end


-- 界面进入回调
function BaseWindow:OnBaseEnter( ... )
	self:OnEnter()
	-- EventCommon:OnEvent("EnterWindow", self:GetName())
end
function BaseWindow:Hide(bDestroy)

	if not self:IsCreate() then
		return
	end
	if not self:IsShow() then
		if bDestroy then
			self:Destroy()
		end
		return
	end

	-- -- 帧回调映射去除
	-- if g_TimeLineAndWindowtMap and self._lTimelineList then
	-- 	for _, pTimeLine in pairs( self._lTimelineList ) do
	-- 		g_TimeLineAndWindowtMap[pTimeLine] = nil
	-- 	end
	-- end

	if self._baseDustLayerTimer then
		self:DeleteTimer(self._baseDustLayerTimer)
		self._baseDustLayerTimer = nil
	end
	if self._baseDustLayer then
		self._baseDustLayer:setVisible(false)
		self._baseDustListener:setEnabled(false)
	end

	com.debug("%s.Hide()", self)
	self.layer:setVisible(false)
	self:OnHide()

	self:__onBaseActionRemove()

	for _, buttonTimerList in pairs(self._buttonTimerList) do
		for _, buttonTimer in pairs(buttonTimerList) do 
			self:DeleteTimer(buttonTimer)
		end
	end

	self._buttonTimerList = {}

	-- 友盟统计
	if self._isLogPageView then
		sc.MobClickCpp:endLogPageView(self:GetName())

		sc.MobClickCpp:endEventWithLabel("ShowWindow", self:GetName())
	end

	OnWindowShowChangeUIWebViewStatus()
	EventCommon:OnEvent("ExitWindow", self:GetName())

	-- 页面关闭时是否立刻销毁
	if self._isDestroyWhenHide or bDestroy then
		self:Destroy()
	end
	if self._fHideCallFunc then
		self._fHideCallFunc()
		self._fHideCallFunc = nil
	end
end


-- 检测是否需要繁体切换字体
function BaseWindow:__checkZhHantChangeFont( ... )
	-- body
end

-----------------------------------------------------------
-- 设置控件文本,应用多语言本地化
function BaseWindow:__applylocalization()
	-- 当前语言
	self._sLastLanguageType = LanguageCommon:GetLanguageType()

    -- 当前语言是否需求界面布局反转
	local bReverseWindowLayout = LanguageCommon:IsReverseWindowLayout()
	-- 是否整个界面固定不翻转
	if not self._bFixedWindow then
		self:DoApplylocalizationToControl(self.layer, bReverseWindowLayout)
	else
		-- 后续按钮不需要再翻转
		bReverseWindowLayout = false
	end

    self:OnApplylocalization(bReverseWindowLayout)
end
-- 界面本地化处理 (bReverseWindowLayout 当前语言是否需求界面布局反转)
function BaseWindow:OnApplylocalization( bReverseWindowLayout )
	-- body
end

function BaseWindow:__reApplylocalization( ... )
	-- 语言没变化,不做处理
	local sCurLanguageType = LanguageCommon:GetLanguageType()
	if self._sLastLanguageType == sCurLanguageType then
		return
	end
	self._sLastLanguageType = sCurLanguageType

    -- 当前语言是否需求界面布局反转
	local bReverseWindowLayout = LanguageCommon:IsReverseWindowLayout()
	-- 是否整个界面固定不翻转
	if not self._bFixedWindow then
		self:DoApplylocalizationToControl(self.layer, bReverseWindowLayout)
	else
		-- 后续按钮不需要再翻转
		bReverseWindowLayout = false
	end

    self:OnResetApplylocalization(bReverseWindowLayout)
end
-- 重置界面本地化处理 (bReverseWindowLayout 当前语言是否需求界面布局反转)
function BaseWindow:OnResetApplylocalization( bReverseWindowLayout )
	-- body
end

-- 对控件应用本地化处理
function BaseWindow:DoApplylocalizationToControl( pControl, bReverseWindowLayout )
    -- 当前语言是否需求界面布局反转
    if bReverseWindowLayout then
    	DoFlippedNode(pControl, true, false)
    -- 恢复节点翻转
    else
    	ResumeFlippedNode(pControl)
    end
end
-----------------------------------------------------------
-- 添加web控件显示控制
function BaseWindow:InitUIWebViewControl( control )
	InitWindowUIWebViewControl(self, control)
end
-- 清理web控件
function BaseWindow:ClearUIWebViewControl( control )
	ClearWindowUIWebViewControl(self, control)
end
-----------------------------------------------------------
-- 界面被添加到场景回调
function BaseWindow:OnInit( ... )
	-- body
end

-- 界面打开回调
function BaseWindow:OnShow( ... )

end

-- 界面隐藏回调
function BaseWindow:OnHide( ... )
	return
end

-- 界面初始化回调 前
function BaseWindow:OnCreateBefore( ... )

end

-- 界面初始化回调
function BaseWindow:OnCreate( ... )
	return
end

-- 界面销毁回调
function BaseWindow:OnBaseDestroy( ... )
	-- body
end
-- 界面销毁回调
function BaseWindow:OnDestroy(bNowRelease)
	-- body
end

-- 界面进入回调
function BaseWindow:OnEnter( ... )
	-- body
end

-- 界面离开回调
function BaseWindow:OnExit( ... )
	return
end

-- 插入注册回调控件列表
function BaseWindow:InsertRegisterControl( pControl )
	table.insert( self._lRegisterControlList, pControl )
end


-----------------------------------------------------------

-- 自定义界面
CustomWindow = class(BaseWindow)
function CustomWindow:ctor(arg)
	self.name = self._initArg.name or "CustomWindow"

	self._operLock = false

	-- self:CreateWindow()
end
function CustomWindow:OnCreateWindow( ... )

	local layerObj = self:InitWindow()
	if not layerObj then
		com.error("window(%s)init error", self._initArg.name)
		return
	end

	self.layer = layerObj
	-- self.layer:retain() 
	Lua_Retain(self.layer, self) 
end

-- 界面对象初始化
function CustomWindow:InitWindow( ... )
	return cc.Layer:create()
end

function CustomWindow:OnBaseDestroy(bNowRelease)
	local lastLayer = self.layer
	if lastLayer then
		lastLayer:removeFromParent(true)
	end
	
	if bNowRelease then
		com.debug("CustomWindow Destroy(%s)", self)
		if lastLayer then
			Lua_Release(lastLayer)
		end
		DumpNodeInfo(lastLayer)
		return
	end

	RegisterTimerCall(function( ... )
		com.debug("CustomWindow wait Destroy(%s)", self)
		if lastLayer then
			Lua_Release(lastLayer)
		end

		DumpNodeInfo(lastLayer)
	end, 0)
end


-----------------------------------------------------------
-- 界面管理器
GameUIManager = class(BaseWindow)
-----------------------------------------------------------

function GameUIManager:ctor(obj)
	self.name = obj.name or "GameUIManager"
	self._defaultAction = self._config.DefaultAction

	-- 界面重复打开时是否不重新播放动作
	self._bNotMultiRunAction = isVailNumber(self._config.IsNotMultiRunAction)
    com.debug("Init Window(%s) = %s", obj.name, self._config)
end


function GameUIManager:OnCreateWindow( ... )
	self._subControlList = {}
	self._dLockFontDict = {}
	--判断界面是否存在
	local time = os.mTimer()

--##JSCodeClose##Start##--js不支持
	local fullPath = cc.FileUtils:getInstance():fullPathForFilename(self._config.Path)
	if not cc.FileUtils:getInstance():isFileExist(fullPath) then
		com.error("界面csb文件（%s）不存在", self._config.Path)
		return
	end
--##JSCodeClose##End##--js不支持

	self._node = cc.CSLoader:createNode(self._config.Path) 

	--界面获取设置分辨率
	local frameSize = cc.Director:getInstance():getVisibleSize()
	self._node:setContentSize(frameSize)
	ccui.Helper:doLayout(self._node)

	self.layer = cc.Layer:create()

	if not self._node then
		com.fail("界面[%s]布局(%s)加载失败", self.name, self._config.Path)
		return
	end
	if self.layer then
		Lua_Retain(self.layer, self)
	end

	self.layer:addChild(self._node)
	--com.debug("%s.node(%s) layer(%s)", self, self._node, self.layer)

	
	function eventFunc(eventType)
		if eventType == "enter" then 
			self:OnBaseEnter()
		elseif eventType == "exit" then      
			self:OnExit()  
		else
			-- com.warn("Unknow EventType = %s", eventType)
		end 
	end
	self.layer:registerScriptHandler(eventFunc)

	self._operLock = false

	self:__init()

	self:__initCsbInfo()

	self:__initLabelEffect()

	self:__initControlLayout()
end
function GameUIManager:OnBaseDestroy( bNowRelease, bNotNowClearTexture )
	self:__onBaseActionRemove()
	local lastLayer = self.layer
	if lastLayer then
		lastLayer:removeFromParent(true)
	end
	
	if bNowRelease then
		com.debug("GameUIManager Destroy(%s)", self)
		if lastLayer then
			Lua_Release(lastLayer)
		end
		--清除内存
		if not bNotNowClearTexture then
			ImageCommon:RemoveUnusedTextures()
		end
		
		DumpNodeInfo(lastLayer)
		return
	end

	RegisterTimerCall(function( ... )	
		if lastLayer then
			com.debug("GameUIManager wait Destroy(%s)", self)
			Lua_Release(lastLayer)
		end

		--清除内存
		if not bNotNowClearTexture then
			ImageCommon:RemoveUnusedTextures()
		end

		DumpNodeInfo(lastLayer)

	end, 0)
end

--界面主动作初始化
function GameUIManager:__onBaseActionInit( ... )
	self._node:stopAllActions()
	self._baseNodeAction = cc.CSLoader:createTimeline(self._config.Path)
	self._node:runAction(self._baseNodeAction)	
	self:__initFrameEvent(self._baseNodeAction)
	self:__onSubActionInit()
end

--界面主动作清除
function GameUIManager:__onBaseActionRemove()
	self:__onSubActionRemove()
	self._node:stopAllActions()
end


--界面子动作初始化
function GameUIManager:__onSubActionInit()
	self:__onSubActionRemove()
	for	key, actionConfig in pairs(self._subCsbActionCfg) do
		if actionConfig.IsDefaultPlay == 1 then
			self:runSubCsbAction(key)
		end
	end
end

function GameUIManager:__onSubActionRemove()
	for	key, actionConfig in pairs(self._subCsbActionCfg) do
		local control = self:GetItemByName(actionConfig.NodeName)
		if control then
			control:stopAllActions()
		end
	end
end

function GameUIManager:stopSubCsbAction()
	self:__onSubActionRemove()
end

--播放界面子动作(嵌套的csb动作)
function GameUIManager:runSubCsbAction(actionKey)
	local actionConfig = self._subCsbActionCfg[actionKey]
	if not actionConfig then
		com.error("csb action(%s) no found", actionKey)
		return
	end

--##JSCodeClose##Start##--js不支持
	local fullPath = cc.FileUtils:getInstance():fullPathForFilename(actionConfig.Path)
	if not cc.FileUtils:getInstance():isFileExist(fullPath) then
		com.error("csb action file(%s) no found", actionConfig.Path)
		return
	end
--##JSCodeClose##End##--js不支持
	
	local nodeAction = cc.CSLoader:createTimeline(actionConfig.Path)
	local control = self:GetItemByName(actionConfig.NodeName)
	if control then
		control:runAction(nodeAction)
	end

	self:__initFrameEvent(nodeAction)

	if actionConfig.IsLoop == 1 then
		nodeAction:play(actionConfig.ActionName, true)
	else
		nodeAction:play(actionConfig.ActionName, false)
	end
end

----------------------------------------------------------
-- 是否播放界面打开动作
function GameUIManager:IsRunShowAction( ... )
	return true
end
-- 播放界面打开动作
function GameUIManager:OnRunShowAction( ... )
	
end


function GameUIManager:OnBaseShow( bOldShow )

	if self:IsRunShowAction() then

		-- 如果是多次打开界面,不重复播放动作
		if bOldShow and self._bNotMultiRunAction then
			com.debug("%s._bNotMultiRunAction", self)
			return
		end
		--播放默认动作，节点名字 Default，动作名字 DefaultAction
		if string.isVail(self._defaultAction) then
			self:runAction(self._defaultAction, false)
		end
		self:OnRunShowAction()
	end
end


function GameUIManager:__parseNodeChild(node)
	local childList = node:getChildren()
	for _, control in pairs(childList) do
		self:__parseNodeChild(control)
		local nodeName = control:getName()	
		if string.isVail(nodeName)then
			-- com.debug("nodeName[%s] = %s", nodeName, control)
			if self._subControlList[nodeName] then
				com.error("nodeName(%s) repeat register!", nodeName)
			else
				self._subControlList[nodeName] = self:__processRichText(nodeName, control )
			end
		end
		
	end
end

-- 处理富文本控件
function GameUIManager:__processRichText( sNodeName, pControl )
	-- 只处理文本
    if not (pControl.setString or pControl.getString) then
        return pControl
    end
    -- 检测命名
	if not string.startWith(sNodeName, "Rich_") then
		return pControl
	end


    local pRichText = UI.CreateXmlRichText(pControl)
	pControl:removeFromParent()

	return pRichText
end


--初始化
function GameUIManager:__init()
	self:__parseNodeChild(self._node)
	-- self:__initBtn()
	self:__initSize()
	--初始化界面所有子动作（编辑器编辑的动作）
	self:__initSubAction()
end

function GameUIManager:__initSubAction( ... )
	self._subCsbActionCfg = {}
	local winActionCfg = ConfigCommon:GetCustomConfig("config/window_action.txt", self._sGameConfigType)
	if not winActionCfg then
		return
	end
	for key, singleActionCfg in pairs(winActionCfg) do
		local winNameList = string.split(singleActionCfg["WindowName"], ",")
		if table.hasValue(winNameList, self.name) then
			self._subCsbActionCfg[key] = singleActionCfg
		end
	end
end




--初始化动作帧事件回调
function GameUIManager:__initFrameEvent(actionTimeline)
	if not actionTimeline then
		return
	end

	table.insert( self._lTimelineList, actionTimeline )
	g_TimeLineAndWindowtMap[actionTimeline] = self

	-- local function onFrameEvent(frame)
 --        if nil == frame then
 --            return
 --        end

 --        --动作回调
 --        local frameEventName = frame:getEvent()
        
 --        if self[frameEventName] then
 --        	self[frameEventName](self)
 --        end
 --    end

    actionTimeline:setFrameEventCallFunc( onWindowFrameEvent )
end

function onWindowFrameEvent( frame )
	if nil == frame then
        return
    end
    local pTimeline = frame:getTimeline()
    local pActionTimeline = pTimeline:getActionTimeline()

	local pSelf = g_TimeLineAndWindowtMap[pActionTimeline]
    --动作回调
    local frameEventName = frame:getEvent()
    if pSelf and pSelf[frameEventName] then
    	pSelf[frameEventName]( pSelf )
    end
end

--初始化按钮回调
function GameUIManager:RegisterButtonEvent(controlList)
	--回调处理
	local function onButtonCallFunc(control, callFunc, index, touchEvent, bNotIntervalClick)
		local tag = index or control:getTag()
		if callFunc then
			--添加点击间隔
			if not bNotIntervalClick then
				if not self._buttonTimerList[control] then
					self._buttonTimerList[control] = {}
				end
			
				if self._buttonTimerList[control][touchEvent] then
					return
				end
				self._buttonTimerList[control][touchEvent] = RegisterTimerCall(function()
						self._buttonTimerList[control][touchEvent] = nil
					end
					, Def_ButtonClickInterval)
			end
    		-- 是否过滤点击
            if self.FilterClick and self:FilterClick(tag, control) then
                com.debug("%s.FilterClick true", self)
                return
            end
            -- 按钮钩子回调
            UI.CallButtonHook(control, tag)
	    	callFunc(self, tag)
    	end
	end

	for controlName, controlInfo in pairs(controlList) do
		local control = self:GetItemByName(controlName)
		if control then
			table.insert( self._lRegisterControlList, control )
			local normal = string.format("%sCharNormal", controlName)
			local highlighted = string.format("%sCharHighlighted", controlName)
			local disabled = string.format("%sCharDisabled", controlName)
			if self:IsControlExist(normal) or self:IsControlExist(disabled) then
				if self:IsControlExist(normal) then
					self:ShowItemByName(normal)
				end

				if self:IsControlExist(disabled) then
					self:HideItemByName(disabled)
				end
				
				if self:IsControlExist(highlighted) then
					self:HideItemByName(highlighted)
				end
			end
		    local function previousCallback(sender, eventType)
				--点击触摸
			    if eventType == ccui.TouchEventType.began then
			    	self:onButtonTouchDown(controlName)
			    	onButtonCallFunc(control, controlInfo["TouchDown"], controlInfo["Index"], "TouchDown", controlInfo["NotIntervalClick"])
			     --触摸移动
			    elseif eventType == ccui.TouchEventType.moved then
			    	self:onButtonTouchMoved(controlName)
			    	if control:isHighlighted() then
			    		onButtonCallFunc(control, controlInfo["TouchMove"], controlInfo["Index"], "TouchMove", controlInfo["NotIntervalClick"])
			    	else	
			    		onButtonCallFunc(control, controlInfo["TouchCancel"], controlInfo["Index"], "TouchCancel", controlInfo["NotIntervalClick"])
			    	end
			    	
			    --触摸结束
			    elseif eventType == ccui.TouchEventType.ended then
			     	self:onButtonTouchEnd(controlName)
			    	onButtonCallFunc(control, controlInfo["TouchEnd"], controlInfo["Index"], "TouchEnd", controlInfo["NotIntervalClick"])

			    --触摸取消
			    elseif eventType == ccui.TouchEventType.canceled then
			    	self:onButtonTouchCancel(controlName)
			    	onButtonCallFunc(control, controlInfo["TouchCancel"], controlInfo["Index"], "TouchCancel", controlInfo["NotIntervalClick"])
			    end
				    
			end
			control:addTouchEventListener(previousCallback)
		end
	end
end

--检测是否繁体切换字体
function GameUIManager:__checkZhHantChangeFont( ... )
	if not GetDefineVariable(config, "EnableFixZhHantFont") then
		return
	end

	local languageType = LanguageCommon:GetCustomLanguage()
    if languageType == "ZhHant" then
        self:__changeFontName("")
    else
        self:__changeFontName(config.DefaultFont)
    end
    self:__initLabelEffect()
end

--切换字体
function GameUIManager:__changeFontName( fontName )
	if os.isWindow() then
		fontName = ""
	end
	for itemName, control in pairs(self._subControlList) do
		if not control.LockFont then
			if control.setFontName then
				control:setFontName(fontName)
			end

			if control.setTitleFontName then
				control:setTitleFontName(fontName)
			end
		end
	end
end

function GameUIManager:LockFont( sControlName, sFontName )
	local pControl = self:GetItemByName(sControlName)
	if not pControl then
		return
	end
	pControl.LockFont = sFontName
	
	if pControl.setFontName then
		pControl:setFontName(sFontName)
	end

	if pControl.setTitleFontName then
		pControl:setTitleFontName(sFontName)
	end
end
-- 对控件应用本地化处理
function GameUIManager:DoApplylocalizationToControlName( sControlName, pControl, bReverseWindowLayout )
	-- 是否需要翻转
	local bNeedReverse = false
	-- 是否文本显示类控件
	if IsTextControl(pControl) then
		bNeedReverse = true
	-- 控件固定布局
	elseif self:IsFixedLayout(sControlName) then
		bNeedReverse = true
	end

	if not bNeedReverse then
		return
	end

	-- 对文本类控件做翻转, 以便负负得正
	self:DoApplylocalizationToControl(pControl, bReverseWindowLayout)
end

-- 设置控件文本,应用多语言本地化 (bReverseWindowLayout 当前语言是否需求界面布局反转)
function GameUIManager:OnApplylocalization(bReverseWindowLayout)
	self._dLabelControlStrDict = {}
	self._dEditControlPlaceStrDict = {}
	self._dControlStrDict = {}

	for itemName, control in pairs(self._subControlList) do
		-- 对控件应用本地化处理
		self:DoApplylocalizationToControlName(itemName, control, bReverseWindowLayout)
		-- 自动适配控件字体大小
		self:__autoAdaptFontSizeScale( itemName, control, self._sLastLanguageType )

		--label
		local str = nil
		if IsLabelControl(control) then
			-- local str = control:getString()
			str = control:getString()
			if str ~= "" then
				self:setLabelValue(itemName, str)
				-- self._dLabelControlStrDict[itemName] = str

			end

			-- 编辑框
			if control.setPlaceHolder and control.getPlaceHolder then
				-- local str = control:getPlaceHolder()
				str = control:getPlaceHolder()
				if str ~= "" then
					self:setPlaceHolder(itemName, str)
					-- self._dEditControlPlaceStrDict[itemName] = str
				end
			end

		-- 富文本
		elseif IsRichTextControl(control) then
			str = self:GetRichText(itemName)
			self:SetRichText(itemName, str)

		--button
		elseif IsButtonControl(control) then
			-- local str = control:getTitleText()
			str = control:getTitleText()
			if str ~= "" then
				self:setButtonLabelValue(itemName, str)
				-- self._dLabelControlStrDict[itemName] = str
			end
		end	
		self:__saveControlLanguageData(itemName, str)
	end
end

-- 重置界面本地化处理 (bReverseWindowLayout 当前语言是否需求界面布局反转)
function GameUIManager:OnResetApplylocalization( bReverseWindowLayout )
	-- if not GetDefineVariable(config, "EnableReApplylocalization") then
	-- 	return
	-- end

	
	for itemName, vlaue in pairs(self._dControlStrDict) do

		local control = self:GetItemByName(itemName)
		-- 对控件应用本地化处理
		self:DoApplylocalizationToControlName(itemName, control, bReverseWindowLayout)
		-- 自动适配控件字体大小
		self:__autoAdaptFontSizeScale( itemName, control, self._sLastLanguageType )

		if IsLabelControl(control) then
			if control.setPlaceHolder and control.getPlaceHolder then
				if vlaue["str"] then
					self:setPlaceHolder(itemName, vlaue["str"])
				end
			end
			self:setLabelValue(itemName, vlaue["str"], unpack(vlaue["other"]))

		-- 富文本
		elseif IsRichTextControl(control) then
			str = self:GetRichText(itemName)
			self:SetRichText(itemName, str)

		--button
		elseif IsButtonControl(control) then
			self:setButtonLabelValue(itemName, vlaue["str"])
		end	
	end

	-- for itemName, str in pairs(self._dLabelControlStrDict) do
	-- 	local control = self:GetItemByName(itemName)
	-- 	if control.setString and control.getString then
	-- 		if control.setPlaceHolder and control.getPlaceHolder then
	-- 			local placeStr = self._dEditControlPlaceStrDict[itemName]
	-- 			if placeStr then
	-- 				self:setPlaceHolder(itemName, placeStr)
	-- 			end
	-- 		end
	-- 		self:setLabelValue(itemName, str)
	-- 	end
	-- 	--button
	-- 	if control.setTitleText and control.getTitleText then
	-- 		self:setButtonLabelValue(itemName, str)
	-- 	end	
	-- end
end

function GameUIManager:__initSize()
	 self._controlSizeDict = {}
	 for itemName, control in pairs(self._subControlList) do
	 	if control.getContentSize then
	 		local width = control:getContentSize().width * control:getScaleX()
	 		local height = control:getContentSize().height * control:getScaleY()
	 		self._controlSizeDict[itemName] = cc.size(width, height)
	 	end
	 end
end

-- 注册自定义控件到界面管理器
function GameUIManager:RegisterItemByName( itemName, control )
	self._subControlList[itemName] = control

 	if control.getContentSize then
 		local width = control:getContentSize().width * control:getScaleX()
 		local height = control:getContentSize().height * control:getScaleY()
 		self._controlSizeDict[itemName] = cc.size(width, height)
 	end
end

----------------------------------------------------------
function GameUIManager:GetControlOriginalSize(itemName)
	return self._controlSizeDict[itemName]
end
----------------------------------------------------------

function GameUIManager:getActionManager()
	
end

---------------------------------------------------------------------------------------
--控件停止动作
function GameUIManager:stopAllAction()
	if self._node then
		self._node:stopAllActions()
		self._baseNodeAction = nil
	end
end

--播放动作(没有动作名则播放默认的)
function GameUIManager:runAction(actionName, bLoop)
	if not self._baseNodeAction then
        self:__onBaseActionInit()
    end 

	if actionName then
		self._baseNodeAction:play( actionName, bLoop )
	else
		self._baseNodeAction:gotoFrameAndPlay(0, bLoop)
	end

end
-- 动作是否存在
function GameUIManager:IsAnimationExist( sActionName )
	if not self._baseNodeAction then
        self:__onBaseActionInit()
    end 
    if not sActionName then
    	return false
    end
    local bHasAction = self._baseNodeAction:IsAnimationInfoExists(sActionName)
    return bHasAction
end

--根据帧播放动作（从某帧到某帧）
function GameUIManager:runActionByFrame(startIndex, endIndex, bLoop)
	if self._baseNodeAction then
		self._baseNodeAction:gotoFrameAndPlay(startIndex, endIndex, bLoop)
	end
end

--动作暂停
function GameUIManager:PauseAction()
	if self._baseNodeAction then
		self._baseNodeAction:pause()
	end
end

--动作恢复
function GameUIManager:ResumeAction()
	if self._baseNodeAction then
		self._baseNodeAction:resume()
	end
end

-- 恢复动作节点
function GameUIManager:ResumeWindowAction( ... )
	if self._node then
		cc.Director:getInstance():getActionManager():resumeTarget(self._node)
	end
end

--是否动作播放中
function GameUIManager:isActionPlaying()
	return self._baseNodeAction:isPlaying()
end


-- 暂停控件动作
function GameUIManager:PauseControlAction( controlName )
	local control = self:GetItemByName(controlName)
	if control then
		control:pause()
	end
end

-- 恢复控件动作
function GameUIManager:ResumeControlAction( controlName )
	local control = self:GetItemByName(controlName)
	if control then
		control:resume()
	end
end


-----------------------------------------------------------------------------
--控件停止粒子动画
function GameUIManager:stopParticle(controlName)
	local control = self:GetItemByName(controlName)
	if control then
		if control.stopSystem then
			control:stopSystem()
		end
	end
end


--控件播放粒子动画
function GameUIManager:startParticle(controlName)
	local control = self:GetItemByName(controlName)
	if control then
		if control.resetSystem then
			control:resetSystem()
		end
	end
end


----------------------------------------------------------------------------

--控件是否显示
function GameUIManager:IsItemShow(controlName)
	local item = self:GetItemByName(controlName)
	if item then
		return item:isVisible()
	end
	return false
end


--显示控件
--controlName 控件名字
function GameUIManager:ShowItemByName(controlName)
	local item = self:GetItemByName(controlName)
	if self:IsItemShow(controlName) then
		return
	end
	if item then
		item:setVisible(true)
	end
end

--隐藏控件
--controlName 控件名字
function GameUIManager:HideItemByName(controlName)
	local item = self:GetItemByName(controlName)
	if not self:IsItemShow(controlName) then
		return
	end
	if item then
		item:setVisible(false)
	end
end


--获取控件
function GameUIManager:GetItemByName(controlName)
	if not self._subControlList[controlName] then
		com.error("window(%s) control name(%s)no found", self.name, controlName)
		return nil
	end
	return self._subControlList[controlName]
end
-- 兼容旧版(禁止再使用了)
function GameUIManager:getItemByName( controlName )
	return self:GetItemByName(controlName)
end

--控件是否存在
function GameUIManager:IsControlExist(controlName)
	if self._subControlList[controlName] then
		return true
	end
	return false
end

-- 获取坐标
function GameUIManager:GetPosition(controlName)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	return control:getPosition()
end
-- 设置坐标
function GameUIManager:SetPosition(controlName, posX, posY)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:setPosition(posX, posY)
end
-- 设置坐标X
function GameUIManager:SetPositionX(controlName, posX)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:setPositionX(posX)
end
-- 设置坐标Y
function GameUIManager:SetPositionY(controlName, posY)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:setPositionY(posY)
end


--设置按钮图片
function GameUIManager:setButtonImage(controlName, normal, selected, disabled, imgType)
	imgType = imgType or ccui.TextureResType.localType
	local btnControl = self:GetItemByName(controlName)
	local normalImg = ImageCommon:getImageFileNameByName(normal)
	local selectedImg = ImageCommon:getImageFileNameByName(selected)
	local disabledImg = ImageCommon:getImageFileNameByName(disabled)
	if btnControl then
		btnControl:loadTextures(normalImg, selectedImg, disabledImg, imgType)
	end
end

--设置按钮正常状态图片
function GameUIManager:setButtonNormalImage(controlName, normal, imgType)
	imgType = imgType or ccui.TextureResType.localType
	local btnControl = self:GetItemByName(controlName)
	local normalImg = ImageCommon:getImageFileNameByName(normal)
	if btnControl then
		btnControl:loadTextureNormal(selectedImg, imgType)
	end
end

--设置按钮点击状态图片
function GameUIManager:setButtonPressedImage(controlName, selected, imgType)
	imgType = imgType or ccui.TextureResType.localType
	local btnControl = self:GetItemByName(controlName)
	local selectedImg = ImageCommon:getImageFileNameByName(selected)
	if btnControl then
		btnControl:loadTexturePressed(selectedImg, imgType)
	end
end

--设置按钮不可点击状态图片
function GameUIManager:setButtonDisabledImage(controlName, disabled, imgType)
	imgType = imgType or ccui.TextureResType.localType
	local btnControl = self:GetItemByName(controlName)
	local disabledImg = ImageCommon:getImageFileNameByName(disabled)
	if btnControl then
		btnControl:loadTextureDisabled(disabledImg, imgType)
	end
end



-- 设置按钮颜色
function GameUIManager:setButtonLabelColor( labelName, color )
	local btnControl = self:GetItemByName(labelName)
	if btnControl then
		btnControl:setTitleColor(color)
    end
end

-- 获取按钮颜色
function GameUIManager:getButtonLabelColor( controlName )
	local btnControl = self:GetItemByName(controlName)
	if btnControl then
		return btnControl:getTitleColor()
    end
    return nil
end

-- 设置按钮文本
function GameUIManager:setButtonLabelValue( controlName, value, ... )
	local btnControl = self:GetItemByName(controlName)
	if btnControl then
		value, _ = LanguageCommon:GetString(tostring(value), ...)
		btnControl:setTitleText(value)
    end
end

--获取按钮文本
function GameUIManager:getButtonLabelValue(controlName)
	local btnControl = self:GetItemByName(controlName)
	if btnControl then
		return btnControl:getTitleText()
    end
    return nil
end

--设置按钮选中
function GameUIManager:setButtonSelectedState(controlName, isSelect)
	local btnControl = self:GetItemByName(controlName)
	if btnControl then
		btnControl:setBright(isSelect)
		local normal = string.format("%sCharNormal", controlName)
		local highlighted = string.format("%sCharHighlighted", controlName)
		local disabled = string.format("%sCharDisabled", controlName)
		if isSelect then
			if self:IsControlExist(normal) or self:IsControlExist(disabled) then
				if self:IsControlExist(normal) then
					self:HideItemByName(normal)
				end

				if self:IsControlExist(disabled) then
					self:HideItemByName(disabled)
				end

				if self:IsControlExist(highlighted) then
					self:ShowItemByName(highlighted)
				else
					if self:IsControlExist(disabled) then
						self:ShowItemByName(disabled)
					end	
				end
			end
		else
			if self:IsControlExist(normal) or self:IsControlExist(disabled) then

				if self:IsControlExist(normal) then
					self:ShowItemByName(normal)
				end

				if self:IsControlExist(disabled) then
					self:HideItemByName(disabled)
				end

				if self:IsControlExist(highlighted) then
					self:HideItemByName(highlighted)
				end
			end
		end
    end
end

function GameUIManager:setButtonEnabledState(controlName, isEnable)
	self:setButtonDisabledState(controlName, isEnable)
end

--设置按钮不可用
function GameUIManager:setButtonDisabledState(controlName, isEnable)
	local btnControl = self:GetItemByName(controlName)
	if btnControl then
		btnControl:setBright(isEnable)
		btnControl:setEnabled(isEnable)
		local normal = string.format("%sCharNormal", controlName)
		local highlighted = string.format("%sCharHighlighted", controlName)
		local disabled = string.format("%sCharDisabled", controlName)
		if isEnable then
			if self:IsControlExist(normal) or self:IsControlExist(disabled) then
				if self:IsControlExist(normal) then
					self:ShowItemByName(normal)
				end

				if self:IsControlExist(disabled) then
					self:HideItemByName(disabled)
				end
				
				
				if self:IsControlExist(highlighted) then
					self:HideItemByName(highlighted)				
				end
			end
		else
			if self:IsControlExist(normal) or self:IsControlExist(disabled) then

				if self:IsControlExist(normal) then
					self:HideItemByName(normal)
				end

				if self:IsControlExist(disabled) then
					self:ShowItemByName(disabled)
				end

				if self:IsControlExist(highlighted) then
					self:HideItemByName(highlighted)				
				end
			end
		end
    end
end


function GameUIManager:onButtonTouchDown( controlName )
	local normal = string.format("%sCharNormal", controlName)
	local highlighted = string.format("%sCharHighlighted", controlName)
	local disabled = string.format("%sCharDisabled", controlName)
	if self:IsControlExist(normal) or self:IsControlExist(disabled) then

		if self:IsControlExist(normal) then
			self:HideItemByName(normal)
		end

		if self:IsControlExist(disabled) then
			self:HideItemByName(disabled)
		end

		if self:IsControlExist(highlighted) then
			self:ShowItemByName(highlighted)
		else
			if self:IsControlExist(disabled) then
				self:ShowItemByName(disabled)
			end
		end
	end
end

function GameUIManager:onButtonTouchMoved(controlName)
	local btnControl = self:GetItemByName(controlName)
	if not btnControl then
		return
	end
	local normal = string.format("%sCharNormal", controlName)
	local highlighted = string.format("%sCharHighlighted", controlName)
	local disabled = string.format("%sCharDisabled", controlName)
	if self:IsControlExist(normal) or self:IsControlExist(disabled) then
		if btnControl:isHighlighted() then

			if self:IsControlExist(normal) then
				self:HideItemByName(normal)
			end

			if self:IsControlExist(disabled) then
				self:HideItemByName(disabled)
			end

			if self:IsControlExist(highlighted) then
				self:ShowItemByName(highlighted)
			else
				if self:IsControlExist(disabled) then
					self:ShowItemByName(disabled)
				end
			end
		else
			if self:IsControlExist(normal) then
				self:ShowItemByName(normal)
			end

			if self:IsControlExist(disabled) then
				self:HideItemByName(disabled)
			end

			if self:IsControlExist(highlighted) then
				self:HideItemByName(highlighted)				
			end
		end
	end
end

function GameUIManager:onButtonTouchEnd(controlName)
	local normal = string.format("%sCharNormal", controlName)
	local highlighted = string.format("%sCharHighlighted", controlName)
	local disabled = string.format("%sCharDisabled", controlName)
	if self:IsControlExist(normal) or self:IsControlExist(disabled) then

		if self:IsControlExist(normal) then
			self:ShowItemByName(normal)
		end

		if self:IsControlExist(disabled) then
			self:HideItemByName(disabled)
		end

		if self:IsControlExist(highlighted) then
			self:HideItemByName(highlighted)
		end
	end
end


function GameUIManager:onButtonTouchCancel( controlName )
	local normal = string.format("%sCharNormal", controlName)
	local highlighted = string.format("%sCharHighlighted", controlName)
	local disabled = string.format("%sCharDisabled", controlName)
	if self:IsControlExist(normal) or self:IsControlExist(disabled) then
		if self:IsControlExist(normal) then
			self:ShowItemByName(normal)
		end

		if self:IsControlExist(disabled) then
			self:HideItemByName(disabled)
		end
		if self:IsControlExist(highlighted) then
			self:HideItemByName(highlighted)
		end
	end
end

function GameUIManager:setPlaceHolder( sControlName, vValue )
	local pEditControl = self:GetItemByName(sControlName )
	if nil ~= pEditControl then
		local sValueStr, _ = LanguageCommon:GetString( tostring(vValue) )
		pEditControl:setPlaceHolder( sValueStr )
    end
end
--------------------------------------
function GameUIManager:__initCsbInfo( ... )
	self._sCsbName = ""

	local sPath = self._config.Path
	sPath = string.rstrip(sPath, ".csb")

	local lPathList = string.split(sPath, "/") 
	self._sCsbName = lPathList[#lPathList]
end
--------------------------------------
-- 初始化控件布局
function GameUIManager:__initControlLayout( ... )
	-- 固定布局的控件字典
	self._dFixedControlDict = {}
	-- 是否整个界面固定不翻转
	self._bFixedWindow = false

	self:__initControlLanguageLayout()

	
	if not ConfigCommon:IsExistConfig("config/window_control_layout.txt", self._sGameConfigType) then
		return
	end

	local dControlConfig = ConfigCommon:getDataByField("config/window_control_layout.txt", "WindowCsbName", self._sCsbName, self._sGameConfigType)
	if not dControlConfig then
		return
	end

	for _, dControlInfo in pairs(dControlConfig) do
		-- 是否固定布局，不随语言翻转界面
		if isVailNumber(dControlInfo["IsFixedLayout"]) then
			local sControlName = dControlInfo["ControlName"]
			if sControlName == self._sCsbName then
				-- 是否整个界面固定不翻转
				self._bFixedWindow = true
			else
				self._dFixedControlDict[sControlName] = true
			end
		end
	end
end

-- 控件是否固定布局，不随语言翻转界面
function GameUIManager:IsFixedLayout( sControlName )
	if not self._dFixedControlDict then
		return false
	end
	return self._dFixedControlDict[sControlName] or false
end
--------------------------------------

-- 初始化界面字体大小本地化适配
function GameUIManager:__initControlLanguageLayout( ... )
	-- 字体缩放 多语言适配信息
	self._dControlLangScaleDict = {}

	if not ConfigCommon:IsExistConfig("config/window_language_layout.txt", self._sGameConfigType) then
		return
	end

	local dControlConfig = ConfigCommon:getDataByField("config/window_language_layout.txt", "WindowCsbName", self._sCsbName, self._sGameConfigType)
	if not dControlConfig then
		return
	end


	for _, dControlInfo in pairs(dControlConfig) do
		local sControlName = dControlInfo["ControlName"]
		self._dControlLangScaleDict[sControlName] = dControlInfo
	end

end

-- 获取指定控件的多语言字体缩放适配信息
function GameUIManager:__getFontSizeScaleByLanguage( sControlName, sCurLanguageType )
	local dControlInfo = self._dControlLangScaleDict[sControlName]
	if not dControlInfo then
		return false, nil
	end

	local sFiledName = string.format("FontSizeScale_%s", sCurLanguageType)
	local fFontSizeScale = dControlInfo[sFiledName]
	if not fFontSizeScale or fFontSizeScale <= 0 then
		fFontSizeScale = 1
	end

	return true, fFontSizeScale
end

-- 自动适配控件字体大小
function GameUIManager:__autoAdaptFontSizeScale( sControlName, pControl, sCurLanguageType )
	local bNeedChange, fFontSizeScale = self:__getFontSizeScaleByLanguage(sControlName, sCurLanguageType)
	if not bNeedChange then
		return
	end

	if not (pControl.setFontSize or pControl.setTitleFontSize) then
		com.error("__autoAdaptFontSizeScale[%s, %s, %s] no supp setFontSize", sControlName, pControl, sCurLanguageType)
		return
	end

	if not pControl.OrgFontSize then
		if pControl.getFontSize then
			pControl.OrgFontSize = pControl:getFontSize()
		else
			pControl.OrgFontSize = pControl:getTitleFontSize()
		end
	end
	local fLastFontSize = pControl.OrgFontSize * fFontSizeScale

	if pControl.getFontSize then
		pControl:setFontSize(fLastFontSize)
	else
		pControl:setTitleFontSize(fLastFontSize)
	end
end

--------------------------------------
--初始化文本特效
function GameUIManager:__initLabelEffect()

	-- 应用安卓缩放比例
	local bUseAndroidScale = os.isAndroid()

	local charConfig = ConfigCommon:getDataByField("config/window_char_effect.txt", "WindowCsbName", self._sCsbName, self._sGameConfigType)
	if not charConfig then
		return
	end
	for _, charInfo in pairs(charConfig) do
		
		-- 应用安卓缩放比例
		if bUseAndroidScale then
			local pLabel = self:GetItemByName(charInfo["ControlName"])
			if pLabel then
				local fLabelScale = charInfo["AndroidScale"] or 0
				if fLabelScale > 0 then
					pLabel:setScale(fLabelScale)
				end
			end
		end

		if table.isNotEmpty(charInfo["ShadowColorList"]) then
			if table.getCount(charInfo["ShadowColorList"]) == 4 then
				local color = cc.c4b(unpack(charInfo["ShadowColorList"]))
				local dir = charInfo["ShadowDir"] or 1
				local size = cc.size(dir * charInfo["ShadowSize"]/2, - dir * charInfo["ShadowSize"]/2)
				self:SetLabelEnableShadow(charInfo["ControlName"], color, size)
			else
				com.error("控件（%s）阴影配置异常", charInfo["ControlName"])
			end
		end
		if table.isNotEmpty(charInfo["OutlineColorList"]) then
			if table.getCount(charInfo["OutlineColorList"]) == 4 then
				local color = cc.c4b(unpack(charInfo["OutlineColorList"]))
				local size = charInfo["OutlineSize"]
				self:SetLabelEnableOutline(charInfo["ControlName"], color, size)
			else
				com.error("控件（%s）描边配置异常", charInfo["ControlName"])
			end
		end
		if table.isNotEmpty(charInfo["GlowColorList"]) then
			if table.getCount(charInfo["GlowColorList"]) == 4 then
				local color = cc.c4b(unpack(charInfo["GlowColorList"]))
				self:SetEnableGlow(charInfo["ControlName"], color)
			else
				com.error("控件（%s）外发光配置异常", charInfo["ControlName"])
			end
		end
	end
end


--设置文本外发光
function GameUIManager:SetEnableGlow(labelName, color4B)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:enableGlow(color4B)
    end
end

--设置文本阴影
function GameUIManager:SetLabelEnableShadow(labelName, color4B, size, blurRadius)
	blurRadius = blurRadius or 0
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:enableShadow(color4B, size, blurRadius)
    end
end

--设置文本描边（只能在ios和安卓生效）
function GameUIManager:SetLabelEnableOutline(labelName, color4B, outlineSize)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:enableOutline(color4B, outlineSize)
    end
end

-- 设置富文本控件内容
function GameUIManager:SetRichText(sLabelName, sText, ... )
	local pRichText = self:GetItemByName(sLabelName)
	if nil ~= pRichText then
		UI.SetXmlRichText(pRichText, sText, ...)
    end
end
-- 获取富文本内容
function GameUIManager:GetRichText(sLabelName)
	local pRichText = self:GetItemByName(sLabelName)
	if not pRichText then
		return nil
	end
	return UI.GetXmlRichText(pRichText)
end

--设置值
function GameUIManager:setLabelValue(labelName, value, ...)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
		value, _ = LanguageCommon:GetString(tostring(value), ...)
        label:setString(value or "")
    end
end
function GameUIManager:SetLabelValue( ... )
	self:__saveControlLanguageData( ... )
	return self:setLabelValue(...)
end

function GameUIManager:GetLabelValue( ... )
	return self:getLabelValue(...)
end
--获取值
function GameUIManager:getLabelValue(labelName)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        return label:getString()
    end
    return nil
end

--设置字体大小
function GameUIManager:setFontSize( labelName, fontSize )
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:setFontSize(fontSize)
    end
end

--设置文本框字体
function GameUIManager:SetTextFontFile( labelName, fileName )
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:setFontName(fileName)
    end
end


--设置自定义字体
function GameUIManager:SetBMFontFile( labelName, fileName )
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:setFntFile(fileName)
    end
end

--设置图片字体属性
function GameUIManager:SetAtlasProperty(labelName, stringValue, charMapFile, itemWidth, itemHeight, startCharMap)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:setProperty(stringValue, charMapFile, itemWidth, itemHeight, startCharMap)
    end
end


--获取颜色
function GameUIManager:GetControlColor(labelName)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        return label:getColor()
    end
    return nil
end
--设置颜色
function GameUIManager:SetControlColor(labelName, colorR, colorG, colorB, bNeedSetSubControl)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:setColor(cc.c3b(colorR, colorG, colorB))

        -- 需要对子节点生效
        if bNeedSetSubControl then
        	label:setCascadeColorEnabled(true)
        end
    end
end
--设置颜色
function GameUIManager:SetControlColor3(labelName, color, bNeedSetSubControl)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:setColor(color)

        -- 需要对子节点生效
        if bNeedSetSubControl then
        	label:setCascadeColorEnabled(true)
        end
    end
end


-- 获取控件类型
function GameUIManager:GetNodeTypeName(controlName)

end

-- 设置控件图片
function GameUIManager:SetControlImage(controlName, imageName, isThumb)
    local cardBtnSize = self:GetControlOriginalSize(controlName)
	local cardBtn = self:GetItemByName(controlName)
	if cardBtn then

   		UI.SetControlImage(cardBtn, cardBtnSize, imageName, isThumb)
	end
end

-- 设置控件图片,不缩放
function GameUIManager:SetControlImageNoScale(controlName, imageName, isThumb)
	local cardBtn = self:GetItemByName(controlName)
	if cardBtn then

		-- com.debug("GetNodeTypeName = ", self:GetNodeTypeName(controlName))
		-- com.debug("controlName = ", controlName)
   		UI.SetControlImage(cardBtn, nil, imageName, isThumb)
	end
end

-----------------------------
--复选框注册回调
function GameUIManager:CheckBoxRegisterEvent(controlName, selectCallFunc, unSelectCallFunc, selectArg, unSelectArg)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	
	local function callBack(sender, eventType)
		com.debug("eventType = ", eventType)
		if eventType == ccui.CheckBoxEventType.selected then
			if selectCallFunc then
				selectArg = selectArg or {}
				selectCallFunc(self, unpack(selectArg))
			else
				com.error("复选框选中回调函数（%s）不存在！")
			end
		elseif eventType == ccui.CheckBoxEventType.unselected then
			if unSelectCallFunc then
				unSelectArg = unSelectArg or {}
				unSelectCallFunc(self, unpack(unSelectArg))
			else
				com.error("复选框取消回调函数（%s）不存在！")
			end
		end
	end
	table.insert( self._lRegisterControlList, control )
	control:addEventListener(callBack)
end

--获取复选框状态
function GameUIManager:GetCheckBoxSelectState(controlName)
	local control = self:GetItemByName(controlName)
	if not control then
		return nil
	end
	return control:isSelected()
end

--设置复选框状态
function GameUIManager:SetCheckBoxSelectState(controlName, isSelect)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:setSelected(isSelect)
end

---------------------------------------------------
--设置加载进度条或滑动条比率值
function GameUIManager:SetPercent(controlName, percent)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:setPercent(percent)
end

--获取加载进度条或滑动条比率值
function GameUIManager:GetPercent(controlName)
	local control = self:GetItemByName(controlName)
	if not control then
		return nil
	end
	return control:getPercent()
end

----------------------------------------------------
--滑动条注册滑动回调
function GameUIManager:SliderRegisterCallFunc(controlName, callFuncName)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	

	local function callBack(sender, eventType)
		com.debug("eventType = ", eventType)
		if eventType == ccui.ScrollviewEventType.percentChanged then
			if string.isVail(callFuncName) and self[callFuncName] then
				self[callFuncName](self)
			else
				com.error("滑动条滑动回调函数（%s）不存在！")
			end
		end
	end
	table.insert( self._lRegisterControlList, control )
	control:addEventListener(callBack)
end


------------------------------------------------------
--滚动层注册事件
function GameUIManager:ScrollRegisterEvent(controlName, onScrollToTop, onScrollToBottom, onScrollToLeft, onScrollToRight,
											onScrolling, onBounceTop, onBounceBottom, onBounceLeft, onBounceRight)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	-- local container = control:getInnerContainer()
	-- local _,posy = container:getPosition()
	local function callBack(sender, eventType)
		com.debug("eventType = ", eventType)
		if eventType == ccui.ScrollviewEventType.scrollToTop then
			-- com.debug("----scrollToTop----")
			if string.isVail(onScrollToTop) and self[onScrollToTop] then
				self[onScrollToTop](self)
			end
		elseif eventType == ccui.ScrollviewEventType.scrollToBottom then
			-- com.debug("----scrollToBottom----")
			if string.isVail(onScrollToBottom) and self[onScrollToBottom] then
				self[onScrollToBottom](self)
			end
		elseif eventType == ccui.ScrollviewEventType.scrollToLeft then
			com.debug("----scrollToLeft----")
			if string.isVail(onScrollToLeft) and self[onScrollToLeft] then
				self[onScrollToLeft](self)
			end
		elseif eventType == ccui.ScrollviewEventType.scrollToRight then
			com.debug("----scrollToRight----")
			if string.isVail(onScrollToRight) and self[onScrollToRight] then
				self[onScrollToRight](self)
			end
		elseif eventType == ccui.ScrollviewEventType.scrolling then
			if string.isVail(onScrolling) and self[onScrolling] then
				self[onScrolling](self)
			end
		elseif eventType == ccui.ScrollviewEventType.bounceTop then
			-- com.debug("----bounceTop----")
			if string.isVail(onBounceTop) and self[onBounceTop] then
				self[onBounceTop](self)
			end
		elseif eventType == ccui.ScrollviewEventType.bounceBottom then
			-- com.debug("----bounceBottom----")
			if string.isVail(onBounceBottom) and self[onBounceBottom] then
				self[onBounceBottom](self)
			end
		elseif eventType == ccui.ScrollviewEventType.bounceLeft then
			com.debug("----bounceLeft----")
			if string.isVail(onBounceLeft) and self[onBounceLeft] then
				self[onBounceLeft](self)
			end
		elseif eventType == ccui.ScrollviewEventType.bounceRight then
			com.debug("----bounceRight----")
			if string.isVail(onBounceRight) and self[onBounceRight] then
				self[onBounceRight](self)
			end
		end
	end
	table.insert( self._lRegisterControlList, control )
	control:addEventListener(callBack)
end


--滚动层绑定滑动条
function GameUIManager:ScrollBindSlider(scrollControlName, sliderControlName)
	local scroll = self:GetItemByName(scrollControlName)
	if not scroll then
		return
	end

end

--滚动层清除所有子控件
function GameUIManager:ScrollRemoveAllChild( scrollControlName )
	local scroll = self:GetItemByName(scrollControlName)
	if not scroll then
		return
	end
	scroll:removeAllChildren()
end


-------------------------------------------------
--分页滚动层注册事件
function GameUIManager:PageScrollRegisterEvent(controlName, onScrollTurning)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	local function callBack(sender, eventType)
		com.debug("eventType = ", eventType)
		if eventType == ccui.PageViewEventType.turning then
			if string.isVail(onScrollTurning) and self[onScrollTurning] then
				self[onScrollTurning](self)
			end
		end
	end
	table.insert( self._lRegisterControlList, control )
	control:addEventListener(callBack)
end


--分页滚动层所有的层对象都是Layout对象 page = ccui.Layout:create()
--增加分页
function GameUIManager:AddPage(controlName, page)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:addPage(page)
end

--获取当前页码
function GameUIManager:GetCurPageIndex(controlName)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	return control:getCurPageIndex()
end

--滚动到指定页
function  GameUIManager:ScrollToPage(controlName, pageIndex)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:scrollToPage(pageIndex)
end

--插入分页
function GameUIManager:InsertPage(controlName, page, idx)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:insertPage(page, idx)
end

--删除指定索引分页
function GameUIManager:RemovePage(controlName, page)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:removePage(page)
end

--删除指定索引分页
function GameUIManager:RemovePageAtIndex(controlName, idx)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:removePageAtIndex(idx)
end

--清除所有分页
function GameUIManager:RemoveAllPages(controlName)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:removeAllPages()
end

--保存控件，支持多语言
function GameUIManager:__saveControlLanguageData( itemName, str, ... )
	local otherList = pack(...)
	self._dControlStrDict[itemName] = {["str"] = str, ["other"] = otherList}
end

-----------------------------------------------------------
-- CCB界面管理器
CCBWindow = class(GameUIManager)
-----------------------------------------------------------



function CCBWindow:OnCreateWindow( ... )

	self._proxy = cc.CCBProxy:create()
	Lua_Retain(self._proxy) 
	local pNode, dItemDict, pAnimationManager = CCBReaderLoad(self._config.Path, self._proxy, self)
	if not pNode then
		com.fail("window[%s]ccb(%s)load fail", self.name, self._config.Path)
		return
	end
	self.layer = tolua.cast(pNode,"cc.Layer")
	-- com.debug("%s.pNode(%s) layer(%s)", self, pNode, self.layer)
	Lua_Retain(self.layer) 

	--图层中的Label列表
	self._subControlList = dItemDict
	self._dLockFontDict = {}
	self._pAnimationManager = pAnimationManager

	function eventFunc(eventType)
		if eventType == "enter" then 
			self:OnBaseEnter()
		elseif eventType == "exit" then      
			self:OnExit()  
		else
			-- com.warn("Unknow EventType = %s", eventType)
		end 
	end
	self.layer:registerScriptHandler(eventFunc)

	self._operLock = false

	self:__init()

end

function CCBWindow:OnBaseDestroy( bNowRelease, bNotNowClearTexture )

	local lastLayer = self.layer
	if lastLayer then
		lastLayer:removeFromParent(true)
	end
	local lastProxy = self._proxy
	if lastProxy then
		lastProxy:removeFromParent(true)
	end
	
	if bNowRelease then
		com.debug("CCBWindow Destroy(%s)", self)
		if lastLayer then
			Lua_Release(lastLayer)
			lastLayer = nil
		end
		if lastProxy then
			Lua_Release(lastProxy)
			lastProxy = nil
		end
		--清除内存
		if not bNotNowClearTexture then
			ImageCommon:RemoveUnusedTextures()
		end
		
		DumpNodeInfo(lastLayer)
		return
	end

	RegisterTimerCall(function( ... )	
		com.debug("CCBWindow wait Destroy(%s)", self)
		if lastLayer then
			Lua_Release(lastLayer)
			lastLayer = nil
		end
		if lastProxy then
			Lua_Release(lastProxy)
			lastProxy = nil
		end

		--清除内存
		if not bNotNowClearTexture then
			ImageCommon:RemoveUnusedTextures()
		end

		DumpNodeInfo(lastLayer)

	end, 0)
end
-----------------------------------------------------------


--初始化
function CCBWindow:__init()

	self:__initSize()

end

function CCBWindow:stopAllAction(  )
	if self.layer then
		self.layer:stopAllActions()
	end
end

function CCBWindow:runAction(actionName)
	if self._pAnimationManager then
		local action = actionName or self._defaultAction
		-- 没有action这个动作时会程序会崩掉
		if string.isVail(action) then
	        -- self._pAnimationManager:runAnimationsForSequenceNamedTweenDuration(action, 0)      
	        local iActionSeqID = self._pAnimationManager:getSequenceId(action)      
	        if iActionSeqID ~= cc.ACTION_TAG_INVALID then
	        	self._pAnimationManager:runAnimationsForSequenceIdTweenDuration(iActionSeqID, 0)
	        else
	        	com.error("%s.runAction[%s] error, no found action", self, actionName)
	        end
		end
    end
end

--动作暂停
function CCBWindow:PauseAction()

end

--动作恢复
function CCBWindow:ResumeAction()

end
-- 恢复动作节点
function CCBWindow:ResumeWindowAction(  )

end

--是否动作播放中
function CCBWindow:isActionPlaying()
	return false
end


--界面主动作初始化
function CCBWindow:__onBaseActionInit( ... )
end

--界面主动作清除
function CCBWindow:__onBaseActionRemove()
end


--界面子动作初始化
function CCBWindow:__onSubActionInit()
end

function CCBWindow:__onSubActionRemove()
end

function CCBWindow:stopSubCsbAction()
end

function CCBWindow:RegisterButtonEvent( ... )
	-- body
end

--播放界面子动作(嵌套的csb动作)
function CCBWindow:runSubCsbAction(actionKey)
	self:runAction(actionKey)
end

-- 设置按钮文本
function CCBWindow:setButtonLabelValue( controlName, value, controlState )
    local label = self:GetItemByName(controlName)
	if nil ~= label then
		local valueStr, _ = LanguageCommon:GetString(tostring(value))
		--local valueStr = cc.String:create(value)
		if controlState then
			label:setTitleForState(valueStr, controlState)
		else
	        label:setTitleForState(valueStr, cc.CONTROL_STATE_NORMAL)
	        label:setTitleForState(valueStr, cc.CONTROL_STATE_HIGH_LIGHTED)
	        label:setTitleForState(valueStr, cc.CONTROL_STATE_DISABLED)
	        label:setTitleForState(valueStr, cc.CONTROL_STATE_SELECTED)
	    end
    end
end

---------------------------------------------------------------------------------------------

-- 读取扩展配置
function AddCustomConfig( sGameConfigType )
	local dAllWinInfo = InitAllWindow(nil, sGameConfigType)

	g_dCustomWindowInfoDict[sGameConfigType] = dAllWinInfo
end
-- 删除扩展配置
function DelCustomConfig( sGameConfigType )
	local dAllWinInfo = g_dCustomWindowInfoDict[sGameConfigType]
	if dAllWinInfo then
		for sWinName, dWinInfo in pairs(dAllWinInfo) do
			-- 如果没有代码文件
			if string.isEmpty(dWinInfo.CodePath) then
				_G[dWinInfo.CustomClassName] = nil
			else
				package.loaded[dWinInfo.CodePath] = nil
			end

			if dWinInfo.WindowObj then
				dWinInfo.WindowObj:Destroy()
				delWinCache(dWinInfo.WindowObj)
			end
		end
	end
	g_dCustomWindowInfoDict[sGameConfigType] = nil
end
---------------------------------------------------------------------------------------------
function InitAllWindow(progressInfo, sGameConfigType)
	local sConfigPath = Def_Windows_Config_Path
	return InitCofingWindow(sConfigPath, progressInfo, sGameConfigType)
end

--初始化配置中的界面 （progressInfo可选 隔帧加载参数）
function InitCofingWindow(path, progressInfo, sGameConfigType)
	local windowList = ConfigCommon:GetCustomConfig(path, sGameConfigType)

	-- 隔帧加载机制
	local step, index
	if progressInfo then
		step = (progressInfo.progressCount - progressInfo.progressIndex) / table.getCount(windowList)
		index = 0
	end

	local dAllWinInfo = {}

	for key, windowConfig in pairs(windowList) do
		local sCodePath = string.rstrip(windowConfig["CodePath"], ".lua")
		local winName = windowConfig["WinName"]

		-- 界面类自定义类名, 如果没配置默认使用界面名
		local sCustomClassName = windowConfig["CustomClassName"]
		if string.isEmpty(sCustomClassName) then
			sCustomClassName = winName
		end

		-- 如果没有代码文件, 创建默认界面类
		if string.isEmpty(sCodePath) then
			_G[sCustomClassName] = GameUIManager
		else
			require(sCodePath)
		end

		local windowClass = _G[sCustomClassName]
		local windowObj = nil
		if windowClass then
			local winArg = {name = winName, config = windowConfig}

			-- 解析界面所在的场景列表
			local sceneNameList = string.split(windowConfig["Scene"], ",")
			for _, sceneName in pairs(sceneNameList) do
				sceneName = string.strip(sceneName)
				winArg.scene = sceneName
				windowObj = windowClass.new(winArg, sGameConfigType)
				setWinCache(sceneName, windowObj, sGameConfigType)
			end
		else
			com.error("加载界面(%s)失败！无法找到界面类(%s)", winName, sCustomClassName)
		end

		dAllWinInfo[winName] = {
			CodePath = sCodePath,
			CustomClassName = sCustomClassName,
			WindowObj = windowObj,
		}


		if progressInfo then
			index = index + 1
			local value = math.modf(progressInfo.progressIndex + step * index)

			progressInfo.setProgressFunc(value)
		end
	end

	return dAllWinInfo
end

-- 销毁所有界面
function purgeWindowCache()
	for scene, windowList in pairs(g_windowCache) do
		for winName, winObj in pairs(windowList) do
			winObj:Destroy(true, true)
		end
	end
	ImageCommon:RemoveUnusedTextures()
end

function Clear( ... )
	purgeWindowCache()
end

-- 销毁场景中的界面
function ClearSceneWindow( scene )
	com.info("ClearSceneWindow(%s)", scene)

	-- 先注册计时器会后执行
	RegisterTimerCall(function( )	
		com.info("ClearSceneWindow(%s) wait", scene)
		--清除内存
		ImageCommon:RemoveUnusedTextures()
	end, 0)

	local sceneName = scene:getName()
	local sceneWinList = getSceneWinList(sceneName)
	for windowName, window in pairs(sceneWinList) do
		-- com.debug("SceneWindow(%s)", window)
		if window:GetScene() == sceneName then
			if window:IsCreate() then
				-- window:OnInit()
				-- window:Hide()	
				window:Destroy(false, true)
			end	
		end
	end 

end

--初始化场景中的界面
function InitSceneWindow(scene, defaultInitCount)
	com.debug("InitSceneWindow(%s) = %s", scene, defaultInitCount)
	local sceneName = scene:getName()
	local sceneWinList = getSceneWinList(sceneName)
	local index = 0
	for windowName, window in pairs(sceneWinList) do
		if window:GetScene() == sceneName then
			if window:IsDefaultCreate() then
				com.debug("IsDefaultCreate", window)
				if not window:IsCreate() then
					window:CreateWindow()
					index = index + 1
				end
			end
		end
		-- 不传默认加载全部
		if (defaultInitCount and defaultInitCount > 0) and index >= defaultInitCount then
			break
		end
	end 
end

-- 初始化场景的界面显示
function InitSceneWindowVisible(scene)
	local sceneName = scene:getName()
	-- 配置的场景显示界面
	local sceneWinList = getSceneWinList(sceneName)
	for windowName, window in pairs(sceneWinList) do
		-- com.debug("%s.OnInit()", window)
		if window:IsCreate() then
			window:OnInit()
			window:Hide()
		end
	end
	for windowName, window in pairs(sceneWinList) do
		if window:GetIsAutoOpen() then
			window:Show()
		end
	end
	-- 预设置显示界面
	local preShowList = scene:GetPreShowList()
	for windowName, argList in pairs(preShowList) do
		local window = GetWinByName(windowName)
		if window then
			window:Show(unpack(argList))
		end
	end
end

--隐藏场景中的所有界面
function HideSceneAllWindows(scene)
	local sceneName = scene:getName()
	-- 配置的场景显示界面
	local sceneWinList = getSceneWinList(sceneName)
	for windowName, window in pairs(sceneWinList) do
		if window:IsCreate() and window:IsShow() then
			window:Hide()
		end
	end
end

-- web控件列表
local g_webViewDict = {}
-- 添加web控件显示控制
function InitWindowUIWebViewControl( window, control )
	local sceneName = window:GetScene()
	if not g_webViewDict[sceneName] then
		g_webViewDict[sceneName] = {}
	end
	g_webViewDict[sceneName][control] = window
end
-- 清理web控件显示控制
function ClearWindowUIWebViewControl( window, control )
	local sceneName = window:GetScene()
	if not g_webViewDict[sceneName] then
		return
	end
	g_webViewDict[sceneName][control] = nil
end
-- 界面显示时控制web界面显示
function OnWindowShowChangeUIWebViewStatus( ... )
	local curScene = SceneCommon:GetCurScene()
	local sceneName = curScene:getName()
	-- 配置的场景显示界面
	local sceneWinList = getSceneWinList(sceneName)

	-- 找出打开的界面里 最顶层的界面
	local maxZOrder = 0
	for windowName, window in pairs(sceneWinList) do
		if window:IsShow() then
			local zOrder = window:GetZOrder()
			if zOrder > maxZOrder then
				maxZOrder = zOrder
			end
		end
	end

	if not g_webViewDict[sceneName] then
		return
	end
	
	-- 把层级比较低的web控件都隐藏起来
	for control, window in pairs(g_webViewDict[sceneName]) do
		local zOrder = window:GetZOrder()
		local visible = false
		if not window:IsShow() or zOrder < maxZOrder then
			visible = false
		else
			visible = true
		end
		if window:IsCreate() then
			control:SetPlatformVisible(visible)
		end
	end
end

