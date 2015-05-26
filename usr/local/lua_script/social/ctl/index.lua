--
--    张海  2015-05-06
--    描述：  BBS index controller.
--
ngx.header.content_type = "text/plain";
local web = require("social.router.web")
local util = require("social.common.util")
local cjson = require "cjson"
local request = require("social.common.request")
local context = ngx.var.path_uri
local log = require("social.common.log")

-----
-- sphinx 端口
-- 3335 topic
-- 3336 post

--获取service
--@param string name
--@return table service
local function getService(name)
    local service_path = "social.service";
    return require(service_path .. "." .. name)
end

--获取区列表
local function index()
    local region_id = request:getStrParam('region_id', false, false)
    local bbs_id = request:getStrParam('bbs_id', false, false)
    if (region_id == nil or string.len(region_id) == 0) and (bbs_id == nil or string.len(bbs_id) == 0) then
        local result = { success = false, info = { name = "", data = "region_id 或 bbs_id 不能同时为空" } };
        ngx.print(cjson.encode(result))
        return;
    end
    local service = getService("BbsService")
    local resResult = {}
    if region_id ~= nil and string.len(region_id) > 0 then
        resResult = service:getBbsByRegionId(region_id)
    end
    if bbs_id ~= nil and string.len(bbs_id) > 0 then
        resResult = service:getBbsById(bbs_id)
    end
    if resResult then
        resResult.success = true
    else
        resResult = {}
        resResult.success = false
        resResult.info = { name = "", data = "没有数据" }
    end
    log.debug(resResult)
    ngx.print(cjson.encode(resResult))
end

--- 通过regionid获取bbs基本信息。
-- @param #string region_id
local function getInfoByRegionId()
    local region_id = request:getStrParam('region_id', true, true)
    local service = getService("BbsService")
    local resResult = service:getBbsInfoByRegionId(region_id)

    if resResult then
        local keys = { "id", "name", "logo_url", "icon_url", "domain", "region_id", "region_type" }
        resResult = util:multi_hget(resResult, keys)
        resResult.success = true
    else
        resResult = {}
        resResult.success = false
        resResult.info = { name = "", data = "没有数据" }
    end
    log.debug(resResult)
    ngx.print(cjson.encode(resResult))
end

--- 通过bbsid获取bbs基本信息。
-- @param #string bbs_id
local function getInfoByBbsId()
    local bbsId = request:getStrParam('bbs_id', true, true)
    local service = getService("BbsService")
    local resResult = service:getBbsInfoByBbsId(bbsId)
    if resResult then
        local keys = { "id", "name", "logo_url", "icon_url", "domain", "region_id", "region_type" }
        resResult = util:multi_hget(resResult, keys)
        resResult.success = true
    else
        resResult = {}
        resResult.success = false
        resResult.info = { name = "", data = "没有数据" }
    end
    log.debug(resResult)
    ngx.print(cjson.encode(resResult))
end


--获取版块列表
local function getForums()
    local bbsid = request:getStrParam('bbs_id', true, true)
    local partitionid = request:getStrParam('partition_id', true, true)
    local service = getService("BbsService")
    local result = service:getForums(bbsid, partitionid)
    if result then
        result.success = true
    else
        result.success = false
    end
    log.debug(result)
    ngx.print(cjson.encode(result))
end

--------------------------------------------------------------------------------
-- 主题帖列表 GET方式 1
-- @param #string bbs_id 论坛id
-- @param #string forum_id: 版块id
-- @param #string category_id:分类id(可以为空)
-- @param #string pageNumber : 页码
-- @param #string pageSize: 每页显示条数.
-- @param #string filterTopic 主题筛选.
-- @param #string filterDate 时间筛选(1:一天，2:两天，3:一周，4:一个月，5:三个月)
-- @param #string sortType 排序（1:发帖时间2:回复时间,3:查看时间,4:最后发表,5:热门）
local function topicList()
    log.debug("topicList start");
    --做sphinx操作，才能实现列表
    local service = require("social.service.BbsTopicService")
    local bbsid = request:getStrParam('bbs_id', true, true)
    local forumid = request:getStrParam('forum_id', false, true)
    local categoryid = request:getStrParam('category_id', false, false)
    local pageNumber = request:getStrParam('pageNumber', true, true)
    local pageSize = request:getStrParam('pageSize', true, true)
    local filterDate = request:getStrParam('filterDate', false, false)
    local sortType = request:getStrParam('sortType', false, false)
    local best = request:getStrParam('best', false, true)
    local result = service:getTopicsFromSsdb(bbsid, forumid, categoryid, nil, filterDate, sortType, best, pageNumber, pageSize)
    if result then
        cjson.encode_empty_table_as_object(false)
        result.success = true;
        ngx.say(cjson.encode(result))
    else
        result.success = false;
        result.info = { name = "", data = "没有数据" }
        ngx.say(cjson.encode(result))
    end
    return;
end

--------------------------------------------------------------------------------
-- 主题帖列表 GET方式搜所 1
-- @param #string bbs_id 论坛id
-- @param #string forum_id: 版块id
-- @param #string category_id:分类id(可以为空)
-- @param #string searchText :查询的字符串.
-- @param #string pageNumber : 页码
-- @param #string pageSize: 每页显示条数.
local function topicSearchList()
    log.debug("topicSearchList start");
    --做sphinx操作，才能实现列表
    local service = getService("BbsTopicService")
    local bbsid = request:getStrParam("bbs_id", true, true)
    local pageNumber = request:getStrParam("pageNumber", true, true)
    local pageSize = request:getStrParam("pageSize", true, true)
    local searchText = request:getStrParam("searchText", true, true)
    log.debug("searchText 搜所内容:")
    log.debug(searchText)
    searchText = ngx.decode_base64(searchText)
    log.debug("searchText 搜所内容base64解码后:")
    log.debug(searchText)
    local result = service:getTopicsFromSsdb(bbsid, nil, nil, searchText, nil, nil, nil, pageNumber, pageSize)
    if result then
        cjson.encode_empty_table_as_object(false)
        result.success = true;
        ngx.say(cjson.encode(result))
    else
        result.success = false;
        result.info = { name = "", data = "没有数据" }
        ngx.say(cjson.encode(result))
    end
    return;
end



--------------------------------------------------------------------------------
-- 通过主题帖id获取回复贴信息.1
-- @param #string bbs_id
-- @param #string forum_id
-- @param #string topic_id
-- @param #string pageNumber.
-- @param #string pageSize.
--
local function topicView()
    local service = getService("BbsPostService")
    local topicService = getService("BbsTopicService")
    local topicid = request:getStrParam("topic_id", true, true)
    local bbsid = request:getStrParam("bbs_id", true, true)
    local forumid = request:getStrParam("forum_id", true, true)
    local pageNumber = request:getStrParam("pageNumber", true, true)
    local pageSize = request:getStrParam("pageSize", true, true)
    local r = service:getPostsFromDb(bbsid, forumid, topicid, pageNumber, pageSize)
    log.debug(r);
    topicService:updateTopicViewCountToDb(topicid)
    topicService:updateTopicViewCountToSsdb(topicid)
    cjson.encode_empty_table_as_object(false)
    if r then
        r.success = true
        ngx.say(cjson.encode(r))
    else
        r.success = false;
        r.info = { name = "", data = "没有数据" }
        ngx.say(cjson.encode(r))
    end
end

local function getBbsList()
    -- local regionid =  request:getStrParam("region_id", true, true)
    local bbsid = request:getStrParam("bbs_id", true, true)
    local pageNumber = request:getStrParam("pageNumber", true, true)
    local pageSize = request:getStrParam("pageSize", true, true)
    local service = getService("BbsService")
    local bbsResult = service:getBbsByIdFromDb(bbsid)
    local resResult = {}
    log.debug(bbsResult)
    if bbsResult and #bbsResult > 0 then
        local regionId = bbsResult[1].region_id;
        local orgType = bbsResult[1].region_type;

        local result = service:getBbsList(regionId, orgType, pageNumber, pageSize)
        if not result then
            result.success = false
            result.info = { name = "", data = "没有数据." }
            ngx.say(cjson.encode(result))
            return
        end
        cjson.encode_empty_table_as_object(false)
        result.success = true
        ngx.say(cjson.encode(result))
        return;
    end
    resResult.success = false;
    resResult.info = { name = "", data = "没有数据." }
    ngx.say(cjson.encode(resResult))
    return
end

-------------------------------------------------------------------------------------
-- 配置url.
-- 按功能分
local urls = {
    context .. '/$', index,
    context .. '/getInfoByRegionId', getInfoByRegionId,
    context .. '/getInfoByBbsId', getInfoByBbsId,
    context .. '/getForums$', getForums,
    context .. '/topic/list', topicList,
    context .. '/topic/search', topicSearchList,
    context .. '/topic/view', topicView,
    context .. '/bbsList$', getBbsList,
}
local app = web.application(urls, nil)
app:start()

