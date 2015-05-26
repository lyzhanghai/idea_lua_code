--
--    张海  2015-05-06
--    描述：  BBS bbsctrl 此下的controller受权限控制.
--
ngx.header.content_type = "text/plain";
local web = require("social.router.web")
local util = require("social.common.util")
local cjson = require "cjson"
local request = require("social.common.request");
local log = require("social.common.log")
local context = ngx.var.path_uri

--- -
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
    log.debug("topicSave start");
    local service = getService("BbsTopicService")
    local BbsService = getService("BbsService")
    local bbsid = request:getStrParam("bbs_id", true, true)
    local forumid = request:getStrParam("forum_id", true, true)
    local categoryid = request:getStrParam("category_id", true, true)
    local identityid = request:getStrParam("identity_id", true, true)

    local title = request:getStrParam("title", true, true)
    local personid = request:getStrParam("person_id", true, true)
    local breply = request:getStrParam("b_reply", true, true)
    local btop = request:getStrParam("b_top", false, false)
    local bbest = request:getStrParam("b_best", false, false)
    if btop==nil or string.len(btop)==0 then
        btop =0;
    end
    if bbest==nil or string.len(bbest)==0 then
        bbest =0;
    end
    local content = request:getStrParam("content", true, false)
    local personName = request:getStrParam("person_name", true, true)
    log.debug("personName:" .. personName);
    local rr = {}
    rr.success = false
    local topic = {}
    topic.bbsId = bbsid;
    topic.forumId = forumid;
    topic.categoryId = categoryid;
    topic.title = title;
    topic.personId = personid;
    topic.bReply = breply;
    topic.bTop = btop;
    topic.bBest = bbest;
    topic.content = content;
    topic.personName = personName;
    topic.identityId = identityid;
    local topicid = service:getTopicPkId()
    topic.id = topicid;
    local results, err, errno, sqlstate = service:saveTopic(topic); --保存到数据库
    if not results then
        ngx.log(ngx.ERR, "bad result: ", err, ": ", errno, ": ", sqlstate, ".");
        rr.info = { name = "", data = "添加数据库出错." }
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
    totalService:addTopicTotalNumber(bbsid)

    BbsService:updatePostForumToDb(forumid, topicid)
    BbsService:updatePostForumToSsdb(forumid, topicid)
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
local function checkUser()
    local service = getService("BbsService")
    local identityid = request:getStrParam("identity_id", true, true)
    local personname = request:getStrParam("person_name", true, true)
    local bbsid = request:getStrParam("bbs_id", true, true)
    --local flag = request:getStrParam("flag", true, true)
    local personid = request:getStrParam("person_id", true, true)
    local forumid = request:getStrParam("forum_id", true, true)
    local r = {}
    r.success = false
    local forumUser = service:getForumnUserByPersonId(personid, forumid, identityid, bbsid)
    log.debug("identityid :" .. identityid .. " personid:" .. personid .. " forumid:" .. forumid)
    if not forumUser or #forumUser == 0 then --如果不存在此记录。
        log.debug("数据库中不存在记录.")
        local result = service:checkForumUser(personid, identityid, bbsid)
        log.debug(result)
        if result then
            service:saveForumUser(forumid, personid, identityid, personname, 0)
            r.success = true;
            r.info = "成功"
        else
            r.success = false;
            r.exists = false --证明不存在
            r.info = { name = "", data = "不可发帖,权限不足。" }
        end
    else
        log.debug("数据库中存在记录.")
        if forumUser[1]["flag"] == 2 then
            r.success = false
            r.exists = true --证明存在
            r.info = { name = "", data = "您已经申请过了。" }
        else
            r.success = true;
            r.flag = forumUser[1]["flag"];
            r.info = "成功"
        end
    end
    ngx.print(cjson.encode(r))
end

--------------------------------------------------------------------------------
-- 发帖前，先验证用户信息与权限
-- @param #string forum_id
-- @param #string person_id
-- @param #string identity_id
-- @param #string person_name
-- @param #string bbs_id
local function forumUserAdd()
    local service = getService("BbsService")
    local identityid = request:getStrParam("identity_id", true, true)
    local personname = request:getStrParam("person_name", true, true)
    --local flag = request:getStrParam("flag", true, true)
    local personid = request:getStrParam("person_id", true, true)
    local forumid = request:getStrParam("forum_id", true, true)
    local r = {}
    r.success = false
    local forumUser = service:getForumnUserByPersonId(personid, forumid, identityid)
    log.debug("identityid :" .. identityid .. " personid:" .. personid .. " forumid:" .. forumid)
    if not forumUser or #forumUser == 0 then --如果不存在此记录。
        log.debug("数据库中不存在记录.")
        service:saveForumUser(forumid, personid, identityid, personname, 2)
    end
    r.success = true;
    r.info = "成功"
    ngx.print(cjson.encode(r))
end

--------------------------------------------------------------------------------
-- 回复帖信息保存.1
-- @param #string
-- @param #string topic_id 主题帖id.
-- @param #string title 标题
-- @param #string content 回复内容,
-- @param #string bbs_id 论坛id.
-- @param #string forum_id 版块id.
-- @param #string person_id 回复人id.
-- @param #string person_name 回复人姓名.
-- @param #string identity_id 回复人身份id.
-- @param #string parent_id,回复帖子id 回复哪个帖子(不填认为是对主题回复)
-- @param #string ancestor_id 祖先帖子id
local function postSave()
    local service = getService("BbsPostService")
    local BbsService = getService("BbsService")
    local topicId = request:getStrParam("topic_id", true, true)
    local title = request:getStrParam("title", true, true)
    local content = request:getStrParam("content", true, false)
    local bbsId = request:getStrParam("bbs_id", true, true)
    local forumId = request:getStrParam("forum_id", true, true)
    local personId = request:getStrParam("person_id", true, true)
    local personName = request:getStrParam("person_name", true, true)
    local identityId = request:getStrParam("identity_id", true, true)
    local parentId = request:getStrParam("parent_id", false, true)
    local ancestorId = request:getStrParam("ancestor_id", false, true)
    local pageSize = request:getStrParam("pageSize", true, true)
    local r = {}
    r.success = false
    local post = {}
    post.topicId = topicId
    post.title = title
    post.content = content
    post.bbsId = bbsId
    post.forumId = forumId
    post.personId = personId
    post.personName = personName
    post.identityId = identityId
    post.parentId = parentId
    post.ancestorId = ancestorId
    local postid = service:getPostPkId();
    post.id = postid

    local status, err = pcall(function()
        service:savePost(post)
    end)
    if not status then
        local err1 = { name = "", data = "保存失败" }
        error(err1, 1)
    end
    service:savePostToSsdb(post)
    r.success = true
    r.id = postid
    local count = service:getPostCount(topicId)
    --------------------------------
    ---- 计算最后一页.
    local _pagesize = tonumber(pageSize)
    local totalRow = count
    local totalPage = math.floor((totalRow + _pagesize - 1) / _pagesize)
    r.pagenum = totalPage;
    --------------------------------
    -- 对回复帖次数+1
    local totalService = getService("BbsTotalService")
    totalService:addForumPostCurrentDateNum(bbsId, forumId)
    totalService:addPostNumber(bbsId) --对此论坛的总帖数+1

    BbsService:updatePostForumToDb(forumId, postid)
    BbsService:updatePostForumToSsdb(forumId, postid)

    log.debug(cjson.encode(r))
    ngx.say(cjson.encode(r))
end

----- 设置主题帖置顶
-- @param #string topic_id
local function setTop()
    local topicId = request:getStrParam("topic_id", true, true)
    local service = getService("BbsTopicService")
    local result = service:setTopByIdToDb(topicId, false)
    service:setTopByIdToSsDb(topicId, false)
    local r = {}
    r.success = false
    if result then
        r.success = true
        r.info = { name = "", data = "成功" }
    else
        r.info = { name = "", data = "失败" }
    end
    ngx.say(cjson.encode(r))
end

----- 取消主题帖置顶
-- @param #string topic_id
local function cancelTop()
    local topicId = request:getStrParam("topic_id", true, true)
    local service = getService("BbsTopicService")
    local result = service:setTopByIdToDb(topicId, true)
    service:setTopByIdToSsDb(topicId, true)
    local r = {}
    r.success = false
    if result then
        r.success = true
        r.info = { name = "", data = "成功" }
    else
        r.info = { name = "", data = "失败" }
    end
    ngx.say(cjson.encode(r))
end

----- 设置主题帖精华
-- @param #string topic_id
-- @param #string value
local function setBest()
    local topicId = request:getStrParam("topic_id", true, true)
    local value = request:getStrParam("value", true, true)
    local r = {}
    local service = getService("BbsTopicService")
    local result = service:setBestByIdToDb(topicId, value)
    service:setBestByIdToSsDb(topicId, value)
    r.success = false
    if result then
        r.success = true
        r.info = { name = "", data = "成功" }
    else
        r.info = { name = "", data = "失败" }
    end
    ngx.say(cjson.encode(r))
end


local function delTopic()
    local topicId = request:getStrParam("topic_id", true, true)
    local service = getService("BbsTopicService")
    local db_status = service:deletTopicByIdToDb(topicId)
    local ssdb_status = service:deletTopicByIdToSsDb(topicId)
    local r = { success = false, info = { name = "", data = "成功" } }
    log.debug("db_status: "..tostring(db_status));
    log.debug("ssdb_status:"..tostring(ssdb_status));
    if db_status and ssdb_status then
        r.success = true;
        ngx.say(cjson.encode(r))
        return;
    end
    ngx.say(cjson.encode(r))
end

local function delPost()
    local postId = request:getStrParam("post_id", true, true)
    local topicId = request:getStrParam("topic_id", true, true)
    local service = getService("BbsPostService")
    local db_status = service:deletPostByIdToDb(postId)
    local sdb_status = service:deletPostByIdToSsDb(topicId, postId)
    local r = { success = false, info = { name = "", data = "成功" } }
    if db_status and sdb_status then
        r.success = true;
        ngx.say(cjson.encode(r))
        return;
    end
    ngx.say(cjson.encode(r))

end

ngx.log(ngx.ERR, "context:=========================" .. context)
--按功能分
local urls = {
    context .. '/topic/checkUser', checkUser,
    context .. '/topic/save', topicSave,
    context .. '/post/save', postSave,
    context .. '/forumuser/add', forumUserAdd,
    context .. '/topic/settop', setTop,
    context .. '/topic/canceltop', cancelTop,
    context .. '/topic/setbest', setBest,
    context .. '/topic/delete', delTopic,
    context .. '/post/delete', delPost,
}
local app = web.application(urls, nil)
app:start()

