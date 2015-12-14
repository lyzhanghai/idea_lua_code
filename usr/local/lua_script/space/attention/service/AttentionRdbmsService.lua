--
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2015/10/6 0006
-- Time: 下午 3:05
-- To change this template use File | Settings | File Templates.
--

local log = require("social.common.log")
local DBUtil = require "common.DBUtil";
local TS = require "resty.TS"
local TableUtil = require("social.common.table")

--教师空间5 学生空间6 家长空间7 班级空间105 学校空间104
local _M = {
    recommend = "1", --推荐
    hot = "2", --热门
    new = "3", --最新加入

    fan = "fan_num",--粉丝
    access="access_num", --人气.
}
--- 保存关注数
function _M.addFanNum(id, identityid, stattype)
    local db = DBUtil:getDb();
    local sql = "SELECT * FROM T_SOCIAL_SPACE_STAT WHERE COMMON_ID=%s AND IDENTITY_ID=%s AND STAT_TYPE=%s";
    local list = db:query(sql);
    if not list then
        --如果不存在
        local insert_sql = "INSERT INTO `t_social_space_stat` ( `fan_num`, `identity_id`, `stat_type`, `common_id`) VALUES (1, %d, %d, %d);"
        insert_sql = string.format(insert_sql,identityid,stattype,id);
        local result =  db:query(insert_sql);
        return result.affected_rows > 0;
    else
        --如果存在
        local update_sql = "UPDATE T_SOCIAL_SPACE_STAT SET FAN_NUM=FAN_NUM+1 WHERE IDENTITY_ID=%d AND STAT_TYPE=%d AND COMMON_ID=%d"
        update_sql = string.format(update_sql,identityid,stattype,id);
        local result =  db:query(update_sql);
        return result.affected_rows > 0;
    end

end

--- 保存访问量
function _M.addAccessNum(id, identityid, stattype)
    local db = DBUtil:getDb();
    local sql = "SELECT * FROM T_SOCIAL_SPACE_STAT WHERE COMMON_ID=%s AND IDENTITY_ID=%s AND STAT_TYPE=%s";
    local list = db:query(sql);
    if not list then
        --如果不存在
        local insert_sql = "INSERT INTO `T_SOCIAL_SPACE_STAT` ( `ACCESS_NUM`, `IDENTITY_ID`, `STAT_TYPE`, `COMMON_ID`) VALUES (1, %d, %d, %d);"
        insert_sql = string.format(insert_sql,identityid,stattype,id);
        local result =  db:query(insert_sql);
        return result.affected_rows > 0;
    else
        --如果存在
        local update_sql = "UPDATE T_SOCIAL_SPACE_STAT SET ACCESS_NUM=ACCESS_NUM+1 WHERE IDENTITY_ID=%d AND STAT_TYPE=%d AND COMMON_ID=%d"
        update_sql = string.format(update_sql,identityid,stattype,id);
        local result =  db:query(update_sql);
        return result.affected_rows > 0;
    end
end


--取消关注.
function _M.delFanNum(id,identityid,stattype)
    local update_sql = "UPDATE T_SOCIAL_SPACE_STAT SET FAN_NUM=FAN_NUM-1 WHERE IDENTITY_ID=%d AND STAT_TYPE=%d AND COMMON_ID=%d"
    update_sql = string.format(update_sql,identityid,stattype,id);
    local result =  db:query(update_sql);
    return result.affected_rows > 0;
end

local function getIconAndName(list)
       if list and TableUtil:length(list) > 0 then
           for i = 1, #list do
               local _id = list[i]['id']
               local _identityid =  list[i]['id']
           end
       end
end

local function getStatSpaceCount(identityid,stattype)
    local db = DBUtil:getDb();
    local count_sql = "select count(id) as totalRow from T_SOCIAL_SPACE_STAT where identity_id=%s and stat_type=%s";
    count_sql = string.format(count_sql,identityid,stattype)
    local count = db:query(count_sql);
    if TableUtil:length(count) == 0 then
        return nil;
    end
    return  count[1].totalRow;
end
--根据身份id 和类型获取统计信息。
function _M.getStatSpace(identityid,stattype,pagesize,pagenum,type)
    local db = DBUtil:getDb();
    local totalRow = getStatSpaceCount(identityid,stattype)
    local totalPage = math.floor((totalRow + pagesize - 1) / pagesize)
    local offset = pagesize * pagenum - pagesize
    local list_sql = "SELECT * FROM  T_SOCIAL_SPACE_STAT WHERE IDENTITY_ID=%s AND STAT_TYPE=%s ORDER BY %s"
    list_sql = string.format(list_sql,identityid,stattype,type);
    list_sql = list_sql .. " LIMIT " .. offset .. "," .. pagesize
    log.debug(list_sql);
    local list = db:query(list_sql);
    DBUtil:keepDbAlive(db);
    getIconAndName(list)
    local result = { list = list, totalRow = totalRow, totalPage = totalPage, pageNum = pagenum, pageSize = pagesize }
    return result
end

return _M;