--
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2015/10/19 0019
-- Time: 上午 9:22
-- To change this template use File | Settings | File Templates.
-- 资源接口.

local log = require("social.common.log")
local SsdbUtil = require("social.common.ssdbutil")
local RedisUtil = require("social.common.redisutil")
local DBUtil = require "social.common.mysqlutil";
local myPrime = require "resty.PRIME";
local util = require("social.common.util")
local TableUtil = require("social.common.table")
local _M = {}

local function checkParamIsNull(t)
    for key, var in pairs(t) do
        if var == nil or string.len(var) == 0 then
            error(key .. " 不能为空.")
        end
    end
end

local function urlencode(str)
    if (str) then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w ])",
            function(c) return string.format("%%%%%02X", string.byte(c)) end)
        str = string.gsub(str, " ", "+")
    end
    return str
end
local function encodeURI(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end
------------------------------------------------------------------------------------------------------------------------
-- 空间获取获取资源信息.
-- @param personid string 用户id.
-- @param identityid string  身份id.
-- @param type_ids string 类型id.
-- @param res_type string 资源类型.
-- @param pagesize int 每页显示条数
-- @param pagenum int 当前页.
function _M.getResource(personid, identityid, res_type, type_ids, pagesize, pagenum)

    checkParamIsNull({
        personid = personid,
        identityid = identityid,
        res_type = res_type,
        type_ids = type_ids,
        pagesize = tostring(pagesize),
        pagenum = tostring(pagenum)
    })

    local result_value = {}
    local offset = pagesize * pagenum - pagesize
    local limit = pagesize
    local str_maxmatches = pagenum * 100;


    local sql = "SELECT SQL_NO_CACHE id FROM t_resource_my_info_sphinxse WHERE query=\'filter=b_delete,0;filter=res_type," .. res_type .. ";filter=type_id," .. type_ids .. ";filter=person_id," .. personid .. ";filter=identity_id," .. identityid .. ";sort=attr_desc:TS;maxmatches=" .. str_maxmatches .. ";offset=" .. offset .. ";limit=" .. limit .. "\';SHOW ENGINE SPHINX  STATUS;"
    log.debug("输出的sphinx 语句:")
    log.debug(sql);

    local db = DBUtil:getDb();
    local res = db:query(sql);
    local res1 = db:read_result()
    local _, s_str = string.find(res1[1]["Status"], "found: ")
    local e_str = string.find(res1[1]["Status"], ", time:")
    local totalRow = string.sub(res1[1]["Status"], s_str + 1, e_str - 1)
    local totalPage = math.floor((totalRow + pagesize - 1) / pagesize)
    local ssdb_db = SsdbUtil:getDb();
    local cache = RedisUtil:getDb();
    local keys = { "resource_id_int", "resource_id_char", "resource_title", "resource_type_name", "resource_type", "resource_format", "resource_page", "resource_size", "create_time", "down_count", "file_id", "thumb_id", "preview_status", "structure_id", "scheme_id_int", "type_id", "width", "height", "group_id", "table_pk", "bk_type_name", "beike_type", "resource_size_int", "for_urlencoder_url", "for_iso_url", "app_type_id", "subject_id", "stage_id" }
    local list = {}
    if res then
        for i = 1, #res do
            local result = {};
            log.debug("=========================================");
            log.debug(res[i]["id"]);
            local resource_value = ssdb_db:multi_hget("myresource_" .. res[i]["id"], unpack(keys));
            if resource_value and #resource_value > 0 then
                -- log.debug(resource_value);
                local _resource = util:multi_hget(resource_value, keys);
                TableUtil:copy(_resource, result, keys); --copy对象.
                local structure_id = _resource.structure_id;
                result.structure_id = structure_id;
                local subject_id = _resource.subject_id;
                result.subject_id = subject_id;
                local scheme_id = _resource.scheme_id_int;
                result.scheme_id = scheme_id;
                result.iid = res[i]["id"];
                local curr_path = ""

                local structures = cache:zrange("structure_code_" .. structure_id, 0, -1)
                for i = 1, #structures do
                    local structure_info = cache:hmget("t_resource_structure_" .. structures[i], "structure_name")
                    curr_path = curr_path .. structure_info[1] .. "->"
                end
                curr_path = string.sub(curr_path, 0, #curr_path - 2)
                --log.debug(curr_path);
                log.debug(_resource.resource_title)
                local url_str = encodeURI(_resource.resource_title)
                log.debug(url_str)
                result.url_code = url_str;
                result.parent_structure_name = curr_path;
                local app_type_id = _resource.app_type_id;
                local app_type_name = "";
                if app_type_id ~= "-1" and app_type_id ~= "1" then
                    local app_typeids = myPrime.dec_prime(app_type_id);
                    local app_type_name_tab = Split(app_typeids, ",");
                    for i = 1, #app_type_name_tab do
                        local apptypename = "";
                        if subject_id == "-1" then
                            apptypename = '素材';
                        else
                            apptypename = cache:hget("t_base_apptype_" .. scheme_id .. "_" .. app_type_name_tab[i], "app_type_name")
                        end

                        app_type_name = ((i == 1) and apptypename) or app_type_name .. "," .. apptypename;
                    end
                    result.app_type_name = app_type_name;
                    result.app_type_id = app_type_id;
                end
                if subject_id ~= "-1" or subject_id ~= "0" or subject_id ~= 0 then
                    local subject_info = ssdb_db:multi_hget("subject_" .. subject_id, "stage_subject");

                    if subject_info then
                        result.stage_subject = tostring(subject_info[2])
                    end
                end
                table.insert(list, result);
            end
        end
    end
    result_value.list = list;
    result_value.totalRow = totalRow
    result_value.totalPage = totalPage;
    result_value.pageNumber = pagenum
    result_value.pageSize = pagesize;
    return result_value;
end



return _M

