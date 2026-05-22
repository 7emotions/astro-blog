---
title: 给 AI Agent 装上「嘴巴」和「耳朵」—— 让 OpenCode 真实打电话
published: 2026-05-18
description: "Phone Agent MCP 开发：通过 ADB + 蓝牙 HSP 让 AI Agent 真正拨打电话、自主对话，edge-tts + whisper + DeepSeek 实现端到端语音交互"
image: ''
tags: [OpenCode, AI Agent, MCP, 语音, TTS, Whisper, 工具开发]
category: "开发"
draft: false
lang: ""
---

# 背景

在使用 OpenCode 这样的 AI Agent 平台时，Agent 可以写代码、读文件、搜文档、部署服务，但有一个根本的能力空白：**它不能打电话**。

想象这些场景：

- Agent 帮你完成了代码部署，需要通知王经理 —— 你只能自己拿起手机
- Agent 从数据库里找到了一批欠费用户，需要逐一确认 —— 你手动拨号
- Agent 检测到服务器宕机，想通知运维 —— 它只能发文字消息

Agent 不缺信息，缺的是**触达真人的通道**。电话仍然是最高优先级的通知方式 —— 微信可能静音，邮件可能淹没，但电话铃响，对方一定会接。

于是我写了

::github{repo="7emotions/phone-agent"}

# 功能

Phone Agent 是一个 MCP Server，跑在连接了 Android 手机的 Linux 机器上，向 OpenCode Agent 暴露 7 个工具：

| MCP Tool | 功能 | 典型场景 |
|---|---|---|
| `phone_dial` | 拨号 + 预生成开场白 TTS | 任何电话的第一步 |
| `phone_converse` | 多轮自主对话（LLM 驱动） | 确认出席、通知延期、收集信息 |
| `phone_ask` | 单轮：问 → 录 → 识别 → 提取 | 简单的是/否问题 |
| `phone_speak` | 单向 TTS 播放 | 纯通知，不需要回复 |
| `phone_check` | 查询通话状态 | 拨号前确认、挂断后确认 |
| `phone_hangup` | 挂断 | 结束时调用 |
| `phone_filler` | 播放预生成的垫话 | 桥接 TTS 生成延迟 |

Agent 只需要组合这些工具就可以完成完整的通话任务：

```
phone_dial(number, opening="您好，我是XX公司的AI助手...")
  → 拨号 + TTS 后台生成，接通瞬间播放

phone_converse(goal="确认明天评审会出席", skip_opening=true)
  → LLM 自主对话：录 → 识别 → 决策 → TTS → 回复 → 循环

phone_hangup()
  → 挂断，Agent 总结对话结果
```

# 架构设计

## 整体架构

```
┌──────────────────────────────────────────────────────┐
│                  OpenCode Agent                       │
│  phone_dial / hangup / check / speak / ask / converse │
└─────────────────────┬────────────────────────────────┘
                      │ MCP stdio (JSON-RPC)
┌─────────────────────▼────────────────────────────────┐
│              phone_call_mcp.py (688行)                │
│  ├─ 拨号调度    → ADB am start CALL                  │
│  ├─ 对话引擎    → DeepSeek API 方向盘                 │
│  ├─ 语音合成    → edge-tts (云端) / espeak-ng (本地)   │
│  ├─ 语音识别    → faster-whisper tiny                │
│  ├─ 录音控制    → WebRTC VAD + parecord               │
│  ├─ 回声管理    → 5次重试清除 loopback                │
│  └─ 蓝牙管理    → HSP 自动重连                        │
└──────┬──────────────────────────┬────────────────────┘
       │                          │
   ┌───▼────┐              ┌──────▼──────┐
   │  ADB   │              │  蓝牙 HSP    │
   │ (拨号) │              │ paplay 上行  │
   └────────┘              │ parecord 下行│
                           └─────────────┘
```

## 为什么是 MCP？

OpenCode 本身没有「打电话」的能力，但它有 MCP 扩展机制。我把整个电话能力包装成一个 MCP Server：

- **Agent 不需要知道蓝牙、ADB、PulseAudio 的存在** —— 它只需要调用工具
- **对话决策在远端 LLM 完成** —— Agent 只负责编排，不参与每轮决定
- **Skill 提供使用指南** —— `phone-call` Skill 告诉 Agent 什么时候用哪个工具、怎么组合

## 双引擎设计：API + 本地各司其职

```
对话决策 (方向盘)  → DeepSeek API  → 约 1 秒延迟，语义理解强
简单提取 (辅助)    → 本地 1.5B LM → 更快的结构化提取
TTS               → edge-tts      → 2-5 秒，后台并行生成
ASR               → whisper tiny  → 1-3 秒，速度优先
```

**为什么不用纯本地？** 1.5B 的本地模型做多轮对话决策不稳定，容易陷入重复提问。DeepSeek API 做方向盘，本地模型做简单提取，各做自己擅长的。

**为什么用 whisper tiny 而不是 small？** 实测 tiny 转写日常中文对话准确率 90% 以上，但比 small 快 3-5 倍。电话场景需要「够用就好」的转写速度，而不是精准字幕。

# 关键技术

## 四层停止机制

多轮对话最大的坑是「不知道什么时候停」。Phone Agent 实现了四层防御：

| 层 | 机制 | 触发条件 |
|---|------|----------|
| 1. 模型 `done` | LLM 判断对话完成 | 信息收集完毕 / 对方拒绝 / 对话结束 |
| 2. 关键词 | 检测推脱/拒绝语 | "帮你记"、"打错"、"稍后联系"、"尽快" 等 25 个以上关键词 |
| 3. 去重 | 连续两轮相同回复 | "喂？" → "喂？"（对方不配合） |
| 4. max_turns | 硬上限 | 安全网，防止死循环 |

经过 184 条多场景模拟对话测试，停止准确率达到 **98%**。模型 `done` 是第一道线，关键词是安全网 —— 模型有时会被"我帮你记一下"这类委婉拒绝骗过去，关键词层补上这个缺口。

## 两段式开场：零延迟通话

一个容易被忽略但体验差距巨大的细节：**TTS 生成需要 2-5 秒**。如果接通后才开始生成 TTS，对方会听到 2-5 秒的沉默，以为是骚扰电话直接挂掉。

解决方案：

```
phone_dial(number, opening="您好，我是...")
    │
    ├── 拨号中 (ringing) ───→ 后台生成 opening TTS
    │
    └── 对方接听 ───→ 检测 state=ACTIVE ───→ 立即播放 TTS
```

开场白在拨号振铃期间后台生成，对方接通的瞬间就听到声音 —— 就像真人打电话一样自然。后续对话通过 `phone_converse(skip_opening=true)` 无缝衔接。

## TTS 间隙填补

录音结束后，LLM 决策 + TTS 生成需要 3-8 秒。如果对方在这期间听不到任何声音，会以为断线。

解决：录音结束 2 秒后，如果 TTS 还没生成完，自动播放预录的垫话「请稍等，让我思考一下」。如果 TTS 在垫话期间完成，等垫话播完再切入 TTS —— 不抢话、不重叠、不断线。

第一轮永远不播垫话（对方刚接电话，垫话显得突兀）。

## 「不知道就说不知道」

LLM 最大的问题之一是**幻觉**——被问到不知道的信息时会编造答案。在电话场景里这尤其危险。

Phone Agent 在 System Prompt 里明确要求：

> 遇到你不知道的信息，诚实说"这个我不确定，我确认后再回复您"，返回 done，reason 写 "callback: 需要确认XXX后再回电"。

Agent 拿到 `done_reason: "callback:..."` 后会告知用户需要查证，然后带着确认后的信息重拨。

# 如何使用

## 1. 硬件准备

- **一台 Linux 电脑**（蓝牙 + USB）
- **一台 Android 手机**（已 root，已测试 Xiaomi 22041216C / Android 14 / MTK Dimensity 8100）
- **USB 数据线**连接电脑和手机

## 2. 蓝牙配对 (HSP)

```bash
bluetoothctl pair F8:AB:82:92:08:76
bluetoothctl trust F8:AB:82:92:08:76
pactl list cards short | grep bluez  # 确认识别
```

HSP（Headset Profile）是关键——它能提供双向 8kHz 语音通路。A2DP 只能单向放音乐，不能录音。

## 3. 安装依赖

```bash
pip install mcp edge-tts webrtcvad
apt install pulseaudio pulseaudio-module-bluetooth ffmpeg
pip install faster-whisper  # ASR
```

## 4. 生成垫话音频

```bash
python3 gen_fillers.py
```

## 5. 配置 MCP Server

```bash
git clone https://github.com/7emotions/phone-agent.git
```

在 `opencode.jsonc` 中添加：

```jsonc
"phone-call": {
  "type": "local",
  "command": ["python3", "/path/to/phone_call_mcp.py"],
  "enabled": true,
  "timeout": 300000,
  "environment": {
    "PHONE_CONVERSE_BACKEND": "api",
    "PHONE_TTS_BACKEND": "edge",
    "PHONE_LLM_URL": "https://api.deepseek.com/chat/completions",
    "PHONE_LLM_KEY": "sk-xxx",
    "PHONE_LLM_MODEL": "deepseek-chat",
    "PHONE_LLM_CONTEXT": "你是XX公司的AI助手。",
    "PHONE_BT_MAC": "F8:AB:82:92:08:76",
    "PHONE_BT_CARD": "bluez_card.F8_AB_82_92_08_76",
    "PHONE_BT_SINK": "bluez_sink.F8_AB_82_92_08_76.headset_audio_gateway",
    "PHONE_BT_SOURCE": "bluez_source.F8_AB_82_92_08_76.headset_audio_gateway",
    "PHONE_ADB": "/path/to/adb"
  }
}
```

## 6. 安装 Agent Skill

将仓库里的 `skill-phone-call.md` 复制到 `~/.agents/skills/phone-call/SKILL.md`，重启 OpenCode。

## 7. 使用

配置完成后，Agent 就获得了打电话能力。对它说：

> "帮我打电话给 138xxxx，确认他明天下午能否参加评审会"

Agent 会自动：
1. 调用 `phone_dial` 拨号，附带预生成的「你好，我是 XX 公司 AI 助手...」开场白
2. 调用 `phone_converse` 进行多轮对话
3. 在对话完成后挂断
4. 从返回的 `transcripts` 中提取信息，用自然语言回复你

# 对话演示

一段真实通话记录（对方为某公司客服）：

```
Agent: 您好，我是南京青赋驭境的AI助手，想跟您确认一下
       明天下午的评审会您这边能参加吗？

Caller: 现上评审会是吧？请问具体是哪个部门或者项目的会议呢？

Agent: 是明天下午的线上评审会，具体是南京青赋驭境的项目评审会。

Caller: 嗯，收到了，我会尽快帮您确认一下是否能参加的。

→ 触发停止（关键词："尽快"）— 对方表达了帮忙意愿但未承诺
```

另一段成功回电流程：

```
Agent: 您好，刚才关于XXX的问题，我已经确认了，请问您现在方便吗？

Caller: 方便的，你说。

Agent: 根据我们的记录，您在系统中的状态是XXX，所以需要您...

Caller: 好的，明白了，我马上去处理。

→ 触发停止（模型 done）— 信息传达清楚，对方已承诺
```

# 局限与后续计划

**当前局限：**

- **需要 root 手机**：ADB 拨号不要求 root，但蓝牙 HSP profile 管理在非 root 设备上有限制
- **仅限中文**：whisper 支持多语言，但 System Prompt 和 filler 目前只写中文
- **Linux 单机部署**：MCP 要求 stdio 通道，不能远程调用
- **单路通话**：HSP 只能处理一路双向音频，不能同时打两个电话
- **需要 USB 连接**：ADB over WiFi 也可以，但有线更稳定

**计划中的改进：**

- [ ] 支持 ADB over WiFi，摆脱 USB 线
- [ ] 多语言支持（英文 System Prompt + 英文 filler）
- [ ] 回电调度：从 `done_reason` 提取待确认事项，自动创建回电任务
- [ ] GPU 加速 whisper（CUDA / Apple Silicon）
- [ ] 通话录音存档，供 Agent 回顾历史对话

# 结语

[phone-agent](https://github.com/7emotions/phone-agent) 给 AI Agent 装上了一个真正的「嘴巴」和「耳朵」——不是模拟的，是真实能打通电话的。

它的核心价值不在于技术多么复杂（688 行 Python），而在于**打通了 Agent 到真人之间的最后一公里**。Agent 能写代码、能搜文档、能部署服务，但在此之前，它需要一个人类来替它打电话。现在不需要了。

如果你也在用 OpenCode 或其他支持 MCP 的 AI Agent 平台，欢迎尝试。项目开源在 GitHub，MIT 协议。

> 项目地址：[github.com/7emotions/phone-agent](https://github.com/7emotions/phone-agent)
>
> 背景文章：[Terminator-AI — 「普通人用 OpenClaw 实战：自动打电话」](https://www.bilibili.com/video/BV1kvPnz9EcA)
