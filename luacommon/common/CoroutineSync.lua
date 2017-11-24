-- package
module("sync", package.seeall)
----------------------------------------------------------
-- 协程字典
local g_threadCallDict = {}
-- 回调生成器字典
local g_threadCallMakerDict = {}
----------------------------------------------------------
-- 获取当前协程内的恢复回调
function getSingleCallBack()
    local thread = coroutine.running()
    return g_threadCallDict[thread]
end
----------------------------------------------------------
-- 多重等待回调生成器
CallBackMaker = class()
function CallBackMaker:ctor()
    -- 当前协程
    self._thread = coroutine.running()
    self._isDestroy = false

    -- 等待回调数
    self._waitCallCount = 0
    -- 获取当前协程内的恢复回调
    self._threadCallBack = getSingleCallBack()
    -- 是否在等待回调
    self._lock = false

    -- 用于累计调用最后恢复协程的回调
    self._callBackFunc = function()
        -- 已经销毁停止掉
        if self._isDestroy then
            com.error("%s._isDestroy call = %s", self, self._waitCallCount)
            return
        end
        self._waitCallCount = self._waitCallCount - 1
        if self._waitCallCount < 0 then
            com.error("%s.repeat call = %s", self, self._waitCallCount)
        end
        if self._lock and self._waitCallCount <= 0 then
            self._lock = false
            self._threadCallBack()
        end
    end
end
function CallBackMaker:__str__()
    return string.format("Thread(%s)", GetObjectIndex(self))
end
-- 返回回调函数，并创建一个新的等待回调计数
function CallBackMaker:create()
    self._waitCallCount = self._waitCallCount + 1
    return self._callBackFunc
end
-- 判断是否还需要等待回调
function CallBackMaker:isWait()
    return self._waitCallCount > 0
end
-- 等待回调，同步
function CallBackMaker:waitSync()
    if self:isWait() then
        self._lock = true
        waitSync()
    end
end
-- 销毁停用等待线程
function CallBackMaker:destroy( ... )
    self._isDestroy = true
    g_threadCallMakerDict[self._thread] = nil
end
----------------------------------------------------------

-- 获取当前协程的回调生成器
function getSingleCallBackMaker()
    local thread = coroutine.running()
    if not thread then
        com.error("Current no in coroutine thread!")
        return
    end
    if not g_threadCallMakerDict[thread] then
        g_threadCallMakerDict[thread] = CallBackMaker.new()
    end
    return g_threadCallMakerDict[thread]
end
-- 
function getCallBackMaker()
    return CallBackMaker.new()
end
----------------------------------------------------------

-- 等待同步
function waitSync()
    coroutine.yield()
end

----------------------------------------------------------
-- 创建一个新协程
function newThread(func)
    local thread = coroutine.create(func)
    -- 协程同步回调
    g_threadCallDict[thread] = function()
        xpcallThread(thread)
        if isThreadEnd(thread) then
            delThread(thread)
        end
    end
    return thread
end
----------------------------------------------------------

local function isEmptyThread()
    return not g_threadCallDict or table.getn(g_threadCallDict) == 0
end
-- 协程是否结束
function isThreadEnd(thread)
    return coroutine.status(thread) == "dead"
end
-- 获取当前协程
function getThread()
    local thread = coroutine.running()
    return thread
end
-- 删除协程
function delThread(thread)
    g_threadCallDict[thread] = nil
end
----------------------------------------------------------
-- 传递协程，以显示协程内部堆栈
function handleAssert( thread, e)
    if __G__TRACKBACK__ then
        __G__TRACKBACK__(e, thread)
    else
        print(thread, "handleAssert ", e)
        print(debug.traceback(thread))
    end
end
-- 保护模式运行协程，以捕捉异常
function xpcallThread( thread, ... )
    local argList = getVarArgs(...)
    xpcall(function()
        -- 正常lua报错 会被resume 截取
        local result, e = coroutine.resume(thread, unpack(argList))
        if not result then
            handleAssert(thread, e)
        end
    -- c++ 调用 lua_error传递异常 resume截取不到，但是会被xpcall 截取到
    end, 
    function( e )
        handleAssert(thread, e)
    end)
end
----------------------------------------------------------
-- 运行指定协程
function runThread(thread, ...)
    xpcallThread(thread, ...)
    if isThreadEnd(thread) then
        delThread(thread)
    end
end
-- 创建协程 执行某函数
function callFunction(func, ...)
    thread = newThread(func)
    runThread(thread, ...)
end

---------------interface-----------------
---- thread = sync.newThread(func)
---- sync.runThread(thread)
-----------------------------------------
---- callBackMaker = sync.CallBackMaker.new()
---- addCall(callBackMaker:create())
---- callBackMaker:waitSync()
-------------------
---- callBackMaker.isWait()
---- sync.waitSync()
-----------------------------------------
-----------------------------------------
---- sync.getSingleCallBack()
---- sync.waitSync()
-----------------------------------------


---------------test----------------------
-- do
    
--     --- test callBack
--     local callList = {}
--     function addCall(callFunc)
--         table.insert(callList, callFunc)
--     end
--     function isEmptyCallBack()
--         return not callList or table.getn(callList) == 0
--     end
--     function checkCallBack()
--         local tmpList = callList
--         callList = {}
--         for _, callFunc in pairs(tmpList) do
--             callFunc()
--         end
--     end
--     function checkSingleCallBack()
--         if table.getn(callList) == 0 then
--             return
--         end
--         local callFunc = table.remove(callList)
--         callFunc()
--     end
--     function mainLoop(mainThread)
--         runThread(mainThread)
--         while true do
--             if isEmptyCallBack() and isEmptyThread() then
--                 break
--             end
--             print("---mainLoop")
--             -- checkCallBack()
--             checkSingleCallBack()
--         end
--     end

-- end


-- local mainThread = newThread(function ( ... )
--     print("start")

--     callBackMaker = CallBackMaker.new()
--     addCall(callBackMaker:create())
--     addCall(callBackMaker:create())
--     print("call")
--     print("waitSync 1") 
--     callBackMaker:waitSync()

--     callBackMaker = CallBackMaker.new()
--     addCall(callBackMaker:create())
--     addCall(callBackMaker:create())
--     addCall(callBackMaker:create())
--     print("call ---")
--     print("waitSync 1---") 
--     if callBackMaker:isWait() then
--         waitSync()   
--     end

--     print("running")

--     addCall(getSingleCallBack())
--     print("waitSync 3")
--     waitSync()

--     print("end")
-- end)

-- print("mainLoop")
-- mainLoop(mainThread)
-- print("endLoop")
