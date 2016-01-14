--[[
微课
@Author  feiliming
@Date    2015-10-19
]]

local len = string.len

local cjson = require "cjson"
local ssdbUtil = require "social.common.ssdbutil"
local redisUtil = require "social.common.redisutil"
local mysqlUtil = require "social.common.mysqlutil"

local _M = {}

--person_id, 必选
--identity_id, 必选
--type_id, 可选, 多个时逗号分隔, 1：收藏 2：我推荐 3：推荐给我 4：我评论 5：反馈 6：我的上传 7：我的共享
--page_number, 可选, 默认1
--page_size, 可选, 默认10
--返回值table
function _M:getWkds(person_id, identity_id, type_id, page_number, page_size) 
	if not person_id or len(person_id) == 0
		or not identity_id or len(identity_id) == 0 then
		return nil,"参数错误"
	end
	if not page_number or len(page_number) == 0 or tonumber(page_number) <= 0 then
		page_number = 1
	end
	if not page_size or len(page_size) == 0 or tonumber(page_size) <= 0 then
		page_size = 10
	end
	local offset = page_size*page_number - page_size
	local limit = page_size
	local str_maxmatches = page_number*100;

	local ssql = "SELECT SQL_NO_CACHE id FROM t_wkds_info_sphinxse WHERE query='filter=b_delete,0;filter=ISDRAFT,0;filter=type,2;filter=type_id,"..type_id..";filter=person_id,"..person_id..";sort=attr_desc:TS;maxmatches="..str_maxmatches..";offset="..offset..";limit="..limit.."';SHOW ENGINE SPHINX  STATUS;"
	--ngx.log(ngx.ERR,"========="..ssql)
	local mysql = mysqlUtil:getDb();
	local r, err = mysql:query(ssql)
	if not r then
		return nil, err
	end

	--去第二个结果集中的Status中截取总个数
	local r2, err = mysql:read_result()
	if not r2 then
		return nil, err
	end
	local _,s_str = string.find(r2[1]["Status"],"found: ")
	local e_str = string.find(r2[1]["Status"],", time:")
	local total_row = string.sub(r2[1]["Status"],s_str+1,e_str-1)
	local total_page = math.floor((total_row+page_size-1)/page_size)

	local redis = redisUtil:getDb();
	local ssdb = ssdbUtil:getDb();
	local wkds_list = {}
	for _, v in ipairs(r) do
		local wkds = {}
		local wkds_id = v.id
		--ngx.log(ngx.ERR,"---------"..wkds_id)
		local wkds_hr = redis:hmget("wkds_"..wkds_id,"wkds_id_int","wkds_name","thumb_id","wk_type_name","content_json")
		--content_json可用计算缩略图
		wkds.id = wkds_id
		wkds.wkds_id_int = wkds_hr[1]
		wkds.wkds_name = wkds_hr[2]
		wkds.thumb_id = wkds_hr[3]
		wkds.wk_type_name = wkds_hr[4]

		table.insert(wkds_list, wkds)
	end

	local rr = {}
	rr.list = wkds_list
	rr.pageNumber = page_number
	rr.pageSize = page_size
	rr.totalRow = total_row
	rr.totalPage = total_page
	return rr
end

return _M