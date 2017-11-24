require "common/class"
require "common/LanguageCommon"
require "common/UICommon"



-- 节点对象映射
local g_TimeLineAndWidgetMap ={}

-- ui控件管理器
WidgetManager = class()

function WidgetManager:ctor( obj )
	self._win = obj.win
	self._name = obj.windowName or ""
	self._csbPath = obj.FilePath
	self.name = obj.widgetName or ""
--##JSCodeClose##Start##--js不支持
	local fullPath = cc.FileUtils:getInstance():fullPathForFilename(self._csbPath)
	if not cc.FileUtils:getInstance():isFileExist(fullPath) then
		com.error("csb文件（%s）不存在", self._csbPath)
		return
	end
--##JSCodeClose##End##--js不支持

	self._bCache = false
	self._hasCache = false
	self._bDestroy = false

	-- 隐藏界面时是否清理缓存
	self._bClearCacheByHide = true

	--获取缓存条目
	if SubItemCacheCommon then
		self._bCache = true
		self._layer = SubItemCacheCommon:GetSubItemCache(self._csbPath)
	end

	if not self._layer then
		self._bCache = false
		self._layer = cc.CSLoader:createNode(self._csbPath)
		if self._layer then
			Lua_Retain(self._layer, string.format("WidgetManager_%s", tostring(self._name)))
		end
	end

	-- self.layer:addChild(self._node)
	self._buttonTimerList = {}
	self._subControlList = {}

	-- 时间线列表（隐藏或销毁时释放对应的WidgetManager引用，防止内存泄露）
	self._lTimelineList = {}

	-- 注册回调控件列表（隐藏或销毁时释放对应的WidgetManager引用，防止内存泄露）
	self._lRegisterControlList = {}

	self:__parseNodeChild(self._layer)

	self:__initSize()

    --初始化界面所有子动作（编辑器编辑的动作）
	self:__initSubAction()

	--适配条目大小和子节点位置
	self:__adaptWidthAndChildPos(obj)

	self._layer:setAnchorPoint(obj.AnchorPoint or cc.p(0, 0))
	if obj.bPages then
		local layout = ccui.Layout:create()
		layout:addChild(self._layer)
		obj.layer:addPage(layout)
	else
		self:SetPosition(obj.pos_x, obj.pos_y)
		obj.layer:addChild(self._layer)
	end
	self:OnCreate()

	self:RegisterControl()

	self:__initCsbInfo()
	self:__initLabelEffect()

	-- 是否整个界面固定不翻转
	self._bFixedWindow = false
	self:__initControlLayout()

	self:__applylocalization()

    self._fReApplylocalization = function() self:__reApplylocalization() end
	EventCommon:RegisterEvent("ChangeLanguageRefreshText", self._fReApplylocalization)

end

function WidgetManager:OnCreate( ... )

end

function WidgetManager:__adaptWidthAndChildPos( obj )
	--只能对可以设置大小的处理
	if not self._layer.getContentSize then
		return
	end

	if (not obj.bAdaptWidth) and (not obj.bAdaptHeight) then
		return
	end

	local parentSize = obj.layer:getContentSize()
	local pCurSize = self._layer:getContentSize()
	local childList = self._layer:getChildren()
	if obj.bAdaptWidth then
		for _, control in pairs(childList) do
			local fPosx, fPosy = control:getPosition()
			local fNewPosx = (fPosx / pCurSize.width) * parentSize.width
			control:setPosition(fNewPosx, fPosy)
		end
		self._layer:setContentSize(cc.size(parentSize.width, pCurSize.height))
	elseif obj.bAdaptHeight then
		for _, control in pairs(childList) do
			local fPosx, fPosy = control:getPosition()
			local fNewPosy = (fPosy / pCurSize.height) * parentSize.height
			control:setPosition(fPosx, fNewPosy)
		end
		self._layer:setContentSize(cc.size(pCurSize.width, parentSize.height))
	end
end


-- 设置隐藏界面时缓存清理模式
function WidgetManager:SetClearCacheModeByHide( bClearCacheByHide )

	self._bClearCacheByHide = bClearCacheByHide
end

function WidgetManager:IsClearCacheByHide( ... )
	return self._bClearCacheByHide
end

-- 对控件应用本地化处理
function WidgetManager:DoApplylocalizationToControl( pControl, bReverseWindowLayout )
    -- 当前语言是否需求界面布局反转
    if bReverseWindowLayout then
    	DoFlippedNode(pControl, true, false)
    -- 恢复节点翻转
    else
    	ResumeFlippedNode(pControl)
    end
end
-- 对控件应用本地化处理
function WidgetManager:DoApplylocalizationToControlName( sControlName, pControl, bReverseWindowLayout )

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

-- 设置控件文本,应用多语言本地化
function WidgetManager:__applylocalization()
	self._dLabelControlStrDict = {}
	self._dEditControlPlaceStrDict = {}
	self._dControlStrDict = {}

    -- 当前语言是否需求界面布局反转
	local bReverseWindowLayout = LanguageCommon:IsReverseWindowLayout()
	-- 是否整个界面固定不翻转
	if self._bFixedWindow then
		self:DoApplylocalizationToControl(self._layer, bReverseWindowLayout)
		-- 后续按钮不需要再翻转
		bReverseWindowLayout = false
	end

	-- 当前语言
	self._sLastLanguageType = LanguageCommon:GetLanguageType()

	for itemName, control in pairs(self._subControlList) do
		-- 对控件应用本地化处理
		self:DoApplylocalizationToControlName(itemName, control, bReverseWindowLayout)

		--label
		local str = nil
		if control.setString and control.getString then
			-- local str = control:getString()
			str = control:getString()
			if str ~= "" then
				self:SetLabelValue(itemName, str)
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

		end
		--button
		if control.setTitleText and control.getTitleText then
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

--重置应用多语言本地化
function WidgetManager:__reApplylocalization( ... )
	if self._bDestroy then
		return
	end
	-- 语言没变化,不做处理
	local sCurLanguageType = LanguageCommon:GetLanguageType()
	if self._sLastLanguageType == sCurLanguageType then
		return
	end
	self._sLastLanguageType = sCurLanguageType

	-- 当前语言是否需求界面布局反转
	local bReverseWindowLayout = LanguageCommon:IsReverseWindowLayout()
	-- 是否整个界面固定不翻转
	if self._bFixedWindow then
		self:DoApplylocalizationToControl(self._layer, bReverseWindowLayout)
		-- 后续按钮不需要再翻转
		bReverseWindowLayout = false
	end


	for itemName, vlaue in pairs(self._dControlStrDict) do
		local control = self:GetItemByName(itemName)

		-- 对控件应用本地化处理
		self:DoApplylocalizationToControlName(itemName, control, bReverseWindowLayout)
		
		if control.setString and control.getString then
			if control.setPlaceHolder and control.getPlaceHolder then
				if vlaue["str"] then
					self:setPlaceHolder(itemName, vlaue["str"])
				end
			end
			self:SetLabelValue(itemName, vlaue["str"], unpack(vlaue["other"]))
		end
		--button
		if control.setTitleText and control.getTitleText then
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
	-- 		self:SetLabelValue(itemName, str)
	-- 	end
	-- 	--button
	-- 	if control.setTitleText and control.getTitleText then
	-- 		self:setButtonLabelValue(itemName, str)
	-- 	end	
	-- 	-- -- 编辑框
	-- 	-- if control.setPlaceHolder and control.getPlaceHolder then
	-- 	-- 	self:setPlaceHolder(itemName, str)
	-- 	-- end
	-- end
end

--保存控件，支持多语言
function WidgetManager:__saveControlLanguageData( itemName, str, ... )
	local otherList = pack(...)
	self._dControlStrDict[itemName] = {["str"] = str, ["other"] = otherList}
end


function WidgetManager:IsCacheWidget( ... )
	return self._bCache
end

function WidgetManager:Destroy(bNowRelease, bNotNowClearTexture)

	self._bDestroy = true
	EventCommon:UnRegisterEvent("ChangeLanguageRefreshText", self._fReApplylocalization)

	self:OnHide()

	-- 帧回调映射去除
	if g_TimeLineAndWidgetMap and self._lTimelineList then
		for _, pTimeLine in pairs( self._lTimelineList ) do
			g_TimeLineAndWidgetMap[pTimeLine] = nil
		end
	end
    -- 按钮回调映射界面去除
	for _, pControl in pairs( self._lRegisterControlList ) do
		ScriptHandlerMgr:getInstance():removeObjectAllHandlers( pControl )
	end
	self._lRegisterControlList = {}

	self:__onBaseActionRemove()
	local lastLayer = self._layer
	if lastLayer then
		lastLayer:removeFromParent(true)
	end

	for _, buttonTimerList in pairs(self._buttonTimerList) do
		for _, buttonTimer in pairs(buttonTimerList) do 
			DeleteTimer(buttonTimer)
		end
	end

	self._buttonTimerList = {}

	if self._bCache then
		if not self._hasCache then
			SubItemCacheCommon:CacheSubItem(self._csbPath, self._layer)
			self._hasCache = true
		end
		-- self._subControlList = nil
		-- self._controlSizeDict = nil
		-- self._controlScaleDict = nil
		return
	end
	
	if bNowRelease then
		com.debug("WidgetManager Destroy(%s)", self)
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
		com.debug("WidgetManager wait Destroy(%s)", self)
		if lastLayer then
			Lua_Release(lastLayer)
		end

		--清除内存
		if not bNotNowClearTexture then
			ImageCommon:RemoveUnusedTextures()
		end

		DumpNodeInfo(lastLayer)

	end, 0)

	-- self._subControlList = nil
	-- self._controlSizeDict = nil
	-- self._controlScaleDict = nil
end

--检测是否繁体切换字体
function WidgetManager:__checkZhHantChangeFont( ... )
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
function WidgetManager:__changeFontName( fontName )
	if os.isWindow() then
		fontName = ""
	end
	for itemName, control in pairs(self._subControlList) do
		if control.setFontName then
			control:setFontName(fontName)
		end

		if control.setTitleFontName then
			control:setTitleFontName(fontName)
		end
	end
end

--解析子节点
function WidgetManager:__parseNodeChild(node)
	local childList = node:getChildren()
	for _, control in pairs(childList) do
		self:__parseNodeChild(control)
		local nodeName = control:getName()	
		if string.isVail(nodeName)then
			if self._subControlList[nodeName] then
				com.error("control name（%s）已被注册", nodeName)
			else
				self._subControlList[nodeName] = control
			end
		end
		
	end
end

function WidgetManager:GetContentSize( ... )
	return self._layer:getContentSize()
end


--初始化大小
function WidgetManager:__initSize( ... )
	self._controlSizeDict = {}
	self._controlScaleDict = {}
	for itemName, control in pairs(self._subControlList) do
		if control.getContentSize then
			self._controlSizeDict[itemName] = control:getContentSize()
		end
		if control.getScaleX and control.getScaleY then
			self._controlScaleDict[itemName] = {control:getScaleX(), control:getScaleY()}
		end
	end
end


function WidgetManager:RegisterControl()
end

--初始化按钮回调
function WidgetManager:RegisterButtonEvent(controlList)
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
					end, 
				1)
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
			if self:IsControlExist(normal) and self:IsControlExist(disabled) then
				self:ShowItemByName(normal)
				self:HideItemByName(disabled)
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


----------------------------------------------------------
function WidgetManager:__str__()
	return string.format("WidgetObject(%s)[%s]", tostring(self._name), self._dataIndex)
end
----------------------------------------------------------
function WidgetManager:GetControlOriginalSize(itemName)
	return self._controlSizeDict[itemName]
end
----------------------------------------------------------
-- function WidgetManager:SetLabelFontName( ... )
-- 	for itemName, control in pairs(self._subControlList) do
-- 	 	if self._proxy:getNodeTypeName(control) == "CCLabelTTF" then
-- 	 		if control then
-- 				control:setFontName(config.DefaultFont)
-- 			end
-- 	 	end
-- 	 end
-- end

-- 记录数据
function WidgetManager:SetData( dataIndex, singleLineIndex, iShowIndex)
	--数据索引（和显示的索引不一定一致）
	self._dataIndex = dataIndex
	self._singleLineIndex = singleLineIndex

	--所在位置索引
	self._iShowIndex = iShowIndex
	-- com.debug("%s.SetData = %s, %s", self, dataIndex, singleLineIndex)
end

-- 设置控件坐标
function WidgetManager:SetControlPosition( controlName, posx, posy )
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:setPosition(posX, posY)
end


function WidgetManager:SetPosition(pos_x, pos_y)
	--com.debug("SetPosition = ", pos_x, pos_y)
	self._layer:setPosition(cc.p(pos_x, pos_y))
end


-- 获取控件的坐标
function WidgetManager:GetControlPosition(controlName)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	return control:getPosition()
end

-- 设置控件的坐标
function WidgetManager:SetControlPosition(controlName, posx, posy)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:setPosition(posx, posy)
end

-- 设置控件的纵坐标
function WidgetManager:SetControlPositionY(controlName, posy)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:setPositionY(posy)
end

-- 设置控件的横坐标
function WidgetManager:SetControlPositionX(controlName, posx)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:setPositionX(posx)
end


function WidgetManager:GetPosition()
	return self._layer:getPosition()
end


function WidgetManager:Show(dataInfo)
	--检测是否需要繁体切换字体
	self:__checkZhHantChangeFont()
	self._layer:setVisible(true)
	self:__onBaseActionInit()
	self:OnShow(dataInfo)

	--重置多语言本地化
	self:__reApplylocalization()
end

function WidgetManager:GetControl(  )
	return self._layer
end

function WidgetManager:OnShow( dataInfo )
	-- body
end

function WidgetManager:IsShow()
	return self._layer:isVisible()
end

function WidgetManager:Hide()
	

	self._layer:setVisible(false)

	self:OnHide()
	self:__onBaseActionRemove()

	for _, buttonTimerList in pairs(self._buttonTimerList) do
		for _, buttonTimer in pairs(buttonTimerList) do 
			DeleteTimer(buttonTimer)
		end
	end

	self._buttonTimerList = {}


	-- 隐藏界面时是否清理缓存
	if not self._bClearCacheByHide then
		return
	end

	if self._bCache then

		-- 帧回调映射去除
		if g_TimeLineAndWidgetMap and self._lTimelineList then
			for _, pTimeLine in pairs( self._lTimelineList ) do
				g_TimeLineAndWidgetMap[pTimeLine] = nil
			end
		end

		for _, pControl in pairs( self._lRegisterControlList ) do
			ScriptHandlerMgr:getInstance():removeObjectAllHandlers( pControl )
		end
		self._lRegisterControlList = {}
		self._layer:removeFromParent(true)


		-- self._subControlList = nil
		-- self._controlSizeDict = nil
		-- self._controlScaleDict = nil

		if not self._hasCache then
			SubItemCacheCommon:CacheSubItem(self._csbPath, self._layer)
			self._hasCache = true
		end
	end
end

function WidgetManager:OnHide()
end

function WidgetManager:Remove( ... )
	self._layer:removeAllChildrenWithCleanup(true)
end

-- 设置控件图片
function WidgetManager:SetControlImage(controlName, imageName, isThumb)
	local control = self:GetItemByName(controlName)
	isThumb = isThumb or false
	if control then

    	local controlSize = self:GetControlOriginalSize(controlName)
   		UI.SetControlImage(control, controlSize, imageName, isThumb)
	end
end

-- 设置控件图片,不缩放
function WidgetManager:SetControlImageNoScale(controlName, imageName, isThumb)
	local cardBtn = self:GetItemByName(controlName)
	if cardBtn then
   		UI.SetControlImage(cardBtn, nil, imageName, isThumb)
	end
end

---------------------------------------------------


--设置按钮图片
function WidgetManager:setButtonImage(controlName, normal, selected, disabled, imgType)
	imgType = imgType or ccui.TextureResType.localType
	local btnControl = self:GetItemByName(controlName)
	local normalImg = ImageCommon:getImageFileNameByName(normal)
	local selectedImg = ImageCommon:getImageFileNameByName(selected)
	local disabledImg = ImageCommon:getImageFileNameByName(disabled)
	if btnControl then
		btnControl:loadTextures(normalImg, selectedImg, disabledImg, imgType)
	end
end

--设置颜色
function WidgetManager:SetControlColor4(labelName, colorR, colorG, colorB, alpha)
	-- com.info("SetControlColor = ", labelName)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:setTextColor(cc.c4b(colorR, colorG, colorB, alpha))
    end
end

--设置颜色
function WidgetManager:SetControlColor(labelName, colorR, colorG, colorB, bNeedSetSubControl)
	-- com.info("SetControlColor = ", labelName)
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
function WidgetManager:SetControlColor3(labelName, color, bNeedSetSubControl)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:setColor(color)
        
        -- 需要对子节点生效
        if bNeedSetSubControl then
        	label:setCascadeColorEnabled(true)
        end
    end
end


--获取控件
function WidgetManager:GetItemByName(itemName)
	if nil ~= self._subControlList[itemName] then
    	return self._subControlList[itemName]
    end
    com.error("control name（%s）获取不到", itemName)
    return nil 
end

--控件是否存在
function WidgetManager:IsControlExist(controlName)
	if self._subControlList[controlName] then
		return true
	end
	return false
end

function WidgetManager:IsItemShow(itemName)
	local item = self:GetItemByName(itemName)
	if item then
		return item:isVisible()
	end
	return false
end

function WidgetManager:ShowItemByName(itemName)
	local item = self:GetItemByName(itemName)
	if item then
		item:setVisible(true)
	end
end

function WidgetManager:HideItemByName(itemName)
	local item = self:GetItemByName(itemName)
	if item then
		item:setVisible(false)
	end
end

--设置按钮图片
function WidgetManager:setButtonImage(controlName, normal, selected, disabled, imgType)
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
function WidgetManager:setButtonNormalImage(controlName, normal, imgType)
	imgType = imgType or ccui.TextureResType.localType
	local btnControl = self:GetItemByName(controlName)
	local normalImg = ImageCommon:getImageFileNameByName(normal)
	if btnControl then
		btnControl:loadTextureNormal(selectedImg, imgType)
	end
end

--设置按钮点击状态图片
function WidgetManager:setButtonPressedImage(controlName, selected, imgType)
	imgType = imgType or ccui.TextureResType.localType
	local btnControl = self:GetItemByName(controlName)
	local selectedImg = ImageCommon:getImageFileNameByName(selected)
	if btnControl then
		btnControl:loadTexturePressed(selectedImg, imgType)
	end
end

--设置按钮不可点击状态图片
function WidgetManager:setButtonDisabledImage(controlName, disabled, imgType)
	imgType = imgType or ccui.TextureResType.localType
	local btnControl = self:GetItemByName(controlName)
	local disabledImg = ImageCommon:getImageFileNameByName(disabled)
	if btnControl then
		btnControl:loadTextureDisabled(disabledImg, imgType)
	end
end


--设置按钮选中
function WidgetManager:setButtonSelectedState(controlName, isSelect)
	local btnControl = self:GetItemByName(controlName)
	if btnControl then
		btnControl:setBright(isSelect)
		local normal = string.format("%sCharNormal", controlName)
		local highlighted = string.format("%sCharHighlighted", controlName)
		local disabled = string.format("%sCharDisabled", controlName)
		if isSelect then
			if self:IsControlExist(normal) and self:IsControlExist(disabled) then
				self:HideItemByName(normal)
				self:HideItemByName(disabled)
				if self:IsControlExist(highlighted) then
					self:ShowItemByName(highlighted)
				else
					self:ShowItemByName(disabled)	
				end
			end
		else
			if self:IsControlExist(normal) and self:IsControlExist(disabled) then
				self:ShowItemByName(normal)
				self:HideItemByName(disabled)
				if self:IsControlExist(highlighted) then
					self:HideItemByName(highlighted)
				end
			end
		end
    end
end

--设置按钮不可用
function WidgetManager:setButtonDisabledState(controlName, isEnable)
	local btnControl = self:GetItemByName(controlName)
	if btnControl then
		btnControl:setBright(isEnable)
		btnControl:setEnabled(isEnable)
		local normal = string.format("%sCharNormal", controlName)
		local highlighted = string.format("%sCharHighlighted", controlName)
		local disabled = string.format("%sCharDisabled", controlName)
		if isEnable then
			if self:IsControlExist(normal) and self:IsControlExist(disabled) then
				self:ShowItemByName(normal)
				self:HideItemByName(disabled)
				if self:IsControlExist(highlighted) then
					self:HideItemByName(highlighted)				
				end
			end
		else
			if self:IsControlExist(normal) and self:IsControlExist(disabled) then
				self:HideItemByName(normal)
				self:ShowItemByName(disabled)
				if self:IsControlExist(highlighted) then
					self:HideItemByName(highlighted)				
				end
			end
		end
    end
end

function WidgetManager:onButtonTouchDown( controlName )
	local normal = string.format("%sCharNormal", controlName)
	local highlighted = string.format("%sCharHighlighted", controlName)
	local disabled = string.format("%sCharDisabled", controlName)
	if self:IsControlExist(normal) and self:IsControlExist(disabled) then
		self:HideItemByName(normal)
		self:HideItemByName(disabled)
		if self:IsControlExist(highlighted) then
			self:ShowItemByName(highlighted)
		else
			self:ShowItemByName(disabled)
		end
	end
end


function WidgetManager:onButtonTouchMoved(controlName)
	local btnControl = self:GetItemByName(controlName)
	if not btnControl then
		return
	end
	local normal = string.format("%sCharNormal", controlName)
	local highlighted = string.format("%sCharHighlighted", controlName)
	local disabled = string.format("%sCharDisabled", controlName)
	if self:IsControlExist(normal) and self:IsControlExist(disabled) then
		if btnControl:isHighlighted() then
			self:HideItemByName(normal)
			self:HideItemByName(disabled)
			if self:IsControlExist(highlighted) then
				self:ShowItemByName(highlighted)
			else
				self:ShowItemByName(disabled)
			end
		else
			self:ShowItemByName(normal)
			self:HideItemByName(disabled)
			if self:IsControlExist(highlighted) then
				self:HideItemByName(highlighted)				
			end
		end
	end
end

function WidgetManager:onButtonTouchEnd(controlName)
	local normal = string.format("%sCharNormal", controlName)
	local highlighted = string.format("%sCharHighlighted", controlName)
	local disabled = string.format("%sCharDisabled", controlName)
	if self:IsControlExist(normal) and self:IsControlExist(disabled) then
		self:ShowItemByName(normal)
		self:HideItemByName(disabled)
		if self:IsControlExist(highlighted) then
			self:HideItemByName(highlighted)
		end
	end
end


function WidgetManager:onButtonTouchCancel( controlName )
	local normal = string.format("%sCharNormal", controlName)
	local highlighted = string.format("%sCharHighlighted", controlName)
	local disabled = string.format("%sCharDisabled", controlName)
	if self:IsControlExist(normal) and self:IsControlExist(disabled) then
		self:ShowItemByName(normal)
		self:HideItemByName(disabled)
		if self:IsControlExist(highlighted) then
			self:HideItemByName(highlighted)			
		end
	end
end



-- 设置按钮文本
function WidgetManager:setButtonLabelValue( controlName, value, ... )
	local btnControl = self:GetItemByName(controlName)
	if btnControl then
		value, _ = LanguageCommon:GetString(tostring(value), ...)
		btnControl:setTitleText(value)
    end
end

----------------------------
--复选框注册回调
function WidgetManager:CheckBoxRegisterEvent(controlName, selectCallFunc, unSelectCallFunc, selectArg, unSelectArg)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	table.insert( self._lRegisterControlList, control )
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
	control:addEventListener(callBack)
end

--获取复选框状态
function WidgetManager:GetCheckBoxSelectState(controlName)
	local control = self:GetItemByName(controlName)
	if not control then
		return nil
	end
	return control:isSelected()
end

--设置复选框状态
function WidgetManager:SetCheckBoxSelectState(controlName, isSelect)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:setSelected(isSelect)
end

--------------------------------------
function WidgetManager:__initCsbInfo( ... )
	self._sCsbName = ""

	local sPath = self._csbPath
	sPath = string.rstrip(sPath, ".csb")

	local lPathList = string.split(sPath, "/") 
	self._sCsbName = lPathList[#lPathList]
end
--------------------------------------------------------------------
-- 初始化控件布局
function WidgetManager:__initControlLayout( ... )
	-- 固定布局的控件字典
	self._dFixedControlDict = {}
	-- 是否整个界面固定不翻转
	self._bFixedWindow = false

	if not ConfigCommon:IsExistConfig("config/window_control_layout.txt") then
		return
	end

	local dControlConfig = ConfigCommon:getDataByField("config/window_control_layout.txt", "WindowCsbName", self._sCsbName)
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
function WidgetManager:IsFixedLayout( sControlName )
	return self._dFixedControlDict[sControlName] or false
end
--------------------------------------
--初始化文本特效
function WidgetManager:__initLabelEffect()

	-- 应用安卓缩放比例
	local bUseAndroidScale = os.isAndroid()

	local charConfig = ConfigCommon:getDataByField("config/window_char_effect.txt", "WindowCsbName", self._sCsbName)
	if not charConfig then
		return
	end
	for _, charInfo in pairs(charConfig) do

		-- 应用安卓缩放比例
		if bUseAndroidScale then
			local pLabel = self:GetItemByName(charInfo["ControlName"])
			if pLabel then
				local fLabelScale = charInfo["AndroidScale"]
				if fLabelScale and fLabelScale > 0 then
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
function WidgetManager:SetEnableGlow(labelName, color4B)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:enableGlow(color4B)
    end
end

--设置文本阴影
function WidgetManager:SetLabelEnableShadow(labelName, color4B, size, blurRadius)
	blurRadius = blurRadius or 0
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:enableShadow(color4B, size, blurRadius)
    end
end

--设置文本描边（只能在ios和安卓生效）
function WidgetManager:SetLabelEnableOutline(labelName, color4B, outlineSize)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        label:enableOutline(color4B, outlineSize)
    end
end


--设置值
function WidgetManager:SetLabelValue(labelName, value, ...)
	self:__saveControlLanguageData( labelName, value, ... )

	local label = self:GetItemByName(labelName)
	if nil ~= label then
		value, _ = LanguageCommon:GetString(tostring(value), ...)
        label:setString(value)
    end
end

--获取值
function WidgetManager:GetLabelValue(labelName)
	local label = self:GetItemByName(labelName)
	if nil ~= label then
        return label:getString()
    end
    return nil
end


--设置加载进度条或滑动条比率值
function WidgetManager:SetPercent(controlName, percent)
	local control = self:GetItemByName(controlName)
	if not control then
		return
	end
	control:setPercent(percent)
end

--获取加载进度条或滑动条比率值
function WidgetManager:GetPercent(controlName)
	local control = self:GetItemByName(controlName)
	if not control then
		return nil
	end
	return control:getPercent()
end


--界面主动作初始化
function WidgetManager:__onBaseActionInit()
	if self._layer then
		self._layer:stopAllActions()
	end
	self._baseNodeAction = cc.CSLoader:createTimeline(self._csbPath)
	self._layer:runAction(self._baseNodeAction)	
	self:__initFrameEvent( self._baseNodeAction )
	self:__onSubActionInit()
end

--界面主动作清除
function WidgetManager:__onBaseActionRemove()
	self:__onSubActionRemove()
	if self._layer then
		self._layer:stopAllActions()
	end
end

--界面子动作初始化
function WidgetManager:__onSubActionInit()
	self:__onSubActionRemove()
	for	key, actionConfig in pairs(self._subCsbActionCfg) do
		if actionConfig.IsDefaultPlay == 1 then
			self:runSubCsbAction(key)
		end
	end
end

function WidgetManager:__onSubActionRemove()
	for	key, actionConfig in pairs(self._subCsbActionCfg) do
		local control = self:GetItemByName(actionConfig.NodeName)
		if control then
			control:stopAllActions()
		end
	end
end

function WidgetManager:stopSubCsbAction()
	self:__onSubActionRemove()
end

--播放界面子动作(嵌套的csb动作)
function WidgetManager:runSubCsbAction(actionKey)
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

	self:__initFrameEvent( nodeAction )

	if actionConfig.IsLoop == 1 then
		nodeAction:play(actionConfig.ActionName, true)
	else
		nodeAction:play(actionConfig.ActionName, false)
	end
end


function WidgetManager:__initSubAction( ... )
	self._subCsbActionCfg = {}
	local winActionCfg = ConfigCommon:get("config/window_action.txt")
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
function WidgetManager:__initFrameEvent( actionTimeline )
	if not actionTimeline then
		return
	end

	table.insert( self._lTimelineList, actionTimeline )
	g_TimeLineAndWidgetMap[actionTimeline] = self
    actionTimeline:setFrameEventCallFunc(onFrameEvent)
end

function onFrameEvent( frame )
	if nil == frame then
        return
    end
    local pTimeline = frame:getTimeline()
    local pActionTimeline = pTimeline:getActionTimeline()

	local pSelf = g_TimeLineAndWidgetMap[pActionTimeline]
    --动作回调Hide
    local frameEventName = frame:getEvent()
    if pSelf and pSelf[frameEventName] then
    	pSelf[frameEventName]( pSelf )
    end
end



--控件停止动作
function WidgetManager:stopAllAction()
	if self._layer then
		self._layer:stopAllActions()
	end
end

--播放动作
function WidgetManager:runAction(actionName, bLoop)
	if self._baseNodeAction then
		if actionName then
			self._baseNodeAction:play(actionName, bLoop)
		else
			self._baseNodeAction:gotoFrameAndPlay(0, bLoop)
		end
	end
end

--根据帧播放动作
function WidgetManager:runActionByFrame(startIndex, endIndex, bLoop)
	if self._baseNodeAction then
		self._baseNodeAction:gotoFrameAndPlay(startIndex, endIndex, bLoop)
	end
end

--动作暂停
function WidgetManager:PauseAction()
	if self._baseNodeAction then
		self._baseNodeAction:pause()
	end
end

--动作恢复
function WidgetManager:ResumeAction()
	if self._baseNodeAction then
		self._baseNodeAction:resume()
	end
end



---------------------------------------------------------------------------
-- 滚动层管理器
ScrollManager = class()

function ScrollManager:ctor(window, scroll, layerInfo)
	com.debug("ScrollManager(%s) = %s", tostring(window.name), self)
	self._win = window
	self._name = window.name
	self._scroll = scroll

	layerInfo = layerInfo or {}
	self._layerInfo = layerInfo
	self._widgetObjList = {}
	self._pulldownList = {}  --下拉框存储列表
	self._isPulldown = false

	self._onShowPageInfo = layerInfo.onShowPageInfo

	-- 获取可显示对象总数
	self._onGetObjCount = layerInfo.onGetObjCount
	-- 获取指定页卡牌序号列表
	self._onGetObjIndexList = layerInfo.onGetObjIndexList
	--获取信息列表
	self._onGetInfoList = layerInfo.onGetInfoList
	-- 获取对象数据索引
	self._onGetObjectDataIndex = layerInfo.onGetObjectDataIndex
	-- 设置对象自定义控制器
	self._objectCustomControlClass = self._layerInfo.CustomControlClass

	--加载的json资源
    self:SetObjectConfigFile(layerInfo.loadFile)
	--获取配置
	self._getConfig = layerInfo.onGetConfig
	self._onOtherInfo = layerInfo.onOtherInfo

	com.debug("%s._scroll = %s", self._name, self._scroll)

	self._innerContainer = self._scroll:getInnerContainer()

	self._curCount = 0
	self._pageObjCount = layerInfo.pageObjCount or 9999
	self._placeCount = layerInfo.placeCount

	self._bShowPage = false
	self._sShowPageControlName = "pageShow"
	self._sShowPageFmt = "%d/%d"

    self._objHeight = layerInfo.objHeight or self._objHeight
    self._objWidth = layerInfo.objWidth or self._objWidth
	self._rowObjCount = layerInfo.rowObjCount or 1 	--每行
	self._pageIndex = 1
	self._descriptNodeHigeht = 0 		--描述内容高度

	self._isHorizontal = layerInfo.isHorizontal 	-- 是否横向

	-- 设置页面内容大小
	self._innerSize = self._scroll:getInnerContainerSize()
	self._innerWidth = self._innerSize.width
	self._innerHeight = self._innerSize.height

	self._scroll:setClippingEnabled(true) 		--设置裁剪
	self:__scrollRegisterEvent()
	self._baseX = layerInfo.baseX or 0
	self._baseY = 0

	self._scrollPos = cc.p(self._scroll:getPosition())

	self._lastPosx, self._lastPosy = self._innerContainer:getPosition()

	-- -- 默认不显示动作
	-- self._bShowObjectAction = false

	self._bAdaptWidth = false
	self._bAdaptHeight = false

	-- 隐藏界面时是否清理缓存
	self._bClearCacheByHide = true
end
---------------------------------------------------------------------------

function ScrollManager:SetAdaptWidth()
	self._bAdaptWidth = true
end

function ScrollManager:SetAdaptHeight()
	self._bAdaptHeight = true
end

-- 设置每页对象数 (-1 无限制)
function ScrollManager:SetPageObjectCount( pageObjCount )
	if pageObjCount < 0 then
		pageObjCount = 9999
	end
	self._pageObjCount = pageObjCount
end
-- 设置每个对象高度
function ScrollManager:SetObjectHeight( objHeight )
	self._objHeight = objHeight
end

-- 设置每行对象数
function ScrollManager:SetRowObjectCount( rowObjCount )
	self._rowObjCount = rowObjCount or 1 	--每行
end
-- 设置每个对象宽度
function ScrollManager:SetObjectWidth( objWidth )
	self._objWidth = objWidth
end

-- 设置基础x轴偏移
function ScrollManager:SetBaseX( baseX )
	self._baseX = baseX
end

-- 设置基础y轴偏移
function ScrollManager:SetBaseY( baseY )
	self._baseY = baseY
end

--设置横向
function ScrollManager:SetHorizontal( bHorizontal )
	self._isHorizontal = bHorizontal
end

-- 设置对象界面配置
function ScrollManager:SetObjectConfigFile(loadFile)
    if loadFile then
        self._loadFile = loadFile
        self:__initItemSize()
    end
end

function ScrollManager:__initItemSize()
    local function loadItemFile(csbPath)
        local layer
        if SubItemCacheCommon then
            layer = SubItemCacheCommon:GetSubItemCache(csbPath)
        end
        if not layer then
            layer = cc.CSLoader:createNode(csbPath)
        end
        return layer
    end

    if self._objWidth == nil or self._objHeight == nil then
        local layer = loadItemFile(self._loadFile)
        local contentSize = layer:getContentSize()
        self._objWidth = self._objWidth or contentSize.width
        self._objHeight = self._objHeight or contentSize.height
    end
end

-- 设置对象自定义控制器
function ScrollManager:SetObjectCustomControlClass( controlClass )
	self._objectCustomControlClass = controlClass
end

-- 注册对象数量获取接口
function ScrollManager:Register_ObjectFunc_GetCount( func, ... )
	self._onGetObjCount = packFunction(func, ...)
end

function ScrollManager:__getObjCount()
    if self._onGetObjCount then
        return self._onGetObjCount()
    else
        return self:__defaultGetObjCount()
    end
end

function ScrollManager:__defaultGetObjCount()
    return table.getCount(self:__getObjInfo())
end

-- 注册所有可显示对象信息列表获取接口
function ScrollManager:Register_ObjectFunc_GetAllInfo( func, ... )
	self._onGetInfoList = packFunction(func, ...)
end
-- 注册对象信息数据索引获取接口, 需要接收参数(index), 默认返回一样的index
function ScrollManager:Register_ObjectFunc_GetDataIndex( func, ... )
	self._onGetObjectDataIndex = packFunction(func, ...)
end

-- 注册对象显示索引获取接口 需要接收参数(index, count)
function ScrollManager:Register_ObjectFunc_GetListByIndex( func, ... )
	self._onGetObjIndexList = packFunction(func, ...)
end

function ScrollManager:__getListByIndex(iIndex, iCount)
    if self._onGetObjIndexList then
        return self._onGetObjIndexList(iIndex, iCount)
    else
        return self:__defaultGetListByIndex(iIndex, iCount)
    end
end

function ScrollManager:__defaultGetListByIndex(iIndex, iCount)
    return table.getSortListByRange(self:__getObjInfo(), iIndex, iCount, function(iCurIndex, iNextIndex)
        return iCurIndex < iNextIndex
    end)
end

-- 注册对象页码现实接口 需要接收参数(pageindex, pagecount)
function ScrollManager:Register_ObjectFunc_OnPageInfo( func, ... )
	self._onShowPageInfo = packFunction(func, ...)
end


-- 获取界面配置
function ScrollManager:Register_ObjectFunc_OnGetConfig( func, ... )
	self._getConfig = packFunction(func, ...)
end

--滚动到底部回调
function ScrollManager:Register_ObjectFunc_OnBounceBottom(func, ... )
	self._onBounceBottom = packFunction(func, ...)
end

function ScrollManager:Register_ObjectFunc_OnScrollToLeftEnd(func, ... )
	self._onScrollToLeftEnd = packFunction(func, ...)
end

function ScrollManager:Register_ObjectFunc_OnScrollToRightEnd(func, ... )
	self._onScrollToRightEnd = packFunction(func, ...)
end


-- 注册对象滚动成滑到最上面接口
function ScrollManager:Register_ObjectFunc_OnBounceTop(func, ... )
	self.__onBounceTop = packFunction(func, ...)
end

-- -- 设置显示对象动作
-- function ScrollManager:SetBShowObjectAction(bShowObjectAction)
-- 	self._bShowObjectAction = bShowObjectAction
-- end

function ScrollManager:SetShowPageInfo( sControlName, sFmt)
	self._bShowPage = true
	self._sShowPageControlName = sControlName
	self._sShowPageFmt = sFmt
end

--设置滑动条对象信息
function ScrollManager:SetSliderInfo( sliderObj, minPercent, initScale, bAutoHidden )
	self._fInitScale = initScale or 1
	self._pSliderObj = sliderObj
	self._fSliderMinPercent = minPercent
	self._fSliderMaxPercent = 100 - minPercent
	self._sliderSize = self._pSliderObj:getContentSize()
	self._fSliderRealMinPercent = self._fSliderMinPercent
	self._fSliderRealMaxPercent = self._fSliderMaxPercent
	self._bAutoHidden = bAutoHidden
end

---------------------------------------------------------------------------
function ScrollManager:__setSliderInfo()
	if not self._pSliderObj then
		return
	end

	-- 设置了自动隐藏的情况下 在内容不足一页时 将滑动条隐藏
	if self._bAutoHidden then
		self._pSliderObj:setVisible(self:IsCanScroll())
	end

	-- self._pSliderObj:setScale(self._fInitScale)
	self._pSliderObj:setContentSize(self._sliderSize)
	local curInnerSize = self._scroll:getInnerContainerSize()
	local sliderSize = self._pSliderObj:getContentSize()
	-- local scale = (sliderSize.width / curInnerSize.height) * self._fInitScale
	-- self._pSliderObj:setContentSize(cc.size(curInnerSize.height, sliderSize.height))
	-- self._pSliderObj:setScaleX(scale)
	self._pSliderObj:setPercent(self._fSliderMinPercent)
	self._fSliderRealMinPercent = self._fSliderMinPercent
	self._fSliderRealMaxPercent = 100 - self._fSliderMinPercent
end

function ScrollManager:__setSliderPercent( ... )
	if not self._pSliderObj then
		return
	end

	local curInnerSize = self._scroll:getInnerContainerSize()
	local addHeight = (curInnerSize.height - self._innerHeight)
	if addHeight <= 0 then
		return
	end
	local posx, posy = self._innerContainer:getPosition()
	local percent = self._fSliderRealMinPercent + ((addHeight + posy) / addHeight) * (self._fSliderRealMaxPercent - self._fSliderRealMinPercent)
	percent = math.max(self._fSliderRealMinPercent, percent)
	percent = math.min(self._fSliderRealMaxPercent, percent)
	self._pSliderObj:setPercent(percent)
end

--是否可以滚动
function ScrollManager:IsCanScroll( ... )
	local curInnerSize = self._scroll:getInnerContainerSize()
	local addHeight = (curInnerSize.height - self._innerHeight)
	if addHeight <= 0 then
		return false
	end
	return true
end

-- 不建议使用 命名和实际功能有冲突 todo 修改
function ScrollManager:SetScrollEnabled( bEnable )
	local bBounceEnable = self._scroll:isBounceEnabled()
	if bBounceEnable then
		self._scroll:setEnabled(bEnable)
	end
end

-- 设置滚动到边缘时 是否可以继续滚动并发生回弹
function ScrollManager:SetBounceEnabled( bEnable )
    self._scroll:setBounceEnabled(bEnable)
end

--滚动层注册事件
function ScrollManager:__scrollRegisterEvent()
	local function callBack(sender, eventType)
		if eventType == ccui.ScrollviewEventType.scrollToTop then
			-- com.debug("--------scrollToTop----------")
			if self.__onScrollToTop then
				self:__onScrollToTop()
			end
		elseif eventType == ccui.ScrollviewEventType.scrollToBottom then
			-- com.debug("--------scrollToBottom----------")
			if self.__onScrollToBottom then
				self:__onScrollToBottom()
			end
		elseif eventType == ccui.ScrollviewEventType.scrollToLeft then
			-- com.debug("--------scrollToLeft----------")
			if self.__onScrollToLeft then
				self:__onScrollToLeft()
			end
		elseif eventType == ccui.ScrollviewEventType.scrollToRight then
			-- com.debug("--------scrollToRight----------")
			if self.__onScrollToRight then
				self:__onScrollToRight()
			end
		elseif eventType == ccui.ScrollviewEventType.scrolling then
			-- com.debug("--------scrolling----------")
			if self.__onScrolling then
				self:__onScrolling()
			end
			self:__setSliderPercent()
		elseif eventType == ccui.ScrollviewEventType.bounceTop then
			-- com.debug("--------bounceTop----------")
			if self.__onBounceTop then
				self:__onBounceTop()
			end
		elseif eventType == ccui.ScrollviewEventType.bounceBottom then
			-- com.debug("--------bounceBottom----------")
			if self.__onBounceBottom then
				self:__onBounceBottom()
			end
		elseif eventType == ccui.ScrollviewEventType.bounceLeft then
			-- com.debug("--------bounceLeft----------")
			if self.__onBounceLeft then
				self:__onBounceLeft()
			end
		elseif eventType == ccui.ScrollviewEventType.bounceRight then
			-- com.debug("--------bounceRight----------")
			if self.__onBounceRight then
				self:__onBounceRight()
			end
		elseif eventType == ccui.ScrollviewEventType.scrollToLeftEnd then		
			-- com.debug("-------__onScrollToLeftEnd---------")
			if self.__onScrollToLeftEnd then
				self:__onScrollToLeftEnd()
			end
		elseif eventType == ccui.ScrollviewEventType.scrollToRightEnd then
			-- com.debug("-------__onScrollToRightEnd---------")
			if self.__onScrollToRightEnd then
				self:__onScrollToRightEnd()
			end	
		end
	end

	if self._win.InsertRegisterControl then
		self._win:InsertRegisterControl( self._scroll )
	end
	self._scroll:addEventListener(callBack)
end

function ScrollManager:__onBounceBottom()
	if self._onBounceBottom then
		self._onBounceBottom()
	end
end


function ScrollManager:__onScrollToLeftEnd()
	self:__showPageInfo(false)
	if self._onScrollToLeftEnd then
		self._onScrollToLeftEnd()
	end
end

function ScrollManager:__onScrollToRightEnd()
	self:__showPageInfo(true)
	if self._onScrollToRightEnd then
		self._onScrollToRightEnd()
	end
end

function ScrollManager:__showPageInfo(isRight)
	if not self._pageObjCount then
		return
	end
	local lastIndex = self._pageIndex
	self._pageIndex = self._pageIndex + ((isRight and 1) or -1)
	if self._pageIndex > self._pageCount then
		self._pageIndex = self._pageCount
		return
	elseif self._pageIndex <= 0 then
		self._pageIndex = 1
		return
	end
	if lastIndex ~= self._pageIndex then
		self:__showScrollInfo(self._pageIndex)
	end
	if self._pageCount > 1 then
		self:runScrollAction(isRight)
	end
end

-- 设置滚动方向
-- cc.SCROLLVIEW_DIRECTION_NONE = -1
-- cc.SCROLLVIEW_DIRECTION_HORIZONTAL = 0
-- cc.SCROLLVIEW_DIRECTION_VERTICAL = 1
-- cc.SCROLLVIEW_DIRECTION_BOTH  = 2
function ScrollManager:setScrollDirection( viewDirection )
	if self._scroll then
		self._scroll:setDirection(viewDirection)
	end
end

function ScrollManager:runScrollAction( isRight )
	self._scroll:stopAllActions()
	if isRight then
		self._scroll:setPosition(cc.p(640, self._scrollPos.y))
	else
		self._scroll:setPosition(cc.p(-640, self._scrollPos.y))
	end
	local moveAction = cc.MoveTo:create(0.2, self._scrollPos)
	self._scroll:runAction(moveAction)
end

function ScrollManager:Destroy(bNowRelease)
	if not bNowRelease then
		-- 先注册计时器会后执行
		RegisterTimerCall(function( )	
			com.debug("ScrollManager[%s].Destroy", self)
			--清除内存
			ImageCommon:RemoveUnusedTextures()
		end, 0)
	end

	-- 倒序销毁
	local iWidgetCount = #self._widgetObjList
	for iWidgetIndex = iWidgetCount, 1, -1 do
		local widgetObj = self._widgetObjList[iWidgetIndex]
		widgetObj:Destroy(bNowRelease, true)
	end
	if self._onOtherInfo then
		self._onOtherInfo:Destroy(bNowRelease)
	end

	self._widgetObjList = {}

	if bNowRelease then
		com.debug("ScrollManager[%s].Destroy", self)
		ImageCommon:RemoveUnusedTextures()
	end
end

function ScrollManager:__str__()
	return string.format("ScrollManager(%s)", tostring(self._name))
end


function ScrollManager:Hide(bNotRemove)
	self._scroll:setVisible(false)
	if not self._isPulldown then
		self._pulldownList = {}
	end
	self._isPulldown = false

	-- 倒序销毁
	local iWidgetCount = #self._widgetObjList
	for iWidgetIndex = iWidgetCount, 1, -1 do
		local widgetObj = self._widgetObjList[iWidgetIndex]
		widgetObj:Hide()
		if widgetObj:IsCacheWidget() and widgetObj:IsClearCacheByHide() then
			self._widgetObjList[iWidgetIndex] = nil
		end
	end
end

function ScrollManager:IsShow()
	return self._scroll:isVisible()
end

function ScrollManager:Show(pageIndex, bNotResetOffset)
	self:Hide(true)
	self._scroll:setVisible(true)

	self._pageIndex = pageIndex or 1
	-- 对象总数
	self._objCount = self:__getObjCount()

	if self._pageObjCount then
		self._pageCount = math.ceil(self._objCount / self._pageObjCount)
		if self._pageCount <= 0 then
			self._pageCount = 1
		end
		
		if self._pageIndex > self._pageCount then
			self._pageIndex = self._pageCount
		end
	end

	self:__showScrollInfo(self._pageIndex, bNotResetOffset)

	if not bNotResetOffset then
		self._lastPosx, self._lastPosy = self._innerContainer:getPosition()
		-- com.debug("last self._lastPosx = %s, self._lastPosy = %s", self._lastPosx, self._lastPosy)
	end

	--设置滑动条信息
	self:__setSliderInfo()
	-- self:ShowObjList(self._objIndexList, self._curCount)
end

-- 获取总页数
function ScrollManager:GetPageCount()
	return self._pageCount
end

-- 刷新显示
function ScrollManager:Refresh()
	self:Show(self._pageIndex, true)
end


-- 显示单页滚动信息
function ScrollManager:__showScrollInfo(pageIndex, bNotResetOffset)
	com.debug("pageIndex = ", pageIndex)
	--self._scroll:getInnerContainer():setPosition(self._lastPos)
	if self._bShowPage then
		-- 显示卡牌页码标签
		self._win:setLabelValue(self._sShowPageControlName, string.format(self._sShowPageFmt, pageIndex, self._pageCount))
	end

	local pageObjCount = self._pageObjCount or 0
	local index = pageObjCount * (pageIndex - 1) + 1
	-- 显示的卡牌数量
	self._curCount = self._objCount - index + 1
	if self._pageObjCount and self._curCount > self._pageObjCount then
		self._curCount = self._pageObjCount
	end
	--横向滚动
	if self._isHorizontal then
		-- 设置内容大小
		local width = math.max(self._innerWidth, self._baseX + self._curCount * self._objWidth)
		self._scroll:setInnerContainerSize(cc.size(width, self._innerHeight))
	else
		if self._onOtherInfo then
			--com.info("self._onOtherInfo", self._onOtherInfo)
			self._descriptNodeHigeht = self._onOtherInfo:GetContentSize().height + 40
		end

		--判断是否有下拉框
		com.debug("self._pulldownList = ", self._pulldownList)
		if table.isNotEmpty(self._pulldownList) then
			local curIndex, addHeight = table.getFirst(self._pulldownList)
			self._baseY = self._baseY + addHeight
		end
		self._baseY = self._objHeight * math.ceil(self._curCount / self._rowObjCount) + self._descriptNodeHigeht
		
		self._baseY = math.max(self._baseY, self._innerHeight)

		self._scroll:setInnerContainerSize(cc.size(self._innerWidth, self._baseY))

	end

	-- self._lastPosx, self._lastPosy = self._innerContainer:getPosition()
	-- com.debug("self._lastPosx = %s, self._lastPosy = %s", self._lastPosx, self._lastPosy )
	--self._lastPos = cc.p(self._scroll:getInnerContainer():getPosition())
	-- 获取第n个起卡牌
	-- com.debug("cardInfoList = ", cardInfoList)
	com.debug("index = %s, count = %s", index, self._curCount)
	self._objIndexList = self:__getListByIndex(index, self._curCount)

	self:ShowObjList(self._objIndexList, self._curCount)


	if self._onShowPageInfo then
		self._onShowPageInfo(pageIndex, self._pageCount)
	end
	if not bNotResetOffset then
		self:ResetScroll()
	end

end

function ScrollManager:ReShowWithoutSort()
	self:ShowObjList(self._objIndexList, self._curCount)
end


-- 获取列表元素对象
function ScrollManager:GetListElementByIndex(index, isDesc)
	-- 倒序序号
	if isDesc then
		index = self._curCount - index + 1
	end
	com.debug("self._widgetObjList = ", self._widgetObjList, index)
	local widgetObj = self._widgetObjList[index]
	return widgetObj
end

-- 获取单个对象信息页面
function ScrollManager:__getSingleObjControl(index)
	local posX = self._baseX + self._objWidth * math.mod(index-1, self._rowObjCount)
	local posY = self._baseY - self._objHeight * math.ceil(index / self._rowObjCount)

	--只支持横向滚动
	if self._isHorizontal then
		posX = self._baseX + self._objWidth * (index - 1)
		posY = self._baseY
	end
	if table.isNotEmpty(self._pulldownList) then
		local curIndex, addHeight = table.getFirst(self._pulldownList)
		if index > curIndex then
			posY = posY - addHeight
		end
	end
-- com.info("__getSinagleCardControl index(%s) posY(%s)",index, posY)	
	if self._widgetObjList[index] then
		self._widgetObjList[index]:SetPosition(posX, posY)
	else
		local tab = {}
		tab["FilePath"]= self._loadFile
		tab["layer"] = self._scroll
		tab["pos_x"] = posX
		tab["pos_y"] = posY
		tab["win"] = self._win
		tab["windowName"] = self._name
		tab["bAdaptWidth"] = self._bAdaptWidth
		tab["bAdaptHeight"] = self._bAdaptHeight
		local widgetObj
		if self._objectCustomControlClass then
			widgetObj = self._objectCustomControlClass.new(tab, self)
		else
			widgetObj = WidgetManager.new(tab)
		end
		self._widgetObjList[index] = widgetObj
		-- 设置隐藏界面时缓存清理模式
		widgetObj:SetClearCacheModeByHide(self._bClearCacheByHide)
	end
	return self._widgetObjList[index]
end

-- 设置隐藏界面时缓存清理模式
function ScrollManager:SetClearCacheModeByHide( bClearCacheByHide )
	self._bClearCacheByHide = bClearCacheByHide
end


-- 显示单个卡牌信息
function ScrollManager:__showSingleObjInfo(index, singleLineInfo, singleLineID)
	--com.info("__showSingleObjInfo")

	local widgetObj = self:__getSingleObjControl(index)

	local dataIndex = self:__getObjectDataIndex(singleLineID)

	-- 记录数据
	widgetObj:SetData(dataIndex, singleLineID, index)
	widgetObj:Show(singleLineInfo)
end

-- 显示卡牌信息列表
function ScrollManager:ShowObjList(objIndexList, count)
	--显示好友界面信息
	local objInfoList = self:__getObjInfo()
	local curIndex = 0
	local curPosIndex = 1
	-- com.info("ShowObjList objIndexList: ", objIndexList)
	-- 显示卡牌信息
	for curIndex, objIndex in pairs(objIndexList) do
		local objInfo = objInfoList[objIndex]
		-- com.info("ShowObjList(curIndex = %s, objIndex = %s) = %s", curIndex, objIndex, objInfo)
		
		-- -- 显示动作
		-- if self._bShowObjectAction then
			
		-- 	self:SetScrollOffsetByIndex(curPosIndex)
		-- end

		curPosIndex = curPosIndex + 1

		self:__showSingleObjInfo(curIndex, objInfo, objIndex)
	end
	-- 隐藏剩余
	local controlCount = table.getCount(self._widgetObjList)
	if count < controlCount then
		-- 倒序
		local iWidgetCount = #self._widgetObjList
		for iWidgetIndex = iWidgetCount, count + 1, -1 do
			local widgetObj = self._widgetObjList[iWidgetIndex]

			-- local widgetObj = self:__getSingleObjControl(iWidgetIndex)
			widgetObj:Hide()
			if widgetObj:IsCacheWidget() and widgetObj:IsClearCacheByHide() then
				self._widgetObjList[iWidgetIndex] = nil
			end
		end
	end
	if self._onOtherInfo then
		local posy = self._baseY - table.getCount(objIndexList) * self._objHeight - self._descriptNodeHigeht
		local posx = 0
		self._onOtherInfo:SetPosition(posx, posy)
	end
end

--获取卡牌信息
function ScrollManager:__getObjInfo()
	if self._onGetInfoList then
		--com.info("__getObjInfo ", self._onGetCardInfo())
		return self._onGetInfoList()
	else
		return DataMgr:getPlayerData("CardInfo")
	end
end

-- 遍历对象信息列表
function ScrollManager:MapObjList(mapFunc, window, ...)
	for index = 1, self._curCount do
		local widgetObj = self._widgetObjList[index]
		local objIndex = self._objIndexList[index]
		mapFunc(window, widgetObj, objIndex, ...)
	end
end

--刷新当前页面
function ScrollManager:RefreshCurPage( ... )
	self:Show( self._pageIndex )
end

--获取每一行的配置信息
function ScrollManager:__getLineConfig(singleLineInfo)
	if self._getConfig then
		return self._getConfig(singleLineInfo)
	end
	return nil
end

-- 获取对象数据索引
function ScrollManager:__getObjectDataIndex( singleLineIndex )
	if self._onGetObjectDataIndex then
		return self._onGetObjectDataIndex(singleLineIndex)
	end
	return singleLineIndex
end

--设置显示下拉框
function ScrollManager:SetPulldownList(widgetObj, descBox, height)
	if descBox:isVisible() then
		descBox:setVisible(false)
	end
	com.debug("SetPulldownList index", index)
	local index = table.indexOf(self._widgetObjList, widgetObj)
	local curIndex, addHeight = table.getFirst(self._pulldownList)
	if curIndex ~= index or addHeight == 0 then
		descBox:setVisible(true)
		self._pulldownList = {}
		if index then
			self._pulldownList[index] = height - 15
		end	
	else
		self._pulldownList[index] = 0
	end
	self._isPulldown = true
	self:Refresh()
	local pos_x, pos_y = widgetObj:GetPosition()
	pos_x = pos_x + widgetObj:GetControlOriginalSize("achieveBackground").width / 2
	pos_y = pos_y + 15
	descBox:setPosition(cc.p(pos_x, pos_y))
end

--重置滚动位置
function ScrollManager:ResetScroll( ... )
	local posx, posy = self._innerContainer:getPosition()
	if self._isHorizontal then
		self._innerContainer:setPosition(posx, posy)
	else
		if self._baseY ~= self._innerHeight then
			self._innerContainer:setPosition(posx, self._innerHeight - self._baseY)
			self._scroll:jumpToTop()
		end
	end
end

-- 设置指定索引偏移
function ScrollManager:SetScrollOffsetByIndex(index)
	index = index - 1
	local lastPosy = self._lastPosy + index * self._objHeight
	-- com.debug("lastPosx = %s, lastPosy = %s", self._lastPosx, lastPosy)
	if lastPosy > 0 then
		lastPosy = 0
	end
	self._innerContainer:setPosition(self._lastPosx, lastPosy)
end

-- 设置移动到指定索引偏移
function ScrollManager:MoveScrollOffsetByIndex(index, bNotCheck)
	if (index <= 2) and (not bNotCheck) then
		return
	end
	index = index - 1
	local lastPosy = self._lastPosy + index * self._objHeight
	-- com.debug("lastPosx = %s, lastPosy = %s", self._lastPosx, lastPosy)
	if lastPosy > 0 then
		lastPosy = 0
	end

	index = math.max(0, index - 1)
	local oldLastPosy = self._lastPosy + index * self._objHeight
	if oldLastPosy > 0 then
		oldLastPosy = 0
	end

	local function onActionEnd( ... )
		self:__setSliderPercent()
	end
	local action = cc.MoveBy:create(0.1, cc.p(0, math.max(self._objHeight, lastPosy - oldLastPosy)))
	
	action = AnimationCommon:getCallBackAction(action, onActionEnd)
	self._innerContainer:runAction(action)
	
end


--预先创建条目缓存
function ScrollManager:PreCreateItemCache()
	-- local pageObjCount = self._pageObjCount
	-- if not pageObjCount or pageObjCount > 15 then
	-- 	pageObjCount = 15
	-- end
	-- -- 显示卡牌信息
	-- for index = 1, pageObjCount do
	-- 	local tab = {}
	-- 	tab["FilePath"]= self._loadFile
	-- 	tab["layer"] = self._scroll
	-- 	tab["pos_x"] = 0
	-- 	tab["pos_y"] = 0
	-- 	tab["win"] = self._win
	-- 	tab["windowName"] = self._name
	-- 	local widgetObj
	-- 	if self._objectCustomControlClass then
	-- 		widgetObj = self._objectCustomControlClass.new(tab, self)
	-- 	else
	-- 		widgetObj = WidgetManager.new(tab)
	-- 	end
	-- 	self._widgetObjList[index] = widgetObj
	-- end
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
local NeedMoveDis = 60

--自定义滚动条目管理器
SingleDefineItemControl = class(WidgetManager)
----------------------------------------------------------
----------------------------------------------------------
	-- self._dataIndex = dataIndex
	-- self._singleLineIndex = singleLineIndex
function SingleDefineItemControl:OnCreate( ... )
	self._index = nil
	self._needScaleBig = false
	self._bInAction= false
	self:SetScale(0.7)
	self._mAction = nil
	self._bNew = false
end

function SingleDefineItemControl:Show( dataInfo )
	self._dateInfo = dataInfo
	self._bInAction = false
	self._mAction = nil
	self._bNew = false

	-- 父类方法
    super(SingleDefineItemControl).Show(self, dataInfo)
end

function SingleDefineItemControl:SetPosList( posList )
	self._posList = posList
end

function SingleDefineItemControl:SetInAction( bAction )
	self._bInAction = bAction
end

function SingleDefineItemControl:IsInAction( ... )
	return self._bInAction
end

function SingleDefineItemControl:SetScale( scale )
	self._layer:setScale(scale)
end

function SingleDefineItemControl:GetScale()
	return self._layer:getScale()
end

function SingleDefineItemControl:SetIndex(index )
	self._index = index
end

function SingleDefineItemControl:GetIndex()
	return self._index
end

function SingleDefineItemControl:SetAction( action )
	self._mAction = action
end

function SingleDefineItemControl:GetAction()
	return self._mAction
end

function SingleDefineItemControl:GetIsNew( ... )
	return self._bNew
end

function SingleDefineItemControl:__onMoveUp( ... )
	-- body
end


function SingleDefineItemControl:__onMoveDown( ... )
	-- body
end

--向上移动
function SingleDefineItemControl:MoveUp(bChangeDir, isCheck, yDis)
	local posx, posy = self:GetPosition()
	if not isCheck and (posy - self._posList[self._index].y) >= 42 then
		self:SetPosition(self._posList[self._index].x + 70, self._posList[self._index].y + 42)
		if self._index == 1 then
			self:SetPosition(self._posList[self._index].x + 3, self._posList[self._index].y + 42)
		end
		return
	end

	local newPosx = posx - 5 * yDis / 3
	if self._index == 1 then
		newPosx = math.max(self._posList[self._index].x, (posx - 0.1*yDis))
		if posy >= self._posList[self._index].y then
			newPosx = posx + 0.1*yDis
		end
	elseif self._index > 1 then
		newPosx = posx + 5 * yDis / 3	
	end

	self:SetPosition(newPosx , posy + yDis)

	if posy >= self._posList[self._index].y then
		self._needScaleBig = false
	end

	if self._index == 1 then
		local scale = self:GetScale()
		if bChangeDir then
			if self._needScaleBig then
				if posy < self._posList[self._index].y then
					self._needScaleBig = true
				end
			else
				self._needScaleBig = true
			end
		end

		if self._needScaleBig then
			scale = math.min(1, scale + math.abs(yDis) * 0.2 / (84 - NeedMoveDis))
			self:SetScale(scale)
		else
			scale = math.max(0.85, scale - math.abs(yDis) * 0.2 / NeedMoveDis)
			self:SetScale(scale)
		end
	end
	
	if isCheck then
		self:__checkUpCanChangePos(posy + yDis)
	end
end
	
function SingleDefineItemControl:__checkUpCanChangePos( posy )
	local moveDis = (posy - self._posList[self._index].y)
	--com.debug("-------MoveUp------moveDis---------", moveDis)
	if moveDis >= NeedMoveDis then
		local pos = self._posList[self._index+1]
		if self._index == 1 then
			self:SetScale(0.7)
			self:SetPosition(pos.x-(140*(84 - moveDis)/84), pos.y-(84 - moveDis))
		end
		if self._index == 0 then
			self:SetScale(0.85)
			self:SetPosition(pos.x-6, pos.y-(84 - moveDis))
			self._needScaleBig = true	
		end
		self._index = self._index + 1
		self:__onMoveUp()
		self:OnShow(self._dateInfo)
	end
end

--向下移动
function SingleDefineItemControl:MoveDown(bChangeDir, isCheck, yDis)
	local posx, posy = self:GetPosition()
	if not isCheck and (posy - self._posList[self._index].y) <= - 42 then
		self:SetPosition(self._posList[self._index].x + 70, self._posList[self._index].y - 42)
		if self._index == 1 then
			self:SetPosition(self._posList[self._index].x + 3, self._posList[self._index].y - 42)
		end
		return
	end

	local newPosx = posx + 5 * yDis / 3
	if self._index == 1 then
		newPosx = math.max(self._posList[self._index].x, (posx - 0.1*yDis))
		if posy <= self._posList[self._index].y then
			newPosx = posx + 0.1*yDis
		end
	elseif self._index > 1 then
		newPosx = posx - 5*yDis/3
	end

	self:SetPosition( newPosx, posy - yDis)

	if posy <= self._posList[self._index].y then
		self._needScaleBig = false
	end

	if self._index == 1 then
		local scale = self:GetScale()
		if bChangeDir then
			if self._needScaleBig then
				if posy > self._posList[self._index].y then
					self._needScaleBig = true
				end
			else
				self._needScaleBig = true
			end
		end
		if self._needScaleBig then
			scale = math.min(1, scale + math.abs(yDis) * 0.2 / (84 - NeedMoveDis))
			self:SetScale(scale)
		else
			scale = math.max(0.85, scale - math.abs(yDis) * 0.2 / NeedMoveDis)
			self:SetScale(scale)
		end
	end


	if isCheck then
		self:__checkDownCanChangePos(posy - yDis)
	end
end


function SingleDefineItemControl:__checkDownCanChangePos( posy )
	local moveDis = (posy - self._posList[self._index].y)
	--com.debug("-------MoveDown------moveDis---------", moveDis)
	if moveDis <= -NeedMoveDis then
			local pos = self._posList[self._index-1]
			if self._index == 1 then
				self:SetScale(0.7)
				self:SetPosition(pos.x-(140*(84-math.abs(moveDis))/84), pos.y+(84-math.abs(moveDis)))
			end
			if self._index == 2 then
				self:SetScale(0.85)
				self:SetPosition(pos.x-6, pos.y+(84-math.abs(moveDis)))
				self._needScaleBig = true
			end
		self._index = self._index - 1
		self:__onMoveDown()
		self:OnShow(self._dateInfo)
	end

end

function SingleDefineItemControl:ResetPos()
	self._needScaleBig = false
	local pos = self._posList[self._index]
	if self._index == 1 then
		self:SetScale(1)
	end
	
	if self._index == -2 or self._index == 4 then
		self._bInAction = true
		local posx, posy = self:GetPosition()
		self:SetPosition(posx, pos.y)
        local function callBack(...)
            self._bInAction = false
        end
		local action = cc.MoveTo:create(0.1, cc.p(1150, pos.y))
		action = AnimationCommon:getCallBackAction(action, callBack)
		self._layer:runAction(action)
	else
		self:SetPosition(pos.x, pos.y)	
	end
end

function SingleDefineItemControl:StartTouch()
	local pos = self._posList[self._index]
	if self._index == -2 or self._index == 4 then
		 self:SetPosition(pos.x, pos.y)
	end
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--自定义圆圈滚动
--圆圈滚动管理器
CircleScrollManager = class()
function CircleScrollManager:ctor(window, layer, touchLayer)
	self._win = window
	self._name = window.name
	self._widgetObjList = {}
	self._controlList = {}
	self._layer = layer
	self._touchLayer = touchLayer

	self._curShowIndex = 1
	self._bSpecial = false

	self:__registerTouchLayer()
end

function CircleScrollManager:SetSpecial( bSpecial )
	self._bSpecial = bSpecial
end

function CircleScrollManager:SetBasePos(x, y)
	self._basePosx, self._basePosy = x, y
end

function CircleScrollManager:SetBaseDis(xDis, yDis)
	self._xDis, self._yDis = xDis, yDis
end

--每个对象高度
function CircleScrollManager:SetObjectHeight( objHeight )
	self._objHeight = objHeight
end

-- 设置对象界面配置
function CircleScrollManager:SetObjectConfigFile( loadFile )
	self._loadFile = loadFile
end
-- 设置对象自定义控制器
function CircleScrollManager:SetObjectCustomControlClass( controlClass )
	self._objectCustomControlClass = controlClass
end

-- 注册对象数量获取接口
function CircleScrollManager:Register_ObjectFunc_GetCount( func, ... )
	self._onGetObjCount = packFunction(func, ...)
end
-- 注册所有可显示对象信息列表获取接口
function CircleScrollManager:Register_ObjectFunc_GetAllInfo( func, ... )
	self._onGetInfoList = packFunction(func, ...)
end
-- 注册对象信息数据索引获取接口, 需要接收参数(index), 默认返回一样的index
function CircleScrollManager:Register_ObjectFunc_GetDataIndex( func, ... )
	self._onGetObjectDataIndex = packFunction(func, ...)
end

-- 注册对象显示索引获取接口 需要接收参数(index, count)
function CircleScrollManager:Register_ObjectFunc_GetListByIndex( func, ... )
	self._onGetObjIndexList = packFunction(func, ...)
end

--设置当前要显示的条目索引
function CircleScrollManager:SetCurShowItemIndex( index )
	self._curShowIndex = index
end

function CircleScrollManager:Register_ObjectFunc_OnTounchBegan( func, ... )
	self._onTounchBegan = packFunction(func, ...)
end

function CircleScrollManager:Register_ObjectFunc_OnTounchMoved( func, ... )
	self._onTounchMoved = packFunction(func, ...)
end

function CircleScrollManager:Register_ObjectFunc_OnTounchEnd( func, ... )
	self._onTounchEnd = packFunction(func, ...)
end

function CircleScrollManager:Register_ObjectFunc_OnActionEnd( func, ... )
	self._onActionEnd = packFunction(func, ...)
end




--显示
function CircleScrollManager:Show( ... )
	self:Hide()
-- if self._listener then
-- self._listener:setEnabled(true)
-- end
	-- 对象总数
	self._objCount = self._onGetObjCount()
	self._posList = {}
	local downIndex = 1

	for idx=1, self._objCount do
		downIndex = downIndex - 1
		if self._bSpecial then
			if idx == 2 then
				self._posList[idx] = cc.p(self._basePosx + 10, self._basePosy + 100)
			elseif idx == 1 then
				self._posList[idx] = cc.p(self._basePosx, self._basePosy)
			else
				self._posList[idx] = cc.p(self._basePosx + 10 + (idx-2) * self._xDis, self._basePosy + 100 + (idx-2) * self._yDis)
			end

			if downIndex == 0 then
				self._posList[downIndex] = cc.p(self._basePosx + 10, self._basePosy - 100)
			else
				self._posList[downIndex] = cc.p(self._basePosx + 10 + math.abs(downIndex * self._xDis), self._basePosy - 100 - math.abs(downIndex * self._yDis))
			end
		else
			self._posList[idx] = cc.p(self._basePosx + (idx - 1) * self._xDis, self._basePosy + (idx - 1) * self._yDis)
			self._posList[downIndex] = cc.p(self._basePosx + idx * self._xDis, self._basePosy - idx * self._yDis)
		end
	end

	local objIndexList = self._onGetObjIndexList()
	
	self._controlList = {}

	self:ShowItemList(objIndexList, self._objCount)
end

function CircleScrollManager:Hide( ... )
	-- 倒序
	local iWidgetCount = #self._widgetObjList
	for iWidgetIndex = iWidgetCount, 1, -1 do
		local widgetObj = self._widgetObjList[iWidgetIndex]
		if widgetObj:GetAction() then
			widgetObj:GetControl():stopAction(widgetObj:GetAction())
			widgetObj:SetAction()
		end
		widgetObj:Hide()
	end
	self._controlList = {}
	if self._listener then
		self._listener:setEnabled(false)
	end
end

function CircleScrollManager:Destroy(bNowRelease)
	if not bNowRelease then
		-- 先注册计时器会后执行
		RegisterTimerCall(function( )	
			com.debug("CircleScrollManager[%s].Destroy wait", self)
			--清除内存
			ImageCommon:RemoveUnusedTextures()
		end, 0)
	end

	self._eventDispatcher:removeEventListener(self._listener)
	self._listener = nil

	-- 倒序销毁
	local iWidgetCount = #self._widgetObjList
	for iWidgetIndex = iWidgetCount, 1, -1 do
		local widgetObj = self._widgetObjList[iWidgetIndex]
		widgetObj:Destroy(bNowRelease, true)
	end
	self._widgetObjList = {}
	
	if bNowRelease then
		com.debug("CircleScrollManager[%s].Destroy", self)
		ImageCommon:RemoveUnusedTextures()
	end
end

-- 显示单个条目信息
function CircleScrollManager:__showSingleItemInfo(index, singleLineInfo, singleLineID)
	local widgetObj = self:__getSingleItemControl(index)

	widgetObj:SetPosList(self._posList)
	-- 记录数据
	widgetObj:SetData(singleLineID, singleLineID)

	widgetObj:Show(singleLineInfo)
	widgetObj:GetControl():setVisible(false)
end

-- 显示条目信息列表
function CircleScrollManager:ShowItemList(objIndexList, count)
	--显示好友界面信息
	local objInfoList = self:_onGetInfoList()

	-- 显示卡牌信息
	for curIndex, objIndex in ipairs(objIndexList) do
		local objInfo = objInfoList[objIndex]
		self:__showSingleItemInfo(curIndex, objInfo, objIndex)
	end

	-- 隐藏剩余
	local controlCount = #self._widgetObjList
	if count < controlCount then
		-- 倒序处理
		for curIndex = controlCount, count + 1, -1 do
			self._widgetObjList[curIndex]:Hide()
		end
	end

end


-- 获取单个对象信息页面
function CircleScrollManager:__getSingleItemControl(index)
	local curIndex = self._curShowIndex - index + 1
	local pos = self._posList[curIndex]
	if not pos then
		com.error("当前设置显示索引（%s）副本条目位置不存在", self._curShowIndex)
		return
	end
	if self._widgetObjList[index] then
		self._widgetObjList[index]:SetPosition(pos)
	else
		local tab = {}
		tab["FilePath"]= self._loadFile
		tab["layer"] = self._layer
		tab["pos_x"] = pos.x
		tab["pos_y"] = pos.y
		tab["win"] = self._win
		tab["windowName"] = self._name
		tab["AnchorPoint"] = cc.p(1, 0.5)
		local widgetObj
		if self._objectCustomControlClass then
			widgetObj = self._objectCustomControlClass.new(tab, self)
		else
			widgetObj = SingleDefineItemControl.new(tab)
		end
		self._widgetObjList[index] = widgetObj
	end

	table.insert(self._controlList, self._widgetObjList[index])
	self._widgetObjList[index]:SetIndex(curIndex)
	if curIndex == 1 then
		self._widgetObjList[index]:SetScale(1)
	else
		self._widgetObjList[index]:SetScale(0.7)
	end

	return self._widgetObjList[index]
end


--注册层触摸
function CircleScrollManager:__registerTouchLayer()
	local size = self._touchLayer:getContentSize()
	local posx, posy = self._touchLayer:getPosition()
	local touchRect = cc.rect(posx, posy, size.width, size.height)
	local function onTouchBegan(touch, event)
		self._bMove = false		
		local location = touch:getLocation()
		self._startY = location.y
		if not cc.rectContainsPoint(touchRect, cc.p(location.x, location.y)) then
			return false
		end
     	return self:__onTouchBegan(location.x, location.y) 
	end
	local function onTouchMoved(touch, event)
		local location = touch:getLocation()
		if not cc.rectContainsPoint(touchRect, cc.p(location.x, location.y)) then
			return false
		end
		local delta = touch:getDelta()
		self._bChangeDir = false
		local moveY = location.y - self._startY
		if math.abs(moveY) >= 5 then
			self._bMove = true
		end

		if delta.y > 0 then
			if self._moveDir ~= 1 and self._moveDir ~= 0 then
				self._bChangeDir = true
			end
			self._moveDir = 1
		elseif delta.y < 0 then
			if self._moveDir ~= -1  and self._moveDir ~= 0 then
				self._bChangeDir = true
			end
			self._moveDir = -1
		end
     	return self:__onTouchMoved(location.x, location.y, math.abs(delta.y))
	end
	local function onTouchEnded(touch, event)
		local location = touch:getLocation()
     	return self:__onTouchEnded(location.x, location.y) 
	end
	self._listener = cc.EventListenerTouchOneByOne:create()
	--listener:setSwallowTouches(true)
	self._listener:registerScriptHandler(onTouchBegan, cc.Handler.EVENT_TOUCH_BEGAN)
    self._listener:registerScriptHandler(onTouchMoved, cc.Handler.EVENT_TOUCH_MOVED)
    self._listener:registerScriptHandler(onTouchEnded, cc.Handler.EVENT_TOUCH_ENDED)
    self._listener:registerScriptHandler(onTouchEnded, cc.Handler.EVENT_TOUCH_CANCELLED)
   
    self._eventDispatcher = self._touchLayer:getEventDispatcher()
    self._eventDispatcher:addEventListenerWithSceneGraphPriority(self._listener, self._touchLayer)

    if self._win.InsertRegisterControl then
    	self._win:InsertRegisterControl( self._listener )
    end

end


function CircleScrollManager:__onTouchBegan(x, y)
	for i, control in pairs(self._controlList) do
		control:StartTouch()
	end
	self._moveDir = 0

	if self._onTounchBegan then
		self._onTounchBegan(x, y)
	end
	
	return true
end

function CircleScrollManager:__onTouchMoved(x, y, yDis)
	for i, control in pairs(self._controlList) do
		if control:IsInAction() then
			return true
		end
	end
	
	if self._moveDir == 1 then		
		self:__showMoveUp(x, y, yDis)
	elseif self._moveDir == -1 then
		self:__showMoveDown(x, y, yDis)
	end

	if self._onTounchMoved then
		self._onTounchMoved(x, y)
	end

	return true
end

function CircleScrollManager:__onTouchEnded(x, y)
	if self._onTounchEnd then
		self._onTounchEnd()
	end
	for i, control in pairs(self._controlList) do
		control:ResetPos()
	end
	return true
end


function CircleScrollManager:__showMoveUp( x, y, yDis)
	local moveDis = (y - self._startY)
	local bcanNotMove = self:CheckUpCanNotMove()
	if bcanNotMove then
		for i, control in pairs(self._controlList) do
			control:MoveUp(self._bChangeDir, false, yDis)
		end
		return
	end

	for i, control in pairs(self._controlList) do
		control:MoveUp(self._bChangeDir, true, yDis)
	end

end

function CircleScrollManager:__showMoveDown( x, y, yDis)
	--local moveDis = (y - self._startY)
	local bcanNotMove = self:CheckDownCanNotMove()
	if bcanNotMove then
		for i, control in pairs(self._controlList) do
			control:MoveDown(self._bChangeDir, false, yDis)
		end
		return
	end

	for i, control in pairs(self._controlList) do
		control:MoveDown(self._bChangeDir, true, yDis)
	end
 
end

--检查是否不能移动
function CircleScrollManager:CheckUpCanNotMove()
	local bcanNotMove = true
	for i, control in pairs(self._controlList) do
		--com.debug("------control--up---index--", control:GetIndex())
		if control:GetIndex() <= 0 then
			bcanNotMove = false
			break
		end
	end

	return bcanNotMove
end

--检查是否不能移动
function CircleScrollManager:CheckDownCanNotMove()
	local bcanNotMove = true
	for i, control in pairs(self._controlList) do
		--com.debug("-------control--down---index-", control:GetIndex())
		if control:GetIndex() >= 2 then
			bcanNotMove = false
			break
		end
	end

	return bcanNotMove
end

-----------------------------------------------------
--正常条目播放显示动作
function CircleScrollManager:ShowNormalAciton()
	local index = 0
	local function onActionEnd( control )
		control:SetAction()
		index = index + 1
		if index >= table.getCount(self._controlList) then
			if self._listener then
				self._listener:setEnabled(true)
			end
			if self._onActionEnd then
				self._onActionEnd()
			end
		end
		
	end
	for i, control in pairs(self._controlList) do
		control:GetControl():setVisible(true)
		local size = control:GetContentSize()
		local curIndex = control:GetIndex()
		local pos = self._posList[curIndex]
		local xdis = size.width * control:GetScale()
		local tick = 0.15 * control:GetScale()
		control:SetPosition(pos.x + xdis, pos.y)
		--默认不显示
		local lastPosx = pos.x
		if curIndex == -2 or curIndex == 4 then
			lastPosx = 1150
		end

		local action = cc.MoveTo:create(tick, cc.p(lastPosx, pos.y))
		action = AnimationCommon:getCallBackAction(action, onActionEnd, control)
		control:SetAction(action)
		control:GetControl():runAction(action)
	end
end


--播放增加新条目动作
function CircleScrollManager:ShowNewAciton(fCallFunc)
	--分离新旧条目
	self._oldControlList = {}
	self._newControlList = {}
	local count = table.getCount(self._controlList)
	for idx = 1, count do
		local control = self._controlList[idx]
		if control:GetIsNew() then
			table.insert(self._newControlList, control)
		else
			table.insert(self._oldControlList, control)
		end
	end

	self._index = table.getCount(self._newControlList)
	--都是新条目
	if table.getCount(self._oldControlList) == 0 then
		if fCallFunc then
			fCallFunc(packFunction(self.__showSingleControl, self))
		end
		--self:__showSingleControl()
	else
		--旧条目动作结束
		local index = 0
		local function onActionEnd( control )
			control:SetAction()
			index = index + 1
			if index >= table.getCount(self._oldControlList) then
				local function onDelayActionEnd()
					control:SetAction()
					if self._index == 0 then
						if self._listener then
							self._listener:setEnabled(true)
						end
						if self._onActionEnd then
							self._onActionEnd()
						end
						return
					end
					self:__moveSingleControl()
				end
				-- local action = cc.DelayTime:create(0.5)
				-- action = AnimationCommon:getCallBackAction(action, onDelayActionEnd)
				-- control:SetAction(action)
				-- control:GetControl():runAction(action)
				if fCallFunc then
					fCallFunc(onDelayActionEnd)
				end
			end
		end

		--显示旧条目
		local controlIndex = 1
		for idx, control in pairs(self._oldControlList) do
			control:GetControl():setVisible(true)
			local size = control:GetContentSize()
			control:SetIndex(controlIndex)
			if controlIndex == 1 then
				control:SetScale(1)
			else
				control:SetScale(0.7)
			end
			control:OnShow(control._dateInfo)
			
			--条目播放动作
			local pos = self._posList[controlIndex]
			local xdis = size.width * control:GetScale()
			local tick = 0.15 * control:GetScale()
			control:SetPosition(pos.x + xdis, pos.y)
			local action = cc.MoveTo:create(tick, pos)
			action = AnimationCommon:getCallBackAction(action, onActionEnd, control)
			control:SetAction(action)
			control:GetControl():runAction(action)
			controlIndex = controlIndex - 1
		end
	end
end

--旧条目移动
function CircleScrollManager:__moveSingleControl()
	local index = 0
	local function onActionEnd( control )
		control:SetAction()
		index = index + 1
		if index >= table.getCount(self._oldControlList) then
			self:__showSingleControl()
		end
	end
	for i, control in pairs(self._oldControlList) do
		local curIndex = control:GetIndex()
		local pos = self._posList[curIndex - 1]
		control:SetIndex(curIndex - 1)
		control:OnShow(control._dateInfo)
		local action1 = cc.MoveTo:create(0.1, pos)
		local scaleAction = cc.ScaleTo:create(0.1, 0.7)
		local action = AnimationCommon:getSpawnAction({action1, scaleAction})
		action = AnimationCommon:getCallBackAction(action, onActionEnd, control)
		control:GetControl():runAction(action)
		control:SetAction(action)
	end
end

--显示条目
function CircleScrollManager:__showSingleControl()
	--没有新条目返回
	if self._index == 0 then
		return
	end
	local control = self._newControlList[self._index]

	local function onActionEnd( ... )
		control:SetAction()
		if self._index <= 0 then
			if self._listener then
				self._listener:setEnabled(true)
			end
			if self._onActionEnd then
				self._onActionEnd()
			end
			return
		end
		self:__moveSingleControl()
	end
	
	control:GetControl():setVisible(true)
	self._index = self._index - 1
	local pos = self._posList[1]
	control:SetIndex(1)
	control:SetScale(1)
	control:OnShow(control._dateInfo)
	table.insert(self._oldControlList, control)
	control:GetControl():setPosition(cc.p(pos.x + 720, pos.y))
	local action1 = cc.MoveTo:create(0.1, pos)
	local action2 = cc.DelayTime:create(0.2)
	action2 = AnimationCommon:getCallBackAction(action2, onActionEnd)
	local action = AnimationCommon:getSequenceAction({action1, action2})
	control:GetControl():runAction(action)
	control:SetAction(action)
end


-----------------------------------------------------
function CircleScrollManager:CheckIsTouchMove()
	return self._bMove
end

function CircleScrollManager:GetPosList()
	return self._posList
end

function CircleScrollManager:GetCurShowIndex( ... )
	return self._curShowIndex
end


function CircleScrollManager:GetListElementByIndex( index, isDesc )
	-- 倒序序号
	if isDesc then
		local count = self._objCount
		index = count - index + 1
	end
	com.debug("%s._widgetObjList[%s] = %s", self, index, self._widgetObjList)
	local widgetObj = self._widgetObjList[index]

	return widgetObj
end



-----------------------------------------------------------------------------------------
--子条目缓存
SubItemCacheManager = class()

function SubItemCacheManager:ctor()
	self._subItemCacheMgr = nil
end

function SubItemCacheManager:InitSubItemCache( ... )
	-- 缓存管理器
	self._subItemCacheMgr = GameObjectCacheManager.new()
	self._controlLayerSizeDict = {}
	self._controlSizeDict = {}
	self._controlScaleDict = {}
	self._controlColorDict = {}
	self._controlPosDict = {}
	self._subControlList = {}
	self._lHasInitFuncList = {}
	self._dCacheCountDict = {}
end

function SubItemCacheManager:__createSubItem( loadFile )
--##JSCodeClose##Start##--js不支持
	local fullPath = cc.FileUtils:getInstance():fullPathForFilename(loadFile)
	if not cc.FileUtils:getInstance():isFileExist(fullPath) then
		com.error("csb文件（%s）不存在", loadFile)
		return
	end
--##JSCodeClose##End##--js不支持

	local pCacheObj = cc.CSLoader:createNode(loadFile)
	if pCacheObj then
		Lua_Retain(pCacheObj, string.format("SubItemCacheManager_%s", loadFile))
	end
	pCacheObj:setVisible(false)

	--遍历节点
	self._subControlList[pCacheObj] = {}
	self:__parseNodeChild(pCacheObj, self._subControlList[pCacheObj])
	self:__init(pCacheObj)

	return pCacheObj
end

--解析子节点
function SubItemCacheManager:__parseNodeChild(pCacheObj, lCacheList)
	local childList = pCacheObj:getChildren()
	for _, control in pairs(childList) do
		self:__parseNodeChild(control, lCacheList)
		local nodeName = control:getName()	
		if string.isVail(nodeName)then
			if lCacheList[nodeName] then
				com.error("control name（%s）已被注册", nodeName)
			else
				lCacheList[nodeName] = control	
			end
		end
	end
end


--初始化大小
function SubItemCacheManager:__init( pCacheObj )
	self._controlLayerSizeDict[pCacheObj] = pCacheObj:getContentSize()
	
	self._controlSizeDict[pCacheObj] = {}
	self._controlScaleDict[pCacheObj] = {}
	self._controlColorDict[pCacheObj] = {}
	self._controlPosDict[pCacheObj] = {}
	local controlInfo = self._subControlList[pCacheObj]
	for itemName, control in pairs(controlInfo) do
		--判断是精灵才记录
		if getNodeTypeName(control) == "cc.Sprite" then
			if control.getContentSize then
				self._controlSizeDict[pCacheObj][itemName] = control:getContentSize()
			end
			if control.getScaleX and control.getScaleY then
				self._controlScaleDict[pCacheObj][itemName] = {control:getScaleX(), control:getScaleY()}
			end
		end
		if control.getColor then
			self._controlColorDict[pCacheObj][itemName] = control:getColor()
		end
		if control.getPosition then
			self._controlPosDict[pCacheObj][itemName] = cc.p(control:getPosition())
		end
	end

end

function SubItemCacheManager:__resetSize(pCacheObj)
	if not self._subControlList[pCacheObj] then
		return
	end

	if self._controlLayerSizeDict[pCacheObj] then
		pCacheObj:setContentSize(self._controlLayerSizeDict[pCacheObj])
	end

	for itemName, control in pairs(self._subControlList[pCacheObj]) do
		--判断是精灵才重设
		if getNodeTypeName(control) == "cc.Sprite" then
			if control.setContentSize then
				if self._controlSizeDict[pCacheObj] and self._controlSizeDict[pCacheObj][itemName] then
					control:setContentSize(self._controlSizeDict[pCacheObj][itemName])
				end
			end
		
			if control.setScaleX and control.setScaleY then
				if self._controlScaleDict[pCacheObj] and self._controlScaleDict[pCacheObj][itemName] then
					local scaleX, scaleY = unpack(self._controlScaleDict[pCacheObj][itemName])
					control:setScaleX(scaleX)
					control:setScaleY(scaleY)
				end
			end
		end

		if control.setColor then
			if self._controlColorDict[pCacheObj] and self._controlColorDict[pCacheObj][itemName] then
		        control:setColor(self._controlColorDict[pCacheObj][itemName])
		    end
		end

		if control.setPosition then
			if self._controlPosDict[pCacheObj] and self._controlPosDict[pCacheObj][itemName] then
		        control:setPosition(self._controlPosDict[pCacheObj][itemName])
		    end		
		end
		-- if control.disableEffect then
		-- 	control:disableEffect()
		-- end
	end
end


function SubItemCacheManager:__onCacheSubItem( sObjType, pCacheObj )
	pCacheObj:setVisible(false)
	pCacheObj:stopAllActions()
	pCacheObj:setOpacity(255)
	local function setTouchEventListenerNil()
	end
	for itemName, control in pairs(self._subControlList[pCacheObj]) do
		if control.addTouchEventListener then
			control:addTouchEventListener(setTouchEventListenerNil)
		end
	end
end

function SubItemCacheManager:__destroySubItem( sObjType, pCacheObj )
	pCacheObj:removeFromParent(true)
	if pCacheObj then
		Lua_Release(pCacheObj)
	end
end

--设置条目缓存
function SubItemCacheManager:SetSubItemCache(itemPath, count)
	if self._subItemCacheMgr then
		if not self._lHasInitFuncList[itemPath] then
			self._subItemCacheMgr:SetObjectCreateFunc(itemPath, self.__createSubItem, self, itemPath)
			self._subItemCacheMgr:SetObjectCacheFunc(itemPath, self.__onCacheSubItem, self)
			self._subItemCacheMgr:SetObjectDestroyFunc(itemPath, self.__destroySubItem, self)
			self._lHasInitFuncList[itemPath] = true
		end
		if self._dCacheCountDict[itemPath] then
			self._dCacheCountDict[itemPath] = self._dCacheCountDict[itemPath] + count
		else
			self._dCacheCountDict[itemPath] = count
		end
		self._subItemCacheMgr:InitCacheCount(itemPath, self._dCacheCountDict[itemPath])
	end
end

--获取条目缓存
function SubItemCacheManager:GetSubItemCache( itemPath )
	if self._subItemCacheMgr then
		if not self._subItemCacheMgr:HasSetObjectCreateFunc(itemPath) then
			return nil
		end
		local pCacheObj = self._subItemCacheMgr:GetObject(itemPath)
		pCacheObj:setVisible(true)
		self:__resetSize(pCacheObj)
		return pCacheObj
	end
	return nil
end


--清除子条目
function SubItemCacheManager:Clear()
	if self._subItemCacheMgr then
		self._subItemCacheMgr:ClearAll()
	end
end

--缓存子条目
function SubItemCacheManager:CacheSubItem( sObjType, pCacheObj )
	if self._subItemCacheMgr then
		self._subItemCacheMgr:CacheObject(sObjType, pCacheObj)
	end
end

SubItemCacheCommon = SubItemCacheManager.new()

--- 标签页
--- 点击按钮显示对应内容
--- 以下是使用例子

--[[
--local tab = Tab.new({
--    win = windowObj,
--    tab1 = {
--        btn = "btn1",
--        panel = "panel1",
--        toggleInCallback = function()
--            com.info("toggle in tab1")
--        end
--    },
--    tab2 = {
--        btn = "btn2",
--        panel = "panel2",
--        toggleInCallback = function()
--            com.info("toggle in tab2")
--        end
--    },
--})
--tab:Toggle("tab1")
--]] --

Tab = class()

function Tab:ctor(args)
    self.win = args.win
    self.tabTable = args.tabTable
    self:__registerEvent()
end

function Tab:Toggle(newTabKey)
	local oldTabKey, oldTabInfo = self:__getCurTabInfo()
	if oldTabInfo and oldTabInfo.toggleOutCallback then
		oldTabInfo.toggleOutCallback()
	end
	self:__update(newTabKey)
	local newTabInfo = self.tabTable[newTabKey]
	if newTabInfo.toggleInCallback then
		newTabInfo.toggleInCallback()
	end
end

function Tab:__update(tab)
    for _tab, info in pairs(self.tabTable) do
        if _tab == tab then
            self.win:setButtonDisabledState(info.btn, false)
            self.win:ShowItemByName(info.panel)
        else
            self.win:setButtonDisabledState(info.btn, true)
            self.win:HideItemByName(info.panel)
        end
    end
end

function Tab:__registerEvent()
    local map = {}
    for tab, info in pairs(self.tabTable) do
        map[info.btn] = { TouchEnd = function() self:Toggle(tab) end }
    end
    self.win:RegisterButtonEvent(map)
end

function Tab:__getCurTabInfo()
	for tab, info in pairs(self.tabTable) do
		if self.win:IsItemShow(info.panel) then
			return tab, info
		end
	end
end

--- 勾选框
--- 点击改变勾选状态
--- 以下是使用例子

--[[
--local check = Check.new({
--    win = windowObj,
--    control = "xxxCheck",
--    onToggle = function(check)
--        com.info("check state toggle:", check)
--    end,
--})
-- onToggle 是可选的
]] --

Check = class()

function Check:ctor(args)
    self.win = args.win
    self.control = args.control
    self.onToggle = args.onToggle
    self:Update(args.check)
    self:__registerEvent()
end

--- 切换按钮的勾选状态
--- 有传参数就会根据参数的指定进行改变
--- 没有传参就会变成和当前状态相反的状态
--- check:Toggle(true) => check = true
--- curCheck == false check:Toggle() => check == true
function Check:Toggle(check)
    check = (check == nil and not self:IsChecked()) or check
    self:Update(check)
    if self.onToggle then
        self.onToggle(self:IsChecked())
    end
end

function Check:Update(check)
    local normal = self.control .. "CbNormal"
    local checked = self.control .. "CbChecked"
    if check then
        self.win:HideItemByName(normal)
        self.win:ShowItemByName(checked)
    else
        self.win:ShowItemByName(normal)
        self.win:HideItemByName(checked)
    end
end

--- 获取当前的勾选状态
function Check:IsChecked()
    return self.win:IsItemShow(self.control .. "CbChecked")
end

function Check:__registerEvent()
    self.win:RegisterButtonEvent({
        [self.control] = { TouchEnd = function() self:Toggle() end },
    })
end

--- 点选框组
--- 点击切换选中目标
--- 以下是使用例子

--[[
--local lanRadio = Radio.new({
--    win = self,
--    cbTable = {
--        Chinese = {
--            control = "checkSc",
--        },
--        ZhHant = {
--            control = "checkTc",
--        },
--        English = {
--            control = "checkEn",
--        },
--    },
--    default = "Chinese"
--    onToggle = function(selectedItemKey, lastSelectedItemKey)
--        com.info("itemKey的值就是上面cbTable的key")
--    end
--})
-- onToggle是可选的
--]] --

Radio = class()

function Radio:ctor(args)
    self.win = args.win
    self.cbTable = args.cbTable
    self.default = args.default
    self.onToggle = args.onToggle
    self:__init()
    self:__registerEvent()
end

function Radio:Toggle(key)
    local lastKey = self.curKey
    self:Update(key)
    if self.onToggle then
        self.onToggle(key, lastKey)
    end
end

function Radio:Update(key)
    local lastKey = self.curKey
    if lastKey then
        local lastControlName = self.cbTable[lastKey].control
        self.win:GetItemByName(lastControlName):setTouchEnabled(true)
        self.win:setButtonDisabledState(lastControlName, true)
    end

    self.curKey = key
    local curControlName = self.cbTable[self.curKey].control
    self.win:GetItemByName(curControlName):setTouchEnabled(false)
    self.win:setButtonDisabledState(curControlName, false)
end

function Radio:__init()
    for key, info in pairs(self.cbTable) do
        if key == self.default then
        	self.curKey = key
            self.win:GetItemByName(info.control):setTouchEnabled(false)
            self.win:setButtonDisabledState(info.control, false)
        else
            self.win:GetItemByName(info.control):setTouchEnabled(true)
            self.win:setButtonDisabledState(info.control, true)
        end
    end
end

function Radio:__registerEvent()
    local map = {}
    for key, info in pairs(self.cbTable) do
        map[info.control] = { TouchEnd = function() self:Toggle(key) end }
    end
    self.win:RegisterButtonEvent(map)
end

----------------------------------------------------------------------
Radio2 = class()

function Radio2:ctor(args)
    self.win = args.win
    self.cbTable = args.cbTable
    self.default = args.default
    self.onToggle = args.onToggle
    self:Init()
    self:RegisterEvent()
end

function Radio2:Toggle(key)
	local lastKey = self.curKey
    self:Update(key)
    if self.onToggle then
    	self.onToggle(key, lastKey)
    end
end

function Radio2:Update(key)
	local lastKey = self.curKey
    if lastKey then
        local lastControlName = self.cbTable[lastKey].control
        self.win:GetItemByName(lastControlName):setTouchEnabled(true)
        self.win:SetCheckBoxSelectState(lastControlName, false)
    end

    self.curKey = key
    local curControlName = self.cbTable[self.curKey].control
    self.win:GetItemByName(curControlName):setTouchEnabled(false)
    self.win:SetCheckBoxSelectState(curControlName, true)
end

function Radio2:Init()
    for key, info in pairs(self.cbTable) do
        if key == self.default then
        	self.curKey = key
        	self.win:GetItemByName(info.control):setTouchEnabled(false)
            self.win:SetCheckBoxSelectState(info.control, true)
        else
            self.win:GetItemByName(info.control):setTouchEnabled(true)
            self.win:SetCheckBoxSelectState(info.control, false)
        end
    end
end

function Radio2:RegisterEvent()
    for key, info in pairs(self.cbTable) do
        self.win:CheckBoxRegisterEvent(info.control, function() self:Toggle(key) end)
    end
end