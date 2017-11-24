
require "common/com"
require "common/LanguageCommon"
require "core/SceneCommon"
require "core/EventCommon"
------------------
-- 下载速度定时检测间隔
DownloadSpeedInterval = 1
-- // localFile size error
kLocalFileError = 0
-- // Error caused by creating a file to store downloaded data
kCreateFile = 1
-- /** Error caused by network
-- 	-- network unavaivable
-- 	-- timeout
-- 	-- ...
-- 	*/
kNetwork = 2
-- /** Error caused in uncompressing stage
-- 	-- can not open zip file
-- 	-- can not read file global information
-- 	-- can not read file information
-- 	-- can not create a directory
-- 	-- ...
-- 	*/
kUncompress = 3
kClear = 4
kGetSize = 5

CURLE_OK = 0
CURLE_UNSUPPORTED_PROTOCOL = 1    -- /* 1 */
CURLE_FAILED_INIT = 2             -- /* 2 */
CURLE_URL_MALFORMAT = 3           -- /* 3 */
CURLE_NOT_BUILT_IN = 4            -- /* 4 - [was obsoleted in August 2007 for
                                -- 7.17.0, reused in April 2011 for 7.21.5] */
CURLE_COULDNT_RESOLVE_PROXY = 5   -- /* 5 */
CURLE_COULDNT_RESOLVE_HOST = 6    -- /* 6 */
CURLE_COULDNT_CONNECT = 7        -- /* 7 */
CURLE_FTP_WEIRD_SERVER_REPLY = 8  -- /* 8 */
CURLE_REMOTE_ACCESS_DENIED = 9   --  /* 9 a service was denied by the server
                               --  due to lack of access - when login fails
                               --  this is not returned. */
CURLE_HTTP_RETURNED_ERROR = 22  --   /* 22 */
CURLE_WRITE_ERROR = 23           --  /* 23 */
CURLE_READ_ERROR = 26            --   /* 26 - couldn't open/read from file */
CURLE_RANGE_ERROR = 33           --  /* 33 - RANGE "command" didn't work */
-----------------------------------------------------------
local TEMP_PACKAGE_FILE_NAME = "-update-temp-package-"
local TEMP_PACKAGE_FILE_EXT = ".zip"
-------------------------------------------------
AutomaticUpdateManager = class()
-------------------------------------------------
function AutomaticUpdateManager:ctor( ... )
	self._updateTimer = nil
	self._curAllSize = -1
	self._curDownloadSize = 0

	self:Init()
end
-------------------------------------------------

function AutomaticUpdateManager:ReloadClient( ... )
	com.info("ReloadClient")

	self._loadingSceneArg = SceneCommon:GetScene("LoadingScene"):GetSceneArg()
	
	self:__reloadResources()

	self:__reloadScript()
end

function AutomaticUpdateManager:__reloadResources( ... )
	com.info("__reloadResources")
	sc.MobClickCpp:beginEvent("UpdateDynamicPackage__reloadResources")

	EventCommon:OnEvent("ReloadResources")

	-- 清理UI注册钩子
	if UI and UI.Clear then
		UI.Clear()
	end
	-- 销毁声音
	if AudioCommon and AudioCommon.Clear then
		AudioCommon:Clear()
	end
	-- 销毁界面
	if WindowCommon and WindowCommon.purgeWindowCache then
		WindowCommon.purgeWindowCache()
	end

	if SubItemCacheCommon and SubItemCacheCommon.Clear then
		SubItemCacheCommon:Clear()
	end

	-- 销毁图片资源
	if ImageCommon and ImageCommon.Clear then
		ImageCommon:Clear()
	end

	-- 销毁动画
	if AnimationCommon and AnimationCommon.Clear then
		AnimationCommon:Clear()
	end

	-- 销毁配置
	if ConfigCommon and ConfigCommon.Clear then
		ConfigCommon:Clear()
	end

	-- 销毁场景资源
	if SceneCommon and SceneCommon.Clear then
		SceneCommon:Clear()
	end
	
	-- 断开网络模块
	if Communicate and Communicate.ClearAll then
		Communicate.ClearAll()
	end

	-- 断开网络模块
	if Net and Net.ClearAll then
		Net.ClearAll()
	end

	-- 关闭log模块
	if com and com.Clear() then
		com.Clear()
	end

	-- 清理高精度计时器缓存
	if ClearPrecisionTimer then
		ClearPrecisionTimer()
	end

	sc.MobClickCpp:endEvent("UpdateDynamicPackage__reloadResources")
end
function AutomaticUpdateManager:__reloadScript( ... )
	com.info("__reloadScript")
	sc.MobClickCpp:beginEvent("UpdateDynamicPackage__reloadScript")
	EventCommon:OnEvent("ReloadScript")

    cc.FileUtils:getInstance():addSearchPath(Def_VersionRoot, true)

	sc.LuaCommon:unregisterScriptHandler()

    -- 重新load zip包 脚本
    CCLuaLoadChunksFromZIP(config.CodeZipPath)

	-- 释放模块
	for name, obj in pairs(package.loaded) do
		if not _BulitinModule_[name] then
			package.loaded[name] = nil
		end
	end

    require "common/LoadHelper"
    InitPlatformSDK()

    require "logic/LogicEntry"
	sc.MobClickCpp:endEvent("UpdateDynamicPackage__reloadScript")

    -- 开始游戏逻辑
    LogicEntry.OnInitClient(self._loadingSceneArg)
end

-------------------------------------------------
-- 资源下载成功
function AutomaticUpdateManager:__updateResourcesDownloadSuccess( ... )
	com.info("__updateResourcesDownloadSuccess")
	
	if self._updateTimer then
		DeleteTimer(self._updateTimer)
		self._updateTimer = nil
	end

	EventCommon:OnEvent("UpdateResourcesDownloadSuccess")
end
-- 资源更新成功
function AutomaticUpdateManager:__updateResourcesSuccess()
	sc.MobClickCpp:endEvent("UpdateDynamicPackage")
	com.info("updateResources Success")
	EventCommon:OnEvent("UpdateResourcesSuccess")

	-- 检测配置和代码路径
    checkVersionData(true, true)

    SetClientUserData("LastUpdateVersion", "", "string")
	SetClientUserData("LastUpdateVersionPackageCount", 0, "int")
end
-------------------------------------------------
-- 资源更新进度
function AutomaticUpdateManager:__updateResourcesProgress(index, percent, totalToDownload, nowDownloaded, downloadSpeed)
	index = index + 1
	self._curDownload = nowDownloaded

	-- 总下载比例
	if self._lastDownloadIndex ~= index and totalToDownload ~= 0 then
		self._lastDownloadIndex = index
		self._curDownloadSize = self._curDownloadSize + totalToDownload
	end
	local curSize = self._curDownloadSize - (totalToDownload - nowDownloaded)
	local curPercent = 0
	if self._curAllSize > 0 then
		curPercent = curSize / self._curAllSize * 100
	end 
	local speedStr = GetBufferLenFormatStr(self._speed)

	-- com.info("__updateResourcesProgress(%s| %s%%) : %s", index, curPercent, speedStr)

	EventCommon:OnEvent("DownloadClientUpdateProgress", curPercent, speedStr)
end

-------------------------------------------------
-- 获取http异常原因
function AutomaticUpdateManager:__getHttpErrorStr(errorCode)
	local errorTypeMsg
	if errorCode == CURLE_UNSUPPORTED_PROTOCOL then
		errorTypeMsg = "CURLE_UNSUPPORTED_PROTOCOL"
	elseif errorCode == CURLE_COULDNT_CONNECT then
		errorTypeMsg = "CURLE_COULDNT_CONNECT"
	elseif errorCode == CURLE_REMOTE_ACCESS_DENIED then
		errorTypeMsg = "CURLE_REMOTE_ACCESS_DENIED"
	elseif errorCode == CURLE_HTTP_RETURNED_ERROR then
		errorTypeMsg = "CURLE_HTTP_RETURNED_ERROR"
	elseif errorCode == CURLE_WRITE_ERROR then
		errorTypeMsg = "CURLE_WRITE_ERROR"
	elseif errorCode == CURLE_READ_ERROR then
		errorTypeMsg = "CURLE_READ_ERROR"
	elseif errorCode == CURLE_RANGE_ERROR then
		errorTypeMsg = "CURLE_RANGE_ERROR"
	elseif errorCode >= 500 then
		errorTypeMsg, _ = LanguageCommon:GetString("CURLE_HTTP_SERVER_ERROR", errorCode)
	elseif errorCode >= 400 then
		errorTypeMsg, _ = LanguageCommon:GetString("CURLE_HTTP_QUERY_ERROR", errorCode)
	else
		local sFoundErrorMsg, bFound = LanguageCommon:GetString(string.format("CURLE_ERROR_%s", errorCode))
		if bFound then
			errorTypeMsg = sFoundErrorMsg
		else
			errorTypeMsg, _ = LanguageCommon:GetString("CURLE_UNKNOW_ERROR", errorCode)
		end
	end
	return errorTypeMsg
end
-- 资源更新失败
function AutomaticUpdateManager:__updateResourcesFail(index, errorType, errorCode)
	index = index + 1
	com.info("updateResources(%s) Fail, errorType(%s), errorCode(%s)", index, errorType, errorCode)

	local title = "UpdateResourcesFail"
	local errorMsg = ""
	if errorType == kLocalFileError then
		sc.MobClickCpp:event("UpdateDynamicPackage_kLocalFileError", tostring(index))
		errorMsg, _ = LanguageCommon:GetString("UpdateDynamicPackage_kLocalFileError", index)
	elseif errorType == kCreateFile then
		sc.MobClickCpp:event("UpdateDynamicPackage_kCreateFile", tostring(index))
		errorMsg, _ = LanguageCommon:GetString("UpdateDynamicPackage_kCreateFile", index)
	elseif errorType == kGetSize then
		sc.MobClickCpp:event("UpdateDynamicPackage_kGetSize", tostring(index))
		local errorTypeMsg = self:__getHttpErrorStr(errorCode)
		errorMsg, _ = LanguageCommon:GetString("UpdateDynamicPackage_kGetSize", index, errorTypeMsg)
	elseif errorType == kNetwork then
		sc.MobClickCpp:event("UpdateDynamicPackage_kNetwork", tostring(index))
		local errorTypeMsg = self:__getHttpErrorStr(errorCode)
		errorMsg, _ = LanguageCommon:GetString("UpdateDynamicPackage_kNetwork", index, errorTypeMsg)
	elseif errorType == kUncompress then
		sc.MobClickCpp:event("UpdateDynamicPackage_kUncompress", tostring(index))
		errorMsg, _ = LanguageCommon:GetString("UpdateDynamicPackage_kUncompress", index, errorCode)
	elseif errorType == kClear then
		sc.MobClickCpp:event("UpdateDynamicPackage_kClear", tostring(index))
		errorMsg, _ = LanguageCommon:GetString("UpdateDynamicPackage_kClear", index)
	else
		sc.MobClickCpp:event("UpdateDynamicPackage_kUnknow", tostring(index))
		errorMsg, _ = LanguageCommon:GetString("UpdateDynamicPackage_kUnknow", index, errorType)
	end

	com.error("UpdateFail: %s", errorMsg)

	EventCommon:OnEvent("UpdateResourcesFail", title, errorMsg)

end
-------------------------------------------------
-- 下载速度定时刷新
function AutomaticUpdateManager:__onDownloadProgress( ... )
	local oldDownload = self._lastDownload
	self._lastDownload = self._curDownload
	self._speed = (self._lastDownload - oldDownload) / DownloadSpeedInterval
	self._speed = self._speed > 0 and self._speed or 0
end

-- 开始更新 (curVersion 版本临时存放目录)
function AutomaticUpdateManager:StartUpdate( curVersion )
	sc.MobClickCpp:beginEvent("UpdateDynamicPackage")

	if self._updateTimer then
		DeleteTimer(self._updateTimer)
	end

	self._updateTimer = RegisterTimer(self.__onDownloadProgress, DownloadSpeedInterval, self)
	self._lastDownload = 0
	self._curDownload = 0
	self._speed = 0

	self._curDownloadSize = 0
	self._lastDownloadIndex = -1

	sc.AutomaticUpdate:getInstance():MultiUpdate(curVersion, Def_VersionRoot)

	EventCommon:OnEvent("StartClientUpdate")
end

-------------------------------------------------
-- 更新文件大小
function AutomaticUpdateManager:__onUpdateSize(size)
	sc.MobClickCpp:endEvent("UpdateDynamicPackage_checkUpdateSize")

	self._curAllSize = size

	local sizeStr = ""
	if self._curAllSize > 0 then
		sizeStr = GetBufferLenFormatStr(self._curAllSize)
	end

	com.info("__onUpdateSize(%s) : %s", self._curAllSize, sizeStr)

	EventCommon:OnEvent("GetUpdateSize", self._curAllSize, sizeStr)
end
-------------------------------------------------

-- 检测更新包大小
function AutomaticUpdateManager:CheckUpdatePackageSize( ... )
	sc.MobClickCpp:beginEvent("UpdateDynamicPackage_checkUpdateSize")

	sc.AutomaticUpdate:getInstance():CheckUpdatePackageSize()
end
-------------------------------------------------

-- 初始化更新信息
function AutomaticUpdateManager:InitUpdateInfo( updatePackageUrlList, sNewVersion )
	-- 版本文件清理列表
	local clearFileList = {}
	local sLastUpdateVersion = GetClientUserData("LastUpdateVersion", "string")
	if string.isVail(sLastUpdateVersion) and sLastUpdateVersion ~= self._sNewVersion then
		local iPackageCount = GetClientUserData("LastUpdateVersionPackageCount", "int") or 0
		local index = 0
		for idx = 1, iPackageCount do
			index = index + 1
			local str = sLastUpdateVersion .. TEMP_PACKAGE_FILE_NAME .. index .. TEMP_PACKAGE_FILE_EXT
			table.insert(clearFileList, str)
		end
	end

	for _, packageName in pairs(clearFileList) do
		local fileName = Def_VersionRoot .. packageName
		if cc.FileUtils:getInstance():isFileExist(fileName) then
			cc.FileUtils:getInstance():removeFile(fileName)
		end
	end	

	local updateMgr = sc.AutomaticUpdate:getInstance()
	updateMgr:InitUpdate()
	local packageCount = 0
	for index = 1, #updatePackageUrlList do
		local urlList = string.split(updatePackageUrlList[index], ",")
		for _, url in pairs(urlList) do
			url = string.strip(url)
			updateMgr:AddUpdatePackageInfo(url, "")
			packageCount = packageCount + 1
		end
	end

	self:CheckUpdatePackageSize()

	SetClientUserData("LastUpdateVersion", sNewVersion, "string")
	SetClientUserData("LastUpdateVersionPackageCount", packageCount, "int")
end

-------------------------------------------------
-- 客户端启动初始化
function AutomaticUpdateManager:Init()
    com.info("sc.AutomaticUpdateCore.Init")

	-- 资源更新事件
	sc.AutomaticUpdate:getInstance():registerScriptHandler(function(eventType, arg, ...)
		-- com.debug("eventType(%s) = %s", eventType, index)
		if eventType == "Error" then
			self:__updateResourcesFail(arg, ...)

		elseif eventType == "Progress" then
			self:__updateResourcesProgress(arg, ...)

		elseif eventType == "DownloadSuccess" then
			self:__updateResourcesDownloadSuccess()

		elseif eventType == "Success" then
			self:__updateResourcesSuccess()


		elseif eventType == "UpdateSize" then
			self:__onUpdateSize(arg)
		else
			com.error("AutomaticUpdate. unKnow eventType = %s", eventType)
		end
	end)

end

-------------------------------------------------
AutomaticUpdateCore = AutomaticUpdateManager.new()



-- -------------------test----------------------
-- require "core/AutomaticUpdateCore"

-- function MainWindow:OnShow( ... )
-- 	-- 注册事件
-- 	EventCommon:RegisterEvent("GetUpdateSize", self.OnUpdateSize, self)
-- 	EventCommon:RegisterEvent("UpdateResourcesFail", self.OnUpdateResourcesFail, self)
-- 	EventCommon:RegisterEvent("DownloadClientUpdateProgress", self.OnDownloadClientUpdateProgress, self)
-- 	EventCommon:RegisterEvent("UpdateResourcesSuccess", self.OnUpdateResourcesSuccess, self)
-- 	EventCommon:RegisterEvent("UpdateResourcesDownloadSuccess", self.OnUpdateResourcesDownloadSuccess, self)

-- 	-- 开始初始化更新
-- 	local updatePackageUrlList = {
-- 		"127.0.0.1:8147/version/code/0.1.11.zip",
-- 		"127.0.0.1:8147/version/code/0.2.1.zip",

-- 		"127.0.0.1:8147/version/config/0.1.11.zip",
-- 		"127.0.0.1:8147/version/config/0.2.1.zip",
		
-- 		"127.0.0.1:8147/version/res/0.1.2.34.zip",
-- 		"127.0.0.1:8147/version/res/0.1.3.13.zip",
-- 	}
-- 	local clearFileList = {}
-- 	AutomaticUpdateCore:InitUpdateInfo(updatePackageUrlList, clearFileList)
-- end
-- -- 初始化之后会接到大小事件
-- function MainWindow:OnUpdateSize( allSize, sizeStr )
-- 	com.info("%s.OnUpdateSize allSize(%s) sizeStr(%s)", self, allSize, sizeStr)
-- 	-- 开始更新，存到 tset 临时目录
-- 	AutomaticUpdateCore:StartUpdate("test")
-- end
-- -- 更新失败
-- function MainWindow:OnUpdateResourcesFail( index, errorMsg )
-- 	com.info("%s.OnUpdateResourcesFail index(%s) errorMsg(%s)", self, index, errorMsg)
-- end
-- -- 更新进度条
-- function MainWindow:OnDownloadClientUpdateProgress( curPercent, speedStr )
-- 	com.info("%s.OnDownloadClientUpdateProgress curPercent(%s) speedStr(%s)", self, curPercent, speedStr)
-- end
-- -- 更新下载成功
-- function MainWindow:OnUpdateResourcesDownloadSuccess(  )
-- 	com.info("%s.OnUpdateResourcesDownloadSuccess", self)
-- end
-- -- 更新全部成功
-- function MainWindow:OnUpdateResourcesSuccess(  )
-- 	com.info("%s.OnUpdateResourcesSuccess", self)
-- end