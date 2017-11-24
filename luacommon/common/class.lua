-- 储存类定义
local _class = {}
local _objectIndex = 0
-- 判断是否类实例接口
 function isInstance(obj)
 	return rawget(obj, "__isClass")
 	-- return obj.__isClass
 end
-- 支持获取 obj索引
 function GetObjectIndex(obj)
 	return rawget(obj, "__objectIndex")
 	-- return obj.__objectIndex
 end

 function super( class_type )
 	return class_type.super.propertys
 end

function class(super)
	local class_type = {}
	class_type.ctor = false
	class_type.super = super

	-- 实例创建方法
	class_type.new = function(...) 
		-- obj索引
		_objectIndex = _objectIndex + 1
		-- 类实例对象
		local obj = {__isClass = true, __objectIndex = _objectIndex}
		-- 先设置继承关系, 以支持 子类构造函数中 调用父类方法
		setmetatable(obj, { __index = _class[class_type]})
		-- 设置父类对象
		if super then
			obj.super = _class[super]
		end

		do
			local create
			create = function(c,...)
				-- 递归调用父类构造函数
				if c.super then
					create(c.super,...)
				end
				-- 最后才调用子类的构造函数
				if c.ctor then
					c.ctor(obj,...)
				end
			end
			-- 调用构造函数
			create(class_type,...)
		end
		return obj
	end
	-- 储存类定义元表（用于保存类的方法）
	class_type.propertys = {}
	_class[class_type] = class_type.propertys

 	-- 设置类对象 新增属性 都储存到 类定义的元表上
	setmetatable(class_type, {__newindex=
		function(t,k,v)
			class_type.propertys[k]=v
		end
	})
 	-- 如果 有继承父类, 类定义里不存在的属性都从父类定义里获取 （也就是继承父类）
	if super then
		setmetatable(class_type.propertys, {__index=
			function(t,k)
				local ret = _class[super][k]
				class_type.propertys[k] = ret
				return ret
			end
		})
	end
 	-- 返回类对象
	return class_type
end