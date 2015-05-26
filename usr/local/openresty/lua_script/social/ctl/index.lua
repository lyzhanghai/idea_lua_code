ngx.header.content_type = "text/plain";
local web = require("social.router.web")
local util = require("social.common.util")
local cjson = require "cjson"
local context = ngx.var.path_uri

--- -
-- sphinx 端口
-- 3335 topic
-- 3336 post

--get args
local getArgs = function()
    local request_method = ngx.var.request_method
    local args, err
    if request_method == "GET" then
        args, err = ngx.req.get_uri_args()
    else
        ngx.req.read_body()
        args, err = ngx.req.get_post_args()
    end
    return args
end

--获取service
--@param string name
--@return table service
local function getService(name)
    local service_path = "social.service";
    return require(service_path .. "." .. name)
end

--获取区列表
local function index()
    local args = getArgs()
    local bbsid = args['bbs_id']
    local service = getService("BbsService")
    local resResult = service:getBbsById(bbsid)
    if resResult then
        resResult.success = true
    else
        resResult = {}
        resResult.success = false
        resResult.info = "没有论坛数据."
    end
    util:logData(resResult);
    ngx.print(cjson.encode(resResult))
end

--获取版块列表
local function getForums()
    local args = getArgs()
    local bbsid = args['bbs_id']
    local partitionid = args['partition_id']
    local service = getService("BbsService")
    local result = service:getForums(bbsid, partitionid)
    util:logData(result);
    ngx.print(cjson.encode(result))
end


local function checkParam(args, names)
    for _, name in pairs(names) do
        local _value = args[name];
        if _value == nil or string.len(_value) == 0 then
            error(name .. "不能为空.")
        end
    end
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
    util:logData("topicList start");
    local args = getArgs()
    --做sphinx操作，才能实现列表
    local service = getService("BbsTopicService")
    local args = getArgs()
    local bbsid = args["bbs_id"]
    local forumid = args["forum_id"]
    local categoryid = args["category_id"]
    local pageNumber = args["pageNumber"]
    local pageSize = args["pageSize"]
    local filterDate = args["filterDate"];
    local sortType = args["sortType"];
    local rr = {}
    rr.success = false
    local status, errormsg = pcall(checkParam, args, { "bbs_id", "forum_id", "category_id" })
    util:logData(status);
    if not status then
        rr.info = errormsg
        ngx.say(cjson.encode(rr))
        return;
    end
    local result = service:getTopicsFromSsdb(bbsid, forumid, categoryid, nil, filterDate, sortType, pageNumber, pageSize)
    if result then
        cjson.encode_empty_table_as_object(false)
        result.success = true;
        ngx.say(cjson.encode(result))
    else
        result.success = false;
        result.info = "请求失败"
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
    util:logData("topicSearchList start");
    local args = getArgs()
    --做sphinx操作，才能实现列表
    local service = getService("BbsTopicService")
    local args = getArgs()
    local bbsid = args["bbs_id"]
    local forumid = args["forum_id"]
    local pageNumber = args["pageNumber"]
    local pageSize = args["pageSize"]
    local searchText = args["searchText"]
    local rr = {}
    rr.success = false
    local status, errormsg = pcall(checkParam, args, { "bbs_id", "forum_id" })
    util:logData(status);
    if not status then
        rr.info = errormsg
        ngx.say(cjson.encode(rr))
        return;
    end
    local result = service:getTopicsFromSsdb(bbsid, forumid, nil, searchText, nil, nil, pageNumber, pageSize)
    if result then
        cjson.encode_empty_table_as_object(false)
        result.success = true;
        ngx.say(cjson.encode(result))
    else
        result.success = false;
        result.info = "请求失败"
        ngx.say(cjson.encode(result))
    end
    return;
end

--------------------------------------------------------------------------------
-- 主题帖保存.1
-- @param #string bbs_id：论坛id
-- @param #string forum_id: 版块id
-- @param #string category_id:分类id
-- @param #string title :     标题,
-- @param #string person_id:发帖人id 可通过后台获取(登录人)
-- @param #string b_reply:是否允许回复.
-- @param #string b_best:是否精华
-- @param #string b_top:是否置顶.
-- @param #string content:主题帖内容
local function topicSave()
    util:logData("topicSave start");
    local service = getService("BbsTopicService")
    local args = getArgs()
    local bbsid = args["bbs_id"]
    local forumid = args["forum_id"]
    local categoryid = args["category_id"]
    local title = args["title"]
    local personid = args["person_id"]
    local breply = args["b_reply"]
    local btop = args["b_top"]
    local content = args["content"]
    local personName = args["person_name"]
    util:logData("personName:" .. personName);
    local rr = {}
    rr.success = false
    local status, errormsg = pcall(checkParam, args, { "bbs_id", "forum_id", "category_id", "title", "person_id", "b_reply", "b_top", "content", "person_name" })
    util:logData(status);
    if not status then
        rr.info = errormsg
        ngx.say(cjson.encode(rr))
        return;
    end

    local topic = {}
    topic.bbsId = bbsid;
    topic.forumId = forumid;
    topic.categoryId = categoryid;
    topic.title = title;
    topic.personId = personid;
    topic.bReply = breply;
    topic.bTop = btop;
    topic.content = content;
    topic.personName = personName
    local topicid = service:getTopicPkId()
    topic.id = topicid;
    local results, err, errno, sqlstate = service:saveTopic(topic); --保存到数据库
    if not results then
        ngx.log(ngx.ERR, "bad result: ", err, ": ", errno, ": ", sqlstate, ".");
        rr.info("添加数据库出错.")
        ngx.say(cjson.encode(rr));
        return;
    end
    --local id = results.insert_id;
    service:saveTopicToSsdb(topic) -- 保存到ssdb
    ----------------------------------
    -- 对今天主题帖数+1
    local totalService = getService("BbsTotalService")
    totalService:addForumTopicCurrentDateNumber(bbsid, forumid)
    totalService:addPostNumber(bbsid) --对此论坛的总帖数+1
    rr.id = topic.id;
    rr.success = true
    ngx.print(cjson.encode(rr))
end

--------------------------------------------------------------------------------
-- 主题帖保存POST方式
-- 发帖前，先验证用户信息与权限
-- @param #string forum_id
-- @param #string person_id
-- @param #string identity_id
-- @param #string person_name
-- @param #string flag
-- @param #string bbs_id
local function checkUser()
    local args = getArgs()
    local service = getService("BbsService")
    local bbsid = args["bbs_id"]
    local personid = args["person_id"]
    local personname = args["person_name"]
    local identityid = args["identity_id"]
    local flag = args["flag"]
    local forumid = args["forum_id"]

    local r = {}
    r.success = false
    local status, errormsg = pcall(checkParam, args, { "bbs_id", "person_id", "person_name", "identity_id", "flag", "forum_id" })
    if not status then
        r.info = errormsg
        ngx.say(cjson.encode(r))
        return;
    end


    local result = service:checkForumUser(bbsid)
    if result then
        service:saveForumUser(forumid, personid, identityid, personname, flag)
        r.success = true;
        r.info = "成功"
    else
        r.success = false;
        r.info = "不可发帖"
    end
    ngx.print(cjson.encode(r))
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
    local args = getArgs()
    local service = getService("BbsPostService")
    local topicService = getService("BbsTopicService")
    local topicid = args["topic_id"]
    local bbsid = args["bbs_id"]
    local forumid = args["forum_id"]

    local pageNumber = args["pageNumber"]
    local pageSize = args["pageSize"]
    local r = {}
    r.success = false
    local status, errormsg = pcall(checkParam, args, { "topic_id", "bbs_id", "forum_id", "pageNumber", "pageSize" })
    if not status then
        r.info = errormsg
        ngx.say(cjson.encode(r))
    end
    r = service:getPostsFromDb(bbsid, forumid, topicid, pageNumber, pageSize)
    util:logData(r);
    topicService:updateTopicViewCountToDb(topicid)
    topicService:updateTopicViewCountToSsdb(topicid)
    cjson.encode_empty_table_as_object(false)
    if r then
        r.success = true
        ngx.say(cjson.encode(r))
    else
        r.success = false;
        r.info = "请求失败"
        ngx.say(cjson.encode(r))
    end
end

--------------------------------------------------------------------------------
-- 回复帖信息保存.1
-- @param #string
-- topic_id 主题帖id.
-- title 标题
-- content 回复内容,
-- bbs_id 论坛id.
-- forum_id 版块id.
-- person_id 回复人id.
-- person_name 回复人姓名.
-- identity_id 回复人身份id.
-- parent_id,回复帖子id 回复哪个帖子(不填认为是对主题回复)
-- ancestor_id 祖先帖子id
--
local function postSave()
    local args = getArgs()
    local service = getService("BbsPostService")
    local topicId = args["topic_id"]
    local title = args["title"]
    local content = args["content"]
    local bbsId = args["bbs_id"]
    local forumId = args["forum_id"]
    local personId = args["person_id"]
    local personName = args["person_name"]
    local identityId = args["identity_id"]
    local parentId = args["parent_id"]
    local ancestorId = args["ancestor_id"]
    local r = {}
    r.success = false
    local status, errormsg = pcall(checkParam, args, { "topic_id", "title", "content", "bbs_id", "forum_id", "person_id", "person_name", "identity_id", "parent_id", "ancestor_id" })
    if not status then
        r.info = errormsg
        ngx.say(cjson.encode(r))
        return;
    end
    local post = {}
    post.topicId = topicId
    post.title = title
    post.content = content
    post.bbsiId = bbsId
    post.forumId = forumId
    post.personId = personId
    post.personName = personName
    post.identityId = identityId
    post.parentId = parentId
    post.ancestorId = ancestorId
    local postid = service:getPostPkId();
    post.id = postid
    local result = service:savePost(post)
    if result then
        service:savePostToSsdb(post)
        r.success = true
    end
    --------------------------------
    -- 对回复帖次数+1
    local totalService = getService("BbsTotalService")
    totalService:addForumPostCurrentDateNum(bbsId, forumId)
    totalService:addPostNumber(bbsId) --对此论坛的总帖数+1
    ngx.say(cjson.encode(r))
end

--按功能分
local urls = {
    context .. '/$', index,
    context .. '/getForums$', getForums,
    context .. '/topic/list', topicList,
    context .. '/topic/search', topicSearchList,
    context .. '/topic/checkUser', checkUser,
    context .. '/topic/save', topicSave,
    context .. '/topic/view', topicView,
    context .. '/post/save', postSave,
}
local app = web.application(urls, nil)
app:run()

