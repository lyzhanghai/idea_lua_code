--[[
    获取空间管理的班级数据.
    @Author zhanghai
    @Date   2015-4-27
--]]
ngx.header.content_type = "text/plain;charset=utf-8"
local say = ngx.say
local len = string.len
local insert = table.insert
local quote = ngx.quote_sql_str
local log = require("social.common.log")

--require model
local mysqllib = require "resty.mysql"
local cjson = require "cjson"

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

--get args
local getArgs = function()
    local request_method = ngx.var.request_method
    local args,err
    if request_method == "GET" then
        args,err = ngx.req.get_uri_args()
    else
        ngx.req.read_body()
        args,err = ngx.req.get_post_args()
    end
    return args
end


--获取参数
-- org_id：机构id，从这个节点往下取
-- org_type：机构类型，1省2市3区县4校5分校6部门7班级
-- school_type：1小学2初中3高中4完全中学5九年一贯6十二年一贯
-- school_name：base64和URL编码的学校名称，模糊查询
-- pageNumber：当前页
-- pageSize：每页条数
--
local getParams = function()
    local args = getArgs()
    local org_id = args["org_id"]
    local org_type = args["org_type"]
    local teacher_type = args["teacher_type"]
    local teacher_name = args["teacher_name"]
    local pageNumber = args["pageNumber"]
    local pageSize = args["pageSize"]
    local district = args["district"]
    local province = args["province"]
    local city = args["city"]
    local school = args["school"]
    if not org_id or len(org_id)==0 then
        error()
    end
    -- if not org_type or len(org_type)==0 then
    --    error()
    -- end
    if not province or len(province)==0 then
        province="0"
    end
    if not district or len(district)==0 then
        district="0"
    end
    if not city or len(city)==0 then
        city="0"
    end
    if not school or len(school)==0 then
        school="0"
    end
    -- if not school_type or len(school_type)==0 then
    --    error()
    -- end
    if teacher_name and len(teacher_name)~=0 then
        teacher_name = ngx.decode_base64(teacher_name)
    end
    if not pageNumber or len(pageNumber)==0 then
        error()
    end
    if not pageSize or len(pageSize)==0 then
        error()
    end
    return org_id,org_type,teacher_type,teacher_name,province,city,district,school,pageNumber,pageSize
end


-- CREATE TABLE `t_scoial_space_excellence` (
--     `ID` INT(11) NOT NULL AUTO_INCREMENT COMMENT 'id',
--     `record_id` INT(11) NOT NULL COMMENT '记录id',
--     `org_id` INT(11) NOT NULL COMMENT '机构id用户登录时取的机构',
--     `org_type` INT(11) NOT NULL COMMENT '机构类型1省2市3区县4校',
--     PRIMARY KEY (`ID`)
-- )
-- id  record_id   org_id   org_type
-- 1    1            1        1
-- 2    2            1        1
--1省2市3区县4校5分校6部门7班级
--显示省市区
local function getExcellence(record_id)
    local querySql = "select ifnull(group_concat(t.org_type),-1) as org_type from t_social_space_excellence t where t.identityid = 3 and t.record_id="..record_id
    log.debug(querySql);
    local result, err = mysql:query(querySql)

    if not result then
        error()
    end
    --1,2
    return result
end


-- local function resolveParam(tab)
--     local str = ""
--     for k,v in ipairs(tab) do
--         if k~=table.getn(tab) then
--             str = str..v..","
--         else
--             str = str..v
--         end
--     end
--     return str
-- end

local function convertTableToString(t)
    local str = ""
    if not t or table.getn(t)==0 then return str  end

    for i=1,#t do
        if i<table.getn(t) then
            str = str..t[i]..","
        else
            str = str..t[i]
        end
    end
    return str
end

local function arraySort(arrays)
    local t = {}
    if arrays and #arrays>0 then
        for i=1,#arrays do
            table.insert(t,arrays[i]);
        end
    end
    table.sort(t)
    return t;
end


local function getExcellenceQuery(org_id,org_type,province,city,district,school,pageNumber,pageSize)
    local queryCountSql="SELECT count(*) as totalRow FROM (SELECT t.id,t.record_id,t.org_id, GROUP_CONCAT(t.org_type) AS org_type FROM t_social_space_excellence t WHERE 1=1 and t.identityid = 3"
    --local querySql = "select record_id,org_type from (select t.id,t.record_id,t.org_id ,group_concat(t.org_type) as org_type from t_scoial_space_excellence t group by record_id) t1 where t1.org_id="..org_id.." and t1.org_type="
    local querySql = "SELECT record_id,org_type,org_id FROM (SELECT t.id,t.record_id,t.org_id, GROUP_CONCAT(t.org_type) AS org_type FROM t_social_space_excellence t WHERE 1=1 and t.identityid = 3"
    local whereIdSql = ""

    if org_type == "1" then
        whereIdSql = " AND t.provinceid="..org_id
    elseif  org_type == "2" then
        whereIdSql = " AND t.cityid="..org_id
    elseif org_type == "3" then
        whereIdSql = " AND t.districtid="..org_id
    elseif org_type== "4" then
        whereIdSql = " AND t.schoolid="..org_id
    end

    local t = {}
    -- local tabs = {}
    if province=="1" then
        table.insert(t,"t1.org_type like '%1%'")
    end
    if city=="1" then
        table.insert(t,"t1.org_type like '%2%'")
    end
    if district=="1" then
        table.insert(t,"t1.org_type like '%3%'")
    end
    if school=="1" then
        table.insert(t,"t1.org_type like '%4%'")
    end
    local wheresql = "where "..table.concat(t," and ")
    if province=="0" and city=="0" and  district=="0" and school=="0" then wheresql="" end
    local  groupSql = " GROUP BY record_id) t1 "
    querySql=querySql..whereIdSql..groupSql..wheresql

    log.debug(querySql);
    queryCountSql=queryCountSql..whereIdSql..groupSql..wheresql
    log.debug(queryCountSql);
    ngx.log(ngx.ERR,"queryCountSql=================",queryCountSql)
    local count,err1 = mysql:query(queryCountSql)
    ngx.log(ngx.ERR,"count[1].totalRow=================",count[1].totalRow)


    local totalRow = count[1].totalRow
    local totalPage = math.floor((totalRow + pageSize - 1) / pageSize)
    local offset = pageSize*pageNumber - pageSize
    local limit = pageSize
    querySql = querySql.." LIMIT "..offset..","..pageSize

    log.debug(querySql);
    log.debug(queryCountSql);

    ngx.log(ngx.ERR,"querySql:"..querySql)
    local result, err = mysql:query(querySql)
    return result,totalRow,totalPage,err
end




-- 从接口中取出进行迭代
local function iteratorData(queryResult,resResult,orgType,pageNumber,pageSize)
    if queryResult then
        ngx.log(ngx.ERR,"for start..............",cjson.encode(queryResult))
        resResult.pageSize = queryResult.pageSize;
        resResult.pageNumber = queryResult.pageNumber;
        resResult.totalPage = queryResult.totalPage;
        resResult.totalRow = queryResult.totalRow;
        resResult.teacher_list={}
        local teacherlist = queryResult.teacher_list;
        if teacherlist~=nil and #teacherlist>0 then
            ngx.log(ngx.ERR,"for start.......teacherlist.......",cjson.encode(queryResult))
            for j=1,#teacherlist do
                local resTempTeacherResult = {}
                resTempTeacherResult.teacher_id = teacherlist[j].teacher_id
                resTempTeacherResult.teacher_name = teacherlist[j].teacher_name
                resTempTeacherResult.stage_id = teacherlist[j].stage_id
                resTempTeacherResult.stage_name = teacherlist[j].stage_name
                resTempTeacherResult.subject_id=teacherlist[j].subject_id
                resTempTeacherResult.subject_name = teacherlist[j].subject_name
                resTempTeacherResult.school_id = teacherlist[j].school_id;
                resTempTeacherResult.school_name = teacherlist[j].school_name;
                resTempTeacherResult.province_id=teacherlist[j].province_id
                resTempTeacherResult.city_id = teacherlist[j].city_id
                resTempTeacherResult.district_id = teacherlist[j].district_id
                local status,teacherRes = pcall(getExcellence,teacherlist[j].teacher_id)
                resTempTeacherResult.excellent_group = {}
                if teacherRes~=nil and #teacherRes>0 then
                    if teacherRes[1].org_type~="-1" then
                        resTempTeacherResult.excellent_group = arraySort(Split(teacherRes[1].org_type,","));
                    end
                end
                table.insert(resResult.teacher_list,resTempTeacherResult)
            end
        end
        cjson.encode_empty_table_as_object(false)
        ngx.log(ngx.ERR,"resResult:======================>",cjson.encode(resResult))
    else
        resResult.teacher_list={}
        resResult.pageSize = pageSize;
        resResult.pageNumber = pageNumber;
        resResult.totalPage = 0;
        resResult.totalRow =0;
    end
end

local function iteratorTeacherPageList(queryResult,org_type,resResult,excellent_group,totalRow,totalPage,pageNumber,pageSize)
    ngx.log(ngx.ERR,"iteratorClassPageList:======================>",cjson.encode(queryResult))
    if queryResult and queryResult~=nil then
        resResult.pageSize = pageSize;
        resResult.pageNumber = pageNumber;
        resResult.totalPage = totalPage;
        resResult.totalRow =totalRow;
        resResult.teacher_list={}
        for j=1,#queryResult do
            local resTempTeacherResult = {}
            resTempTeacherResult.teacher_id = queryResult[j].person_id
            resTempTeacherResult.teacher_name = queryResult[j].person_name
            resTempTeacherResult.stage_id = queryResult[j].stage_id
            resTempTeacherResult.stage_name = queryResult[j].stage_name
            resTempTeacherResult.subject_id=queryResult[j].subject_id
            resTempTeacherResult.subject_name = queryResult[j].subject_name
            resTempTeacherResult.school_id = queryResult[j].school_id;
            resTempTeacherResult.school_name = queryResult[j].school_name;
            resTempTeacherResult.province_id=queryResult[j].province_id
            resTempTeacherResult.city_id = queryResult[j].city_id
            resTempTeacherResult.district_id = queryResult[j].district_id
            ngx.log(ngx.ERR,"excellent_group:=start========================================>",cjson.encode(org_type[j]))
            resTempTeacherResult.excellent_group = arraySort(Split(org_type[j],","));
            --ngx.log(ngx.ERR,"excellent_group:=start==end======================================>",cjson.encode(resTempSchoolResult.excellent_group))
            table.insert(resResult.teacher_list,resTempTeacherResult)
        end
    end
end

--获取json
local function getSpaceTeacherData()
    local resResult = {}
    resResult.success = false
    resResult.info = "成功"
    local sta,org_id,org_type,teacher_type,teacher_name,province,city,district,school,pageNumber,pageSize = pcall(getParams);

    if not sta then
        resResult.info="参数错误！"
        return cjson.encode(resResult)
    end
    ngx.log(ngx.ERR,sta)
    local queryParam = {org_id=org_id,org_type=org_type,teacher_type=teacher_type,teacher_name=teacher_name,pageNumber=pageNumber,pageSize=pageSize}
    local personService = require "base.person.services.PersonService";
    if province=="0" and district=="0" and city=="0" and school=="0" then
        local queryResult = personService:queryTeacherByOrgWithPage(queryParam);
        cjson.encode_empty_table_as_object(false)
        ngx.log(ngx.ERR,"返回数据：",cjson.encode(queryResult))
        if not queryResult then
            resResult.info="接口调用返回错误！"
            return cjson.encode(resResult)
        end
        log.debug(queryResult);
        iteratorData(queryResult,resResult,org_type,pageNumber,pageSize)--查询全部调用接口

        ngx.log(ngx.ERR,"返回resResult：",cjson.encode(resResult))
    else

        local ids,totalRow,totalPage,err = getExcellenceQuery(org_id,org_type,province,city,district,school,pageNumber,pageSize)

        if ids~=nil and #ids>0 then
            ngx.log(ngx.ERR,"============",cjson.encode(ids))
            local id_table = {}
            local org_typet = {}
            for i=1,#ids do
                table.insert(id_table,ids[i]['record_id'])
                table.insert(org_typet,ids[i]['org_type'])
            end
            
            

            local personPageList = personService:getPersonByIds(id_table);
            if not personPageList then
                resResult.info="接口调用返回错误！"
                return cjson.encode(resResult)
            end
            --调用接口，传ids tables.
            iteratorTeacherPageList(personPageList,org_typet,resResult,org_type,totalRow,totalPage,pageNumber,pageSize)
        else
            resResult.teacher_list={}
            resResult.pageSize = pageSize;
            resResult.pageNumber = pageNumber;
            resResult.totalPage = 0;
            resResult.totalRow =0;
        end
    end
    resResult.success = true
    cjson.encode_empty_table_as_object(false)
    mysql:set_keepalive(0,v_pool_size)
    return cjson.encode(resResult)
end

say(getSpaceTeacherData())
