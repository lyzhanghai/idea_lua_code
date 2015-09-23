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
	local query_bureau_sql = "select bureau_id,person_id from t_base_person where person_id = "..personId.." and identity_id = "..identityId;
	ngx.log(ngx.ERR, "[hy_log]->[person_info]-> 查询当前教师所在的学校的Sql语句 ===> [[["..query_bureau_sql.."]]]");
	local DBUtil      = require "common.DBUtil";
    local queryBureauResult = DBUtil: querySingleSql(query_bureau_sql);
    if not queryBureauResult then
        return false;
    end
	local bureau_id = queryBureauResult[1]["bureau_id"];
	local query_teacher_sql = "select person_id from t_base_person where bureau_id = "..bureau_id.." and identity_id ="..identityId.." and person_id <> "..personId;
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
	local class_id = queryClassResult[1]["class_id"];
	local query_student_sql = "select student_id from t_base_student where class_id = "..class_id.." and student_id<>"..studentId;
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
	local query_student_sql = "select t2.student_id from T_BASE_CLASS_SUBJECT t1  join  t_base_student t2 on t1.class_id = t2.class_id  where t1.teacher_id = 30317;";
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
    if not queryClassResult then
        return false;
    end
	local class_id = queryClassResult[1]["class_id"];
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


return _PersonInfoModel;