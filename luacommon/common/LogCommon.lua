require "common/class"
require "common/config"

require("common/PlatformLib")
require("common/comlib")
-------------------------------------------------------
--实现配置log保存数量 删除旧文件
--实现模式 用顺序队列方式保存文件路径 并保存至本地数据
-------------------------------------------------------
LogManager = class()
-- 需要重新打开错误log文件
_G.IsNeedOpenError = false

function LogManager:ctor( ... )
    --debugLog路径列表
	self._lFileNameList = {}
    
    --文件句柄
    self._debugFile = nil
    self._errorFile = nil
    --当前文件日期
    self._curDebugFileDate = nil
    -- self._curErrorFileDate = nil
end

--初始化
function LogManager:Init( ... )
    --时间格式
    self._TimeFormat =  "%Y%m%d"
    --Log模式
    self._LogMode = (not _G.IsReload) and config.LogMode or "a"
    --路径
    self._cacheLogPath, self._curDebugFileDate, self._sFileName = self:__createNewDebugFileName()
    self._errorLogPath = self:__createNewErrorFileName()
   
	--文件最大保存数量 默认 为7
	self._iLogMaxCount = GetDefineVariable(config, "LogMaxCount") or 7 

    --初始化保存在客户端数据下的文件路径
	self:__initFileNameListData()
end
----------------------------------------------------------------------------------
--获取已写入文件信息
function LogManager:__initFileNameListData( ... )
    local sFileNameList = GetClientUserDataByChecknum("DebugFileNameListStr", "string")
    self._lFileNameList = string.split(sFileNameList, "|")
end


--检测debug文件数量
function LogManager:__checkLogFileCount( ... )
    if #self._lFileNameList > self._iLogMaxCount then
        local fileName = table.remove(self._lFileNameList, 1)
        local sFilePath = self:__getRealFilePath(fileName)
        os.remove(sFilePath)
        local sFileNameList = table.concat(self._lFileNameList, "|")
        SetClientUserDataByChecknum("DebugFileNameListStr", sFileNameList, "string")
        return
    end

    local sFileNameList = table.concat(self._lFileNameList, "|")
    SetClientUserDataByChecknum("DebugFileNameListStr", sFileNameList, "string")
end

function LogManager:__getRealFilePath( fileName )
    local cachePath = os.getCachePath()
    local formatStr = string.sub(cachePath, -1) == "/" and "%s%s" or "%s/%s"
    local debugLogPath = string.format(formatStr, cachePath, fileName)
    return debugLogPath
end

--添加一个debug文件数据
function LogManager:__addDebugLogData( fileName )
	--判断是否数据存在
    if table.hasValue(self._lFileNameList, fileName) then
        return
    end
    
    table.insert(self._lFileNameList, fileName)  
    self:__checkLogFileCount()
end


--根据日期生成一个新的Debuglog 文件的路径
function LogManager:__createNewDebugFileName( ... )
    local logName = config.LogPath or "debug.log"
    local curDate = os.realdate(self._TimeFormat, os.time())
    local logPath = curDate..logName
    local debugLogPath = self:__getRealFilePath(logPath)
    return debugLogPath, curDate, logPath
end

--根据日期生成一个新的Errorlog 文件的路径
function LogManager:__createNewErrorFileName( ... )
    local errLogName = config.ErrorLogPath or "errorLog.log"
    local cachePath = os.getCachePath()
    local formatStr = string.sub(cachePath, -1) == "/" and "%s%s" or "%s/%s"
    local errorLogPath = string.format(formatStr, cachePath, errLogName)
    return errorLogPath
end
---------------------------------------------------------------------------------
--写LOG
function  LogManager:WriteLog( logStr )
    --如果日期改变 新建一个文件
    local logDate = os.realdate(self._TimeFormat, os.time())
    if logDate ~= self._curDebugFileDate then
        if self._debugFile then
            io.close(self._debugFile)
        end
        self._cacheLogPath ,self._curDebugFileDate, self._sFileName = self:__createNewDebugFileName()
        self._debugFile = nil
    end

    if not self._debugFile then
        --打开文件
        self._debugFile = assert(io.open(self._cacheLogPath, self._LogMode))
        --文件头
        local sCodeZipPath = GetDefineVariable(config, "CodeZipPath") or os.CodeZipPath
        local sLogHeader = string.format("InitClientLog[%s][%s] OpenUDID = %s", self._LogMode, tostring(sCodeZipPath), OpenUDID)
        self._debugFile:write(sLogHeader, "\n")
        --保存文件路径
        self:__addDebugLogData(self._sFileName)
    end

    self._debugFile:write(logStr, "\n")
    self._debugFile:flush()
end

function LogManager:Clear( ... )
    if self._debugFile then
            -- print("logfile close")
        io.close(self._debugFile)
    end

    if self._errorFile then
        io.close(self._errorFile)
    end

    self._debugFile = nil
    self._errorFile = nil
    self._LogMode = "a"
    _G.IsReload = true
end

function LogManager:FlushDebugLog( ... )
    if self._debugFile then
        self._debugFile:flush()
        io.close(self._debugFile)
        self._debugFile = nil
    end
end

function LogManager:FlushErrorLog( ... )
    if self._errorFile then
        self._errorFile:flush()
        io.close(self._errorFile)
        self._errorFile = nil
    end
end

--写错误log
function LogManager:WriteErrorLog( logStr, sLastNormalLogStr )
    -- 需要重新打开错误log文件
    if not self._errorFile or _G.IsNeedOpenError then
        if self._errorFile then
            io.close(self._errorFile)
        end

        _G.IsNeedOpenError = false
                -- print("logfile open")
        self._errorFile = assert(io.open(self._errorLogPath, "a"))
        --文件头
        self._errorFile:write("InitClientErrorLog OpenUDID = ".. OpenUDID, "\n")
    end

    if sLastNormalLogStr then
        self._errorFile:write("LastLogStr:\t", sLastNormalLogStr, "\n")
    end
    self._errorFile:write(logStr, "\n\n")
    self._errorFile:flush()
end

--返回句柄
function LogManager:GetDebugFile( ... )
    return self._debugFile
end

--返回句柄
function LogManager:GetErrorFile( ... )
    return self._errorFile
end

--返回debug 路径
function LogManager:GetDebugLogPath( ... )
    return self._cacheLogPath
end

--返回err 路径
function LogManager:GetErrorLogPath( ... )
    return self._errorLogPath
end
------------------------------------------------
LogCommon = LogManager.new()