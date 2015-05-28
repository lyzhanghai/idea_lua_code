local DBUtil = require "common.DBUtil";
local TableUtil = require("social.common.table")
local log = require("social.common.log")
local RedisUtil = require("social.common.redisutil")
local quote = ngx.quote_sql_str
local M = {}
local VideoService = M


---------------------------------------------------------------
-- 创建视频文件夹
-- Person_id：用户id
-- Identity_id：身份id
-- Folder_name：文件夹名称
-- Is_private：0公有,1私有
function M:createVideoFolder(personId, identityId, folderName, isPrivate)
    if personId == nil or string.len(personId) == 0 then
        error("personId 不能为空.")
    end
    if identityId == nil or string.len(identityId) == 0 then
        error("identityId 不能为空.")
    end
    if folderName == nil or string.len(folderName) == 0 then
        error("folderName 不能为空.")
    end
    if isPrivate == nil or string.len(isPrivate) == 0 then
        error("isPrivate 不能为空.")
    end
    local sql = "INSERT INTO T_SOCIAL_VIDEO_FOLDER(PERSON_ID, IDENTITY_ID, FOLDER_NAME, CREATE_TIME,  IS_PRIVATE, IS_DEFAULT,VIDEO_NUM) VALUES (" ..
            personId .. "," .. identityId .. "," .. quote(folderName) .. ",now()," .. isPrivate .. ",0,0)"
    local result = DBUtil:querySingleSql(sql);
    return result
end

---------------------------------------------------------------
-- 编辑视频文件夹
-- @param #string Folder_id：文件夹id
-- @param #string Folder_name：文件夹名称
-- @param #string Is_private：0公有,1私有
function M:editVideoFolder(folderName, isPrivate, folderId)
    if folderId == nil or string.len(folderId) == 0 then
        error("folderId 不能为空.")
    end
    if isPrivate == nil or string.len(isPrivate) == 0 then
        error("isPrivate 不能为空.")
    end
    if folderName == nil or string.len(folderName) == 0 then
        error("folderName 不能为空.")
    end
    local sql = "UPDATE T_SOCIAL_VIDEO_FOLDER SET FOLDER_NAME = " .. quote(folderName) .. ",IS_PRIVATE = " .. quote(isPrivate) ..
            " WHERE ID = " .. quote(folderId)
    local result = DBUtil:querySingleSql(sql);
    return result
end

----------------------------------------------------------------
-- 通过id获取文件夹信息.
function M:getVideoFolderById(folderId)
    if folderId == nil or string.len(folderId) == 0 then
        error("folderId 不能为空.")
    end
    local sql = "SELECT * FROM T_SOCIAL_VIDEO_FOLDER T WHERE ID = " .. quote(folderId)
    local result = DBUtil:querySingleSql(sql);
    return result
end

----------------------------------------------------------------
-- 删除视频文件夹 1
-- Folder_id：文件夹id
function M:deleteVideoFolder(folderId)
    if folderId == nil or string.len(folderId) == 0 then
        error("folderId 不能为空.")
    end
    local db = DBUtil:getDb();
    local dsql = "UPDATE T_SOCIAL_VIDEO SET IS_DELETE=1 WHERE FOLDER_ID = " .. quote(folderId)
    local dresutl, err = db:query(dsql)
    if dresutl then
        local dsql1 = "UPDATE T_SOCIAL_VIDEO_FOLDER SET IS_DELETE=1 WHERE ID = " .. quote(folderId)
        local dresutl1, err = db:query(dsql1)
        if dresutl1 then
            return true;
        end
    end
    return false;
end

-----------------------------------------------------------------
-- 获取视频文件列表.
-- @param #string Person_id：用户id
-- @param #string Identity_id：身份id
-- @param #string Is_private：0公有,1私有,不传查所有
function M:getVideoFolder(personId, identityId, isPrivate)
    if personId == nil or string.len(personId) == 0 then
        error("personId 不能为空.")
    end
    if identityId == nil or string.len(identityId) == 0 then
        error("identityId 不能为空.")
    end
    if isPrivate == nil or string.len(isPrivate) == 0 then
        error("isPrivate 不能为空.")
    end
    local sql = "SELECT * FROM T_SOCIAL_VIDEO_FOLDER t WHERE PERSON_ID = " .. quote(personId) .. " AND IDENTITY_ID = " .. quote(identityId) .. " AND IS_DELETE=0"
    if isPrivate and string.len(isPrivate) > 0 then
        sql = sql .. " AND IS_PRIVATE = " .. tonumber(isPrivate)
    end
    sql = sql .. " ORDER BY CREATE_TIME ASC"
    log.debug("获取视频文件列表.sql:"..sql)
    local result = DBUtil:querySingleSql(sql);

    log.debug(result);
    --    log.debug(result)
    --    local list = {}
    --    if result then
    --        for i = 1, #result do
    --            local t = {}
    --            local _result = result[i];
    --            t.id = _result["id"]
    --        end
    --    end
    return result;
end

-----------------------------------------------------------------
-- 通过id获取文件夹信息.
-- @param #string folder_id：文件夹id
function M:getFolderById(id)
    if id == nil or string.len(id) == 0 then
        error("id 不能为空.")
    end
    local sql = "SELECT * FROM T_SOCIAL_VIDEO_FOLDER t WHERE id = " .. quote(id)
    local result = DBUtil:querySingleSql(sql);
    return result;
end

-----------------------------------------------------------------
-- 创建视频文件.
-- @param #string Person_id：用户id
-- @param #string Identity_id：身份id
-- @param #string Folder_id：文件夹id
-- @param #string video_name：视频名称
-- @param #string file_id：file_id加扩展名
-- @param #string file_size：视频大小
-- @param #string description：视频说明描述
function M:createVideo(personId, identityId, folderId, videoName, fileId, fileSize, description,resourceId)
    if personId == nil or string.len(personId) == 0 then
        error("personId 不能为空.")
    end
    if identityId == nil or string.len(identityId) == 0 then
        error("identityId 不能为空.")
    end
    if folderId == nil or string.len(folderId) == 0 then
        error("folderId 不能为空.")
    end
    if videoName == nil or string.len(videoName) == 0 then
        error("videoName 不能为空.")
    end
    if fileId == nil or string.len(fileId) == 0 then
        error("fileId 不能为空.")
    end
    if fileSize == nil or string.len(fileSize) == 0 then
        error("fileSize 不能为空.")
    end
    if description == nil or string.len(description) == 0 then
        error("description 不能为空.")
    end
    if resourceId == nil or string.len(resourceId) == 0 then
        error("resourceId 不能为空.")
    end
   -- local resourceId = "" --调用平台接口，保存资源信息，然后返回 resourceid.
    local sql = "INSERT INTO  t_social_video (person_id,identity_id,folder_id,video_name,file_id,file_size,description,resource_id)"
    local value = " values(" .. personId .. "," .. identityId .. "," .. folderId .. "," .. quote(videoName) .. "," .. fileId .. "," .. fileSize .. "," .. quote(description) .. "," .. resourceId .. ")"
    sql = sql .. value;
    local db = DBUtil:getDb();
    local result = db:query(sql);
    --照片数加1
    local usql = "UPDATE T_SOCIAL_VIDEO_FOLDER SET VIDEO_NUM = VIDEO_NUM + 1 WHERE ID = " .. quote(folderId)
    local status = db:query(usql)
    if status and result then
        return true
    else
        return false;
    end
end

-----------------------------------------------------------------
-- 编辑视频文件信息.
-- @param #string video_id：照片id
-- @param #string video_name：文件夹名称
-- @param #string description：视频描述、说明
function M:editVideo(videoId, videoName, description)
    if videoId == nil or string.len(videoId) == 0 then
        error("videoId 不能为空.")
    end
    if videoName == nil or string.len(videoName) == 0 then
        error("videoName 不能为空.")
    end
    if description == nil or string.len(description) == 0 then
        error("description 不能为空.")
    end
    local sql = "UPDATE T_SOCIAL_VIDEO SET VIDEO_NAME=%s,DESCRIPTION=%s WHERE ID=%d"
    sql = string.format(sql, quote(videoName), quote(description), videoId)
    local result = DBUtil:querySingleSql(sql);
    return result;
end



local function reloadResourceM3U8Info(result)
    if result then
        if TableUtil:length(result) > 0 then
            local db = RedisUtil:getDb()
            for i = 1, #result do
                local resourceId =  result[i]['resource_id'];
                log.debug("在redis中获取 资源信息.key: resource_"..resourceId)
                local resRecord = db:hmget("resource_"..resourceId,"m3u8_status","m3u8_url","thumb_id")
                log.debug(resRecord)
                if resRecord~=ngx.null then
                    local m3u8_status = tostring(resRecord[1])
                    local m3u8_url = tostring(resRecord[2])
                    local thumb_id = tostring(resRecord[3])
                    result[i].m3u8_status = m3u8_status
                    result[i].m3u8_url = m3u8_url
                    result[i].thumb_id = thumb_id
                end
            end
        end
    end

end
-----------------------------------------------------------------
-- 通过video_id获取视频.
-- @param #string video_id：照片id
function M:getVideoById(id)
    if id == nil or string.len(id) == 0 then
        error("id 不能为空.")
    end
    local sql = "SELECT *  FROM T_SOCIAL_VIDEO WHERE ID=%d";
    sql = string.format(sql, id);
    local result = DBUtil:querySingleSql(sql);
    reloadResourceM3U8Info(result)
    return result;
end

-----------------------------------------------------------------
-- 删除视频，可以批量删除 1
-- @param #string video_ids：照片id，多个用逗号分隔
function M:deleteVideo(ids)
    --    local idas = Split(ids, ",")
    --    for i = 1,#idas  do
    --        idas[i]
    --    end
    if ids == nil or string.len(ids) == 0 then
        error("id 不能为空.")
    end
    local sql = "UPDATE T_SOCIAL_VIDEO SET IS_DELETE=1 WHERE ID IN(" .. ids .. ")"
    log.debug("删除视频sql:"..sql)
    local result = DBUtil:querySingleSql(sql)

    return result;
end

-----------------------------------------------------------------
-- 获取视频列表.
-- @param #string Folder_id：文件夹id
-- @param #string pageNumber：第几页
-- @param #string pageSize：每页条数
function M:getVideoList(folderId, pageNumber, pageSize)
    if folderId == nil or string.len(folderId) == 0 then
        error("folderId 不能为空");
    end
    if pageNumber == nil or string.len(pageNumber) == 0 then
        error("pageNumber 不能为空");
    end

    if pageSize == nil or string.len(pageSize) == 0 then
        error("pageSize 不能为空");
    end
    local count_sql = "SELECT COUNT(*) as totalRow FROM T_SOCIAL_VIDEO T WHERE T.FOLDER_ID=" .. folderId .. " AND IS_DELETE=0"
    local list_sql = "SELECT *  FROM T_SOCIAL_VIDEO T WHERE T.FOLDER_ID=" .. folderId .. " AND IS_DELETE=0"
    log.debug("获取主题帖列表.count_sql:" .. count_sql);
    local count = DBUtil:querySingleSql(count_sql);
    if TableUtil:length(count) == 0 then
        return false;
    end
    log.debug("获取视频列表.count:" .. count[1].totalRow);
    local _pagenum = tonumber(pageNumber)
    local _pagesize = tonumber(pageSize)
    local totalRow = count[1].totalRow
    local totalPage = math.floor((totalRow + _pagesize - 1) / _pagesize)
    local offset = _pagesize * _pagenum - _pagesize
    list_sql = list_sql .. " LIMIT " .. offset .. "," .. _pagesize
    log.debug("获取视频列表.list sql:" .. list_sql);
    local list = DBUtil:querySingleSql(list_sql);
    if list then
        log.debug("获取视频列表.list :");
        log.debug(list)
        reloadResourceM3U8Info(list)--加载m3u8信息.
        local result = { video_list = list, totalRow = totalRow, totalPage = totalPage, pageNumber = pageNumber, pageSize = pageSize }
        return result;
    else
        return false;
    end
end

-----------------------------------------------------------------
-- 视频移动，可以批量移动
-- @param #string video_ids：照片id，多个用逗号分隔
-- @param #string from_folder_id：从文件夹id
-- @param #string to_folder_id：移动到文件夹id
function M:moveVideos(videoIds, fromFolderId, toFolderId)
    if videoIds == nil or string.len(videoIds) == 0 then
        error("videoIds 不能为空")
    end
    if fromFolderId == nil or string.len(fromFolderId) == 0 then
        error("fromFolderId 不能为空")
    end
    if toFolderId == nil or string.len(toFolderId) == 0 then
        error("toFolderId 不能为空")
    end
    local t_ids = Split(videoIds, ",")
    local t_sqls = {}
    for i = 1, #t_ids do
        local pid = t_ids[i]
        if pid and string.len(pid) > 0 then
            local dsql = "UPDATE T_SOCIAL_VIDEO SET FOLDER_ID = " .. quote(toFolderId) .. " WHERE ID = " .. quote(pid) .. ";"
            table.insert(t_sqls, dsql)
        end
    end

    local dresult = DBUtil:batchExecuteSqlInTx(t_sqls, 1000)
    local db = DBUtil:getDb()
    --照片数
    if dresult then
        --从照片数-n
        local usql = "UPDATE T_SOCIAL_VIDEO_FOLDER SET VIDEO_NUM = VIDEO_NUM - " .. #t_sqls .. " WHERE ID = " .. quote(fromFolderId)
        local uresutl, err = db:query(usql)
        if not uresutl then
            return false;
        end
        --照片数+n
        local usql1 = "UPDATE T_SOCIAL_VIDEO_FOLDER SET VIDEO_NUM = VIDEO_NUM + " .. #t_sqls .. " WHERE ID = " .. quote(toFolderId)
        local uresutl1, err = db:query(usql1)
        if not uresutl1 then
            return false;
        end
    end
    return true;
end

return VideoService;