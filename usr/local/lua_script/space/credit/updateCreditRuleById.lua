--[[
写操作记录到异步队列
@Author  feiliming
@Date    2015-12-8
]]

local say = ngx.say
local len = string.len
local quote = ngx.quote_sql_str

--require model
local cjson = require "cjson"
local ssdblib = require "resty.ssdb"
local mysqllib = require "resty.mysql"
local TS = require "resty.TS"
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

local rule_id = args["rule_id"]
local rule_name = args["rule_name"]
local rule_comment = args["rule_comment"]
local cycle_type = args["cycle_type"]
local reward_num = args["reward_num"]
local extcredits = args["extcredits"]
local b_use = args["b_use"]

if not rule_id or len(rule_id) == 0 or
    not rule_name or len(rule_name) == 0 or
    not extcredits or len(extcredits) == 0 or
    not b_use or len(b_use) == 0 or
    not cycle_type or len(cycle_type) == 0  then
	say("{\"success\":false,\"info\":\"参数错误！\"}")
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

local extcredits_list = {}

local status,err =pcall(function()
    extcredits_list = cjson.decode(extcredits)
end)

if not status then
    say("{\"success\":false,\"info\":\"参数错误！\"}")
    return;
end
if not extcredits or len(extcredits) == 0 or not extcredits_list or next(extcredits_list) == nil then
    say("{\"success\":false,\"info\":\"参数错误！\"}")
    return
end


local resultTable = {};
resultTable.rule_id = rule_id
resultTable.rule_name = rule_name
resultTable.rule_comment = rule_comment
resultTable.cycle_type = cycle_type
resultTable.reward_num = reward_num
resultTable.extcredits = extcredits_list
resultTable.b_use = b_use
local updatats = TS.getTs()
local updataSql = "update t_social_credit_rule set rule_name="..quote(rule_name)..",rule_comment="..quote(rule_comment)
                ..",cycle_type="..quote(cycle_type)..",reward_num="..quote(reward_num)..",b_use="..quote(b_use)..",ts="..updatats

for k,v in pairs(extcredits_list) do
    if next(extcredits_list) == nil then
        updataSql = updataSql..""
    else
        updataSql = updataSql..","..k.."="..quote(v)
    end
end
updataSql = updataSql.." where id = "..quote(rule_id)

local result, err = mysql:query(updataSql)
if not result then
    say("{\"success\":false,\"info\":\""..err.."\"}")
else
    say("{\"success\":true}")
end

--release
mysql:set_keepalive(0,v_pool_size)