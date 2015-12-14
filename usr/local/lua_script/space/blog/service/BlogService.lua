--
-- 博客博文前台service
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2015/11/12 0012
-- Time: 上午 9:52
-- To change this template use File | Settings | File Templates.
--

local baseService = require("social.service.CommonBaseService")
local log = require("social.common.log")
local DBUtil = require "common.DBUtil";
local SSDBUtil = require("social.common.ssdbutil")
local TableUtil = require("social.common.table")
local _M = {}
------------------------------------------------------------------------------------------------------------------------
-- 1.	获取机构博客的基本信息
-- @param string org_person_id
-- @param string identity_id
function _M.getBlogInfo(org_person_id, identity_id, func)
end

------------------------------------------------------------------------------------------------------------------------
-- 2.	修改主题
-- @param string theme_id
-- @param string org_person_id
-- @param string identity_id
function _M.updateTheme(theme_id, org_person_id, identity_id, func)
end

------------------------------------------------------------------------------------------------------------------------
-- 3.	门户获取最新、热门、精华、文章
-- @param table param
function _M.getBlogArticle(param, func)
end

------------------------------------------------------------------------------------------------------------------------
-- 4.	获取推荐的博客(设置优秀的)
-- @param table param
function _M.getRecommendBlog(param, func)
end

------------------------------------------------------------------------------------------------------------------------
-- 7.	门户获取教师、学生、家长的分类（分类下显示此分类下博文条数）
-- @param table identity_ids
-- @param string org_id
function _M.getCategoryArticleByIdentityId(org_id, identity_ids, func)
end

------------------------------------------------------------------------------------------------------------------------
-- 8.	门户获取博客统计数(总用户数，总博文数，今日新增博文数，总浏览数，总评论数，今日访问量)
-- @param string org_id
-- @param string org_type
-- @param string identity_id
function _M.getBlogStat(org_id, org_type, identity_id, func)
end

------------------------------------------------------------------------------------------------------------------------
-- 10.	通过分类获取此分类下的文章
-- @param string org_id
-- @param string org_type
-- @param string category_id
-- @param int pagenum
-- @param int pagesize
function _M.getArticleByCatetoryId(org_id, org_type, category_id, pagenum, pagesize, func)
end

------------------------------------------------------------------------------------------------------------------------
-- 11.	根据文章内容，文章标题搜索
-- @param table param.
function _M.search(param)
end



function _M.initDb()
    log.debug("初始化数据库开始.")
    local sql = require("space.blog.service.initsql");
    local db = DBUtil:getDb();
    local result = db:query(sql[1])
    log.debug(result);
    local length = tonumber(result.insert_id)
    local ssdb = SSDBUtil:getDb();
    for i = 1, 18 do
        log.debug(i)
        local name = "social_blog_category_%s"
        name = string.format(name, i)
        local _sql = string.format("SELECT * FROM T_SOCIAL_BLOG_CATEGORY T WHERE T.ID=%s", i);
        local _result = db:query(_sql);
        log.debug(_result);
        if _result and _result[1] then
            for k, v in pairs(_result[1]) do
                if tostring(v) == "userdata: NULL" then
                    _result[1][k] = "";
                end
            end
            log.debug(name);
            log.debug(_result[1])
            local status = ssdb:multi_hset(name, _result[1])
            log.debug(status)
        end
    end
    log.debug("初始化数据库结束.")
    return result;
end

return baseService:inherit(_M):init()