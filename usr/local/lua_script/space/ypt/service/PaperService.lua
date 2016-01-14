--
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2015/10/19 0019
-- Time: 上午 9:23
-- To change this template use File | Settings | File Templates.
--
local log = require("social.common.log")
local SsdbUtil = require("social.common.ssdbutil")
local RedisUtil = require("social.common.redisutil")
local DBUtil = require "social.common.mysqlutil";
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
-- 空间获取试卷信息
-- @param personid string 用户id.
-- @param identityid string  身份id.
-- @param type_ids string 类型id.
-- @param pagesize int 每页显示条数
-- @param pagenum int 当前页.
function _M.getPaper(personid, identityid, type_ids, pagesize, pagenum)
    checkParamIsNull({
        personid = personid,
        identityid = identityid,
        type_id = type_id,
        pagesize = tostring(pagesize),
        pagenum = tostring(pagenum)
    })
    local offset = pagesize * pagenum - pagesize
    local limit = pagesize
    local str_maxmatches = pagenum * 100;
    local db = DBUtil:getDb();
    local ssdb_db = SsdbUtil:getDb();
    local cache = RedisUtil:getDb();
    local sql = "SELECT SQL_NO_CACHE id FROM t_sjk_paper_my_info_sphinxse WHERE query='filter=b_delete,0;filter=type_id," .. type_ids .. ";filter=person_id," .. personid .. ";sort=attr_desc:TS;maxmatches=" .. str_maxmatches .. ";offset=" .. offset .. ";limit=" .. limit .. "\';SHOW ENGINE SPHINX  STATUS;";
    log.debug(sql);
    local res = db:query(sql)
    local result = { list = {} }
    --去第二个结果集中的Status中截取总个数
    local res1 = db:read_result()
    local _, s_str = string.find(res1[1]["Status"], "found: ")
    local e_str = string.find(res1[1]["Status"], ", time:")
    local totalRow = string.sub(res1[1]["Status"], s_str + 1, e_str - 1)
    local totalPage = math.floor((totalRow + pagesize - 1) / pagesize)

    local keys = { "paper_id_char", "paper_name", "question_count", "create_time", "paper_type", "preview_status", "extension", "file_id", "paper_page", "structure_id", "paper_id_char", "paper_id_int", "table_pk", "group_id", "person_id", "identity_id", "owner_id", "type_id", "for_urlencoder_url", "for_iso_url", "identity_id", "identity_id", "paper_app_type", "paper_app_type_name", "subject_id" }

    for i = 1, #res do

        local paper_value = cache:hmget("mypaper_" .. res[i]["id"], unpack(keys));
        local _paper = TableUtil:toMap(paper_value, keys);
        local paper_result = {}
        TableUtil:copy(_paper, paper_result, keys); --copy对象.

        if paper_value and #paper_value > 0 then
            if _paper.paper_type == "2" then
                local resource_info_id = cache:hmget("mypaper_" .. res[i]["id"], "resource_info_id")[1]
                local resource_keys = { "preview_status", "for_iso_url", "for_urlencoder_url", "file_id", "resource_page", "structure_id", "scheme_id_int" };
                local resource_info = ssdb_db:multi_hget("resource_" .. resource_info_id, unpack(resource_keys))
                local _resource = util:multi_hget(resource_info, resource_keys);
                --TableUtil:copy(_resource, paper_result, resource_keys); --copy对象.
                paper_result.preview_status = _resource.preview_status;
                paper_result.for_iso_url = _resource.for_iso_url;
                paper_result.for_urlencoder_url = _resource.for_urlencoder_url;
                paper_result.file_id = _resource.file_id;
                paper_result.page = _resource.resource_page;
                paper_result.structure_id = _resource.structure_id;
                paper_result.scheme_id_int = _resource.scheme_id_int;
            end
            local structure_id = _paper.structure_id;
            local curr_path = ""
            local structures = cache:zrange("structure_code_" .. structure_id, 0, -1)

            for i = 1, #structures do
                local structure_info = cache:hmget("t_resource_structure_" .. structures[i], "structure_name")
                curr_path = curr_path .. structure_info[1] .. "->"
            end
            curr_path = string.sub(curr_path, 0, #curr_path - 2)
            paper_result.structure_id = curr_path
            paper_result.url_code = encodeURI(_paper.paper_name)
            paper_result.paper_source = _paper.paper_type;
            paper_result.extenstion = _paper.extension;
            --paper_result.page = _paper.paper_page;
            table.insert(result.list, paper_result);
        end
    end
    result.totalRow = totalRow
    result.totalPage = totalPage;
    result.pageNumber = pagenum
    result.pageSize = pagesize;

    return result;
end


return _M;