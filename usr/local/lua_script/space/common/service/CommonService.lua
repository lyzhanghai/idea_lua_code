--
-- Created by IntelliJ IDEA.
-- User: zhanghai
-- Date: 2015/10/29 0029
-- Time: 下午 4:13
-- To change this template use File | Settings | File Templates.
--
local log = require("social.common.log")
local TableUtil = require("social.common.table")

local _M = {}
--param
function _M.getFriends(orgid, personid, identityid, identityids, searchtext, pagenum, pagesize)
    local personAndOrgBaseInfoService = require "space.services.PersonAndOrgBaseInfoService";
    local friendService = require "space.services.FriendService";
    local personService = require "base.person.services.PersonService";
    local personResult = personService:queryPersonsByKeyAndOrg(orgid, searchtext, identityids, pagenum, pagesize);
    --log.debug(personResult);
    local result = {}
    if personResult then
        local list = personResult.rows;
        local _list = {}
        if list and TableUtil:length(list) > 0 then
            local personid_temp = {}
            for i = 1, #list do
                local item = {}
                local person_id = list[i]['person_id'];
                -- personid_temp[#personid_temp + 1] = person_id;
                item.person_id = person_id;
                item.identity_id = list[i]['identity_id'];
                table.insert(personid_temp, item);
            end

            local plist = personAndOrgBaseInfoService:getPersonBaseInfoByPersonIdAndIdentityId(personid_temp);
            log.debug(plist);
            if plist and #plist > 0 then
                for i = 1, #plist do
                    local _item = {}
                    _item.avatar_fileid = plist[i]['avatar_fileid'];
                    _item.person_id = list[i]['person_id']
                    _item.person_name = list[i]['person_name']
                    _item.sch_name = list[i]['sch_name']
                    _item.school_id = list[i]['school_id']
                    _item.identity_id = list[i]['identity_id'];

                    _item.isfriend = friendService:isFriend(personid, identityid, _item.person_id, _item.identity_id)
--                    log.debug("personid:"..personid.." identityid:"..identityid)
--                    log.debug("与:"..identityid)
--                    log.debug("personid:".._item.person_id.."identityid:".._item.identity_id.." 好友关系.."..tostring(_item.isfriend))
                    table.insert(_list, _item);
                end
            end
        end
        log.debug(_list);
        result.list = _list;
        result.totalrow = tonumber(personResult.records);
        result.totalpage = personResult.total
        result.pagenum = personResult.page
    end
    return result;
end

return _M;

