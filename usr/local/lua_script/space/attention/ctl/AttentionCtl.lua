--
-- Created by IntelliJ IDEA.
-- User: 张海
-- Date: 2015/7/6
-- Time: 9:45
-- To change this template use File | Settings | File Templates.
--

ngx.header.content_type = "text/plain";
local web = require("social.router.web")
local cjson = require "cjson"
local request = require("social.common.request")
local no_permission_context = ngx.var.path_uri_no_permission --无权限的context.
local context = ngx.var.path_uri --有权限的context.
local log = require("social.common.log")
local service = require("space.attention.service.AttentionService")

-------------------------------------------------------------------------------------------------------
-- 保存关注信息.
local function save()
    local personid = request:getStrParam("personid", true, true) --关注人id
    local identityid = request:getStrParam("identityid", true, true) --关注人id
    local b_personid = request:getStrParam("b_personid", true, true) --被关注人id
    local b_identityid = request:getStrParam("b_identityid", true, true) --被关注人的身份.
    local r = service.save({ personid = personid, identityid = identityid, b_personid = b_personid, b_identityid = b_identityid })
    local result = {}
    result.success = true;
    if not r then
        result.success = false;
        result.info = { name = "", data = "添加出错." }
        ngx.say(cjson.encode(result));
        return;
    end
    ngx.say(cjson.encode(result));
end

-------------------------------------------------------------------------------------------------------
-- 查询关注信息.
local function query()
    log.debug("查询关注信息.")
    local personid = request:getStrParam("personid", true, true) --关注人id
    local identityid = request:getStrParam("identityid", true, true) --关注人id
    local b_personid = request:getStrParam("b_personid", true, true) --被关注人id
    local b_identityid = request:getStrParam("b_identityid", true, true) --被关注人的身份.
    local result = { success = true, list = {} }
    local list = service.queryAttention({ personid = personid, identityid = identityid, b_personid = b_personid, b_identityid = b_identityid })
    if not list then
        ngx.say(cjson.encode({ success = false }))
        return;
    end
    result.list = list
    ngx.say(cjson.encode(result));
end

-------------------------------------------------------------------------------------------------------
-- 查询被关注信息.
local function bquery()
    log.debug("查询被关注信息.")
    local personid = request:getStrParam("personid", true, true) --关注人id
    local identityid = request:getStrParam("identityid", true, true) --关注人id
    local b_personid = request:getStrParam("b_personid", true, true) --被关注人id
    local b_identityid = request:getStrParam("b_identityid", true, true) --被关注人的身份.
    local result = { success = true, list = {} }
    local list = service.queryBAttention({ personid = personid, identityid = identityid, b_personid = b_personid, b_identityid = b_identityid })
    if not list then
        ngx.say(cjson.encode({ success = false }))
        return;
    end
    result.list = list
    ngx.say(cjson.encode(result));
end

local function get()
    local personid = request:getStrParam("personid", false, true) --关注人id
    local identityid = request:getStrParam("identityid", false, true) --关注人id
    local b_personid = request:getStrParam("b_personid", true, true) --被关注人id
    local b_identityid = request:getStrParam("b_identityid", true, true) --被关注人的身份.
    local result = service.get({ personid = personid, identityid = identityid, b_personid = b_personid, b_identityid = b_identityid })
    if not result then
        result.success = false
        ngx.say(cjson.encode(result))
        return;
    end
    ngx.say(cjson.encode(result));
end

------------------------------------------------------------------------------------------------------
-- 设置访问量.
local function access()
    local personid = request:getStrParam("personid", false, true) --关注人id
    local identityid = request:getStrParam("identityid", false, true) --关注人id
    local b_personid = request:getStrParam("b_personid", true, true) --被关注人id
    local b_identityid = request:getStrParam("b_identityid", true, true) --被关注人的身份.
    local result = service.access(personid, identityid, b_personid, b_identityid)
    if not result then
        ngx.say(cjson.encode({ success = false }))
        return;
    end
    ngx.say(cjson.encode({ success = true }))
end

local function accesslist()
    local personid = request:getStrParam("personid", true, true) --关注人id
    local identityid = request:getStrParam("identityid", true, true) --关注人id
    local list = service.accesslist(personid, identityid)
    local result = { success = true, list = {} }
    if not list then
        ngx.say(cjson.encode({ success = false }))
        return;
    end
    result.list = list
    ngx.say(cjson.encode(result));
end


------------------------------------------------------------------------------------------------------
-- 取消关注
local function delete()
    local personid = request:getStrParam("personid", true, true) --关注人id
    local identityid = request:getStrParam("identityid", true, true) --关注人id
    local b_personid = request:getStrParam("b_personid", true, true) --被关注人id
    local b_identityid = request:getStrParam("b_identityid", true, true) --被关注人的身份.
    local r = service.delete({ personid = personid, identityid = identityid, b_personid = b_personid, b_identityid = b_identityid })
    if not r then
        ngx.say(cjson.encode({ success = false }))
        return;
    end
    ngx.say(cjson.encode({ success = true }))
end


-- 配置url.
-- 按功能分
local urls = {
    context .. '/save', save,
    context .. '/query', query,
    context .. '/bquery', bquery,
    no_permission_context .. '/get', get,
    no_permission_context .. '/access', access,
    context .. '/list_access', accesslist,
    context .. '/cancel', delete
}
local app = web.application(urls, nil)
app:start()