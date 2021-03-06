--
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2015/11/24 0024
-- Time: 上午 9:11
-- To change this template use File | Settings | File Templates.
--
local web = require("social.router.web")
local request = require("social.common.request")
local cjson = require "cjson"
local context = ngx.var.path_uri --有权限的context.
local no_permission_context = ngx.var.path_uri_no_permission --无权限的context.
local log = require("social.common.log")
local TableUtil = require("social.common.table")
local blogManagerService = require("space.blog.service.BlogManagerService");
local blogService = require("space.blog.service.BlogService");
--- 保存个人分类
local function savePersonCategory()
    local identity_id = request:getStrParam("identity_id", true, true)
    local name = request:getStrParam("name", true, true)
    local person_id = request:getStrParam("person_id", true, true)
    local person_name = request:getStrParam("person_name", true, true)
    local sequence = request:getStrParam("sequence", false, true)
    local business_type = request:getStrParam("business_type", false, true)
    local business_id = request:getStrParam("business_id", false, true)
    local level = request:getStrParam("level", false, true)
    local result = blogManagerService.savePersonCategory({ level = level, identity_id = identity_id, name = name, org_person_id = person_id, person_name = person_name, sequence = sequence, business_type = business_type, business_id = business_id });
    local r = { success = false, info = '' }
    if result then
        r.success = true
        r.id = result;
        r.info = '保存成功'
    end
    ngx.say(cjson.encode(r));
end

--- 修改个人分类
local function updatePersonCategory()
    local id = request:getStrParam("id", true, true)
    local name = request:getStrParam("name", true, true)
    local result = blogManagerService.updatePersonCategory({ id = id, name = name });
    local r = { success = false, info = '' }
    if result then
        r.success = true
        r.info = '修改成功'
    end
    ngx.say(cjson.encode(r));
end



--- 修改个人分类顺序
local function updatePersonCategoryOrder()

    local category_json = request:getStrParam("category", true, true)
    local org_person_id = request:getStrParam("org_person_id", true, true)
    local identity_id = request:getStrParam("identity_id", true, true)
    local category = cjson.decode(category_json)
    local status = pcall(blogManagerService.updatePersonCategoryOrder, category, org_person_id, identity_id)
    local r = { success = false, info = '' }
    if not status then
        r.info = '修改个人分类顺序失败.'
        ngx.say(cjson.encode(r));
        return;
    end
    r.info = '修改个人分类顺序成功.'
    r.success = true;
    ngx.say(cjson.encode(r));
    return;
end

--- 个人分类查询.
local function getCategory()
    local person_id = request:getStrParam("person_id", false, true)
    local identity_id = request:getStrParam("identity_id", false, true)
    local business_type = request:getStrParam("business_type", true, true)
    local business_id = request:getStrParam("business_id", true, true)
    local level = request:getStrParam("level", true, true);
    local result = blogManagerService.getCategory(person_id, identity_id, business_type, business_id, level)
    local r = { success = false, info = '', list = {} }
    log.debug(result);
    if result then
        for i = 1, #result do
            local person_name = result[i]['person_name']
            local id = result[i]['id'];
            local name = result[i]['name'];
            local sequence = result[i]['sequence'];
            local article_num = result[i]['article_num'];
            local _list = { name = name, id = id, person_name = person_name, sequence = sequence, article_num = article_num };
            table.insert(r.list, _list);
        end
        r.success = true;
        r.info = '查询成功'
        cjson.encode_empty_table_as_object(false)
        ngx.say(cjson.encode(r));
    else
        r.success = true;
        r.list = {}
        ngx.say(cjson.encode(r));
    end
    return;
end

--- 分类删除(可批量删除).
local function deletPersonCategoryByIds()
    local ids = request:getStrParam("ids", true, true)
    local _ids = Split(ids, ",")
    local result, info = blogManagerService.deletPersonCategoryByIds(_ids)
    local r = { success = false, info = '' }
    if not result then
        r.info = info;
        ngx.say(cjson.encode(r));
        return;
    end
    r.success = true;
    r.info = '删除成功'
    ngx.say(cjson.encode(r));
end


--- 个人博客博文删除
local function deleteArticle()
    local ids = request:getStrParam("ids", true, true)
    local _ids = Split(ids, ",")

    local result = blogManagerService.deleteArticle(_ids)
    local r = { success = false, info = '' }
    if result > 0 then --影响行数.
        r.success = true;
        r.info = '删除成功'
        ngx.say(cjson.encode(r));
        return;
    end
    r.info = '删除失败.'
    ngx.say(cjson.encode(r));
end

--- 个人博客博文移动.
local function moveArticle()
    local ids = request:getStrParam("ids", true, true)
    local _ids = cjson.decode(ids)
    log.debug(_ids);
    local dest_category_id = request:getStrParam("dest_category_id", true, true)
    local result = blogManagerService.moveArticle(dest_category_id, _ids)
    local r = { success = false, info = '' }
    if result > 0 then --影响行数.
        r.success = true;
        r.info = '移动成功'
        ngx.say(cjson.encode(r));
        return;
    end
    r.info = '移动失败.'
    ngx.say(cjson.encode(r));
end

--- 个人博客博文移动.
local function getArticleById()
    local id = request:getStrParam("id", true, true)
    local result = blogManagerService.getArticleById(id)
    log.debug(result)
    local r = { success = false }
    if result then
        result.success = true
        ngx.say(cjson.encode(result));
        return;
    end
    r.info = "此id对应的文章不存在."
    ngx.say(cjson.encode(r));
end

--- 个人博客博文修改
local function updateArticle()
    local id = request:getStrParam("id", true, true)
    local person_category_id = request:getStrParam("person_category_id", true, true)
    local overview = request:getStrParam("overview", false, true)
    local title = request:getStrParam("title", true, true)
    local thumb_id = request:getStrParam("thumb_id", false, true)
    local thumb_ids = request:getStrParam("thumb_ids", false, true)
    local content = request:getStrParam("content", true, true)
    local org_category_id = request:getStrParam("org_category_id", false, true)

    local result = blogManagerService.updateArticle({
        id = id,
        person_category_id = person_category_id,
        overview = overview,
        title = title,
        thumb_id = thumb_id,
        thumb_ids = thumb_ids,
        content = content,
        org_category_id = org_category_id
    })
    local r = { success = false, info = '' }
    if result > 0 then
        r.success = true
        r.info = '修改成功'
        ngx.say(cjson.encode(r));
        return;
    end
    ngx.say(cjson.encode(r));
end


local function getBlogInfo()
    local org_person_id = request:getStrParam("org_person_id", true, true)
    local identity_id = request:getStrParam("identity_id", true, true)
    local result = blogManagerService.getBlogInfo(org_person_id, identity_id);

    log.debug(result);

    if result then
        local aService = require "space.services.PersonAndOrgBaseInfoService"
        local t = {}
        table.insert(t, { person_id = org_person_id, identity_id = identity_id });
        local rt = aService:getPersonBaseInfoByPersonIdAndIdentityId(t)
        -- log.debug(rt);

        if rt and TableUtil:length(rt) > 0 then
            result.logo = rt[1].avatar_fileid;
            result.person_name = rt[1].person_name;
        end
    else
        result = {}
    end
    if result and TableUtil:length(result) > 0 then
        result.success = true;
    else
        result.success = false;
    end
    --  log.debug(result);
    ngx.say(cjson.encode(result));
end


local function saveBlog()
    local name = request:getStrParam("name", true, true)
    local logo = request:getStrParam("logo", false, true)
    local check_status = request:getStrParam("check_status", false, true)
    local identity_id = request:getStrParam("identity_id", true, true)
    local signature = request:getStrParam("signature", false, true)
    local theme_id = request:getStrParam("theme_id", true, true)
    local province_id = request:getStrParam("province_id", false, true)
    local city_id = request:getStrParam("city_id", false, true)
    local district_id = request:getStrParam("district_id", false, true)
    local school_id = request:getStrParam("school_id", false, true)
    local org_person_id = request:getStrParam("org_person_id", true, true)
    local param = {
        name = name,
        logo = logo,
        check_status = check_status,
        identity_id = identity_id,
        signature = signature,
        theme_id = theme_id,
        province_id = province_id,
        city_id = city_id,
        district_id = district_id,
        school_id = school_id,
        org_person_id = org_person_id
    }
    local status, result = pcall(blogManagerService.saveBlog, param)
    local r = { success = false }


    if status and result then
        r.success = true;
        r.id = result;
        ngx.say(cjson.encode(r));
        return;
    end
    r.info = result;
    ngx.say(cjson.encode(r));
end


local function updateBlog()
    local name = request:getStrParam("name", true, true)
    local logo = request:getStrParam("logo", false, true)
    local check_status = request:getStrParam("check_status", false, true)
    local signature = request:getStrParam("signature", false, true)
    local theme_id = request:getStrParam("theme_id", true, true)
    local org_person_id = request:getStrParam("org_person_id", true, true)
    local identity_id = request:getStrParam("identity_id", true, true)
    local id = request:getStrParam("id", true, true)
    local param = { name = name, logo = logo, check_status = check_status, signature = signature, theme_id = theme_id, id = id, org_person_id = org_person_id, identity_id = identity_id }
    local status, result = pcall(blogManagerService.updateBlog, param)
    local r = { success = false }
    if status and result > 0 then
        r.success = true;
        ngx.say(cjson.encode(r));
        return;
    end
    r.info = result;
    ngx.say(cjson.encode(r));
end

local function search()
    log.debug("search")
    local org_id = request:getStrParam("org_id", false, true)
    local org_type = request:getStrParam("org_type", false, true)
    local search_key = request:getStrParam("search_key", false, true)
    local search_type = request:getStrParam("search_type", true, true)
    local identity_id = request:getStrParam("identity_id", false, true)
    local pagenum = request:getStrParam("pagenum", false, true)
    local pagesize = request:getStrParam("pagesize", false, true)
    local person_id = request:getStrParam("person_id", false, true)

    local start_time = request:getStrParam("start_time", false, true)
    local end_time = request:getStrParam("end_time", false, true)

    local category_id = request:getStrParam("category_id", false, true)
    local business_type = request:getStrParam("business_type", true, true)

    local param = { org_id = org_id, search_type = search_type, org_type = org_type, search_key = search_key, identity_id = identity_id, pagenum = pagenum, pagesize = pagesize, person_id = person_id, start_time = start_time, end_time = end_time, category_id = category_id, business_type = business_type }
    log.debug(param)
    local result = blogManagerService.personArticleList(param)
    if result then
        cjson.encode_empty_table_as_object(false)
        result.success = true;
    end
    ngx.say(cjson.encode(result))
end


local function saveArticle()
    local person_category_id = request:getStrParam("person_category_id", true, true)
    local overview = request:getStrParam("overview", false, true)
    local title = request:getStrParam("title", true, true)
    local thumb_id = request:getStrParam("thumb_id", false, true)
    local thumb_ids = request:getStrParam("thumb_ids", false, true)
    -- local blog_id = request:getStrParam("blog_id", false, true)
    local person_id = request:getStrParam("person_id", true, true)
    local person_name = request:getStrParam("person_name", true, true)
    local identity_id = request:getStrParam("identity_id", true, true)
    local org_category_id = request:getStrParam("org_category_id", false, true)
    local stage_id = request:getStrParam("stage_id", false, true)
    local stage_name = request:getStrParam("stage_name", false, true)
    local subject_id = request:getStrParam("subject_id", false, true)
    local subject_name = request:getStrParam("subject_name", false, true)
    local province_id = request:getStrParam("province_id", false, true)
    local city_id = request:getStrParam("city_id", false, true)
    local district_id = request:getStrParam("district_id", false, true)
    local school_id = request:getStrParam("school_id", false, true)
    local business_type = request:getStrParam("business_type", true, true)
    local content = request:getStrParam("content", true, true)
    log.debug(content);
    local param = {
        person_category_id = person_category_id,
        overview = overview,
        title = title,
        thumb_id = thumb_id,
        thumb_ids = thumb_ids,
        -- blog_id = blog_id,
        person_id = person_id,
        person_name = person_name,
        identity_id = identity_id,
        org_category_id = org_category_id,
        stage_id = stage_id,
        stage_name = stage_name,
        subject_id = subject_id,
        subject_name = subject_name,
        province_id = province_id,
        city_id = city_id,
        district_id = district_id,
        school_id = school_id,
        business_type = business_type,
        content = content;
    }
    local id = blogManagerService.saveArticle(param)
    local result = {}
    if result then
        cjson.encode_empty_table_as_object(false)
        result.id = id;
        result.success = true;
    end
    ngx.say(cjson.encode(result))
end

------------------------------------------------------------------------------------------------------------------------
-- 对评论次数加1
local function addCommentNum()
    local article_id = request:getStrParam("article_id", true, true) --博文id.
    local blog_id = request:getStrParam("blog_id", true, true) --博客id
    local result = blogManagerService.addCommentNum(blog_id, article_id);
    local r = { success = true, info = "添加成功" }
    if not result then
        r.success = false;
        r.info = "添加失败."
    end
    ngx.say(cjson.encode(r))
end

------------------------------------------------------------------------------------------------------------------------
-- 对评浏览数加1
local function addBrowseNum()
    local article_id = request:getStrParam("article_id", true, true) --博文id.
    local blog_id = request:getStrParam("blog_id", true, true) --博客id
    local result = blogManagerService.addBrowseNum(blog_id, article_id);
    local r = { success = true, info = "添加成功" }
    if not result then
        r.success = false;
        r.info = "添加失败."
    end
    ngx.say(cjson.encode(r))
end


local function setShow()
    local ids = request:getStrParam("ids", true, true) --博客博文id,支持多个.ids 逗号分隔.
    local org_type = request:getStrParam("org_type", true, true) --设置显示机构级别.
    local is_cancel = request:getStrParam("is_cancel", false, true) --是否取消
    local _ids = Split(ids, ",")
    local status, err = pcall(blogService.setShow, { ids = _ids, org_type = org_type, is_cancel = is_cancel })
    if status then
        ngx.say(cjson.encode({ success = true }))
    else
        ngx.say(cjson.encode({ success = false, info = err }))
    end
    return;
end

local function setBest()
    local ids = request:getStrParam("ids", true, true) --博客博文id,支持多个.ids 逗号分隔.
    local org_type = request:getStrParam("org_type", true, true) --设置精华机构级别.
    local is_cancel = request:getStrParam("is_cancel", false, true) --是否取消
    local _ids = Split(ids, ",")
    local status, err = pcall(blogService.setBest, { ids = _ids, org_type = org_type, is_cancel = is_cancel })
    if status then
        ngx.say(cjson.encode({ success = true }))
    else
        ngx.say(cjson.encode({ success = false, info = err }))
    end
    return;
end

local function setRecommend()
    local ids = request:getStrParam("ids", true, true) --博客博文id,支持多个.ids 逗号分隔.
    local explain = request:getStrParam("explain", false, true) --博客博文推荐说明
    local from_id = request:getStrParam("from_id", true, true)
    local from_level = request:getStrParam("from_level", true, true)
    local to_id = request:getStrParam("to_id", true, true)
    local to_level = request:getStrParam("to_level", true, true)
    local _ids = Split(ids, ",")
    local status, err = pcall(blogService.setRecommend, { ids = _ids, explain = explain, from_id = from_id, from_level = from_level, to_id = to_id, to_level = to_level })
    if status then
        ngx.say(cjson.encode({ success = true }))
    else
        ngx.say(cjson.encode({ success = false, info = err }))
    end
    return;
end



local function getExcellentBlog()
    local org_type = request:getStrParam("org_type", true, true)
    local org_id = request:getStrParam("org_id", true, true)
    local page_size = request:getNumParam("page_size", true, true)
    local page_num = request:getNumParam("page_num", true, true)
    local name = request:getStrParam("name", false, true);
    name = ngx.decode_base64(name)
    local identity_id = request:getStrParam("identity_id", true, true)

    local display = request:getStrParam("display", false, true)
    local param = { org_type = org_type, org_id = org_id, page_num = page_num, page_size = page_size, name = name, display = display, identity_id = identity_id };
    local result = blogService.getExcellentBlog(param)
    cjson.encode_empty_table_as_object(false)
    if result then
        result.success = true;
    else
        result.success = false;
        result.info = "查询失败."
    end
    ngx.say(cjson.encode(result));
    return;
end

local function setExcellentBlog()
    local org_person_id = request:getStrParam("org_person_id", true, true)
    local identity_id = request:getStrParam("identity_id", true, true)
    local province_id = request:getStrParam("province_id", true, true)
    local city_id = request:getStrParam("city_id", true, true)
    local district_id = request:getStrParam("district_id", true, true)
    local school_id = request:getStrParam("school_id", true, true)
    local org_type = request:getStrParam("org_type", true, true)
    local business_type = request:getStrParam("business_type", false, true)
    local is_cancel = request:getStrParam("is_cancel", false, true)

    local param =
    {
        org_person_id = org_person_id,
        identity_id = identity_id,
        province_id = province_id,
        city_id = city_id,
        district_id = district_id,
        school_id = school_id,
        org_type = org_type,
        business_type = business_type,
        is_cancel = is_cancel,
    }
    local r = blogService.setExcellentBlog(param);
    if r then
        ngx.say(cjson.encode({ success = true, info = '保存成功.' }));
    else
        ngx.say(cjson.encode({ success = false, info = '保存失败.' }))
    end
    return;
end


local function orgArticleList()
    local org_id = request:getStrParam("org_id", false, true)
    local org_type = request:getStrParam("org_type", false, true)
    local search_key = request:getStrParam("search_key", false, true)
    local search_type = request:getStrParam("search_type", true, true)
    local identity_id = request:getStrParam("identity_id", false, true)
    local pagenum = request:getStrParam("pagenum", false, true)
    local pagesize = request:getStrParam("pagesize", false, true)
    local person_id = request:getStrParam("person_id", false, true)
    local start_time = request:getStrParam("start_time", false, true)
    local end_time = request:getStrParam("end_time", false, true)
    local category_id = request:getStrParam("category_id", false, true)
    local business_type = request:getStrParam("business_type", true, true)
    local from_id = request:getStrParam("from_id", false, true)
    local to_id = request:getStrParam("to_id", false, true)
    local tab_type = request:getStrParam("tab_type", false, false)
    local param = {
        org_id = org_id,
        org_type = org_type,
        search_key = search_key,
        search_type = search_type,
        identity_id = identity_id,
        pagenum = pagenum,
        pagesize = pagesize,
        person_id = person_id,
        start_time = start_time,
        end_time = end_time,
        category_id = category_id,
        business_type = business_type,
        from_id = from_id,
        to_id = to_id,
        tab_type = tab_type,
    }
    log.debug(param);
    local result = blogService.orgArticleList(param);
    --log.debug(result);
    result.success = true;
    cjson.encode_empty_table_as_object(false)
    ngx.say(cjson.encode(result));
    return;
end

local function getOrgBlogStat()
    local org_id = request:getStrParam("org_id", true, true)
    local org_type = request:getStrParam("org_type", true, true);
    local identity_id = request:getStrParam("identity_id", false, true);
    local category_id = request:getStrParam("category_id", false, true);
    log.debug(category_id);
    local param = { org_id = org_id, org_type = org_type, identity_id = identity_id, category_id = category_id }
    local result = blogService.getOrgBlogStat(param)
    cjson.encode_empty_table_as_object(false)
    if result then
        result.success = true;
    end
    ngx.say(cjson.encode(result));
end


local function initCategory()
    local result = blogService.initDb()

    ngx.say(cjson.encode(result))
end







-- 配置url.
-- 按功能分
local urls = {
    context .. '/savePersonCategory', savePersonCategory, --保存个人分类
    context .. '/updatePersonCategory', updatePersonCategory, --2)	修改个人分类
    context .. '/updateCategoryOrder', updatePersonCategoryOrder, --修改个人分类顺序.
    context .. '/getCategory', getCategory, --个人分类查询 .
    context .. '/deletPersonCategoryByIds', deletPersonCategoryByIds, --个人分类删除.
    context .. '/deleteArticle', deleteArticle, --个人博客博文 删除.
    context .. '/moveArticle', moveArticle, --个人博客博文管理.移动
    no_permission_context .. '/getArticleById', getArticleById, --个人博客博文查看.
    context .. '/updateArticle', updateArticle, --个人博客博文修改.
    context .. '/getBlogInfo', getBlogInfo, --获取博客信息.
    context .. '/saveBlog', saveBlog, --保存博客.
    context .. '/updateBlog', updateBlog, --更新博客.
    no_permission_context .. '/search', search, --搜索文章.
    context .. '/saveArticle', saveArticle, --保存博客博文文章.
    no_permission_context .. "/initCategory", initCategory, --数据库初始化分类.
    no_permission_context .. "/addCommentNum", addCommentNum, --添加评论次数。
    no_permission_context .. "/addBrowseNum", addBrowseNum, --添加浏览次数
    context .. '/setShow', setShow, --机构博客博文设置显示.
    context .. '/setBest', setBest, --机构博客博文设置精华.
    context .. '/setRecommend', setRecommend, --机构博客博文设置推荐
    no_permission_context .. '/getExcellentBlog', getExcellentBlog, --获取优秀博客
    context .. '/setExcellentBlog', setExcellentBlog, --设置优秀博客.
    no_permission_context .. '/orgArticleList', orgArticleList, --机构博客博文搜所.
    no_permission_context .. '/getOrgBlogStat', getOrgBlogStat --机构博客统计，
}
local app = web.application(urls, nil)
app:start()

