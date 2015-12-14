--
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2015/10/19 0019
-- Time: 上午 9:18
-- To change this template use File | Settings | File Templates.
--

--
ngx.header.content_type = "text/plain";
local web = require("social.router.web")
local cjson = require "cjson"
local request = require("social.common.request")
local context = ngx.var.path_uri --有权限的context.
local log = require("social.common.log")

local ResourceService = require("space.ypt.service.ResourceService")
local WkdsService = require("space.ypt.service.WkdsService")
local PaperService = require("space.ypt.service.PaperService")
local HomeWorkService = require("space.ypt.service.HomeWorkService")
-----------------------------------------------------------
-- 资源、备课
local function getResourceAll()
    local personid = request:getStrParam("person_id", true, true)
    local identityid = request:getStrParam("identity_id", true, true)
    local restype = request:getStrParam("res_type", true, true)
    local type_ids = request:getStrParam("type_ids", true, true)
    local pagesize = request:getNumParam("pageSize", true, true)
    local pagenum = request:getNumParam("pageNumber", true, true)
    local result = ResourceService.getResource(personid, identityid, restype, type_ids, pagesize, pagenum);

    if result then
        result.success = true;
    end
    cjson.encode_empty_table_as_object(false)
    ngx.say(cjson.encode(result));
end

-----------------------------------------------------------
-- 试题试卷
local function getPaperAll()
    local personid = request:getStrParam("person_id", true, true)
    local identityid = request:getStrParam("identity_id", true, true)
    --    local restype = request:getStrParam("res_type", true, true)
    local type_ids = request:getStrParam("type_ids", true, true)
    local pagesize = request:getNumParam("pageSize", true, true)
    local pagenum = request:getNumParam("pageNumber", true, true)
    local result = PaperService.getPaper(personid, identityid, type_ids, pagesize, pagenum);
    if result then
        result.success = true;
    end
    cjson.encode_empty_table_as_object(false)
    ngx.say(cjson.encode(result));
end

-----------------------------------------------------------
-- 微课
local function getWkdsAll()
    local personid = request:getStrParam("person_id", true, true)
    local identityid = request:getStrParam("identity_id", true, true)
    --    local restype = request:getStrParam("res_type", true, true)
    local type_ids = request:getStrParam("type_ids", true, true)
    local pagesize = request:getNumParam("pageSize", true, true)
    local pagenum = request:getNumParam("pageNumber", true, true)
    local result, err = WkdsService:getWkds(personid, identityid, type_ids, pagenum, pagesize);
    local rr = {}
    if not result then
        rr.success = false
    else
        rr = result
        rr.success = true
    end
    cjson.encode_empty_table_as_object(false)
    ngx.say(cjson.encode(rr));
end

------------------------------------------------------------------------------------------------------------------------
--- 作业
local function getHomeWork()
    -- local nid = request:getStrParam("nid", true, true)
    --    local schemeid = request:getStrParam("scheme_id", true, true)
    --    local cnode = request:getStrParam("cnode", true, true)
    local sortorder = request:getStrParam("sort_order", true, true)
    local pagesize = request:getStrParam("pageSize", true, true)
    local pagenum = request:getStrParam("pageNumber", true, true)
    --    local isroot = request:getStrParam("is_root", true, true)
    --    local keyword = request:getStrParam("keyword", false, true)
    local personid = request:getStrParam("person_id", false, true)
    local param = { sortorder = sortorder, pagesize = pagesize, pagenum = pagenum, personid = personid };

    local err, result = pcall(HomeWorkService.getHomeWorkByTeacher,param);
    local r = {}
    if not err then
        r.success = false;
        r.info = "参数错误！"
    else
        r = result;
        r.success = true
    end
    log.debug(r)
    cjson.encode_empty_table_as_object(false)
    ngx.say(cjson.encode(r));
end



-- 配置url.
-- 按功能分
local urls = {
    context .. '/getResourceAll', getResourceAll,
    context .. '/getPaperAll', getPaperAll,
    context .. '/getWkdsAll', getWkdsAll,
    context .. '/getHomeWork', getHomeWork,
}
local app = web.application(urls, nil)
app:start()