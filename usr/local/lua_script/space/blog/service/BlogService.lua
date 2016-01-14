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
local DBUtil = require "social.common.mysqlutil";
local SSDBUtil = require("social.common.ssdbutil")
local util = require("social.common.util")
local TableUtil = require("social.common.table")
local TS = require "resty.TS"
local quote = ngx.quote_sql_str
local Constant = require("space.blog.constant.Constant")
local blogMySqlDao = require("space.blog.dao.BlogMySqlDao");
local _M = {
    cache = true
}

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




-------------------------------------------------------------------------------------------------------------------------
local function getArticleListBySSDB(res, org_id, org_type)
    local list = {}
    local ssdb = SSDBUtil:getDb();
    for i = 1, #res do
        local key = "social_blog_article_" .. res[i]["id"]
        local keys = { "blog_id", "person_id", "person_name", "identity_id", "title", "overview", "content", "thumb_id", "person_category_id", "thumb_ids", "org_category_id", "browse_num", "comment_num", "support_num", "create_time", "top", "stage_id", "stage_name", "subject_id", "subject_name", "province_id", "city_id", "business_type", "district_id", "school_id", "show", "best" }
        local _result = ssdb:multi_hget(key, unpack(keys))
        --log.debug("======================")
        --log.debug(_result)
        if _result and #_result > 0 then
            local _blog_article = util:multi_hget(_result, keys)

            -- log.debug(_blog_article)
            local blog_article = {}
            local name = "social_blog_category_%s"
            name = string.format(name, _blog_article.org_category_id)
            local category_result = ssdb:multi_hget(name, unpack({ "name" }))
            local _category_result = util:multi_hget(category_result, { "name" })
            --log.debug(_category_result)

            blog_article.catetory_name = _category_result.name
            blog_article.category_id = _blog_article.org_category_id
            blog_article.title = _blog_article.title
            blog_article.overview = _blog_article.overview
            blog_article.person_name = _blog_article.person_name
            blog_article.thumb_id = _blog_article.thumb_id
            blog_article.create_time = _blog_article.create_time
            blog_article.browse_num = _blog_article.browse_num
            blog_article.comment_num = _blog_article.comment_num
            --            local org_type = Constant.ORG_TABLE_MAPPING["org_"..org_type];
            --            local _org_type = _blog_article[org_type]
            _blog_article.show = _blog_article.show == "" and "0" or _blog_article.show;
            blog_article.show = _blog_article.show
            --            log.debug(_blog_article.show);
            --            log.debug(org_type)
            local _org_type = Constant.BIT_FLAG[tonumber(org_type)]; --4 or 2 == 6 证明不包含
            --            log.debug(_org_type)
            if _blog_article.show == "0" then
                blog_article.isshow = false
            else
                blog_article.isshow = bit:_or(_org_type, tonumber(_blog_article.show)) == _org_type and true or false;
            end

            _blog_article.best = _blog_article.best == "" and "0" or _blog_article.best;
            blog_article.best = _blog_article.best
            if _blog_article.best == "0" then
                blog_article.isbest = false
            else
                blog_article.isbest = bit:_or(_org_type, tonumber(_blog_article.best)) == _org_type and true or false;
            end
            local recommond_name = "social_blog_article_%s_recommend";
            recommond_name = string.format(recommond_name, res[i]["id"])
            local recommondResult = ssdb:multi_hget(recommond_name, unpack({ "id" }));
            local recommond_status = false;
            if recommondResult and #recommondResult > 0 and recommondResult[1] ~= "ok" then
                recommond_status = true;
            end
            log.debug(recommond_status)
            blog_article.recommond_status = recommond_status;
            blog_article.id = res[i]["id"]
            table.insert(list, blog_article)
        end
    end

    return list;
end

local function getBit(b)
    local r = bit:getInTable(b)
    return table.concat(r, ",");
end



-- 20.	机构文章管理搜索
--1门户显示,2.本级精华，3.推荐，4. 推荐给上级的,5下级推荐的

--- @param table param
function _M.orgArticleList(param, func)
    local result,totalRow,totalPage = blogMySqlDao.orgArticleList(param);
    local blog = { list = {} }
    blog.page_number = param.pagenum;
    blog.total_page = totalPage;
    blog.total_row = totalRow;
    blog.page_size = param.pagesize
    if result then
        blog.list = getArticleListBySSDB(result, param.org_id, param.org_type);
    end
    if func and type(func) == "function" then func() end
    return blog
end

------------------------------------------------------------------------------------------------------------------------


--local function setShowDb(param, func)
--    local ids = param.ids;
--    local org_type_k = 'bit' .. param.org_type;
--    local org_type = Constant.BIT_FLAG[org_type_k];
--    local db = DBUtil:getDb();
--    db:query("START TRANSACTION;")
--    local logic = (param.is_cancel and "^") or "|"; --如果是加显示则执行or 操作加入权限，如果是取消显示，则做异或运算。
--    local status, err = pcall(function()
--        local ts = TS.getTs();
--        local sql = "UPDATE T_SOCIAL_BLOG_ARTICLE T SET T.UPDATE_TS=%s,T.SHOW=(T.SHOW%s%s) WHERE T.ID IN (%s)"
--        sql = string.format(sql,ts, logic, org_type, table.concat(ids, ","));
--        log.debug(sql);
--        local result = db:query(sql);
--        if not result then
--            error("更新出错.")
--        end
--    end)
--    if status then
--        db:query("COMMIT;")
--        func()
--    else
--        log.debug("更新显示出错.");
--        log.debug(err);
--        db:query("ROLLBACK;")
--    end
--end

local function setShowSSDB(param)
    local ids = param.ids;
    local org_type_k = tonumber(param.org_type);
    local org_type = Constant.BIT_FLAG[org_type_k];
    local ssdb = SSDBUtil:getDb();
    log.debug(ids);
    log.debug(param.is_cancel);
    for i = 1, #ids do
        local name = string.format("social_blog_article_%s", ids[i]);
        local key = { "show" };
        local _result = ssdb:multi_hget(name, unpack(key));
        if _result and #_result > 0 and _result[1] ~= "ok" then
            local _blog = util:multi_hget(_result, key)
            log.debug(_blog)
            _blog.show = ((_blog.show == "" or _blog.show == "0") and 0) or _blog.show
            local value = (param.is_cancel and bit:_xor(tonumber(_blog.show), org_type)) or bit:_or(tonumber(_blog.show), org_type);
            _blog.show = value;
            log.debug(value);
            ssdb:multi_hset(name, _blog);
        else
            local value = (param.is_cancel and bit:_xor(tonumber(0), org_type)) or bit:_or(tonumber(0), org_type);
            ssdb:multi_hset(name, { show = value });
        end
    end
end

--
--机构博客博文的显示不显示设置.
--@param param.ids table
--@param param.org_type string
--@param func function 回调函数.
function _M.setShow(param, func)
    blogMySqlDao.setShowDb(param, function()
        if _M.cache then
            setShowSSDB(param)
        end
    end)
    if func and type(func) == "function" then func() end
end


------------------------------------------------------------------------------------------------------------------------

--更新ssdb
local function setBestSSSB(param)
    local ids = param.ids;
    local org_type_k = tonumber(param.org_type);
    local org_type = Constant.BIT_FLAG[org_type_k];
    local ssdb = SSDBUtil:getDb();
    for i = 1, #ids do
        local name = string.format("social_blog_article_%s", ids[i]);
        local key = { "best" };
        local _result = ssdb:multi_hget(name, unpack(key));
        if _result and #_result > 0 and _result[1] ~= "ok" then
            local _blog = util:multi_hget(_result, key)
            _blog.best = (_blog.best == "" and 0) or _blog.best
            local value = (param.is_cancel and bit:_xor(tonumber(_blog.best), org_type)) or bit:_or(tonumber(_blog.best), org_type);
            _blog.best = value;
            ssdb:multi_hset(name, _blog);
        else
            local value = (param.is_cancel and bit:_xor(tonumber(0), org_type)) or bit:_or(tonumber(0), org_type);
            ssdb:multi_hset(name, { best = value });
        end
    end
end

--机构博客博文的精华设置.
--@param param.ids table
--@param param.org_type string
--@param func function 回调函数.
function _M.setBest(param, func)
    blogMySqlDao.setBestDb(param, function()
        if _M.cache then
            setBestSSSB(param)
        end
    end)
    if func and type(func) == "function" then func() end
end









------------------------------------------------------------------------------------------------------------------------
local function setRecommendSSDB(param, recommendIds)
    local ids = param.ids;
    local db = SSDBUtil:getDb();
    for i = 1, #ids do
        param.id = recommendIds[i];
        local name = "social_blog_article_%s_recommend";
        name = string.format(name, ids[i]);
        param.ids = nil;
        db:multi_hset(name, param);
    end
end


--机构博客博文设置推荐
--@param param.ids table
--@param param.from_id string
--@param param.from_level string
--@param param.to_id string
--@param param.to_level string
--@param param.explain string
function _M.setRecommend(param, func)
    _M:checkParamIsNull({ from_id = param.from_id, from_level = param.from_level, to_id = param.to_id, to_level = param.to_level });
    --    setRecommendDb(param, function(ids)
    --        if _M.cache then
    --            setRecommendSSDB(param, ids)
    --        end
    --    end)

    local status, recommenIds = pcall(blogMySqlDao.setRecommendDb, param)
    if status and _M.cache then
        setRecommendSSDB(param, recommenIds)
    end
    if not status then
        error("设置推荐出错.")
    end
    if func and type(func) == "function" then func() end
end

--设置优秀。
--@param param.org_person_id string
--@param param.identity_id string
--@param param.province_id string
--@param param.city_id string
--@param param.district_id string
--@param param.school_id string
--@param param.org_type string
function _M.setExcellentBlog(param, func)
    _M:checkParamIsNull({ org_person_id = param.org_person_id, identity_id = param.identity_id, province_id = param.province_id, city_id = param.city_id, district_id = param.district_id, school_id = param.school_id, org_type = param.org_type })
    log.debug(param);
    local result = blogMySqlDao.setExcellentBlogDb(param);
    if func and type(func) == "function" then func() end
    return result;
end




-- 学生6 老师5 家长7
--
--local function getExcellent(org_person_id, identity_id, org_type, person_id)
--    log.debug("org_type:" .. org_type);
--    local _org_type = Constant.BIT_FLAG[tonumber(org_type)];
--    log.debug(_org_type);
--    local excellent = getBit(_org_type);
--
--    local o_type = Constant.ORG_TABLE_MAPPING[tonumber(org_type)];
--    local sql = "SELECT * FROM T_SOCIAL_EXCELLENT WHERE IDENTITY_ID=%s AND ORG_PERSON_ID=%s AND EXCELLENT IN (%s) AND EXCELLENT<>0";
--    sql = string.format(sql, identity_id, person_id, excellent);
--    -- log.debug("查询优秀sql:");
--    -- log.debug(sql)
--    local db = DBUtil:getDb();
--    local result = db:query(sql);
--    return result;
--end





local function filterData(queryResult, org_id, org_type, identity_id)
    local result = { list = {} };
    if queryResult then
        local list = queryResult.rows;
        if list ~= nil and #list > 0 then
            for j = 1, #list do
                local _temp = {}
                _temp.person_id = list[j].person_id
                _temp.person_name = list[j].person_name
                _temp.province_id = list[j].province_id
                _temp.city_id = list[j].city_id
                _temp.district_id = list[j].district_id
                _temp.school_id = list[j].school_id;
                local excellent_result = blogMySqlDao.getExcellent(org_id, identity_id, tonumber(org_type), _temp.person_id)
                _temp.isexcellent = TableUtil:length(excellent_result) > 0;
                table.insert(result.list, _temp)
            end
        end
        result.total_page = tonumber(queryResult.total);
        result.total_row = tonumber(queryResult.records);
    else
        result.total_page = 0;
        result.total_row = 0;
    end
    return result;
end

function _M.getExcellentBlog(param, func)
    log.debug(param)
    _M:checkParamIsNull({
        org_id = param.org_id,
        identity_id = param.identity_id,
        page_num = tostring(param.page_num),
        page_size = tostring(param.page_size),
        org_type = param.org_type
    })
    local excellentResult = {}
    local personService = require "base.person.services.PersonService";
    if param.display == "1" then --显示全部
        local queryResult = personService:queryPersonsByKeyAndOrg(tonumber(param.org_id), param.name, param.identity_id, param.page_num, param.page_size);
        log.debug(queryResult);
        excellentResult = filterData(queryResult, tonumber(param.org_id), param.org_type, param.identity_id)
        excellentResult.page_num = param.page_num
        excellentResult.page_size = param.page_size
        log.debug(excellentResult)
    else --显示优秀

        local result, totalPage, count = blogMySqlDao.getExcellentOrgBlogList(param);
        excellentResult.list = {};
        if result then
            for i = 1, #result do
                local person_id = result[i]['org_person_id'];
                local identity_id = result[i]['identity_id'];
                local city_id = result[i]['city_id'];
                local school_id = result[i]['school_id'];
                local district_id = result[i]['district_id'];
                local province_id = result[i]['province_id'];
                local _result = personService:getPersonInfo(person_id, identity_id);
                local person_name = _result['table_List']['person_name'];
                local _temp = { person_name = person_name, person_id = person_id, city_id = city_id, district_id = district_id, school_id = school_id, province_id = province_id, isexcellent = true };
                table.insert(excellentResult.list, _temp);
            end
            excellentResult.total_page = tonumber(totalPage);
            excellentResult.page_num = tostring(param.page_num);
            excellentResult.page_size = tostring(param.page_size);
            excellentResult.total_row = tonumber(count);
        else
            excellentResult.total_page = 0;
            excellentResult.total_row = 0;
            excellentResult.page_num = tostring(param.page_num);
            excellentResult.page_size = tostring(param.page_size);
        end
        log.debug(excellentResult)
    end
    return excellentResult;
end

--总博文数           费
--
--今日新增博文        我 查询博客表
--
--总浏览数           费 我去查
--
--总评论数           费 我去查
--
--今日访问量         黄
function _M.getOrgBlogStat(param, func)
    _M:checkParamIsNull({ org_id = param.org_id, org_type = param.org_type})
    local result = {};
    result.article_count = blogMySqlDao.getBlogArticleCount(param);
    result.corrent_day_count = blogMySqlDao.getBlogArticleCurrentDayCount(param);
    result.browse_count = blogMySqlDao.getBlogArticleBrowseCount(param);
    result.comment_count = blogMySqlDao.getBlogArticleCommentCount(param);
    if func and type(func) == "function" then func() end
    return result;
end

------------------------------------------------
-- function
return baseService:inherit(_M):init()