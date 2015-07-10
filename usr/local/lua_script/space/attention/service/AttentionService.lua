--
-- Created by IntelliJ IDEA.
-- User: 张海 .
-- Date: 2015/7/6
-- Time: 9:46
-- To change this template use File | Settings | File Templates.
--

local log = require("social.common.log")
local RedisUtil = require("social.common.redisutil")
local SsdbUtil = require("social.common.ssdbutil")
local TS = require "resty.TS"
local _M = {}

--------------------------------------------------------------------
local function checkParamIsNull(t)
    for key, var in pairs(t) do
        if var == nil or string.len(var) == 0 then
            error(key .. " 不能为空.")
        end
    end
end

--设置关注
local function setAttention(param)
    local db = SsdbUtil:getDb();
    local key = param.b_identityid .. "_" .. param.b_personid
    db:zset("space_attention_identityid_" .. param.identityid .. "_personid_" .. param.personid, key, TS.getTs())
    db:incr("space_attention_identityid_" .. param.identityid .. "_personid_" .. param.personid .. "_count", 1);
end

--设置被关注.
local function setBAttention(param)
    local db = SsdbUtil:getDb();
    local key = param.identityid .. "_" .. param.personid
    db:zset("space_b_attention_identityid_" .. param.b_identityid .. "_personid_" .. param.b_personid, key, TS.getTs())
    db:incr("space_b_attention_identityid_" .. param.b_identityid .. "_personid_" .. param.b_personid .. "_count", 1);
end

-------------------------------------------------------------
-- 保存关注人信息.
function _M.save(param)
    checkParamIsNull(param)
    local status = pcall(function()
        setAttention(param)
        setBAttention(param)
    end)
    if status then
        return true;
    end
    return false;
end

local function getPersonInfoByRedis(zResult)
    local aService = require "space.services.PersonAndOrgBaseInfoService"
    local id_result = {}
    if zResult and zResult[1] and zResult[1] ~= "ok" then
        for i = 1, #zResult, 2 do
            local temp = {}
            local r = Split(zResult[i], "_")
            temp.person_id = r[2];
            temp.identity_id = r[1];
            table.insert(id_result,temp);
        end
        local rt = aService:getPersonBaseInfoByPersonIdAndIdentityId(id_result)
        return rt;
    end
    return {};
end

local function getAttention(personid, identityid)
    local db = SsdbUtil:getDb();
    local zResult = db:zrange("space_attention_identityid_" .. identityid .. "_personid_" .. personid, 0, 10)
    log.debug(zResult);
    local result = getPersonInfoByRedis(zResult)
    return result;
end

local function getBAttention(personid, identityid)
    local db = SsdbUtil:getDb();
    local name = "space_b_attention_identityid_" .. identityid .. "_personid_" .. personid;
    local zResult = db:zrange(name, 0, 10)
    log.debug(name)
    log.debug(zResult);
    local result = getPersonInfoByRedis(zResult)
    return result;
end

--------------------------------------------------------------
-- 查询关注人
function _M.queryAttention(param)
    checkParamIsNull({
        personid = param.personid,
        identityid = param.identityid,
        b_personid = param.b_personid,
        b_identityid = param.b_identityid,
    })
    local result = getAttention(param.personid, param.identityid)
    return result
end

--------------------------------------------------------------
-- 查询关注人
function _M.queryBAttention(param)
    log.debug(param)
    checkParamIsNull({
        personid = param.personid,
        identityid = param.identityid,
        b_personid = param.b_personid,
        b_identityid = param.b_identityid,
    })
    local result = getBAttention(param.personid, param.identityid)
    return result
end


function _M.get(param)
    local result = {}
    --    checkParamIsNull({
    --        personid = personid,
    --        identityid = identityid,
    --    })
    local db = SsdbUtil:getDb();
    if param.personid and param.identityid then
        --关注量
        local attention_count = db:get("space_attention_identityid_" .. param.identityid .. "_personid_" .. param.personid .. "_count"); --关注数量
        if attention_count and attention_count[1] and string.len(attention_count[1]) > 0 then
            result.attention_count = attention_count[1];
        else
            result.attention_count = 0
        end
        --被关注量
        local attentionb_count = db:get("space_b_attention_identityid_" .. param.identityid .. "_personid_" .. param.personid .. "_count"); --被关注数量
        if attentionb_count and attentionb_count[1] and string.len(attentionb_count[1]) > 0 then
            result.attentionb_count = attentionb_count[1];
        else
            result.attentionb_count = 0
        end
        --是否关注
        local is_attention = db:zexists("space_attention_identityid_" .. param.identityid .. "_personid_" .. param.personid, param.b_identityid .. "_" .. param.b_personid)
        log.debug(is_attention)
        if is_attention and is_attention[1] and tonumber(is_attention[1]) > 0 then
            result.is_attention = 1;
        else
            result.is_attention = 0;
        end
        --被谁访问
        db:zset("space_attention_access_" .. param.type .. "_identityid_" .. param.b_identityid .. "_personid_" .. param.b_personid, param.identityid .. "_" .. param.personid, TS.getTs())

    end
    local access_quantity = db:get("space_attention_access_" .. param.type .. "_quantity_identityid_" .. param.b_identityid .. "_personid_" .. param.b_personid)
    if access_quantity and access_quantity[1] and string.len(access_quantity[1]) > 0 then
        result.access_quantity = access_quantity[1]
    else
        result.access_quantity = 0
    end
    db:incr("space_attention_access_" .. param.type .. "_quantity_identityid_" .. param.b_identityid .. "_personid_" .. param.b_personid, 1);--访问量加1



    return result;
end

function _M.access(personid, identityid, b_personid, b_identityid, type)
    local db = SsdbUtil:getDb();
    if not personid and not identityid then
        local key = identityid .. "_" .. personid
        db:zset("space_attention_access_" .. type .. "_identityid_" .. b_identityid .. "_personid_" .. b_personid, key, TS.getTs())
    end
    local result = db:incr("space_attention_access_" .. type .. "_quantity_identityid_" .. b_identityid .. "_personid_" .. b_personid, 1);
    return result;
end

function _M.accesslist(personid, identityid, type)
    local db = SsdbUtil:getDb();
    local zResult = db:zrange("space_attention_access_" .. type .. "_identityid_" .. identityid .. "_personid_" .. personid, 0, 10)
    local result = getPersonInfoByRedis(zResult)
    return result;
end

function _M.delete(param)
    checkParamIsNull(param)
    local db = SsdbUtil:getDb();
    local key = param.b_identityid .. "_" .. param.b_personid
    db:zdel("space_attention_identityid_" .. param.identityid .. "_personid_" .. param.personid, key)
    db:incr("space_attention_identityid_" .. param.identityid .. "_personid_" .. param.personid .. "_count", -1);
    local b_key = param.identityid .. "_" .. param.personid
    db:zdel("space_b_attention_identityid_" .. param.b_identityid .. "_personid_" .. param.b_personid, b_key)
    db:incr("space_b_attention_identityid_" .. param.b_identityid .. "_personid_" .. param.b_personid .. "_count", -1);
    return true;
end

return _M;
