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

local page_number = args["page_number"]
local page_size = args["page_size"]

if not page_number or len(page_number) == 0 or tonumber(page_number) == nil or tonumber(page_size) == nil or
    not page_size or len(page_size) == 0 then
	say("{\"success\":false,\"info\":\"参数错误！\"}")
	return
end
page_number = tonumber(page_number)
page_size = tonumber(page_size)
if not (page_number > 0) then
    page_number = 0
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

local countsql = "SELECT count(*) as countrow FROM t_social_credit_rule;"
local countr, err = mysql:query(countsql)
if not countr then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end
total_row = countr[1].countrow
local rr = {}

local resultsql = "select id,credit_name from t_social_credit_setting where b_use = 1;"
local result, err = mysql:query(resultsql)
if not result then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end
local rule_text = ""
for k,v in pairs(result) do
    rule_text = rule_text..","..result[k].id
end
--[[local title_list = {};
for k,v in pairs(result) do
    title_list[result[k].id]=result[k].credit_name
end]]

if total_row == 0 then
    rr.total_row = 0;
    rr.total_page = 0;
    rr.page_number = page_number;
    rr.page_size = page_size;
    rr.rule_list = {};
else
    local isql = "SELECT id,rule_name,rule_comment,business_type,cycle_type,reward_num,b_use"..rule_text.." FROM t_social_credit_rule LIMIT "..(page_size*page_number-page_size).."," ..page_size
    local ir, err = mysql:query(isql)
    if not ir then
        say("{\"success\":false,\"info\":\""..err.."\"}")
        return
    end
    rr.rule_list = ir;
    rr.total_row = total_row;
    rr.total_page = math.floor((total_row + page_size - 1) / page_size)
    rr.page_number = page_number;
    rr.page_size = page_size;
end

--return
rr.success = true
rr.title_list = result;

say(cjson.encode(rr))

--release
mysql:set_keepalive(0,v_pool_size)