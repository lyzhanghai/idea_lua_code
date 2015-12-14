--[[
编辑照片名称
@Author feiliming
@Date   2015-4-24
]]

local say = ngx.say
local len = string.len
local quote = ngx.quote_sql_str

--require model
local cjson = require "cjson"
local mysqllib = require "resty.mysql"

--get args
local request_method = ngx.var.request_method
local args,err
if request_method == "GET" then
    args,err = ngx.req.get_uri_args()
else
    ngx.req.read_body()
    args,err = ngx.req.get_post_args()
end
if not args then 
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end

local picture_id = args["picture_id"]
local picture_name = args["picture_name"]
if not picture_id or len(picture_id) == 0 or
	not picture_name or len(picture_name) == 0 then
	say("{\"success\":false,\"info\":\"参数错误！\"}")
	return
end

--mysql
local mysql, err = mysqllib:new()
if not mysql then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end
local ok, err = mysql:connect{
    host = v_mysql_ip,
    port = v_mysql_port,
    database = v_mysql_database,
    user = v_mysql_user,
    password = v_mysql_password,
    max_packet_size = 1024 * 1024 }
if not ok then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end

--select
local ssql = "select resource_id from t_social_gallery_picture where id = "..quote(picture_id)
local sresult, err = mysql:query(ssql)
if not sresult then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end
local resource_id = sresult[1] and sresult[1].resource_id or nil
--ngx.log(ngx.ERR, "======"..resource_id)
if resource_id then
    local aService = require "space.services.PersonAndOrgBaseInfoService"
    local rt = aService:getResById1(resource_id)
    --ngx.log(ngx.ERR, "======"..rt[1].resource_id_int)
    if rt and rt[1] and rt[1].resource_id_int and len(rt[1].resource_id_int) > 0 then
        --去修改资源名称
        local res = ngx.location.capture("/dsideal_yy/ypt/resource/updateResName", {
            method = ngx.HTTP_POST,
            body = "obj_id_int="..rt[1].resource_id_int.."&obj_name="..picture_name.."&type_id=1"
        });
    end
end

--update
local isql = "update t_social_gallery_picture set picture_name = "..quote(picture_name).." where id = "..quote(picture_id)
local iresult, err = mysql:query(isql)
if not iresult then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end


--return
local rr = {}
rr.success = true

cjson.encode_empty_table_as_object(false)
say(cjson.encode(rr))

--release
mysql:set_keepalive(0,v_pool_size)