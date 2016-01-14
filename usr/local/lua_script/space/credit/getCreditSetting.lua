--[[
写操作记录到异步队列
@Author  feiliming
@Date    2015-12-22
]]

local say = ngx.print

--require model
local cjson = require "cjson"
local mysqllib = require "resty.mysql"
--local log = require "social.common.log"

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

local sql = "SELECT * FROM t_social_credit_setting ORDER BY sequence"
local sr, err = mysql:query(sql)
if not sr then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end

local list = sr
for k,v in pairs(sr) do
    --log.debug(v.credit_unit)
    v.credit_name = (tostring(v.credit_name) == "userdata: NULL" and "" or v.credit_name)
    v.credit_icon = (tostring(v.credit_icon) == "userdata: NULL" and "" or v.credit_icon)
    v.credit_unit = (tostring(v.credit_unit) == "userdata: NULL" and "" or v.credit_unit)
    list[k] = v
end

--return
local rr = {}
rr.success = true
rr.list = list

cjson.encode_empty_table_as_object(false)
say(cjson.encode(rr))

--release
mysql:set_keepalive(0,v_pool_size)