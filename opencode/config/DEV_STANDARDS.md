# 逆天西瓜开发规范

## 项目工具优先（如果项目中有对应的工具类时优先使用，比如时间的）
- 时间：`DatetimeHelper::now()`，不写 `date('Y-m-d H:i:s')`
- 配置：`ConfigHelper::getValue()` 或 `EnvHelper`，不编造 key
- 域名：grep 项目已有写法，不凭感觉写 key
- 写代码前先 grep 确认调用方式

## 同命名空间不 import
- 同一个 namespace 下的类直接用，不写多余的 `use`

## SQL 可读性
- BETWEEN 值在左：`'$now' between ma.start_time AND ma.end_time`
- 关联表条件尽量并入 `where()` 数组，减少 `andWhere` 行数

## 返回类型声明
- `: void` 删掉，无意义
- `: array` 等有文档价值的保留

## 参数传递
- Service 给 AR 传 form 对象，不拆散成多个单独参数
- 计算类字段（dates、activityId 等）注入 form，Service 是唯一数据源

## 异常处理
- 异步任务：try 内不满足就抛，catch 统一返回 Result
- HTTP 请求：只局部捕获可能失败的地方（如读配置），不整个方法包

## 架构分层
- Controller 薄：路由 + 参数注入
- Service 厚：业务逻辑唯一归宿
- AR：DB 封装，所有查询方法在此
- Model：纯表映射，只含 `tableName()`

## 编码习惯
- 中文常量、变量、注释
- Allman 大括号（类和方法另起一行）
- 写完必自测：语法检查 → 跑实际方法 → 核对输出
- 提交前检查：未使用变量、逻辑一致性、可复用代码
- 编码后审视：需求合理性、性能优化空间
