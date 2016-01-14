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

if not rule_id or len(rule_id) == 0 then
    say("{\"success\":false,\"info\":\"参数错误\"}")
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

local creditSettingSql = "select id,credit_name from t_social_credit_setting where b_use=1";
local settingResutl, err = mysql:query(creditSettingSql)
if not settingResutl then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end
if not settingResutl or next(settingResutl) == nil then
    say("{\"success\":true,\"list\":[]}")
    mysql:set_keepalive(0,v_pool_size)
    return
end

local rule_text = ""
for k,v in pairs(settingResutl) do
    rule_text = rule_text..",t."..settingResutl[k].id
end

local ruleSql = "SELECT t.id,t.rule_name,t.rule_comment,t.cycle_type,t.reward_num"..rule_text.." FROM t_social_credit_rule t  WHERE t.id="..rule_id;
local ruleResule, err = mysql:query(ruleSql)
if not ruleResule then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end
for k,v in pairs(settingResutl) do
    ruleResule[1][settingResutl[k].id.."_name"] = settingResutl[k].credit_name
end
ruleResule[1].success = true
local resultTable = ruleResule[1];

say(cjson.encode(resultTable))

mysql:set_keepalive(0,v_pool_size)