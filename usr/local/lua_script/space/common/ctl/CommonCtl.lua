--
-- Created by IntelliJ IDEA.
-- User: zh
-- To change this template use File | Settings | File Templates.

local web = require("social.router.web")
local request = require("social.common.request")
local context = ngx.var.path_uri
local log = require("social.common.log")
local http = require "resty.http"
local cjson = require "cjson"
local permission_context = ngx.var.permission_uri --无权限的context.
local service = require("space.common.service.CommonService")
local function getSpaceMenu()
    local person_id = request:getStrParam("person_id", true, true)
    local identity_id = request:getStrParam("identity_id", true, true)
    local poService = require("space.services.PersonAndOrgBaseInfoService")
    local r = poService:getPersonSpaceMenu(person_id, identity_id)
    local rr = {}
    if not r then
        rr.success = false
        ngx.say(cjson.encode(rr))
        return
    end
    rr = r
    rr.success = true
    cjson.encode_empty_table_as_object(false);
    ngx.say(cjson.encode(rr))
end

--- 通过机构id获取人信息，包括好友信息头像.
local function getPersonInfoByOrgId()
    local org_id = request:getNumParam("org_id", true, true)
    local identity_id = request:getStrParam("identity_id", true, true)
    local identity_ids = request:getStrParam("identity_ids", true, true)
    local person_id = request:getStrParam("person_id", true, true)
    local seachetext = request:getStrParam("seachetext", false, false)
    local pagenum = request:getStrParam("pagenum", true, true)
    local pagesize = request:getStrParam("pagesize", true, true)
    log.debug(seachetext);
    if seachetext and string.len(seachetext) > 0 then
       -- seachetext = ngx.unescape_uri(seachetext)
        seachetext = ngx.decode_base64(seachetext);
    end
    log.debug(seachetext);
    local result = service.getFriends(org_id, person_id, identity_id, identity_ids, seachetext, pagenum, pagesize);
    if not result then
        result.success = false;
    else
        result.success = true;
    end
    ngx.say(cjson.encode(result));
    return;
end

-- 配置url.
-- 按功能分
local urls = {
    context .. '/getSpaceMenu', getSpaceMenu,
    permission_context .. '/getPersonInfoByOrgId', getPersonInfoByOrgId
}
local app = web.application(urls, nil)
app:start()
