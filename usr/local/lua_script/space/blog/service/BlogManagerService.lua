--
-- 博客博文后台管理service
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2015/11/12 0012
-- Time: 上午 9:53
-- To change this template use File | Settings | File Templates.
--

local log = require("social.common.log")
local SSDBUtil = require("social.common.ssdbutil")
local TS = require "resty.TS"
--local TableUtil = require("social.common.table")
local DBUtil = require "common.DBUtil";
local quote = ngx.quote_sql_str
local util = require("social.common.util")
local TableUtil = require("social.common.table")
local baseService = require("social.service.CommonBaseService")
log.level = "debug"
local _M = {
    cache = true
}

local BIT_FLAG = {
    bit101 = 8,
    bit102 = 4,
    bit103 = 2,
    bit104 = 1
}

local function checkNull(param)
    baseService:checkParamIsNull(param)
end


------------------------------------------------------------------------------------------------------------------------
--- 修改个人分类
-- 抛出错误
--
-- @param table param
local function updatePersonCategoryDb(param, func)
    local db = DBUtil:getDb();

    local sql = "update T_SOCIAL_BLOG_CATEGORY set name=%s where id=%s"
    sql = string.format(sql, quote(param.name), param.id)
    log.debug(sql)
    local result = db:query(sql)
    func()
    return result
end

local function updatePersonCategorySSDB(param)
    local name = "social_blog_category_%s"
    local db = SSDBUtil:getDb();
    name = string.format(name, param.id)
    log.debug(param);
    log.debug(name);
    local status = db:multi_hset(name, param)
    log.debug(status);
    return status;
end

function _M.updatePersonCategory(param, func)

    checkNull({ id = param.id, name = param.name })

    local result = updatePersonCategoryDb(param, function()
        if _M.cache then
            updatePersonCategorySSDB(param)
        end
    end)

    log.debug(result)

    if func then func() end

    return result.affected_rows
end

------------------------------------------------------------------------------------------------------------------------
--- 保存个人分类
-- 抛出错误
--
-- @param table param

--保存分类到mysql数据库
local function savePersonCategoryToDb(param, func)
    local columns = TableUtil:keys(param);
    local values = TableUtil:values(param);
    local sql = "INSERT INTO `%s` (`%s`) VALUES (%s)";
    sql = string.format(sql, "T_SOCIAL_BLOG_CATEGORY", table.concat(columns, "`,`"), "'" .. table.concat(values, "','") .. "'")
    log.debug(sql);
    local insertid = DBUtil:querySingleSql(sql).insert_id
    func(insertid)
    return insertid;
end

--保存分类到ssdb
local function savePersonCategoryToSSDB(param)
    local name = "social_blog_category_%s"
    local db = SSDBUtil:getDb();
    name = string.format(name, param.id)
    local status = db:multi_hset(name, param)
    return status;
end

function _M.savePersonCategory(param, func)
    checkNull(param)
    local insertid = savePersonCategoryToDb(param, function(id)
        log.debug(param);
        if _M.cache then
            param.id = id;
            local status = savePersonCategoryToSSDB(param);
        end
    end);
    if func then func() end
    return insertid;
end


------------------------------------------------------------------------------------------------------------------------
--- 14.	分类排序升降
--- @param table category 是一个json数据[{"category_id":"18","sequence":1},{"category_id":"17","sequence":2}] 转换的table
--- @param string org_person_id 机构或个人
--- @param string identity_id 身份id
local function updatePersonCategoryOrderDb(category, org_person_id, identity_id, func)
    local db = DBUtil:getDb()
    for i = 1, #category do
        local sql = "UPDATE T_SOCIAL_BLOG_CATEGORY set sequence=%s where id=%s and identity_id=%s and org_person_id=%s";
        sql = string.format(sql, quote(category[i]['sequence']), quote(category[i]['category_id']), quote(identity_id), quote(org_person_id))
        log.debug(sql)
        db:query(sql);
    end
    func();
end

local function updatePersonCategoryOrderSSDB(category)
    local ssdb = SSDBUtil:getDb();
    for i = 1, #category do
        local name = "social_blog_category_%s"
        name = string.format(name, category[i]['category_id']);
        ssdb:multi_hset(name, 'sequence', category[i]['sequence'])
    end
end

function _M.updatePersonCategoryOrder(category, org_person_id, identity_id, func)

    if not org_person_id or string.len(org_person_id) == 0 then
        error("org_person_id 参数不能为空.")
    end
    if not identity_id or string.len(identity_id) == 0 then
        error("identity_id 参数不能为空.")
    end
    updatePersonCategoryOrderDb(category, org_person_id, identity_id, function()
        if _M.cache then
            updatePersonCategoryOrderSSDB(category)
        end
    end)
    if func then func() end
end

------------------------------------------------------------------------------------------------------------------------
--- 15.	个人博客管理分类查询
-- @apram string person_id 人id
-- @param string identity_id 身份id
-- @param string business_type 业务类型，
-- @param string business_id 业务id.
function _M.getCategory(person_id, identity_id, business_type, business_id, level, func)
    checkNull({ business_id = business_id, business_type = business_type, level = level })
    local sql = "SELECT * FROM T_SOCIAL_BLOG_CATEGORY WHERE IS_DEL=0 AND BUSINESS_TYPE=%s AND BUSINESS_ID=%s AND LEVEL=%s"
    local _sql = ""
    if person_id and string.len(person_id) > 0 then
        _sql = _sql .. " AND ORG_PERSON_ID=" .. quote(person_id);
    end
    if identity_id and string.len(identity_id) > 0 then
        _sql = _sql .. " AND IDENTITY_ID=" .. quote(identity_id);
    end
    sql = string.format(sql .. _sql .. " ORDER BY SEQUENCE", quote(business_type), quote(business_id), level);
    log.debug(sql);
    local db = DBUtil:getDb()
    local result = db:query(sql);

    log.debug(result);

    if func then
        func()
    end
    return result;
end

------------------------------------------------------------------------------------------------------------------------
--- 16.	个人博客管理分类删除
-- @param table ids 多个主键id
-- @return int 影响行数.
local function deletPersonCategoryByIdsSSDB(ids)
    local db = SSDBUtil:getDb()
    for i = 1, #ids do
        local name = "social_blog_category_%s";
        name = string.format(name, ids[i])
        db:hclear(name);
    end
end

local function deletPersonCategoryByIdsDb(ids, func)

    local sql = "SELECT COUNT(ID) AS c  FROM T_SOCIAL_BLOG_ARTICLE WHERE PERSON_CATEGORY_ID=%s"
    local db = DBUtil:getDb();
    local delete_ids = {}
    for i = 1, #ids do
        sql = string.format(sql, ids[i])
        local countResult = db:query(sql)
        if countResult and countResult[1] then
            log.debug(countResult)
            log.debug(countResult[1])
            if tonumber(countResult[1]['c']) > 0 then
                return false, "该分类下有博文，不能删除."
            end
        end
        delete_ids[#delete_ids + 1] = ids[i];
    end
    local delete_sql = "UPDATE T_SOCIAL_BLOG_CATEGORY SET IS_DEL=1 WHERE ID IN(%s)"
    delete_sql = string.format(delete_sql, table.concat(delete_ids, ","))
    local result = db:query(delete_sql)
    if result and result.affected_rows > 0 then
        func()
    end
    return result
end

function _M.deletPersonCategoryByIds(ids, func)
    log.debug(ids);
    if TableUtil:length(ids) == 0 then
        error("ids 不能为空.")
    end
    local result, info = deletPersonCategoryByIdsDb(ids, function()
        if _M.cache then
            deletPersonCategoryByIdsSSDB(ids);
        end
    end)
    if func and type(func)=="function" then
        func()
    end
    return result, info;
end


------------------------------------------------------------------------------------------------------------------------
--- 17.	个人博客博文管理.删除
-- @param table ids 多个主键id
-- @return int 影响行数.
local function deleteArticleDb(ids, func)
    local update_ts = TS.getTs()
    local _ids = ids;
    log.debug(_ids);
    local db = DBUtil:getDb();
    db:query("START TRANSACTION;")
    local sql = "UPDATE T_SOCIAL_BLOG_ARTICLE SET IS_DEL=1,UPDATE_TS=%s WHERE ID IN(%s)"
    sql = string.format(sql, update_ts, table.concat(ids, ","))
    log.debug(sql);
    local result = db:query(sql);

    log.debug(_ids);
    for i = 1, #_ids do
        local select_sql = "select * from T_SOCIAL_BLOG_ARTICLE where id=%s";
        select_sql = string.format(select_sql, ids[i]);
        local _sresult = db:query(select_sql);
        log.debug(_sresult)
        if _sresult then
            local blog_id = _sresult[1]['blog_id'];
            local person_category_id = _sresult[1]['person_category_id'];
            sql = string.format("UPDATE T_SOCIAL_BLOG SET ARTICLE_NUM=ARTICLE_NUM-1 WHERE ID=%s AND ARTICLE_NUM>0", blog_id);
            log.debug(sql);
            local u_result = db:query(sql);
            sql = string.format("UPDATE T_SOCIAL_BLOG_CATEGORY SET ARTICLE_NUM=ARTICLE_NUM-1 WHERE ID=%s AND ARTICLE_NUM>0", person_category_id);
            local c_result = db:query(sql);
            if not u_result or not c_result then
                --事务回滚.
                db:query("ROLLBACK;");
                return 0;
            end
        end
    end
    --提交事务
    db:query("COMMIT;")
    log.debug(result);
    local affected_rows = result.affected_rows;
    func(affected_rows)
    return affected_rows;
end

local function deleteArticleSSDB(param)

    local db = SSDBUtil:getDb();
    for i = 1, #param do
        local name = "social_blog_info_personid_%s_identityid_%s";
        name = string.format(name, param[i]['person_id'], param[i]['identity_id']);
        local keys = { "person_id", "identity_id", "name", "id", "signature", "theme_id", "create_time", "access_num", "article_num", "check_status", "province_id", "city_id", "district_id", "school_id" };
        local result = db:multi_hget(name, unpack(keys))
        if result and #result > 0 and result[1] ~= "ok" then
            local _result = util:multi_hget(result, keys)
            if tonumber(_result.article_num) > 0 then
                local article_num = tonumber(_result.article_num) - 1;
                db:multi_hset(name, { article_num = article_num })
            end
        end
    end
end

function _M.deleteArticle(ids, func)
    if not ids or TableUtil:length(ids) == 0 then
        error("ids 不能为空.")
    end
    local affected_rows = deleteArticleDb(ids, function(affected_rows)
        if _M.cache and affected_rows > 0 then
            local sql = "SELECT PERSON_ID,IDENTITY_ID FROM T_SOCIAL_BLOG_ARTICLE WHERE ID IN (%s)"
            local db = DBUtil:getDb();
            sql = string.format(sql, table.concat(ids, ","));
            local result = db:query(sql);
            local _param = {};
            if result then
                for i = 1, #result do
                    table.insert(_param, { person_id = result[i]['PERSON_ID'], identity_id = result[i]['IDENTITY_ID'] });
                end
                deleteArticleSSDB(_param);
            end
        end
    end);
    if func and type(func)=="function" then func() end
    return affected_rows
end


------------------------------------------------------------------------------------------------------------------------
--- 17.	个人博客博文管理.移动
-- @param string dest_category_id
-- @param table ids 多个主键id
-- @return int 影响行数.
local function moveArticleDB(dest_category_id, ids, func)
    log.debug(ids);
    log.debug("移动文章的分类.")
    local db = DBUtil:getDb();
    db:query("START TRANSACTION;")
    local _ids = {}
    local _category_ids = {}
    for i=1,#ids do
        table.insert(_ids,ids[i]['id']);
        table.insert(_category_ids,ids[i]['category_id']);
    end

    local sql = "UPDATE T_SOCIAL_BLOG_ARTICLE  SET PERSON_CATEGORY_ID=%s WHERE ID IN (%s)"
    sql = string.format(sql, dest_category_id, table.concat(_ids, ","))
    log.debug(sql);
    local result = db:query(sql)

    log.debug(_category_ids);
    for i = 1,#_category_ids  do
        local c_sql = "UPDATE T_SOCIAL_BLOG_CATEGORY SET ARTICLE_NUM=ARTICLE_NUM-1 WHERE ID=%s"
        c_sql = string.format(c_sql,_category_ids[i]);
        log.debug(c_sql)
        local result1= db:query(c_sql);
        if not result1 then
            db:query("ROLLBACK;");
            return nil;
        end
    end

    local r_sql = "UPDATE T_SOCIAL_BLOG_CATEGORY SET ARTICLE_NUM=ARTICLE_NUM+%s WHERE ID=%s"
    r_sql = string.format(r_sql,#_ids,dest_category_id);
    log.debug(r_sql)
    local result2 = db:query(r_sql);

    if not result or not result2 then
        --事务回滚.
        db:query("ROLLBACK;");
        return nil;
    end
    db:query("COMMIT;")
    func()
    return result;
end

local function moveArticleSSDB(dest_category_id, ids)
    local ssdb = SSDBUtil:getDb()
    for i = 1, #ids do
        local name = string.format("social_blog_article_%s", ids[i]['id']);
        log.debug(name)
        ssdb:multi_hset(name, { person_category_id = dest_category_id });
        --local r = ssdb:multi_hget(name, unpack({ "person_category_id" }));
    end
end

function _M.moveArticle(dest_category_id, ids, func)
    checkNull({ dest_category_id = dest_category_id })

    if not ids or TableUtil:length(ids) == 0 then
        error("ids 不能为空.")
    end
    local result = moveArticleDB(dest_category_id, ids, function()
        if _M.cache then
            moveArticleSSDB(dest_category_id, ids);
        end
    end);

    if func and type(func)=="function" then
        func()
    end
    return (result and result.affected_rows) or 0;
end




------------------------------------------------------------------------------------------------------------------------
--- 17.	个人博客博文管理.修改博文
-- @param table param
-- @return int 影响行数.
local function updateArticleDb(param, func)
    log.debug(param);
    local sql = "UPDATE T_SOCIAL_BLOG_ARTICLE SET UPDATE_TS=%s,PERSON_CATEGORY_ID=%s,OVERVIEW=%s,TITLE=%s,THUMB_ID=%s,THUMB_IDS=%s,CONTENT=%s,ORG_CATEGORY_ID=%s%s%s WHERE ID=%s"
    local stage_update_sql = "";
    if param.stage_id and string.len(param.stage_id) then
        stage_update_sql = string.format(",stage_id=%s,stage_name=%s", quote(param.stage_id), quote(param.stage_name))
    end
    local subject_update_sql = "";
    if param.subject_id and string.len(param.subject_id) then
        subject_update_sql = string.format(",subject_id=%s,subject_name=%s", quote(param.subject_id), quote(param.subject_name))
    end
    sql = string.format(sql, param.update_ts, quote(param.person_category_id), quote(param.overview), quote(param.title), quote(param.thumb_id), quote(param.thumb_ids), quote(param.content), quote(param.org_category_id), stage_update_sql, subject_update_sql, quote(param.id))
    local db = DBUtil:getDb()
    local result, err = db:query(sql)
    if result and result.affected_rows > 0 then
        func();
    end
    return result
end

local function updateArticleSSDB(param)
    local name = string.format("social_blog_article_%s", param.id);
    local ssdb = SSDBUtil:getDb();
    ssdb:multi_hset(name, param);
end

function _M.updateArticle(param, func)
    checkNull({
        id = param.id,
        person_category_id = param.person_category_id,
        title = param.title,
        content = param.content,
    })
    local update_ts = TS.getTs()
    param.update_ts = update_ts;
    local result = updateArticleDb(param, function()
        if _M.cache then
            updateArticleSSDB(param)
        end
    end)
    if func and type(func)=="function" then
        func()
    end
    return result.affected_rows
end

------------------------------------------------------------------------------------------------------------------------
--- 17.	个人博客博文管理.保存博文
-- @param table param
--
-- person_category_id
-- overview
-- title
-- thumb_id
-- thumb_ids
-- content
-- Blog_id
-- person_id
-- Person_name
-- identity_id
-- org_category_id
-- stage_id
-- Stage_name
-- Subject_name
-- subject_id
-- province_id
-- city_id
-- district_id
-- school_id
-- business_type
local function saveArticleToSSDB(param, id)
    local name = string.format("social_blog_article_%s", id);
    local ssdb = SSDBUtil:getDb();
    ssdb:multi_hset(name, param);

    local bloginfo_name = "social_blog_info_%s"

    bloginfo_name = string.format(bloginfo_name, param.blog_id)

    local key = { "article_num" };
    local _result = ssdb:multi_hget(bloginfo_name, unpack(key));
    if _result and #_result > 0 then
        local _blog = util:multi_hget(_result, key)
        local article_num = _blog.article_num + 1;
        ssdb:multi_hset(bloginfo_name, { article_num = article_num });
    end

    local _name = "social_blog_info_personid_%s_identityid_%s";
    _name = string.format(_name, param.person_id, param.identity_id);
    _result = ssdb:multi_hget(_name, unpack(key));
    if _result and #_result > 0 then
        local _blog = util:multi_hget(_result, key)
        local article_num = _blog.article_num + 1;
        ssdb:multi_hset(_name, { article_num = article_num });
    end
end

local function saveArticleToDB(param, func)
    param.content = quote(param.content);
    local columns = TableUtil:keys(param);
    local values = TableUtil:values(param);
    local v = {}
    for i = 1, #values do
        table.insert(v, quote(values[i]))
    end
    local db = DBUtil:getDb();
    --开启事务
    db:query("START TRANSACTION;")
    local sql = "INSERT INTO `%s` (`%s`) VALUES (%s)";
    sql = string.format(sql, "T_SOCIAL_BLOG_ARTICLE", table.concat(columns, "`,`"), table.concat(v, ","))
    local insertid = db:query(sql).insert_id
    sql = string.format("UPDATE T_SOCIAL_BLOG SET ARTICLE_NUM=ARTICLE_NUM+1 WHERE ID=%s", param.blog_id);
    local u_result = db:query(sql);

    sql = string.format("UPDATE T_SOCIAL_BLOG_CATEGORY SET ARTICLE_NUM=ARTICLE_NUM+1 WHERE ID=%s", param.person_category_id);

    local c_result = db:query(sql);
    if not u_result or not c_result then
        --事务回滚.
        db:query("ROLLBACK;");
        return nil;
    end
    --提交事务
    db:query("COMMIT;")
    func(insertid)
    return insertid;
end

function _M.saveArticle(param, func)
    checkNull({
        person_category_id = param.person_category_id,
        title = param.title,
        content = param.content,
        blog_id = param.blog_id,
        person_id = param.person_id,
        person_name = param.person_name,
        identity_id = param.identity_id,
    })
    param.ts = TS.getTs()
    param.update_ts = TS.getTs()
    param.create_time = os.date("%Y-%m-%d %H:%M:%S")
    local content = param.content; --此处把content取出来，因为mysql做insert操作时，需对字符串做quote操作，但是存储在ssdb中的字符串，不需要做quote处理，所以先把其取出，再放回。
    local insertid = saveArticleToDB(param, function(id)
        if _M.cache then
            param.content = content; --
            log.debug(param.content);
            saveArticleToSSDB(param, id)
        end
    end)
    if func and type(func)=="function" then func() end
    return insertid;
end



------------------------------------------------------------------------------------------------------------------------
--- 17.	个人博客博文管理.查看
-- @param string id
local function getArticleByIdDb(id)
    local sql = "SELECT * T_SOCIAL_BLOG_ARTICLE WHERE ID = %s"
    sql = string.format(sql, id)
    local db = DBUtil:getDb();
    local result = db:query(sql)

    return result
end

local function getArticleByIdSSDB(id)
    local name = string.format("social_blog_article_%s", id);
    local ssdb = SSDBUtil:getDb();
    local keys = {
        "id",
        "person_category_id",
        "category_name",
        "overview", "title",
        "thumb_id",
        "thumb_ids",
        "content",
        "blog_id",
        "person_id",
        "person_name",
        "identity_id",
        "org_category_id",
        "stage_id",
        "stage_name",
        "subject_id",
        "subject_name",
        "create_time",
        "comment_num",
        "browse_num"
    }
    local result = ssdb:multi_hget(name, unpack(keys))
    if result and #result > 0 and result[1] ~= "ok" then
        local _result = util:multi_hget(result, keys);
        return {
            id = id,
            person_category_id = _result.person_category_id,
            category_name = _result.category_name,
            overview = _result.overview,
            title = _result.title,
            thumb_id = _result.thumb_id,
            thumb_ids = _result.thumb_ids,
            content = _result.content,
            blog_id = _result.blog_id,
            person_id = _result.person_id,
            person_name = _result.person_name,
            identity_id = _result.identity_id,
            org_category_id = _result.org_category_id,
            stage_id = _result.stage_id,
            stage_name = _result.stage_name,
            subject_id = _result.subject_id,
            subject_name = _result.subject_name,
            create_time = _result.create_time,
            comment_num = _result.comment_num,
            browse_num = _result.browse_num
        }
    end
    return nil
end

function _M.getArticleById(id, func)
    checkNull({ id = id })
    local result = (_M.cache and getArticleByIdSSDB(id)) or nil
    if not result then
        result = getArticleByIdDb(id)
        if result and _M.cache then
            for i = 1, #result do
                saveArticleToSSDB(result[i], id);
            end
        end
    end
    if func and type(func)=="function" then
        func()
    end
    return result
end

------------------------------------------------------------------------------------------------------------------------
--- 18.	个人博客访问统计（日，周，月，所有时间）
--- @param table param
function _M.getPersonBlogStat(param, func)
end



local function getBlog(org_person_id, identity_id)
    local sql = "SELECT * FROM T_SOCIAL_BLOG WHERE ORG_PERSON_ID=%s AND IDENTITY_ID=%s";
    sql = string.format(sql, org_person_id, identity_id);
    local db = DBUtil:getDb()
    local result = db:query(sql);
    return result;
end

------------------------------------------------------------------------------------------------------------------------
---
-- 19.	机构博客基本信息设置（添加）
-- name
-- logo
-- blog_address
-- check_status
-- identity_id
-- logo
-- signature
-- theme_id
-- province_id
-- city_id
-- district_id
-- school_id
-- Org_person_id
-- id
local function saveBlogDb(param, func)

    local columns = TableUtil:keys(param);
    local values = TableUtil:values(param);
    local sql = "INSERT INTO `%s` (`%s`) VALUES (%s)";

    sql = string.format(sql, "T_SOCIAL_BLOG", table.concat(columns, "`,`"), "'" .. table.concat(values, "','") .. "'")

    log.debug(sql);
    local db = DBUtil:getDb();
    local insertid = db:query(sql).insert_id
    func(insertid)
    return insertid;
end

local function saveBlogSSDB(id, param)
    local name = "social_blog_info_%s"
    local _name = "social_blog_info_personid_%s_identityid_%s";
    local db = SSDBUtil:getDb();
    name = string.format(name, id)
    param.id = id;
    _name = string.format(_name, param.org_person_id, param.identity_id)
    local pi_status, err = db:multi_hset(_name, param)
    local status, err1 = db:multi_hset(name, param)
    return status;
end

--- @param table param
function _M.saveBlog(param, func)
    checkNull({ name = param.name, identity_id = param.identity_id, theme_id = param.theme_id, org_person_id = param.org_person_id })

    local blog_result = getBlog(param.org_person_id, param.identity_id)


    if blog_result and TableUtil:length(blog_result) > 0 then
        error('此用户的博客已存在.')
    end

    param.article_num = 0;
    param.access_num = 0;
    param.create_time = os.date("%Y-%m-%d %H:%M:%S")

    local iid = saveBlogDb(param, function(insertid)
        if _M.cache then
            saveBlogSSDB(insertid, param);
        end
    end)
    if func and type(func)=="function" then
        func()
    end
    return iid;
end

------------------------------------------------------------------------------------------------------------------------
---
-- 19.	机构博客基本信息设置（修改）
-- name
-- logo
-- blog_address
-- check_status
-- identity_id
-- logo
-- signature
-- theme_id
-- province_id
-- city_id
-- district_id
-- school_id
-- Org_person_id
-- id
--- @param table param
local function updateBlogDb(param, func)
    local templet = "UPDATE `%s` SET %s WHERE %s"
    --local _sql = splitSetSql(param)
    local setSql = function()
        local sql = ""
        local i = 1;
        local count = TableUtil:length(param);
        for k, v in pairs(param) do
            i = i + 1
            if v then
                sql = sql .. k .. "='" .. v .. "'";
                if i <= count then
                    sql = sql .. ","
                end
            end
        end
        return sql;
    end
    local sql = string.format(templet, 'T_SOCIAL_BLOG', setSql(), 'id=' .. param.id);
    local db = DBUtil:getDb();
    local affected_rows = db:query(sql).affected_rows

    func()

    return affected_rows;
end

function _M.updateBlog(param, func)
    checkNull({ name = param.name, theme_id = param.theme_id })

    local affected_rows = updateBlogDb(param, function()
        if _M.cache then
            saveBlogSSDB(param.id, param)
        end
    end)

    if func and type(func)=="function" then func() end
    return affected_rows
end

------------------------------------------------------------------------------------------------------------------------
---
-- 20.	机构文章管理搜索
--- @param table param
function _M.articleList(param, func)
end

------------------------------------------------------------------------------------------------------------------------
---

-- 20.	个人文章管理搜索
--/usr/local/sphinx/bin/searchd -c /usr/local/sphinx/etc/csft_blog_article.conf
--/usr/local/sphinx/bin/indexer -c /usr/local/sphinx/etc/csft_blog_article.conf --rotate --all
--/usr/local/sphinx/bin/searchd -c /usr/local/sphinx/etc/csft_blog_article.conf --stop
--- @param table param
function _M.personArticleList(param, func)

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
    if func and type(func)=="function" then func() end
    return blog
end

------------------------------------------------------------------------------------------------------------------------
--- 21.	机构文章管理设置精华
--- @param table ids
-- @param string org_type 省  101  市102  区县 103  校 104
function _M.setBest(ids, org_type, func)
    --local bit = require("social.common.bit")
    checkNull({ ids = ids, org_type = org_type })
    local sql = "UPDATE T_SOCIAL_BLOG_ARTICLE SET BEST=%s WHERE ID IN (%s)";
    sql = string.format(sql, BIT_FLAG['bit' .. org_type], table.concat(ids, ','));
    local db = DBUtil:getDb();
    local result = db.query(sql);
    if func and type(func)=="function" then func() end
    return result.affected_rows
end

------------------------------------------------------------------------------------------------------------------------
--- 22.	机构文章管理推荐（支持批量推荐）
--- @param table param
function _M.setRecommend(param, func)
end


------------------------------------------------------------------------------------------------------------------------
--- 23.	机构文章管理删除（支持批量删除）
--- @param table ids
function _M.deleteOrgArticle(ids, func)
    _M.deleteArticle(ids, func)
end

------------------------------------------------------------------------------------------------------------------------
--- 24.	机构博客管理优秀博客管理搜索
--- @param string org_person_id
--- @param string org_type
--- @param string isall
function _M.excellentList(org_person_id, org_type, isall, func)
end

------------------------------------------------------------------------------------------------------------------------
--- 25.	机构博客管理优秀博客管理设置优秀取消优秀
--- @param string org_person_id
--- @param string org_type
--- @param string isall
function _M.excellentSet(param, func)
end

------------------------------------------------------------------------------------------------------------------------
--- 26.	验证个人博客是否有分类
-- @param string person_id
-- @param string identity_id
function _M.validateCategory(person_id, identity_id, func)
end

local function getBlogInfoDb(org_person_id, identity_id, func)
    local db = DBUtil:getDb();
    local sql = "SELECT * FROM T_SOCIAL_BLOG WHERE ORG_PERSON_ID=%s AND IDENTITY_ID=%s"
    sql = string.format(sql, org_person_id, identity_id);
    local _result = db:query(sql)
    local result;
    if _result and TableUtil:length(_result) > 0 then
        result = _result[1];
        func(result[1]['id'], result);
    end

    return result;
end

local function getBlogInfoSSDB(org_person_id, identity_id)
    local _name = "social_blog_info_personid_%s_identityid_%s";
    local db = SSDBUtil:getDb();
    _name = string.format(_name, org_person_id, identity_id);
    local keys = { "org_person_id", "identity_id", "name", "id", "signature", "theme_id", "create_time", "access_num", "comment_num", "article_num", "check_status", "province_id", "city_id", "district_id", "school_id" };
    local _result = db:multi_hget(_name, unpack(keys));
    log.debug(_result);
    local result;
    if _result and #_result > 0 and _result[1] ~= "ok" then
        result = util:multi_hget(_result, keys)
        local name = "social_blog_info_%s";
        name = string.format(name, result.id);
        local r = db:multi_hget(name, unpack({ "access_num", "comment_num" }));
        if r and #r > 0 and r[1] ~= "ok" then
            local _r = util:multi_hget(r, keys)
            result.access_num = _r.access_num;
            result.comment_num = _r.comment_num;
        else
            result.access_num = 0;
            result.comment_num = 0;
        end
    end
    return result;
end

function _M.getBlogInfo(org_person_id, identity_id, func)
    checkNull({ org_person_id = org_person_id, identity_id = identity_id })
    local result = getBlogInfoSSDB(org_person_id, identity_id)
    if not result then
        result = getBlogInfoDb(org_person_id, identity_id, function(id, param) --查完数据库回填至ssdb.
            if _M.cache then
                saveBlogSSDB(id, param)
            end
        end);
    end
    if func and type(func)=="function" then func() end
    return result
end


------------------------------------------------------------------------------------------------------------------------
-- 对文章评论次数自增1
local function addCommentNumDb(blog_id, article_id, func)
    local db = DBUtil:getDb();
    db:query("START TRANSACTION;") --开启事务
    local sql = "UPDATE T_SOCIAL_BLOG_ARTICLE SET COMMENT_NUM=COMMENT_NUM+1 WHERE ID=%s";
    sql = string.format(sql, article_id);
    local result1 = db:query(sql);
    sql = "UPDATE T_SOCIAL_BLOG SET COMMENT_NUM = COMMENT_NUM+1 WHERE ID=%s"
    sql = string.format(sql, blog_id);
    local result2 = db:query(sql);
    if not result2 or not result1 then
        --事务回滚.
        db:query("ROLLBACK;");
        return nil;
    end
    --提交事务
    db:query("COMMIT;")
    if result1 and result1.affected_rows > 0 and result2 and result2.affected_rows > 0 then
        func()
    end
    return result1;
end

local function addCommentNumSSDB(blog_id, article_id)
    local db = SSDBUtil:getDb()
    --对文章的评论次数加1
    local name = "social_blog_article_" .. article_id
    local keys = { "comment_num" }
    local _result = db:multi_hget(name, unpack(keys))
    local result;
    if _result and #_result > 0 and _result[1] ~= "ok" then
        result = util:multi_hget(_result, keys)
        db:multi_hset(name, { comment_num = result.comment_num + 1 })
    else
        db:multi_hset(name, { comment_num = 1 })
    end
    --对博客下文章的评论次数加1
    name = string.format("social_blog_info_%s", blog_id);
    keys = { "comment_num" }
    _result = db:multi_hget(name, unpack(keys))
    if _result and #_result > 0 and _result[1] ~= "ok" then
        result = util:multi_hget(_result, keys)
        db:multi_hset(name, { comment_num = result.comment_num + 1 })
    else
        db:multi_hset(name, { comment_num = 1 })
    end
end

function _M.addCommentNum(blog_id, article_id, func)
    checkNull({ article_id = article_id })
    local result = addCommentNumDb(blog_id, article_id, function()
        if _M.cache then
            addCommentNumSSDB(blog_id, article_id);
        end
    end)
    if func and type(func)=="function" then func() end
    return result and result.affected_rows > 0
end




------------------------------------------------------------------------------------------------------------------------
-- 对文章浏览次数加1 browse_num
local function addBrowseNumDb(blog_id, article_id, func)
    local db = DBUtil:getDb();
    db:query("START TRANSACTION;") --开启事务
    local sql = "UPDATE T_SOCIAL_BLOG_ARTICLE SET BROWSE_NUM=BROWSE_NUM+1 WHERE ID=%s";
    sql = string.format(sql, article_id);
    local result1 = db:query(sql);
    sql = "UPDATE T_SOCIAL_BLOG SET ACCESS_NUM = ACCESS_NUM+1 WHERE ID=%s"
    sql = string.format(sql, blog_id);
    local result2 = db:query(sql);
    if not result2 then
        --事务回滚.
        db:query("ROLLBACK;");
        return nil;
    end
    --提交事务
    db:query("COMMIT;")
    if result1 and result1.affected_rows > 0 and result2 and result2.affected_rows > 0 then
        func()
    end
    return result1;
end

local function addBrowseNumSSDB(blogid, article_id)
    local db = SSDBUtil:getDb()
    --- 对文章浏览次数的缓存加1
    local name = "social_blog_article_" .. article_id
    local keys = { "browse_num" }
    local _result = db:multi_hget(name, unpack(keys))
    local result;
    if _result and #_result > 0 and _result[1] ~= "ok" then
        result = util:multi_hget(_result, keys)
        db:multi_hset(name, { browse_num = result.browse_num + 1 })
    else
        db:multi_hset(name, { browse_num = 1 })
    end

    --- 对博客下文章的浏览次数加1
    name = string.format("social_blog_info_%s", blogid);
    keys = { "access_num" }
    _result = db:multi_hget(name, unpack(keys))
    if _result and #_result > 0 and _result[1] ~= "ok" then
        result = util:multi_hget(_result, keys)
        db:multi_hset(name, { access_num = result.access_num + 1 })
    else
        db:multi_hset(name, { access_num = 1 })
    end
end

function _M.addBrowseNum(blog_id, article_id, func)
    checkNull({ article_id = article_id })
    local result = addBrowseNumDb(blog_id, article_id, function()
        if _M.cache then
            addBrowseNumSSDB(blog_id, article_id);
        end
    end)
    if func and type(func)=="function" then func() end
    return result and result.affected_rows > 0
end


return baseService:inherit(_M):init()