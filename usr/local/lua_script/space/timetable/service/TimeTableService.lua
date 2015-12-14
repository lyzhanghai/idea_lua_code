--
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2015/10/12 0012
-- Time: 下午 3:23
-- To change this template use File | Settings | File Templates.
-- 课程表读取，目前给手机 ，传自定义与任课计划类型区分调用接口。
--
local log = require("social.common.log")
local SsdbUtil = require("social.common.ssdbutil")
local cjson = require "cjson"
local _M = {}

local function getTimeTableType(person_id, identity_id)
    local db = SsdbUtil:getDb()
    local result;
    cjson.encode_empty_table_as_object(false)
    local json = db:get("space_info_" .. person_id .. "_" .. identity_id)

    if json and json[1] and string.len(json[1]) > 0 then
        local jsonResult = cjson.decode(json[1])
        local setting_t = jsonResult['ALL_Setting']
        for k, _ in pairs(setting_t) do
            local _k = string.sub(k, 1, -7)
            if _k == "timetable" then
                result = setting_t[k]['self_setting']['timetable_type']; --1任课计划，2自定义
                return result
            end
        end
    else
        result = "1";
    end
    return result
end

function _M.getTimeTableData(person_id, identity_id,type)
    local db = SsdbUtil:getDb()
    local t  = getTimeTableType(person_id, identity_id);
    log.debug(t);
    local timetable_type = ((type == nil or string.len(type) == 0) and getTimeTableType(person_id, identity_id)) or type;
    log.debug(timetable_type);


    local obj ={};

    if tostring(timetable_type) == "1" then
        --http://10.10.6.199/dsideal_yy/class/getTeaKechengbiao?random_num=611575&person_id=30163&xq_id=2
        local classService = require "base.class.services.ClassService";
        obj = classService:getCurSyllabus(person_id,identity_id);
        obj.type=tostring(timetable_type);
        obj.point_count = 8
    else
        --小黄
        --spacetimetable
        local json, err = db:get("space_ajson_spacetimetable_" .. person_id .. "_" .. identity_id)
        if json and json[1] and string.len(json[1])>0 and json~="ok" and json~="not_found" then
            local jsonObj = json[1]
            local jsonTable =  cjson.decode(jsonObj);
            local jsonList = jsonTable['list'];
            obj.weekday_count =  7
            obj.type  =tostring(timetable_type);
            obj.point_count = jsonTable['row'];
            log.debug(obj)
            obj.list = {}
            for i=1,#jsonList do--为星期几.
                local lst = jsonList[i];
                for j = 1,#lst do--j为第几节课
                    if lst[j]~="" then
                        local temp = {}
                        log.debug("i:"..i.." : ".." j:"..j .." value:"..lst[j])
                        temp.pointname = i
                        temp.weekday=j
                        temp.subject_name = lst[j];
                        table.insert(obj.list,temp);
                    end
                end
            end
        else
            obj.weekday_count =  7
            obj.type =tostring(timetable_type);
            obj.list = {}
            obj.point_count = 8
        end
    end
    return obj;
end




return _M