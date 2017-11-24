---------------------fixed------------------- 
module("AutoUpdate", package.seeall)
---------------------fixed------------------- 

function log_info( sMessage, ... )
    local fPrintFunc = release_print or print
    if com and com.info then
        fPrintFunc = com.info
    else
        sMessage = "log_info " .. sMessage
    end
    fPrintFunc(sMessage, ...)
end
function log_err( sMessage, ... )
    local fPrintFunc = release_print or print
    if com and com.info then
        fPrintFunc = com.error
    else
        sMessage = "log_err " .. sMessage
    end
    fPrintFunc(sMessage, ...)
end

-- 模块初始化
function initBase( ... )
    log_info("initBase")

    -- 已经初始化
    if rawget(_G, "_InitAutoUpdate") then
        log_info("initBase has init")
        return
    end

    -- 内置模块列表
    _G._BulitinModule_ = {}
    -- 内置变量列表
    _G._BulitinVariable_ = {}

    for sModuleName in pairs(package.loaded) do
        _G._BulitinModule_[sModuleName] = true
        -- log_info( "sModuleName", sModuleName)
    end
    -- 排除main函数
    _G._BulitinVariable_["main"] = false

    -- 使用扩展代码
    _G._UseExtCodeZipPath = nil
    -- 版本目录
    local sWritablePath = cc.FileUtils:getInstance():getWritablePath()
    _G.Def_VersionRoot = string.format("%sVersion/", sWritablePath)

    -- 默认搜索路径
    cc.FileUtils:getInstance():addSearchPath(sWritablePath)

    -- 使用扩展资源
    _G._UseExtResourcePath = nil

    -- 全局变量元表
    _G._GlobalMetaTable = getmetatable(_G)

    -- 最大版本尝试请求次数
    _G.Def_VersionRequest_TryRequestCount = 3
    
    -- 基础属性
    _G.AppCppVersion = sc.ApplicationInfo:getAppVersion()
    _G.OpenUDID = sc.ApplicationInfo:getOpenUDID()
    _G.APP_ID = sc.ApplicationInfo:getPackageName()
    log_info("AppCppVersion : ", _G.AppCppVersion)
    log_info("OpenUDID : ", _G.OpenUDID)
    log_info("APP_ID : ", _G.APP_ID)

    -- 自动更新初始化
    _G._InitAutoUpdate = true



    -- 记录初始全局
    for sVarName in pairs(_G) do
        _G._BulitinVariable_[sVarName] = true
        -- log_info( "sVarName", sVarName)
    end
    _G._BulitinVariable_["_BulitinVariable_"] = true
end


-- 重载所有模块及资源
function reloadAllScriptAndResource( sCodeZipPath, sResourcePath, bReset )
    log_info("reloadAllScriptAndResource", sCodeZipPath, sResourcePath, bReset)

    -- 当前已经是最新代码, 不需要再次载入
    if not bReset and (rawget(_G, "_UseExtCodeZipPath") == sCodeZipPath) and (rawget(_G, "_UseExtResourcePath") == sResourcePath) then
        log_info( "reloadAllScriptAndResource has use, return ")
        return false
    end

    -- 清理脚本模块
    clearScript()

    -- 切换代码
    switchLuaCode(sCodeZipPath, bReset)
    -- 切换资源目录
    switchResource(sResourcePath, bReset)

    package.loaded["main"] = nil
    require("main")

    return true
end

-- 清理脚本模块
function clearScript( ... )
    log_info("clearScript")

    -- 还原全局元表
    setmetatable(_G, _G._GlobalMetaTable)

    -- 清理版本相关
     __clearVersionProcess()

    -- 过滤列表
    local lFilterList = {"ConfigCommon", "SceneCommon", "ImageCommon", "Communicate", "Net", "com"}
    local dFilterDict = {}
    for _, sName in pairs(lFilterList) do
        dFilterDict[sName] = true
    end 


    -- 释放旧的模块
    for sModuleName, pModuleObj in pairs(package.loaded) do
        if not _G._BulitinModule_[sModuleName] then
            package.loaded[sModuleName] = nil
            -- log_info("sModuleName.check", sModuleName, pModuleObj)

            -- 尝试执行clear函数
            if pModuleObj and type(pModuleObj) == "table" and (not dFilterDict[sModuleName]) then
                local fClearFunc = rawget(pModuleObj, "ClearAll") or rawget(pModuleObj, "Clear")
                if fClearFunc and isFunction(fClearFunc) then
                    log_info("ModuleObj.call", sModuleName, fClearFunc)
                    fClearFunc()
                end
            end
        end
    end

    -- 全局变量不清空, 尝试执行clear函数
    for sVarName, pGlobalValue in pairs(_G) do
        if not _G._BulitinVariable_[sVarName] then
            -- log_info("sVarName.check", sVarName, pGlobalValue)
            if pGlobalValue and type(pGlobalValue) == "table" and (not dFilterDict[sVarName]) and isInstance(pGlobalValue) then
                local bModule = rawget(pGlobalValue, "_M")
                if not bModule then
                    local fClearFunc = pGlobalValue.ClearAll or pGlobalValue.Clear
                    if fClearFunc and isFunction(fClearFunc) then
                        log_info("GlobalValue:call", sVarName, fClearFunc)
                        fClearFunc(pGlobalValue)
                    end
                end
            end
        end
    end

    -- 清理模块列表
    for _, sName in ipairs(lFilterList) do
        local pTargetObj = _G[sName]
        if pTargetObj then
            local fClearFunc = pTargetObj.ClearAll or pTargetObj.Clear
            if fClearFunc then
                if isInstance(pTargetObj) then
                    log_info("Target.Obj:Clear", sName)
                    fClearFunc(pTargetObj)
                else
                    log_info("Target.Module.Clear", sName)
                    fClearFunc()
                end
            end
        end
    end

    -- 清理高精度计时器缓存
    if rawget(_G, "ClearPrecisionTimer") then
        ClearPrecisionTimer()
    end

    cc.Director:getInstance():restart()
    cc.Director:getInstance():mainLoop()
end

-- 切换代码(bReset 强制重置代码)
function switchLuaCode( sCodeZipPath, bReset )
    log_info("switchLuaCode", sCodeZipPath, bReset)

    if not bReset and rawget(_G, "_UseExtCodeZipPath") == sCodeZipPath then
        log_info( "has use code = ", sCodeZipPath)
        return
    end
    _G._UseExtCodeZipPath = sCodeZipPath

    -- 重新load zip包 脚本
    CCLuaLoadChunksFromZIP(sCodeZipPath)

end

-- 切换资源目录
function switchResource( sResourcePath, bReset )
    log_info("switchResource", sResourcePath, bReset)

    if not bReset and rawget(_G, "_UseExtResourcePath") == sResourcePath then
        log_info( "has use resource = ", sResourcePath)
        return
    end
    -- 使用扩展资源
    _G._UseExtResourcePath = sResourcePath

    -- 清理资源路径缓存
    cc.FileUtils:getInstance():purgeCachedEntries()

    -- 普通资源
    cc.FileUtils:getInstance():addSearchPath(sResourcePath, true)
    -- UI资源目录
    local sUIResRoot = string.format("%spublish/", _G.Def_VersionRoot)
    cc.FileUtils:getInstance():addSearchPath(sUIResRoot, true)
end

-- 初始化默认资源
function initDefaultResource( ... )
    log_info("initDefaultResource")

    -- UI资源目录
    local sUIResRoot = string.format("publish/")
    cc.FileUtils:getInstance():addSearchPath(sUIResRoot, true)
end

-- 判定是否使用扩展版本
function isUseExtVersion( ... )
    -- 使用下载的版本配置
    local sLastConfigZipPath = GetDefineVariable(config, "ConfigZipPath") or "config.data"
    local sConfigZipPath = _G.Def_VersionRoot .. sLastConfigZipPath
    if not os.isExist(sConfigZipPath) then
        log_info("no found sConfigZipPath = ", sConfigZipPath)
        return false
    end
    -- 当前版本
    local sCurVersion = GetClientConfigVsrsion()
    log_info("sCurVersion = ", sCurVersion)

    -- 当前已经是使用扩展版本了
    if os.getFullPath(sLastConfigZipPath) == os.getFullPath(sConfigZipPath) then
        log_info("has use ext version = ", sCurVersion)
        return true
    end

    local sNewVersion = GetClientConfigVersion(sConfigZipPath)

    log_info("sNewVersion = ", sNewVersion)

    -- 新版本 版本号更高
    bUseExtVersion = VersionCompare(sCurVersion, sNewVersion) == -1
    return bUseExtVersion
end

-- 清理旧版残余资源
function clearOldVersionResource( ... )
    log_info("clearOldVersionResource")
    -- 当前主程序版本更高,清理version旧资源
    if cc.FileUtils:getInstance():isDirectoryExist(_G.Def_VersionRoot) then
        log_info("removeDirectory", Def_VersionRoot)
        local bRet = cc.FileUtils:getInstance():removeDirectory(Def_VersionRoot)
        if not bRet then
            log_err(string.format("removeDirectory %s fail", Def_VersionRoot))
        end
    end
end


function init( ... )
    initBase()

    require("common/config")
    require("common/comlib")
    require("common/PlatformLib")
    require("common/com")

    -- 判定是否使用扩展版本
    local bUseExtVersion = isUseExtVersion()

    -- 切换代码及资源
    if bUseExtVersion then
        -- 版本代码及资源路径
        local sCodeZipPath = _G.Def_VersionRoot .. (GetDefineVariable(config, "CodeZipPath") or "driver.data")
        local sResourcePath = _G.Def_VersionRoot
        if os.isExist(sCodeZipPath) then
            -- 使用扩展版本
            return reloadAllScriptAndResource(sCodeZipPath, sResourcePath)
        else
            log_err("no found sCodeZipPath = ", sCodeZipPath)
        end
    end

    -- 初始化默认资源
    initDefaultResource()
    -- 清理旧版残余资源
    clearOldVersionResource()

    return false
end

-------------------------------------------------------------------------

-- 检测版本更新
function __doCheckVersionUpdate( dVersionInfo )
    -- if dVersionInfo
end


-------------------------------------------------------------------------
-- 检测版本
function checkVersion( iCurTryCount )
    -- 当前尝试次数
    iCurTryCount = iCurTryCount or 0
    iCurTryCount = iCurTryCount + 1

    requestVersionInfo(__parseVersionInfo, __retryRequestVersionInfo, iCurTryCount)
end

function __parseVersionInfo( sVersionStr, iCurTryCount )

    local bSuccess = xpcall(function( ... )
        sVersionStr = string.replace(sVersionStr, "\\/", "/")
        local dVersionInfo = Json_Decode(sVersionStr)
        if not dVersionInfo or (not dVersionInfo.success) then
            -- 重试
            __retryRequestVersionInfo(iCurTryCount)
            return
        end

        __doCheckVersionUpdate(dVersionInfo)

    end, function (sErrMsg, pThread)
        local sOutStr = (pThread and debug.traceback(pThread) or debug.traceback())
        log_err("__parseVersionInfo error", sErrMsg, sOutStr)
    end)

    -- 重试
    if not bSuccess then
        __retryRequestVersionInfo(iCurTryCount)
    end

end
function __retryRequestVersionInfo( iCurTryCount )
    -- 失败处理,尝试3次
    if iCurTryCount >= _G.Def_VersionRequest_TryRequestCount then
        log_err("__retryRequestVersionInfo fail, try count = %s", iCurTryCount)
        return
    end

    checkVersion(iCurTryCount)
end



-------------------------------------------------------------------------
-- 获取版本渠道
function getVersionChannel( ... )
    -- app key
    local sVersionChannel = ""
    if GetDefineVariable(config, "VersionChannel") then
        sVersionChannel = config.VersionChannel
    end
    -- app 平台配置
    local sPlatformVersionChannel = sc.ApplicationInfo:getInfoByKey("VersionChannel")
    if string.isVail(sPlatformVersionChannel) then
        sVersionChannel = sPlatformVersionChannel
    end

    -- win32兼容
    if os.isWindow() and string.isEmpty(sVersionChannel) then
        sVersionChannel = _G.APP_NAME
    end

    return sVersionChannel
end

-- 请求版本信息
function requestVersionInfo( fSuccessCallback, fErrorCallback, iCurTryCount )
    __clearVersionProcess()

    local pHttpRequest = cc.XMLHttpRequest:new()
    pHttpRequest.responseType = cc.XMLHTTPREQUEST_RESPONSE_STRING

    _G._LastVersionRequest = pHttpRequest

    -- 当前版本
    local sCurVersion = GetClientConfigVsrsion()
    -- 

    local sMethodType = "POST"
    local sBaseRequestUrl = "http://version.simplecreator.net/version/"
    local sHttpUrl = string.format("%s?channel=%s&platform=%s&appid=%s&dataver=%s&appver=%s", getVersionChannel(),
                os.getPlatformStr(), _G.APP_ID, sBaseRequestUrl, sCurVersion, _G.AppCppVersion)
    pHttpRequest:open(sMethodType, sHttpUrl)

    -- 回调
    local function onReadyStateChange()

        __clearVersionProcess()

        local response = pHttpRequest.response

        if (pHttpRequest.readyState ~= cc.XMLHTTPREQUEST_READYSTATE_DONE) or (pHttpRequest.status < 200) or (pHttpRequest.status >= 400) then
            log_err("checkVersion[%s][%s] error, readyState=%s, status=%s, response=%s", sHttpUrl, 
                        sMethodType, pHttpRequest.readyState, pHttpRequest.status, response)
            if fErrorCallback then
                fErrorCallback(iCurTryCount)
            end
            return
        end

        log_info("checkVersion response = ", response)
        if fSuccessCallback then
            fSuccessCallback(response, iCurTryCount)
        end
    end
    pHttpRequest:registerScriptHandler(onReadyStateChange)
    pHttpRequest:send()
end

function __clearVersionProcess( ... )
    -- 清理版本请求
    if _G._LastVersionRequest then
        _G._LastVersionRequest:unregisterScriptHandler()
        _G._LastVersionRequest = nil
    end
end