# SQLite 数据库迁移

应用使用 Drift 与 SQLite 的 `PRAGMA user_version`。当前 schema 是 **v37**，与应用发行版号独立。

| 入口 | 职责 |
| --- | --- |
| `lib/data/database/tables.dart`、`novel_role_tables.dart` | 当前表结构 |
| `lib/data/database/database_defaults.dart` | 新库的默认角色、语音库、工程和 Provider |
| `lib/data/database/migrations/database_migrations.dart` | 按目标版本执行迁移并管理事务 |
| `lib/data/database/migrations/vNNN.dart` | 只处理进入该版本的结构或数据变更 |
| `lib/data/database/migrations/legacy_schema_repair.dart` | 兼容早期发布包缺表与缺列 |
| `lib/data/database/database_connection.dart` | 选取数据库文件并在升级前备份 |

新库由 Drift 一次创建当前结构。旧库按版本顺序执行迁移，整条升级与版本号在同一事务提交。升级失败保留原结构、数据及版本号。磁盘旧库升级前保留一份 `.before-v<目标版本>.bak`，同名备份继续保留。遇到高于当前版本的库会拒绝打开。

## 历史来源

`scripts/tests/fixtures/database_schemas/history.json` 保存各历史版本的 SQLite 建表定义和 Git 来源。DDL 从相应提交的 Drift 表定义及生成代码建立空库后读取，同一条定义只保存一次。v17 是根据 v20 提交中记录的原始步骤还原的测试结构。

| 版本 | 迁移内容与依据 |
| --- | --- |
| v1–v16 | 从最早的 Provider、模型、声音、任务表演进到语音库、工程、历史、时间线和字幕。早期提交曾在升级时删表并重建。现在按历史结构增量添加，v2 的声音表及 v6 的 Provider 表保留数据后重建，以调整原有约束或默认值。 |
| v17–v20 | `786d7f5` 中的小说表、读者设置和两项数据修正。Git 首个小说提交标为 v20，v17–v19 来自该提交内的升级分支。 |
| v21–v24 | `f72d88a` 中记录的小说预取、缓存提示和播放偏好。 |
| v25–v27 | `be6af9d` 增加 Provider 并发及配额列。`68b8d55` 修复缺失的表与配额列。`0f56082` 增加小说播放间隔。 |
| v29–v32 | `d4811fc` 调整旧默认 Provider 参数。`3794e7f` 补充默认 Provider。`f216cc8` 增加响度及合并设置。`643164b` 新增默认 OpenAI 官方连接。 |
| v33 | `a323573` 增加小说角色、标注、声音绑定和编辑记录。 |
| v34 | `feat/ai-capability-layer` 增加 `voice_asset_settings`、`connection_capabilities`、`provider_models`、`capability_defaults`，并把 `voice.chain.*`、`dialog.live.*` 设置迁入 `voice_asset_settings`。 |
| v35 | `a9bae7c` 为 `connection_capabilities` 增加 `position`、`model_order`（按能力排列连接与模型）。 |
| v36 | `b63f566` 增加 `chat_sessions`、`chat_messages`（角色聊天）。 |
| v37 | 为 `voice_assets` 增加可空的 `seed`（角色固定随机种子，[Issue #13](https://github.com/Neiroha/Neiroha/issues/13)）。 |

v3、v7、v11、v28 没有独立的 schema 提交。v8、v10、v15 提升了版本号，生成的表结构未变化。升级表保留这些空步骤，方便解释旧文件的版本号。早期新库种子数据仍由初始化负责。

## 增加一个版本

1. 修改当前表定义并提升 `schema_version.dart` 中的版本号。
2. 在 `migrations/` 新建目标版本文件，从旧结构添加、转换或搬迁需要的字段，然后注册到 `database_migrations.dart`。历史步骤使用固定的历史结构定义。遇到表重建，保留数据、约束以及依赖的索引和触发器，并验证外键。
3. 运行 `dart run build_runner build` 重新生成 Drift 代码。保存新增版本的可重放建表快照，补有代表性的数据升级测试。
4. 在无凭据的临时数据库上验证直接跨版本升级、新库创建和失败回滚，再跑全量测试。

```powershell
flutter test scripts/tests/database_migration_history_test.dart scripts/tests/database_repair_test.dart scripts/tests/novel_role_migration_test.dart scripts/tests/openai_provider_seed_test.dart
```
