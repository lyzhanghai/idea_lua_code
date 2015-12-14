--[[
好友service
@Author  feiliming
@Date    2015-7-27
]]

local ssdbUtil = require "social.common.ssdbutil"

local _M = {}

function _M:getFriendsByPersonIdAndIdentityId( person_id, identity_id )
	local ssdb = ssdbUtil:getDb()
	local friends = {}

	local z0 = ssdb:zrange("social_friend_sorted_"..identity_id.."_"..person_id, 0, 10000) 
	if z0 and #z0 > 0 and z0[1] ~= "ok" and z0[1] ~= "not_found" then
	    for i=1, #z0, 2 do
	        local friend_id = z0[i]
	        local t0 = ssdb:multi_hget("social_friend_"..friend_id, "fperson_id", "fidentity_id", "apply_time")
	        if t0 and #t0 > 0 and t0[1] ~= "ok" and t0[1] ~= "not_found" then
	            local friend = {}
	            --friend.friend_id = friend_id
	            --friend.group_id = group_id
	            friend.person_id = t0[2]
	            friend.identity_id = t0[4]

	            friends[#friends + 1] = friend
	        end
	    end
	end

	ssdbUtil:keepalive()
	return friends
end

function _M:getFriendsCountByPersonIdAndIdentityId( person_id, identity_id )
	local ssdb = ssdbUtil:getDb()
	local r = ssdb:zsize("social_friend_sorted_"..identity_id.."_"..person_id)
	ssdbUtil:keepalive()
	return r and r[1] or "0"
end

--判断是否已是好友
function _M:isFriend(person_id, identity_id, fperson_id, fidentity_id)
	local ssdb = ssdbUtil:getDb()
	local r = false
	local friending1 = ssdb:hexists("social_friend", identity_id.."_"..person_id.."_"..fidentity_id.."_"..fperson_id)
	local friending2 = ssdb:hexists("social_friend", fidentity_id.."_"..fperson_id.."_"..identity_id.."_"..person_id)
	if friending1 and friending1[1] == "1" then
	    r = true
	end
	if friending2 and friending2[1] == "1" then
	    r = true
	end
	--ssdbUtil:keepalive()
	return r
end

return _M