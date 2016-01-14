--[[
写操作记录到异步队列
@Author  feiliming
@Date    2015-12-17
]]

local say = ngx.say
local len = string.len
local quote = ngx.quote_sql_str

--require model
local cjson = require "cjson"
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

local person_id = args["person_id"] or ""
local identity_id = args["identity_id"] or ""
local platform_type = args["platform_type"]
local ip_addr = args["ip_addr"] or ""
local operation_system = args["operation_system"] or ""
local browser = args["browser"] or ""
local business_type = args["business_type"]
local relatived_id = args["relatived_id"] or ""
local r_person_id = args["r_person_id"] or ""
local r_identity_id = args["r_identity_id"] or ""
local r_province_id = args["r_province_id"] or ""
local r_city_id = args["r_city_id"] or ""
local r_district_id = args["r_district_id"] or ""
local r_school_id = args["r_school_id"] or ""
local r_class_id = args["r_class_id"] or ""
local operation_content = args["operation_content"] or ""

if not platform_type or len(platform_type) == 0 or 
    not business_type or len(business_type) == 0 then
	say("{\"success\":false,\"info\":\"参数错误！\"}")
	return
end

--write to queue
local paramObj  = {}
paramObj.person_id = person_id
paramObj.identity_id = identity_id
paramObj.platform_type = platform_type
paramObj.ip_addr = ip_addr
paramObj.operation_system = operation_system
paramObj.browser = browser
paramObj.business_type = business_type
paramObj.relatived_id = relatived_id
paramObj.r_person_id = r_person_id
paramObj.r_identity_id = r_identity_id
paramObj.r_province_id = r_province_id
paramObj.r_district_id = r_district_id
paramObj.r_city_id = r_city_id
paramObj.r_school_id = r_school_id
paramObj.r_class_id = r_class_id
paramObj.operation_content = operation_content
paramObj.norepeat_ts = TS.getTs()

--local creditService = require "space.credit.CreditService"
--local r,err = creditService:writeToQueue (paramObj)

local asyncQueueService = require "common.AsyncDataQueue.AsyncQueueService"
local asyncCmdStr = asyncQueueService: getAsyncCmd("007001", paramObj)
--ngx.log(ngx.ERR, "[supervise] -> asyncCmdStr: [", asyncCmdStr, "]")
local r,err = asyncQueueService: sendAsyncCmd(asyncCmdStr)

--return
local rr = {}
rr.success = true
if not r then
    rr.success = false
    rr.info = err
end

cjson.encode_empty_table_as_object(false)
say(cjson.encode(rr))

--release
