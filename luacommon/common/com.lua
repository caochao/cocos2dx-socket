-- package
module("com", package.seeall)
-- use lib
local debuglib = debug
debug = false
error = false
-- Load Config
require("common/PlatformLib")
require("common/config")
require("common/comlib")
require("common/LogCommon")
----------------------------------------------------------
IsError = false
----------------------------------------------------------
-- 是否开启 release print log输出 (可在安卓logcat看见)
_G.NormalPrintFunc = print
if GetDefineVariable(config, "bEnableReleasePrint") then
    _G.NormalPrintFunc = release_print
elseif os.isAndroid() then
    _G.NormalPrintFunc = function( ... )
    end
end
_G.ErrorPrintFunc = release_print
----------------------------------------------------------
--##JSCodeClose##Start##--js不支持
if config.IsDebug then
    if not rawget(_G, "_require") then
        _G._require = require

        local requireIndex = 0
        _G.require = function(path)
            local log = com and com.debug or NormalPrintFunc
            local tabIndent = string.rep("\t", requireIndex)

            log(tabIndent.."require = "..path)
            requireIndex = requireIndex + 1
            local obj = _G._require(path)
            requireIndex = requireIndex - 1
            log(tabIndent.."require end= "..path)

            return obj
        end
    end
end
--##JSCodeClose##End##--js不支持

function reload(moduleName)
    -- local moduleNameList = string.split(moduleName, "/")
    -- local realModuleName = table.getLast(moduleNameList)
    local realModuleName = moduleName
    -- com.debug("package.loaded = ", table.keys(package.loaded))
    local moduleObj = package.loaded[realModuleName]
    com.debug("reload(%s) = [%s]%s", moduleName, realModuleName, moduleObj)
    package.loaded[realModuleName] = nil
    return require(moduleName)
end

-- CodeZipPath
if not GetDefineVariable(config, "CodeZipPath") then
    config.CodeZipPath = os.CodeZipPath
end
----------------------------------------------------------
-- 需要重新打开错误log文件
_G.IsNeedOpenError = false
-- Log func
do
    local bUseDateLog = not (GetDefineVariable(config, "NotUseDateLog") or false)

    LogPath = config.LogPath or "log.log"
    ErrorLogPath = config.ErrorLogPath or "errorLog.log"
    TimeFormat = config.TimeFormat or "%Y-%m-%d %X"

    local LogMode = (not _G.IsReload) and config.LogMode or "a"
    local logfile = nil
    local errorLogfile = nil

    local g_bCreateNormalLogFileError = false
    local g_bCreateErrorLogFileError = false

    local cachePath = os.getCachePath()
    local formatStr = string.sub(cachePath, -1) == "/" and "%s%s" or "%s/%s"
    local cacheLogPath = string.format(formatStr, cachePath, LogPath)
    local errorLogPath = string.format(formatStr, cachePath, ErrorLogPath)

    if bUseDateLog then
        LogCommon:Init()
    end
    -- 最近一句普通log信息
    local sLastNormalLogStr = nil

    function getDebugLogPath( ... )
        if bUseDateLog then
            return LogCommon:GetDebugFile()
        end
        return cacheLogPath
    end
    function getErrorLogPath( ... )
        if bUseDateLog then
            return LogCommon:GetErrorFile()
        end
        return errorLogPath
    end

    ErrorPrintFunc("cacheLogPath = ", getDebugLogPath())
    ErrorPrintFunc("errorLogPath = ", getErrorLogPath())
        

    local g_logType = {
    	["DEBUG"] = 0, 
	    ["INFO"] = 1, 
	    ["WARN"] = 2, 
	    ["ERROR"] = 3, 
	    ["FAIL"] = 4
	}
    LogLevel = g_logType[string.upper(config.LogLevel or "")] or g_logType["WARN"]
	DialogLevel = g_logType[string.upper(config.DialogLevel or "")] or g_logType["WARN"]
    
    function Clear( ... )
        if bUseDateLog then
            LogCommon:Clear()
            return
        end

    	if logfile then
    		-- print("logfile close")
    		io.close(logfile)
    	end

		if errorLogfile then
			io.close(errorLogfile)
		end

		logfile = nil
		errorLogfile = nil
        LogMode = "a"
        _G.IsReload = true

        g_bCreateNormalLogFileError = false
        g_bCreateErrorLogFileError = false
    end

    getVarArgs = _G.getVarArgs

    function getLogVarArgs( ... )
    	local num = select("#", ...)
    	local arg = {}
    	for index=1, num do
    		local value = select(index, ...)
    		if value == nil then
    			value = "nil"
    		end
    		-- 不能插入 nil  数量可能不一致
    		table.insert(arg, value)
    	end
    	return arg
    end

    local function getLogFormatStr(argList)
    	-- print(arg[1], type(arg[1]), string.find(arg[1], "%%s"))
        local bFoundFormat = false
    	if type(argList[1]) == "string" and #argList > 1 then
            if string.find(argList[1], "%%[%-%+]?%d*[cdiouxXeEfgGqs]") then
                bFoundFormat = true
            elseif string.find(argList[1], "%%[%-%+]?%d+%.%d*[cdiouxXeEfgGqs]") then
                bFoundFormat = true
            end
        end 

        if bFoundFormat then
    		return string.format(unpack(argList))
    	else
    		return table.concat(argList, " ")
    	end
    end

    local function getLogInfo( ... )
    	local num = select("#", ...)
    	-- print("num = ", num)
    	-- print("getLogInfo = ", ...)
    	local arg = {}
    	for index=1, num do
    		local value = select(index, ...)
    		if value == nil then 
    			value = "nil" 
    		elseif type(value) ~= "string" then
    			if string.getStr then
    				value = string.getStr(value)
    			end
    		end
    		table.insert(arg, value)
    	end
    	return getLogFormatStr(arg)
    end

    local function getLogInfoByArg(argList)
    	-- print("getLogInfoByArg = ", argList)
    	for index, value in pairs(argList) do
    		if value == nil then
    			argList[index] = "nil"
    		elseif type(value) ~= "string" then
    			if string.getStr then 
    				argList[index] = string.getStr(value)
    			end
    		end
    	end
    	return getLogFormatStr(argList)
    end

    function writeLog(logStr)
    	if not logStr then
    		return
    	end

        --开启按日期写入的log
        if bUseDateLog then
            LogCommon:WriteLog(logStr)
            return
        end

    	if not logfile then
            if g_bCreateNormalLogFileError then
                return
            end
            local sErrMsg = nil
	        logfile, sErrMsg = io.open(cacheLogPath, LogMode)
            if not logfile then
                ErrorPrintFunc(string.format("writeLog create log file[%s, %s, %s] Error", cacheLogPath, LogMode, sErrMsg))
                g_bCreateNormalLogFileError = true
                return
            end
            local sLogHeader = string.format("InitClientLog[%s][%s] OpenUDID = %s", LogMode, tostring(config.CodeZipPath), OpenUDID)
	        logfile:write(sLogHeader, "\n")
    	end
      	logfile:write(logStr, "\n")

    	logfile:flush()
    end

    function writeErrorLog(logStr, sLastNormalLogStr)
    	if not logStr then
    		return
    	end
        --开启按日期写入的log
        if bUseDateLog then
            LogCommon:WriteErrorLog(logStr, sLastNormalLogStr)
            return
        end
         -- 需要重新打开错误log文件
    	if not errorLogfile or _G.IsNeedOpenError then
            if g_bCreateErrorLogFileError then
                return
            end
            if errorLogfile then
              io.close(errorLogfile)
            end
            _G.IsNeedOpenError = false
        		-- print("logfile open")
            local sErrMsg = nil
            errorLogfile, sErrMsg = io.open(errorLogPath, "a")
            if not errorLogfile then
                ErrorPrintFunc(string.format("writeLog create log file[%s, %s, %s] Error", errorLogPath, "a", sErrMsg))
                g_bCreateErrorLogFileError = true
                return
            end
            errorLogfile:write("InitClientErrorLog OpenUDID = ".. OpenUDID, "\n")
    	end

        if sLastNormalLogStr then
            errorLogfile:write("LastLogStr:\t", sLastNormalLogStr, "\n")
        end
      	errorLogfile:write(logStr, "\n\n")

    	errorLogfile:flush()
    end
    function flushDebugLog( ... )
        if bUseDateLog then
            LogCommon:FlushDebugLog()
            return
        end
        if logfile then
            logfile:flush()
            io.close(logfile)
            logfile = nil
        end
    end
    function flushErrorLog( ... )
        if bUseDateLog then
            LogCommon:FlushErrorLog()
            return
        end

		if errorLogfile then
    		errorLogfile:flush()
    		io.close(errorLogfile)
    		errorLogfile = nil
		end
    end

    -- 是否开启log缓存
    local g_isEnable = false
    -- log缓存列表
    local g_cacheLogList = {}

    -- 设置log缓存
    function SetLogCacheEnable(isEnable)
    	-- print("SetLogCacheEnable = ", isEnable)
    	if g_isEnable ~= isEnable then
    		flushLog()
    	end
    	g_isEnable = isEnable
    end

    -- 保存log到缓存
    function CacheLog(tick, logLv, ...)
    	-- print("CacheLog = ", logLv, ...)
    	local arg = getLogVarArgs(...)
    	table.insert(g_cacheLogList, {tick, logLv, arg})
    end

    -- log缓存写入文件
    function WriteLogCache()
    	-- print("WriteLogCache = ", g_isEnable)
    	for _, logInfo in pairs(g_cacheLogList) do
    		local tick, logLv, logArg = unpack(logInfo)
    		-- print("logLv = ", logLv)
    		-- print("logArg = ", logArg)
    		local logInfoStr = getLogInfoByArg(logArg)
    		-- print("logInfoStr = ", logInfoStr)
	        showLog(tick, logLv, logInfoStr, true)
    	end
    	g_cacheLogList = {}
    end


    --报错提示框显示
    function Dialog(logLv, msg)
        -- print("DialogLevel = ", DialogLevel)
        -- print("logLv = ", logLv)
        -- print("g_logType[logLv] = ", g_logType[logLv])
        -- print("g_logType = ", g_logType)
        if g_logType[logLv] < DialogLevel then
            return
        end
        if LogicEntry and GetDefineVariable(LogicEntry, "Dialog") then
            LogicEntry.Dialog(logLv, msg, true)
        end
    end

    -- log写入文件
    function showLog(tick, logLv, logInfoStr, isNotPrint)
        local fPrintFunc = NormalPrintFunc
        local bErrorLog = g_logType[logLv] >= g_logType["ERROR"]
        if bErrorLog then
            fPrintFunc = ErrorPrintFunc
        end

        local sTimeStr = os.realdate(TimeFormat, tick)
        local fCpuTick, fCpuTick2 = math.modf(os.mTimer())
        local sFloatTimeStr = string.format("%0.7f", fCpuTick2)
    	local logStr = table.concat({sTimeStr, sFloatTimeStr, logLv, logInfoStr}, "\t") 
    	if not isNotPrint then
    		if string.len(logStr) > 1740 then
    			fPrintFunc(string.sub(logStr, 1, 1740), "...")
    		else
        		fPrintFunc(logStr)
    		end
        	Dialog(logLv, logInfoStr)
    	end

        writeLog(logStr)
        --输出错误日志
        if bErrorLog then
       		writeErrorLog(logStr, sLastNormalLogStr)
        else
            sLastNormalLogStr = logStr
       	end
       	
    end

    --开始写log
    function log(logLv, ... )
		-- local statIndex = com.startStat("log")
    	if g_logType[logLv] < LogLevel then 
			-- com.stopStat(statIndex)
    		return 
    	end

        local tick = os.time()
    	if g_isEnable then
    		CacheLog(tick, logLv, ...)
			-- com.stopStat(statIndex)
			if g_logType[logLv] < DialogLevel then
    			return 
			end
    	end

        local logInfoStr = getLogInfo(...)
        showLog(tick, logLv, logInfoStr)
		-- com.stopStat(statIndex)
    end

    -- 刷新log缓存
    function flushLog( ... )
    	-- print("flushLog g_isEnable = ", g_isEnable)
    	-- print("flushLog g_cacheLogList = ", table.isNotEmpty(g_cacheLogList))
    	if g_isEnable or table.isNotEmpty(g_cacheLogList) then
    		WriteLogCache()
    	end
        --写入日期log
        if bUseDateLog then
            if LogCommon:GetDebugFile() then
                LogCommon:GetDebugFile():flush()
            end
            return
        end

    	if logfile then
    		logfile:flush()
    	end
    end

	debug = function ( ... )
                log("DEBUG", ...) 
            end
	info = function ( ... )
                log("INFO", ...)
            end
	warn = function ( ... )
            log("WARN", ...)
            end
	error = function ( ... ) 
        IsError = true
		log("ERROR", ...) 
		-- 显示错误发生时的堆栈信息
		if config.EnableErrorTraceback then
            if isFunction(_G.debug.traceback) then
                log("ERROR", _G.debug.traceback())
            end
            log("ERROR", getDebug(4))
            log("ERROR", getDebug(5))
		end
	end
	fail = function ( ... ) 
        IsError = true
        log("FAIL", ...) 
        -- 显示错误发生时的堆栈信息
        if config.EnableErrorTraceback then
            if isFunction(_G.debug.traceback) then
                log("FAIL", _G.debug.traceback())
            end
            log("FAIL", getDebug(4))
            log("FAIL", getDebug(5))
        end
    end
end

-- debug func
do
	local function getValueStr(value)
		return "(" .. string.getStr(value) .. ")"
	end

	local function getLocal(funcIndex)
		funcIndex = funcIndex + 1
		local index = 1
		local arg = {}
		while true do
			local name, value = _G.debug.getlocal(funcIndex, index)
			if not name then
                break
            end
		 	if value ~= _G and name ~= "(*temporary)" then
		 		-- print("getLocal name = ", name, " v= ", value)
				table.insert(arg, name .. "=" .. getValueStr(value))
		 	end
			index = index + 1
		end

		return table.concat(arg, ", ")
	end

	local function getUpvalue(func)
		local index = 1
		local arg = {}
		while true do
			local name, value = _G.debug.getupvalue(func, index)
			if not name then
                break
            end
		 	if value ~= _G and name ~= "(*temporary)" then
		 		-- print("getUpvalue name = ", name, " v= ", value)
				table.insert(arg, name .. "=" .. getValueStr(value))
			end
			index = index + 1
		end

		return table.concat(arg, ", ")
	end

	function getDebug(funcIndex, ...)
		local funcIndex  = funcIndex or 2
		local info = _G.debug.getinfo(funcIndex, "nSl")
        if not info then
            return ""
        end
		local func = info.func
		-- print("\tsource: " .. info.short_src)
		-- print("\tname: " .. (info.name or "nil"))
		-- print("\tcurrentline: " .. info.currentline)
		local strList = {
			----  ... and arg => only one, in body
			(... and string.format(...) or "debugInfo") .. ": ",
			"\tsource: " .. info.short_src,
			"\tname: " .. (info.name or "none"),
			"\tcurrentline: " .. info.currentline,
			"\tlocal: " .. getLocal(funcIndex),
			"\tupvalue: " .. (func and getUpvalue(func) or "none"),
		}
		return table.concat(strList, "\n")
	end
	function showDebug( ... ) 
		info(getDebug(3, ...)) 
		info(_G.debug.traceback())
	end
end
