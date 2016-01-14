--
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2016/1/9 0009
-- Time: 下午 3:48
-- To change this template use File | Settings | File Templates.
--
local mysql = require("resty.mysql")
local MySQL = {}


local TIMEOUT = 1000;
--- 初始化连接
--
-- @return resty.mysql MySQL连接
function MySQL:initClient()
    local client, err = mysql:new();
    if not client then
        error(err)
    end
    client:set_timeout(TIMEOUT) --1秒.
    local options = {
        user = v_mysql_user,
        password = v_mysql_password,
        database = v_mysql_database,
        host = v_mysql_ip,
        port = v_mysql_port
    }
    local result, errmsg, errno, sqlstate = client:connect(options)
    if not result then
        error("连接数据库出错.")
    end
    ngx.ctx[MySQL] = client
    return ngx.ctx[MySQL]
end

--- 获取连接
--
-- @return resty.mysql MySQL连接
function MySQL:getDb()
    return ngx.ctx[MySQL] or self:initClient()
end

function MySQL:querySingleSql(sql)
    local db = self:getDb();
    local queryResult, err, errno, sqlstate = db:query(sql);
    if not queryResult or queryResult == nil then
        ngx.log(ngx.ERR, "[zh_log]->[DBUtil]-> sql语句执行出错：[err]-> [", err, "], [errno]-> [", errno, "], [sqlstate]->[", sqlstate, "]");
        self:clean();
        return false;
    end
    self:clean();

    return queryResult;
end
---回收mysql,清空ctx.
function MySQL:clean()
    --- 关闭连接
    if ngx.ctx[MySQL] then
        ngx.ctx[MySQL]:set_keepalive(TIMEOUT, v_pool_size)
        ngx.ctx[MySQL] = nil
    end
end

return MySQL;