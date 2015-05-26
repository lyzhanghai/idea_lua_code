--
--    张海  2015-05-06
--    描述：  BBS BbsPostService 接口.
--
local util = require("social.common.util")
local DBUtil = require "common.DBUtil";
local SsdbUtil = require("social.common.ssdbutil")
local TableUtil = require("social.common.table")
local BbsTopicService = require("social.service.BbsTopicService")
local BbsPostService = {}
local db = {}
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

--------------------------------------------------------------------------------
-- CREATE TABLE `t_social_bbs_post` (
-- `id` INT(11) NOT NULL COMMENT '主键',
-- `bbs_id` INT(11) NOT NULL COMMENT '论坛id',
-- `forum_id` INT(11) NOT NULL COMMENT '版块id',
-- `top_id` INT(11) NOT NULL COMMENT '主题帖id',
-- `title` VARCHAR(100) NULL DEFAULT NULL COMMENT '帖子标题',
-- `content` BLOB NULL COMMENT '帖子内容，引用回复时截取内容存在一起',
-- `person_id` INT(11) NULL DEFAULT NULL COMMENT '发帖人id',
-- `identity_id` INT(11) NULL DEFAULT NULL COMMENT '发帖人身份id',
-- `person_name` VARCHAR(32) NULL DEFAULT NULL COMMENT '真实姓名',
-- `create_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
-- `floor` INT(11) NULL DEFAULT NULL COMMENT '楼层,主帖算1楼',
-- `support_count` INT(10) NULL DEFAULT NULL COMMENT '支持数',
-- `oppose_count` INT(10) NULL DEFAULT NULL COMMENT '反对数',
-- `parent_id` INT(11) NOT NULL COMMENT '回复帖子id 回复哪个帖子',
-- `ancestor_id` INT(10) NOT NULL COMMENT '祖先帖子id',
-- PRIMARY KEY (`id`)
-- )
-- COMMENT='回帖表'
-- COLLATE='utf8_general_ci'
local function convertPost(post)
    local t = {
        ID = post.id,
        BBS_ID = post.bbsId,
        FORUM_ID = post.forumId,
        TOPIC_ID = post.topicId,
        TITLE = ngx.quote_sql_str(post.title),
        CONTENT = ngx.quote_sql_str(post.content),
        PERSON_ID = post.personId,
        PERSON_NAME = ngx.quote_sql_str(post.personName),
        CREATE_TIME = "now()",
        FLOOR = post.floor,
        SUPPORT_COUNT = post.supportCount,
        OPPOSE_COUNT = post.opposeCount,
        PARENT_ID = post.parentId,
        ANCESTOR_ID = post.ancestorId
    }
    util:logData("保存回帖信息数据Table:");
    util:logData(t)
    return t;
end

--------------------------------------------------------------------------------
-- 保存回帖信息
-- @param #table post
-- @return #result 影响行数
function BbsPostService:savePost(post)
    if post == nil or TableUtil:length(post) == 0 then
        error("post is null");
    end
    local tempPost = convertPost(post)
    local column = {}
    local fileds = {}
    for key, var in pairs(tempPost) do
        if tempPost[key] then
            addTable(tempPost, key, column, fileds)
        end
    end
    local sql = splitAddSql(column, fileds, "T_SOCIAL_BBS_POST")
    util:logData("保存回帖信息sql:" .. sql);
    local result = DBUtil:querySingleSql(sql);
    --topicid,lastPostId,replyerPersonId,replyerIdentityId
    local topicid = post.topicId;

    local lastPostId = post.id;

    local replyerPersonId = post.personId

    local replyerIdentityId = post.identityId

    BbsTopicService:updateTopicToDb(topicid, lastPostId, replyerPersonId, replyerIdentityId) --更新主题表的回复信息到数据库.

    return result
end

--------------------------------------------------------------------------------
-- 获取主键
function BbsPostService:getPostPkId()
    local db = SsdbUtil:getDb();
    local postid = db:incr("social_bbs_post_pk")[1] --生成主键id.
    SsdbUtil:keepalive(db)
    return postid
end

--------------------------------------------------------------------------------
--
-- 保存回帖信息(ssdb)
-- @param #table post
-- @return #result 影响行数
function BbsPostService:savePostToSsdb(post)
    if post == nil or TableUtil:length(post) == 0 then
        error("post is null");
    end
    if post.topicId == nil or string.len(post.topicId) == 0 then
        error("topic id is null");
    end
    local key = "social_bbs_topicid_" .. post.topicId .. "_postid_" .. post.id
    db = SsdbUtil:getDb();
    db:multi_hset(key, post)
    local postids_t, err = db:hget("social_bbs_forum_topic_include_post", "topic_id_" .. post.topicId)
    local postids = ""
    if postids_t and string.len(postids_t[1]) > 0 then
        postids = postids_t[1] .. "," .. post.id
    else
        postids = post.id
    end
    db:hset("social_bbs_forum_topic_include_post", "topic_id_" .. post.topicId, postids)
    --保存主题帖信息.
    SsdbUtil:keepalive(db)

    local topicid = post.topicId;

    local lastPostId = post.id;

    local replyerPersonId = post.personId

    local replyerIdentityId = post.identityId

    BbsTopicService:updateTopicToSsdb(topicid, lastPostId, replyerPersonId, replyerIdentityId) --更新主题表的回复信息.
end

--------------------------------------------------------------------------------
local function getPostSphinxData(bbsid, forumid, topicid, pagenum, pagesize)
    local offset = pagesize * pagenum - pagesize
    local limit = pagesize
    local str_maxmatches = "10000"
    local db = DBUtil:getDb();
    local sql = "SELECT SQL_NO_CACHE id FROM T_SOCIAL_BBS_POST_SPHINXSE WHERE query='%s;%s;%s;filter=b_delete,0;sort=attr_desc:ts;maxmatches=" .. str_maxmatches .. ";offset=" .. offset .. ";limit=" .. limit .. "';SHOW ENGINE SPHINX  STATUS;"
    local bbsidFilter = "filter=bbs_id," .. bbsid
    local forumidFilter = "filter=forum_id," .. forumid
    local topicidFilter = "filter=topic_id," .. topicid
    sql = string.format(sql, bbsidFilter, forumidFilter, topicidFilter);
    util:logData("sql :" .. sql)
    local res = db:query(sql)
    --去第二个结果集中的Status中截取总个数
    local res1 = db:read_result()
    util:logData(res1)
    local _, s_str = string.find(res1[1]["Status"], "found: ")
    local e_str = string.find(res1[1]["Status"], ", time:")
    local totalRow = string.sub(res1[1]["Status"], s_str + 1, e_str - 1)
    local totalPage = math.floor((totalRow + pagesize - 1) / pagesize)
    return res, totalRow, totalPage
end

--
--
--分页获取回复帖
--@param #string bbsid
--@param #string forumid
--@param #string topicid 主帖id
--@param #string pagenum 页.
--@param #string pagesize 每页显示条数.
--@result #table  {list=list,totalRow=totalRow,totalPage=totalPage}
function BbsPostService:getPostsFromDb(bbsid, forumid, topicid, pagenum, pagesize)
    if bbsid == nil or string.len(bbsid) == 0 then
        error("bbs id 不能为空");
    end
    if forumid == nil or string.len(forumid) == 0 then
        error("forum id 不能为空");
    end
    if topicid == nil or string.len(topicid) == 0 then
        error("topic id 不能为空");
    end

    if pagenum == nil or string.len(pagenum) == 0 then
        error("pagenum  不能为空");
    end
    if pagesize == nil or string.len(pagesize) == 0 then
        error("pagesize  不能为空");
    end

    --    {
    --        "success":true
    --        "forum_name" :版块名称.
    --        "title"：主题帖标题
    --        "content":主题帖内容
    --        "person_id":发帖人id 可通过后台获取(登录人)
    --        "person_name":发帖人姓名.
    --        "create_time":发帖时间.
    --        "b_reply":是否允许回复.(如果为0允许回复，1不允许回复，如果为1不reply_list为空
    --        "pageNumber": 1,
    --        "totalPage": 总页数,
    --        "totalRow":总记录数,
    --        "pageSize":每页条数,
    --        "view_count":查看次数,
    --        "reply_count":回复次数,
    --        "reply_list":[
    --            {"id":
    --            "content":回帖内容,
    --            "person_name":回帖人姓名.,
    --            "person_id":发帖人id 可通过后台获取(登录人),
    --            "floor":楼层,
    --            "create_time":回帖时间},
    --        ]
    --    }
    local db = SsdbUtil:getDb()
    local topic_keys = { "forumName", "title", "content", "personId", "personName", "createTime", "bReply", "viewCount", "replyCount" }
    local topic_key = "social_bbs_topicid_" .. topicid
    local topicResult = db:multi_hget(topic_key, unpack(topic_keys))
    local topic = {}
    if topicResult and #topicResult > 0 then
        local _topic = util:multi_hget(topicResult, topic_keys)
        topic.forum_name = _topic.forumName;
        topic.title = _topic.title;
        topic.content = _topic.content;
        topic.person_id = _topic.personId;
        topic.person_name = _topic.personName
        topic.createTime = _topic.createTime;
        topic.b_reply = _topic.bReply;
        topic.view_count = _topic.viewCount;
        topic.reply_count = _topic.replyCount;
        local forumResult = db:multi_hget("social_bbs_forum_" .. forumid, "name")
        if forumResult and #forumResult > 0 then
            topic.forum_name = forumResult[2]
        end
        topic.reply_list = {}
        local res, totalRow, totalPage = getPostSphinxData(bbsid, forumid, topicid, pagenum, pagesize);
        if res then
            for i = 1, #res do
                local key = "social_bbs_topicid_" .. topicid .. "_postid_" .. res[i]["id"]
                local keys = { "id", "content", "personId", "personName", "createTime", "floor" }
                local _result = db:multi_hget(key, unpack(keys))

                util:logData("从ssdb中取出的数据")
                util:logData(_result);
                if _result and #_result > 0 then
                    local _post = util:multi_hget(_result, keys)
                    util:logData("转换后的数据")
                    util:logData(_post);
                    local t = {}
                    t.id = _post.id
                    t.category_name = _post.content
                    t.person_id = _post.personId;
                    t.person_name = _post.personName
                    t.create_time = _post.createTime;
                    t.floor = _post.floor;
                    table.insert(topic.reply_list, t)
                end
            end
        end
    end
    return topic;
end

return BbsPostService;
