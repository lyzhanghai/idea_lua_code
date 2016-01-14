--
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2016/1/9 0009
-- Time: 上午 9:10
-- To change this template use File | Settings | File Templates.
--
local baseDao = require("social.dao.CommonBaseDao")
local Constant = require("space.blog.constant.Constant")
local bit = require("social.common.bit")
local DBUtil = require "social.common.mysqlutil";
local TableUtil = require("social.common.table")
local quote = ngx.quote_sql_str
local log = require("social.common.log")
local TS = require "resty.TS"
local _M = {}


local function getBit(b)
    local r = bit:getInTable(b)
    return table.concat(r, ",");
end

--计算分页.
local function calculatePage(pageNumber, pageSize, totalRow)
    local _pagenum = tonumber(pageNumber)
    local _pagesize = tonumber(pageSize)
    local totalRow = totalRow
    local totalPage = math.floor((totalRow + _pagesize - 1) / _pagesize)
    if totalPage > 0 and tonumber(pageNumber) > totalPage then
        _pagenum = totalPage
    end
    local offset = _pagesize * _pagenum - _pagesize
    return offset, _pagesize, totalPage
end

function _M.getExcellent(org_person_id, identity_id, org_type, person_id)
    -- log.debug("org_type:" .. org_type);
    local _org_type = Constant.BIT_FLAG[tonumber(org_type)];
    -- log.debug(_org_type);
    local excellent = table.concat(bit:getInTable(_org_type), ",");
    --local o_type = Constant.ORG_TABLE_MAPPING[tonumber(org_type)];
    local sql = "SELECT * FROM T_SOCIAL_EXCELLENT WHERE IDENTITY_ID=%s AND ORG_PERSON_ID=%s AND EXCELLENT IN (%s) AND EXCELLENT<>0";
    sql = string.format(sql, identity_id, person_id, excellent);
    log.debug("查询优秀sql:");
    log.debug(sql)
    local db = DBUtil:getDb();
    local result = db:query(sql);
    return result;
end

--
--获取优秀机构博客博文的count
function _M.getExcellentOrgBlogCount(param)
    local db = DBUtil:getDb();
    local _org_type = Constant.BIT_FLAG[tonumber(param.org_type)];
    local excellent = getBit(_org_type);
    local o_type = Constant.ORG_TABLE_MAPPING[tonumber(param.org_type)];
    local count_sql = "SELECT COUNT(ID) AS TOTALROW FROM T_SOCIAL_EXCELLENT WHERE IDENTITY_ID=%s AND %s=%s  AND EXCELLENT IN (%s) AND EXCELLENT<>0";
    count_sql = string.format(count_sql, param.identity_id, o_type, param.org_id, excellent);
    local c_result = db:query(count_sql);
    if TableUtil:length(c_result) == 0 then
        return 0;
    end
    log.debug("获取优秀列表.count:" .. c_result[1]['TOTALROW']);
    return c_result[1]['TOTALROW']
end

--获取优秀机构博客博文的list
--@return table result,int totalPage,int count
function _M.getExcellentOrgBlogList(param)
    local count = _M.getExcellentOrgBlogCount(param);
    local db = DBUtil:getDb();
    local _org_type = Constant.BIT_FLAG[tonumber(param.org_type)];
    local excellent = getBit(_org_type);
    local o_type = Constant.ORG_TABLE_MAPPING[tonumber(param.org_type)];
    local sql = "SELECT * FROM T_SOCIAL_EXCELLENT WHERE IDENTITY_ID=%s AND %s=%s  AND EXCELLENT IN (%s) AND EXCELLENT<>0";
    sql = string.format(sql, param.identity_id, o_type, param.org_id, excellent);
    local offset, _pagesize, totalPage = calculatePage(param.page_num, param.page_size, count);
    sql = sql .. " LIMIT " .. offset .. "," .. _pagesize
    log.debug("查询优秀sql:");
    log.debug(sql)
    local result = db:query(sql);
    return result, totalPage, count;
end

--设置优秀（可保存，可修改）
function _M.setExcellentBlog(param)
    log.debug("设置优秀.")
    local db = DBUtil:getDb()
    local org_type_k = tonumber(param.org_type);
    local org_type = Constant.BIT_FLAG[org_type_k];

    log.debug(org_type)
    local logic = (param.is_cancel and "^") or "|"; --如果是加显示则执行or 操作加入权限，如果是取消显示，则做异或运算。
    local querysql = "SELECT ID FROM T_SOCIAL_EXCELLENT T WHERE T.ORG_PERSON_ID = %s";
    querysql = string.format(querysql, param.org_person_id);
    local result = db:query(querysql);
    local sql;
    if result and result[1] then
        sql = "UPDATE T_SOCIAL_EXCELLENT T SET T.EXCELLENT=(T.EXCELLENT%s%s) WHERE T.ORG_PERSON_ID=%s"
        sql = string.format(sql, logic, org_type, param.org_person_id);
    else
        param.is_cancel = nil;
        param.org_type = nil;
        param.excellent = org_type;
        local columns = TableUtil:keys(param);
        local values = TableUtil:values(param);
        local v = {}
        for i = 1, #values do
            table.insert(v, quote(values[i]))
        end
        sql = "INSERT INTO `%s` (`%s`) VALUES (%s)";
        sql = string.format(sql, "T_SOCIAL_EXCELLENT", table.concat(columns, "`,`"), table.concat(v, ","))
    end
    log.debug(sql);
    local saveOrUpdateResult = db:query(sql)
    --如果是修改，返回影响行数，如果是保存，则返回保存的id.
    return (result and result[1]) and saveOrUpdateResult.affected_rows or saveOrUpdateResult.insert_id
end



--机构博客博文设置推荐
function _M.setRecommendDb(param)
    local db = DBUtil:getDb();
    local recommenIds = {};
    db:query("START TRANSACTION;")
    local status, err = pcall(function()
        for i = 1, #param.ids do
            local sql = "INSERT INTO `%s` (%s) VALUES (%s)";
            sql = string.format(sql, "T_SOCIAL_BLOG_RECOMMEND", "ARTICLE_ID,FROM_ID,FROM_LEVEL,TO_ID,TO_LEVEL,`EXPLAIN`,TS,UPDATE_TS", quote(param.ids[i]) .. "," .. quote(param.from_id) .. "," .. quote(param.from_level) .. "," .. quote(param.to_id) .. "," .. quote(param.to_level) .. "," .. quote(param.explain) .. "," .. quote(TS.getTs()) .. "," .. quote(TS.getTs()));
            log.debug(sql);
            local result = db:query(sql);
            log.debug(result)
            --TODO:此处需要加入对主表的update_ts进行修改。

            local master_table_sql = "UPDATE T_SOCIAL_BLOG_ARTICLE SET UPDATE_TS=%s WHERE ID=%s";
            master_table_sql = string.format(master_table_sql, TS.getTs(), quote(param.ids[i]));
            local update_result = db:query(master_table_sql);

            if not result or not update_result or update_result.affected_rows <= 0 then
                error("保存失败.") --TODO:保存失败.
            end
            table.insert(recommenIds, result.insert_id)
        end
    end)
    if status then
        db:query("COMMIT;")
        return recommenIds;
    else
        log.debug("保存存推荐信息出错.")
        db:query("ROLLBACK;")
        error("保存推荐信息出错.")
    end
end

--根据机构id获取此机构下的博文总数.
--@param string param.org_id
--@param string param.orgtype
--@return int
function _M.getBlogArticleCount(param)
    local db = DBUtil:getDb()
    local org_id = param.org_id;
    local org_type = param.org_type;
    local o_type = Constant.ORG_TABLE_MAPPING[tonumber(org_type)];
    local category_filter = (not param.category_id or string.len(param.category_id)==0) and "" or " AND ORG_CATEGORY_ID="..param.category_id;
    local identity_filter = (not param.identity_id or string.len(param.identity_id)==0) and "" or " AND IDENTITY_ID="..param.identity_id;

    local sql = "SELECT COUNT(ID) AS C FROM T_SOCIAL_BLOG_ARTICLE T WHERE T.IS_DEL=0 AND T.%s=%s"..category_filter..identity_filter;
    log.debug(sql);
    sql = string.format(sql, o_type, org_id);
    local result = db:query(sql);
    if result then
        return result[1]['C'];
    end
    return 0;
end

--根据机构id获取今日新增博文（去掉删除的）
--@param string param.org_id
--@param string param.orgtype
--@return int
function _M.getBlogArticleCurrentDayCount(param)

    local db = DBUtil:getDb()
    local org_id = param.org_id;
    local org_type = param.org_type;
    local o_type = Constant.ORG_TABLE_MAPPING[tonumber(org_type)];

    local category_filter = (not param.category_id or string.len(param.category_id)==0) and "" or " AND ORG_CATEGORY_ID="..param.category_id;
    local identity_filter = (not param.identity_id or string.len(param.identity_id)==0) and "" or " AND IDENTITY_ID="..param.identity_id;
    local sql = "SELECT COUNT(T.ID) AS C FROM T_SOCIAL_BLOG_ARTICLE T WHERE T.IS_DEL=0 AND T." .. o_type .. "=" .. org_id .. " AND DATE_FORMAT(T.CREATE_TIME, '%Y-%m-%d')=DATE_FORMAT(now(), '%Y-%m-%d')"..identity_filter..category_filter;
    log.debug(sql);
    local result = db:query(sql);
    if result then
        return result[1]['C'];
    end
    return 0;
end

--根据机构id获取博客博文的总浏览数.(去掉删除的)
--@param string param.org_id
--@param string param.orgtype
function _M.getBlogArticleBrowseCount(param)
    local db = DBUtil:getDb()
    local org_id = param.org_id;
    local org_type = param.org_type;
    local o_type = Constant.ORG_TABLE_MAPPING[tonumber(org_type)];
    log.debug(param);
    local category_filter = (not param.category_id or string.len(param.category_id)==0) and "" or " AND ORG_CATEGORY_ID="..param.category_id;
    local identity_filter = (not param.identity_id or string.len(param.identity_id)==0) and "" or " AND IDENTITY_ID="..param.identity_id;
    local sql = "SELECT IFNULL(SUM(T.BROWSE_NUM),0) AS S FROM T_SOCIAL_BLOG_ARTICLE T WHERE T.IS_DEL=0 AND T.%s=%s"..category_filter..identity_filter;
    log.debug(sql);
    sql = string.format(sql, o_type, org_id);
    local result = db:query(sql);
    log.debug(result);
    if result then
        return result[1]['S'] ;
    end
    return 0;
end

--根据机构id获取博客博文的总评论数.
function _M.getBlogArticleCommentCount(param)
    local db = DBUtil:getDb()
    local org_id = param.org_id;
    local org_type = param.org_type;
    local o_type = Constant.ORG_TABLE_MAPPING[tonumber(org_type)];
    local category_filter = (not param.category_id or string.len(param.category_id)==0) and "" or " AND ORG_CATEGORY_ID="..param.category_id;
    local identity_filter = (not param.identity_id or string.len(param.identity_id)==0) and "" or " AND IDENTITY_ID="..param.identity_id;
    local sql = "SELECT IFNULL(SUM(T.COMMENT_NUM),0)  AS S FROM T_SOCIAL_BLOG_ARTICLE T WHERE T.IS_DEL=0 AND T.%s=%s"..category_filter..identity_filter;
    log.debug(sql);
    sql = string.format(sql, o_type, org_id);
    local result = db:query(sql);
    if result then
        return result[1]['S'];
    end
    return 0;
end


--更新数据库
function _M.setBestDb(param, func)
    local ids = param.ids;
    local org_type_k = tonumber(param.org_type);
    local org_type = Constant.BIT_FLAG[org_type_k];
    local db = DBUtil:getDb();
    local ts = TS.getTs();
    db:query("START TRANSACTION;")
    local logic = (param.is_cancel and "^") or "|"; --如果是加显示则执行or 操作加入权限，如果是取消显示，则做异或运算。
    local status, err = pcall(function()
        local sql = "UPDATE T_SOCIAL_BLOG_ARTICLE T SET T.UPDATE_TS=%s,T.BEST=(T.BEST%s%s) WHERE T.ID IN (%s)"
        sql = string.format(sql, ts, logic, org_type, table.concat(ids, ","));
        log.debug(sql);
        local result = db:query(sql);
        if not result then
            error("更新出错.")
        end
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




function _M.setShowDb(param, func)
    local ids = param.ids;
    local org_type_k = tonumber(param.org_type);
    local org_type = Constant.BIT_FLAG[org_type_k];
    local db = DBUtil:getDb();
    local ts = TS.getTs();
    db:query("START TRANSACTION;")
    local status, err = pcall(function()
        for i = 1, #ids do
            local sql = "UPDATE T_SOCIAL_BLOG_ARTICLE T SET T.UPDATE_TS=%s,T.SHOW=%s WHERE T.ID=%s"
            local sql_byid = "SELECT IFNULL(T.SHOW,0) AS _SHOW FROM T_SOCIAL_BLOG_ARTICLE T WHERE T.ID=%s";
            sql_byid = string.format(sql_byid, ids[i]);
            log.debug(sql_byid)
            local result = db:query(sql_byid)
            log.debug(result)
            if result then
                local show = result[1]['_SHOW'];
                -- 如果是加显示则执行or 操作加入权限，如果是取消显示，则做异或运算。
                local value = (param.is_cancel and bit:_xor(tonumber(show), org_type)) or bit:_or(tonumber(show), org_type);
                sql = string.format(sql, ts, value, ids[i]);
                log.debug(sql)
                local _result = db:query(sql)
                if not _result and _result.affected_rows <= 0 then
                    error("更新出错.")
                end
            end
        end
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
local function getFilter(param)
    local tab_type = param.tab_type;
    log.debug(tab_type)
    local tab_types = Split(tab_type, ",")
    log.debug(tab_types)
    local showFilter = "";
    local bestFilter = "";
    local recommondFilter = "";
    for i = 1, #tab_types do
        if tonumber(tab_types[i]) == 1 then --1门户显示
            local show = getBit(Constant.BIT_FLAG[tonumber(param.org_type)]);
            showFilter = "filter=show," .. show .. ";"
        elseif tonumber(tab_types[i]) == 2 then --,2.本级精华
            local best = getBit(Constant.BIT_FLAG[tonumber(param.org_type)]);
            bestFilter = "filter=best," .. best .. ";"
        elseif tonumber(tab_types[i]) == 3 then --3.推荐
            recommondFilter = "!filter=is_recommend,0;"
        elseif tonumber(tab_types[i]) == 4 then --4. 推荐给上级的
            recommondFilter = "filter=from_id," .. param.from_id .. ";" .. "filter=to_id," .. param.to_id .. ";";
        elseif tonumber(tab_types[i] == 5) then --5下级推荐的
            recommondFilter = "filter=to_id," .. param.to_id .. ";"
        end
    end
    return showFilter, bestFilter, recommondFilter;
end

function _M.orgArticleList(param)
    local str_maxmatches = "10000"
    local offset = param.pagesize * param.pagenum - param.pagesize
    local limit = param.pagesize


    local sql = "SELECT SQL_NO_CACHE id FROM T_SOCIAL_BLOG_ARTICLE_RECOMMEND_SPHINXSE  WHERE query='%s%sfilter=is_del,0;maxmatches=" .. str_maxmatches .. ";offset=" .. offset .. ";limit=" .. limit .. "';SHOW ENGINE SPHINX STATUS;";
    --local searchKeyFilter = ((param.search_key == nil or string.len(param.search_key) == 0) and "") or ngx.decode_base64(param.search_key) .. ";"
    local searchKeyFilter = ""
    if param.search_key and string.len(param.search_key) > 0 and param.search_type and string.len(param.search_type) > 0 then
        searchKeyFilter = "mode=extended2;@(" .. param.search_type .. ") " .. ngx.decode_base64(param.search_key) .. ";"
    end

    local personIdFilter = ((param.person_id == nil or string.len(param.person_id) == 0) and "") or "filter=person_id," .. param.person_id .. ";"
    local identityIdFilter = ((param.identity_id == nil or string.len(param.identity_id) == 0) and "") or "filter=identity_id," .. param.identity_id .. ";"
    local businessTypeFilter = ((param.business_type == nil or string.len(param.business_type) == 0) and "") or "filter=business_type," .. param.business_type .. ";"
    local org_level = Constant.ORG_TABLE_MAPPING[tonumber(param.org_type)]; --通过机构级别，动态映射数据表列名.
    local orgTypeFilter = ((param.org_id == nil or string.len(param.org_id) == 0) and "") or "filter=" .. org_level .. "," .. param.org_id .. ";"
    local showFilter = "";
    local bestFilter = "";
    local recommondFilter = "";
    log.debug(param.tab_type);
    showFilter, bestFilter, recommondFilter = getFilter(param)
    local categoryIdTypeFilter = ((param.category_id == nil or string.len(param.category_id) == 0) and "!filter=org_category_id,0") or "filter=org_category_id," .. param.category_id .. ";"
    local _filterDate = ((param.start_time == nil or string.len(param.start_time) == 0) and "") or "range=create_time," .. param.start_time .. "," .. param.end_time .. ";"
    local sort = "sort=extended:top desc,ts desc;"
    local queryFilter = searchKeyFilter .. personIdFilter .. identityIdFilter .. businessTypeFilter .. categoryIdTypeFilter .. _filterDate .. sort;
    local orgFilter = orgTypeFilter .. showFilter .. bestFilter .. recommondFilter;
    sql = string.format(sql, queryFilter, orgFilter)
    log.debug("sql :" .. sql)
    local db = DBUtil:getDb();
    local res = db:query(sql)
    local res1 = db:read_result()
    local _, s_str = string.find(res1[1]["Status"], "found: ")
    local e_str = string.find(res1[1]["Status"], ", time:")
    local totalRow = string.sub(res1[1]["Status"], s_str + 1, e_str - 1)
    local totalPage = math.floor((totalRow + param.pagesize - 1) / param.pagesize)
    return res,totalRow,totalPage;
end

return baseDao:inherit(_M):init()