--
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2015/10/22 0022
-- Time: 上午 9:06
-- To change this template use File | Settings | File Templates.
-- 作业

local log = require("social.common.log")
local SsdbUtil = require("social.common.ssdbutil")
local RedisUtil = require("social.common.redisutil")
local DBUtil = require "common.DBUtil";
local util = require("social.common.util")
local TableUtil = require("social.common.table")
local cjson = require "cjson"
local _M = {}
local function checkParamIsNull(t)
    for key, var in pairs(t) do
        if var == nil or string.len(var) == 0 then
            error(key .. " 不能为空.")
        end
    end
end


local function getStructureScheme(cnode, nid, is_root)
    local structure_scheme;
    if is_root == "1" then
        structure_scheme = ((cnode == "1") and "filter=scheme_id," .. scheme_id .. ";") or "filter=structure_id," .. nid .. ";"
    else
        if cnode == "2" then
            structure_scheme = "filter=structure_id," .. nid .. ";"
        else
            local sid = RedisUtil:getDb():get("node_" .. nid)
            local sids = Split(sid, ",")
            for i = 1, #sids do
                structure_scheme = structure_scheme .. sids[i] .. ","
            end
            structure_scheme = "filter=structure_id," .. string.sub(structure_scheme, 0, #structure_scheme - 1) .. ";"
        end
    end
    return structure_scheme;
end



local function getCount(zyid)

    local ssdb = SsdbUtil:getDb();
    local submission;
    local db = DBUtil:getDb();
    local counts = db:query("SELECT SQL_NO_CACHE id FROM t_zy_info_sphinxse  WHERE query=\'filter=ZY_ID," .. zyid .. "\';SHOW ENGINE SPHINX  STATUS;")
    local count1 = db:read_result()
    local _, s_str = string.find(count1[1]["Status"], "found: ")
    local e_str = string.find(count1[1]["Status"], ", time:")
    local total = string.sub(count1[1]["Status"], s_str + 1, e_str - 1)
    local submissiontotal = ssdb:get("homework_answer_submissionhomework_" .. zyid)
    if string.len(submissiontotal[1]) == 0 then
        submission = ngx.encode_base64("0/" .. (tonumber(total) - 1))
    else
        submission = ngx.encode_base64(submissiontotal[1] .. "/" .. (tonumber(total) - 1))
    end
    return submission
end

--------------------------

-------------------------------------------------------------------------------------------------------------------------
-- 作业接口.
-- local param = { nid = nid, schemeid = schemeid, cnode = cnode, sortorder = sortorder, pagesize = pagesize, pagenum = pagenum, isroot = isroot, keyword = keyword, personid = personid };
function _M.getHomeWorkByTeacher(param)

    checkParamIsNull({
        personid = param.personid,
        sortorder = param.sortorder,
        pagesize = tostring(param.pagesize),
        pagenum = tostring(param.pagenum)
    })


    local ssdb = SsdbUtil:getDb();

    local redis = RedisUtil:getDb();

    local offset = tonumber(param.pagesize) *  tonumber(param.pagenum) - tonumber(param.pagesize)
    local limit = tonumber(param.pagesize)
    local str_maxmatches =  tonumber(param.pagenum) * 100;

    local list = {};

    --升序还是降序
    local asc_desc = (( param.sortorder == "1") and "asc") or "desc"
    local sort_filed = "sort=attr_"..asc_desc..":TS;"
    local person_str = "filter=TEACHER_ID," .. param.personid .. ";"

   -- local structure_scheme = getStructureScheme(param.cnode, param.nid, param.isroot);

    local sql = "SELECT SQL_NO_CACHE id FROM t_zy_info_sphinxse  WHERE query=\'" ..  person_str .. sort_filed .. "filter=TYPE_ID,0;filter=CLASS_ID,0;filter=GROUP_ID,0;sort=attr_desc:ts;maxmatches=" .. str_maxmatches .. ";offset=" .. offset .. ";limit=" .. limit .. "\';SHOW ENGINE SPHINX  STATUS;";

    log.debug(sql);
    local db = DBUtil:getDb();
    local result = db:query(sql)

    local zy1 = db:read_result()
    local _, s_str = string.find(zy1[1]["Status"], "found: ")
    local e_str = string.find(zy1[1]["Status"], ", time:")
    local totalRow = string.sub(zy1[1]["Status"], s_str + 1, e_str - 1)
    local totalPage = math.floor((totalRow + tonumber(param.pagesize) - 1) / tonumber(param.pagesize))
    if result then

        for i = 1, #result do
            local item = {};
            local relate = ssdb:multi_hget("homework_zy_student_relate_" .. result[i]["id"], "zy_id")
            if not relate then
                error("homework_zy_student_relate_" .. result[i]["id"] .. "is null.")
            end
            local zylist, err = ssdb:hget("homework_zy_content", relate[2])
            if not zylist then
                error("homework_zy_content" .. relate[2] .. "is null.")
            end

            local zycontent = cjson.decode(zylist[1]);
            item["zy_id"] = relate[2]
            item["zy_name"] = zycontent.zy_name

            local curr_path = ""
            --获取当前位置
            local structures = redis:zrange("structure_code_" .. zycontent.structure_id, 0, -1)
            for i = 1, #structures do
                local structure_info = redis:hmget("t_resource_structure_" .. structures[i], "structure_name")
                curr_path = curr_path .. structure_info[1] .. "->"
            end
            curr_path = string.sub(curr_path, 0, #curr_path - 2)
            item.parent_structure_name = curr_path
            item.public_time = zycontent.create_time
            item.is_public = zycontent.is_public
            item.is_download = zycontent.is_download
            item.is_look_answer = zycontent.is_look_answer
            item.is_have_res = ((table.getn(zycontent.zy_fj_list) == 0) and 0) or 1;
            item.paper_source = ((zycontent.paper_list and (zycontent.paper_list)[1]) and (zycontent.paper_list)[1].paper_source) or ""
            item.is_have_zg = ((zycontent.zg and (zycontent.zg)[1]) and "1") or "0"
            item.is_have_kg = ((zycontent.kg and (zycontent.kg)[1]) and "1") or "0"

            --老师的作业列表上的统计信息
            -- 提交情况
            item.submission = getCount(relate[2])

            local subjectivepy = ssdb:get("homework_subjectivepy_" .. relate[2])
            if subjectivepy then
                local subjective = ssdb:get("home_answersubjective_" .. relate[2])
                if string.len(subjective[1]) == 0 then
                    item.subjective = ngx.encode_base64("0/0")
                else
                    if string.len(subjectivepy[1]) == 0 then
                        item.subjective = ngx.encode_base64("0/" .. subjective[1])
                    else
                        item.subjective = ngx.encode_base64(subjectivepy[1] .. "/" .. subjective[1])
                    end
                end
            end
            table.insert(list, item);
        end
    end
    local _r = {}
    _r.totalRow = totalRow
    _r.totalPage = totalPage
    _r.pageNumber = pageNumber
    _r.pageSize = pageSize
    _r.list = list
    return _r;
end



return _M;