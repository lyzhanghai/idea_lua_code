local SsdbUtil = require("social.common.ssdbutil")
local util = require("social.common.util")
local M = {}
local BbsTotalService = M

--------------------------------------------------------------------------------
--设置此模块今日主题帖数.
--@param #string bbsid bbsid
--@param #string forumid forumid
function M:addForumTopicCurrentDateNumber(bbsid,forumid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    if forumid==nil or string.len(forumid)==0 then
        error("forumid 不能为空.")
    end
    local currentDate = os.date("%Y%m%d")
    local today_key ="social_bbs_%s_forum_%s_today_%s_topicnumber";
    local history_key ="social_bbs_%s_forum_%s_history_topicnumber";--总
    today_key = string.format(today_key,bbsid,forumid,currentDate);
    util:logData("设置此模块今日主帖数：key:"..today_key)
    
    local db = SsdbUtil:getDb();
    local isTodayExists = db:exists(today_key);
    local isHistoryExists = db:exists(history_key);
    if isTodayExists then-----------------今天主题帖数加1
        db:incr(today_key, 1);
    else
        db:set(today_key,1)
    end
    if isHistoryExists then-----------------总主题帖数加1
        db:incr(history_key, 1);
    else
        db:set(history_key,1)
    end
    -------------------------------------------------------
    --删除前天的数据.
    local b_yesterday = util:day_step(tostring(currentDate),-2);
    local b_yesterday_key = string.format(today_key,bbsid,forumid,b_yesterday);--前天的key
    util:logData("设置此模块前天主帖数：key:"..b_yesterday_key)
    local db = SsdbUtil:getDb();
    local isBYesterdayExists = db:exists(b_yesterday_key);
    if isBYesterdayExists then
        db:del(b_yesterday_key);--删除前天的数据.
    end
    SsdbUtil:keepalive(db)
end
--获取此模块总主题帖数.
--@param #string bbsid bbsid
--@param #string forumid forumid
function M:getForumTopicHistoryNumber(bbsid,forumid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    if forumid==nil or string.len(forumid)==0 then
        error("forumid 不能为空.")
    end
    local history_key ="social_bbs_%s_forum_%s_history_topicnumber"
    history_key = string.format(history_key,bbsid,forumid);
    util:logData("获取此模块总主帖数：history_key:"..history_key)
    local db = SsdbUtil:getDb();
    local count = db:get(history_key)
    local number = 0;
    if count and count[1] and string.len(count[1])>0 then
        number = tonumber(count[1]);
    else
        number=0;
    end
    SsdbUtil:keepalive(db)
    return number;
end

--获取此模块今天主题帖数.
--@param #string bbsid bbsid
--@param #string forumid forumid
function M:getForumTopicCurrentDateNumber(bbsid,forumid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    if forumid==nil or string.len(forumid)==0 then
        error("forumid 不能为空.")
    end
    local currentDate =  tostring(os.date("%Y%m%d"))
    local key ="social_bbs_%s_forum_%s_today_%s_topicnumber";
    key = string.format(key,bbsid,forumid,currentDate);
    util:logData("获取此模块今天主帖数：key:"..key)
    local db = SsdbUtil:getDb();
    local count = db:get(key)
    local number = 0;
    if count and count[1] and string.len(count[1])>0 then
        number = tonumber(count[1]);
    else
        number=0;
    end
    SsdbUtil:keepalive(db)
    return number;
end
--获取此模块昨天主题帖数.
--@param #string bbsid bbsid
--@param #string forumid forumid
function M:getForumTopicYestdayNumber(bbsid,forumid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    if forumid==nil or string.len(forumid)==0 then
        error("forumid 不能为空.")
    end
    local yestoday = util:day_step(tostring(os.date("%Y%m%d")),-1)
    local key ="social_bbs_%s_forum_%s_today_%s_topicnumber";
    key = string.format(key,bbsid,forumid,yestoday);
    util:logData("获取此模块昨天天主帖数：key:"..key)
    local db = SsdbUtil:getDb();
    local count = db:get(key)
    local number = 0;
    if count and count[1] and string.len(count[1])>0 then
        number = tonumber(count[1]);
    else
        number=0;
    end
    SsdbUtil:keepalive(db)
    return number;
end















--------------------------------------------------------------------------------
--设置今天的回帖数.
function M:addForumPostCurrentDateNum(bbsid,forumid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    if forumid==nil or string.len(forumid)==0 then
        error("forumid 不能为空.")
    end
    local currentDate =  tostring(os.date("%Y%m%d"))
    local key ="social_bbs_%s_forum_%s_today_%s_postnumber";
    local history_key ="social_bbs_%s_forum_%s_history_postnumber";--总
    key = string.format(key,bbsid,forumid,currentDate);
    util:logData("设置此模块今日回帖数：key:"..key)
    local db = SsdbUtil:getDb();
    local isTodayExists = db:exists(key);
    local isHistoryExists = db:exists(key);
    if isTodayExists then-----------------今天回帖数加1
        db:incr(key, 1);
    else
        db:set(key,1)
    end
    if isHistoryExists then-----------------总回帖数加1
        db:incr(history_key, 1);
    else
        db:set(history_key,1)
    end
    SsdbUtil:keepalive(db)
end
--------------------------------------------------------------------------------
--获取当天回帖数
function M:getForumPostCurrentDateNum(bbsid,forumid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    if forumid==nil or string.len(forumid)==0 then
        error("forumid 不能为空.")
    end
    local currentDate = tostring(os.date("%Y%m%d"))
    local key ="social_bbs_%s_forum_%s_today_%s_postnumber";
    key = string.format(key,bbsid,forumid,currentDate);
    util:logData("设置此模块今日回帖数：key:"..key)
    local db = SsdbUtil:getDb();
    local count = db:get(key)
    local number = 0;
    if count and count[1] and string.len(count[1])>0 then
        number = tonumber(count[1]);
    else
        number=0;
    end
    SsdbUtil:keepalive(db)
    return number;
end
--------------------------------------------------------------------------------
--获取历史回帖数
function M:getForumPostHistoryNum(bbsid,forumid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    if forumid==nil or string.len(forumid)==0 then
        error("forumid 不能为空.")
    end
    local history_key ="social_bbs_%s_forum_%s_history_postnumber"
    history_key = string.format(history_key,bbsid,forumid);
    util:logData("设置此模块今日回帖数：key:"..history_key)
    local db = SsdbUtil:getDb();
    local count = db:get(history_key)
    local number = 0;
    if count and count[1] and string.len(count[1])>0 then
        number = tonumber(count[1]);
    else
        number=0;
    end
    SsdbUtil:keepalive(db)
    return number;
end

--------------------------------------------------------------------------------
--获取昨天回帖数
function M:getForumPostHistoryNum(bbsid,forumid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    if forumid==nil or string.len(forumid)==0 then
        error("forumid 不能为空.")
    end
    local yestoday = util:day_step(tostring(os.date("%Y%m%d")),-1)--计算昨天时间
    local key ="social_bbs_%s_forum_%s_today_%s_postnumber";--可以用今天的key
    key = string.format(key,bbsid,forumid,yestoday);
    util:logData("设置此模块今日回帖数：key:"..key)
    local db = SsdbUtil:getDb();
    local count = db:get(key)
    local number = 0;
    if count and count[1] and string.len(count[1])>0 then
        number = tonumber(count[1]);
    else
        number=0;
    end
    SsdbUtil:keepalive(db)
    return number;
end







--------------------------------------------------------------------------------
--设置此bbs论坛的今日总贴数
function M:addPostNumber(bbsid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    local currentDate = tostring(os.date("%Y%m%d"))
    local key = "social_bbs_%s_totay_%s_total"
    key = string.format(key,bbsid,currentDate);
    local history_key = "social_bbs_%s_history_total"
    util:logData("添加总帖数key:"..key)
    util:logData("添加历史总帖数key:"..key)
    local db = SsdbUtil:getDb();
    local isTodayExists = db:exists(key);
    if isTodayExists then
        db:incr(key, 1);
    else
        db:set(key,1)
    end
    local isHistoryExists = db:exists(history_key);
    if isHistoryExists then
        db:incr(history_key, 1);
    else
        db:set(history_key,1)
    end
    -------------------------------------------------------
    --删除前天的数据.
    local b_yesterday = util:day_step(currentDate,-2);
    local b_yesterday_key = string.format(key,bbsid,b_yesterday);--前天的key
    util:logData("设置此论坛前天总帖数：key:"..b_yesterday_key)
    local db = SsdbUtil:getDb();
    local isBYesterdayExists = db:exists(b_yesterday_key);
    if isBYesterdayExists then
        db:del(b_yesterday_key);--删除前天的数据.
    end
    SsdbUtil:keepalive(db)
end


--------------------------------------------------------------------------------
--获取此bbs论坛的今天总贴数
function M:getCurrentDatePostTotal(bbsid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    local currentDate = tostring(os.date("%Y%m%d"))
    local key = "social_bbs_%s_totay_%s_total"
    key = string.format(key,bbsid,currentDate);
    util:logData("获取此论坛今日帖数：key:"..key)
    local db = SsdbUtil:getDb();
    local count = db:get(key)
    local number = 0;
    if count and count[1] and string.len(count[1])>0 then
        number = tonumber(count[1]);
    else
        number=0;
    end
    SsdbUtil:keepalive(db)
    return number;
end
--------------------------------------------------------------------------------
--获取此bbs论坛的昨天总贴数
function M:getYestoryPostTotal(bbsid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    local yestoday = util:day_step(tostring(os.date("%Y%m%d")),-1)
    local key = "social_bbs_%s_totay_%s_total"
    key = string.format(key,bbsid,yestoday);
    util:logData("获取此论坛今日帖数：key:"..key)
    local db = SsdbUtil:getDb();
    local count = db:get(key)
    local number = 0;
    if count and count[1] and string.len(count[1])>0 then
        number = tonumber(count[1]);
    else
        number=0;
    end
    SsdbUtil:keepalive(db)
    return number;
end


--------------------------------------------------------------------------------
--获取此bbs论坛的历史总贴数
function M:getHistoryPostTotal(bbsid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    local history_key = "social_bbs_%s_history_total"
    history_key = string.format(history_key,bbsid);
    util:logData("获取此论坛历史总帖数：key:"..history_key)
    local db = SsdbUtil:getDb();
    local count = db:get(history_key)
    local number = 0;
    if count and count[1] and string.len(count[1])>0 then
        number = tonumber(count[1]);
    else
        number=0;
    end
    SsdbUtil:keepalive(db)
    return number;
end

return BbsTotalService;
