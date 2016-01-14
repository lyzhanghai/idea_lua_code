
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

local settingSql = "SELECT s.id,s.credit_name,s.credit_icon,s.credit_unit FROM t_social_credit_setting s WHERE B_USE = 1;";
local settingResutl, err = mysql:query(settingSql)
if not settingResutl then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end
if not settingResutl or next(settingResutl) == nil then
    say("{\"success\":true,\"list\":[]}")
    mysql:set_keepalive(0,v_pool_size)
    return
end
local rule_text = "t.id"
for k,v in pairs(settingResutl) do
    rule_text = rule_text..",t."..settingResutl[k].id
end

local ruleLogSql = "SELECT "..rule_text.." FROM t_social_credit_count t WHERE t.person_id = "..person_id.." AND t.identity_id = "..identity_id..";";
local ruleLogResule, err = mysql:query(ruleLogSql)
if not ruleLogResule then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end

for k,v in pairs(settingResutl) do
    if not ruleLogResule or next(ruleLogResule) == nil then
        settingResutl[k]['extcredit_total'] = 0
    else
        settingResutl[k]['extcredit_total'] = ruleLogResule[1][settingResutl[k].id]
    end
end

local resultTable = {}
resultTable['success'] = true;
resultTable['list'] = settingResutl;
say(cjson.encode(resultTable))
mysql:set_keepalive(0,v_pool_size)