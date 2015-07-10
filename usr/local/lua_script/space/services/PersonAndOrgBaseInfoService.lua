local cjson = require "cjson"
local ssdbUtil = require "social.common.ssdbutil"

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
		local r = ajson and ajson[1] and string.len(ajson[1]) > 0 and cjson.decode(ajson[1]) or false

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
		local r = ajson and ajson[1] and string.len(ajson[1]) > 0 and cjson.decode(ajson[1]) or false

		local t = t or {}
		t.personId = personId
		t.avatar_fileid = r and r.space_avatar_fileid or ""
		t.person_description = r and r.person_description and ngx.decode_base64(r.person_description) or ""
		table.insert(rt, t)
	end
	ssdbUtil:keepalive()
	return rt
end

--获得个人空间基本信息,...为数组，数组里是table，table的属性是person_id和identity_id
function getPersonBaseInfoByPersonIdAndIdentityId(self, ...)
	local ssdb = ssdbUtil:getDb()
	local pit = {...}

	local rt = rt or {}
	for _, pi in ipairs(pit) do
		local ajson, err = ssdb:get("space_ajson_personbaseinfo_"..pi.person_id..."_"..pi.identity_id)
		local r = ajson and ajson[1] and string.len(ajson[1]) > 0 and cjson.decode(ajson[1]) or false

		local t = t or {}
		t.personId = pi.person_id
		t.avatar_fileid = r and r.space_avatar_fileid or ""
		t.person_description = r and r.person_description and ngx.decode_base64(r.person_description) or ""
		table.insert(rt, t)
	end
	ssdbUtil:keepalive()
	return rt
end