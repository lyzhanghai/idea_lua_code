--
--    张海  2015-05-06
--    描述：  BBS service 接口.
--
local util = require("social.common.util")
local DBUtil = require "common.DBUtil";
local TableUtil = require("social.common.table")
local SsdbUtil = require("social.common.ssdbutil")
local TotalService = require("social.service.BbsTotalService")
local BbsService = {}

--------------------------------------------------------------------------------
--通过id获取bbs信息
--@param #string bbsid
--@result #table result bbs信息
function BbsService:getBbsByIdFromDb(bbsid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbs id 不能为空.")
    end
    local sql = string.format("SELECT * FROM T_SOCIAL_BBS WHERE ID=%s",bbsid);
    local result = DBUtil: querySingleSql(sql);
    return result
end


--------------------------------------------------------------------------------
--通过bbsid获取未删除的区.
--@param string bbsid .
--@return table 查询的bbs分区列表.
function BbsService:getPartitions(bbsid)
    local sql = "SELECT * FROM T_SOCIAL_BBS_PARTITION T WHERE T.BBS_ID=" .. bbsid.." AND T.B_DELETE=0 ORDER BY T.SEQUENCE";
    util:logData("通过论坛id查询分区表sql:"..sql);
    local queryResult = DBUtil: querySingleSql(sql);
    return queryResult;
end


--------------------------------------------------------------------------------
--通过bbsid与partitionid获取未删除的版块列表.
--@param #string bbsid
--@param #string partitionid.
function BbsService:getForums(bbsid,partitionid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbsid 不能为空.")
    end
    if partitionid==nil or string.len(partitionid)==0 then
        error("partitionid 不能为空.")
    end
    local sql = string.format("SELECT * FROM T_SOCIAL_BBS_FORUM T WHERE T.BBS_ID=%s AND T.PARTITION_ID=%s AND T.B_DELETE=0 ORDER BY T.SEQUENCE", bbsid,partitionid);
    util:logData("通过bbsid与partitionid获取版块列表sql:"..sql);
    local queryResult = DBUtil: querySingleSql(sql);
    return queryResult;
end

--------------------------------------------------------------------------------
--对模块下的帖数个数进行修改.
--
function BbsService:updateForumTopicPostNumber(forumid)
--    if forumid==nil or string.len(forumid)==0 then
--        error("forumid 不能为空.")
--    end
--     local db = DBUtil:getDb()
--    local selectLastpostTimeSql = "SELECT (NOW()-T.LAST_POST_TIME) V FROM T_SOCIAL_BBS_FORUM T WHERE'"..forumid.."'"
--    local result = db.query(selectLastpostTimeSql);
--    if result then
--         local r = tonumber(result[1]["V"])
--         if r<=0 then
--             "UPDATE T_SOCIAL_BBS_FORUM SET POST_TODAY=POST_TODAY+1 WHERE ID='"..forumid.."'"
--         else
--
--         end
--    end
--
--    local todaySql = "UPDATE T_SOCIAL_BBS_FORUM SET POST_TODAY=POST_TODAY+1 WHERE ID='"..forumid.."'"
--
end
--------------------------------------------------------------------------------
--通过fourmid获取fourm.
--@param #string fourmid
function BbsService:getForumById(fourmid)
    if fourmid==nil or string.len(fourmid)==0 then
        error("fourmid 不能为空.")
    end
    local sql = string.format("SELECT T.ID,T.BBS_ID,T.PARTITION_ID,T.NAME,T.ICON_URL,T.DESCRIPTION,T.SEQUENCE,T.B_DELETE,T.PID,T.POST_TODAY,T.POST_YESTODAY,T.TOTAL_TOPIC FROM T_SOCIAL_BBS_FORUM T WHERE T.ID=%s", fourmid);
    util:logData("通过fourmid获取版块列表sql:"..sql);
    local queryResult = DBUtil: querySingleSql(sql);
    return queryResult;
end




--------------------------------------------------------------------------------
--通过userid获取user

--------------------------------------------------------------------------------
--通过forumid,personid,identityid,personname,flag保存用户与版块关系.
--@param #string forumid
--@param #string personid
--@param #string identityid
--@param #string personname
--@param #string flag
function BbsService:saveForumUser(forumid,personid,identityid,personname,flag)
    local result={}
    if forumid and string.len(forumid)>0 and personid and string.len(personid)>0 and  identityid and string.len(identityid)>0 then
        forumid = tonumber(forumid);
        personid = tonumber(personid);
        identityid = tonumber(identityid);
        flag = tonumber(flag);
        local sql = string.format("INSERT INTO `T_SOCIAL_BBS_FORUM_USER` (`FORUM_ID`, `PERSON_ID`, `IDENTITY_ID`, `PERSON_NAME`, `FLAG`) VALUES (%d, %d, %d, %s, %d)", forumid,personid,identityid,personname,flag);
        util:logData("保存版块用户关系表sql:"..sql);
        result = DBUtil: querySingleSql(sql);
    end
    return result;
end

--------------------------------------------------------------------------------
--验证用户是否可以在此bbs发贴
function BbsService:checkForumUser(personid,bbsid)

    ---通过用户personid获取用户
    --  去基础信息中通过personid获取用户机构（省市区校）id.
    --  获取province_id,city_id,area_id,school_id
    --
    local bbsResult =  self:getBbsByIdFromDb(bbsid)

    if bbsResult and TableUtil.length(bbsResult[1])>0 then
        local bbs = bbsResult[1]
        local regionid = bbs["region_id"]
        --判断是否存在与province_id,city_id,area_id,school_id之中
        return true
    end
    return false

end

--------------------------------------------------------------------------------
--通过bbsid获取区信息，版块信息.(通过数据库获取)
--@param #string bbsid
--@return #table bbs信息首页.
--
--function BbsService:getBbsById(bbsid)
--    if bbsid==nil or string.len(bbsid)==0 then
--        error("bbs id 不能为空.")
--    end
--    local db = DBUtil:getDb();
--    --从mysql判断
--    local ssql = "select id,region_id,name,logo_url,icon_url,domain,status,social_type from t_social_bbs WHERE id = "..bbsid.." and social_type = 1"
--    local sresult, err = db:query(ssql)
--    if not sresult then
--        return false;
--    end
--    local bbs = {}
--    if sresult and #sresult > 0 then
--        bbs = sresult[1]
--        local partitioin_list = {}
--        local psql = "select id,bbs_id,name,sequence from t_social_bbs_partition where bbs_id = "..bbs.id.." and b_delete = 0 order by sequence"
--        local presult, err = db:query(psql)
--        if presult and #presult > 0 then
--            for i=1, #presult do
--                --forum
--                local partitioin = presult[i]
--                local fsql = "select id,bbs_id,partition_id,name,icon_url,description,sequence,replyer_time from t_social_bbs_forum where partition_id = "..partitioin.id.." and b_delete = 0 order by sequence"
--                local fresult, err = db:query(fsql)
--                local forum_list = {}
--                if fresult and #fresult > 0 then
--                    for j=1, #fresult do
--                        forum_list[#forum_list + 1] = fresult[j]
--                    end
--                end
--                partitioin.forum_list = forum_list
--                partitioin_list[#partitioin_list + 1] = partitioin
--            end
--        end
--        bbs.partitioin_list = partitioin_list
--    end
--end


--------------------------------------------------------------------------------
--
--
local db ={}
local function getFourmById(bbsid,fid)
    local keys = {"id","name","last_post_time","total_topic","total_topic_post"}
    local fourm =  db:multi_hget("social_bbs_forum_"..fid,unpack(keys))
    local _fourm= {}
    if fourm and #fourm>0 then
        _fourm=  util:multi_hget(fourm,keys)
        _fourm.total_topic = TotalService:getForumTopicHistoryNumber(bbsid,fid)--此版块主题帖数(包括历史)
        _fourm.total_topic_post=TotalService:getForumPostHistoryNum(bbsid,fid)+ _fourm.total_topic--此版块主题帖数+回复帖数(包括历史)
    end
    return _fourm;
end
---通过bbsid获取区信息，版块信息.(通过ssdb获取)
--@param #string bbsid
--@return #table bbs信息首页.
--
function BbsService:getBbsById(bbsid)
    if bbsid==nil or string.len(bbsid)==0 then
        error("bbs id 不能为空.")
    end
    db = SsdbUtil:getDb();
    local keys = {"id","total_today","total_yestoday","total","name","logo_url","icon_url","domain"}
    local bbsResult = db:multi_hget("social_bbs_"..bbsid,unpack(keys))
    for key, var in pairs(bbsResult) do
        util:logData(var)
    end
    local bbs = {}
    if bbsResult and #bbsResult>0 then
        bbs = util:multi_hget(bbsResult,keys)--工具实现对multi_hget解析
        bbs.partition_list={}
    else
        return nil
    end
    local SOCIAL_BBS_INCLUDE_PARTITION = "social_bbs_include_partition";
    local partitionResult = db:hget(SOCIAL_BBS_INCLUDE_PARTITION,"bbs_id_"..bbsid)
    local partition_list = {}
    if partitionResult and string.len(partitionResult[1]) > 0 then
        local pidstr =  partitionResult[1]
        util:logData("pids 集合:"..pidstr);
        local pids = Split(pidstr,",")
        util:logData(pids);
        for _, pid in ipairs(pids) do
            local partition =  db:multi_hget("social_bbs_partition_"..pid,"id","bbs_id","name","sequence")
            util:logData("获取分区信息:");
            util:logData(partition);
            if partition and #partition>0 then
                partition_list.forum_list={}
                util:logData(partition);
                partition_list.id=partition[2];
                partition_list.bbs_id=partition[4];
                partition_list.name=partition[6];
                partition_list.sequence=partition[8];
                partition_list.forum_list={}
                local SOCIAL_BBS_INCLUDE_FORUM = "social_bbs_include_forum";
                local forumResult = db:hget(SOCIAL_BBS_INCLUDE_FORUM,"partition_id_"..partition[2])
                local forum_list = {}
                if forumResult and string.len(forumResult[1]) > 0 then
                    local fidstr =  forumResult[1]
                    local fids = Split(fidstr,",")
                    util:logData("fids 集合:");
                    util:logData(fids);
                    for _, fid in ipairs(fids) do
                        local _fourm = getFourmById(bbsid,fid)
                        table.insert(forum_list,_fourm)
                    end
                end
                table.insert(partition_list.forum_list,forum_list)
            end
        end
    end
    --util:logData("partition_list 集合:"..partition_list);
    table.insert(bbs.partition_list,partition_list)
    SsdbUtil:keepalive(db)
    return bbs;
end
return BbsService;
