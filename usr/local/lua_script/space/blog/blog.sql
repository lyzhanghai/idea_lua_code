-- --------------------------------------------------------
-- 主机:                           10.10.6.199
-- 服务器版本:                        5.5.39-MariaDB - Source distribution
-- 服务器操作系统:                      Linux
-- HeidiSQL 版本:                  9.1.0.4867
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

-- 导出  表 dsideal_db.t_social_blog 结构
DROP TABLE IF EXISTS `t_social_blog`;
CREATE TABLE IF NOT EXISTS `t_social_blog` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `org_person_id` int(11) DEFAULT NULL,
  `identity_id` int(11) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `logo` varchar(100) DEFAULT NULL,
  `signature` varchar(100) DEFAULT NULL,
  `blog_address` varchar(100) DEFAULT NULL,
  `theme_id` varchar(20) DEFAULT NULL,
  `is_del` int(2) DEFAULT '0',
  `create_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `access_num` int(5) DEFAULT '0',
  `comment_num` int(5) DEFAULT '0',
  `article_num` int(5) DEFAULT '0',
  `check_status` int(2) DEFAULT NULL,
  `province_id` int(6) DEFAULT NULL,
  `city_id` int(6) DEFAULT NULL,
  `district_id` int(6) DEFAULT NULL,
  `school_id` int(6) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='博客信息表';

-- 数据导出被取消选择。


-- 导出  表 dsideal_db.t_social_blog_article 结构
DROP TABLE IF EXISTS `t_social_blog_article`;
CREATE TABLE IF NOT EXISTS `t_social_blog_article` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `blog_id` int(11) DEFAULT NULL,
  `person_id` int(11) DEFAULT NULL,
  `person_name` varchar(50) DEFAULT NULL COMMENT '作者姓名',
  `identity_id` int(10) DEFAULT NULL COMMENT '身份id',
  `title` varchar(100) DEFAULT NULL COMMENT '标题',
  `overview` varchar(500) DEFAULT NULL COMMENT '文章摘要',
  `content` varchar(500) DEFAULT NULL COMMENT '文章内容',
  `thumb_id` varchar(50) DEFAULT NULL COMMENT '指定的缩略图file_id+扩展名',
  `person_category_id` int(10) DEFAULT NULL COMMENT '个人分类id',
  `thumb_ids` varchar(200) DEFAULT NULL COMMENT '前4张图的file_id+扩展名，用于摘要模式显示',
  `org_category_id` int(10) DEFAULT NULL COMMENT '机构门户分类',
  `ts` bigint(20) DEFAULT NULL,
  `update_ts` bigint(20) DEFAULT NULL,
  `browse_num` int(10) DEFAULT '0' COMMENT '浏览次数',
  `comment_num` int(10) DEFAULT '0' COMMENT '评论次数',
  `support_num` int(10) DEFAULT '0' COMMENT '支持次数',
  `create_time` timestamp NULL DEFAULT NULL COMMENT '创建时间',
  `top` int(2) DEFAULT NULL COMMENT '置顶',
  `is_del` int(2) DEFAULT '0',
  `stage_id` varchar(50) DEFAULT NULL COMMENT '学段id',
  `stage_name` varchar(50) DEFAULT NULL COMMENT '学段名称',
  `subject_id` varchar(50) DEFAULT NULL COMMENT '学科id',
  `subject_name` varchar(50) DEFAULT NULL COMMENT '学科名称',
  `province_id` varchar(20) DEFAULT NULL COMMENT '省id',
  `city_id` varchar(20) DEFAULT NULL COMMENT '市id',
  `business_type` varchar(20) DEFAULT NULL COMMENT '业务类型，',
  `district_id` varchar(20) DEFAULT NULL COMMENT '区id',
  `school_id` varchar(20) DEFAULT NULL COMMENT '校id',
  `show` int(2) DEFAULT NULL COMMENT '表示文章在国、省、市、区、校或任意组合上是否显示',
  `best` int(2) DEFAULT NULL COMMENT '省、市、区、校或任意组合上是否精华',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='博客中文章';

-- 数据导出被取消选择。


-- 导出  表 dsideal_db.t_social_blog_article_sphinxse 结构
DROP TABLE IF EXISTS `t_social_blog_article_sphinxse`;
CREATE TABLE IF NOT EXISTS `t_social_blog_article_sphinxse` (
  `id` int(11) unsigned NOT NULL,
  `weight` int(11) DEFAULT '1',
  `query` varchar(20480) NOT NULL,
  KEY `query` (`query`(1024))
) ENGINE=SPHINX DEFAULT CHARSET=utf8 CONNECTION='sphinx://127.0.0.1:3341';

-- 数据导出被取消选择。


-- 导出  表 dsideal_db.t_social_blog_category 结构
DROP TABLE IF EXISTS `t_social_blog_category`;
CREATE TABLE IF NOT EXISTS `t_social_blog_category` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `level` int(2) DEFAULT NULL COMMENT '分类级别，是机构分类，还是个人分类',
  `person_name` varchar(50) DEFAULT NULL COMMENT '姓名',
  `org_person_id` int(10) DEFAULT NULL COMMENT '机构或人id',
  `identity_id` int(10) DEFAULT NULL COMMENT '身份id',
  `name` varchar(50) DEFAULT NULL COMMENT '分类名称',
  `is_del` int(2) DEFAULT '0' COMMENT '是否删除',
  `article_num` int(5) DEFAULT '0' COMMENT '分类下文章个数',
  `business_type` int(11) DEFAULT '0' COMMENT '博客分类、名师工作室分类',
  `business_id` int(11) DEFAULT '0' COMMENT '业务id',
  `sequence` int(4) DEFAULT NULL COMMENT '排序字段',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='博客分类表';

-- 数据导出被取消选择。


-- 导出  表 dsideal_db.t_social_blog_recommend 结构
DROP TABLE IF EXISTS `t_social_blog_recommend`;
CREATE TABLE IF NOT EXISTS `t_social_blog_recommend` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `article_id` int(10) DEFAULT NULL COMMENT '文章id',
  `explain` varchar(100) DEFAULT NULL COMMENT '推荐说明',
  `check_status` int(2) DEFAULT NULL COMMENT '审核状态',
  `from_id` int(10) DEFAULT NULL COMMENT '推机构id',
  `from_level` int(2) DEFAULT NULL COMMENT '推机构级别',
  `to_id` int(10) DEFAULT NULL COMMENT '被推机构id',
  `to_level` int(2) DEFAULT NULL COMMENT '被推荐机构的级别',
  `create_time` date DEFAULT NULL COMMENT '推荐时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='博文推荐';

-- 数据导出被取消选择。
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
