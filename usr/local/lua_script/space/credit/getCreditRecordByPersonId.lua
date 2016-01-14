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

local person_id = args["person_id"]
local identity_id = args["identity_id"]

if not person_id or len(person_id) == 0 or
    not identity_id or len(identity_id) == 0 then
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
    rule_text = rule_text..",l."..settingResutl[k].id
end

local ruleLogSql = "select l.rule_id,r.rule_name,l.total_num,l.last_time,l.total_num,l.cycle_num,r.reward_num"..rule_text.." FROM t_social_credit_rule_log l,t_social_credit_rule r WHERE r.id = l.rule_id and l.person_id = "..quote(person_id).." AND l.identity_id = "..quote(identity_id).." ORDER BY last_time DESC";
local ruleLogResule, err = mysql:query(ruleLogSql)
if not ruleLogResule then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end



local resultTable = {}
resultTable['success'] = true;
resultTable['list'] = ruleLogResule;
resultTable['title_list'] = settingResutl;
say(cjson.encode(resultTable))
mysql:set_keepalive(0,v_pool_size)