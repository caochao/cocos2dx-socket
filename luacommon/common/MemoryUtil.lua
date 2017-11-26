MemoryUtil = {};  
local MemberLog = {};  
MemoryUtil.isPrintingLog = false;  
MemoryUtil.ExcuteCount = 0;  
  
function MemoryUtil.Init()  
    --collectgarbage("stop");  
    MemoryUtil.MemeryClearAllLog();  
    MemoryUtil.Start();  
end  
  
function MemoryUtil.MemeryRecord(key, log)  
    if MemoryUtil.isPrintingLog then  
        return;  
    end  
    if not MemberLog[key] then  
        return;  
    end  
    local runTime = os.clock()*1000 - MemberLog[key].startTime;  
    local addMemory = collectgarbage("count") - MemberLog[key].lastMem - MemoryUtil.ExcuteCount*0.46025;  
    MemberLog[key].totalAdd = MemberLog[key].totalAdd + addMemory;  
    MemberLog[key].totalTime = MemberLog[key].totalTime + runTime;  
    MemberLog[key].Average = MemberLog[key].totalAdd / MemberLog[key].count;  
    MemberLog[key].averageTime = MemberLog[key].averageTime / MemberLog[key].count;  
    if MemberLog[key].MaxAdd < addMemory then  
        MemberLog[key].MaxAdd = addMemory;  
    end  
    if log then  
        error(addMemory);  
    end  
end  
  
function MemoryUtil.MemeryAddLog(key)  
    if MemoryUtil.isPrintingLog then  
        return;  
    end  
    if not MemberLog[key] then  
        MemberLog[key] = {key = "", lastMem = 0, totalAdd = 0, MaxAdd = 0, startTime = 0, totalTime = 0, averageTime = 0, count = 0, Average = 0};  
        MemberLog[key].key = key;  
    end  
    MemberLog[key].lastMem = collectgarbage("count") - MemoryUtil.ExcuteCount*0.46025;  
    MemberLog[key].startTime = os.clock()*1000;  
    MemberLog[key].count = MemberLog[key].count + 1;  
end  
  
function MemoryUtil.MemeryClearAllLog()  
    MemberLog = {};  
    MemoryUtil.ExcuteCount = 0;  
    --LuaGC();  
end  
  
local function SortFunc(memoryA, memoryB)  
    return memoryA.Average > memoryB.Average;  
end  
  
local MemberLogArr = {};  
function MemoryUtil.PrintAllLog()  
    MemoryUtil.isPrintingLog = true;  
    local str = "";  
    for key, value in pairs(MemberLog) do  
        table.insert(MemberLogArr, value);  
    end  
    table.sort(MemberLogArr, SortFunc);  
    for key, value in ipairs(MemberLogArr) do  
        if value.Average > 0.0 then  
            str = str .. "Key:" .. value.key .. "#Average:" .. value.Average .. "#Max:" .. value.MaxAdd .. "#Time:" .. value.averageTime .. "#Count" .. value.count .. "\n";  
        end  
    end  
    MemberLogArr = {};  
    File.WriteAllText("LuaMemory.txt", str);  
    MemoryUtil.isPrintingLog = false;  
end  
  
function MemoryUtil.Start()  
    debug.sethook(MemoryUtil.Profiling_Handler, 'cr', 0)  
end  
  
local funcinfo = nil;  
function MemoryUtil.Profiling_Handler(hooktype)  
  
    MemoryUtil.ExcuteCount = MemoryUtil.ExcuteCount +1;  
    funcinfo = debug.getinfo(2, 'nS')  
  
    if hooktype == "call" then  
        MemoryUtil.Profiling_Call(funcinfo)  
    elseif hooktype == "return" then  
        MemoryUtil.Profiling_Return(funcinfo)  
    end  
    funcinfo = nil;  
end  
  
function MemoryUtil.Func_Title(funcinfo)  
    assert(funcinfo)  
    local name = funcinfo.name or 'anonymous'  
    local line = string.format("%d", funcinfo.linedefined or 0)  
    local source = funcinfo.short_src or 'C_FUNC'  
    return name, source, line;  
end  
  
-- get the function report  
function MemoryUtil.Func_Report(funcinfo)  
    local name, source, line = MemoryUtil.Func_Title(funcinfo)  
    return source .. ":" .. name;   
end  
  
-- profiling call  
function MemoryUtil.Profiling_Call(funcinfo)  
  
    -- get the function report  
    local report = MemoryUtil.Func_Report(funcinfo)  
    assert(report)  
    MemoryUtil.MemeryAddLog(report);  
end  
  
-- profiling return  
function MemoryUtil.Profiling_Return(funcinfo)  
    local report = MemoryUtil.Func_Report(funcinfo)  
    assert(report)  
    MemoryUtil.MemeryRecord(report);  
end  
  
function MemoryUtil.PrintCurrentMem()  
    error(collectgarbage("count"));  
end  