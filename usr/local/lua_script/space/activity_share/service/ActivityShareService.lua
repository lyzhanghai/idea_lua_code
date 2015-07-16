--
-- Created by IntelliJ IDEA.
-- User: zh
-- Date: 2015/7/13
-- Time: 13:58
-- To change this template use File | Settings | File Templates.
--

local log = require("social.common.log")
local SsdbUtil = require("social.common.ssdbutil")
local TS = require "resty.TS"
local TableUtil = require("social.common.table")
local DBUtil = require "common.DBUtil";
local quote = ngx.quote_sql_str
local _M = {}
--------------------------------------------------------------------
local function checkParamIsNull(t)
    for key, var in pairs(t) do
        if var == nil or string.len(var) == 0 then
            error(key .. " 不能为空.")
        end
    end
end

-------------------------------------------------------------
-- 获取快乐分享列表
-- {
-- Success:true
-- "pageNumber": 1,
-- "totalPage": 总页数,
-- "totalRow":总记录数,
-- "pageSize":每页条数,
-- list:[{
-- title:标题，
-- view_num:查看次数，
-- reply_num：评论次数.
-- create_date:创建日期
-- id: id
-- },{}]
-- }
local function listFromDb(param)
    local _pagenum = tonumber(param.page_num)
    local _pagesize = tonumber(param.page_size)
    local list_sql = "SELECT id,title,create_date FROM T_SOCIAL_ACTIVITY_SHARE WHERE PERSON_ID=%s AND IDENTITY_ID=%s AND MESSAGE_TYPE=%s"
    list_sql = string.format(list_sql, param.person_id, param.identity_id, param.message_type)
    local count_sql = "SELECT count(id)  as totalRow  FROM T_SOCIAL_ACTIVITY_SHARE WHERE PERSON_ID=%s AND IDENTITY_ID=%s AND MESSAGE_TYPE=%s ORDER BY SEQUENCE"
    count_sql = string.format(count_sql, param.person_id, param.identity_id, param.message_type)
    local count = DBUtil:querySingleSql(count_sql);
    if TableUtil:length(count) == 0 then
        return nil;
    end
    log.debug("获取主题帖列表.count:" .. count[1].totalRow);
    local totalRow = count[1].totalRow
    local totalPage = math.floor((totalRow + _pagesize - 1) / _pagesize)
    local offset = _pagesize * _pagenum - _pagesize

    list_sql = list_sql .. " LIMIT " .. offset .. "," .. _pagesize
    log.debug("获取活动列表.list sql:" .. list_sql);
    local list = DBUtil:querySingleSql(list_sql);
    log.debug(list);
    local result = { list = list, totalRow = totalRow, totalPage = totalPage, pageNum = _pagenum, pageSize = _pagesize }
    return result;
end

local function listFromSSDB(param)
end

function _M.list(param)
    checkParamIsNull(param)
    return listFromDb(param)
end


--Title
--Context
--Person_id
--Person_name
--Identity_id
--Message_type
--File_id
--List:[{
--    File_id
--Style
--Seq
--memo
--},{
--
--}]
-----------------------------------------------------------------------------
-- 保存活动
local function saveToDb(param)
    local db = DBUtil:getDb()
    db:query("START TRANSACTION;")
    local insert_sql_z = "insert  into t_social_activity_share (title,context,person_id,person_name,identity_id,message_type) values (%s,%s,%s,%s,%s,%s);";
    insert_sql_z = string.format(insert_sql_z, quote(param.title), quote(param.context), quote(param.person_id), quote(param.person_name), quote(param.identity_id), quote(param.message_type))
    log.debug(insert_sql_z)
    local queryResultZ = db:query(insert_sql_z);
    local share_id;
    -- db:query("COMMIT;");
    log.debug(queryResultZ)
    if queryResultZ then
        share_id = queryResultZ.insert_id;
        local list = param.list;
        local insert_sql = "insert  into t_social_activity_share_detail (file_id,share_id,memo,sequence,style,source) values "
        local values_sql = ""
        for i = 1, #list do
            local formatstr;
            formatstr = (i == #list and "(%s,%s,%s,%s,%s,%s);") or "(%s,%s,%s,%s,%s,%s),"
            values_sql = values_sql .. string.format(formatstr, quote(list[i].file_id), share_id, quote(list[i].memo), list[i].sequence, quote(list[i].style), quote(list[i].source))
        end
        local sql = insert_sql .. values_sql
        log.debug(sql);
        local r, err, errno, sqlstate = db:query(sql);
        --        log.debug(r)
        --        log.debug(err)
        --        log.debug(errno)
        --        log.debug(sqlstate)
        if not r then
            log.debug("执行ROLLBACK")
            db:query("ROLLBACK;");
            return false
        else
            db:query("COMMIT;");
        end
    else
        db:query("ROLLBACK;");
        return false;
    end
    --local queryResult = DBUtil:querySingleSql(insert_sql .. values_sql);
    DBUtil:keepDbAlive(db);
    return true, share_id
end

local function saveToSSDB(param)
    local key = "social_activity_share_id_" .. param.id;
    local db = SsdbUtil:getDb();
    db:zset("social_activity_share", key, TS.getTs())
    db:multi_hset(key, param);
end

function _M.save(param)
    --  checkParamIsNull(param)
    local result, id = saveToDb(param)
    --    if result then
    --        param.id = id;
    --        saveToSSDB(param);
    --    end
    return result;
end

-----------------------------------------------------------------------------
-- 删除 活动
local function deleteToDb(id)
    local db = DBUtil:getDb()
    db:query("START TRANSACTION;")
    local delete_sql = "UPDATE T_SOCIAL_ACTIVITY_SHARE SET IS_DELETE = 1 WHERE ID = " .. id
    local result = db:query(delete_sql)
    if result.affected_rows > 0 then
        local delete_detail_sql = "UPDATE T_SOCIAL_ACTIVITY_SHARE_DETAIL SET IS_DELETE = 1 WHERE SHARE_ID = " .. id
        local r = db:query(delete_detail_sql)
        if r then
            db:query("COMMIT;")
        else
            db:query("ROLLBACK;");
            return false;
        end
    end
    DBUtil:keepDbAlive(db);
    return true;
end

local function deleteToSSDB(id)
    local db = SsdbUtil:getDb()
    local key = "social_activity_share_id_" .. id;
    db:zdel("social_activity_share", key)
    db:hclear(key);
end

function _M.delete(id)
    checkParamIsNull({ id = id })
    local result = deleteToDb(id);
    return result;
    --    if result then
    --        deleteToSSDB(id)
    --        return true;
    --    end
    --    return false;
end

---------------------------------------------------------------------------------------------------------------
-- 删除活动中的某一个照片.
function _M.deleteDetail(id)
    checkParamIsNull({ id = id })
    local db = DBUtil:getDb()
    local delete_detail_sql = "UPDATE T_SOCIAL_ACTIVITY_SHARE_DETAIL SET IS_DELETE = 1 WHERE SHARE_ID = " .. id
    local r = db:query(delete_detail_sql)
    if r.affected_rows > 0 then
        return true;
    end
    return false;
end


-----------------------------------------------------------------------------
-- 修改活动
-- Id
-- Title
-- Context
-- Person_id
-- Person_name
-- Identity_id
-- Message_type
-- File_id
-- List:[{
-- File_id
-- Style
-- Seq
-- memo
-- },{
--
-- }]
function _M.update(param)
    local db = DBUtil:getDb()
    db:query("START TRANSACTION;")
    local update_sql = "UPDATE T_SOCIAL_ACTIVITY_SHARE SET TITLE = %s,CONTEXT = %s WHERE ID = %s;";
    update_sql = string.format(update_sql, quote(param.title), quote(param.context), param.id)
    db:query(update_sql) --对主表中的数据进行修改。
    local delete_sql = "DELETE FROM T_SOCIAL_ACTIVITY_SHARE_DETAIL WHERE SHARE_ID = " .. param.id;
    local r1 = db:query(delete_sql) --删除子表中的数据

    local insert_sql = "INSERT INTO T_SOCIAL_ACTIVITY_SHARE_DETAIL (FILE_ID,SHARE_ID,MEMO,SEQUENCE,STYLE,SOURCE) VALUES "
    local values_sql = ""
    for i = 1, #param.list do
        local formatstr;
        formatstr = (i == #param.list and "(%s,%s,%s,%s,%s,%s);") or "(%s,%s,%s,%s,%s,%s),"
        values_sql = values_sql .. string.format(formatstr, quote(param.list[i].file_id), param.id, quote(param.list[i].memo), param.list[i].sequence, quote(param.list[i].style), quote(param.list[i].source))
    end
    local insert_sqls = insert_sql .. values_sql
    log.debug(insert_sqls)
    local r2 = db:query(insert_sqls);
    if r1 and r2 then
        db:query("COMMIT;")
    else
        db:query("ROLLBACK;");
        return false;
    end
    DBUtil:keepDbAlive(db);
    return true;
end

--{
--        title
--context
--id
--list:[
--    {
--        file_id:
--        Memo
--Style
--Create_date
--}
--]
--}

------------------------------------------------------------------------------------
-- 通过id查看 、
function _M.view(id)
    local db = SsdbUtil:getDb();
    local view_sql = "SELECT R1.TITLE,R1.CONTEXT,R1.ID FROM T_SOCIAL_ACTIVITY_SHARE R1 WHERE R1.ID = " .. id
    local view_result = DBUtil:querySingleSql(view_sql);
    local result = { list = {} }
    local view_detail_sql = "SELECT R.FILE_ID,R.MEMO,R.STYLE,R.CREATE_DATE FROM T_SOCIAL_ACTIVITY_SHARE_DETAIL R WHERE R.SHARE_ID = " .. id .. " AND R.IS_DELETE = 0"
    if view_result and #view_result > 0 then
        result.id = view_result[1].ID;
        result.context = view_result[1].CONTEXT;
        result.title = view_result[1].TITLE;
        local count = db.get("social_activity_share_view_.." .. id .. ".._count")
        local view_count = 0
        if count and count[1] and string.len(count[1]) > 0 then
            view_count = tonumber(count[1]);
        end
        result.view_count = view_count;


        local view_detail_result = DBUtil:querySingleSql(view_detail_sql);
        log.debug(view_detail_result)
        if view_detail_result then
            for i = 1, #view_detail_result do
                local temp = {}
                temp.file_id = view_detail_result[i].FILE_ID
                temp.memo = view_detail_result[i].MEMO
                temp.style = view_detail_result[i].STYLE
                temp.create_date = view_detail_result[i].CREATE_DATE
                table.insert(result.list, temp);
            end
        end
    end

    db:incr("social_activity_share_view_.." .. id .. ".._count", 1);
    return result;
end

return _M;