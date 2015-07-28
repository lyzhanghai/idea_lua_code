**动态信息接口说明**
-----------------


**功能**：保存动态信息
**地址**：/dsideal_yy/space/dynamic/save
**方法**：post
**参数**：


		 - person_id  必填
		 - identity_id 非必填
		 - city_id 非必填 市id
		 - province_id 非必填 省id
		 - area_id 非必填 区id
		 - school_id 非必填 学校id
		 - class_id 非必填 班id.
		 - group_id 非必填 组 id.
		 - message 必填 信息.
		 - message_type 必填 用于判断业务。

 **响应**：{"success":true} 或{"success":false}


----------
**功能**：查询动态信息
**地址**：/dsideal_yy/space/dynamic/query
**方法**：get
**参数**：


		 - person_id  必填
		 - identity_id 非必填
		 - pagenum 必填 分页信息
		 - pagesize 必填 分页信息
		 - city_id 非必填 市id
		 - province_id 非必填 省id
		 - area_id 非必填 区id
		 - school_id 非必填 学校id
		 - class_id 非必填 班id.
		 - group_id 非必填 组 id.
		 - message_type 必填 用于判断业务。
		 - type 非必填，用于查询我的同学，我的同事，我的老师，我的好友等,通过此字段调用不同的接口信息。

 **响应**：`
 {"totalRow":"1","pageNumber":1,"pageSize":10,"list":[{"school_id":"2000931","group_id":"1","pi_id":"","province_id":"100007","class_id":"1","city_id":"200051","area_id":"300529","message":"zhanghaizhanghai","identity_id":"5","person_id":"30164","message_type":"1"}],"totalPage":1}
`




