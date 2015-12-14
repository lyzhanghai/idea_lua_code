#ngx.header.content_type = "text/plain;charset=utf-8"
--[[
#李政言 2014-12-30
#描述：根据学生id获得对应的学生姓名,id以“，”分隔
]]
--1.获得参数方法
local request_method = ngx.var.request_method;
local args = nil;
if "GET" == request_method then
    args = ngx.req.get_uri_args();
else
    ngx.req.read_body();
    args = ngx.req.get_post_args();
end

--2.获得参数
--获得学生id
if args["student_id"] == nil or args["student_id"] == "" then
    ngx.say("{\"success\":false,\"info\":\"student_id参数错误！\"}")
    return
end
local student_id = args["student_id"]
local limit = args["limit"]
if not limit then
    limit = 10000
end

--3.连接数据库
local mysql = require "resty.mysql";
local db, err = mysql : new();
if not db then 
    ngx.log(ngx.ERR, err);
    return;
end

  db:set_timeout(1000) -- 1 sec

local ok, err, errno, sqlstate = db:connect{
    host = v_mysql_ip,
    port = v_mysql_port,
    database = v_mysql_database,
    user = v_mysql_user,
    password = v_mysql_password,
    max_packet_size = 1024 * 1024 }

if not ok then
    ngx.say("failed to connect: ", err, ": ", errno, " ", sqlstate)
    return
end

--4.连接redis服务器
local redis = require "resty.redis"
local cache = redis:new()
local ok,err = cache:connect(v_redis_ip,v_redis_port)
if not ok then
    ngx.say("{\"success\":\"false\",\"info\":\""..err.."\"}")
    return
end


local sel_teacher = "SELECT cs.teacher_id AS TEACHER_ID, ds.SUBJECT_ID, ds.SUBJECT_NAME FROM t_base_term bt,t_base_class_subject cs,t_base_student bs,t_dm_subject ds WHERE bt.xq_id = cs.xq_id AND cs.class_id = bs.class_id AND ds.SUBJECT_ID = cs.SUBJECT_ID AND bt.sfdqxq = 1 AND cs.b_use = 1 AND bs.student_id ="..student_id.." limit "..limit;
local total_sql = "SELECT count(*) as totalRow FROM t_base_term bt,t_base_class_subject cs,t_base_student bs,t_dm_subject ds WHERE bt.xq_id = cs.xq_id AND cs.class_id = bs.class_id AND ds.SUBJECT_ID = cs.SUBJECT_ID AND bt.sfdqxq = 1 AND cs.b_use = 1 AND bs.student_id ="..student_id;
local results, err, errno, sqlstate = db:query(sel_teacher);
if not results then
    ngx.log(ngx.ERR, "bad result: ", err, ": ", errno, ": ", sqlstate, ".");
	ngx.say("{\"success\":\"false\",\"info\":\"查询数据出错！\"}");
    return
end

local t_r = db:query(total_sql)
local total_row = t_r and t_r[1] and t_r[1].totalRow or "0"

--调用空间接口取基本信息
local personIds = {}
for i=1,#results do
    table.insert(personIds, results[i].TEACHER_ID)
end
local aService = require "space.services.PersonAndOrgBaseInfoService"
local rt = aService:getPersonBaseInfo("5", unpack(personIds))
for i=1,#results do
    for _, v in ipairs(rt) do
        if tostring(results[i].TEACHER_ID) == tostring(v.personId) then
            results[i].avatar_fileid = v and v.avatar_fileid or ""
            --teacherlist[i].description = v and v.person_description or ""
            break
        end
    end
end

--查询关注情况
local attentionService = require "space.attention.service.AttentionService"
local param = {}
param.personid = student_id
param.identityid = "6"
param.page_size = 100000
param.page_num = 1
--ngx.log(ngx.ERR,cjson.encode(param))
local at = attentionService.queryAttention(param)
for i=1,#results do
    results[i].attention = 0
    for _, v in ipairs(at) do
        if tostring(results[i].TEACHER_ID) == tostring(v.personId) then
            results[i].attention = 1
            break
        end
    end
end

local responseObj = {};
local recordsPerson = {};

for i=1, #results do
	local temp_personId= results[i]["TEACHER_ID"];
    local temp_avatar_fileid = results[i]["avatar_fileid"];
	--根据教师id获得对应的教师姓名
	local temp_personinfo =  cache:hmget("person_"..temp_personId.."_5","person_name","avatar_url");
    local temp_attention = results[i]["attention"];
   -- local temp_loginname = results[i]["LOGIN_NAME"];
	local record = {};
	record.id = temp_personId;
	record.name = temp_personinfo[1];
	record.userPhoto = temp_personinfo[2];
	--record.logiNname = temp_loginname;
    record.avatar_fileid = temp_avatar_fileid;
    record.attention = temp_attention;
    record.subject_id = results[i]["SUBJECT_ID"];
    record.subject_name = results[i]["SUBJECT_NAME"];
	
	table.insert(recordsPerson, record);
end

responseObj.success = true;
responseObj.teacherlist = recordsPerson;
responseObj.total_row = total_row

-- 5.将table对象转换成json
local cjson = require "cjson";
cjson.encode_empty_table_as_object(false);
local responseJson = cjson.encode(responseObj);

-- 6.输出json串到页面
ngx.say(responseJson);

-- 7.将mysql连接归还到连接池
ok, err = db: set_keepalive(0, v_pool_size);
if not ok then
	ngx.log(ngx.ERR, "====>将Mysql数据库连接归还连接池出错！");
end

-- 将redis连接归还到连接池
local ok, err = cache: set_keepalive(0, v_pool_size)
if not ok then
    ngx.log(ngx.ERR, "====>将Redis连接归还连接池出错！");
end










