--[[
写操作记录到异步队列
@Author  feiliming
@Date    2015-12-22
]]

local say = ngx.say
local len = string.len
local quote = ngx.quote_sql_str

--require model
local cjson = require "cjson"
local ssdblib = require "resty.ssdb"
local mysqllib = require "resty.mysql"
local log = require "social.common.log"

--post args
local request_method = ngx.var.request_method
local args,err
if request_method == "GET" then
    args,err = ngx.req.get_uri_args()
else
    ngx.req.read_body()
    args,err = ngx.req.get_post_args() 
end
if not args then 
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end

local list = args["list"]
local list_t = list and cjson.decode(list)
log.debug(list_t)
if not list or len(list) == 0 or not list_t then
	say("{\"success\":false,\"info\":\"参数错误！\"}")
	return
end
for _,v in pairs(list_t) do
    if not v then
        say("{\"success\":false,\"info\":\"参数错误！\"}")
        return
    end
    if not v.credit_name or not v.credit_icon or
            not v.credit_unit or not v.credit_init or
            not v.b_use or not v.id then
        say("{\"success\":false,\"info\":\"参数错误！\"}")
        return
    end
end

--ssdb
local ssdb = ssdblib:new()
local ok, err = ssdb:connect(v_ssdb_ip, v_ssdb_port)
if not ok then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end

--mysql
local mysql, err = mysqllib:new()
if not mysql then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end
local ok, err = mysql:connect{
    host = v_mysql_ip,
    port = v_mysql_port,
    database = v_mysql_database,
    user = v_mysql_user,
    password = v_mysql_password,
    max_packet_size = 1024 * 1024 }
if not ok then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end

local function updateCreditSetting(list_t)
    for _,v in pairs(list_t) do
        local usql = "UPDATE t_social_credit_setting SET credit_name = %s,credit_icon = %s, credit_unit = %s, credit_init = %s, b_use = %s WHERE id = %s"
        usql = string.format(usql, quote(v.credit_name), quote(v.credit_icon), quote(v.credit_unit), quote(v.credit_init), quote(v.b_use), quote(v.id))
        --log.debug(usql)
        local ur, err = mysql:query(usql)
        if not ur or ur.affected_rows == 0 then
            error("更新积分体系失败!")
        end
    end
end

--return
local rr = {}
rr.success = true

--事务控制
mysql:query("START TRANSACTION;")
local status, err = pcall(function()
    updateCreditSetting(list_t)
end)
if status then
    mysql:query("COMMIT;")
else
    mysql:query("ROLLBACK;")
    rr.success = false
    rr.info = err
end

cjson.encode_empty_table_as_object(false)
say(cjson.encode(rr))

--release
ssdb:set_keepalive(0,v_pool_size)
mysql:set_keepalive(0,v_pool_size)