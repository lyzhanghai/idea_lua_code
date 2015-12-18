--[[
	局部函数：人员信息基础接口
]]
local _PersonInfoModel = {};

---------------------------------------------------------------------------
--[[
	局部函数：获取人员的详细信息（待完善），包括教师和学生
	参数：	personId 	 	人员ID
	参数：	identityId   	身份ID
]]
local function getPersonDetail(self, personId, identityId)
	
	local CacheUtil = require "multi_check.model.CacheUtil";
	local cache = CacheUtil: getRedisConn();
	
	local result, err = cache: hmget("person_" .. personId .. "_" .. identityId, "person_name", "sheng", "shi", "qu", "xiao", "bm");
	if not result or result == ngx.null then 
		CacheUtil: keepConnAlive(cache);
		return false;
	end
	
	local record = {};
	record.person_name 	= result[1];
	record.province_id 	= result[2];
	record.city_id 		= result[3];
	record.district_id 	= result[4];
	record.school_id 	= result[5];
	record.org_id 		= result[6];
	
	CacheUtil: keepConnAlive(cache);
	return record;
end

_PersonInfoModel.getPersonDetail = getPersonDetail;

---------------------------------------------------------------------------
--[[
	局部函数：获取人员的姓名
	参数：	personId 	 	人员ID
	参数：	identityId   	身份ID
]]
local function getPersonName(self, personId, identityId)
	
	local CacheUtil = require "multi_check.model.CacheUtil";
	local cache = CacheUtil: getRedisConn();
	
	local result, err = cache: hmget("person_" .. personId .. "_" .. identityId, "person_name");
	if not result or result == ngx.null then 
		CacheUtil: keepConnAlive(cache);
		return false;
	end
	
	CacheUtil: keepConnAlive(cache);
	return result[1];
end

_PersonInfoModel.getPersonName = getPersonName;


---------------------------------------------------------------------------
--[[
	描述：	根据多个ID获取人员
	参数：	personIds 	 多个人员的ID
	返回值：	table对象，存储多个人员的ID
]]
local function getByIds(self, personIds)
	
	local DBUtil = require "common.DBUtil";
	local sql = "SELECT T1.PERSON_NAME, T1.PERSON_ID, T1.IDENTITY_ID, T1.STAGE_ID, T1.STAGE_NAME, T1.SUBJECT_ID, T1.SUBJECT_NAME, T2.ORG_ID, T2.ORG_NAME FROM T_BASE_PERSON T1 INNER JOIN T_BASE_ORGANIZATION T2 ON T1.BUREAU_ID=T2.ORG_ID WHERE T1.B_USE=1 ";
	
	if personIds ~= nil and #personIds > 0 then
		for index = 1, #personIds do
            local personId = personIds[index];
            if index == 1 then
                sql = sql .. " AND (T1.PERSON_ID=" .. personId;
            else
                sql = sql .. " OR T1.PERSON_ID=" .. personId;
            end

            if index == #personIds then
                sql = sql .. ")";
            end
		end
    else
        return {};
    end

	ngx.log(ngx.ERR, "[sj_log]->[person_info]-> 根据多个ID查询人员的sql语句 ===> ", sql);
    local queryResult = DBUtil: querySingleSql(sql);
	if not queryResult then
		return false;
	end

	local teacherList = {};
	for index = 1, #queryResult do
		local stuRecord = queryResult[index];
		local convertRecord = {};

		convertRecord["person_id"]   = stuRecord["PERSON_ID"];
		convertRecord["identity_id"] = stuRecord["IDENTITY_ID"];
		convertRecord["person_name"] = stuRecord["PERSON_NAME"];
		convertRecord["school_id"]   = tonumber(stuRecord["ORG_ID"]);
		convertRecord["school_name"] = stuRecord["ORG_NAME"];
		convertRecord["province_id"] = stuRecord["PROVINCE_ID"];
		convertRecord["city_id"]     = stuRecord["CITY_ID"];
		convertRecord["district_id"] = stuRecord["DISTRICT_ID"];

		if stuRecord["STAGE_ID"] == ngx.null or stuRecord["STAGE_ID"] == nil or stuRecord["STAGE_ID"]=="" then
			convertRecord["stage_id"]     = 0;
			convertRecord["stage_name"]   = "无";
			convertRecord["subject_id"]   = 0;
			convertRecord["subject_name"] = "无";
		else
			convertRecord["stage_id"]     = stuRecord["STAGE_ID"];
			convertRecord["stage_name"]   = stuRecord["STAGE_NAME"];
			convertRecord["subject_id"]   = stuRecord["SUBJECT_ID"];
			convertRecord["subject_name"] = stuRecord["SUBJECT_NAME"];
		end
		table.insert(teacherList, convertRecord);
	end
    return teacherList;
end

_PersonInfoModel.getByIds = getByIds;
---------------------------------------------------------------------------

--[[
	描述： 获取教师的任教科目
	作者： 申健 2015-05-04
	参数： teacherId  教师ID
]]
local function getTeachSubjectByPersonId(self, teacherId)

    local sql = "SELECT DISTINCT STAGE.STAGE_ID, STAGE.STAGE_NAME, T1.SUBJECT_ID, T2.SUBJECT_NAME, IF(T3.SCHEME_ID IS NULL, 0, 1) AS KNOW_EXIST FROM T_BASE_CLASS_SUBJECT T1 INNER JOIN T_DM_SUBJECT T2 ON T1.SUBJECT_ID=T2.SUBJECT_ID INNER JOIN T_DM_STAGE STAGE ON T2.STAGE_ID=STAGE.STAGE_ID LEFT OUTER JOIN T_RESOURCE_SCHEME T3 ON T1.SUBJECT_ID=T3.SUBJECT_ID AND T3.TYPE_ID=2 AND T3.B_USE=1 WHERE T1.TEACHER_ID=" .. teacherId .. " ORDER BY T2.STAGE_ID, T2.SUBJECT_ID";
    ngx.log(ngx.ERR, "[sj_log]->[person_info]-> 查询教师任教科目的Sql语句 ===> [[[", sql, "]]]");

    local DBUtil      = require "common.DBUtil";
    local queryResult = DBUtil: querySingleSql(sql);
    if not queryResult then
        return false;
    end
    
    local resultTable = {};
    for index=1, #queryResult do
        local record    = queryResult[index];
        local resultObj = {};
        resultObj["stage_id"]        = record["STAGE_ID"];
        resultObj["stage_name"]      = record["STAGE_NAME"];
        resultObj["subject_id"]      = record["SUBJECT_ID"];
        resultObj["subject_name"]    = record["SUBJECT_NAME"];
        resultObj["knowledge_exist"] = record["KNOW_EXIST"];
    	
        table.insert(resultTable, resultObj);
    end
    
    return resultTable;
end

_PersonInfoModel.getTeachSubjectByPersonId = getTeachSubjectByPersonId;


---------------------------------------------------------------------------

--[[
	描述： 获取教师指定科目下任教的班级
	作者： 申健 2015-05-04
	参数： teacherId  教师ID
	参数： subjectId  科目ID
]]
local function getTeachClassesBySubject(self, teacherId, subjectId)

    local sql = "SELECT T1.CLASS_ID, T2.CLASS_NAME FROM T_BASE_CLASS_SUBJECT T1 INNER JOIN T_BASE_CLASS T2 ON T1.CLASS_ID=T2.CLASS_ID WHERE TEACHER_ID=" .. teacherId .. " AND SUBJECT_ID=" .. subjectId .. " ORDER BY CLASS_ID";
    ngx.log(ngx.ERR, "[sj_log]->[person_info]-> 查询在科目[", subjectId, "]下，教师任教班级的Sql语句 ===> [[[", sql, "]]]");

    local DBUtil      = require "common.DBUtil";
    local queryResult = DBUtil: querySingleSql(sql);
    if not queryResult then
        return false;
    end
    
    local resultTable = {};
    for index=1, #queryResult do
        local record = queryResult[index];
        table.insert(resultTable, { class_id=record["CLASS_ID"], class_name=record["CLASS_NAME"] } );
    end
    
    return resultTable;
end

_PersonInfoModel.getTeachClassesBySubject = getTeachClassesBySubject;


---------------------------------------------------------------------------
--[[
    描述： 根绝班级ID ，获取当前学期下所有的老师
    作者： 胡悦 2015-07-07
    参数： calssId  班级ID
]]
local function getTeacherByClass(self,classId)
	local query_term_sql = "select xq_id from t_base_term where sfdqxq=1";
	ngx.log(ngx.ERR, "[hy_log]->[person_info]-> 查询当前学期的Sql语句 ===> [[["..query_term_sql.."]]]");
	local DBUtil      = require "common.DBUtil";
    local queryTermResult = DBUtil: querySingleSql(query_term_sql);
    if not queryTermResult then
        return false;
    end
	local xqId = queryTermResult[1]["xq_id"];
	local query_teacher_sql = "select  distinct(cs.teacher_id),bp.person_name from t_base_class_subject cs join t_base_person bp on cs.teacher_id= bp.person_id where  cs.xq_id = "..xqId.." and cs.class_id = "..classId.." and cs.b_use=1";
	local queryTeacherResult = DBUtil: querySingleSql(query_teacher_sql);
	local resultTable = {};
    for index=1, #queryTeacherResult do
        local record = queryTeacherResult[index];
        table.insert(resultTable, { person_id=record["teacher_id"], person_name=record["person_name"] } );
    end
    
    return resultTable;

end

_PersonInfoModel.getTeacherByClass = getTeacherByClass;
---------------------------------------------------------------------------
--[[
	描述： 通过班级和学科获得任教教师
	作者： 崔金龙 2015-05-04
	参数： class_id,subject_id
]]
local function getTeachByClassSubject(self, class_id,subject_id)
    local sql = "SELECT teacher_id from T_BASE_CLASS_SUBJECT "..
            "where b_use=1 AND CLASS_ID=" .. class_id .. " and SUBJECT_ID="..subject_id..
            " and XQ_ID = (SELECT XQ_ID from t_base_term where SFDQXQ=1) LIMIT 1";
    --ngx.log(ngx.ERR,"#####################"..sql)
    local DBUtil = require "common.DBUtil";
    local queryResult = DBUtil: querySingleSql(sql);
    if not queryResult then
        return false;
    end
    if queryResult and queryResult[1] then
        return queryResult[1].teacher_id;
    else
        return "";
    end
end
_PersonInfoModel.getTeachByClassSubject = getTeachByClassSubject;

---------------------------------------------------------------------------

--[[
    描述： 获取和我一个学校的老师
    作者： 胡悦 2015-07-25
    参数： identityId  身份Id
		   personId 教师ID
    返回值：存储结果的table
]]
local function getMyColleagues(self,identityId,personId)
	local query_bureau_sql = "select bureau_id,person_id from t_base_person where b_use=1 and person_id = "..personId.." and identity_id = "..identityId;
	ngx.log(ngx.ERR, "[hy_log]->[person_info]-> 查询当前教师所在的学校的Sql语句 ===> [[["..query_bureau_sql.."]]]");
	local DBUtil      = require "common.DBUtil";
    local queryBureauResult = DBUtil: querySingleSql(query_bureau_sql);
    if not queryBureauResult then
        return false;
    end
	local bureau_id = queryBureauResult[1]["bureau_id"];
	local query_teacher_sql = "select person_id from t_base_person where b_use=1 and  bureau_id = "..bureau_id.." and identity_id ="..identityId.." and person_id <> "..personId;
	local queryTeacherResult = DBUtil: querySingleSql(query_teacher_sql);
	local resultTable = {};
    for index=1, #queryTeacherResult do
        local record = queryTeacherResult[index];
        table.insert(resultTable, { person_id=record["person_id"], identity_id= identityId} );
    end
    
    return resultTable;

end

_PersonInfoModel.getMyColleagues = getMyColleagues;
---------------------------------------------------------------------------

--[[
    描述： 获取和我一个班级的同学
    作者： 胡悦 2015-07-25
    参数：    studentId 学生Id
    返回值：存储结果的table
]]
local function getMyClassmates(self,studentId)
	local query_class_sql = "select class_id  from t_base_student where student_id = "..studentId;
	ngx.log(ngx.ERR, "[hy_log]->[person_info]-> 查询当前学生所在的班级的Sql语句 ===> [[["..query_class_sql.."]]]");
	local DBUtil      = require "common.DBUtil";
    local queryClassResult = DBUtil: querySingleSql(query_class_sql);
    if not queryClassResult then
        return false;
    end
	local calss_id;
	if queryClassResult and queryClassResult[1] then
		class_id = queryClassResult[1]["class_id"];
	else
		return false;
	end
	
	local query_student_sql = "select student_id from t_base_student where b_use=1 and  class_id = "..class_id.." and student_id<>"..studentId;
	local queryStudentResult = DBUtil: querySingleSql(query_student_sql);
	local resultTable = {};
    for index=1, #queryStudentResult do
        local record = queryStudentResult[index];
        table.insert(resultTable, { student_id=record["student_id"]} );
    end
    
    return resultTable;

end

_PersonInfoModel.getMyClassmates = getMyClassmates;
---------------------------------------------------------------------------

--[[
    描述： 根据老师ID获取我的学生
    作者： 胡悦 2015-07-25
    参数：    personId 教师Id
    返回值：存储结果的table
]]
local function getMyStudents(self,personId)
	local DBUtil      = require "common.DBUtil";
	local query_student_sql = "select t2.student_id from T_BASE_CLASS_SUBJECT t1  join  t_base_student t2 on t1.class_id = t2.class_id  where t2.b_use=1 and t1.teacher_id = "..personId;
	local queryStudentResult = DBUtil: querySingleSql(query_student_sql);
	local resultTable = {};
    for index=1, #queryStudentResult do
        local record = queryStudentResult[index];
        table.insert(resultTable, { student_id=record["student_id"]} );
    end
    
    return resultTable;

end

_PersonInfoModel.getMyStudents = getMyStudents;
---------------------------------------------------------------------------

--[[
    描述： 根据学生ID获取我的老师
    作者： 胡悦 2015-07-25
    参数：    studentId 学生ID
    返回值：存储结果的table
]]
local function getMyTeachers(self,studentId)
	local query_class_sql = "select class_id  from t_base_student where student_id = "..studentId;
	ngx.log(ngx.ERR, "[hy_log]->[person_info]-> 查询当前学生所在的班级的Sql语句 ===> [[["..query_class_sql.."]]]");
	local DBUtil      = require "common.DBUtil";
    local queryClassResult = DBUtil: querySingleSql(query_class_sql);
    if not queryClassResult or queryClassResult[1]==nil then
        return false;
    end
	local calss_id;
	if queryClassResult and queryClassResult[1] then
		class_id = queryClassResult[1]["class_id"];
	else
		return false;
	end
	local query_teacher_sql = "select distinct teacher_id from T_BASE_CLASS_SUBJECT where class_id = "..class_id;
	local queryTeacherResult = DBUtil: querySingleSql(query_teacher_sql);
	local resultTable = {};
    for index=1, #queryTeacherResult do
        local record = queryTeacherResult[index];
        table.insert(resultTable, { teacher_id=record["teacher_id"]} );
    end
    
    return resultTable;

end

_PersonInfoModel.getMyTeachers = getMyTeachers;
---------------------------------------------------------------------------
--[[
    描述： 获取人员信息
	根据person_id和identity_id查询用户详细信息，
	1.如果是教师返回登录名login_name、真实姓名、所属省、市、区、校id及名称，2如果是学生还要增加返回班级id及班级名称
]]
local function getPersonInfo(self,person_id,identity_id)
		local resultTable = {};
		local DBUtil  = require "common.DBUtil";
		local _CacheUtil = require "common.CacheUtil";
		
		local cache = _CacheUtil.getRedisConn();
		local query_login_sql="select login_name from t_sys_loginperson where person_id="..person_id.." and identity_id="..identity_id;
		local query_login_res = DBUtil: querySingleSql(query_login_sql);
		
		if query_login_res==nil or query_login_res[1]==nil or query_login_res[1]["login_name"] == ngx.null then
				resultTable["login_name"]="";
		else 
				resultTable["login_name"]=query_login_res[1]["login_name"];
		end
		local user_cache =_CacheUtil:hmget("person_"..person_id.."_"..identity_id,"person_name","sheng","shi","qu","xiao");
		local person_name = user_cache["person_name"];
		if person_name == nil or person_name == ""  or person_name == ngx.null  then 
			
			return false;
		end
		if tonumber(identity_id)==7 then 
			--local student_id="";
			local query_student_sql="select s.student_id from t_base_parent p join t_base_student s on p.student_id = s.student_id where p.parent_id="..person_id;
			ngx.log(ngx.ERR,"根据家长信息查询学生信息SQL："..query_student_sql);
			local querystudentParentResult = DBUtil: querySingleSql(query_student_sql);
			if querystudentParentResult and querystudentParentResult[1] then
				resultTable["student_id"] = querystudentParentResult[1]["student_id"];
				--家长的信息继承学生的
				person_id= querystudentParentResult[1]["student_id"];
				identity_id=6;
			else
				return false;
			end
		
			--return resultTable;
		end
		
		local province_id = user_cache["sheng"];
		local city_id = user_cache["shi"];
		local district_id = user_cache["qu"];
		
		local bureau_id =  user_cache["xiao"];--单位ID 
		local bureau_type="";                    --单位类型 1为教育局 2学校 3部门
		
		local query_bureau_type_sql="select org_type from t_base_organization where org_id="..bureau_id;
		ngx.log(ngx.ERR,"查询单位类型的SQL："..query_bureau_type_sql);
		
		local query_bureau_type_res = DBUtil: querySingleSql(query_bureau_type_sql);
		
		if  query_bureau_type_res and  query_bureau_type_res[1] then 
			bureau_type=query_bureau_type_res[1]["org_type"];
			
		else
			
			bureau_type="";
		end
		
		
		resultTable["bureau_id"] = bureau_id;
		resultTable["bureau_type"] = bureau_type;
		resultTable["person_name"] = person_name;
		resultTable["province_id"] = province_id;
		resultTable["city_id"] = city_id;
		resultTable["district_id"] = district_id;
		local org_cache = _CacheUtil:hmget("t_base_organization_"..bureau_id,"org_name");
		resultTable["bureau_name"] = org_cache["org_name"];
		if tonumber(bureau_type) == 2 then 
			local school_id = user_cache["xiao"];
			resultTable["school_id"] = school_id;
			resultTable["school_name"] = org_cache["org_name"];
			--查询分校信息 
			local query_branch_school_sql = "select org_id as school_id,org_name as school_name from t_base_organization where main_school_id="..school_id;
			ngx.log(ngx.ERR,"查询分校信息SQL---->"..query_branch_school_sql);
			local query_branch_school_res = DBUtil: querySingleSql(query_branch_school_sql);
			resultTable["branch_school"]=query_branch_school_res;
			
			--查询主校信息
			local query_main_school_sql="select t1.org_id,t1.org_name from t_base_organization t1 inner join t_base_organization t2 on t1.org_id = t2.main_school_id where t2.org_id = "..school_id;
			local query_main_school_res = DBUtil: querySingleSql(query_main_school_sql);
			if query_main_school_res and query_main_school_res[1] then 
				resultTable["main_school_id"]=query_main_school_res[1]["org_id"];
				resultTable["main_school_name"]=query_main_school_res[1]["org_name"];
			else
				resultTable["main_school_id"]="";
				resultTable["main_school_name"]="";
			end
		end
		
		local query_province_sql = "select provincename from t_gov_province where id = "..province_id;
		local query_city_sql="select cityname from t_gov_city where id = "..city_id;
		local query_district_sql="select districtname from t_gov_district where id="..district_id;
		local queryProvinceResult= DBUtil: querySingleSql(query_province_sql);
		if queryProvinceResult and queryProvinceResult[1] then
				resultTable["province_name"] = queryProvinceResult[1]["provincename"];
			else
				resultTable["province_name"] = "";
		end
		local queryCityResult= DBUtil: querySingleSql(query_city_sql);
		if queryCityResult and queryCityResult[1] then
				resultTable["city_name"] = queryCityResult[1]["cityname"];
			else
				resultTable["city_name"] = "";
		end
		
		local queryDistrictResult= DBUtil: querySingleSql(query_district_sql);
		if queryDistrictResult and queryDistrictResult[1] then
				resultTable["district_name"] = queryDistrictResult[1]["districtname"];
			else
				resultTable["district_name"] = "";
		end
		
		
		if tonumber(identity_id) == 6 then
		--学生
			local query_class_sql = "select c.class_id,c.class_name from t_base_student s  join t_base_class c  on s.class_id = c.class_id  where student_id ="..person_id;
			ngx.log(ngx.ERR, "[hy_log]->[person_info]-> 查询学生所在班级 ===> [[["..query_class_sql.."]]]");
		
			local queryClassResult = DBUtil: querySingleSql(query_class_sql);
			if queryClassResult and queryClassResult[1] then
				resultTable["class_id"] = queryClassResult[1]["class_id"];
				resultTable["class_name"] = queryClassResult[1]["class_name"];
			else
				return false;
			end
		
		--查询家长信息
			local query_student_parent_sql="select p.parent_id from t_base_parent p join t_base_student s on p.student_id = s.student_id where s.student_id="..person_id;
			local querystudentParentResult = DBUtil: querySingleSql(query_student_parent_sql);
			if querystudentParentResult and querystudentParentResult[1] then
				resultTable["student_parent_id"] = querystudentParentResult[1]["parent_id"];
			else
				resultTable["student_parent_id"] = "";
			end
			
		end
		--查询角色 
		local query_role_sql="select distinct pr.role_id,r.role_code,r.role_name from t_sys_person_role pr join t_sys_role r on pr.role_id=r.role_id where pr.person_id="..person_id.." and pr.identity_id="..identity_id;
		ngx.log(ngx.ERR,"查询角色的SQL---->"..query_role_sql);
		
		local query_role_res=DBUtil: querySingleSql(query_role_sql);
		resultTable["roles"]=query_role_res;
	
		_CacheUtil:keepConnAlive(cache)
		
		return resultTable;

end
_PersonInfoModel.getPersonInfo = getPersonInfo;

---------------------------------------------------------------------------
--[[
    描述： 根据学校ID获取所有教师
]]
local function getTeachersBySchId(self,school_id,stage_id,subject_id,pageNumber,pageSize)
	local DBUtil      = require "common.DBUtil";
	local cjson = require "cjson"
	local query_sql = "select person_id,person_name,XB_NAME,PERSON_NUM,ORG_ID from t_base_person where identity_id = 5 ";
	if school_id == nil or school_id == "" then 
	
	else
		query_sql = query_sql.." and bureau_id ="..school_id
	end
	
	if stage_id == nil or stage_id == "" then 
	
	else
		query_sql = query_sql.." and stage_id ="..stage_id
	end
	
	
	if subject_id == nil or subject_id == "" then 
	
	else
		query_sql = query_sql.." and subject_id ="..subject_id;
	end
	if pageNumber== nil or pageNumber=="" or pageSize==nil or pageSize=="" then 
	
	else
	
		local offset = pageSize*pageNumber-pageSize
		local limit = pageSize
		query_sql = query_sql.." LIMIT "..offset..","..limit;
	end
	
	
	ngx.log(ngx.ERR,"查询学校下的老师的SQL--->"..query_sql);
	local queryResult= DBUtil: querySingleSql(query_sql);
	local returnResult={};
	if not queryResult then
        return returnResult;
    end
	for i=1,#queryResult do
		local res = {}
		local person_id = queryResult[i]["person_id"]
		local person_name = queryResult[i]["person_name"]
		res.person_id = person_id;
		res.person_name = person_name;
		res.person_num = queryResult[i]["PERSON_NUM"]
		res.xb_name =queryResult[i]["XB_NAME"]
		res.org_id = queryResult[i]["ORG_ID"];
		ngx.log(ngx.ERR,"person_id:"..person_id..",person_name:"..person_name);
	--	local value = ngx.location.capture("/dsideal_yy/person/getPersonTxByYw?person_id="..person_id.."&identity_id=5&yw=ypt")
		--local result = cjson.decode(value.body);
		local result = self:getPersonTx(person_id,5,'ypt');
		--ngx.log(ngx.ERR,result.file_id);
		--{"file_id":"A40F8EF0-92FE-2E68-0E8D-34CB5D22F1D9","extension":"png","success":true}
	--	if result.success then
			res.file_id = result.file_id
			res.extension=result.extension
	--	end
		
		returnResult[i]= res;
	end
	
	return returnResult;

end
_PersonInfoModel.getTeachersBySchId = getTeachersBySchId;
-- -------------------------------------------------------------------------

--[[
    描述： 查询教师数量
]]
local function getTeacherCountBySchId(self,school_id,stage_id,subject_id,pageNumber,pageSize)
	local DBUtil      = require "common.DBUtil";
	local cjson = require "cjson"
	local query_sql = "select count(1) as COUNT from t_base_person where identity_id = 5 ";
	if school_id == nil or school_id == "" then 
	
	else
		query_sql = query_sql.." and bureau_id ="..school_id
	end
	
	if stage_id == nil or stage_id == "" then 
	
	else
		query_sql = query_sql.." and stage_id ="..stage_id
	end
	
	
	if subject_id == nil or subject_id == "" then 
	
	else
		query_sql = query_sql.." and subject_id ="..subject_id;
	end
	
	
	
	ngx.log(ngx.ERR,"查询学校下的老师的SQL--->"..query_sql);
	local queryResult= DBUtil: querySingleSql(query_sql);
	local returnResult={};
	if not queryResult or not queryResult[1] then
        return returnResult;
	else 
		return queryResult[1]["COUNT"];
    end
	
end
_PersonInfoModel.getTeacherCountBySchId = getTeacherCountBySchId;
-- -------------------------------------------------------------------------

--[[
	局部函数：在指定单位下根据用户名模糊查询用户包含教师和学生
	作者： 胡悦 2015-08-27
	参数：unitId  单位ID
]]
local function queryPersonsByKeyAndOrg(self, unitId, personNameKey,identity_ids,pageNumber, pageSize)
	
	local DBUtil = require "common.DBUtil";
	local queryKey = ngx.quote_sql_str("%" .. personNameKey .. "%");
	local unitType =1;
	local offset = pageSize*pageNumber-pageSize;
	local limit  = pageSize;
	local fieldTab = {"PROVINCE_ID", "CITY_ID", "DISTRICT_ID", "BUREAU_ID", "BUREAU_ID"};
	local fieldTab_name = {"PROVINCE_NAME", "CITY_NAME", "DISTRICT_NAME", "SCHOOL_NAME", "ORG_NAME"};
	local countSql = "";
	local sql = "";
	if identity_ids == "5,6" then 
		countSql = "SELECT COUNT(1) AS TOTAL_ROW FROM (".. 
					 " select PERSON_ID, JP,QP,PERSON_NAME,IDENTITY_ID,ORG_ID,BUREAU_ID,PROVINCE_ID,CITY_ID,DISTRICT_ID from T_BASE_PERSON  union all".. 
					 " select S.STUDENT_ID as PERSON_ID,S.JP,S.QP,S.STUDENT_NAME AS PERSON_NAME,6 as IDENTITY_ID, C.ORG_ID,S.BUREAU_ID,O.PROVINCE_ID,O.CITY_ID,O.DISTRICT_ID"..
					 " from T_BASE_STUDENT S  JOIN T_BASE_CLASS C  ON S.CLASS_ID=C.CLASS_ID join T_BASE_ORGANIZATION O ON C.ORG_ID=O.ORG_ID ) PERSON".. 
					" left JOIN T_GOV_PROVINCE PROVINCE ON PERSON.PROVINCE_ID=PROVINCE.ID "..
					" left JOIN T_GOV_CITY CITY ON PERSON.CITY_ID=CITY.ID "..
					" left JOIN T_GOV_DISTRICT DISTRICT ON PERSON.DISTRICT_ID=DISTRICT.ID "..
					" INNER JOIN T_BASE_ORGANIZATION SCHOOL ON PERSON.BUREAU_ID=SCHOOL.ORG_ID "..
					" INNER JOIN T_BASE_ORGANIZATION ORG ON PERSON.ORG_ID=ORG.ORG_ID "..
					" WHERE 1=1  AND (PERSON.QP LIKE " .. queryKey .. " OR PERSON.JP LIKE " .. queryKey .. " OR PERSON.PERSON_NAME LIKE " .. queryKey .. ") AND (PERSON.IDENTITY_ID=5 or PERSON.IDENTITY_ID=6)  ";

	
		sql = "SELECT PERSON.PERSON_ID, PERSON.IDENTITY_ID, PERSON.PERSON_NAME,"..
					" PROVINCE.ID AS PROVINCE_ID, PROVINCE.PROVINCENAME AS PROVINCE_NAME,"..
					" CITY.ID AS CITY_ID, CITY.CITYNAME AS CITY_NAME,".. 
					" DISTRICT.ID AS DISTRICT_ID, DISTRICT.DISTRICTNAME AS DISTRICT_NAME,"..
					" SCHOOL.ORG_ID AS SCHOOL_ID, SCHOOL.ORG_NAME AS SCHOOL_NAME,"..
					" ORG.ORG_ID, ORG.ORG_NAME FROM (".. 
					 " select PERSON_ID, JP,QP,PERSON_NAME,IDENTITY_ID,ORG_ID,BUREAU_ID,PROVINCE_ID,CITY_ID,DISTRICT_ID from T_BASE_PERSON  union all".. 
					 " select S.STUDENT_ID as PERSON_ID,S.JP,S.QP,S.STUDENT_NAME AS PERSON_NAME,6 as IDENTITY_ID, C.ORG_ID,S.BUREAU_ID,O.PROVINCE_ID,O.CITY_ID,O.DISTRICT_ID"..
					 " from T_BASE_STUDENT S  JOIN T_BASE_CLASS C  ON S.CLASS_ID=C.CLASS_ID join T_BASE_ORGANIZATION O ON C.ORG_ID=O.ORG_ID ) PERSON".. 
					" left JOIN T_GOV_PROVINCE PROVINCE ON PERSON.PROVINCE_ID=PROVINCE.ID".. 
					" left JOIN T_GOV_CITY CITY ON PERSON.CITY_ID=CITY.ID".. 
					" left JOIN T_GOV_DISTRICT DISTRICT ON PERSON.DISTRICT_ID=DISTRICT.ID".. 
					" INNER JOIN T_BASE_ORGANIZATION SCHOOL ON PERSON.BUREAU_ID=SCHOOL.ORG_ID".. 
					" INNER JOIN T_BASE_ORGANIZATION ORG ON PERSON.ORG_ID=ORG.ORG_ID".. 
					" WHERE 1=1 AND (PERSON.QP LIKE " .. queryKey .. " OR PERSON.JP LIKE " .. queryKey .. " OR PERSON.PERSON_NAME LIKE " .. queryKey .. ") AND (PERSON.IDENTITY_ID=5 or PERSON.IDENTITY_ID=6)";
		
	elseif identity_ids == "5" then 
		countSql = "SELECT COUNT(1) AS TOTAL_ROW FROM (".. 
					 " select PERSON_ID, JP,QP,PERSON_NAME,IDENTITY_ID,ORG_ID,BUREAU_ID,PROVINCE_ID,CITY_ID,DISTRICT_ID from T_BASE_PERSON ".. 
					" ) PERSON".. 
					" left JOIN T_GOV_PROVINCE PROVINCE ON PERSON.PROVINCE_ID=PROVINCE.ID "..
					" left JOIN T_GOV_CITY CITY ON PERSON.CITY_ID=CITY.ID "..
					" left JOIN T_GOV_DISTRICT DISTRICT ON PERSON.DISTRICT_ID=DISTRICT.ID "..
					" INNER JOIN T_BASE_ORGANIZATION SCHOOL ON PERSON.BUREAU_ID=SCHOOL.ORG_ID "..
					" INNER JOIN T_BASE_ORGANIZATION ORG ON PERSON.ORG_ID=ORG.ORG_ID "..
					" WHERE 1=1  AND (PERSON.QP LIKE " .. queryKey .. " OR PERSON.JP LIKE " .. queryKey .. " OR PERSON.PERSON_NAME LIKE " .. queryKey .. ") AND (PERSON.IDENTITY_ID=5 or PERSON.IDENTITY_ID=6)  ";

	
		sql = "SELECT PERSON.PERSON_ID, PERSON.IDENTITY_ID, PERSON.PERSON_NAME,"..
					" PROVINCE.ID AS PROVINCE_ID, PROVINCE.PROVINCENAME AS PROVINCE_NAME,"..
					" CITY.ID AS CITY_ID, CITY.CITYNAME AS CITY_NAME,".. 
					" DISTRICT.ID AS DISTRICT_ID, DISTRICT.DISTRICTNAME AS DISTRICT_NAME,"..
					" SCHOOL.ORG_ID AS SCHOOL_ID, SCHOOL.ORG_NAME AS SCHOOL_NAME,"..
					" ORG.ORG_ID, ORG.ORG_NAME FROM (".. 
					 " select PERSON_ID, JP,QP,PERSON_NAME,IDENTITY_ID,ORG_ID,BUREAU_ID,PROVINCE_ID,CITY_ID,DISTRICT_ID from T_BASE_PERSON   ) PERSON".. 
					" left JOIN T_GOV_PROVINCE PROVINCE ON PERSON.PROVINCE_ID=PROVINCE.ID".. 
					" left JOIN T_GOV_CITY CITY ON PERSON.CITY_ID=CITY.ID".. 
					" left JOIN T_GOV_DISTRICT DISTRICT ON PERSON.DISTRICT_ID=DISTRICT.ID".. 
					" INNER JOIN T_BASE_ORGANIZATION SCHOOL ON PERSON.BUREAU_ID=SCHOOL.ORG_ID".. 
					" INNER JOIN T_BASE_ORGANIZATION ORG ON PERSON.ORG_ID=ORG.ORG_ID".. 
					" WHERE 1=1 AND (PERSON.QP LIKE " .. queryKey .. " OR PERSON.JP LIKE " .. queryKey .. " OR PERSON.PERSON_NAME LIKE " .. queryKey .. ") AND (PERSON.IDENTITY_ID=5 or PERSON.IDENTITY_ID=6)";
	
	
	
	
	elseif identity_ids == "6" then 
	
		countSql = "SELECT COUNT(1) AS TOTAL_ROW FROM (".. 
					 " select S.STUDENT_ID as PERSON_ID,S.JP,S.QP,S.STUDENT_NAME AS PERSON_NAME,6 as IDENTITY_ID, C.ORG_ID,S.BUREAU_ID,O.PROVINCE_ID,O.CITY_ID,O.DISTRICT_ID"..
					 " from T_BASE_STUDENT S  JOIN T_BASE_CLASS C  ON S.CLASS_ID=C.CLASS_ID join T_BASE_ORGANIZATION O ON C.ORG_ID=O.ORG_ID ) PERSON".. 
					" left JOIN T_GOV_PROVINCE PROVINCE ON PERSON.PROVINCE_ID=PROVINCE.ID "..
					" left JOIN T_GOV_CITY CITY ON PERSON.CITY_ID=CITY.ID "..
					" left JOIN T_GOV_DISTRICT DISTRICT ON PERSON.DISTRICT_ID=DISTRICT.ID "..
					" INNER JOIN T_BASE_ORGANIZATION SCHOOL ON PERSON.BUREAU_ID=SCHOOL.ORG_ID "..
					" INNER JOIN T_BASE_ORGANIZATION ORG ON PERSON.ORG_ID=ORG.ORG_ID "..
					" WHERE 1=1  AND (PERSON.QP LIKE " .. queryKey .. " OR PERSON.JP LIKE " .. queryKey .. " OR PERSON.PERSON_NAME LIKE " .. queryKey .. ") AND (PERSON.IDENTITY_ID=5 or PERSON.IDENTITY_ID=6)  ";

	
		sql = "SELECT PERSON.PERSON_ID, PERSON.IDENTITY_ID, PERSON.PERSON_NAME,"..
					" PROVINCE.ID AS PROVINCE_ID, PROVINCE.PROVINCENAME AS PROVINCE_NAME,"..
					" CITY.ID AS CITY_ID, CITY.CITYNAME AS CITY_NAME,".. 
					" DISTRICT.ID AS DISTRICT_ID, DISTRICT.DISTRICTNAME AS DISTRICT_NAME,"..
					" SCHOOL.ORG_ID AS SCHOOL_ID, SCHOOL.ORG_NAME AS SCHOOL_NAME,"..
					" ORG.ORG_ID, ORG.ORG_NAME FROM (".. 
					 " select S.STUDENT_ID as PERSON_ID,S.JP,S.QP,S.STUDENT_NAME AS PERSON_NAME,6 as IDENTITY_ID, C.ORG_ID,S.BUREAU_ID,O.PROVINCE_ID,O.CITY_ID,O.DISTRICT_ID"..
					 " from T_BASE_STUDENT S  JOIN T_BASE_CLASS C  ON S.CLASS_ID=C.CLASS_ID join T_BASE_ORGANIZATION O ON C.ORG_ID=O.ORG_ID ) PERSON".. 
					" left JOIN T_GOV_PROVINCE PROVINCE ON PERSON.PROVINCE_ID=PROVINCE.ID".. 
					" left JOIN T_GOV_CITY CITY ON PERSON.CITY_ID=CITY.ID".. 
					" left JOIN T_GOV_DISTRICT DISTRICT ON PERSON.DISTRICT_ID=DISTRICT.ID".. 
					" INNER JOIN T_BASE_ORGANIZATION SCHOOL ON PERSON.BUREAU_ID=SCHOOL.ORG_ID".. 
					" INNER JOIN T_BASE_ORGANIZATION ORG ON PERSON.ORG_ID=ORG.ORG_ID".. 
					" WHERE 1=1 AND (PERSON.QP LIKE " .. queryKey .. " OR PERSON.JP LIKE " .. queryKey .. " OR PERSON.PERSON_NAME LIKE " .. queryKey .. ") AND (PERSON.IDENTITY_ID=5 or PERSON.IDENTITY_ID=6)";
	
	
	
	elseif identity_ids == "7" then 
		countSql = "SELECT COUNT(1) AS TOTAL_ROW FROM (".. 
				 " select P.PARENT_ID as PERSON_ID,S.JP,S.QP,P.PARENT_NAME AS PERSON_NAME,6 as IDENTITY_ID, C.ORG_ID,S.BUREAU_ID,O.PROVINCE_ID,O.CITY_ID,O.DISTRICT_ID "..
				 " from T_BASE_PARENT P join  T_BASE_STUDENT S on P.STUDENT_ID = S.STUDENT_ID  JOIN T_BASE_CLASS C  ON S.CLASS_ID=C.CLASS_ID join T_BASE_ORGANIZATION O ON C.ORG_ID=O.ORG_ID "..
				 "  ) PERSON "..
				 " left JOIN T_GOV_PROVINCE PROVINCE ON PERSON.PROVINCE_ID=PROVINCE.ID "..
				 " left JOIN T_GOV_CITY CITY ON PERSON.CITY_ID=CITY.ID "..
				 " left JOIN T_GOV_DISTRICT DISTRICT ON PERSON.DISTRICT_ID=DISTRICT.ID "..
				 " INNER JOIN T_BASE_ORGANIZATION SCHOOL ON PERSON.BUREAU_ID=SCHOOL.ORG_ID "..
				 " INNER JOIN T_BASE_ORGANIZATION ORG ON PERSON.ORG_ID=ORG.ORG_ID "..
				 " WHERE 1=1 AND (PERSON.QP LIKE " .. queryKey .. " OR PERSON.JP LIKE " .. queryKey .. " OR PERSON.PERSON_NAME LIKE " .. queryKey .. ") AND (PERSON.IDENTITY_ID=5 or PERSON.IDENTITY_ID=6)";
	
	
		sql = 	"SELECT PERSON.PERSON_ID, PERSON.IDENTITY_ID, PERSON.PERSON_NAME,  "..
				" PROVINCE.ID AS PROVINCE_ID, PROVINCE.PROVINCENAME AS PROVINCE_NAME,  "..
				 " CITY.ID AS CITY_ID, CITY.CITYNAME AS CITY_NAME, "..
				 " DISTRICT.ID AS DISTRICT_ID, DISTRICT.DISTRICTNAME AS DISTRICT_NAME, "..
				 " SCHOOL.ORG_ID AS SCHOOL_ID, SCHOOL.ORG_NAME AS SCHOOL_NAME, "..
				 " ORG.ORG_ID, ORG.ORG_NAME FROM ( "..
				 " select P.PARENT_ID as PERSON_ID,S.JP,S.QP,P.PARENT_NAME AS PERSON_NAME,6 as IDENTITY_ID, C.ORG_ID,S.BUREAU_ID,O.PROVINCE_ID,O.CITY_ID,O.DISTRICT_ID "..
				 " from T_BASE_PARENT P join  T_BASE_STUDENT S on P.STUDENT_ID = S.STUDENT_ID  JOIN T_BASE_CLASS C  ON S.CLASS_ID=C.CLASS_ID join T_BASE_ORGANIZATION O ON C.ORG_ID=O.ORG_ID "..
				 "  ) PERSON "..
				 " left JOIN T_GOV_PROVINCE PROVINCE ON PERSON.PROVINCE_ID=PROVINCE.ID "..
				 " left JOIN T_GOV_CITY CITY ON PERSON.CITY_ID=CITY.ID "..
				 " left JOIN T_GOV_DISTRICT DISTRICT ON PERSON.DISTRICT_ID=DISTRICT.ID "..
				 " INNER JOIN T_BASE_ORGANIZATION SCHOOL ON PERSON.BUREAU_ID=SCHOOL.ORG_ID "..
				 " INNER JOIN T_BASE_ORGANIZATION ORG ON PERSON.ORG_ID=ORG.ORG_ID "..
				 " WHERE 1=1 AND (PERSON.QP LIKE " .. queryKey .. " OR PERSON.JP LIKE " .. queryKey .. " OR PERSON.PERSON_NAME LIKE " .. queryKey .. ") AND (PERSON.IDENTITY_ID=5 or PERSON.IDENTITY_ID=6)";
	
	end
	
	
	if tonumber(unitId)==99999 then 
	
	else
	
		local CheckPerson = require "multi_check.model.CheckPerson";
		unitType = CheckPerson:getUnitType(unitId);
		ngx.log(ngx.ERR, "[hy_log] -> [person_info] -> 单位类型(unitType)：[" .. unitType .. "]");
		ngx.log(ngx.ERR, "===> 参数：personNameKey -> [", personNameKey, "]");
		local fieldName = fieldTab[unitType];
		
		
			countSql=countSql.." and PERSON." .. fieldName .. "=" .. unitId;
			sql=sql.." and PERSON." .. fieldName .. "=" .. unitId;
		
	end
	sql = sql.. " LIMIT " .. offset .. "," .. limit;
	
	
	ngx.log(ngx.ERR, " ===> countSql语句 ===> ", countSql);
	
	
	
	local res=DBUtil: querySingleSql(countSql);
	
	local totalRow = res[1]["TOTAL_ROW"];
	local totalPage = math.floor((totalRow+pageSize-1)/pageSize);
	ngx.log(ngx.ERR, " ===> sql语句 ===> ", sql);

	local res=DBUtil: querySingleSql(sql);
	if not res then
		return {success=false, info="查询数据出错！"};
	end
	
	local resultListObj = {};
	for i=1, #res do
		local record = {};
		record.person_id   	 = res[i]["PERSON_ID"];
		record.identity_id   = res[i]["IDENTITY_ID"];
		record.person_name   = res[i]["PERSON_NAME"];
		record.unit_type	 = unitType;
		record.province_id 	 = res[i]["PROVINCE_ID"];
		record.province_name = res[i]["PROVINCE_NAME"];
		if res[i]["PROVINCE_NAME"] == nil  or res[i]["PROVINCE_NAME"]==ngx.null then 
			record.province_name 	 = "";
		else
			record.province_name 	 = res[i]["PROVINCE_NAME"];
		
		end
		record.city_id 		 = res[i]["CITY_ID"];
		if res[i]["CITY_NAME"] == nil  or res[i]["CITY_NAME"]==ngx.null then 
			record.city_name 	 = "";
		else
			record.city_name 	 = res[i]["CITY_NAME"];
		
		end
		record.district_id 	 = res[i]["DISTRICT_ID"];
		record.district_name = res[i]["DISTRICT_NAME"];
		if res[i]["DISTRICT_NAME"] == nil  or res[i]["DISTRICT_NAME"]==ngx.null then 
			record.district_name 	 = "";
		else
			record.district_name 	 = res[i]["DISTRICT_NAME"];
		
		end
		record.school_id 	 = res[i]["SCHOOL_ID"];
		record.sch_name 	 = res[i]["SCHOOL_NAME"];
		
		if res[i]["SCHOOL_NAME"] == nil  or res[i]["SCHOOL_NAME"]==ngx.null then 
			record.sch_name 	 = "";
		else
			record.sch_name 	 = res[i]["SCHOOL_NAME"];
		
		end
		record.org_id 		 = res[i]["ORG_ID"];
		record.org_name 	 = res[i]["ORG_NAME"];
	--[[
		if res[i]["STAGE_ID"] == ngx.null or res[i]["STAGE_ID"] == nil or res[i]["STAGE_ID"]=="" or res[i]["STAGE_NAME"] == ngx.null or res[i]["SUBJECT_ID"] == ngx.null or res[i]["SUBJECT_NAME"] == ngx.null then
			record.stage_id 	= 0;
			record.subject_id 	= 0;
			record.subject_name = "--";
		else
			record.stage_id 	= res[i]["STAGE_ID"];
			record.subject_id 	= res[i]["SUBJECT_ID"];
			record.subject_name = res[i]["STAGE_NAME"] .. res[i]["SUBJECT_NAME"];
		end
]]			
		local school_name = "";
		
		for j = unitType + 1, #fieldTab do
			if j == unitType + 1 then
				school_name = res[i][fieldTab_name[j]];
			else
					if res[i][fieldTab_name[j]] ~="" and res[i][fieldTab_name[j]]~=ngx.null then 
						school_name = school_name .. "--" .. res[i][fieldTab_name[j]];
					end
			
			end
		end
		
		record.school_name = school_name;
		table.insert(resultListObj, record);
	end
	
	local resultJsonObj = {};
	resultJsonObj.success   = true;
	resultJsonObj.records   = totalRow;
	resultJsonObj.total 	= totalPage;
	resultJsonObj.page 		= pageNumber;
	resultJsonObj.rows 		= resultListObj;
	

	
	return resultJsonObj;
end

_PersonInfoModel.queryPersonsByKeyAndOrg = queryPersonsByKeyAndOrg;
---------------------------------------------------------------------------
--[[
    描述：需要查询所有人，包括教师、学生、家长等
]]
local function getPersonByClassId(self,class_id)
	local DBUtil = require "common.DBUtil";
	local cjson = require "cjson"
	--1 查询学生
	local query_student_sql="select student_id,student_name from t_base_student where class_id="..class_id;
	ngx.log(ngx.ERR,"查询学生信息SQL："..query_student_sql);
	local student_res=DBUtil: querySingleSql(query_student_sql);
	local resultJsonObj={};
	for i=1,#student_res do
		local record={};
		local student_id = student_res[i]["student_id"];
		record["person_id"]=student_res[i]["student_id"];
		record["person_name"]=student_res[i]["student_name"];
		--local value = ngx.location.capture("/dsideal_yy/person/getPersonTxByYw?person_id="..student_id.."&identity_id=6&yw=ypt")
		--local result = cjson.decode(value.body);
		local result = self:getPersonTx(student_id,6,'ypt');
		record["file_id"]=result.file_id;
		record["extension"]=result.extension;
		record["extension"]=result.extension;
		local query_login_name="select login_name from t_sys_loginperson where person_id ="..student_id.." and identity_id=6"
		local login_res=DBUtil: querySingleSql(query_login_name);
		if login_res == nil  or login_res[1] == nil then
		record["login_name"]="";
		else
		record["login_name"]=login_res[1]["login_name"];
		end
		
		table.insert(resultJsonObj, record);
		
	end
	
	--2查询班主任
	local bzr_id=-1;
	local query_bzr_sql="select p.person_id,p.person_name from t_base_class c  join t_base_person p on c.bzr_id=p.person_id where class_id ="..class_id;
	local query_bzr_res=DBUtil: querySingleSql(query_bzr_sql);
		for i=1,#query_bzr_res do
		local record={};
		local person_id = query_bzr_res[i]["person_id"];
		record["person_id"]=query_bzr_res[i]["person_id"];
		bzr_id=person_id;
		record["person_name"]=query_bzr_res[i]["person_name"];
		--local value = ngx.location.capture("/dsideal_yy/person/getPersonTxByYw?person_id="..person_id.."&identity_id=5&yw=ypt")
		--local result = cjson.decode(value.body);
		local result = self:getPersonTx(person_id,5,'ypt');
		record["file_id"]=result.file_id;
		record["extension"]=result.extension;
		record["extension"]=result.extension;
		local query_login_name="select login_name from t_sys_loginperson where person_id ="..person_id.." and identity_id=5"
		local login_res=DBUtil: querySingleSql(query_login_name);
		if login_res == nil  or login_res[1] == nil then
		record["login_name"]="";
		else
		record["login_name"]=login_res[1]["login_name"];
		end
		table.insert(resultJsonObj, record);
	end
	
	--3查询任课老师
	local query_teacher_sql="select  p.person_id,p.person_name from T_BASE_CLASS_SUBJECT  c  join t_base_person p on c.teacher_id=p.person_id where c.class_id ="..class_id;
	local query_teacher_res=DBUtil: querySingleSql(query_teacher_sql);
		for i=1,#query_teacher_res do
		local record={};
		local person_id = query_teacher_res[i]["person_id"];
		record["person_id"]=query_teacher_res[i]["student_id"];
		record["person_name"]=query_teacher_res[i]["person_name"];
		--local value = ngx.location.capture("/dsideal_yy/person/getPersonTxByYw?person_id="..person_id.."&identity_id=5&yw=ypt")
		--local result = cjson.decode(value.body);
		
		local result = self:getPersonTx(person_id,5,'ypt');
		record["file_id"]=result.file_id;
		record["extension"]=result.extension;
		record["extension"]=result.extension;
		local query_login_name="select login_name from t_sys_loginperson where person_id ="..person_id.." and identity_id=5"
		local login_res=DBUtil: querySingleSql(query_login_name);
		if login_res == nil  or login_res[1] == nil then
		record["login_name"]="";
		else
		record["login_name"]=login_res[1]["login_name"];
		end
		if tonumber(bzr_id)==tonumber(person_id) then 
		
		else
			table.insert(resultJsonObj, record);
		end
	end
	
	return resultJsonObj;
end
_PersonInfoModel.getPersonByClassId = getPersonByClassId;
-- -------------------------------------------------------------------------
--[[
    描述：根据旧的uuid查询登录人信息，统一认证需要 by huyue 2015-09-24
]]
local function getLoginpersonByOlduseruuid(self,old_user_uuid)
	local DBUtil = require "common.DBUtil";
	local sql="select person_name,login_name,identity_id,b_use,person_id from t_sys_loginperson where old_user_uuid="..old_user_uuid;
	ngx.log(ngx.ERR,"根据旧的用户ID查询用户详情SQL："..sql);
	local res=DBUtil: querySingleSql(sql);
	if not res then 
		return false;
	else
		return res[1];
	end

end
_PersonInfoModel.getLoginpersonByOlduseruuid = getLoginpersonByOlduseruuid;
-- -------------------------------------------------------------------------
--[[
	获取person头像
]]
local function getPersonTx(self,person_id,identity_id,yw)
	local _SSDBUtil = require "common.SSDBUtil";
	local tx_info = _SSDBUtil:multi_hget(yw.."_"..person_id.."_"..identity_id,"extension","file_id")
	local res =  {}
	if not tx_info or tx_info[2] == nil then
		res.extension = "jpg";
	else
		res.extension = tx_info[2];
	end
	if not tx_info or tx_info[4] == nil then
		res.file_id = "0D7B3741-0C3D-D93C-BA3D-74668271F934";
	else
		res.file_id = tx_info[4];
	end
	return res;
end
_PersonInfoModel.getPersonTx = getPersonTx;
-- -------------------------------------------------------------------------
return _PersonInfoModel;