--
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2015/10/12 0012
-- Time: 下午 3:22
-- To change this template use File | Settings | File Templates.
--

local web = require("social.router.web")
local request = require("social.common.request")
local cjson = require "cjson"
local context = ngx.var.path_uri --有权限的context.
local timeTableService = require("space.timetable.service.TimeTableService")
local TableUtil = require("social.common.table")
local function getTimeTable()
    local person_id = request:getStrParam("person_id", true, true)
    local identity_id = request:getStrParam("identity_id", true, true)
    local type = request:getStrParam("type", false, true)
    local result = timeTableService.getTimeTableData(person_id,identity_id,type);
    if TableUtil:length(result)>0 then
        cjson.encode_empty_table_as_object(false)
        result.success = true;
        ngx.say(cjson.encode(result));
    else
        ngx.say(cjson.encode({success= false}));
    end


end

-- 配置url.
-- 按功能分
local urls = {
    context .. '/getTimeTable', getTimeTable, --1)	获取课程 表.
}
local app = web.application(urls, nil)
app:start()