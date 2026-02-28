# Encroach
![image](Assets/encroach_cover.png)

"Encroach is a systemic simulation of human expansion, driven not by commands, but by conditions."

## 项目简介

**Encroach** 是一个基于 Godot 4 (GDScript) 的 2D 系统生态模拟游戏。
其核心游戏哲学在于**放弃直接控制**：玩家无法直接命令游戏内的 Agent（人类实体）去执行任何动作（例如移动、采集、休息）。玩家唯一的干预手段是在世界中放置预设的“建筑蓝图”。这些建筑会产生一种影响周围区域的环境辐射场，进而改变处于该辐射场内的 Agent 的行为逻辑权重（例如更倾向于采集、更倾向于休息）。

游戏通过一套纯粹的底层规则来运转：TimeSystem 驱动 tick 循环，AgentManager 掌管实体的生老病死，BuildingManager 处理建筑的影响，而真正的灵魂是 `RuleEvaluator`，它实时评估条件并决定行为倾向。

## 核心机制

- **没有指令，只有条件**：颠覆传统 RTS 的框选微操，采用自下而上的 Agent 智能驱动机制。
- **环境影响行为**：通过放置具有属性值的“建筑物”，间接引导族群向特定目标发展。
- **残酷的自然规则**：Agent 的饥饿、衰老是不可逆的。资源采集、消耗形成紧凑的闭环。如果环境过于恶劣或资源枯竭导致全员饿死，系统将走向正常的结局（游戏结束），这并非 Bug，而是模拟的自然法则。
- **Data-Driven 数据驱动**：各类规则、条件及实体权重完全依赖外部配置数据（JSON/Dictionary）计算，高度解耦。

## 技术栈与架构

- **引擎**: Godot 4.x
- **系统层级**:
  - `World` (根节点，只负责推送 Tick 时间)
  - `TimeSystem` (时间滴答驱动与天数变换)
  - `AgentManager` (管理 HumanAgent 实体阵列)
  - `BuildingManager` (处理蓝图放置与建成实例影响)
  - `RuleEvaluator` (规则引擎，负责条件判断与权重注入)

## 目前进展

该项目目前处于 MVP（最小可行性产品）阶段。核心的时间循环、实体代谢（自动觅食/饿死离生）、资源枯竭逻辑、基于随机点的世界生成已验证完成。极简主义的几何视觉效果（白圈为人、绿方块为资源）使得核心机制更直观可见。

> 详情请查阅项目内的 [TODO.md](TODO.md) 与 [ARCHITECTURE.md](ARCHITECTURE.md) 以了解完整的开发计划和架构准则。

## AI 协同开发指南
本项目采用 AI First 理念开发，致力于“代码即 Context”。详细编码规范和交互工作流，请务必查看 [DEVELOPMENT_GUIDELINES.md](DEVELOPMENT_GUIDELINES.md)。
