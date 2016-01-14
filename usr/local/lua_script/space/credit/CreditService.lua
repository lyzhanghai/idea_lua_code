--[[
积分service
@Author  feiliming
@Date    2015-12-28
]]

local TS = require "resty.TS"

local _M = {}

--[[
参数说明：
"person_id": 30163, 操作者id，需要登录的操作必选，匿名浏览等时可选
"identity_id": 5, 操作者身份id，需要登录的操作必选，匿名浏览等时可选
"platform_type": 1, 1表示web、2.ebag、3.teach、4.office、5.app，必选
"ip_addr": 10.10.6.199, 操作者ip，可选
"operation_system": win7、win8、apple等，操作者使用的操作系统，可选
"browser": IE10，操作者使用的浏览器，可选
"business_type": 1, 业务类型id，按功能点划分，参考t_socail_dictionary数据字典，必选
"relatived_id": 72546, 被操作的相关业务数据id，比如资源id，可选
"r_person_id": 625, 被操作数据所有者id，可选
"r_identity_id": 5, 被操作数据所有者身份id，可选
"r_province_id": 10001, 被操作数据所属省id，可选
"r_city_id": 20001, 被操作数据所属市id，可选
"r_district_id": 30001, 被操作数据所属区县id，可选
"r_school_id": 456, 被操作数据所属校id，可选
"r_class_id": 789, 被操作数据所属班id，可选
"operation_content": 操作详细说明，留作系统动态使用，可以是一段文字，如果需要超链接也可以是一段html代码，例如：张三上传了一条微课“bootstrap视频教程”，需要登录的操作必选，匿名浏览等时可选，长度小于1000
]]
function _M:writeToQueue(args)

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

    if not platform_type or string.len(platform_type) == 0 or
            not business_type or string.len(business_type) == 0 then
        return false,"参数错误!"
    end

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

    local asyncQueueService = require "common.AsyncDataQueue.AsyncQueueService"
    local asyncCmdStr = asyncQueueService: getAsyncCmd("007001", paramObj)
    --ngx.log(ngx.ERR, "[supervise] -> asyncCmdStr: [", asyncCmdStr, "]")
    local r,err = asyncQueueService: sendAsyncCmd(asyncCmdStr)

    if not r then
        return false,err
    end

    return true
end

return _M