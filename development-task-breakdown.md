# TongJing 详细开发任务清单（前端 / 后端 / 数据表 / API）

## 0. 使用说明
- 本清单按 `MVP -> 增长 -> AI增强` 三阶段拆分。
- 每个任务含：优先级、负责人建议、完成定义（DoD）。
- 优先级定义：`P0` 必须，`P1` 重要，`P2` 增强。

## 0.1 当前迭代快照（2026-03-28）

| 项 | 状态 |
|----|------|
| Spring：S3 未配置时本地上传 + `GET /api/v1/local-media/**` 直链 | 已完成 |
| Spring：Flyway 迁移 `shoot_plans` 表 | 已完成 |
| Spring：`/api/v1/shoot-plans` 列表 / 幂等 PUT / PATCH done / DELETE | 已完成 |
| Flutter：拍摄计划改走接口（原 SharedPreferences 已移除） | 已完成 |
| 挑战页后端与真实挑战流 | 未做（仍为占位 UI） |
| AI 标签/文案真实服务 | 未做（发布页仍为端上辅助） |

**运维提示**：若托管库禁止 Flyway 写 `flyway_schema_history`，可设 `spring.flyway.enabled=false` 并手动执行 `db/migration/V20260328120000__shoot_plans.sql`。真机访问本机图片 URL 时设置 `TONGJING_PUBLIC_BASE_URL`（如 `http://192.168.x.x:9091`）。

---

## 1. 前端任务清单（Flutter）

## 1.1 P0 - MVP 核心闭环

### FE-001 底部五 Tab 主框架
- 内容：`首页 / 地图 / 发布 / 计划挑战 / 我的` 框架与路由稳定化。
- DoD：
  - 五 Tab 可稳定切换，状态保持正确。
  - 深链路由可进入指定页面。

### FE-002 发布流程 Step 化重构
- 内容：上传 -> EXIF 展示 -> 机位微调 -> 标签/Tips -> 发布。
- DoD：
  - 图片选择后 1 次流转完成发布。
  - EXIF 可查看、可编辑、可回填默认值。

### FE-003 首页 Feed 三分流
- 内容：关注、推荐、最新三路内容流 UI 与分页。
- DoD：
  - 三分流独立分页，不串数据。
  - 下拉刷新与上拉加载稳定。

### FE-004 参数筛选器
- 内容：设备、参数区间、场景标签筛选面板。
- DoD：
  - 支持多条件组合筛选。
  - 筛选条件可回显、可重置。

### FE-005 地图页与机位点展示
- 内容：地图锚点展示 + BottomSheet 列表联动。
- DoD：
  - 点击地图点可查看机位下作品。
  - 地图拖动后列表数据随视野更新。

### FE-006 互动能力
- 内容：点赞、评论、收藏、一键转计划。
- DoD：
  - 所有互动状态实时回显。
  - 收藏后可在“我的计划”看到新增计划。

### FE-007 个人中心基础版
- 内容：资料卡、作品列表、收藏列表。
- DoD：
  - 作品、收藏列表可分页加载。
  - 个人统计数据正确展示。

## 1.2 P1 - 增长阶段

### FE-008 同款挑战页
- 内容：挑战列表、挑战详情、参与上传入口。
- DoD：挑战页可发起参与并显示作品聚合。

### FE-009 装备库管理页
- 内容：机身/镜头录入、编辑、删除、排序。
- DoD：装备库 CRUD 全流程可用。

### FE-010 足迹地图
- 内容：个人拍摄足迹点亮与城市统计。
- DoD：发布带地理信息作品后自动点亮。

## 1.3 P2 - AI 增强

### FE-011 AI 标签与文案接入
- 内容：发布页异步拉取 AI 标签、文案建议并一键采纳。
- DoD：AI 结果可编辑、可拒绝、可重试。

### FE-012 AI 构图辅助工具入口
- 内容：裁剪建议、路人消除入口与结果对比视图。
- DoD：工具调用成功后可预览前后对比。

---

## 2. 后端任务清单（Spring Boot）

## 2.1 P0 - MVP 核心闭环

### BE-001 鉴权与用户会话稳定化
- 内容：登录、会话续期、鉴权中间件统一。
- DoD：核心业务接口全部鉴权生效。

### BE-002 上传与媒体处理链路
- 内容：图片上传、对象存储、缩略图生成、元数据记录。
- DoD：
  - 上传成功后返回可访问资源 URL。
  - 失败可重试且不产生脏记录。

### BE-003 EXIF 解析服务
- 内容：解析图片 EXIF 并标准化写库。
- DoD：
  - 常见机型字段映射正确。
  - 缺失字段返回空值而非报错。

### BE-004 作品发布服务
- 内容：保存作品主体、EXIF、标签、Tips、机位信息。
- DoD：发布事务一致，任何子步骤失败可回滚。

### BE-005 Feed 聚合服务
- 内容：关注/推荐/最新三路查询。
- DoD：分页稳定，排序规则可配置。

### BE-006 参数筛选检索服务
- 内容：设备、参数、标签交叉过滤。
- DoD：支持组合条件查询与性能可接受响应。

### BE-007 地图检索服务
- 内容：按视野范围返回机位点及作品摘要。
- DoD：地图缩放、移动后查询结果准确。

### BE-008 互动服务
- 内容：点赞、评论、收藏、一键转计划。
- DoD：互动计数最终一致，重复操作幂等。

## 2.2 P1 - 增长阶段

### BE-009 挑战系统
- 内容：挑战创建、参与、聚合作品流。
- DoD：挑战详情可准确展示参与作品。

### BE-010 装备库服务
- 内容：用户设备资产 CRUD 与设备推荐关系。
- DoD：装备变更后推荐接口可返回差异结果。

### BE-011 足迹统计服务
- 内容：按城市/机位聚合作品足迹。
- DoD：统计接口支持时间筛选与分页。

## 2.3 P2 - AI 增强

### BE-012 AI 编排服务
- 内容：统一封装标签、文案、调色建议、机位预测。
- DoD：上游模型可替换，失败有降级策略。

### BE-013 AI 预测提醒任务
- 内容：天气 + 机位收藏生成提醒任务并推送。
- DoD：提醒任务按计划触发且可取消。

---

## 3. 数据表与数据层任务清单

## 3.1 P0 - MVP 必要表

### DB-001 用户与关系
- 表建议：`users`、`user_sessions`、`user_follows`
- DoD：支持用户资料、会话、关注关系查询。

### DB-002 作品主表与扩展
- 表建议：`photos`、`photo_exif`、`photo_tags`、`photo_tips`
- DoD：作品主体与 EXIF 分离存储，便于检索。

### DB-003 地理与机位
- 表建议：`spots`、`photo_spots`
- DoD：支持经纬度索引与范围查询。

### DB-004 社区互动
- 表建议：`photo_likes`、`photo_comments`、`photo_favorites`
- DoD：点赞/收藏去重约束，评论可分页。

### DB-005 计划系统
- 表建议：`shoot_plans`、`plan_items`
- DoD：收藏转计划可追踪来源作品。

## 3.2 P1 - 增长必要表

### DB-006 挑战系统
- 表建议：`challenges`、`challenge_entries`
- DoD：支持挑战与参与作品关联查询。

### DB-007 装备库
- 表建议：`user_equipments`
- DoD：用户装备资产可维护并可过滤查询。

## 3.3 P2 - AI 相关表

### DB-008 AI 结果缓存
- 表建议：`ai_photo_annotations`、`ai_copy_suggestions`
- DoD：AI 结果可回溯、可重算、可版本化。

### DB-009 AI 预测提醒
- 表建议：`ai_spot_predictions`、`notification_tasks`
- DoD：提醒任务状态可观测（待发送/成功/失败）。

---

## 4. API 任务清单（建议接口分组）

## 4.1 P0 - MVP 接口

### API-AUTH
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET /api/auth/me`

### API-PUBLISH
- `POST /api/uploads/images`
- `POST /api/photos/exif/parse`
- `POST /api/photos`
- `PUT /api/photos/{id}`
- `GET /api/photos/{id}`

### API-FEED
- `GET /api/feed/following`
- `GET /api/feed/recommended`
- `GET /api/feed/latest`

### API-SEARCH
- `GET /api/photos/search`（设备/参数/标签）
- `GET /api/spots/in-bounds`（地图视野）
- `GET /api/spots/{id}/photos`

### API-INTERACTION
- `POST /api/photos/{id}/like`
- `DELETE /api/photos/{id}/like`
- `POST /api/photos/{id}/favorite`
- `DELETE /api/photos/{id}/favorite`
- `POST /api/photos/{id}/comments`
- `GET /api/photos/{id}/comments`

### API-PLAN
- `POST /api/plans/from-favorite/{photoId}`
- `GET /api/plans`
- `PUT /api/plans/{id}`
- `POST /api/plans/{id}/execute`

### API-PROFILE
- `GET /api/users/{id}/profile`
- `GET /api/users/{id}/photos`
- `GET /api/users/{id}/favorites`

## 4.2 P1 - 增长接口

### API-CHALLENGE
- `POST /api/challenges`
- `GET /api/challenges`
- `GET /api/challenges/{id}`
- `POST /api/challenges/{id}/entries`

### API-EQUIPMENT
- `GET /api/equipments`
- `POST /api/equipments`
- `PUT /api/equipments/{id}`
- `DELETE /api/equipments/{id}`

## 4.3 P2 - AI 接口

### API-AI
- `POST /api/ai/photos/{id}/tags`
- `POST /api/ai/photos/{id}/copywriting`
- `POST /api/ai/photos/{id}/grading-suggestions`
- `POST /api/ai/spots/predictions`

---

## 5. 联调与验收任务

## 5.1 P0 联调清单
- FE 与 BE 对齐发布接口字段（EXIF、地理、标签、Tips）。
- 地图范围查询坐标精度与前端缩放层级一致。
- 收藏转计划链路端到端验证。

## 5.2 测试清单（最小）
- 单元测试：EXIF 解析、排序规则、筛选规则。
- 接口测试：发布、Feed、检索、互动、计划。
- 冒烟测试：新用户从浏览到发布完整流程。

## 5.3 上线前检查
- 鉴权、限流、日志、告警配置。
- 关键埋点接入并验证数据回传。
- 数据备份与回滚预案确认。

---

## 6. 推荐执行顺序（两周冲刺版）

### Sprint 1（第 1 周）
- 前端：FE-001~FE-004
- 后端：BE-001~BE-006
- 数据：DB-001~DB-004
- API：MVP 鉴权/发布/Feed/检索

### Sprint 2（第 2 周）
- 前端：FE-005~FE-007
- 后端：BE-007~BE-008
- 数据：DB-005
- API：互动/计划/个人中心
- 验收：发布 -> 浏览 -> 收藏 -> 转计划闭环

---

## 7. 交付物定义
- 产品文档：`product-development-plan.md`
- 任务清单：`development-task-breakdown.md`
- 进度文档：`daily-progress-2026-03-26.md`

以上三份文档构成当前阶段“可执行开发基线”，可直接用于排期、分工与迭代管理。
