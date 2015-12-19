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
local bit = require("social.common.bit")
local DBUtil = require "common.DBUtil";
local SSDBUtil = require("social.common.ssdbutil")
local util = require("social.common.util")
local TableUtil = require("social.common.table")
local _M = {
    cache = true
}
local BIT_FLAG = {
    bit101 = 8,
    bit102 = 4,
    bit103 = 2,
    bit104 = 1
}

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




-- 20.	个人文章管理搜索
--/usr/local/sphinx/bin/searchd -c /usr/local/sphinx/etc/csft_blog_article.conf
--/usr/local/sphinx/bin/indexer -c /usr/local/sphinx/etc/csft_blog_article.conf --rotate --all
--/usr/local/sphinx/bin/searchd -c /usr/local/sphinx/etc/csft_blog_article.conf --stop
--- @param table param
function _M.orgArticleList(param, func)

    local str_maxmatches = "10000"
    local offset = param.pagesize * param.pagenum - param.pagesize
    local limit = param.pagesize
    -- checkNull({ categoryid = param.categoryid, org_type = org_type })

    local sql = "SELECT SQL_NO_CACHE id FROM T_SOCIAL_BLOG_ARTICLE_SPHINXSE  WHERE query='%s%s%s%s%s%s%sfilter=is_del,0;maxmatches=" .. str_maxmatches .. ";offset=" .. offset .. ";limit=" .. limit .. "';SHOW ENGINE SPHINX STATUS;";
    --local searchKeyFilter = ((param.search_key == nil or string.len(param.search_key) == 0) and "") or ngx.decode_base64(param.search_key) .. ";"
    local searchKeyFilter = ""
    if param.search_key and string.len(param.search_key) > 0 and param.search_type and string.len(param.search_type) > 0 then
        searchKeyFilter = "mode=extended2;@(" .. param.search_type .. ") " .. ngx.decode_base64(param.search_key) .. ";"
    end

    local personIdFilter = ((param.person_id == nil or string.len(param.person_id) == 0) and "") or "filter=person_id," .. param.person_id .. ";"
    local identityIdFilter = ((param.identity_id == nil or string.len(param.identity_id) == 0) and "") or "filter=identity_id," .. param.identity_id .. ";"
    local businessTypeFilter = ((param.business_type == nil or string.len(param.business_type) == 0) and "") or "filter=business_type," .. param.business_type .. ";"

    local categoryIdTypeFilter = ((param.category_id == nil or string.len(param.category_id) == 0) and "") or "filter=person_category_id," .. param.category_id .. ";"
    local _filterDate = ((param.start_time == nil or string.len(param.start_time) == 0) and "") or "range=create_time," .. param.start_time .. "," .. param.end_time .. ";"
    local sort = "sort=extended:top desc,ts desc;"
    sql = string.format(sql, searchKeyFilter, personIdFilter, identityIdFilter, businessTypeFilter, categoryIdTypeFilter, _filterDate, sort)

    log.debug("sql :" .. sql)
    local db = DBUtil:getDb();
    local res = db:query(sql)
    local res1 = db:read_result()
    local _, s_str = string.find(res1[1]["Status"], "found: ")
    local e_str = string.find(res1[1]["Status"], ", time:")
    local totalRow = string.sub(res1[1]["Status"], s_str + 1, e_str - 1)
    local totalPage = math.floor((totalRow + param.pagesize - 1) / param.pagesize)
    local blog = { list = {} }
    blog.page_number = param.pagenum;
    blog.total_page = totalPage;
    blog.total_row = totalRow;
    blog.page_size = param.pagesize
    local ssdb = SSDBUtil:getDb();
    if res then
        for i = 1, #res do
            local key = "social_blog_article_" .. res[i]["id"]
            local keys = { "blog_id", "person_id", "person_name", "identity_id", "title", "overview", "content", "thumb_id", "person_category_id", "thumb_ids", "org_category_id", "browse_num", "comment_num", "support_num", "create_time", "top", "stage_id", "stage_name", "subject_id", "subject_name", "province_id", "city_id", "business_type", "district_id", "school_id", "show", "best" }
            local _result = ssdb:multi_hget(key, unpack(keys))
            --log.debug("======================")
            --log.debug(_result)
            if _result and #_result > 0 then
                local _blog_article = util:multi_hget(_result, keys)
                local blog_article = {}
                local name = "social_blog_category_%s"
                name = string.format(name, _blog_article.person_category_id)
                local category_result = ssdb:multi_hget(name, unpack({ "name" }))
                local _category_result = util:multi_hget(category_result, { "name" })
                --log.debug(_category_result)

                blog_article.catetory_name = _category_result.name
                blog_article.category_id = _blog_article.person_category_id
                blog_article.title = _blog_article.title
                blog_article.overview = _blog_article.overview
                blog_article.person_name = _blog_article.person_name
                blog_article.thumb_id = _blog_article.thumb_id
                blog_article.create_time = _blog_article.create_time
                blog_article.browse_num = _blog_article.browse_num
                blog_article.comment_num = _blog_article.comment_num
                blog_article.id = res[i]["id"]
                table.insert(blog.list, blog_article)
            end
        end
    end
    if func and type(func) == "function" then func() end
    return blog
end

------------------------------------------------------------------------------------------------------------------------
-- local function setShowDb(param, func)
-- local ids = param.ids;
-- local org_type_k = 'bit' .. param.org_type;
-- local org_type = BIT_FLAG[org_type_k];
-- local db = DBUtil:getDb();
-- db:query("START TRANSACTION;")
-- local status,err = pcall(function()
-- for i = 1, #ids do
-- local sql = "UPDATE T_SOCIAL_BLOG_ARTICLE T SET T.SHOW=%s WHERE T.ID=%s"
-- local sql_byid = "SELECT IFNULL(T.SHOW,0) AS _SHOW FROM T_SOCIAL_BLOG_ARTICLE T WHERE T.ID=%s";
--
-- sql_byid = string.format(sql_byid, ids[i]);
-- log.debug(sql_byid)
-- local result = db:query(sql_byid)
-- log.debug(result)
-- if result then
-- local show = result[1]['_SHOW'];
-- -- 如果是加显示则执行or 操作加入权限，如果是取消显示，则做异或运算。
-- local value =(param.is_cancel and bit:_xor(tonumber(show), org_type)) or bit:_or(tonumber(show), org_type);
-- sql = string.format(sql, value, ids[i]);
-- log.debug(sql)
-- local _result = db:query(sql)
-- if not _result and _result.affected_rows <= 0 then
-- error("更新出错.")
-- end
-- end
-- end
-- end)
-- if status then
-- db:query("COMMIT;")
-- func()
-- else
-- log.debug("更新显示出错.");
-- log.debug(err);
-- db:query("ROLLBACK;")
-- end
-- end
local function setShowDb(param, func)
    local ids = param.ids;
    local org_type_k = 'bit' .. param.org_type;
    local org_type = BIT_FLAG[org_type_k];
    local db = DBUtil:getDb();
    db:query("START TRANSACTION;")
    local logic = (param.is_cancel and "^") or "|"; --如果是加显示则执行or 操作加入权限，如果是取消显示，则做异或运算。
    local status, err = pcall(function()
        local sql = "UPDATE T_SOCIAL_BLOG_ARTICLE T SET T.SHOW=(T.SHOW%s%s) WHERE T.ID IN (%s)"
        sql = string.format(sql, logic, org_type, table.concat(ids, ","));
        log.debug(sql);
        db:query(sql);
    end)
    if status then
        db:query("COMMIT;")
        func()
    else
        log.debug("更新显示出错.");
        log.debug(err);
        db:query("ROLLBACK;")
    end
end

local function setShowSSDB(param)
    local ids = param.ids;
    local org_type_k = 'bit' .. param.org_type;
    local org_type = BIT_FLAG[org_type_k];
    local ssdb = SSDBUtil:getDb();
    for i = 1, #ids do
        local name = string.format("social_blog_article_%s", ids[i]);
        local key = { "show" };
        local _result = ssdb:multi_hget(name, unpack(key));
        if _result and #_result > 0 and _result[1] ~= "ok" then
            local _blog = util:multi_hget(_result, key)
            _blog.show = (_blog.show == "" and 0) or _blog.show
            local value = (param.is_cancel and bit:_xor(tonumber(_blog.show), org_type)) or bit:_or(tonumber(_blog.show), org_type);
            _blog.show = value;
            ssdb:multi_hset(name, _blog);
        end
    end
end

--@param param.ids table
--@param param.org_type string
function _M.setShow(param, func)
    setShowDb(param, function()
        if _M.cache then
            setShowSSDB(param)
        end
    end)
    if func and type(func) == "function" then func() end
end

return baseService:inherit(_M):init()