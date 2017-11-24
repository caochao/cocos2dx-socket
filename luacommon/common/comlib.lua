-- require "luaext/json"
require "common/class"

-----------------------------------------------------
-- 是否数字
function isNumber( value )
    if not value then
        return false
    end
    return type(value) == "number"
end
-- 是否非0数字（非0）
function isVailNumber( value )
    if not isNumber(value) then
        return false
    end
    return value ~= 0
end

-- 是否浮点
function isFloat( value )
    if not isNumber(value) then
        return false
    end
    local num, sub = math.modf(value)
    if sub == 0 then
        return false
    end
    return true
end

-- 是否奇数
function isOdd( value )
    return math.mod(value, 2) == 1
end

-- 是否绝对奇数（包含负奇数）
function isAbsOdd( value )
    if math.mod(value, 2) == 1 or math.mod(value, 2) == -1 then
        return true
    end
    return false
end

-- 是否函数
function isFunction( func )
    if not func then
        return false
    end
    return type(func) == "function"
end

-- 是否字符串
function isString( sStr )
    if not sStr then
        return false
    end
    return type(sStr) == "string"
end
-- 是否数组
function isArray( pTable )
    if not pTable then
        return false
    end
    return type(pTable) == "table"
end

-- 获取保留n位小数点后的数
function GetPreciseDecimal(nNum, n)
    if type(nNum) ~= "number" then
        return nNum
    end
    
    n = n or 0
    n = math.floor(n)
    local fmt = '%.' .. n .. 'f'
    local nRet = tonumber(string.format(fmt, nNum))

    return nRet
end

-- 获取数字自动格式化
function GetAutoFloatFormatStr( fValue, sFloatFormatStr )
    sFloatFormatStr = sFloatFormatStr or "%0.2f"
    local sFormatStr = nil
    if isFloat(fValue) then
        sFormatStr = string.format(sFloatFormatStr, fValue)
    else
        sFormatStr = string.format("%d", fValue)
    end
    return sFormatStr
end
-----------------------------------------------------------------
-- 判断utf8字符byte长度
-- 0xxxxxxx - 1 byte
-- 110yxxxx - 192, 2 byte
-- 1110yyyy - 225, 3 byte
-- 11110zzz - 240, 4 byte
local function chsize(char)
    if not char then
        return 0
    elseif char > 240 then
        return 4
    elseif char > 225 then
         return 3
    elseif char > 192 then
        return 2
    else
        return 1
    end
end
 
-- 计算utf8字符串字符数, 各种字符都按一个字符计算
-- 例如utf8len("1你好") => 3
function utf8len(str)
    local len = 0
    local currentIndex = 1
    while currentIndex <= #str do
        local char = string.byte(str, currentIndex)
        currentIndex = currentIndex + chsize(char)
        len = len +1
    end
    return len
end

-- 截取utf8 字符串
-- str:            要截取的字符串
-- startChar:    开始字符下标,从1开始
-- numChars:    要截取的字符长度
function utf8sub(str, startChar, numChars)
    local startIndex = 1
    while startChar > 1 do
        local char = string.byte(str, startIndex)
        startIndex = startIndex + chsize(char)
        startChar = startChar - 1
    end

    local currentIndex = startIndex

    while numChars > 0 and currentIndex <= #str do
        local char = string.byte(str, currentIndex)
        currentIndex = currentIndex + chsize(char)
        numChars = numChars -1
    end
    return str:sub(startIndex, currentIndex - 1)
end

------------------float 相关比较函数 --------------------------------
function compareFloat( fCurValue, fOtherValue, fMinFloatOffset )
    fMinFloatOffset = fMinFloatOffset or GetDefineVariable(config, "MinFloatOffset") or 0.001
    local fDiffValue = fCurValue - fOtherValue
    if fDiffValue < -fMinFloatOffset then
        return -1
    end
    if fDiffValue > fMinFloatOffset then
        return 1
    end
    return 0
end
-- 是否等于
function isEqualThanByFloat( fCurValue, fOtherValue, fMinFloatOffset )
    return compareFloat(fCurValue, fOtherValue, fMinFloatOffset) == 0
end
-- 是否小于
function isLessThanByFloat( fCurValue, fOtherValue, fMinFloatOffset )
    return compareFloat(fCurValue, fOtherValue, fMinFloatOffset) == -1
end
-- 是否大于
function isGreaterThanByFloat( fCurValue, fOtherValue, fMinFloatOffset )
    return compareFloat(fCurValue, fOtherValue, fMinFloatOffset) == 1
end
-- 是否小于等于
function isLessEqualThanByFloat( fCurValue, fOtherValue, fMinFloatOffset )
    local iResult = compareFloat(fCurValue, fOtherValue, fMinFloatOffset)
    return iResult <= 0
end
-- 是否大于等于
function isGreaterEqualThanByFloat( fCurValue, fOtherValue, fMinFloatOffset )
    local iResult = compareFloat(fCurValue, fOtherValue, fMinFloatOffset)
    return iResult >= 0
end


-----------------------开启全局表保护-------------------
local declaredNames = {} 

-----------------------------------------------------
--##JSCodeClose##Start##--js不支持

--该table用于存储所有已经声明过的全局变量名
function EnableGlobalTableProtect( createVariableCallback, noFoundVariableCallback )
    local mt = {
        __newindex = function(gTable, name, value)
            if gTable ~= _G then
                rawset(gTable, name, value)
                return
            end
            --先检查新的名字是否已经声明过，如果存在，这直接通过rawset函数设置即可。
            if not declaredNames[name] then
                -- --再检查本次操作是否是在主程序或者C代码中完成的，如果是，就继续设置，否则报错。
                -- local w = debug.getinfo(2,"S").what
                -- if w ~= "main" and w ~= "C" then
                --     error("attempt to write to undeclared variable " .. name)
                -- end
                --在实际设置之前，更新一下declaredNames表，下次再设置时就无需检查了。
                declaredNames[name] = true
            end
            if createVariableCallback then
                createVariableCallback(name, value)
            else
                print("Setting " .. name .. " to " .. value)
            end
            rawset(gTable, name, value)
        end,
        
        __index = function(gTable, name)
            if gTable ~= _G or name == "__isClass" then
                return rawget(gTable, name)
            end
            if not declaredNames[name] then
                if noFoundVariableCallback then
                    noFoundVariableCallback(name)
                else
                    error("attempt to read undeclared variable " .. name)
                end
                return nil
            else
                return rawget(gTable, name)
            end
        end
    }    
    setmetatable(_G, mt)
end
--##JSCodeClose##End##--js不支持
-----------------------------------------------------
 
--获取可选的全局变量
function GetDefineVariable( gTable, name )
    local value = rawget(gTable, name)
    if value == nil then
        return nil
    end
    return value
end

function HasDefineGlobal( name )
    if declaredNames[name] then
        return true
    end
    local value = rawget(_G, name)
    if value == nil then
        return false
    end
    return true
end

-----------------------------------------------------


-----------------------------------------------------
--##JSCodeClose##Start##--js不支持

-- 获取动态参数列表
function getVarArgs( ... )
    local num = select("#", ...)
    local arg = {}
    if not num then
        return arg
    end
    for index=1, num do
        local value = select(index, ...)
        -- 不能插入 nil  数量可能不一致
        table.insert(arg, value)
    end
    return arg
end
-- 打包参数
pack = getVarArgs

-- 获取动态参数数量
function getVarArgsCount( ... )
    return select("#", ...)
end
-- 获取指定动态参数
function getVarArgsByIndex(index, ...)
    return select(index, ...)
end

function packFunction(func, ...)
    if not func then
        return nil
    end
    local argCount = getVarArgsCount(...)
    if argCount <= 0 then
        return func
    end 
    -- local dFuncInfoStr = getCurFuncCallInfo()

    local lArgList = getVarArgs(...)

    return function( ... )
        local curArgCount = getVarArgsCount(...)
        local curArg = {}
        for index = 1, argCount + curArgCount do
            if index <= argCount then
                table.insert(curArg, lArgList[index])
            else
                local value = getVarArgsByIndex(index - argCount, ...)
                table.insert(curArg, value)
            end
        end
        -- com.debug("packFunction.On = ", dFuncInfoStr)
        return func(unpack(curArg))
    end
end

-- 获取当前函数调用方信息
function getCurFuncCallInfo( dFuncInfo )
    local dFuncInfo = dFuncInfo or debug.getinfo(3, "nSl")
    if not dFuncInfo then
        return ""
    end
    local sFileName = dFuncInfo.short_src
    local sFuncName = dFuncInfo.name or "none"
    local iFuncLine = dFuncInfo.currentline
    local iFunDefined = dFuncInfo.linedefined
    local dFuncInfoStr = string.format("Func(%s|%s:%s/%s)", sFileName, sFuncName, iFuncLine, iFunDefined)
    return dFuncInfoStr, sFuncName
end

--##JSCodeClose##End##--js不支持
-----------------------------------------------------

-- 获取字节描述
function GetBufferLenFormatStr(length)
    -- 字节
    if length < 0x400 then
        return string.format("%3db", length)
    end
    
    -- KB
    if length < 0x100000 then
        return string.format("%3.2fKB", (length / 0x400))
    -- MB
    elseif length < 0x40000000 then
        return string.format("%3.2fMB", (length / 0x100000))
    -- GB
    elseif length < 0x10000000000 then
        return string.format("%3.2fGB", (length / 0x40000000))
    end

    return string.format("%3.2fTB", (length / 0x10000000000))
end
----------------------------------------------------------
local expressionDict = {}
-- 编译表达式
function compile(expression)
    if not expressionDict[expression] then
        local funcObj, errMsg = loadstring("do\nreturn " .. expression .. "\nend")
        if not funcObj then
            com.error("compile(%s) error = %s", expression, errMsg)
            return nil
        end
        expressionDict[expression] = funcObj
    end
    return expressionDict[expression]
end
-- 重载编译缓存
function reloadComplie( ... )
    expressionDict = {}
end
--##JSCodeClose##Start##--js不支持
-- 在argDict环境里 执行表达式expression
function eval(expression, argDict)
    if not expression then
        return nil
    end
    local compileCode = compile(expression)
    if not compileCode then
        return nil
    end
    if argDict then
        argDict["math"] = math
        setfenv(compileCode, argDict)
    end
    return compileCode()
end
--##JSCodeClose##End##--js不支持

-- 编译lua代码
function compile2(luaStr)
    return assert(loadstring(luaStr))
end

-- 运行lua代码
function eval2(luaStr)
    if not luaStr then
        return nil
    end
    local compileCode = compile2(luaStr)
    if not compileCode then
        return nil
    end
    return compileCode()
end
----------------------------------------------------------
local jsonExpressionDict = {}
-- 编译json表达式
function reloadJsonComplie( ... )
    jsonExpressionDict = {}
end
-- 获取json解析结果
function __getJsonDecodeValue(value, isCopy)
    if isCopy and type(value) == "table" then
        value = table.deepCopy(value, 3)
    end
    return value
end
-- 解析json表达式
function Json_Decode(expression, isCopy)
    if not jsonExpressionDict[expression] then
        jsonExpressionDict[expression] = json.decode(expression)
    end
    return __getJsonDecodeValue(jsonExpressionDict[expression], isCopy)
end
-- 编译数据为json表达式
function Json_Encode(expression)
    return json.encode(expression)
end
----------------------------------------------------------
-- 获取json常量配置
function getJsonConstConfig( dConfigDict )
    local dNewConfig = {}
    for sConfigKey, dConfigInfo in pairs(dConfigDict) do
        local sValueStr = dConfigInfo["Value"]
        local pValue = Json_Decode(sValueStr)
        dNewConfig[sConfigKey] = pValue
    end
    return dNewConfig
end
----------------------------------------------------------
string.isEmpty = function(str)
	return not str or str == ""
end
string.isVail = function(str)
	return str and str ~= ""
end

-- 判断字符串前缀
string.startWith = function( str, subStr )
    local count = string.len(subStr)
    return string.sub(str, 1, count) == subStr
end
-- 判断字符串后缀
string.endWith = function( str, subStr )
    local count = string.len(subStr)
    return string.sub(str, -count) == subStr
end

-----------------------------------------------------
--##JSCodeClose##Start##--js不支持

string.replace = function(str, pattern, repl)
    pattern = string.gsub(pattern, "%%", "%%")
    return string.gsub(str, pattern, repl)
end

--##JSCodeClose##End##--js不支持
-----------------------------------------------------

local PATTERN_SIGNCHAR = {
    ["("] = "%(",
    [")"] = "%)",
    ["."] = "%.",
    ["%"] = "%%",
    ["+"] = "%+",
    ["-"] = "%-",
    ["*"] = "%*",
    ["?"] = "%?",
    ["["] = "%[",
    ["^"] = "%^",
    ["$"] = "%$",
    ["]"] = "%]",
}

-- 获取字符串映射
string.map = function(str, charMapping)
    str = tostring(str)
    if not charMapping then
        return str
    end

    local newStr = string.gsub(str, ".", function( char )
        local patChar = PATTERN_SIGNCHAR[char] or char
        local index = string.find(charMapping.Origin, patChar)
        if not index then
            return char
        end
        return string.sub(charMapping.Target, index, index)
    end)
    return newStr
end

-----------------------------------------------------
--##JSCodeClose##Start##--js不支持

-- split缓存
local g_splitCache = {}
string.split = function(s, p)
    if not s then
        return nil
    end
    p = p or " "
    -- split缓存
    if g_splitCache[s] then
        return g_splitCache[s]
    end

    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) 
        -- w not -> nil false
        w = string.strip(w)
        table.insert(rt, w) 
    end )
    g_splitCache[s] = rt
    return rt
end

--##JSCodeClose##End##--js不支持
-----------------------------------------------------

-- strip缓存
local g_stripCache = {}
local function __strip(str, regex, rep)
    if g_stripCache[str] and g_stripCache[str][regex] and g_stripCache[str][regex][rep] then
        return g_stripCache[str][regex][rep]
    end
    local ret = string.gsub(str, regex, rep)
    if not g_stripCache[str] then
        g_stripCache[str] = {}
    end
    if not g_stripCache[str][regex] then
        g_stripCache[str][regex] = {}
    end
    g_stripCache[str][regex][rep] = ret
    return ret
end


--去除左边空格
string.lstrip = function(str, stripStr)
    stripStr = stripStr or "%s*"
    local result = __strip(str, "^" .. stripStr, "")
    return result
end

--去除右边空格
string.rstrip = function(str, stripStr)
    stripStr = stripStr or "%s*"
    local result = __strip(str, stripStr .. "$", "")
    return result
end

--去除两端空格
string.strip = function(str, stripStr)
    stripStr = stripStr or "%s*"
    local result = string.lstrip(string.rstrip(str, stripStr), stripStr)
    return result
end

--去除所有空格
string.allstrip = function(str)
    return string.gsub(str, " ", "")
end

----------------------------------------------------------
local bEnableB2Vec2 = false
if GetDefineVariable then
    if GetDefineVariable(_G, "b2Vec2") then
        bEnableB2Vec2 = true
    end
elseif b2Vec2 then
    bEnableB2Vec2 = true
end

-- box2d 相关函数
if bEnableB2Vec2 then

    -- 2维向量 字符串格式化输出
    function b2Vec2:__str__( ... )
        return string.format("b2Vec2(%s, %s)", self.x, self.y)
    end
    function b2Rot:__str__( ... )
        return string.format("b2Rot(angle=%s, s=%s, c=%s)", self:GetAngle(), self.s, self.c)
    end
    function b2Body__str__( ... )
        return string.format("b2Body(angle=%s, pos=%s)", self:GetAngle(), string.getStr(self:GetPosition()))
    end

    --- Rotate a vector:  b2Mul(const b2Rot& q, const b2Vec2& v)
    function b2Mul(q, v)
        return b2Vec2(q.c * v.x - q.s * v.y, q.s * v.x + q.c * v.y)
    end

    function b2Vec2Length( vec2 )
        return math.sqrt(vec2.x * vec2.x + vec2.y * vec2.y)
    end

    -- 映射精灵到刚体
    function SyncBodyBySprite( body, sprite, ptm_ratio )
        local pCurPos = cc.p(sprite:getPosition())
        local locationWorld = ccp2Vec2(pCurPos, ptm_ratio)
        body:SetTransform(locationWorld, -1 * CC_DEGREES_TO_RADIANS(sprite:getRotation()))
    end
    -- 映射刚体到精灵
    function SyncSpriteByBody( body, sprite, ptm_ratio, bNotBindRotation )
        local pos = body:GetPosition()
        local pSpritePos = vec2ccp(pos, ptm_ratio)


        sprite:setPosition(pSpritePos)

        -- 不绑定角度
        if not bNotBindRotation then
            sprite:setRotation(-1 * CC_RADIANS_TO_DEGREES(body:GetAngle()))
        end
    end

    -- ccpoint 转换 box2d向量
    function ccp2Vec2( pos, ptm_ratio, scale )
        ptm_ratio = ptm_ratio or 1
        scale = scale or 1
        return b2Vec2:new_local(pos.x / ptm_ratio * scale, pos.y / ptm_ratio * scale)
    end
    -- box2d向量 转换 ccpoint
    function vec2ccp( pos, ptm_ratio, scale )
        ptm_ratio = ptm_ratio or 1
        scale = scale or 1
        return cc.p(pos.x * ptm_ratio * scale, pos.y * ptm_ratio * scale)
    end

    function getRectPoints( rect, offsetPos )
        if not offsetPos then
            offsetPos = {x=0, y=0}
        end
        local points = {
            cc.p(rect.origin.x - offsetPos.x, rect.origin.y - offsetPos.y),
            cc.p(rect.origin.x - offsetPos.x + rect.size.width, rect.origin.y - offsetPos.y),
            cc.p(rect.origin.x - offsetPos.x + rect.size.width, rect.origin.y - offsetPos.y + rect.size.height),
            cc.p(rect.origin.x - offsetPos.x, rect.origin.y - offsetPos.y + rect.size.height),
        }
        return points
    end

    -- 创建向量数组 () ptm_ratio box2d比例尺;  centerPos 中心点，可选)
    function createB2Vec2Array( points, ptm_ratio, centerPos, scaleX, scaleY, isFlipX, isFlipY, offsetPos)
        -- com.debug("createB2Vec2Array(%s, %s, %s)", points, ptm_ratio, centerPos)

        local count = #points
        local pointArray = {}

        local pos, posX, posY
        for index = 1, count do
            pos = points[index]

            posX = pos.x
            posY = pos.y
            -- 中心点坐标
            if centerPos then
                posX = posX - centerPos.x
                posY = posY - centerPos.y
            end

            -- 偏移位置
            if offsetPos then
                posX = posX + offsetPos.x
                posY = posY + offsetPos.y
            end
            
            if scaleX then
                posX = posX * scaleX
            end
            if scaleY then
                posY = posY * scaleY
            end

            -- 是否水平翻转
            if isFlipX then
                posX = -posX
            end
            if isFlipY then
                posY = -posY
            end
            -- 计算坐标比例
            table.insert(pointArray, {posX / ptm_ratio, posY / ptm_ratio})
        end
        
        local vertices = sc.Box2dLayer:createB2Vec2Array(pointArray)
        return vertices
    end

    -- 清理向量数组
    function clearB2Vec2Array( vertices )
        sc.Box2dLayer:clearB2Vec2Array(vertices)
    end

    -- 创建用户数据
    function createUserData( value )
        return sc.Box2dLayer:createUserData(value)
    end

    -- 获取用户数据指针
    function getUserDataValue( value )
        return sc.Box2dLayer:getUserDataValue(value)
    end


    -- 是否存在新版接口
    local bNewBox2dUserData = sc.Box2dLayer.SetUserData ~= nil
    if bNewBox2dUserData then
        -- 设置用户数据
        function SetUserData( pObject, value )
            sc.Box2dLayer:SetUserData(pObject, value)
        end
        -- 获取用户数据
        function GetUserData( pObject )
            return sc.Box2dLayer:GetUserData(pObject)
        end
    else
        -- 设置用户数据
        function SetUserData( pObject, value )
            pObject:SetUserData(createUserData(value))
        end
        -- 获取用户数据
        function GetUserData( pObject )
            return getUserDataValue(pObject:GetUserData())
        end
    end





    -- 设置物体质心
    function SetMassCenterPosition( body, center )
        return sc.Box2dLayer:SetMassCenterPosition(body, center)
    end

    -- 创建定制器定义
    function createFixtureDef( fixtureDefine )
        local fixtureDef = b2FixtureDef:new_local()

        local shapeObj = createShape(fixtureDefine)
        fixtureDef.shape = shapeObj

        fixtureDef.isSensor = fixtureDefine.isSensor or false

        if fixtureDefine.groupIndex then
            fixtureDef.filter.groupIndex = fixtureDefine.groupIndex
        end
        if fixtureDefine.categoryBits then
            fixtureDef.filter.categoryBits = fixtureDefine.categoryBits
        end
        if fixtureDefine.maskBits then
            fixtureDef.filter.maskBits = fixtureDefine.maskBits
        end
        fixtureDef.density = fixtureDefine.density or 1.0
        fixtureDef.friction = fixtureDefine.friction or 0.2
        fixtureDef.restitution = fixtureDefine.restitution or 1

        return fixtureDef
    end

    -- 创建形状
    function createShape( shapeDefine )

        -- 类型
        local shapeType = shapeDefine.ShapeType
        -- 对象
        local shapeObj = shapeType:new_local()

        -- 属性
        if table.isNotEmpty(shapeDefine.ShapeProperty) then
            for propertyName, value in pairs(shapeDefine.ShapeProperty) do
                if shapeObj[propertyName] then
                    shapeObj[propertyName] = value
                end
            end
        end

        -- 属性设置函数
        if table.isNotEmpty(shapeDefine.ShapeCallFunc) then
            for propertyFuncName, argList in pairs(shapeDefine.ShapeCallFunc) do
                if shapeObj[propertyFuncName] then
                    shapeObj[propertyFuncName](shapeObj, unpack(argList))
                end
            end
        end
        return shapeObj
    end

    ---------------------------- 圆形例子
    -- Shape = {
    --  Image = "ball1",

    --  -- 圆形
    --  ShapeType = b2CircleShape,
    --  -- 属性
    --  ShapeProperty = {
    --      -- 半径
    --      m_radius = 10,
    --      -- 位置
    --      m_p = b2Vec2(),
    --  },
    --  -- 属性设置函数
    --  ShapeCallFunc = {
    --  },

    -- }
    -- createShape(Shape)
    -- 边界 b2EdgeShape

    ---------------------------- 凸多边形 例子
    -- Shape = {
    --     Image = "ball2",

    --     -- 凸多边形
    --     ShapeType = b2PolygonShape,
    --     -- 属性
    --     ShapeProperty = {
    --     },
    --     -- 属性设置函数
    --     ShapeCallFunc = {
    --         // set
    --         Set = {
    --             -- 5边形的坐标列表
    --             createB2Vec2Array({
    --                 ccp(-10, 3),
    --                 ccp(0, 10),
    --                 ccp(10, 3),
    --                 ccp(5, -8),
    --                 ccp(-6, -8),
    --             }, PTM_RATIO),
    --             -- 5边形
    --             5,
    --         },
    --     },
    -- }
    -- createShape(Shape)
end

-- 获取指定距离和加速度，需要时间，最大速度
function GetSpeedByDistance( distance, acceleration )
    -- com.debug("GetSpeedByDistance(height = %s, acceleration = %s)", distance, acceleration)
    local tick = math.sqrt(2 * distance / math.abs(acceleration))
    local speed = tick * acceleration
    return tick, speed
end

-- 获取指定速度，加速度，时间，求出位移
function GetMoveByAcceleration( fStartSpeed, fAcceleration, fTick )
    return fStartSpeed * fTick + fAcceleration * fTick * fTick
end

----------------------------------------------------------
-- 创建贝塞尔曲线配置 第一控制点 第二控制点，结束点
function BezierConfigMake( pStartPos, pCenterPos, pEndPos)

    local bezierCfg = {
        pStartPos,
        pCenterPos,
        pEndPos,
    }
    return bezierCfg
end

-- 创建模拟贝塞尔曲线动画
function CreateSimulateBezierAction( fTick, iPointCount, pStartPos, pCenterPos, pEndPos )
    local lMoveActionList = {}
    local lPointsList = GetSimulateBezierPoints( pStartPos, pCenterPos, pEndPos, iPointCount)
    local fIntervalTick = fTick / iPointCount
    for _, pTargetPos in pairs(lPointsList) do
        local pMoveAction = cc.MoveTo:create(fIntervalTick, pTargetPos)
        table.insert(lMoveActionList, pMoveAction)
    end
    local pSimulateBezierAction = cc.Sequence:create(lMoveActionList)
    return pSimulateBezierAction
end

-- 创建模拟贝塞尔曲线动画（恒定速度）
function CreateSimulateVelocityBezierAction( fVelocity, iPointCount, pStartPos, pCenterPos, pEndPos )
    local lMoveActionList = {}
    local lPointsList = GetSimulateBezierPoints( pStartPos, pCenterPos, pEndPos, iPointCount)
    --local fIntervalTick = fTick / iPointCount
    local lastPos = pStartPos
    local fAllTick = 0
    for _, pTargetPos in pairs(lPointsList) do
        local dis = cc.pGetDistance(lastPos, pTargetPos)
        local fIntervalTick = math.abs(dis) / fVelocity
        fAllTick = fAllTick + fIntervalTick
        local pMoveAction = cc.MoveTo:create(fIntervalTick, pTargetPos)
        table.insert(lMoveActionList, pMoveAction)
        lastPos = pTargetPos
    end
    local pSimulateBezierAction = cc.Sequence:create(lMoveActionList)
    return pSimulateBezierAction, fAllTick
end

-- 创建模拟贝塞尔曲线动画带角度旋转（恒定速度）
function CreateSimulateVelocityBezierWithRotate( fVelocity, iPointCount, pStartPos, pCenterPos, pEndPos )
    local lMoveActionList = {}
    local lRotateActionList = {}
    local lPointsList = GetSimulateBezierPoints( pStartPos, pCenterPos, pEndPos, iPointCount)
    --local fIntervalTick = fTick / iPointCount
    local lastPos = pStartPos
    local fAllTick = 0
    for _, pTargetPos in pairs(lPointsList) do
        local dis = cc.pGetDistance(lastPos, pTargetPos)
        local fIntervalTick = math.abs(dis) / fVelocity
        fAllTick = fAllTick + fIntervalTick
        local pMoveAction = cc.MoveTo:create(fIntervalTick, pTargetPos)
        local angle = cc.pGetAngle(pTargetPos, lastPos) 
        local pRotateAction = cc.RotateTo:create(fIntervalTick, CC_RADIANS_TO_DEGREES(angle))
        table.insert(lMoveActionList, pMoveAction)
        table.insert(lRotateActionList, pRotateAction)
        lastPos = pTargetPos
    end
    local pSimulateBezierAction = cc.Sequence:create(lMoveActionList)
    local pRotateSequenceAction = cc.Sequence:create(lRotateActionList)
    local pAction = cc.Spawn:create({pSimulateBezierAction, pRotateSequenceAction})
    return pAction, fAllTick
end

-- 获取贝塞尔曲线坐标列表(iPointCount取点数)
function GetSimulateBezierPoints( pStartPos, pCenterPos, pEndPos, iPointCount)

    local fTick = 1
    local pAction = cc.BezierTo:create(fTick, {
        pStartPos,
        pCenterPos,
        pEndPos,
    })

    -- 初始化全局模拟贝塞尔节点
    if not GetDefineVariable(_G, "__SimulateBezierNode") then
        _G.__SimulateBezierNode = cc.Node:create()
        _G.__SimulateBezierNode:retain()
    end

    _G.__SimulateBezierNode:setPosition(pStartPos)
    pAction:startWithTarget(_G.__SimulateBezierNode)

    local lPointsList = {}
    local fIntervalTick = fTick / iPointCount
    for iIndex = 1, iPointCount do
        pAction:update(fIntervalTick * iIndex)

        local pTargetPos = cc.p(_G.__SimulateBezierNode:getPosition())
        table.insert(lPointsList, pTargetPos)
    end

    return lPointsList
end

----------------------------------------------------------

_G["cc.SpriteFrame__str__"] = function ( spriteFrame )
    return string.format("SpriteFrame(%s, %s)", string.getStr(spriteFrame:getRect()), string.getStr(spriteFrame:getOriginalSize()))
end
_G["cc.Node__str__"] = function( pNode )
    local x, y = pNode:getPosition()
    return string.format("Node[%s]{x:%3.4f, y:%3.4f}", tostring(pNode), x, y)
end
_G["cc.Sprite__str__"] = function( sprite )
    local texture, textureName
    if sprite.getTexture then
        texture = sprite:getTexture()
        if texture then
            textureName = texture:getName()
        else
            textureName = "EmptyImage"
        end
    else
        textureName = "None"
    end
    local x, y = sprite:getPosition()
    return string.format("Sprite[%s](%s){x:%3.4f, y:%3.4f}", tostring(sprite), textureName, x, y)
end
-----------------------------------------------------------
-- 序列化函数
string.getLuaStr = function( value )
    local vType = type(value)
    if vType == "string" then
        -- 据说 .. 效率 比 string.format 高
        return '"' .. value .. '"'
        -- return string.format('"%s"', value)
    elseif vType == "boolean" then
        return value and "true" or "false"
    elseif vType == "number" then
        return tostring(value)
    elseif vType == "table" then
        if isInstance(value) then
            if value.__serialize__ then
                return value:__serialize__()
            end
            return string.format('"classObj(%s)"', GetObjectIndex(value))
        else
            local nstr = {}
            local nlistCount = #value
            if table.getCount(value) == nlistCount then
                table.insert(nstr, "{")
                for index = 1, nlistCount do
                    -- 据说 .. 效率 比 string.format 高
                    table.insert(nstr, string.getLuaStr(value[index]) .. ",")
                    -- table.insert(nstr, string.format("%s,", string.getLuaStr(value[index])))
                end
                table.insert(nstr, "}")
            else
                table.insert(nstr, "{")
                for k, v in pairs(value) do
                    local vStr = string.getLuaStr(v)
                    table.insert(nstr, string.format("[%s] = %s,", string.getLuaStr(k), vStr))
                end
                table.insert(nstr, "}")
            end
            return table.concat(nstr, "")
        end
    elseif vType == "function" then
        -- 据说 .. 效率 比 string.format 高
        return '"' .. tostring(value) .. '"'
        -- return string.format('"%s"', tostring(value))
    end
    return "nil"
end
-- 格式化输出
string.getStr = function( value )
    local vType = type(value)
    if vType == "string" then
        -- 据说 .. 效率 比 string.format 高
        return '"' .. value .. '"'
        -- return string.format('"%s"', value)
    elseif vType == "boolean" then
        return value and "true" or "false"
    elseif vType == "number" then
        return tostring(value)
    elseif vType == "table" then
        if isInstance(value) then
            if value.__str__ then
                return value:__str__()
            end
            return string.format("classObj(%s)", GetObjectIndex(value))
        else
            local nstr = {}
            local nlistCount = #value
            if table.getCount(value) == nlistCount then
                table.insert(nstr, string.format("list(%s)[", nlistCount))
                for index = 1, nlistCount do
                    -- 据说 .. 效率 比 string.format 高
                    table.insert(nstr, string.getStr(value[index]) .. ",")
                    -- table.insert(nstr, string.format("%s,", string.getStr(value[index])))
                end
                table.insert(nstr, "]")
            else
                local isModule = rawget(value, "_M")
                table.insert(nstr, isModule and "Module:{" or "table:{")
                for k, v in pairs(value) do
                    local vStr = isModule and tostring(v) or string.getStr(v)
                    table.insert(nstr, string.format("%s = %s,", string.getStr(k), vStr))
                end
                table.insert(nstr, "}")
            end
            return table.concat(nstr, "")
        end
    elseif vType == "function" then
        -- return tostring(value)
        local dFuncInfoStr = getCurFuncCallInfo(debug.getinfo(value, "nSl"))
        local sFormatInfo = string.format("%s[%s]", tostring(value), dFuncInfoStr)
        return sFormatInfo
    elseif vType == "thread" then
        return tostring(value)
    elseif vType == "userdata" then
        if getmetatable(value) then
            if value.__str__ then
                return value:__str__()
            elseif value.addChild then
                local objName = getNodeTypeName(value)
                if objName and objName ~= "Unknow" then
                    local strFuncName = objName .. "__str__"
                    if HasDefineGlobal(strFuncName) then
                        return _G[strFuncName](value)
                    end
                end
                return string.format("%s(%s)", objName, tostring(value))
            end
        end
        return tostring(value)
    end
    return "nil"
end

-- 获取节点类型名
function getNodeTypeName( obj )
    -- 初始化全局节点代理
    if not GetDefineVariable(_G, "__NodeTypeProxy") then
        _G.__NodeTypeProxy = cc.CCBProxy:create()
        _G.__NodeTypeProxy:retain()
    end

    local objName = _G.__NodeTypeProxy:getNodeTypeName(obj)
    if objName == "No Support" then
        objName = "Unknow"
    end
    return objName
end

----------------------------------------------------------
function _Base_Lua_Retain( obj )
    obj:retain()
end
function _Base_Lua_Release( obj )
    obj:release()
end
----------------------------------------------------------
local g_objDict = {}
local g_defaultObjTyoe = "Main"
local g_curObjType = g_defaultObjTyoe
function Lua_SetObjType( objType )
    g_curObjType = objType or g_defaultObjTyoe
end
function _Lua_Retain( obj, info )
    -- com.debug("Lua_Retain(%s) = %s", obj, info)
    obj:retain()
    local objType = g_curObjType
    if not g_objDict[obj] then
        g_objDict[obj] = {type=objType, count=0, info=info}
    end
    g_objDict[obj].count = g_objDict[obj].count + 1
end
function _Lua_Release( obj )
    -- com.debug("Lua_Release(%s)", obj)
    local objType = g_curObjType
    if not g_objDict[obj] then
        com.error("Lua_Release(%s) Error, no Retain!", obj)
        return
    end
    obj:release()

    g_objDict[obj].count = g_objDict[obj].count - 1

    if g_objDict[obj].count == 0 then
        g_objDict[obj] = nil
    end
end
function Lua_ShowRetainInfo( objType )
    com.info("ShowRetainInfo(%s)", objType)
    for obj, retainInfo in pairs(g_objDict) do
        if retainInfo.type == objType then
            com.info("[%10s](%s)--%s.retainCount(%s)", retainInfo.type, retainInfo.info, obj, retainInfo.count)
            -- com.debug("%s.retainCount(%s)", obj, retainInfo.count)
        end
        -- local realRetainCount = obj:retainCount()
        -- com.debug("%s.retainCount(%s) realCount(%s)", obj, retainCount, 1)--obj:retainCount())
    end
end
function Lua_ShowAllRetainInfo( ... )
    com.info("Lua_ShowAllRetainInfo")
    for obj, retainInfo in pairs(g_objDict) do
        com.info("[%10s](%s)--%s.retainCount(%s)", retainInfo.type, retainInfo.info, obj, retainInfo.count)
    end
end

-- 自动修改对象引用接口
function auto_Ref( bEnable )
    if bEnable then
      _G.Lua_Retain = _G._Lua_Retain
      _G.Lua_Release = _G._Lua_Release
    else
      _G.Lua_Retain = _G._Base_Lua_Retain
      _G.Lua_Release = _G._Base_Lua_Release
    end
end
----------------------------------------------------------

-- 截图( pNode为空截图整个屏幕，否则只截图那个node)
function ScreenshotTo( screenshotPath, pNode )

    com.info("ScreenshotTo = ", screenshotPath)

    local renderTexture = Screenshot(pNode)

    -- 保存为PNG图，Win32/Debug目录下  
    renderTexture:saveToFile(screenshotPath, cc.IMAGE_FORMAT_PNG)
    com.info("ScreenshotTo end= ", screenshotPath)
end
-- pNode为空截图整个屏幕，否则只截图那个node)
function Screenshot( pNode )

    -- 获取屏幕尺寸  
    local size = nil
    if pNode then
        size = pNode:getContentSize() 
    else
        size = cc.Director:getInstance():getWinSize()  
    end

    -- 画布
    local renderTexture = cc.RenderTexture:create(size.width, size.height)
    -- 设置位置      
    renderTexture:setAnchorPoint(cc.p(0, 0))
    -- 开始获取      
    renderTexture:begin()

    -- 截图特定控件
    if pNode then
        local bVisible = pNode:isVisible()
        local fPosX, fPosY = pNode:getPosition()
        local pAnchorPos = pNode:getAnchorPoint()

        pNode:setVisible(true)
        pNode:setPosition(0, 0)
        pNode:setAnchorPoint(0, 0)
        pNode:visit()
        pNode:setVisible(bVisible)
        pNode:setPosition(fPosX, fPosY)
        pNode:setAnchorPoint(pAnchorPos)

    -- 截图整个屏幕
    else
        -- 遍历场景节点对象，填充纹理到texure中  
        cc.Director:getInstance():getRunningScene():visit()
    end
    -- 结束获取  
    renderTexture:endToLua()

    return renderTexture
end
----------------------------------------------------------

function DumpNodeInfo( obj, index )
    if not config.IsDebug then
        return
    end

    index = index or 0
    if index == 0 then
        com.debug("DumpNodeInfo(%s)", tostring(obj))
    end
    if not getNodeTypeName( obj ) then
        return
    end
    local childrenArray = obj:getChildren()
    local count = childrenArray and table.getCount(childrenArray)
   -- local retainCount = obj:retainCount()
    local indentStr = string.rep("\t", index)
    if count <= 0 then
        --com.debug("%s%s retainCount = %3s", indentStr, obj, retainCount)
        return
    else
        --com.debug("%s%s retainCount = %3s getChildrenCount = %3s", indentStr, obj, retainCount, count)
    end
    local childIndex = index + 1
    for _, child in pairs(childrenArray) do
        DumpNodeInfo(child, childIndex)
    end
end

-- 遍历所有控件
function MapControl( root, mapFunc )
    -- 执行逻辑
    mapFunc(root)

    local childrenArray = root:getChildren()
    for _, child in pairs(childrenArray) do
        MapControl(child, mapFunc)
    end
end

-- 遍历所有控件(根据返回值控制是否遍历子节点, true停止遍历子节点)
function MapControlEx( root, mapFunc )
    -- 执行逻辑
    if mapFunc(root) then
        return
    end

    local childrenArray = root:getChildren()
    for _, child in pairs(childrenArray) do
        MapControlEx(child, mapFunc)
    end
end

function FixWindowFont( root, fontName )
    -- 遍历文本控件，修改字体
    MapControl(root, function( node )
        if getNodeTypeName(node) == "cc.LabelTTF" then
            local label = tolua.cast(node, "cc.LabelTTF")
            label:setFontName(fontName)
        end
    end)
end

-- 通用翻转节点
function DoFlippedNode( pNode, bFlippedX, bFlippedY )
    if not pNode then
        return
    end
    local pAnchorPos = pNode.OrgAnchor or pNode:getAnchorPoint()
    pNode.OrgAnchor = pAnchorPos

    local pNewAnchor = cc.p(pNode.OrgAnchor)

    if bFlippedX then
        local fScaleX = pNode.OrgScaleX or pNode:getScaleX()
        pNode.OrgScaleX = fScaleX
        pNode:setScaleX(-fScaleX)
        pNewAnchor.x = 1 - pNewAnchor.x
    end
        
    if bFlippedY then
        local fScaleY = pNode.OrgScaleY or pNode:getScaleY()
        pNode.OrgScaleY = fScaleY
        pNode:setScaleY(-fScaleY)
        pNewAnchor.y = 1 - pNewAnchor.y
    end

    pNode:setAnchorPoint(pNewAnchor)
end
-- 恢复节点翻转
function ResumeFlippedNode( pNode, bFlippedX, bFlippedY )
    if not pNode then
        return
    end
    if pNode.OrgAnchor then
        pNode:setAnchorPoint(pNode.OrgAnchor)
    end
    if pNode.OrgScaleX then
        pNode:setScaleX(pNode.OrgScaleX)
    end
    if pNode.OrgScaleY then
        pNode:setScaleY(pNode.OrgScaleY)
    end
end

-- 是否文本显示类控件(label text button)
function IsTextControl( pControl )
    if IsLabelControl(pControl) then
        return true
    end
    if IsButtonControl(pControl) then
        return true
    end
    if IsRichTextControl(pControl) then
        return true
    end
    return false
end
-- 是否富文本控件
function IsRichTextControl( pControl )
    if pControl.createWithXML and pControl.initWithXML then
        return true
    end
    return false
end
-- 是否按钮控件
function IsButtonControl( pControl )
    if pControl.setTitleText and pControl.getTitleText then
        return true
    end
    return false
end
-- 是否text控件
function IsLabelControl( pControl )
    if pControl.setString and pControl.getString then
        return true
    end
    return false
end
----------------------------------------------------------
-- 随机真假
math.randomBoolean = function( ... )
    return math.checkProbability(50, 100)
end

-- 检查概率
math.checkProbability = function(probability, maxNum)
    if probability < 0 then
        return true
    end
    maxNum = maxNum or 1000
    if probability >= maxNum then
        return true
    end
    return math.random(1, maxNum) <= probability
end

math.checkNumRange = function(index, num, checkIndex)
    local offsetIndex = math.modf(num / 2)
    local startIndex = math.max(1, index - offsetIndex)
    local endIndex = index + offsetIndex
    if checkIndex < startIndex or checkIndex > endIndex then
        return false
    end
    return true
end

-- 随机2个浮点数范围
math.randomFloat = function(fStartValue, fEndValue)
    local fOffsetValue = fEndValue - fStartValue
    fOffsetValue = fOffsetValue * math.random()
    return fStartValue + fOffsetValue
end

-- 四舍五入
math.round = function( value )
    local num, sub = math.modf(value)
    if sub >= 0.5 then
        return num + 1
    end
    return num
end
-- math.ceil 向上取整
-- math.floor 向下取整
----------------------------------------------------------
-- 拷贝
function clone(obj)
    if type(obj) == "table" then
        obj = table.copy(obj)
    end
    return obj 
end
----------------------------------------------------------
-- 列表中随机选择一个元素
table.randomChooseOne = function( list )
    local key, value = table.getFirst(table.randomChoose(list))
    return key, value
end
-- 列表中随机选择指定数量元素
table.randomChoose = function(list, count)
    count = count or 1
    local num = table.getCount(list)
    if num <= 0 then
        return {}
    end
    if num <= count then
        return table.copy(list)
    end
    local indexList = table.range(num)
    local removeCount = num - count
    local curCount = num
    while removeCount > 0 do
        local removeIndex = math.random(curCount)
        table.remove(indexList, removeIndex)
        
        removeCount = removeCount - 1
        curCount = curCount - 1
    end
    local indexDict = {}
    for _, index in pairs(indexList) do
        indexDict[index] = true
    end

    local curIndex = 0
    local chooseList = {}
    for key, value in pairs(list) do
        curIndex = curIndex + 1
        if indexDict[curIndex] then
            chooseList[key] = value
        end
    end
    return chooseList
end

table.randomChooseOneByList = function( list )
    local randomKey = math.random(1, #list)
    local randomValue = list[randomKey]
    return randomValue, randomKey
end
----------------------------------------------------------
-- 求和
table.sum = function(list)
    local num = 0
    for _, value in pairs(list) do
        num = num + value
    end
    return num
end
-- 求平均值
table.average = function(list)
    local num, count = 0, 0
    for _, value in pairs(list) do
        num = num + value
        count = count + 1
    end
    return num / count
end
-- 获得指定数字内容的列表(类似python 的range函数)
table.range = function(endIndex, startIndex)
    startIndex = startIndex or 1
    local indexList = {}
    for index = startIndex, endIndex do
        table.insert(indexList, index)
    end
    return indexList
end
-- 获取重复某个值指定次数的列表
table.repeatList = function ( pValue, iCount )
    local lNewList = {}
    for iIndex = 1, iCount do
        table.insert(lNewList, pValue)
    end
    return lNewList
end
-- 列表中删除某个值
table.removeValue = function(list, value)
    local index = table.indexOf(list, value)
    if not index then
        return
    end
    table.remove(list, index)
end
-- 列表更新操作
table.update = function(dict, newData)
	if not dict then
		return nil
	end
    if not newData then
        return dict
    end
	for key, value in pairs(newData) do
		dict[key] = value
	end
	return dict
end
-- 求某个值的索引
table.indexOf = function(list, value)
    if not list then
        return nil
    end
	for index, eValue in pairs(list) do
		if eValue == value then
			return index
		end
	end
	return nil
end
-- 获得key列表
table.keys = function(list)
    if not list then
        return nil
    end
    local keyList = {}  
    for key, value in pairs(list) do  
        table.insert(keyList, key)
    end
    return keyList
end
-- 获取列表对应的字典
table.toDict = function( list )
    local dict = {}
    for _, value in pairs(list) do
        dict[value] = true
    end
    return dict
end
-- 判断是否存在某个值
table.hasValue = function(list, value)
	if table.indexOf(list, value) then
        return  true
    end
    return false
end
-- 检测列表是否相同
table.equal = function(list, newList)
    local newCount = table.getCount(newList)
    local curCount = 0
    for key, value in pairs(list) do
        if newList[key] ~= value then
            return false
        end
        curCount = curCount + 1
    end
    return curCount == newCount
end
-- 列表浅拷贝
table.copy = function(list)
    if not list then
        return nil
    end
    if list.copy then
        return list:copy()
    end
    local newList = {}  
    for key, value in pairs(list) do  
    	newList[key] = value
    end 
    setmetatable(newList, getmetatable(list))
    return newList 
end
-- 列表深拷贝
table.deepCopy = function(list, deepCount)
    -- com.debug("list = %s, deepCount = %s", list, deepCount)
    if list.deepCopy then
        return list:deepCopy(deepCount)
    end
    if not deepCount or deepCount <= 0 then
        return table.copy(list)
    end
    deepCount = deepCount - 1
    local newList = {}  
    for key, value in pairs(list) do 
        if type(value) == "table" then
            value = table.deepCopy(value, deepCount)
        end 
        newList[key] = value
    end 
    setmetatable(newList, getmetatable(list))
    return newList 
end
-- 排序函数
function descSortFunc(curValue, nextValue)
    return curValue > nextValue
end
-- 列表降序排序
table.descSort = function(list)
    if not list then
        return
    end
    table.sort(list, descSortFunc)  
end
-- 获取值列表
table.values = function(list, isDescSort)  
    local dataList = {}
    for key, value in table.pairsByKeys(list, isDescSort) do
       table.insert(dataList, value) 
    end
    return dataList
end
-- 获取列表第一个元素
table.getFirst = function(list)
    for key, value in pairs(list) do  
        return key, value
    end  
    return nil
end
-- 获取列表最后一个元素
table.getLast = function(list)
    if not list then
        return nil
    end
    local count = #list
    return list[count]
end
-- 弹出列表最后一个元素
table.popList = function(list)
    if not list then
        return nil
    end
    local count = #list
    local pValue = list[count]
    list[count] = nil
    return pValue
end
-- 出栈
table.pop = function(list)
    if not list then
        return nil
    end

    if table.isEmpty(list) then
        return nil
    end

    local keyList = table.keys(list)

    table.sort(keyList)
    local selectKey = table.remove(keyList)
    local selectValue = list[selectKey]
    list[selectKey] = nil
    -- local value = table.remove(list, selectKey)

    return selectValue
end

-- 列表顺序遍历迭代器(可指定排序方向 或 排序函数)
table.pairsByKeys = function(list, isDescSort, sortFunc)  
    local keyList = {}  
    for key in pairs(list) do  
        table.insert(keyList, key)
    end  
    if sortFunc then
        table.sort(keyList, sortFunc)  
    elseif isDescSort then
        table.descSort(keyList)  
    else
        table.sort(keyList)  
    end
    local index = 0  
    return function()  
        index = index + 1  
        return keyList[index], list[keyList[index]]  
    end  
end

-- a={1,1,5,6}
-- table.sort(a, function (x, y)
--     if x >= y then
--         return true
--     end
--     return false
-- end)
-- lua排序中的比较函数必须要保证排序是稳定的。
-- 否则会出现 invalid order function for sorting 异常

-- 列表顺序遍历迭代器(可指定元素个数 和 排序函数)
table.pairsSortListByRange = function(lList, count, sortFunc)
    local keyList = {}  
    for key in pairs(lList) do  
        table.insert(keyList, key)
    end  
    table.sort(keyList, sortFunc) 

    local curIndex = 0
    local keyCount = #keyList
    if count < 0 then
        count = keyCount
    end
    return function()  
        curIndex = curIndex + 1  
        if curIndex > count or curIndex > keyCount then
            return nil
        end
        return keyList[curIndex], lList[keyList[curIndex]]  
    end  
end
-- 获取列表中指定顺序中前n个元素(可指定元素个数 和 排序函数)
table.getSortListByRange = function(lList, index, count, sortFunc)
    local keyList = {}  
    for key in pairs(lList) do  
        table.insert(keyList, key)
    end  
    table.sort(keyList, sortFunc)  

    local endIndex = index + count
    local retList = {}
    for curIndex = 1, table.getCount(keyList) do  
        local key = keyList[curIndex]
        if curIndex >= index and curIndex < endIndex then
            table.insert(retList, key)
        end
    end  
    return retList
end
-- 获取列表(list)中指定位置(index)的开始后指定个数(count)元素
table.getListByCapture = function(lList, index, count)
    local captureList = {}
    local endIndex = index + count 
    for curIndex = 1, table.getCount(lList) do 
        local value = lList[curIndex]
        if curIndex >= index and curIndex < endIndex then
            table.insert(captureList, value)
        end
    end
    return captureList
end

-- 获取列表元素数量（支持 字典）
table.getCount = function(list)
    if not list then
        return 0
    end
 	local num = 0
    for key in pairs(list) do  
    	num = num + 1
    end  
    return num
end
-- 判断列表是否存在符合指定条件的元素
table.some = function(list, filterFunc, ...)
    for key, value in pairs(list) do  
    	if filterFunc(key, value, ...) then
    		return true
    	end
    end  
    return false
end
-- 判断列表元素是否 全部符合指定条件
table.every = function(list, filterFunc, ...)
    for key, value in pairs(list) do  
    	if not filterFunc(key, value, ...) then
    		return false
    	end
    end  
    return true
end
-- 获取 列表中符合指定条件的元素
table.filter = function(list, filterFunc, arg)
 	local newList = {}
    for key, value in pairs(list) do  
        local ret
        if arg then
            ret = filterFunc(arg, key, value)
        else
            ret = filterFunc(key, value)
        end
    	if ret then
    		newList[key] = value
    	end
    end  
    return newList
end
-- 截取列表
table.sub = function (lList, num, index)
    if not lList then
        return nil
    end

    num = num or #lList
    index = index or 1
    local newList = {}
    local endIndex = index + num
    for curIndex = 1, table.getCount(lList) do 
        local obj = lList[curIndex]
        if curIndex < endIndex and curIndex >= index then
            table.insert(newList, obj)
        end
    end
    return newList
end
-- 使用指定方法遍历列表
table.map = function(list, mapFunc, ...)
 	local newList = {}
    for key, value in pairs(list) do  
    	newList[key] = mapFunc(key, value, ...)
    end  
    return newList
end
-- 判断列表是否是空的
table.isEmpty = function(list)
	if not list then
		return true
	end
    if type(list) ~= "table" then
        return false
    end
    if _G.next(list) then
        return false
    end
    return true
end
-- 判断列表非空
table.isNotEmpty = function(list)
	return not table.isEmpty(list)
end
-- 列表追加列表
table.expand = function(list, newList)
    if not newList then
        return
    end
	for _, value in pairs(newList) do
        table.insert(list, value)
    end
end

-- 颠倒一个数组类型的table
table.reverse = function (list)

    if list == nil or #list == 0 then
        return nil
    end

    local newList = {}

    local count = #list
    for index = 1, count do
        newList[index] = list[count - index + 1]
    end

    return newList
end

-- 重排一个数组类型的table
table.shuffle = function( list )
    if list == nil or #list == 0 then
        return list
    end

    local count = #list
    local keys = table.keys(list)
    local newList = {}

    local key
    for index = 1, count do
        key = table.remove(keys, math.random(1, #keys))
        table.insert(newList, list[key])
    end

    return newList
end
-----------------------------------------------------
os.realtime = os.realtime or os.time

-- 同步服务端客户端时间差
function SetTimeDifference( serverTick )
    local diffTime = serverTick - os.realtime()
    com.info("服务端系统时间: %s ,客户端系统时间: %s, 时间差: %s", serverTick, os.realtime(), diffTime)

    os.time = function(tick)
        return os.realtime(tick) + diffTime
    end
end


-- 获取北京时间(计算gmt时间,自动补正)
os.realdate = function( sFormatStr, fTick )
    if not string.startWith(sFormatStr, "!") then
        sFormatStr = "!" .. sFormatStr
    end
    fTick = fTick or os.time()
    -- 由gmt时间转换为东8区
    return os.date(sFormatStr, fTick + 28800)
end


-----------------------------------------------------

-- 获取时间戳
os.timestamp = function()
    return sc.LuaCommon:getCurrentTimestamp()
end

-- 实际获得的是CPU运行到现在的时间，即系统开机到现在的时间（精确到毫秒）
os.mTimer = function(  )
    return sc.LuaCommon:getMillisecondNow()
end

-- 实际获得的是CPU运行到现在的时间，即系统开机到现在的时间（精确到毫秒）
function getMillisecondNow( ... )
    return sc.LuaCommon:getMillisecondNow()
end

-- 兼容旧版本，调用外部浏览器访问网页
openURL = function( pszUrl )
    return sc.LuaCommon:openURL( pszUrl )
end

-----------------------------------------------------
local g_writablePath = cc.FileUtils:getInstance():getWritablePath()
os.getCachePath = function ()
    return g_writablePath
end

os.getFullPath = function (path)
    return cc.FileUtils:getInstance():fullPathForFilename(path)
end

os.isExist = function (path)

    if cc.FileUtils:getInstance().isFileExist then
        return cc.FileUtils:getInstance():isFileExist(path)
    end
    return not not io.open(path)
end

os.getFileData = function (path, zipPath)
    if zipPath then
        local zipPath = os.getFullPath(zipPath)

        return cc.FileUtils:getInstance():getFileDataStringFromZip(zipPath, path)
    end

    local fullPath = os.getFullPath(path)
    local file = io.open(fullPath)
    local content = file:read("*a")
    file:close()
    return content, string.len(content)
end
-----------------------------------------------------
-- 获取客户端配置版本
function GetClientConfigVersion(cfgZipPath)
    cfgZipPath = cfgZipPath or GetDefineVariable(config, "ConfigZipPath") or "config.data"
    return os.getFileData("version.txt", cfgZipPath)
end
-- 兼容代码
GetClientConfigVsrsion = GetClientConfigVersion

-----------------------------------------------------
-- 获取本地文件内容
function getLocalFileContent( sFilePath )
    local sFullPath = cc.FileUtils:getInstance():fullPathForFilename(sFilePath)

    -- 查找debug.log所在目录
    if not cc.FileUtils:getInstance():isFileExist(sFullPath) then
        local sCachePath = os.getCachePath()
        local sFormatStr = string.sub(sCachePath, -1) == "/" and "%s%s" or "%s/%s"
        sFullPath = string.format(sFormatStr, sCachePath, sFilePath)
    end


    -- 默认文件没有找到
    if not cc.FileUtils:getInstance():isFileExist(sFullPath) then
        return nil, sFullPath
    end
    
    local pFile = assert(io.open(sFullPath, 'r'))
    local sFileContent = pFile:read("*a")
    pFile:close()

    return sFileContent, sFullPath
end

-- 保护运行指定代码
function runLocalCommand( sCodeStr )
    com.info("runLocalCommand = ", sCodeStr)

    local fCallback = packFunction(eval2, sCodeStr)

    xpcall(fCallback, function (msg, thread)
        local outStr = (thread and debug.traceback(thread) or debug.traceback())
        com.error("runLocalCommand Error=", msg, outStr)
    end)
end

-----------------------------------------------------

-- visible size
do
    local visibleSize, visibleOrigin
    function getVisibleSize()
        if not visibleSize then
            visibleSize = cc.Director:getInstance():getVisibleSize()
        end
        return visibleSize
    end
    function getVisibleOrigin()
        if not visibleOrigin then
            visibleOrigin = cc.Director:getInstance():getVisibleOrigin()
        end
        return visibleOrigin
    end
end

-----------------------------------------------------

-- 版本比较函数
function VersionCompare(curVer, nextVer)
    if curVer == nextVer then
        return 0
    end 
    if not curVer then
        return -1
    end
    if not nextVer then
        return 1
    end
    curVerList = string.split(curVer, ".")
    nextVerList = string.split(nextVer, ".")
    curVerCount = table.getCount(curVerList)
    nextVerCount = table.getCount(nextVerList)
    if curVerCount > nextVerCount then
        return 1
    elseif curVerCount < nextVerCount then
        return -1
    end
    for index = 1, curVerCount do
        curValue = tonumber(curVerList[index])
        nextValue = tonumber(nextVerList[index])
        if curValue > nextValue then
            return 1
        elseif curValue < nextValue then
            return -1
        end
    end
    
    return 0
end

----------------------------------------------------------

-- 恢复动画播放速度,到默认帧率
function setDefaultAnimationInterval(  )
    cc.Director:getInstance():setAnimationInterval(1.0 / _G.kDefaultFPS)
end

-- 自定义动画播放帧率
function setCustomAnimationInterval( iFps )
    cc.Director:getInstance():setAnimationInterval(1.0 / iFps)
end

-- 设置游戏运行速度(比如 3 就是游戏加速3倍, 0.1就是游戏减慢10倍)
function setDeltaTimeMultiple( fMultiple )
    cc.Director:getInstance():setDeltaTimeMultiple(fMultiple)
end
----------------------------------------------------------
-- 方向类型枚举
sc = sc or {}
sc.MoveType = {
    NONE = nil,
    UP = 1,
    DOWN = 2,
    LEFT = 3,
    RIGHT = 4,
}
----------------------------------------------------------
CCTOUCHBEGAN = "began"
CCTOUCHMOVED = "moved"
CCTOUCHENDED = "ended"
CCTOUCHCANCELLED = "cancelled"
----------------------------------------------------------
--##JSCodeClose##Start##--js不支持
-- 设置客户端用戶数据
function SetClientUserData(key, value, vType)
    if vType == "bool" then
        if value then
            value = true
        else
            value = false
        end
        cc.UserDefault:getInstance():setBoolForKey(key, value)
    elseif vType == "int" then
        cc.UserDefault:getInstance():setIntegerForKey(key, value)
    elseif vType == "string" then
        cc.UserDefault:getInstance():setStringForKey(key, value)
    elseif vType == "float" then
        cc.UserDefault:getInstance():setFloatForKey(key, value)
    elseif vType == "double" then
        cc.UserDefault:getInstance():setDoubleForKey(key, value)
    end
    cc.UserDefault:getInstance():flush()
end

-- 获取客户端用户数据
function GetClientUserData(key, vType)
    if vType== "bool" then
        return cc.UserDefault:getInstance():getBoolForKey(key)
    elseif vType == "int" then
        return cc.UserDefault:getInstance():getIntegerForKey(key)
    elseif vType == "string" then
        return cc.UserDefault:getInstance():getStringForKey(key)
    elseif vType == "float" then
        return cc.UserDefault:getInstance():getFloatForKey(key)
    elseif vType == "double" then
        return cc.UserDefault:getInstance():getDoubleForKey(key)
    end
end
--##JSCodeClose##End##--js不支持
----------------------------------------------------------
-- 储存列表
function SaveClientUserListData( saveKey, list, vType )
    if type(list) ~= "table" then
        return false
    end
    local indexKey = saveKey .. ".index"
    local index = 0
    SetClientUserData(indexKey, index, "int")

    local countKey = saveKey .. ".count"
    local count = table.getCount(list)
    SetClientUserData(countKey, count, "int")

    local dataKey = saveKey .. ".data"
    SetClientUserData(dataKey, true, "bool")

    vType = vType or "string"
    for curIndex = 1, count do
        local valueIndex = index + curIndex
        local valueKey = saveKey .. ".data." .. valueIndex
        local value = list[valueIndex]
        SetClientUserData(valueKey, value, vType)
    end
    return true
end
-- 是否储存了列表
function HasClientUserListData( saveKey )
    local dataKey = saveKey .. ".data"
    local hasData = GetClientUserData(dataKey, "bool")
    if not hasData then
        return false
    end
    return true
end
-- 获取列表
function LoadClientUserListData( saveKey, vType )
    if not HasClientUserListData(saveKey) then
        return nil
    end
    vType = vType or "string"
    local indexKey = saveKey .. ".index"
    local countKey = saveKey .. ".count"
    local index = GetClientUserData(indexKey, "int")
    local count = GetClientUserData(countKey, "int")

    local data = {}
    for curIndex = 1, count do
        local valueIndex = index + curIndex
        local valueKey = saveKey .. ".data." .. valueIndex
        local value = GetClientUserData(valueKey, vType)
        table.insert(data, value)
    end
    return data
end
-- 设置列表元素值
function SetClientUserListDataByIndex( saveKey, valueIndex, value, vType )
    if not HasClientUserListData(saveKey) then
        return false
    end
    vType = vType or "string"
    local indexKey = saveKey .. ".index"
    local index = GetClientUserData(indexKey, "int")
    local curIndex = index + valueIndex
    local valueKey = saveKey .. ".data." .. curIndex
    SetClientUserData(valueKey, value, vType)
    return true
end
-- 获取列表元素值
function GetClientUserListDataByIndex( saveKey, valueIndex, vType )
    if not HasClientUserListData(saveKey) then
        return nil
    end
    vType = vType or "string"
    local countKey = saveKey .. ".count"
    local count = GetClientUserData(countKey, "int")
    if count < valueIndex then
        return nil
    end

    local indexKey = saveKey .. ".index"
    local index = GetClientUserData(indexKey, "int")
    local curIndex = index + valueIndex
    local valueKey = saveKey .. ".data." .. curIndex
    com.debug("valueKey = ", valueKey)
    return GetClientUserData(valueKey, vType)
end
-- 弹出列表首个元素
function PopClientUserListData( saveKey, vType )
    if not HasClientUserListData(saveKey) then
        return nil
    end
    vType = vType or "string"
    local indexKey = saveKey .. ".index"
    local countKey = saveKey .. ".count"
    local index = GetClientUserData(indexKey, "int")
    local count = GetClientUserData(countKey, "int")
    if count <= 0 then
        return nil
    end
    local valueIndex = index + 1
    local valueKey = saveKey .. ".data." .. valueIndex
    local value = GetClientUserData(valueKey, vType)
    SetClientUserData(valueKey, nil, vType)

    count = count - 1
    SetClientUserData(countKey, count, "int")
    if count <= 0 then
        index = 0
    else
        index = index + 1
    end
    SetClientUserData(indexKey, index, "int")
    return value
end
-- 压入列表元素
function PushClientUserListData( saveKey, value, vType )
    vType = vType or "string"
    -- 初始化
    if not HasClientUserListData(saveKey) then
        SaveClientUserListData(saveKey, {}, vType)
    end

    local indexKey = saveKey .. ".index"
    local countKey = saveKey .. ".count"
    local index = GetClientUserData(indexKey, "int")
    local count = GetClientUserData(countKey, "int")
    local valueIndex = count + 1
    local curIndex = index + valueIndex
    local valueKey = saveKey .. ".data." .. curIndex
    SetClientUserData(valueKey, value, vType)

    SetClientUserData(countKey, valueIndex, "int")
    return valueIndex
end

----------------------------------------------------------
-- 获取数据校验码
function GetClientUserDataChecknum( value, checkType, valueType)
    if valueType and valueType == "float" then
        value = string.format("%.04f", value)
    end
    return sc.CCCrypto:MD5(checkType .. "heihei" .. tostring(value) .. "bendan" .. OpenUDID)
end
-- 保存数据（带校验码）
function SetClientUserDataByChecknum( key, value, valueType, checkType)
    checkType = checkType or "Checknum"
    local curChecknum = GetClientUserDataChecknum(value, checkType, valueType)
    SetClientUserData(key, value, valueType)
    SetClientUserData(key .. checkType, curChecknum, "string")
end
-- 获取数据（带校验码）
function GetClientUserDataByChecknum( key, valueType, checkType, defaultValue)
    checkType = checkType or "Checknum"
    local value = GetClientUserData(key, valueType)
    local checknum = GetClientUserData(key .. checkType, "string")
    local curChecknum = GetClientUserDataChecknum(value, checkType, valueType)

    if defaultValue == nil then
        if valueType == "bool" then
            defaultValue = false
        elseif valueType == "string" then
            defaultValue = ""
        else
            defaultValue = 0
        end
    end
    if value ~= defaultValue and curChecknum ~= checknum then
        SetClientUserDataByChecknum(key, defaultValue, valueType, checkType)
        return defaultValue, false
    end
    return value, true
end
---------------------------------------------------------------------

local g_dStatInfo = {}
local g_dFuncTickInfo = {}
function InitStatInfo( sName, bNeedAllInfo )
    local dStatInfo = {
        iCount = 0,
        fTick = 0,
        fMaxTick = nil,
        fMinTick = nil,
        fLastEnterTick = nil,
        fCurUseTick = nil,
        bNeedAllInfo = bNeedAllInfo,
        dAllInfo = {}
    }
    g_dStatInfo[sName] = dStatInfo
    return dStatInfo
end

--检测当前帧所有函数执行时间
function CheckFuncUseTickInInterval( lastTick, curTick )
    local fInterval = curTick - lastTick
    lastTick = lastTick - 0.016
    g_dFuncTickInfo[curTick] = {}
    for funcName, dStatInfo in pairs(g_dStatInfo) do
        if dStatInfo.fLastEnterTick then
            if dStatInfo.fLastEnterTick >= lastTick and dStatInfo.fLastEnterTick < curTick then
                if dStatInfo.fCurUseTick and dStatInfo.fCurUseTick >= 0.002 then
                    g_dFuncTickInfo[curTick][funcName] = {fInterval, dStatInfo.fCurUseTick}
                end
            end
        end
    end
end

function ShowFuncUseTickInfo( ... ) 
    for tick, dTickInfo in table.pairsByKeys(g_dFuncTickInfo) do
        local str = string.format("EnterTick= %-10.3f", tick)
        if table.getCount(dTickInfo) > 0 then
            for funcName, useTickInfo in pairs(dTickInfo) do
                local info = string.format("    StatFunc(%-30s) allTick= %-10.3f, fCurUseTick= %-6.5f", funcName, unpack(useTickInfo))
                str = str .. "\n"..info
            end
            str = str .. "\n" .. "-------------------------------------------"
            com.info(str)
        end
    end
end

function AddStatFunc( dStatInfo, fTick )

    if not dStatInfo.fMinTick or dStatInfo.fMinTick > fTick then
       dStatInfo.fMinTick = fTick
    end
    if not dStatInfo.fMaxTick or dStatInfo.fMaxTick < fTick then
       dStatInfo.fMaxTick = fTick
    end
    dStatInfo.fTick = dStatInfo.fTick + fTick
    dStatInfo.iCount = dStatInfo.iCount + 1

    dStatInfo.fCurUseTick = fTick

    if dStatInfo.bNeedAllInfo then
        table.insert(dStatInfo.dAllInfo, fTick)
    end
end

-- 开始监测函数调用性能
function BindStatFunc( sName, fStatFunc )

    local dStatInfo = InitStatInfo(sName)

    return function( ... )
        local fCurTick = os.mTimer()
        dStatInfo.fLastEnterTick = fCurTick
        local lResultList = pack(fStatFunc(...))
        local fTick = os.mTimer() - fCurTick
        AddStatFunc(dStatInfo, fTick)

        return unpack(lResultList)
    end
end

-- 获取函数统计信息
function GetStatFuncInfo( sName )
    local dStatInfo = g_dStatInfo[sName]
    if not dStatInfo then
        return string.format("no found statFunc(%s) info", sName)
    end

    if dStatInfo.iCount <= 0 then
        return string.format("statFunc(%s) not run", sName)
    end

    local allUseTick = g_dStatInfo["Frame"]
    local fAllUseTick
    if allUseTick then
        fAllUseTick = allUseTick.fTick
    else
        fAllUseTick = 1
    end

    local fSingleTick = dStatInfo.fTick / dStatInfo.iCount
    local singleTickEx = 0
    if dStatInfo.iCount > 2 then
        singleTickEx = (dStatInfo.fTick - dStatInfo.fMaxTick - dStatInfo.fMinTick) / (dStatInfo.iCount - 2) 
    end
    local ratio = (dStatInfo.fTick / fAllUseTick) * 100
    local sStatInfo = string.format("StatFunc(%-30s)\tcount[%-6d]\tallTick= %-10.3f\tsingleTick= %-6.5f\tmaxTick= %-6.5f\tminTick = %-6.5f\tsingleTickEx= %-6.5f\t ratio = \t%-6.2f",
                    sName, dStatInfo.iCount, dStatInfo.fTick, fSingleTick, dStatInfo.fMaxTick, dStatInfo.fMinTick, singleTickEx, ratio)

    if dStatInfo.bNeedAllInfo then
        sStatInfo = sStatInfo .. "\n" .. string.getStr(dStatInfo.dAllInfo)
    end
    return sStatInfo
end


-- 是否统计到函数运行
function HasStatFuncRun( sName )
    local dStatInfo = g_dStatInfo[sName]
    if not dStatInfo then
        return false
    end

    if dStatInfo.iCount <= 0 then
        return false
    end
    return true
end

-- 绑定模块或类方法统计性能
function BindObjectStatFunc( classType, sFuncName, sKeyName )
    sKeyName = sKeyName or sFuncName
    if g_dStatInfo[sKeyName] then
        com.error("BindObjectStatFunc(%s) has bind", sKeyName)
        return
    end
    local fStatFunc = classType[sFuncName]
    local bClassFunc = true
    if not fStatFunc then
        bClassFunc = false
        fStatFunc = classType.propertys[sFuncName]
    end

    if not fStatFunc then
        com.error("BindObjectStatFunc(%s) no found func = %s", classType, sFuncName)
        return
    end
    local fBindFunc = BindStatFunc(sKeyName, fStatFunc)
    if bClassFunc then
        classType[sFuncName] = fBindFunc
    else
        classType.propertys[sFuncName] = fBindFunc
    end
end

-- 绑定函数结束回调
function BindCallback( func, callback )
    return function( ... )
        local lResultList = pack(func(...))
        if callback then
            callback()
        end
        return unpack(lResultList)
    end
end

function ResetStatInfo( ... )
    -- g_dStatInfo = {}
    for sStatName, dStatInfo in pairs(g_dStatInfo) do
        dStatInfo.iCount = 0
        dStatInfo.fTick = 0
        dStatInfo.fMaxTick = nil
        dStatInfo.fMinTick = nil
        dStatInfo.fLastEnterTick = nil
        dStatInfo.fCurUseTick = nil  
    end
    g_dFuncTickInfo = {}
end


---------------------------------------------------------------------
-- 获取弧度角
function GetAngleByPos(pEndPos, pStartPos)
    pStartPos = pStartPos or cc.p(0, 0)
    return cc.pToAngleSelf(cc.pSub(pEndPos, pStartPos))
end

-- 弧度转角度
CC_RADIANS_TO_DEGREES = math.deg
-- function CC_RADIANS_TO_DEGREES(__ANGLE__) 
--     return ((__ANGLE__) * 57.29577951)    -- PI * 180
-- end

-- 角度转弧度
CC_DEGREES_TO_RADIANS = math.rad
-- function CC_DEGREES_TO_RADIANS( __ANGLE__ )
--     return ((__ANGLE__) * 0.01745329252)  -- PI / 180
-- end

--屏幕分辨率适配(bHorizontal是否横屏, pDesignSize设计分辨率)
function ScreenResolutionAdaptation(bHorizontal, pDesignSize, bShowAll)
    local director = cc.Director:getInstance()
    local glView = director:getOpenGLView()
    local size = glView:getFrameSize()

    pDesignSize = pDesignSize or cc.size(640, 960)
    
    -- 匹配不缩放（控件位置按比例匹配）
    if bShowAll then
        -- 横屏
        if bHorizontal then
            if size.width / pDesignSize.height > size.height / pDesignSize.width then
                glView:setDesignResolutionSize( pDesignSize.height, pDesignSize.width, cc.ResolutionPolicy.FIXED_HEIGHT )
            else
                glView:setDesignResolutionSize( pDesignSize.height, pDesignSize.width, cc.ResolutionPolicy.FIXED_WIDTH )
            end
        else
            if size.width / pDesignSize.width > size.height / pDesignSize.height then
                glView:setDesignResolutionSize( pDesignSize.width, pDesignSize.height, cc.ResolutionPolicy.FIXED_HEIGHT )
            else
                glView:setDesignResolutionSize( pDesignSize.width, pDesignSize.height, cc.ResolutionPolicy.FIXED_WIDTH )
            end
        end

        
        




        -- --横屏
        -- if bHorizontal then
        --     if (size.height / size.width) <= 0.8 then
        --         glView:setDesignResolutionSize(size.height, pDesignSize.width, cc.ResolutionPolicy.FIXED_HEIGHT)  
        --     else
        --         glView:setDesignResolutionSize(pDesignSize.height, pDesignSize.width, cc.ResolutionPolicy.SHOW_ALL)
        --     end
        -- else
        --     if (size.width / size.height) <= 0.8 then
        --         glView:setDesignResolutionSize(pDesignSize.width, size.height, cc.ResolutionPolicy.FIXED_WIDTH)  
        --     else
        --         glView:setDesignResolutionSize(pDesignSize.width, pDesignSize.height, cc.ResolutionPolicy.SHOW_ALL)
        --     end
        -- end
    else
        --横屏
        if bHorizontal then
            -- if (size.height / size.width) >= 0.56 and (size.height / size.width) <= 0.57 then
            --     glView:setDesignResolutionSize(size.height, pDesignSize.width, cc.ResolutionPolicy.FIXED_HEIGHT)    
            -- else
                glView:setDesignResolutionSize(pDesignSize.height, pDesignSize.width, cc.ResolutionPolicy.EXACT_FIT)
            -- end
        else
            -- if (size.width / size.height) >= 0.56 and (size.width / size.height) <= 0.57 then
            --     glView:setDesignResolutionSize(pDesignSize.width, size.height, cc.ResolutionPolicy.FIXED_WIDTH)  
            -- else     
                glView:setDesignResolutionSize(pDesignSize.width, pDesignSize.height, cc.ResolutionPolicy.EXACT_FIT)
            -- end
        end
    end

    -- com.info("getVisibleSize", director:getVisibleSize() )
    -- com.info("getWinSize", director:getWinSize() )
    -- com.info("getVisibleOrigin", director:getVisibleOrigin() )
    -- com.info("getFrameSize", size )

end


------------------------------------3d相关------------------
--计算射线
function calculateRayByLocationInViewByCamera( pTouchPos, pGameCamera )
    local pUIPos = cc.Director:getInstance():convertToUI(pTouchPos)

    pGameCamera = pGameCamera or cc.Camera:getDefaultCamera()

    local pSourcePos = cc.vec3(pUIPos.x, pUIPos.y, -1)

    --计算近平面点在世界坐标系中的坐标
    local pNearPoint = pGameCamera:unproject(pSourcePos)

    --计算远平面点在世界坐标系中的坐标
    pSourcePos = cc.vec3(pUIPos.x, pUIPos.y, 1)
    local pFarPoint = pGameCamera:unproject(pSourcePos)

    --方向矢量
    local pDirection = {}
    --远平面点减去近平面点求方向矢量
    pDirection.x = pFarPoint.x - pNearPoint.x
    pDirection.y = pFarPoint.y - pNearPoint.y
    pDirection.z = pFarPoint.z - pNearPoint.z
    --归一化
    pDirection   = cc.vec3normalize(pDirection)

    
    local pRay = cc.Ray:new()
    --射线起点位置
    pRay._origin    = pNearPoint
    --射线方向矢量
    pRay._direction = pDirection

    return pRay
end

-- 3d模型动作帧间隔
local Def_Animation3DFrameTick = 1 / 30
function getAnimation3DTick( iFrameIndex )
    return Def_Animation3DFrameTick * iFrameIndex
end

-- 创建3d模型动作
function createAnimation3D( sModelPath, iStartFrameIndex, iEndFrameIndex, bRepeatForever )  
    local pAnimation = cc.Animation3D:create(sModelPath)
    if not pAnimation then
        com.error("createAnimation3D[%s] error, create model fail", sModelPath)
        return nil
    end
    -- 帧时间范围
    local pAction = cc.Animate3D:createWithFrames(pAnimation, iStartFrameIndex, iEndFrameIndex)
    if not pAction then
        com.error("createAnimation3D[%s] error, create action[%s,%s] fail", sModelPath, iStartFrameIndex, iEndFrameIndex)
        return nil
    end
    
    if bRepeatForever then
        pAction = cc.RepeatForever:create(pAction)
    end
    return pAction
end

-- 根据时间创建3d模型动作
function createAnimation3DByDuration( sModelPath, fStartTick, fDuration )
    --com.info("createAnimation3DByDuration", sModelPath, fStartTick, fDuration)
    local pAnimation = cc.Animation3D:create(sModelPath)
    if not pAnimation then
        com.error("createAnimation3DByDuration[%s] error, create model fail", sModelPath)
        return nil
    end

    local pAction = cc.Animate3D:create(pAnimation, fStartTick, fDuration)
    if not pAction then
        com.error("createAnimation3DByDuration[%s] error, create action[%s,%s] fail", sModelPath, fStartTick, fDuration)
        return nil
    end

    return pAction
end


-- 根据矩阵 获取坐标 角度 缩放
function getPositionInfoByMt4( pCurMt4 )
    local scale = cc.vec3()
    local rotation = cc.vec3()
    local translation = cc.vec3()
    local dMat4Info = cc.mat4.decompose(pCurMt4, scale, rotation, translation)
    return dMat4Info.translation, dMat4Info.rotation, dMat4Info.scale
end

--------------------------------------------------------------------------


-- 地图布局管理器
MapLayoutManager = class()


-------------------------------------
---- 初始化布局管理器
-- layoutRect 布局区域
function MapLayoutManager:ctor(layoutRect)
    -- 区域
    self._layoutRect = layoutRect
    if not self._layoutRect then
        com.error("MapLayoutManager.layoutRect error = %s", layoutRect)
        return
    end

    -- 初始位置
    self._initPosX = self._layoutRect.x
    self._initPosY = self._layoutRect.y
end

---- 初始化
-- columnCount 列数
-- rowCount 行数
function MapLayoutManager:Init( columnCount, rowCount )

    -- 区域
    self._columnCount = columnCount
    self._rowCount = rowCount

    -- 布局格子总数
    self._layoutCount = self._columnCount * self._rowCount

    -- 布局信息
    self._columnWidth = self._layoutRect.width / self._columnCount
    self._rowHeight = self._layoutRect.height / self._rowCount
end

function MapLayoutManager:ResetRect( layoutRect )
    -- 区域
    self._layoutRect = layoutRect
    self:Init(self._columnCount, self._rowCount)
end
-------------------------------------
function MapLayoutManager:GetColumnWidth( ... )
    return self._columnWidth
end
function MapLayoutManager:GetRowHeight( ... )
    return self._rowHeight
end

function MapLayoutManager:GetColumnCount( ... )
    return self._columnCount
end
function MapLayoutManager:GetRowCount( ... )
    return self._rowCount
end


-- 获取布局位置数量
function MapLayoutManager:GetLayoutCount( ... )
    return self._layoutCount
end
-------------------------------------


-- 获取指定布局序号坐标
function MapLayoutManager:GetLayoutPosByIndex( index )
    if index < 0 or index > self._layoutCount then
        return nil
    end

    local rowIndex = math.ceil(index / self._columnCount)
    local columnIndex = self._columnCount - (self._columnCount * rowIndex - index)

    return columnIndex, rowIndex
end

-- 获取指定布局坐标点
function MapLayoutManager:GetLayoutPositionByIndex( index )
    local columnIndex, rowIndex = self:GetLayoutPosByIndex( index )
    if not columnIndex then
        return nil
    end
    return self:GetLayoutPosition( columnIndex, rowIndex )
end


-- 获取布局序号
function MapLayoutManager:GetLayoutIndexByPos( columnIndex, rowIndex )
    local layoutIndex = columnIndex + (rowIndex - 1) * self._columnCount
    if layoutIndex < 0 or layoutIndex > self._layoutCount then
        return nil
    end
    return layoutIndex
end

-------------------------------------

-- 获取屏幕坐标
function MapLayoutManager:GetLayoutPosition( iColumnIndex, iRowIndex )
    local fPosX = self:GetLayoutPositionX(iColumnIndex)
    local fPosY = self:GetLayoutPositionY(iRowIndex)
    return fPosX, fPosY
end

-- 获取屏幕坐标X
function MapLayoutManager:GetLayoutPositionX( iColumnIndex )
    local fPosX = self._initPosX + self._columnWidth * (iColumnIndex - 0.5)
    return fPosX
end

-- 获取屏幕坐标Y
function MapLayoutManager:GetLayoutPositionY( iRowIndex )
    local fPosY = self._initPosY + self._rowHeight * (iRowIndex - 0.5)
    return fPosY
end


-- 获取点击列数
function MapLayoutManager:GetLayoutColumnIndexByPosX( posX)
    local columnIndex = math.ceil((posX - self._initPosX) / self._columnWidth)
    if columnIndex <= 0 or columnIndex > self._columnCount then
        return nil
    end
    return columnIndex
end

-- 获取点击行数
function MapLayoutManager:GetLayoutRowIndexByPosY( posY )
    local rowIndex = math.ceil((posY - self._initPosY) / self._rowHeight)
    if rowIndex <= 0 or rowIndex > self._rowCount then
        return nil
    end
    return rowIndex
end

-- 获取点击布局坐标
function MapLayoutManager:GetLayoutPosByPosition( posX, posY )
    local columnIndex = math.ceil((posX - self._initPosX) / self._columnWidth)
    local rowIndex = math.ceil((posY - self._initPosY) / self._rowHeight)

    if columnIndex <= 0 or columnIndex > self._columnCount then
        return nil
    end
    if rowIndex <= 0 or rowIndex > self._rowCount then
        return nil
    end

    return columnIndex, rowIndex
end

-- 获取点击布局序号
function MapLayoutManager:GetLayoutIndexByPosition( posX, posY )
    local columnIndex, rowIndex = self:GetLayoutPosByPosition(posX, posY)
    if not columnIndex or not rowIndex then
        return nil
    end
    
    return self:GetLayoutIndexByPos(columnIndex, rowIndex )
end

-- 是否有效坐标
function MapLayoutManager:IsVaildLayoutPos( columnIndex, rowIndex )
    if columnIndex <= 0 or columnIndex > self._columnCount then
        return false
    end
    if rowIndex <= 0 or rowIndex > self._rowCount then
        return false
    end

    return true
end

----------------------------------------
-- 遍历布局位置
function MapLayoutManager:MapLayout( mapFunC, firstArg, ... )

    for rowIndex = 1, self._rowCount do
        local cfgRowIndex = self._rowCount - rowIndex + 1
        for columnIndex = 1, self._columnCount do
            -- 遍历布局
            if not mapFunC(firstArg, columnIndex, rowIndex, cfgRowIndex, ...) then
                return false
            end
        end
    end
    return true
end
-------------------------------------

------------------------------------------
-- 横向布局管理器
HorizontalMapLayoutManager = class(MapLayoutManager)
------------------------------------------
---- 初始化
-- columnCount 列数
-- rowCount 行数
function HorizontalMapLayoutManager:Init( columnCount, rowCount )

    -- 区域
    self._columnCount = columnCount
    self._rowCount = rowCount

    -- 布局格子总数
    self._layoutCount = self._columnCount * self._rowCount

    -- 布局信息
    self._columnWidth = self._layoutRect.height / self._columnCount
    self._rowHeight = self._layoutRect.width / self._rowCount
end

-- 获取屏幕坐标
function HorizontalMapLayoutManager:GetLayoutPosition( columnIndex, rowIndex )
    local posX = self._initPosX + self._rowHeight * (rowIndex - 0.5)
    local posY = self._initPosY + self._columnWidth * (self._columnCount - columnIndex + 0.5)
    return posX, posY
end
-- 获取点击列数
function HorizontalMapLayoutManager:GetLayoutColumnIndexByPosY( posY )
    local columnIndex = math.ceil((posY - self._initPosY) / self._columnWidth)
    if columnIndex <= 0 or columnIndex > self._columnCount then
        return nil
    end
    columnIndex = self._columnCount - columnIndex + 1
    return columnIndex
end

-- 获取点击行数
function HorizontalMapLayoutManager:GetLayoutRowIndexByPosX( posX )
    local rowIndex = math.ceil((posX - self._initPosX) / self._rowHeight)
    if rowIndex <= 0 or rowIndex > self._rowCount then
        return nil
    end
    return rowIndex
end
-- 获取点击布局坐标
function HorizontalMapLayoutManager:GetLayoutPosByPosition( posX, posY )
    local columnIndex = math.ceil((posY - self._initPosY) / self._columnWidth)
    local rowIndex = math.ceil((posX - self._initPosX) / self._rowHeight)

    if columnIndex <= 0 or columnIndex > self._columnCount then
        return nil
    end
    if rowIndex <= 0 or rowIndex > self._rowCount then
        return nil
    end

    columnIndex = self._columnCount - columnIndex + 1
    return columnIndex, rowIndex
end
------------------------------------------


------------------------------------------

-- 游戏对象缓存管理器
GameObjectCacheManager = class()

function GameObjectCacheManager:ctor( sCacheType )
    self._sCacheType = sCacheType
    self._sCacheMgrStr = string.format("GameObjectCacheManager[%s]", tostring(self._sCacheType))

    -- 缓存对象字典
    self._dCacheDict = {}

    -- 正在使用的对象字典
    self._dUseCacheDict = {}

    -- 创建对象函数
    self._dCacheCreateFunc = {}
    -- 保存缓存函数
    self._dCacheFreeFunc = {}
    -- 销毁缓存函数
    self._dCacheClearFunc = {}
end

function GameObjectCacheManager:__str__(  )
    return self._sCacheMgrStr
end
------------------------------------------
-- 自动设置对象创建回调
function GameObjectCacheManager:AutoSetObjectCreateFunc( sObjType, fCreateFunc, ... )
    if self:HasSetObjectCreateFunc(sObjType) then
        return
    end
    self:SetObjectCreateFunc(sObjType, fCreateFunc, ...)
end

-- 设置对象创建回调(必须设置 ): fCreateFunc(sObjType)
function GameObjectCacheManager:SetObjectCreateFunc( sObjType, fCreateFunc, ... )
    if self._dCacheCreateFunc[sObjType] then
        com.error("SetObjectCreateFunc(%s) fail, has set", sObjType)
        return
    end
    self._dCacheCreateFunc[sObjType] = packFunction(fCreateFunc, ...)

    -- 缓存对象字典
    self._dCacheDict[sObjType] = {}

    -- 正在使用的对象字典
    self._dUseCacheDict[sObjType] = {}
end

-- 自动设置对象闲置回调
function GameObjectCacheManager:AutoSetObjectCacheFunc( sObjType, fCacheFunc, ... )
    if self:HasSetObjectCreateFunc(sObjType) then
        return
    end
    self:SetObjectCacheFunc(sObjType, fCacheFunc, ...)
end
-- 设置对象闲置回调(可选,无配置时会尝试调用obj:CacheObject方法 ): fCacheFunc(sObjType, obj)
function GameObjectCacheManager:SetObjectCacheFunc( sObjType, fCacheFunc, ... )
    if self._dCacheFreeFunc[sObjType] then
        com.error("SetObjectFreeFunc(%s) fail, has set", sObjType)
        return
    end
    self._dCacheFreeFunc[sObjType] = packFunction(fCacheFunc, ...)
end

-- 是否设置过缓存信息
function GameObjectCacheManager:HasSetObjectCreateFunc( sObjType )
    if self._dCacheCreateFunc[sObjType] then
        return true
    end
    return false
end

------------------------------------------
function GameObjectCacheManager:InitCacheCount( sObjType, iCount )
    com.debug("InitCacheCount[%s] = %s", sObjType, iCount )
    if not self._dCacheDict[sObjType] then
        com.error("InitCacheCount(%s) fail, no init type, please set fCreateFunc!", sObjType)
        return false
    end
    -- 数量已经足够
    local lCacheObjList = self._dCacheDict[sObjType]
    local iNewCount = iCount - #lCacheObjList
    if iNewCount <= 0 then
        return true
    end

    -- 可选闲置回调
    local fCacheFunc = self._dCacheFreeFunc[sObjType]
            
    while iNewCount > 0 do
        iNewCount = iNewCount - 1
        local pNewObj = self:__getNewObject(sObjType)
        if not pNewObj then
            com.error("InitCacheCount(%s) fail, create error", sObjType)
            return false
        end

        if fCacheFunc then
            fCacheFunc(sObjType, pNewObj)
        elseif pNewObj.CacheObject then
            pNewObj:CacheObject()
        end

        table.insert(lCacheObjList, pNewObj)
    end
    return true
end

------------------------------------------
-- 自动设置对象销毁回调
function GameObjectCacheManager:AutoSetObjectDestroyFunc( sObjType, fCacheFunc, ... )
    if self._dCacheClearFunc[sObjType] then
        return
    end
    self:SetObjectDestroyFunc(sObjType, fCacheFunc, ... )
end

-- 设置对象销毁回调(可选,无配置时会尝试调用 pCacheObj:Destroy方法 ): fCacheFunc(sObjType, pCacheObj)
function GameObjectCacheManager:SetObjectDestroyFunc( sObjType, fCacheFunc, ... )
    if self._dCacheClearFunc[sObjType] then
        com.error("SetObjectDestroyFunc(%s) fail, has set", sObjType)
        return
    end
    self._dCacheClearFunc[sObjType] = packFunction(fCacheFunc, ...)
end

-- 销毁所有缓存
function GameObjectCacheManager:ClearAll(  )
    com.debug("%s.ClearAll", self)

    -- 缓存的对象
    for sObjType, lCacheObjList in pairs(self._dCacheDict) do
        local fClearFunc = self._dCacheClearFunc[sObjType]
        for _, pCacheObj in pairs(lCacheObjList) do
            self:__destroyCacheObject(sObjType, pCacheObj, fClearFunc)
        end
    end
    self._dCacheDict = {}


    -- 清理正在使用的对象字典
    for sObjType, dCacheObjDict in pairs(self._dUseCacheDict) do
        local fClearFunc = self._dCacheClearFunc[sObjType]
        for pCacheObj, _ in pairs(dCacheObjDict) do
            self:__destroyCacheObject(sObjType, pCacheObj, fClearFunc)
        end
    end
    self._dUseCacheDict = {}

    -- 创建对象函数
    self._dCacheCreateFunc = {}
    -- 保存缓存函数
    self._dCacheFreeFunc = {}
    -- 销毁缓存函数
    self._dCacheClearFunc = {}
end

-- 销毁指定类型的所有缓存
function GameObjectCacheManager:ClearAllByType( sObjType )
    com.debug("%s.ClearAllByType = %s", self, sObjType)
    local fClearFunc = self._dCacheClearFunc[sObjType]

    local lCacheObjList = self._dCacheDict[sObjType]
    self._dCacheDict[sObjType] = nil

    if lCacheObjList then
        for _, pCacheObj in pairs(lCacheObjList) do
            self:__destroyCacheObject(sObjType, pCacheObj, fClearFunc)
        end
    end
        

    local dCacheObjDict = self._dUseCacheDict[sObjType]
    self._dUseCacheDict[sObjType] = nil

    if dCacheObjDict then
        for pCacheObj, _ in pairs(dCacheObjDict) do
            self:__destroyCacheObject(sObjType, pCacheObj, fClearFunc)
        end
    end

    -- 创建对象函数
    self._dCacheCreateFunc[sObjType] = nil
    -- 保存缓存函数
    self._dCacheFreeFunc[sObjType] = nil
    -- 销毁缓存函数
    self._dCacheClearFunc[sObjType] = nil
end

------------------------------------------
function GameObjectCacheManager:__destroyCacheObject( sObjType, pCacheObj, fClearFunc )
    if fClearFunc then
        fClearFunc(sObjType, pCacheObj)
    else
        if pCacheObj.removeFromParent then
            pCacheObj:removeFromParent()
        elseif pCacheObj.Destroy then
            pCacheObj:Destroy()
        else
            com.error("%s.ClearAll[%s](%s) fail, no found clearFunc", self, sObjType, pCacheObj)
        end
    end
end
------------------------------------------
-- 记录使用的缓存对象
function GameObjectCacheManager:__useCacheObject( sObjType, pCacheObj )
    if not self._dUseCacheDict[sObjType] then
        return false
    end
    self._dUseCacheDict[sObjType][pCacheObj] = true
    return true
end
-- 释放使用的缓存对象
function GameObjectCacheManager:__releaseCacheObject( sObjType, pCacheObj  )
    if not self._dUseCacheDict[sObjType] then
        return false
    end
    if not self._dUseCacheDict[sObjType][pCacheObj] then
        com.error("__releaseCacheObject[%s](%s) error, no cache object", sObjType, pCacheObj)
        return false
    end
    self._dUseCacheDict[sObjType][pCacheObj] = nil
    return true
end

------------------------------------------

-- 获取一个新的指定类型对象
function GameObjectCacheManager:GetObject( sObjType )

    local pCacheObj = self:__getCacheObject(sObjType)
    if pCacheObj then
        self:__useCacheObject(sObjType, pCacheObj)
        return pCacheObj
    end

    local pNewObj = self:__getNewObject(sObjType)
    if pNewObj then
        self:__useCacheObject(sObjType, pNewObj)
    else
        com.error("GetObject(%s) fail, pCacheObj = null!", sObjType)
    end
    return pNewObj
end

-- 缓存闲置对象
function GameObjectCacheManager:CacheObject( sObjType, pCacheObj )
    if not self._dCacheDict[sObjType] then
        com.error("CacheObject(%s) fail, no init type, please set fCreateFunc!", sObjType)
        return false
    end

    if not pCacheObj then
        com.error("CacheObject(%s) fail, pCacheObj = null!", sObjType)
        return false
    end

    if not self:__releaseCacheObject(sObjType, pCacheObj) then
        return false
    end

    -- 可选闲置回调
    local fCacheFunc = self._dCacheFreeFunc[sObjType]
    if fCacheFunc then
        fCacheFunc(sObjType, pCacheObj)
    elseif pCacheObj.CacheObject then
        pCacheObj:CacheObject()
    end

    local lCacheObjList = self._dCacheDict[sObjType]
    table.insert(lCacheObjList, pCacheObj)

    return true
end
------------------------------------------

function GameObjectCacheManager:__getCacheObject( sObjType )
    if not self._dCacheDict[sObjType] then
        com.error("GetObject(%s) fail, no init type, please set fCreateFunc!", sObjType)
        return nil
    end
    local lCacheObjList = self._dCacheDict[sObjType]
    local pCacheObj = table.remove(lCacheObjList)
    return pCacheObj
end

function GameObjectCacheManager:__getNewObject( sObjType )
    local fCreateFunc = self._dCacheCreateFunc[sObjType]
    if not fCreateFunc then
        com.error("CreateObject(%s) fail, no init type, please set fCreateFunc!", sObjType)
        return nil
    end
    local pCacheObj = fCreateFunc(sObjType)
    if not pCacheObj then
        com.error("CreateObject(%s) error = null!", sObjType)
        return nil
    end
    return pCacheObj
end
------------------------------------------


-- 通过坐标获得弧度
function GetRadiansByPos( fDisX, fDisY )
    if fDisX == 0 and fDisY == 0 then
        return 0
    end

    if fDisX == 0 then
        -- 90度
        if fDisY > 0 then
            return CC_DEGREES_TO_RADIANS(90)
        -- 负90度
        else
            return CC_DEGREES_TO_RADIANS(-90)
        end
    end

    if fDisY == 0 then
        -- 0度
        if fDisX > 0 then
            return CC_DEGREES_TO_RADIANS(0)
        -- 180度
        else
            return CC_DEGREES_TO_RADIANS(180)
        end
    end

    local fRadians = math.atan(1.0 * fDisY / fDisX)

    -- 2,3象限角
    if fDisX < 0 then
        -- 3象限角
        if fRadians > 0 then
            fRadians = fRadians - CC_DEGREES_TO_RADIANS(180)
        -- 4象限角
        else
            fRadians = fRadians + CC_DEGREES_TO_RADIANS(180)
        end
    end

    return fRadians
end
