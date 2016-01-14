--
--    张海  2015-05-06
--    描述：  CommonBaseDao 接口.
--
local CommonBaseDao = {
}


--- 业务逻辑模块初始化
--
-- @return table 业务逻辑模块
function CommonBaseDao:init()
    return self
end
--- 建立模块与业务逻辑基类的继承关系(模块Dao属性的全部方法将会暴露，可以像调用模块本身的方法一样调用)
--
-- @param table module 模块
-- @return table 模块
function CommonBaseDao:inherit(module)
    module.__super = self
    return setmetatable(module, {
        __index = function(self, key)
            if self.__super[key] then
                return self.__super[key]
            end
            return nil
        end
    })
end
return CommonBaseDao
