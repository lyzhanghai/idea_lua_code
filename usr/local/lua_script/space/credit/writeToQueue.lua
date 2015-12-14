--[[
写操作记录到异步队列
@Author  feiliming
@Date    2015-12-10
]]

local say = ngx.say
local len = string.len
local quote = ngx.quote_sql_str

--require model
local cjson = require "cjson"
local redislib = require "resty.redis"
local mysqllib = require "resty.mysql"

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

local person_id = args["person_id"]
local identity_id = args["identity_id"]
local platform_type = args["platform_type"]
local ip_addr = args["ip_addr"]
local os = args["os"]
local browser = args["browser"]
local business_type = args["business_type"]
local relatived_id = args["relatived_id"]
local r_person_id = args["r_person_id"]
local r_identity_id = args["r_identity_id"]
local r_province_id = args["r_province_id"]
local r_city_id = args["r_city_id"]
local r_district_id = args["r_district_id"]
local r_school_id = args["r_school_id"]
local r_class_id = args["r_class_id"]
local operation_content = args["operation_content"]

if not platform_type or len(platform_type) == 0 or 
    not business_type or len(business_type) == 0 then
	say("{\"success\":false,\"info\":\"参数错误！\"}")
	return
end

--redis
local redis = redislib:new()
local ok,err = redis:connect(v_redis_ip,v_redis_port)
if not ok then
    ngx.say("{\"success\":\"false\",\"info\":\""..err.."\"}")
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

--default
category_id = category_id or "-1"
local create_time = os.date("%Y-%m-%d %H:%M:%S")
local update_ts = TS.getTs()
local isql = "INSERT INTO t_social_notice(title, overview, person_id, identity_id, create_time, content, "..
    "category_id, org_id, org_type, register_id, ts, update_ts, thumbnail, attachments, view_count, b_delete, notice_type, stage_id, stage_name, subject_id, subject_name)"..
    " VALUES ("..quote(title)..", "..quote(overview)..", "..quote(person_id)..", "..quote(identity_id)..
    ", "..quote(create_time)..", "..quote(content)..", "..quote(category_id)..", "..quote(org_id)..
    ", "..quote(org_type)..", "..quote(register_id)..", "..quote(update_ts)..", "..quote(update_ts)..
    ", "..quote(thumbnail)..", "..quote(attachments)..", 0, 0, "..quote(notice_type)..","..quote(stage_id)..","..quote(stage_name)..","..quote(subject_id)..","..quote(subject_name)..")"

local ir, err = mysql:query(isql)
if not ir then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end

local notice_id = ir.insert_id
--发送给接收者
--ngx.log(ngx.ERR,receive_json)

--正文插入到ssdb
--base64 encode
local title_base64 = overview and ngx.encode_base64(title) or ""
local content_base64 = content and ngx.encode_base64(content) or ""
local overview_base64 = overview and ngx.encode_base64(overview) or ""

local notice_t = {}
notice_t.notice_id = notice_id
notice_t.title = title_base64
notice_t.overview = overview_base64
notice_t.person_id = person_id
notice_t.identity_id = identity_id

local hr, err = ssdb:multi_hset("social_notice_"..notice_id, notice_t)
if not hr then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end

--return
local rr = {}
rr.success = true

cjson.encode_empty_table_as_object(false)
say(cjson.encode(rr))

--release
ssdb:set_keepalive(0,v_pool_size)
mysql:set_keepalive(0,v_pool_size)