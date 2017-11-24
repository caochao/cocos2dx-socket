-- package
module("LuaCppCommon", package.seeall)
require "common/com"
require "common/LanguageCommon"
require "common/AudioCommon"
require "core/EventCommon"


-------------------------------------------------
-- 开始接收物理引擎刷新后回调事件
local g_fAfterPhysicUpdateEventFunc = nil
-- 事件侦听器
local g_pAfterPhysicUpdateListener = nil
-------------------------------------------------
-- 自定义事件自定义处理
local g_dCustomEventFuncDict = {}
-------------------------------------------------
-- 错误报告处理接口
local g_crashReportUpdatePreFunc = nil
local g_bEnableAutoCrashReport = false
-------------------------------------------------
-- 剪贴板接收回调
local g_fOnGetClipText = nil
-- 图片保存到相册回调
local g_fSaveCallback = nil
-------------------------------------------------

-- 自定义上传
function PostFileToUrl( path, url, postData )
	sc.AutoCrashReport:getInstance():PostFileToUrl(path, url, postData)
end
-------------------------------------------------

-- 发送邮件(emailRecivers 接受者列表, 标题, 内容)
function SendEmail( emailRecivers, emailTitle, emailContent )
    sc.LuaCommon:sendMail(emailRecivers, emailTitle, emailContent )
end
-- 例子:  LuaCppCommon.SendEmail({"linzefei@qq.com", "909480581@qq.com"}, "title", "content")

function openWechat()
	if not sc.LuaCommon.openWechat then
		com.error("openWechat fail, no found api")
		return false
	end
	return sc.LuaCommon:openWechat()
end

function openQQ()
	if not sc.LuaCommon.openQQ then
		com.error("openQQ fail, no found api")
		return false
	end
	return sc.LuaCommon:openQQ()
end

-------------------------------------------------
-- 发送http请求
function SendHttp( sHttpUrl, sMethodType, dHttpArg, fSuccessCallback, fErrorCallback )
    local xhr = cc.XMLHttpRequest:new()
    xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_ARRAY_BUFFER
    xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_STRING
    xhr:open(sMethodType, sHttpUrl)

    -- post 参数
    if table.isNotEmpty(dHttpArg) then
	    local lRequestDataList = {}
	    for sDataKey, pDataValue in pairs(dHttpArg) do
	    	local sDataValue = string.urlencode(pDataValue)
	    	local sDataStr = string.format("%s=%s", sDataKey, sDataValue)
	    	table.insert(lRequestDataList, sDataStr)
	    end
	    local sRequestData = table.concat(lRequestDataList, "&")
	    xhr:setRequestData(sRequestData)
    end

    -- 回调
    local function onReadyStateChange()

        local response = xhr.response

        if (xhr.readyState ~= cc.XMLHTTPREQUEST_READYSTATE_DONE) or (xhr.status < 200) or (xhr.status >= 400) then
        	com.warn("SendHttp[%s][%s:%s] error, readyState=%s, status=%s, response=%s", sHttpUrl, 
        				sMethodType, dHttpArg, xhr.readyState, xhr.status, response)

        	if fErrorCallback then
        		fErrorCallback()
        	end
        	return
        end

        if fSuccessCallback then
        	fSuccessCallback(response)
        end
    end
    xhr:registerScriptHandler(onReadyStateChange)
    xhr:send()
end

-------------------------------------------------
-- 切换后台回调
function applicationDidEnterBackground()
	com.debug("applicationDidEnterBackground")
	
	sc.ApplicationInfo:setDormancyStatus(false)

	if EventCommon then
		EventCommon:OnEvent("applicationDidEnterBackground")
	end
	-- 使用在线参数功能
	sc.MobClickCpp:updateOnlineConfig()
end
-- 切换前台回调
function applicationWillEnterForeground()
	com.debug("applicationWillEnterForeground")
	
	sc.ApplicationInfo:setDormancyStatus(true)

	if EventCommon then
		EventCommon:OnEvent("applicationWillEnterForeground")
	end
	-- 使用在线参数功能
	sc.MobClickCpp:updateOnlineConfig()
end

-------------------------------------------------
-- createQRCode 错误码
QRCODE_OK = 0
QRCODE_NOFOUND_CONTENT = -2
QRCODE_NOFOUND_API = -1
QRCODE_ERROOR_ENCODE = 1
QRCODE_ERROOR_CREATEIMAGE = 2
QRCODE_ERROOR_CREATEBUFFER = 3
QRCODE_ERROOR_INITIMAGE = 4
QRCODE_ERROOR_SAVEFILE= 5

QRCODE_ERROOR_CREATELOGO_NOFOUND = 6
QRCODE_ERROOR_CREATELOGO_CREATEIMAGE = 7
QRCODE_ERROOR_CREATELOGO_INITIMAGE = 8
QRCODE_ERROOR_CREATELOGO_GETIMAGEDATA = 9
QRCODE_ERROOR_CREATELOGO_TOOBIG = 10

-- 生成二维码
---- sContentStr 内容
---- sFileName   导出路径
---- iImageSize  导出大小(会导出近似大小，但不一定完全匹配)
---- sLogoFile   附加logo文件，可选(必须小于图片大小)
function CreateQRCode( sContentStr, sFileName, iImageSize, sLogoFile )
	com.info("CreateQRCode", sContentStr, sFileName, sLogoFile)
	iImageSize = iImageSize or 0

	if string.isEmpty(sContentStr) then
		com.error("CreateQRCode fail, sContentStr = ", sContentStr)
		return false, QRCODE_NOFOUND_CONTENT
	end

	if not (sc.QRCode and sc.QRCode.createQRCode) then
		com.error("CreateQRCode fail, no found api")
		return false, QRCODE_NOFOUND_API
	end

	local iErrorCode = nil
	-- logo文件可选
	if string.isVail(sLogoFile) then
		iErrorCode = sc.QRCode:createQRCode(sContentStr, sFileName, iImageSize, sLogoFile)
	else
		iErrorCode = sc.QRCode:createQRCode(sContentStr, sFileName, iImageSize)
	end
	if iErrorCode ~= QRCODE_OK then
		com.error("CreateQRCode fail = %s", iErrorCode)
		return false, iErrorCode
	end
	com.info("CreateQRCode success")
	return true
end
-----------------剪贴板操作-----------------------------
-- 异步获取粘贴字符串
function AsynGetClipText( fOnGetClipText )
	if not sc.LuaCommon.getClipText then
		com.error("getClipText fail, no found api")
		return false
	end
	-- 注册成功回调
	g_fOnGetClipText = fOnGetClipText

	-- 异步获取
	-- (成功后会发送 OnNotifyClipText 事件, EventCommon:RegisterEvent("OnNotifyClipText", self.XXXX))
	local bRet = sc.LuaCommon:getClipText()
	return bRet
end
-- 获取剪贴板数据成功
function OnNotifyClipText(  )
	com.info("OnNotifyClipText success")
	if g_fOnGetClipText then
		g_fOnGetClipText(GetLastClipText())
	end
end
-- 获取最后一次剪贴板内容
function GetLastClipText( ... )
	if not sc.LuaCommon.getLastClipText then
		com.error("getLastClipText fail, no found api")
		return ""
	end
	local sCopyStr = sc.LuaCommon:getLastClipText()
	return sCopyStr
end
-----------------剪贴板操作-----------------------------
-- 复制字符串
function SetClipText( sCopyStr )
	if not sc.LuaCommon.setClipText then
		com.error("setClipText fail, no found api")
		return false
	end
	com.info("SetClipText", sCopyStr)
	local bRet = sc.LuaCommon:setClipText(sCopyStr)
	if not bRet then
		com.error("setClipText error")
		return false
	end
	com.info("SetClipText success")
	return bRet
end
-------------------------------------------------
-- 保存图片到相册
function SaveImageToPhotosAlbum( sSourceImagePath, fSaveCallback )
	if not sc.LuaCommon.saveImageToPhotosAlbum then
		com.error("saveImageToPhotosAlbum fail, no found api")
		return false
	end

	-- 注册结果回调
	g_fSaveCallback = fSaveCallback

	com.info("SaveImageToPhotosAlbum", sSourceImagePath)
	local bRet = sc.LuaCommon:saveImageToPhotosAlbum(sSourceImagePath)
	if not bRet then
		com.error("SaveImageToPhotosAlbum error")
		return false
	end
	com.info("SaveImageToPhotosAlbum success")
	return true
end

-- 保存图片结果回调
function OnSaveImageToPhotosAlbumReslt( bSuccess )
	com.info("OnSaveImageToPhotosAlbumReslt", bSuccess)
	if g_fSaveCallback then
		g_fSaveCallback(bSuccess)
	end
end
-------------------------------------------------

-- 获取上次输入内容
function GetLastDialogInput( ... )
	return sc.Dialog:getLastDialogInput()
end

------ 显示对话框
-- pszMsg       			消息内容
-- pszTitle     			标题
-- bEnableEditInput     	是否显示输入框
-- defaultDialogInputText   输入框默认文本
-- callBack     			按钮回调
-- leftStr 					左边按钮文本
-- rightStr 				右边按钮文本
-- centerStr 				中间按钮文本
function ShowDialog( pszMsg, pszTitle, bEnableEditInput, defaultDialogInputText, 
				callBack, leftStr, rightStr, centerStr )

	com.info("ShowDialog", pszMsg, pszTitle, bEnableEditInput, leftStr, rightStr, centerStr)

	pszMsg = LanguageCommon:GetString(pszMsg)
	pszTitle = LanguageCommon:GetString(pszTitle)
	if leftStr then
		leftStr = LanguageCommon:GetString(leftStr)
	end
	if rightStr then
		rightStr = LanguageCommon:GetString(rightStr)
	end
	if centerStr then
		centerStr = LanguageCommon:GetString(centerStr)
	end

	sc.Dialog:setTitle(pszTitle)
	sc.Dialog:setMessage(pszMsg)
	
	com.info("setEnableEditInput = ", bEnableEditInput)
	if bEnableEditInput then
		sc.Dialog:setEnableEditInput(bEnableEditInput or false)
		sc.Dialog:setDefaultDialogInputText(defaultDialogInputText or "")
	else
		sc.Dialog:setEnableEditInput(false)
	end

	callBack = callBack or function( ... ) 
							end
	if centerStr then
		sc.Dialog:setButtonText(callBack, leftStr, rightStr, centerStr)
	elseif rightStr then
		sc.Dialog:setButtonText(callBack, leftStr, rightStr)
	else
		sc.Dialog:setButtonText(callBack, leftStr or "YES")
	end

	sc.Dialog:showDialog()
end

-------------------------------------------------
-- 开始接收物理引擎刷新后回调事件
function RegisterAfterPhysic3DUpdateEvent( fEventFunc )
	g_fAfterPhysicUpdateEventFunc = fEventFunc

	-- 初始化事件
	if not g_pAfterPhysicUpdateListener then
	    g_pAfterPhysicUpdateListener = cc.EventListenerCustom:create("director_after_physic_update", __onAfterPhysicUpdate)
	    cc.Director:getInstance():getEventDispatcher():addEventListenerWithFixedPriority( g_pAfterPhysicUpdateListener, 1 )
	end
end

function __onAfterPhysicUpdate( eventCustom )
	if g_fAfterPhysicUpdateEventFunc then
		g_fAfterPhysicUpdateEventFunc()
	end
end
-------------------------------------------------
-- 开关 默认镜头屏幕外自动过滤渲染处理 (默认开启)
function SetIsNeedCheckScreenVisibility( bCheckScreenVisibility )
	if sc.LuaCommon.setIsNeedCheckScreenVisibility then
		sc.LuaCommon:setIsNeedCheckScreenVisibility(bCheckScreenVisibility)
	end
end
-- 设置当前游戏是否只用到默认2d镜头
function SetUseDefault2DCamera( bUseDefaultCamera )
	if sc.LuaCommon.setUseDefault2DCamera then
		sc.LuaCommon:setUseDefault2DCamera(bUseDefaultCamera)
	end
end
-------------------------------------------------
-- 推送行为
_G.NotificationBehaviorType = {
	-- 无
	NotificationBehavior_None = 0,
	-- 声音
	NotificationBehavior_Music = 1,
	-- 震动
	NotificationBehavior_Shake = 2,
	-- 指示灯
	NotificationBehavior_Light = 4,
	-- 声音和震动
	NotificationBehavior_MusicAndShake = 3,
	-- 声音和指示灯
	NotificationBehavior_MusicAndLight = 5,
	-- 震动和指示灯
	NotificationBehavior_ShakeAndLight = 6,
	-- 震动和震动和指示灯
	NotificationBehavior_All = 7,
}
---- 发起推送
-- * @sMessage : 通知文本消息
-- * @iTriggerTick : 多久之后触发（单位:秒）
-- * @iIntervalTick : 间隔播放时间(单位:秒），若非正整数则不重复播放
 -- * @iBehavior : 行为定义, 参见 NotificationBehaviorType
function StartLocalNotification( sNotifyKey, sMessage, iTriggerTick, iIntervalTick, iBehavior)
	-- 默认不重复
	iIntervalTick = iIntervalTick or 0
	-- 默认无
	iBehavior = iBehavior or NotificationBehaviorType.NotificationBehavior_None
    sc.LocalNotification:schedule(sNotifyKey, sMessage, iTriggerTick, iIntervalTick, iBehavior)
end
	
-- 停止推送
function StopLocalNotification( sNotifyKey )
    sc.LocalNotification:unschedule(sNotifyKey)
end
-----------------推送使用注意事项----------------
-- 有一个要注意的是 如果我们一直在游戏中没退出也没切换后台
-- 那推送要在触发前关掉

-- 也就是如果你期望 10秒后提醒玩家近游戏
-- 一般做法是  设置10秒后推送， 同时开一个计时器 设置9秒时 执行（关闭推送
-- （如果切后台 要关闭计时器， 切前台恢复计时器

-- 这样如果玩家在游戏中，  那9秒时关闭了推送，10秒时就不会提示推送
-- 如果玩家在后台 或者关了游戏 10秒时就会推送
-------------------------------------------------
-- 初始化极光推送
function InitJPush( ... )
    sc.JPush:registerScriptHandler(function(json)
        json = string.replace(json, "\\/", "/")
        json = Json_Decode(json)

        if not json.url then
            com.warn("JPush(%s, %s).json = %s", json.title, json.message, json)
            return
        end
        if not (string.startWith(json.url, "http://") or string.startWith(json.url, "https://") ) then
            json.url = "http://" .. json.url
        end
        com.info("JPush(%s, %s).url = %s", json.title, json.message, json.url)

        function callback(type)
            if 0 == type then
                sc.LuaCommon:openURL(json.url)
            end
        end

        LuaCppCommon.ShowDialog(json.message, json.title, false, "", callback, "Go", "Canncel")
    end)
    sc.JPush:Init()
end
-- 设置极光设备别名
function SetJpushAlias( sUserAlias )
	if not sc.JPush.SetAlias then
		com.error("no support SetJpushAlias", sUserAlias)
		return
	end
	sc.JPush:SetAlias(sUserAlias)
	com.info("SetJpushAlias", sUserTag)
end
-- 设置极光推送用户标签
function SetJpushTag( sUserTag )
	if not sc.JPush.SetTag then
		com.error("no support SetJpushTag", sUserTag)
		return
	end
	sc.JPush:SetTag(sUserTag)
	com.info("SetJpushTag", sUserTag)
end
-- 获取极光 Registration ID
function GetJpushRegistrationID( ... )
	if not sc.JPush.GetRegistrationID then
		com.error("no support GetJpushRegistrationID", sUserAlias)
		return ""
	end
	return sc.JPush:GetRegistrationID()
end
-------------------------------------------------
-- 自定义事件
function onCustomEvent( sCustomEventType, iEventValue )
    -- com.info("onCustomEvent = ", sCustomEventType, iEventValue)

    -- 自定义处理
    local fCustomEventFunc = g_dCustomEventFuncDict[sCustomEventType]
    if fCustomEventFunc then
    	fCustomEventFunc()
    	return
    end

	if EventCommon then
		EventCommon:OnEvent(sCustomEventType, iEventValue)
	end
end
-------------------------------------------------

-- 客户端启动初始化
function Init()
    com.info("sc.LuaCommon.Init")

    -- 剪贴板操作回调
    g_dCustomEventFuncDict["OnNotifyClipText"] = OnNotifyClipText
    -- 保存图片到相册回调
    g_dCustomEventFuncDict["OnSaveImageToPhotosAlbumSuccess"] = packFunction(OnSaveImageToPhotosAlbumReslt, true)
    g_dCustomEventFuncDict["OnSaveImageToPhotosAlbumError"] = packFunction(OnSaveImageToPhotosAlbumReslt, false)

	-- 注册lua通用事件
	sc.LuaCommon:registerScriptHandler(function( eventType, arg, arg2 )
    	-- com.info("sc.LuaCommon.eventType = ", eventType, arg, arg2)
		if eventType == "applicationDidEnterBackground" then
			applicationDidEnterBackground()
		elseif eventType == "applicationWillEnterForeground" then
			applicationWillEnterForeground()
		elseif eventType == "Custom" then
			onCustomEvent(arg, arg2)
		else
			com.error("sc.LuaCommon. unKnow eventType = %s, %s, %s", eventType, arg, arg2)
		end
	end)
end

function Clear( ... )
    sc.LuaCommon:unregisterScriptHandler()
end