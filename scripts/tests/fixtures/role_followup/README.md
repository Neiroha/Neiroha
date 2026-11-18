# 2026-11-18 分角验证样本

这组样本检验显式合唱、匿名插话、同名人物、跨章改称、说话者与听者，以及 Reviewer 的改对与改坏。`chapters` 为依次送入同一作品的原文片段，拼接结果等于 `text`。`gold` 与 `identityChecks` 仅用于离线评分。`same` 和 `distinct` 比较发言对应的数据库角色 ID。`unassigned` 要求类别仍为对白，并保留空白角色。

两组英语样本的原文取自 Standard Ebooks 的公版作品，保留选段的正文与标点。爱丽丝取第七、八章选段，福尔摩斯将《波希米亚丑闻》的选段在身份揭晓前切作两个分析章节。授权与具体来源见原仓库，下载的 XHTML 哈希记在样本中。

- [Lewis Carroll, Alice’s Adventures in Wonderland](https://github.com/standardebooks/lewis-carroll_alices-adventures-in-wonderland/tree/8da5cac1a4ec2c811322eff79daa5e11e851a813/src/epub/text)
- [Arthur Conan Doyle, A Scandal in Bohemia](https://github.com/standardebooks/arthur-conan-doyle_the-adventures-of-sherlock-holmes/blob/6c94b03802c2fb2059b7f1521665a601d640f77e/src/epub/text/a-scandal-in-bohemia.xhtml)

复现实验时，将本目录的五个 JSON 与 `role_assign/12_xianxia.json`、`role_assign/06_village.json`、`role_quality/quality_reveal.json` 复制到单独的输入目录。对同一输入目录调用 `run_role_quality.dart --fixtures <输入目录>`。基线使用应用内置 1.3.0，候选使用 `role_skill_history/SKILL.1.4-experiment.md`。两组传入同一个 `NEIROHA_EVAL_BUDGET_FILE`，每组三轮。
