# Encroach - 架构指南

## 游戏核心哲学 (Game Pillars)

**一句话定义：** "Encroach is a systemic simulation of human expansion, driven not by commands, but by conditions."（一个由条件而非指令驱动的人类扩张系统模拟）

### 硬性约束

1. **玩家绝对不能直接控制 Agent（人）** - 没有移动指令，没有工作分配
2. **玩家唯一的输入是「放置/升级建筑蓝图」**
3. **建筑不是功能按钮，而是「改变周围 Agent 行为权重的环境影响场」**
4. **系统崩溃（人口饿死归零）是正常的结局，不是 Bug**

---

## Godot 技术架构 (Godot 4, 2D, GDScript)

完全解耦的数据驱动架构：

| 系统 | 职责 |
|------|------|
| `World` (Node2D) | 唯一根节点，不发号施令，只负责推进 Tick |
| `TimeSystem` | 负责处理 Tick 循环和天数（Day）更迭 |
| `AgentManager` | 管理所有 HumanAgent 的实例化与销毁 |
| `BuildingManager` | 管理建筑的两种状态（BuildingPlan 蓝图预设 → BuildingInstance 建成实体） |
| `RuleEvaluator` | 核心规则引擎。评估建筑建造条件、建筑对周围 Agent 的影响权重 |

---

## 实体设计逻辑 (Entity Logic)

### HumanAgent (人)
- 采用状态机/行为树
- 每 Tick 根据自身属性（饥饿、口渴、体力、负重）和周围环境（建筑影响场），自主决定当前意图
- 意图包括：游走、开采、回城、休息

### Resource (资源)
- 世界中的具体节点（如食物、水、矿脉）
- 具有储量和采集难度属性

### Building (建筑)
- **必须数据化**
- 新建筑的添加应该是新增 JSON 或 Dictionary 数据，而不是写新的 if/else 逻辑

---

## Vibe Coding 准则

1. **Data-Driven 首选** - 规则和条件判断尽量抽象为配置数据（如 `{ "type": "population_min", "value": 5 }`）
2. **避免面条代码** - 各个 System 之间通过 Signal（信号）通信，不要互相强耦合
3. **MVP 优先** - 现阶段不考虑美术、动画和复杂 UI。一切以纯逻辑、控制台 Log 输出和极简 2D 几何图形（方块、圆圈）为主

---

## 系统运作方式

```
┌─────────────────────────────────────────────────────────────────┐
│                         World (Root)                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ TimeSystem   │──│RuleEvaluator │──│ AgentManager │          │
│  │   (Tick)     │  │  (Weights)   │  │  (Agents)    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│         │                  │                  │                 │
│         ▼                  ▼                  ▼                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    BuildingManager                       │   │
│  │    BuildingPlan → [条件评估] → BuildingInstance         │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

运作流程:
1. TimeSystem 推进 Tick → 发出 tick 信号
2. Agent 接收 Tick → 读取自身状态 + 周围建筑影响权重 → 决定行为
3. BuildingManager 监听蓝图放置 → RuleEvaluator 评估条件 → 实例化建筑
4. 建筑作为环境场 → 改变附近 Agent 的行为权重
5. 循环直到系统崩溃（人口归零）
```
