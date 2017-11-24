
require "common/comlib"
require "common/CoroutineSync"

-------------------------------------------------
-- 注册单次计时器
function RegisterTimerCall(func, fInterval, ...)
    if not func then
        com.error("RegisterTimerCall func is nil!")
        return
    end
    local argList = getVarArgs(...)
    local timer
    local timeFunc = function( ... )
    
        DeleteTimer(timer)
        func(unpack(argList))
    end
    timer = cc.Director:getInstance():getScheduler():scheduleScriptFunc(timeFunc, fInterval, false)
    return timer
end

local g_StatInfo = {}

-- 注册循环计时器
function RegisterTimer(func, fInterval, ...)
    if not func then
        com.error("RegisterTimer func is nil!")
        return
    end

    local dFuncInfoStr, sFuncName = getCurFuncCallInfo()
    local argList = getVarArgs(...)
    local timeFunc = function(  )
        -- if sFuncName ~= "__startNetTick" then
        --     com.debug("OnTick = ", dFuncInfoStr, fInterval)
        -- end
        -- local tick = os.mTimer()
        func(unpack(argList))
        -- local useTick = os.mTimer() - tick
        -- SetStatInfo(sFuncName, useTick)
    end
    local timer = cc.Director:getInstance():getScheduler():scheduleScriptFunc(timeFunc, fInterval, false)
    return timer
end

function SetStatInfo( sFuncName,  useTick, playerCount)
    local dStatInfo = g_StatInfo[sFuncName] or {}
    if not dStatInfo["MaxTick"] then
        dStatInfo["MaxTick"] = useTick
    elseif dStatInfo["MaxTick"] < useTick then
        dStatInfo["MaxTick"] = useTick
    end

    if not dStatInfo["MinTick"] then
        dStatInfo["MinTick"] = useTick
    elseif dStatInfo["MinTick"] > useTick then
        dStatInfo["MinTick"] = useTick
    end
    if not dStatInfo["AllTick"] then
        dStatInfo["AllTick"] = useTick
        dStatInfo["Count"] = 1
    else
        dStatInfo["AllTick"] = dStatInfo["AllTick"] + useTick
        dStatInfo["Count"] = dStatInfo["Count"] + 1
    end
    if useTick < 0.001 then
        local count = dStatInfo["0.001"] or 0
        dStatInfo["0.001"] = count + 1
    elseif useTick >= 0.001 and useTick <= 0.005 then
        local count1 = dStatInfo["0.005"] or 0
        dStatInfo["0.005"] = count1 + 1
    elseif useTick <= 0.008 then
        local count2 = dStatInfo["0.008"] or 0
        dStatInfo["0.008"] = count2 + 1
    elseif useTick <= 0.01 then
        local count3 = dStatInfo["0.01"] or 0
        dStatInfo["0.01"] = count3 + 1
    elseif useTick <= 0.03 then
        local count4 = dStatInfo["0.03"] or 0
        dStatInfo["0.03"] = count4 + 1
    end
    dStatInfo["PlayerCount"] = playerCount or 0
    g_StatInfo[sFuncName] = dStatInfo
end


function ShowTimerTickLog( ... )
    if table.getCount(g_StatInfo) == 0 then
        return
    end
    -- com.info("g_StatInfo = ", g_StatInfo)
    local sStatInfo = ""
    for funcName, dStatInfo in pairs(g_StatInfo) do
        local singleTick = dStatInfo["AllTick"] / dStatInfo["Count"]
        sStatInfo = sStatInfo .. string.format("func = %s singleTick= %-6.5f ", funcName, singleTick)
        for key, value in pairs(dStatInfo) do
            local info = string.format("%s = %s", key, value)
            sStatInfo = sStatInfo .. " " .. info
        end
        sStatInfo = sStatInfo .. "\n"
    end

    com.info("sStatInfo = \n%s", sStatInfo)
end


-- unregister timer 删除计时器
function DeleteTimer(timer)
    cc.Director:getInstance():getScheduler():unscheduleScriptEntry(timer)
end

-------------------------等待函数(需在lua协程里使用)---------------------------
------------------   用法举例    ---------------------
-- sync.callFunction(function( ... )                --
--     print("start sleep")                         --
--     Sleep(1)                                     --
--     print("sleep ...")                           --
--     Sleep(0.5)                                   --
--     print("sleep ...")                           --
--     Sleep(3)                                     --
--     print("sleep end")                           --
-- end)                                             --
------------------------------------------------------
-- 等待指定时间 （受客户端帧最小间隔的影响，精度不高）
function Sleep(sleepTick)
    local thread = sync.getThread()
    if not thread then
        com.warn("sleep is not in thread")
        return
    end
    local callBack = sync.getSingleCallBack()
    -- if sleepTick <= 0 then
    --     sleepTick = 3
    -- end
    RegisterTimerCall(callBack, sleepTick)
    sync.waitSync()
end

------------------------高精度等待计时函数(需在lua协程里使用)---------------------------------
------------------   用法举例    ---------------------
-- sync.callFunction(function( ... )                --
--     print("init sleep")                          --
--     -- 需要先初始化开始时间                      --
--     local precisionGroup = "testSleep"           --
--     InitPrecisionGroupSleep(precisionGroup)      --
--                                                  --
--     print("start sleep")                         --
--     PrecisionSleep(0.1, precisionGroup)          --
--     print("sleep ...")                           --
--     PrecisionSleep(0.05, precisionGroup)         --
--     print("sleep ...")                           --
--     PrecisionSleep(0.001, precisionGroup)        --
--     print("sleep end")                           --
-- end)                                             --
------------------------------------------------------
---------------------------------------------------------------------------
-- 高精度等待计时器，数据缓存
local PrecisionTimer = {}
---------------------------------------------------------------------------
-- 客户端重载时，需要清理高精度计时器
function ClearPrecisionTimer( ... )
    -- 删除计时器
    if PrecisionTimer._timer then
        cc.Director:getInstance():getScheduler():unscheduleScriptEntry(PrecisionTimer._timer)
    end
    -- 清理数据
    PrecisionTimer = {}
end
-- 初始化组等待开始时间
function InitPrecisionGroupSleep( group )
    if not PrecisionTimer._groupTickInfo then
        PrecisionTimer._groupTickInfo = {}
    end
    PrecisionTimer._groupTickInfo[group] = {startTick=getMillisecondNow(), sleepTick=0}
    return PrecisionTimer._groupTickInfo[group]
end
-- 高精度等待 （支持组等待)
function PrecisionSleep(sleepTick, group)
    -- com.debug("PrecisionSleep = ", sleepTick)
    -- 每帧计时器
    if not PrecisionTimer._timer then
        PrecisionTimer._timer = cc.Director:getInstance():getScheduler():scheduleScriptFunc(OnPrecisionSleepTick, 0, false)
    end
    -- 记录等待列表
    if not PrecisionTimer._sleepCallList then
        PrecisionTimer._sleepCallList = {}
        PrecisionTimer._sleepCall_freeIndex = 0
        PrecisionTimer._sleepCall_curIndex = 1
    end
    local curTick = getMillisecondNow()
    local nextTick
    -- 组内等待时间
    if group then
        local groupInfo = PrecisionTimer._groupTickInfo[group]
        -- 初始化组等待开始时间
        if not groupInfo then
            groupInfo = InitPrecisionGroupSleep(group)
        end
        -- 组总等待时间
        groupInfo.sleepTick = groupInfo.sleepTick + sleepTick
        -- 当前等待时间
        nextTick = groupInfo.startTick + groupInfo.sleepTick
        -- 已经达到等待时间直接跳过
        if nextTick <= curTick then
            return
        end
    else
        nextTick = curTick + sleepTick
    end

    -- 获取空闲索引
    local index = PrecisionTimer._sleepCall_curIndex
    PrecisionTimer._sleepCall_curIndex = PrecisionTimer._sleepCall_curIndex + 1
    -- 添加新的等待回调处理
    PrecisionTimer._sleepCallList[index] = {nextTick=nextTick, callFunc=sync.getSingleCallBack()}
    -- 等待
    sync.waitSync()
end
---------------------------------------------------------------------------
-- 每帧回调
function OnPrecisionSleepTick()
    -- 遍历等待列表
    local curTick = getMillisecondNow()
    local freeIndex = PrecisionTimer._sleepCall_freeIndex
    local endIndex = PrecisionTimer._sleepCall_curIndex - 1
    for index = freeIndex + 1, endIndex do
        local callInfo = PrecisionTimer._sleepCallList[index]
        if callInfo and callInfo.nextTick <= curTick then
            PrecisionTimer._sleepCall_freeIndex = index
            callInfo.callFunc()
            PrecisionTimer._sleepCallList[index] = nil
        else
            break
        end
    end
    -- 重新获取，可能上面的回调处理已经添加了新的等待
    local endIndex = PrecisionTimer._sleepCall_curIndex - 1
    if PrecisionTimer._sleepCall_freeIndex == endIndex then
        PrecisionTimer._sleepCall_freeIndex = 0
        PrecisionTimer._sleepCall_curIndex = 1
    end
end