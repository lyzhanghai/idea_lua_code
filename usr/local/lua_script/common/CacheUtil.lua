--[[
	局部函数：获取Redis连接
]]
local _CacheUtil = {};

function _CacheUtil:getRedisConn()
	
	-- 获取redis链接
	local redis = require "resty.redis"
	local cache = redis:new()
	local ok,err = cache:connect(v_redis_ip,v_redis_port)
	if not ok then
		ngx.print("{\"success\":\"false\",\"info\":\""..err.."\"}")
		return false;
	end
	
	return cache;
end

--[[
	局部函数：将mysql连接归还到连接池
]]
function _CacheUtil:keepConnAlive(cache)
	-- 将redis连接归还到连接池
	local ok, err = cache: set_keepalive(0, v_pool_size)
	if not ok then
		ngx.log(ngx.ERR, "====>将Redis连接归还连接池出错！");
		return false;
	end
	return true;
end
----------------------------------------------------------------------------------
--[[
	描述： 判断缓存中field是否存在
	参数： key 		缓存的key
	参数： field 	缓存的field的名称
	返回： true 存在，false 不存在
]]
function _CacheUtil:hexists(key, field)
	local cache = _CacheUtil:getRedisConn();
	if not cache then
		ngx.log(ngx.ERR, "[sj_log] -> [cache_util] -> 获取redis连接失败。");
		_CacheUtil:keepConnAlive(cache);
		return false;
	end

	local result, err = cache: hexists(key, field);
	_CacheUtil:keepConnAlive(cache);
	if not result then
		return false;
	end
	local resNum = tonumber(result);
	return (resNum == 1 and true) or false;
end
----------------------------------------------------------------------------------
--[[
	描述： 判断缓存中field是否存在
	参数： cache 	缓存对象
	参数： key 		缓存的key
	参数： field 	缓存的field的名称
	返回： true 存在，false 不存在
]]
function _CacheUtil:hexists_cache(cache, key, field)
	local result, err = cache: hexists(key, field);
	if not result then
		return false;
	end
	local resNum = tonumber(result);
	return (resNum == 1 and true) or false;
end
----------------------------------------------------------------------------------
--[[
	描述： 判断缓存中field是否存在
	参数： key 		缓存的key
	参数： field 	缓存的field的名称
	返回： 返回结果字符串，false key或field不存在
]]
function _CacheUtil:hget(key, field)
	local cache = _CacheUtil:getRedisConn();
	if not cache then
		ngx.log(ngx.ERR, "[sj_log] -> [cache_util] -> 获取redis连接失败。");
		_CacheUtil:keepConnAlive(cache);
		return false;
	end

	local result, err = cache: hget(key, field);
	_CacheUtil:keepConnAlive(cache);
	if not result then
		ngx.log(ngx.ERR, "[sj_log] -> [cache_util] -> key:[", key, "], field:[", field, "] 的缓存不存在。");
		return false;
	end
	return result;
end

-- 返回DBUtil对象
return _CacheUtil;