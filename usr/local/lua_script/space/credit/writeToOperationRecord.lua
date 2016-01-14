--[[
写操作记录到异步队列
@Author  feiliming
@Date    2015-12-17
]]

local say = ngx.print
local len = string.len
local quote = ngx.quote_sql_str

--require model
local cjson = require "cjson"
local mysqllib = require "resty.mysql"
local TS = require "resty.TS"

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
local paramstr = args["paramstr"]
local paramstr_t = paramstr and cjson.decode(paramstr) or {}
local person_id = paramstr_t.person_id or ""
local identity_id = paramstr_t.identity_id or ""
local platform_type = paramstr_t.platform_type
local ip_addr = paramstr_t.ip_addr or ""
local operation_system = paramstr_t.operation_system or ""
local browser = paramstr_t.browser or ""
local business_type = paramstr_t.business_type
local relatived_id = paramstr_t.relatived_id or ""
local r_person_id = paramstr_t.r_person_id or ""
local r_identity_id = paramstr_t.r_identity_id or ""
local r_province_id = paramstr_t.r_province_id or ""
local r_city_id = paramstr_t.r_city_id or ""
local r_district_id = paramstr_t.r_district_id or ""
local r_school_id = paramstr_t.r_school_id or ""
local r_class_id = paramstr_t.r_class_id or ""
local operation_content = paramstr_t.operation_content or ""
local norepeat_ts = paramstr_t.norepeat_ts or ""

--ngx.log(ngx.ERR,"===========invoke write to operation record"..platform_type..business_type)

if not platform_type or len(platform_type) == 0 or
        not business_type or len(business_type) == 0 then
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

--获取person_id详情, 调用基础数据接口
local person = {}
if person_id and len(person_id) > 0 and identity_id and len(identity_id) > 0 then
    local r = {}
    local personService = require "base.person.services.PersonService"
    r  = personService:getPersonInfo(person_id,identity_id)
    if not r or not r.success then
        say("{\"success\":false,\"info\":\"调用基础数据接口失败\"}")
        return;
    end
    person.province_id = r.table_List and r.table_List.province_id or ""
    person.district_id = r.table_List and r.table_List.district_id or ""
    person.city_id = r.table_List and r.table_List.city_id or ""
    person.school_id = r.table_List and r.table_List.school_id or ""
    person.class_id = r.table_List and r.table_List.class_id or ""
end

--return
local rr = {}
rr.success = true

--判断是否已经写过，防止写队列重复写
local ssql = "SELECT id FROM t_social_operation_record where norepeat_ts = "..quote(norepeat_ts)
local sr, err = mysql:query(ssql)
if not sr then
    rr.success = false
    rr.info = err
end

if sr and #sr == 0 then
    --insert mysql
    local create_time = os.date("%Y-%m-%d %H:%M:%S")
    local ts = TS.getTs()
    local isql = "INSERT INTO t_social_operation_record(person_id, indentity_id, province_id, city_id, district_id, school_id, "..
            "class_id, ip_addr, os, browser, create_time, ts, platform_type, business_type, relatived_id, r_person_id, r_identity_id, "..
            "r_province_id, r_city_id, r_district_id, r_school_id, r_class_id, operation_content, norepeat_ts)"..
            " VALUES ("..quote(person_id)..", "..quote(identity_id)..", "..quote(person.province_id or "")..", "..quote(person.city_id or "")..
            ", "..quote(person.district_id or "")..", "..quote(person.school_id or "")..", "..quote(person.class_id or "")..", "..quote(ip_addr)..
            ", "..quote(operation_system)..", "..quote(browser)..", "..quote(create_time)..", "..quote(ts)..
            ", "..quote(platform_type)..", "..quote(business_type)..", "..quote(relatived_id)..", "..quote(r_person_id)..
            ", "..quote(r_identity_id)..", "..quote(r_province_id)..", "..quote(r_city_id)..", "..quote(r_district_id)..
            ", "..quote(r_school_id)..", "..quote(r_class_id)..", "..quote(operation_content)..", "..quote(norepeat_ts)..")"
    local ir, err = mysql:query(isql)
    if not ir then
        rr.success = false
        rr.info = err
    end
end

cjson.encode_empty_table_as_object(false)
say(cjson.encode(rr))

--release
mysql:set_keepalive(0,v_pool_size)
