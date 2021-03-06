--[[
写操作记录到异步队列
@Author  feiliming
@Date    2015-12-25
]]

local say = ngx.say
local len = string.len
local quote = ngx.quote_sql_str

--require model
local cjson = require "cjson"
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

local org_id = args["org_id"]
local org_level = args["org_level"]
local identity_id = args["identity_id"]
local order_column = args["order_column"]
local order_type = args["order_type"]
local pageNumber = args["pageNumber"]
local pageSize = args["pageSize"]

if not org_id or len(org_id) == 0 or
    not org_level or len(org_level) == 0 or
    not identity_id or len(identity_id) == 0 or
        not pageNumber or len(pageNumber) == 0 or
        not pageSize or len(pageSize) == 0  then
	say("{\"success\":false,\"info\":\"参数错误！\"}")
	return
end

pageNumber = tonumber(pageNumber)
pageSize = tonumber(pageSize)
if not order_column or len(order_column) == 0  then
    order_column = "extcredits1"
end
if not order_type or len(order_type) == 0 then
    order_type = "desc"
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

--查询启用的体系
local setting_flag = true
local sql = "SELECT id,credit_name FROM t_social_credit_setting WHERE B_USE = 1 ORDER BY sequence"
local ruleset, err = mysql:query(sql)
if not ruleset then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end
if #ruleset == 0 then
    setting_flag = false
end

local org_level_map = {
    org_100 = "",
    org_101 = "province_id",
    org_102 = "city_id",
    org_103 = "district_id",
    org_104 = "school_id",
    org_105 = "class_id"
}

--获取person_id详情, 调用基础数据接口
local function getPersonInfo(person_id, identity_id)
    local person = {}
    if person_id and len(person_id) > 0 and identity_id and len(identity_id) > 0 then
        local r = {}
        local personService = require "base.person.services.PersonService"
        r  = personService:getPersonInfo(person_id,identity_id)
        if not r or not r.success then
            return person
        end
        person.person_name = r.table_List and r.table_List.person_name or ""
        person.bureau_id = r.table_List and r.table_List.bureau_id or ""
        person.bureau_name = r.table_List and r.table_List.bureau_name or ""
    end
    return person
end

local count_list = {}
local totalPage = 0
local totalRow = 0
if setting_flag then
    local sql1 = "SELECT COUNT(*) AS totalRow FROM t_social_credit_count WHERE %s"
    if org_level == "100" then
        sql1 = string.format(sql1, "identity_id="..quote(identity_id), order_column, order_type)
    elseif org_level == "101" or org_level == "102" or org_level == "103" or org_level == "104" or org_level == "105" then
        sql1 = string.format(sql1, org_level_map["org_"..org_level].."="..quote(org_id).." AND identity_id="..quote(identity_id))
    else
        say("{\"success\":false,\"info\":\"机构类型错误\"}")
        return
    end
    local totalRow_t, err = mysql:query(sql1)
    if not totalRow_t then
        say("{\"success\":false,\"info\":\""..err.."\"}")
        return
    end
    totalRow = tonumber(totalRow_t[1].totalRow)
    totalPage = math.floor((totalRow + pageSize - 1) / pageSize)
    if totalPage > 0 and pageNumber > totalPage then
        pageNumber = totalPage
    end
    local offset = pageSize*pageNumber-pageSize
    local limit = pageSize

    local settingBues = {}
    for _,v in pairs(ruleset) do
        table.insert(settingBues,v.id)
    end
    local sql2 = "SELECT id,person_id,identity_id, %s FROM t_social_credit_count WHERE %s ORDER BY %s %s LIMIT %s, %s"
    if org_level == "100" then
        sql2 = string.format(sql2, table.concat(settingBues, ","), "identity_id="..quote(identity_id), order_column, order_type, offset, limit)
    else
        sql2 = string.format(sql2, table.concat(settingBues, ","), org_level_map["org_"..org_level].."="..quote(org_id).." AND identity_id="..quote(identity_id), order_column, order_type, offset, limit)
    end
    --local log = require "social.common.log"
    --log.debug(sql1)
    local sr, err = mysql:query(sql2)
    if not sr then
        say("{\"success\":false,\"info\":\""..err.."\"}")
        return
    end
    count_list = sr
    for k,v in pairs(count_list) do
        local p = getPersonInfo(v.person_id, v.identity_id)
        count_list[k].person_name = p.person_name or ""
        count_list[k].bureau_id = p.bureau_id or ""
        count_list[k].bureau_name = p.bureau_name or ""
    end
end

--return
local rr = {}
rr.success = true
rr.setting_flag = setting_flag
rr.setting_list = ruleset
rr.count_list = count_list
rr.totalRow = totalRow
rr.totalPage = totalPage
rr.pageNumber = pageNumber
rr.pageSize = pageSize
rr.order_column = order_column
rr.order_type = order_type

cjson.encode_empty_table_as_object(false)
say(cjson.encode(rr))

--release
mysql:set_keepalive(0,v_pool_size)