--
-- Created by IntelliJ IDEA.
-- User: zh
-- Date: 2015/9/8
-- Time: 8:30
-- To change this template use File | Settings | File Templates.
-- 获取评论功能，从远程调用获取数据，简单封装。

local web = require("social.router.web")
local request = require("social.common.request")
local context = ngx.var.path_uri
local log = require("social.common.log")
local http = require "resty.http"
local cjson = require "cjson"
local function getComment()
    local url = request:getStrParam("url", true, true)
    url = ngx.unescape_uri(url)
    log.debug(url);
    local hc = http:new()
    local ok, code, headers, status, body = hc:request {
        url = url,
        method = "GET",
    }
    log.debug(ok);
    log.debug(code);
    log.debug(status);
    log.debug(headers);

    if code ~= 200 then
        ngx.say("{\"success\": false,\"code\":\"" .. code .. "\"}");
        return;
    end
    local result = {success=true};
    result.body = body;

    ngx.say(cjson.encode(result));
end

-- 配置url.
-- 按功能分
local urls = {
    context .. '/getComment', getComment,
}
local app = web.application(urls, nil)
app:start()
