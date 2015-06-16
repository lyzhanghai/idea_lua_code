--
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2015/6/16
-- Time: 8:43
-- To change this template use File | Settings | File Templates.
-- 通用版块的service.
local serviceBase = require("social.service.CommonBaseService")
local DBUtil = require "common.DBUtil";
local TableUtil = require("social.common.table")
local SsdbUtil = require("social.common.ssdbutil")
local log = require("social.common.log")
local quote = ngx.quote_sql_str
local _M = {
    operate_ssdb = true
}


local function saveForumToDb(param)
    local forum_t = { param.forum_id, param.bbs_id, param.partition_id, quote(param.name), quote(param.icon_url), quote(param.description), param.sequence, "now()", param.type_id, param.type }
    local isql = "insert into t_social_bbs_forum(id,bbs_id,partition_id,name,icon_url,description,sequence,last_post_time,type_id,type) values(" ..
            table.concat(forum_t, ",") .. ")"
    log.debug("保存板块的sql :" .. isql);
    local queryResult = DBUtil:querySingleSql(isql);
    return queryResult.affected_rows
end

local function saveForumToSSDB(param)
    local db = SsdbUtil:getDb();
    local forum = {}
    forum.id = param.forum_id
    forum.bbs_id = param.bbs_id
    forum.partition_id = param.partition_id
    forum.name = param.name
    forum.icon_url = param.icon_url
    forum.description = param.description
    forum.sequence = param.sequence
    forum.b_delete = 0
    forum.post_today = 0
    forum.post_yestoday = 0
    forum.total_topic = 0
    forum.total_post = 0
    forum.last_post_id = 0
    forum.type_id = param.type_id
    forum.type = param.type;
    db:multi_hset("social_bbs_forum_" .. param.forum_id, forum)
    local fids_t, err = db:hget("social_bbs_include_forum", "partition_id_" .. param.partition_id)
    local fids = ""
    if fids_t and string.len(fids_t[1]) > 0 then
        fids = fids_t[1] .. "," .. param.forum_id
    else
        fids = param.forum_id
    end
    db:hset("social_bbs_include_forum", "partition_id_" .. param.partition_id, fids)
end



------------------------------------------------------------------------------------------------------------------------
-- 保存版块信息.
--- @param #table param.
-- bbs_id=param.bbs_id,
-- partition_id=param.partition_id,
-- name=param.name,
-- icon_url=param.icon_url,
-- description=param.description,
-- sequence=param.sequence,
-- typeid=param.typeid,
-- type=param.type
function _M.saveForum(param)
    self:checkParamIsNull({
        bbs_id = param.bbs_id,
        partition_id = param.partition_id,
        name = param.name,
        icon_url = param.icon_url,
        --description = param.description,
        sequence = param.sequence,
        type_id = param.type_id,
        type = param.type
    })
    local db = SsdbUtil:getDb()
    local forum_id = db:incr("social_bbs_forum_pk")[1]
    param.forum_id = forum_id;

    local row = saveForumToDb(param);
    if row > 0 then
        saveForumToSSDB(param)
    end
    SsdbUtil:keepalive()
end

local function updateForumToDb(param)
    local usql = "update t_social_bbs_forum set %s where id = " .. param.forum_id
    local str="bbs_id="..param.bbs_id..","
    str = str.."partition_id="..param.partition_id..","
    str = str.."name="..param.name..","
    str = str.."icon_url="..param.icon_url..","
    str = str.."sequence="..param.sequence..","
    str =  ((param.description==nil or string.len(param.description) == 0) and "") or str.."description="..param.description..","
    str = str.."type_id="..param.type_id..","
    str = str.."type="..param.type
    usql = string.format(usql,str)
    log.debug(usql);
    local queryResult = DBUtil:querySingleSql(usql);
    return queryResult.affected_rows
end

local function updateForumToSSDB(param)
    local db = SsdbUtil:getDb();
    db:multi_hset("social_bbs_forum_" .. param.forum_id, "name", param.name, "icon_url", param.icon_url, "description", param.description, "sequence", param.sequence, "forum_admin_list", "", "type", param.type, "type_id", param.type_id)
    SsdbUtil:keepalive()
end

------------------------------------------------------------------------------------------------------------------------
-- 修改版块信息.
-- @param #string .
function _M.updateForum(param)
    self:checkParamIsNull({
        bbs_id = param.bbs_id,
        partition_id = param.partition_id,
        name = param.name,
        icon_url = param.icon_url,
        forum_id= param.forum_id,
       -- description = param.description,
        sequence = param.sequence,
        type_id = param.type_id,
        type = param.type
    })
    local row = updateForumToDb(param)
    if row > 0 then
        updateForumToSSDB(param)
    end
end


------------------------------------------------------------------------------------------------------------------------
local function deleteOrRecoveryForumToDb(forum_id, isDelete)
    local ssql = "update t_social_bbs_forum set b_delete = 1 where id = " .. forum_id
    local queryResult = DBUtil:querySingleSql(ssql);
    return queryResult.affected_rows
end

local function deleteForumToSSDB(forum_id)
    local db = SsdbUtil:getDb();
    db:hset("social_bbs_forum_" .. forum_id, "b_delete", 1)
    local partition_id = db:hget("social_bbs_forum_" .. forum_id, "partition_id")[1]
    local fids = db:hget("social_bbs_include_forum", "partition_id_" .. partition_id)[1]
    if fids and string.len(fids) > 0 then
        fids = string.gsub(fids, forum_id .. ",", "")
        fids = string.gsub(fids, "," .. forum_id, "")
        fids = string.gsub(fids, forum_id, "")
    end
    db:hset("social_bbs_include_forum", "partition_id_" .. partition_id, fids)
    SsdbUtil:keepalive()
end

--删除版块信息.
--@param #string
function _M.deleteForum(forum_id)
    self:checkParamIsNull({
        forum_id = forum_id
    })
    local row = deleteOrRecoveryForumToDb(forum_id, 1)
    if row > 0 then
        deleteForumToSSDB(forum_id)
    end
end

------------------------------------------------------------------------------------------------------------------------
local function recoveryForumToSSDB(forum_id)
    local db = SsdbUtil:getDb()
    db:hset("social_bbs_forum_" .. forum_id, "b_delete", 0)
    local partition_id = db:hget("social_bbs_forum_" .. forum_id, "partition_id")[1]
    local fids = db:hget("social_bbs_include_forum", "partition_id_" .. partition_id)[1]
    if fids and string.len(fids) > 0 then
        local _fids = Split(fids, ",")
        table.insert(_fids, partition_id);
        local newPids = table.concat(_fids, ",");
        db:hset("social_bbs_include_forum", "partition_id_" .. partition_id, newPids)
    end
end
------------------------------------------------------------------------------------------------------------------------
--恢复删除的版块.
--@param #string forum_id.
function _M.recoveryForum(forum_id)
    self:checkParamIsNull({
        forum_id = forum_id
    })
    local row = deleteOrRecoveryForumToDb(forum_id, 0)
    if row > 0 then
        recoveryForumToSSDB(forum_id)
    end
end



------------------------------------------------------------------------------------------------------------------------
--通过id获取forum
--从数据库读取.
--@param #string forum_id
--@return table
function _M.getForumById(forum_id)
    self:checkParamIsNull({
        forum_id = forum_id
    })
    local sql = "select id,bbs_id,partition_id,name,icon_url,description,sequence,type,type_id from t_social_bbs_forum where id = %s"
    sql = string.format(sql,forum_id);
    local queryResult = DBUtil:querySingleSql(sql);
    local rr = {}
    if queryResult and #queryResult > 0 then
        rr.forum_id = queryResult[1].id
        rr.partition_id = queryResult[1].partition_id
        rr.bbs_id = queryResult[1].bbs_id
        rr.name = queryResult[1].name
        rr.icon_url = queryResult[1].icon_url
        rr.description = queryResult[1].description
        rr.sequence = queryResult[1].sequence
        rr.type = queryResult[1].type
        rr.type_id = queryResult[1].type_id;
    end
    return rr;
end

return serviceBase:inherit(_M):init()

