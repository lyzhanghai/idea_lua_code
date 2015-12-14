local cjson = require "cjson"
local ssdbUtil = require "social.common.ssdbutil"
local redisUtil = require "social.common.redisutil"
local log = require("social.common.log")

module(..., package.seeall) 

_Author = "feiliming"
_Date = "2015-6-2"
_Description = [[
	空间个人或机构基本信息接口, 使用方法：
	local aService = require "space.services.PersonAndOrgBaseInfoService"
	local rt = aService:getOrgBaseInfo("104", unpack(orgIds))
]]

--获得机构空间管理员设置的机构基本信息
function getOrgBaseInfo(self, orgType, ...)
	local ssdb = ssdbUtil:getDb()
	local orgIds = {...}

	local rt = rt or {}
	for _, orgId in ipairs(orgIds) do
		local ajson, err = ssdb:get("space_ajson_orgbaseinfo_"..orgId.."_"..orgType)
		local r = ajson and ajson[1] and string.len(ajson[1]) > 0 and ajson[1] ~= "not_found" and cjson.decode(ajson[1]) or false

		local t = t or {}
		t.orgId = orgId
		t.org_logo_fileid = r and r.org_logo_fileid or ""
		t.org_scenery_fileid = r and r.org_scenery_fileid or ""
		t.org_description = r and r.org_description_text and ngx.decode_base64(r.org_description_text) or ""
		table.insert(rt, t)
	end

	ssdbUtil:keepalive()
	return rt
end

--获得个人空间基本信息
function getPersonBaseInfo(self, identityId, ...)
	local ssdb = ssdbUtil:getDb()
	local personIds = {...}

	local rt = rt or {}
	for _, personId in ipairs(personIds) do
		local ajson, err = ssdb:get("space_ajson_personbaseinfo_"..personId.."_"..identityId)
		local r = ajson and ajson[1] and string.len(ajson[1]) > 0 and ajson[1] ~= "not_found" and cjson.decode(ajson[1]) or false

		local t = t or {}
		t.personId = personId
		t.avatar_fileid = r and r.space_avatar_fileid or ""
		t.person_description = r and r.person_description and ngx.decode_base64(r.person_description) or ""
		table.insert(rt, t)
	end
	ssdbUtil:keepalive()
	return rt
end

--获得个人空间基本信息, 数组里是table，table的属性是person_id和identity_id
function getPersonBaseInfoByPersonIdAndIdentityId(self, pit)
	local ssdb = ssdbUtil:getDb()
	local redis = redisUtil:getDb()
	local rt = rt or {}
	for _, pi in ipairs(pit) do
		local ajson, err = ssdb:get("space_ajson_personbaseinfo_"..pi.person_id.."_"..pi.identity_id)
        log.debug(ajson);
		local r = ajson and ajson[1] and string.len(ajson[1]) > 0 and ajson[1] ~= "not_found" and cjson.decode(ajson[1]) or false

		local person_name = redis:hget("person_"..pi.person_id.."_"..pi.identity_id, "person_name");

		local t = t or {}
		t.personId = pi.person_id
		t.identity_id = pi.identity_id
		t.person_name = person_name or ""
		t.avatar_fileid = r and r.space_avatar_fileid or ""
		t.person_description = r and r.person_description and ngx.decode_base64(r.person_description) or ""
		table.insert(rt, t)
	end
	ssdbUtil:keepalive()
	redisUtil:keepalive()
	return rt
end

--获得用户名称, 数组里是table，table的属性是person_id和identity_id
function getPersonNameByPersonIdAndIdentityIdTable(self, pit)
	local redis = redisUtil:getDb()
	local rt = rt or {}
	for _, pi in ipairs(pit) do

		local person_name = redis:hget("person_"..pi.person_id.."_"..pi.identity_id, "person_name");

		local t = t or {}
		t.personId = pi.person_id
		t.identity_id = pi.identity_id
		t.person_name = person_name or ""

		table.insert(rt, t)
	end
	redisUtil:keepalive()
	return rt
end

--获得用户名称, 参数是person_id和identity_id
function getPersonNameByPersonIdAndIdentityId(self, person_id, identity_id)
	local redis = redisUtil:getDb()

	local person_name = redis:hget("person_"..person_id.."_"..identity_id, "person_name");
	person_name = person_name or ""

	redisUtil:keepalive()
	return person_name
end

--根据资源id查询资源原文件名、fileid、扩展名
function getResById1(self, rids)
	local ssdb = ssdbUtil:getDb()
	local rids_t = Split(rids, ",")
	local rr = {}
	for _, rid in ipairs(rids_t) do
		local hr, err = ssdb:multi_hget("resource_"..rid, "resource_title", "file_id", "resource_format", "resource_id_int")
		local r = {}
		r.resource_id = rid
		r.resource_title = hr and hr[2] or ""
		r.file_id = hr and hr[4] or ""
		r.resource_format = hr and hr[6] or ""
		r.resource_id_int = hr and hr[8] or ""
		table.insert(rr, r)
	end
	
	ssdbUtil:keepalive()
	return rr
end

local function isEmpty(obj)
	if not obj then
		return true
	end
	if type(obj) == "string" then
		return string.len(obj) == 0
	end
	return false
end

--获取用户空间右上角能看见的菜单
--包括所属机构(省、市、区、校)、所管辖机构、班主任、任课计划
function getPersonSpaceMenu(self, person_id, identity_id)
	--log.debug(person_id.."==="..identity_id)
	local menu = {}
	menu.org_list = {}
	local org_list = {}
	--1教师
	if identity_id == "5" then
		--1.1所属机构
		local personModel = require "base.person.model.PersonInfoModel";
	    local status, personTable  = pcall(personModel.getPersonInfo,personModel,person_id,identity_id)
	    --log.debug(personTable)
	    if not status or not personTable then
	    	return nil
	    end
	    local province_id = not isEmpty(personTable.province_id) and personTable.province_id or nil
	    local province_name = not isEmpty(personTable.province_name) and personTable.province_name or nil
	    if province_id and province_name then
		    local p = {}
		    p.org_id = province_id
		    p.org_name = province_name
		    p.org_level = 101
		    p.flag = 0 --0所属 1所管辖
		    org_list[tostring(province_id).."_"..p.org_level] = p
		end
	    local city_id = not isEmpty(personTable.city_id) and personTable.city_id or nil
	    local city_name = not isEmpty(personTable.city_name) and personTable.city_name or nil
	    if city_id and city_name then
		    local c = {}
		    c.org_id = city_id
		    c.org_name = city_name
		    c.org_level = 102
		    c.flag = 0
		    org_list[tostring(city_id).."_"..c.org_level] = c
		end   
	    local district_id = not isEmpty(personTable.district_id) and personTable.district_id or nil
	    local district_name = not isEmpty(personTable.district_name) and personTable.district_name or nil
	    if district_id and district_name then
		    local d = {}
		    d.org_id = district_id
		    d.org_name = district_name
		    d.org_level = 103
		    d.flag = 0
		    org_list[tostring(district_id).."_"..d.org_level] = d		    
	    end
	    local school_id = not isEmpty(personTable.school_id) and personTable.school_id or nil
	    local school_name = not isEmpty(personTable.school_name) and personTable.school_name or nil
	    if school_id and school_name then
		    local s = {}
		    s.org_id = school_id
		    s.org_name = school_name
		    s.org_level = 104
		    s.flag = 0
		    org_list[tostring(school_id).."_"..s.org_level] = s
		end

	    --1.2所管辖机构
	    local roleService = require "base.role.services.RoleService"
	    local role_code = "PROVINCE_BUREAU_ADMIN,CITY_BUREAU_ADMIN,DISTRICT_BUREAU_ADMIN,SCHOOL_ADMIN"
	    local status, result = pcall(roleService.getRoleOrgTreeByRoleCodeAndPersonId, roleService, person_id,role_code,identity_id)
	    --log.debug(status)
	    log.debug(result)
	    if status and result and result.success then
	    	--合并
		    for _, v in ipairs(result.table_List) do
		    	if v.ORG_LEVEL and v.ORG_ID and v.ORG_NAME then
		    		local p = {}
				    p.org_id = v.ORG_ID
				    p.org_name = v.ORG_NAME
				    p.org_level = v.ORG_LEVEL == 1 and 101 or (v.ORG_LEVEL == 2 and 102 or (v.ORG_LEVEL == 3 and 103 or (v.ORG_LEVEL == 4 and 104 or (v.ORG_LEVEL == 6 and 100 or 0))))
				    p.flag = 1
				    org_list[tostring(p.org_id).."_"..p.org_level] = p
				end
		    end
	    end

	    --1.3任课计划
	    --local teach_list = {}
        local url = "/dsideal_yy/space/base/getClassInfoByTeacher?person_id="..person_id
	    local data0 = ngx.location.capture(url)
	    if data0 and data0.status == 200 then
	    	cjson.encode_empty_table_as_object(false)
        	local result_t = cjson.decode(data0.body)
        	if result_t and result_t.success then
		    	--合并
			    for _, v in ipairs(result_t.classlist) do
			    	if v.id and v.name then
			    		local p = {}
					    p.org_id = v.id
					    p.org_name = v.name
					    p.org_level = 105
					    p.flag = 0
					    org_list[tostring(p.org_id).."_"..p.org_level] = p
					end
			    end        		
        	end
	    end

	    --1.4班主任
	    local url1 = "/dsideal_yy/ypt/space/personIsClassTeacher?person_id="..person_id
	    local data = ngx.location.capture(url1)
	    if data and data.status == 200 then
	    	cjson.encode_empty_table_as_object(false)
        	local result_t = cjson.decode(data.body)
        	if result_t and result_t.success and result_t.isClassTeacher then
		    	--合并
			    for _, v in ipairs(result_t.class_list) do
			    	if v.class_id and v.class_name then
			    		local p = {}
					    p.org_id = v.class_id
					    p.org_name = v.class_name
					    p.org_level = 105
					    p.flag = 1
					    org_list[tostring(p.org_id).."_"..p.org_level] = p
					end
			    end        		
        	end
	    end

	--2学生、家长
	else 
		--2.1所属机构
		local personModel = require "base.person.model.PersonInfoModel";
	    local status, personTable  = pcall(personModel.getPersonInfo,personModel,person_id,identity_id)
	    log.debug(personTable)
	    if not status or not personTable then
	    	return nil
	    end
	    local school_id = not isEmpty(personTable.school_id) and personTable.school_id or nil
	    local school_name = not isEmpty(personTable.school_name) and personTable.school_name or nil
	    if school_id and school_name then
		    local s = {}
		    s.org_id = school_id
		    s.org_name = school_name
		    s.org_level = 104
		    org_list[tostring(school_id).."_"..s.org_level] = s
		end
	    local class_id = not isEmpty(personTable.class_id) and personTable.class_id or nil
	    local class_name = not isEmpty(personTable.class_name) and personTable.class_name or nil
	    if class_id and class_name then
		    local s = {}
		    s.org_id = class_id
		    s.org_name = class_name
		    s.org_level = 105
		    org_list[tostring(class_id).."_"..s.org_level] = s
		end		
	end

	for _, v in pairs(org_list) do
		table.insert(menu.org_list, v)
    end 
	return menu
end