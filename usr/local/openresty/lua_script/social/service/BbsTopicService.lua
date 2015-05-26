--
--    张海  2015-05-06
--    描述：  BBSTopicService 接口. 主题帖操作。
--
local util = require("social.common.util")
local DBUtil = require "common.DBUtil";
local SsdbUtil = require("social.common.ssdbutil")
local TableUtil = require("social.common.table")
local BbsTotalService = require("social.service.BbsTotalService")
local TS = require "resty.TS"

--local BbsTopicService = {}
local M = {}
local BbsTopicService = M
--------------------------------------------------------------------------------
local function splitAddSql(fields, values, tableName)
    local templet = "INSERT INTO `%s` (`%s`) VALUES (%s)"
    local query = templet:format(tableName, table.concat(fields, "`,`"), table.concat(values, ","))
    return query;
end

local function addTable(t, fieldStr, columns, values)
    table.insert(columns, fieldStr)
    table.insert(values, t[fieldStr])
end

local function convertTopic(topic)

    local create_ts = TS.getTs()
    local t = {
        ID = topic.id,
        BBS_ID = topic.bbsId,
        FORUM_ID = topic.forumId,
        TITLE = ngx.quote_sql_str(topic.title),
        FIRST_POST_ID = topic.firstPostId,
        PERSON_ID = topic.personId,
        IDENTITY_ID = topic.identityId,
        PERSON_NAME = ngx.quote_sql_str(topic.personName),
        CREATE_TIME = "now()",
        TS = create_ts,
        UPDATE_TS = create_ts,
        LAST_POST_ID = topic.lastPostId,
        REPLYER_PERSON_ID = topic.replyerPersonId,
        REPLYER_IDENTITY_ID = topic.replyerIdentityId,
        REPLYER_TIME = "now()",
        VIEW_COUNT = topic.viewCount,
        CONTENT = ngx.quote_sql_str(topic.content),
        REPLY_COUNT = topic.replyCount,
        B_REPLY = topic.bReply,
        CATEGORY_ID = topic.categoryId,
        B_BEST = topic.bBest,
        B_TOP = topic.bTop,
        SUPPORT_COUNT = topic.supportCount,
        OPPOSE_COUNT = topic.opposeCount
    }
    util:logData("保存主题帖信息数据Table:");
    util:logData(t)
    return t
end

--------------------------------------------------------------------------------
-- 获取主键
function M:getTopicPkId()
    local db = SsdbUtil:getDb();
    local topicid = db:incr("social_bbs_topic_pk")[1]
    SsdbUtil:keepalive(db)
    return topicid
end

--------------------------------------------------------------------------------
-- 保存主题帖信息(保存到MariaDB数据库)
-- @param table topic
-- @return
function M:saveTopic(topic)
    if topic == nil or TableUtil:length(topic) == 0 then
        error("topic is null");
    end
    --local sql = "INSERT INTO `T_SOCIAL_BBS_TOPIC` (`ID`, `BBS_ID`, `FORUM_ID`, `TITLE`, `FIRST_POST_ID`, `PERSON_ID`, `IDENTITY_ID`, `PERSON_NAME`, `CREATE_TIME`, `LAST_POST_ID`, `REPLYER_PERSON_ID`, `REPLYER_IDENTITY_ID`, `REPLYER_TIME`, `VIEW_COUNT`, `CONTENT`, `REPLY_COUNT`, `B_REPLY`, `CATEGORY_ID`, `B_BEST`, `B_TOP`, `SUPPORT_COUNT`, `OPPOSE_COUNT`) VALUES"
    --local values ="(1, 0, 0, '', 0, 0, NULL, NULL, '2015-05-07 14:01:52', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL)";
    local tempTopic = convertTopic(topic)
    local column = {}
    local fileds = {}
    for key, var in pairs(tempTopic) do
        if tempTopic[key] then
            addTable(tempTopic, key, column, fileds)
        end
    end
    local sql = splitAddSql(column, fileds, "T_SOCIAL_BBS_TOPIC")
    util:logData("保存主题帖信息sql:" .. sql);
    return DBUtil:querySingleSql(sql);
end

--- 保存主题帖信息(保存到SSDB数据库)
-- @param table topic
-- @return
function M:saveTopicToSsdb(topic)
    if topic == nil or TableUtil:length(topic) == 0 then
        error("topic is null");
    end
    if topic.forumId == nil or string.len(topic.forumId) == 0 then
        error("forum id is null");
    end
    topic.createTime = os.date("%Y-%m-%d %H:%M:%S")
    local db = SsdbUtil:getDb();

    local key = "social_bbs_topicid_" .. topic.id
    db:multi_hset(key, topic)
    local topicids_t, err = db:hget("social_bbs_forum_include_topic", "forum_id_" .. topic.forumId)
    local topicids = ""
    if topicids_t and string.len(topicids_t[1]) > 0 then
        topicids = topicids_t[1] .. "," .. topic.id
    else
        topicids = topic.id
    end
    db:hset("social_bbs_forum_include_topic", "forum_id_" .. topic.forumId, topicids)
    SsdbUtil:keepalive(db)
end

--------------------------------------------------------------------------------
-- 回复时修改主题表数据(ssdb)
-- @param topicid #string 主题id.
-- @param lastPostId #string 最后回帖id.
-- @param replyerPersonId #string 回复人id.
-- @param replyerIdentityId #string 回复人身份id.
function M:updateTopicToSsdb(topicid, lastPostId, replyerPersonId, replyerIdentityId)
    if topicid == nil or string.len(topicid) == 0 then
        error("topicid is null");
    end
    local db = SsdbUtil:getDb();
    local key = "social_bbs_topicid_" .. topicid
    local keys = { "lastPostId", "replyerPersonId", "replyerIdentityId", "replyCount", "replyerTime" }
    local topicResult = db:multi_hget(key, unpack(keys))
    if topicResult and #topicResult > 0 then
        local _topic = util:multi_hget(topicResult, keys)
        local viewCount = 0;
        local replyCount = 0;
        if _topic.replyCount ~= "" then
            replyCount = tonumber(_topic.replyCount) + 1 --回复总次数加1次
        else
            replyCount = 1
        end
        local _temp = {}
        _temp.replyCount = replyCount;
        _temp.lastPostId = lastPostId;
        _temp.replyerPersonId = replyerPersonId;
        _temp.replyerIdentityId = replyerIdentityId;
        local date = os.date("%Y-%m-%d %H:%M:%S");
        _temp.replyerTime = date
        db:multi_hset(key, _temp)

        -- db:hincr(key, "replyCount", 1); --回复总次数加1次
    end
    SsdbUtil:keepalive(db)
end

--------------------------------------------------------------------------------
-- 回复时修改主题表数据(ssdb)
-- @param topicid #string 主题id.
-- @param lastPostId #string 最后回帖id.
-- @param replyerPersonId #string 回复人id.
-- @param replyerIdentityId #string 回复人身份id.
function M:updateTopicToDb(topicid, lastPostId, replyerPersonId, replyerIdentityId)
    if topicid == nil or string.len(topicid) == 0 then
        error("topicid is null");
    end
    local replyCount
    local sql = "UPDATE T_SOCIAL_BBS_TOPIC ";
    sql = sql .. "SET CREATE_TIME=CREATE_TIME,LAST_POST_ID=" .. lastPostId .. ",REPLYER_PERSON_ID=" .. replyerPersonId .. ",REPLYER_IDENTITY_ID =" .. replyerIdentityId .. ",replyer_time='now()',REPLY_COUNT=REPLY_COUNT+1"
    sql = sql .. " WHERE ID=" .. topicid
    local topicResult = DBUtil:querySingleSql(sql);
    return topicResult;
end





--------------------------------------------------------------------------------
-- 查看时修改主题表数据(ssdb)
-- @param topicid #string 主题id.
function M:updateTopicViewCountToSsdb(topicid)
    if topicid == nil or string.len(topicid) == 0 then
        error("topicid is null");
    end
    local db = SsdbUtil:getDb();
    local key = "social_bbs_topicid_" .. topicid
    util:logData("查看时的topicid key:" .. key);
    local keys = { "viewCount" }
    local topicResult = db:hexists(key, unpack(keys));
    if topicResult then
        db:hincr(key, "viewCount", 1); --回复总次数加1次
    end
    SsdbUtil:keepalive(db)
end

--------------------------------------------------------------------------------
-- 查看时修改主题表数据(ssdb)
-- @param topicid #string 主题id.
function M:updateTopicViewCountToDb(topicid)
    if topicid == nil or string.len(topicid) == 0 then
        error("topicid is null");
    end
    local replyCount
    local sql = "UPDATE T_SOCIAL_BBS_TOPIC ";
    sql = sql .. "SET VIEW_COUNT=VIEW_COUNT+1"
    sql = sql .. " WHERE ID=" .. topicid
    local topicResult = DBUtil:querySingleSql(sql);
    return topicResult;
end

--------------------------------------------------------------------------------
-- 获取主题帖列表.
-- @param #string bbsid 论坛id.
-- @param #string forumid 板块id.
-- @param #string categoryid 板块分类id.
-- @param #int pagenum 页
-- @param #int pagesize 每页显示条数.
-- @result #table  {list=list,totalRow=totalRow,totalPage=totalPage}
function M:getTopics(bbsid, forumid, categoryid, pagenum, pagesize)
    if bbsid == nil or string.len(bbsid) == 0 then
        error("bbs id 不能为空");
    end
    if forumid == nil or string.len(forumid) == 0 then
        error("forum id 不能为空");
    end

    local categorySql = (categoryid ~= nil and string.len(categoryid) > 0) and " AND T.CATEGORY_ID=" .. categoryid or ""
    local count_sql = "SELECT COUNT(*)  as totalRow FROM T_SOCIAL_BBS_TOPIC T WHERE T.BBS_ID=" .. bbsid .. " AND T.FORUM_ID=" .. forumid .. categorySql
    local list_sql = "SELECT *  FROM T_SOCIAL_BBS_TOPIC T WHERE T.BBS_ID=" .. bbsid .. " AND T.FORUM_ID=" .. forumid .. categorySql
    util:logData("获取主题帖列表.count_sql:" .. count_sql);
    local count = DBUtil:querySingleSql(count_sql);
    if TableUtil:length(count) == 0 then
        return nil;
    end
    util:logData("获取主题帖列表.count:" .. count[1].totalRow);

    local _pagenum = tonumber(pagenum)
    local _pagesize = tonumber(pagesize)
    local totalRow = count[1].totalRow
    local totalPage = math.floor((totalRow + _pagesize - 1) / _pagesize)
    local offset = _pagesize * _pagenum - _pagesize
    list_sql = list_sql .. " LIMIT " .. offset .. "," .. _pagesize
    util:logData("获取主题帖列表.list sql:" .. list_sql);
    local list = DBUtil:querySingleSql(list_sql);
    util:logData("获取主题帖列表.list :" .. list);

    local result = { list = list, totalRow = totalRow, totalPage = totalPage }
    return result;
end


--------------------------------------------------------------------------------
local function getBeforeDay(n)
    local date = date(os.date("%Y%m%d%H%M%S")):adddays(n):fmt("%Y%m%d%H%M%S00") .. string.sub(string.format("%14.3f", ngx.now()), 12, 14)
    return date;
end

local function getBeforeMonth(n)
    local date = date(os.date("%Y%m%d%H%M%S")):addmonths(n):fmt("%Y%m%d%H%M%S00") .. string.sub(string.format("%14.3f", ngx.now()), 12, 14)
    return date;
end

--获取主题帖列表.
--@param #string bbsid 论坛id.
--@param #string forumid 板块id.
--@param #string categoryid 板块分类id.
--@param #int pagenum 页
--@param #int pagesize 每页显示条数.
--@param #string filterDate 筛选时间
--@param #string sortType 排序类型.
--@result #table  {list=list,totalRow=totalRow,totalPage=totalPage}
function M:getTopicsFromSsdb(bbsid, forumid, categoryid, searchText, filterDate, sortType, pagenum, pagesize)
    if bbsid == nil or string.len(bbsid) == 0 then
        error("bbs id 不能为空");
    end
    --    if forumid==nil or string.len(forumid)==0 then
    --            error("forumid 不能为空");
    --    end
    local offset = pagesize * pagenum - pagesize
    local limit = pagesize
    local str_maxmatches = "10000"
    local sql;
    sql = "SELECT SQL_NO_CACHE id FROM T_SOCIAL_BBS_TOPIC_SPHINXSE WHERE query='%s%s%s%s;%sfilter=b_delete,0;%smaxmatches=" .. str_maxmatches .. ";offset=" .. offset .. ";limit=" .. limit .. "';SHOW ENGINE SPHINX  STATUS;"
    local bbsidFilter = "filter=bbs_id," .. bbsid .. ";"
    local forumidFilter = ((forumid == nil or string.len(forumid) == 0) and "") or "filter=forum_id," .. forumid .. ";"
    local categoryidFilter = ((categoryid == nil or string.len(categoryid) == 0) and "") or "filter=category_id," .. categoryid .. ";"
    local searchTextFilter = ((searchText == nil or string.len(searchText) == 0) and "") or searchText .. ";"
    local sort = "sort=attr_desc:"
    if not sortType or string.len(filterDate) == 0 or sortType == "1" then
        sort = sort .. "ts;"
    elseif sortType == "2" then
        sort = sort .. "reply_count;"
    elseif sortType == "3" then
        sort = sort .. "view_count;"
    end
    local _filterDate = ""
    local currentDate = TS.getTs() --今天
    local beforeDate="";
    if filterDate == "1" then
        beforeDate = getBeforeDay(-1) --昨天
    elseif filterDate == "2" then
        beforeDate = getBeforeDay(-2) --前两天
    elseif filterDate == "3" then
        beforeDate = getBeforeDay(-7) --前一周
    elseif filterDate == "4" then
        beforeDate = getBeforeMonth(-1) --前一个月
    elseif filterDate == "5" then
        beforeDate = getBeforeMonth(-3) --前三个月
    end
    _filterDate = ((filterDate == nil or string.len(filterDate) == 0) and "") or "select=(IF(ts>" .. beforeDate .. ",1,0) AND IF(ts<" .. currentDate .. ",1,0)) as match_qq;filter=match_qq,1;"
    sql = string.format(sql, searchTextFilter, bbsidFilter, forumidFilter, categoryidFilter, _filterDate, sort);
    local db = DBUtil:getDb();
    util:logData("sql :" .. sql)
    local res = db:query(sql)
    --去第二个结果集中的Status中截取总个数
    local res1 = db:read_result()
    util:logData(res1)
    DBUtil:keepDbAlive(db)

    local _, s_str = string.find(res1[1]["Status"], "found: ")
    local e_str = string.find(res1[1]["Status"], ", time:")
    local totalRow = string.sub(res1[1]["Status"], s_str + 1, e_str - 1)
    local totalPage = math.floor((totalRow + pagesize - 1) / pagesize)
    util:logData(res)
    --    "success":true,
    --    "bbs": 如果开通，同时返回论坛id,
    --    "total_today":今日主题帖数,
    --    "total_topic":主题帖总数(包括历史),
    --    "pageNumber": 1,
    --    "totalPage": 总页数,
    --    "totalRow":总记录数,
    --    "pageSize":每页条数,
    --    "topic_list":[
    --        {id: id,
    --        title:标题,
    --        category_name:分类名称,
    --        person_id:发主题帖人id,
    --        person_name:发主题帖人名,
    --        create_time:发主题帖时间,
    --        replyer_count:回复数，
    --        view_count:查看数,
    --        last_post_id:最后回帖子id,
    --        last_post_name :最后回帖 名称,
    --        replyer_time:最后回帖时间}
    --    ]
    local topic = {}
    topic.total_today = BbsTotalService:getForumTopicCurrentDateNumber(bbsid, forumid);
    topic.total_topic = BbsTotalService:getForumTopicHistoryNumber(bbsid, forumid);
    topic.pageNumber = pagenum;
    topic.totalPage = totalPage;
    topic.totalRow = totalRow;
    topic.pageSize = pagesize
    topic.bbs = bbsid;
    topic.topic_list = {}
    local db = SsdbUtil:getDb();
    if res then
        for i = 1, #res do
            local key = "social_bbs_topicid_" .. res[i]["id"]
            local keys = { "id", "title", "categoryName", "personId", "personName", "createTime", "replyerCount", "viewCount", "lastPostId", "lastPostName", "replyerTime" }
            local _result = db:multi_hget(key, unpack(keys))
            util:logData("从ssdb中取出的数据")
            util:logData(_result);
            if _result and #_result > 0 then
                local _topic = util:multi_hget(_result, keys)
                util:logData("转换后的数据")
                util:logData(_topic);
                local t = {}
                t.id = _topic.id
                t.title = _topic.title;
                t.category_name = _topic.categoryName
                t.person_id = _topic.personId;
                t.person_name = _topic.personName
                t.create_time = _topic.createTime;
                t.replyer_count = _topic.replyerCount
                t.view_count = _topic.viewCount
                t.last_post_id = _topic.lastPostId
                t.last_post_name = _topic.lastPostName
                t.replyer_time = _topic.replyerTime
                table.insert(topic.topic_list, t)
            end
        end
    end
    util:logData("返回的数据")
    util:logData(topic);
    SsdbUtil:keepalive(db)
    return topic;
end

--------------------------------------------------------------------------------
-- 通过bbsid,forumid,获取分类列表.
-- @param #string bbsid
-- @param #string forumid
-- @return #table result
function M:getBbsTopicCategory(bbsid, forum)
    local sql = "SELECT * FROM T_SOCIAL_BBS_TOPIC_CATEGORY T WHERE T.BBS_ID=%s AND FORUM_ID=%s"
    sql = string.format(sql, bbsid, forum)
    util:logData("通过bbsid,forumid,获取分类列表sql:" .. sql);
    return DBUtil:querySingleSql(sql);
end

return BbsTopicService;
