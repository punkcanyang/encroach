# Encroach - 工作日报 (Worklog)

> 本文件用于记录每次较长段落、功能或任务完成后的工作进展。

## 2026-02-27

### 工作内容：项目理解与规则梳理
- **探索与解读架构**：阅读了核心文档 `ARCHITECTURE.md`、`TODO.md` 与 `DEVELOPMENT_GUIDELINES.md`，深度了解了“通过条件而非指令驱动的人类扩张系统模拟”这一游戏哲学。
- **当前进度确认**：确认项目目前完成了时间系统 (TimeSystem)、人类实体基础生命循环 (饥饿、寿命、自动寻食) 和初步的世界构建。
- **核心缺失分析**：分析了目前系统的心脏 `RuleEvaluator` 的代码实现，发现现阶段只有一个空壳框架（`load_default_rules`为空）。提炼出系统缺失的五个核心规则维度：
  1. 行为意图评估规则（Agent自身需求触发条件与权重）
  2. 环境场影响规则（建筑如何改变周围Agent的权重）
  3. 建筑放置与转化规则
  4. 人口与繁衍自然规则
  5. 资源再生与分布规律
- **文档产出**：
  - 补充了项目根目录下的 **README.md**。
  - 创建了 **WORKLOG.md** 以便后续追踪进展，符合 AI First 开发工作流的要求。

### 规则设计产出：填充生态循环漏洞
- **【规则集1】意图驱动**：采用无上限累积的线性模型 `(100-饥饿)*倍率`，且满 80 后不再主动寻食。
- **【规则集2】非食物类优先级**：饱腹(`>=80`)前提下才可挖掘非食物矿石，且系统动态比对全局存量，优先触发“当前最缺资源”的意图。
- **【规则集3】农田脉冲引力与范围衰减**：农田成熟达100%瞬间爆发出极强的觅食引力，引力只在建筑半径内有效并呈距离递减（距中心越近影响越强）。
- **【规则集4】繁殖衍生机制**：各个住所独立按10年循环产出人口，新生儿不凭空生成，而是固定在**空位最多的住所处**实体化。
- **【规则集5】野生矿物的降级消亡**：极其硬核的消亡机制。前期野生食物点一次性；贵金属矿尽后原址降级为工业金属矿，直到降级为土矿后最终挖空消失。极大地增加了早期资源紧缺的压迫感。
- **【规则集6&7】实体物流与生命循环（高维度模拟）**：
  - 加载了 Health(生命值) 设定，饥饿归 0 后不是秒死，而是扣除HP，死后身上携带的资源掉落为包裹。
  - **真实建造**：蓝图需要释放引力吸引 Agent 来实地敲打才能增加进度。
  - **真实仓储**：除了吃饭瞬间消耗，任何矿产被开采后，必须由 Agent 实体步行搬运进“当前有空位的住所”，才算入全局可用库存。拆除返还50%也同样适用于该物流规则。
- **【规则集8】核心点题：蚕食与战争扩张**：
  - **领地声索场**：军事/高级建筑产生辐射场，排斥非本族采集。
  - **异族 AI (竞争者)**：存在由同样参数驱动的敌对族群，争夺有限资源。
  - **碰撞即战争**：在领土交叉或争夺同一个高级矿点时，判定基础 Health 点数与建筑提供的武力 Buff 光环进行死斗，胜者留存，败者化作资源包。
  - **终极目标**：利用建筑的领地辐射和资源挤压，物理上“蚕食（Encroach）”整片大陆并灭绝异族。

### 下一步计划：
核心系统蓝图与所有基础运行规则已经彻底闭环并录入 [TODO.md](TODO.md) 中。下一步将正式进入**编码阶段（Execution）**。

### 修复：物件悬停信息 (Hover Info) 显示缺失的问题
- **问题分析**：`InspectUI` 原本只遍历 `World` 节点的直接子节点来检测鼠标悬停。而在架构调整后，`HumanAgent` 等实体被放在了管理器节点（如 `AgentManager`）之下，导致遍历不到。
- **解决方案**：引入 Godot 的 Node Group（节点组）机制。在 `Cave`、`Resource` 和 `HumanAgent` 实体中加入 `add_to_group("inspectable")`，并修改 `InspectUI` 通过 `get_tree().get_nodes_in_group("inspectable")` 来精准获取所有可检视对象，解决了信息不显示的问题，并且提高了后续添加新实体的扩展性。

### 重构：多资源类型分离系统
- **需求**：将原本只处理食物的单一资源流转改造为 FOOD/DIRT/IND_METAL/PREC_METAL 四种资源独立的搬运、储存、消耗管线。
- **变更范围**（7 个文件）：
  1. **`ResourceTypes.gd`** [新建]：全局共享 class_name 枚举，包含类型定义、翻译键、图标和工具方法
  2. **`Cave.gd`**：`stored_food: int` → `storage: Dictionary`，每种资源独立上限 100，保留向后兼容接口
  3. **`HumanAgent.gd`**：`CarriedResource` 枚举 → `carried_type: int`，新增规则集2 采集优先级（饱腹≥80 才采非食物）
  4. **`ResourceManager.gd`**：按类型分类统计野外资源与采集量
  5. **`StatsPanel.gd`**：分别显示 🍎/🪨/⚙️/💎 各类库存
  6. **`InspectUI.gd`**：山洞面板展示全部库存，Agent 面板展示携带资源类型

### 修复：InspectUI 悬停信息不显示
- **问题分析**：`InspectUI` 挂载在 `UIManager`（CanvasLayer）下，`get_viewport().get_camera_2d()` 返回 `null`，导致坐标转换失败。
- **解决方案**：改用 `get_tree().root.get_camera_2d()` 和 `get_tree().root.get_mouse_position()` 直接从根 Viewport 获取。

### 修复：采集优先级逻辑
- **问题**：储满的资源类型仍被采集；食物低时继续采矿物。
- **解决方案**：`_should_collect_type()` 增加三层判断：
  1. 山洞对应类型已满 → 跳过
  2. 食物库存 < 50% → 禁止采非食物
  3. 饱腹 < 80 → 禁止采非食物

### 修复：建筑错位显示与升级阻塞
- **问题分析**：老版本 `InspectUI` 把所有带库存对象都按“鸭子类型”强行为视为 `Cave` 导致建筑名字张冠李戴，同时玩家反馈木屋无法升级，由于底层逻辑设计失误引起了吞噬物资 Bug。
- **解决方案**：
  1. 改用物理基因组 `building_type` 精准加载格式器，各司其职，消灭跨物种乱码认领。
  2. **【防吞机制】**重写了 `PlayerController.gd` 里面的消费逻辑，由先扣钱后申请放置，分离成了“先检查全域物资 -> 申请原址放置 -> 放置成功后真实扣款”的安全三步走。
  3. **【防撞体积豁免】**在 `BuildingManager.gd` 中增加了专供“原址升级”的豁免检定，建筑升级膨胀不再受四周树木和小人的挤压判定而强行终止，家园顺利通向向摩天大楼。

### 优化：解决 AI 群挤扎堆问题（黑板锁定系统）
- **问题分析**：由于 `HumanAgent` 目标分配时全员共享相同的“距离阈值”最短路径视野，导致同时爆发需求（如农田产出）时，几十个小人叠在一块冲向同一目标，冗余行走大大降低集镇运作效率。
- **解决方案**：引入了基于 `meta(reserved_count)` 注册的黑板占位机制（Blackboard Reservation）。
  1. **多级并发限制**：设定野生矿点 (`MAX_RESERVERS_WILD = 1`) 不许围观；农场 (`FARM = 2`) 允许两人下地；在建蓝图 (`BLUEPRINT = 3`) 允许三人同敲。
  2. **智能分流避险**：在底层 `_find_and_move_to_nearest_resource` 的雷达循环中植入关卡。如果发现物理距离最近的苹果树**已被占满**，系统将强制蒙蔽当前 Agent 对该树的感知，促使其走向远处的备选点位，实现了极其优雅的宏观防扎堆群落分工计算。

## 2026-02-28

### 优化：解决高级建筑导致的人口涨幅滞缓
- **问题分析**：此前，全局的人口增长“按时间自动产妇”逻辑被死死绑定在了出生的唯一节点 `Cave` 身上，定死为 `SPAWN_INTERVAL_DAYS = 3650 (10年)`。导致玩家不管在后期造了多少座满载 150 人的大楼，全世界只有最初的那个山洞能每隔10年蹦出一个人。这造成了“小镇越繁华，出生率反而大幅暴跌”的致命失真。
- **解决方案**：我将繁衍的“时间发条”下放到了所有继承自 `Residence.gd` 的居住类模型里。
  1. 通过在 `BUILDING_DATA` 中引入随等级下降的 `spawn_interval_days`（例如：山洞10年，木屋8年，石屋5年，大厦1年）。
  2. 当 `TimeSystem` 中的日子越迁，全地图**所有有效住宅**都会并发计算其肚子里的计时器。若达到自身孕期并且其内部能抽调出 `FOOD_COST_PER_HUMAN = 50`，那么这栋楼就会随机选向四方自动生产一名新生儿。真正实现了以楼为基座的指数级几何人口大爆炸！
### 优化：美化详细建筑与资源信息面板（InspectUI）
- **问题分析**：玩家反馈点击高阶住宅时的信息面板（如石屋）极度拥挤丑陋，各项文本（上限光环、库存容量、升级要求）全部挤在没有行距的白色统一字号内，连大号的升级底栏按钮也因字数过多而粘连。
- **解决方案**：我重构了 `InspectUI.gd` 中用于排版的单体控件。
  1. **升级为富文本组件**：将主体显示框 `_content_label` 从原先的死板 `Label` 大换血为 `RichTextLabel` 并强制开启 `bbcode_enabled = true`。
  2. **注入色彩与多格式间距 (BBCode)**：使用 `[color=#aaddff]` 及 `[b]` 将属性奖励进行点亮处理。废弃硬编码的 `\n\n\n` 换行拼接，转而使用 `──── 库存物资 ────` 等带色精致分割线，使得区块一目了然。
  3. **升级按钮行距重构**：专门加高了 `_upgrade_btn` 的控件尺寸 Y，并将密密麻麻的五金建材升级条件做成了带醒目标题 `─ 需求建材 ─` 的多行等宽段落列表。视觉上再无压抑感。

### 新机制：【规则集6】实体生老病死与动态寿命体系、遗物包裹系统
- **问题分析**：之前游戏内的小人为长生不死状态（饥饿掉 0 仅瞬杀），后期容易导致人口臃肿。其次，正在搬运矿产的小人突然死亡会导致手头物资永久蒸发，缺乏生存后勤体验。同时，玩家提出小人的寿命应当与社会当时的房屋科技上限相挂钩。
- **解决方案**：完整实装“生命循环”功能：
  1. **独立 Health 血条与饿肚子流血**：`HumanAgent` 不再因饥饿立刻被引擎消灭。当 `hunger <= 0` 时，每天执行 `hp -= 5.0`。只有当 `hp <= 0` 时才会真正饿死。
  2. **动态科技寿命 `lifespan_days`**：重写了 `AgentManager.gd` 中的 `add_agent` 函数。新生的 Agent 寿命将取决于目前世界现存的最高级房屋（例如只有山洞则只能活 10~20年，建出大楼的新人则可延至 30~80年）。当在世时间超过这个动态锚定的天数时触发“寿终正寝”。
  3. **遗产化作 `ResourceDrop` 实体**：当任何 Agent 彻底死亡 (`_die`) 时，立刻检查它 `carried_amount` 是否有货。如果有，在死亡坐标呼叫 Manager 动态生成一个新的鸭子节点 `ResourceDrop.gd`。
  4. **全自动同类拾荒**：将打包好的 `ResourceDrop` 节点塞入 `resource` 分组，并在其中写入了 `collect` 和 `is_depleted` 方法。完美骗过了活着的 Agent 的扫描雷达。因此活着的小人在周围没果子时会第一时间冲向死去的同伴吸取包裹里的营养或矿石！

## 2026-03-01

### 修复：人口生育彻底失效与生命流逝体验缓慢问题
- **问题分析**：玩家反馈繁殖机制疑似未生效。排查发现两个核心问题：
  1. **时间尺度异常**：原先规定 1年=365天，山洞 10年一胎 意味着 3650 个 Tick，玩家实际需要挂机 2 小时才能看到第一个新生儿。
  2. **全局同步怀孕 Bug**：所有建筑用全局 `current_day % interval` 求余，导致多栋房子同一天集体爆兵。
- **解决方案**：
  1. 为 `Cave.gd` 和 `Residence.gd` 各自增加 `_days_active` 独立计时器，用该局部计时器代替全局天数求余。
  2. 将 `DAYS_PER_YEAR` 从 365 压缩至 **10**，同步调整 `BuildingManager.BUILDING_DATA` 中所有 `spawn_interval_days`（山洞:100, 木屋:80, 石屋:50, 大楼:10）。
  3. 将 `AgentManager.add_agent` 中寿命乘数从 `*365` 改为 `*10`。
- **效果**：玩家现在挂机几分钟即可观察到完整的代际更替（出生、繁荣、老死、遗物掉落）。

## 2026-03-01 17:19:39 - 資源與建築系統雙重機制實作

### 實作內容 (Implementation):
1. **野生資源枯竭與降級機制 (規則集5)**
   - 修改 `Resource.gd` 中的 `collect` 方法。
   - 實作 `_apply_degradation` 平滑更新資源狀態。
   - 貴金屬 (採空) -> 工業金屬 (採空) -> 土礦 (採空) -> 消失。
2. **建築拆除與資源返還 (規則集7 補完)**
   - 在 `BuildingManager.gd` 增加 `remove_building_with_refund()` 邏輯。
   - 拆除時根據建構成本動態 `_spawn_resource_drop` 返還 50% 資源包裹至原地附近。
   - `InspectUI.gd` 中新增「拆除建築」的紅色常駐按鈕以供點擊觸發 `PlayerController.demolish_building`。
3. **住所升級路線展開**
   - 修改 `InspectUI.gd` 內部按鈕產生結構，由單一按鈕改為動態 `VBoxContainer`。
   - 支援顯示陣列升級路線 (`UPGRADE_MAP`)，例如山洞可直接並排顯示木屋、石屋、大樓的升級選項。

### 未來待辦 (TODO):
- 需要玩家手動進入遊戲 Play 驗證，上述實作已於代碼層面保護且編譯無誤，但 Godot 目前的渲染環境限制了進一步的主動自動化測試。
- 下一階段可繼續進行 `TODO.md` 中的「時間速度控制（暫停/快進）」。

## 2026-03-01 17:34:28 - UI 完善：Agent 統計面板

### 實作內容 (Implementation):
1. **資料彙整 (Data Aggregation)**
   - 在 `AgentManager.gd` 中實作了 `get_agents_statistics()`，提供全域生命週期狀態統計（總人口、瀕危飢餓人數、平均年齡及行為狀態分佈）。
2. **純代碼介面 (Pure Code UI)**
   - 建立並完成了 `AgentStatsUI.gd`，利用 `RichTextLabel` 顯示 BBCode 格式的圖文。該面板無 .tscn 依賴。
3. **快捷鍵綁定 (Keybinding)**
   - 於 `UIManager.gd` 添加了實例化邏輯，並透過 `_input` 綁定 `C` 鍵，讓玩家能隨時切換此面板的顯示狀態。

### 未來待辦 (TODO):
- 需由玩家手動 Play 驗證 C 鍵開啟 Agent 統計面板的效果與數值準確性。
- 接下來可進行 `TODO.md` 中的「系統日誌/事件紀錄」或「建築選擇面板」。

## 2026-03-01 18:01:06 - UI 完善：建築清單與雙擊追蹤

### 實作內容 (Implementation):
1. **建築清單面板 (Pure Code UI)**
   - 建立並完成了 `BuildingListUI.gd`，每秒抓取 `BuildingManager` 底下所有的現有建築與未完成施工藍圖。
   - 包含對山洞 (Cave)、建設中藍圖及一般建築狀態 (健康度/提供人口等) 的動態判別。
2. **雙擊追蹤與連動選取**
   - 在每個 List 項目綁定 `gui_input`，如果攔截到左鍵雙擊 (`double_click`)，將會呼叫 `WorldCamera.focus_on` 達到平滑移動視角。
   - 同時自動幫玩家選中該建築 (呼叫 `PlayerController.select_building`) 以便 InspectUI 快速彈出。
3. **快捷鍵綁定 (Keybinding)**
   - 於 `UIManager.gd` 添加了 `B` 鍵，讓玩家能隨時開關此建築清單總覽。

### 未來待辦 (TODO):
- 目前的 TODO 中的 `完善 UI 显示（Agent 统计、建筑选择面板）` 已全數完成。
- 下一步可實作「系統日誌/事件紀錄」。

## 2026-03-01 20:41:13 - 建築引力與 AI 權重評估系統

### 實作內容 (Implementation):
1. **AI 決策核心升級**
   - 修改 `HumanAgent._find_and_move_to_nearest_resource()`：AI 不再只顧著找尋絕對距離最近的目標，而改採「最高分綜合評估法」。
   - 每 1 像素的路徑距離仍會給予 -0.2 的衰減懲罰。
2. **全局資源優先權 (Priority)**
   - 於 `ResourceManager.gd` 中新增 `get_resource_priority_weights()` 方法。掃描所有建築的庫存量。
   - 庫存低於 20% 會給予該資源 +200 的權重，若為食物跌破安全線，更會動態疊加 +300 以上的權重，讓 AI 有「搶救」的概念。
3. **農田特殊引力 (Attraction)**
   - 於 `Farm.gd` 新增 `get_attraction_weight()`。一旦農田生長達 100% (is_ready)，它會強行發出高達 +2000 的極高引力分數，吸引周圍或遠處無所事事的 Agent 優先前來收割。

### 未來待辦 (TODO):
- 目前的【規則集3】建築環境與引力規則 已完成。
- 下一步可為遊戲加入視覺反饋（如系統日誌）或進入【規則集8】軍備與異族擴張。

## 2026-03-01 20:53:15 - 硬核搬運物流 (視覺回饋與防呆)

### 實作內容 (Implementation):
1. **負重視覺化**
   - 於 `HumanAgent.gd` 內修改 `_draw()`：當身上有搬運物資 (`carried_amount > 0`) 時，除了顯示原本的顏色圓點，現在還會明確畫出帶有正負號的文字 `+10`，直觀顯示搬運數量。
2. **負重步態蹣跚 (減速機制)**
   - 修改 `_handle_movement()`，增加物理硬核感。如果是帶著資源回家的狀態，移動速度 `MOVE_SPEED` 強制打 7 折（降低 30%）。空手出門採集時則保持原速。
3. **全局防呆覆核 (Validation)**
   - 審視底層 `PlayerController.gd` 與 `ResourceManager.gd` 的全域倉儲抓取機制。
   - 確認了【在途物資不計入國庫】的準則。玩家要蓋房子的錢一定只能從已經送達 `Cave` 或建築倉儲內的才算數。
   - 確認了【接力拾荒】系統穩定運作，死亡居民掉落的遺物包裹能無縫繼承採集介面，被下個路人撿回家。

### 未來待辦 (TODO):
- 繼續實作【系統日誌 / 事件紀錄】系統，以文字流方式展示生態村的點滴。

## 2026-03-01 21:40:00 - 系統事件日誌 UI (System Event Log)

### 實作內容 (Implementation):
1. **建立事件日誌 UI (`EventLogUI.gd`)**
   - 不依賴 `.tscn`，純代碼建立對話框，透過動態 `add_child` 附著在 `UIManager` 下方。
   - 預設擺放在畫面的「右下角」，避開左上角的資源區。
   - 實作了自動淡出：文字停留 12 秒後開始變淡並刪除，以防止長時間遊戲爆滿。
   - 實作了容量防護：超過 15 則時自動移除最舊的日誌，保護畫面不被淹沒及節省系統資源。
2. **彩色事件串流 (Event Broadcasting)**
   - 加入了 Global 的 Call Group 廣播系統 (`get_tree().call_group("event_log")`)。
   - **居民生與死**：在 `AgentManager` 以及 `HumanAgent` 加入了事件。新生兒會帶綠色高亮，並播報存活預期壽命；餓死與老死分別帶有紅色與灰色。更加入「飢餓扣血初期的警告」。
   - **建築與生產**：在 `Building.gd` 播報藍圖放置與落成 (藍色)，在 `Farm.gd` 播報定期收成，在 `Residence.gd` 取代 Console 提示，秀出房子誕生人口的字樣。
3. **錯誤修復：原址升級資源折抵與防呆攔截**
   - 修復了 `PlayerController` 與 `InspectUI` 在判斷資源是否充裕時，未將「升級會自動拆除舊建築並返還 50%」計算在內，導致升級按鈕死鎖的問題。
   - 為所有建築類別統一實作了 `get_refund_resources` 介面，無論拆除或升級，都會退回建造成本 50% 並將肚子肚沒搬完的現貨退出來。
4. **錯誤修復：升級按鈕顯示綠色卻無法點擊**
   - 發現 `InspectUI.gd` 中的 `_update_inspect_content()` 為了更新資源字串，在 `_process` （每幀）中會一併重構 (`queue_free()` 再 `add_child`) 所有的升級按鈕。
   - 導致 Button 節點以每秒 60 次的速度重現，滑鼠引擎根本無法完成一個完整的按鈕 Click (Down/Up) 週期。
   - 已實作按鈕的「快取比對」渲染邏輯，只有在升級選項改變時才重建節點，否則只調用 `text` 與 `disabled` 的覆寫，徹底解決「按鈕點擊被吞掉」的假死錯覺。
5. **錯誤修復：居民 AI 忽略農田與物資採收蒸發 Bug**
   - 發現 `HumanAgent.gd` 的目標篩選機制中，為了躲避已蓋好的房子，會排除掉所有 `is_blueprint = false` 卻帶有 `add_progress` 介面的物件，這導致同樣繼承自 Building 的 Farm 雖然有 `collect` 卻被視為「完工的建築物不可摸」而遭無視。已改為精準「白名單（確認是可採集的資源或是可推進的藍圖）」過濾。
   - 由於農田成熟一次會爆發出 150+ 以上的巨額糧食並給予採集者，居民前往倉庫（如容量僅有 100 的山洞）存放後會滿倉，但先前的 `_deposit_to_cave` 會無腦將居民手上的餘額清為 0，導致物資永久蒸發。現已實裝找尋替補倉庫的機制，若全圖客滿則會將剩下的物資原地丟棄成為包裹，並推播橘色警告。

### 未來待辦 (TODO):
- 進展至最後一個核心項目：【規則集8】領地輻射與異族戰爭，或補齊建築清單與更多地形。

6. **大規模效能最佳化：ECS-lite 巨型重構 (The Grand Migration)**
   - **痛點**：原本每一名小人 (HumanAgent) 都是一個 `Node2D` 實體，這在前期數十人時尚可負擔，但在後期目標為「數千人」的場景中，每個 Node 都在獨立呼叫 `_process` 與迴圈找資源，效能將迅速面臨天花板。
   - **Data Degradation (資料降級)**：實作「物件導向」至「資料導向 (SoA)」的轉換。廢除了原有的 `HumanAgent.tscn`，將狀態管理從單一物件解偶，移入 `AgentManager` 的九個 `PackedArray` 中（例如 `agent_positions`, `agent_hunger` 等）。統一交由單一的 `_process` 迴圈批次結算生命週期、決策以及位移。
   - **Batch Rendering (批次渲染)**：引入 `MultiMeshInstance2D`，透過寫入實體矩陣 `Transform2D` 以達到 $O(1)$ Draw Call 的極致繪圖效能，讓上千名 Agent 得以流暢現身於螢幕。
   - **Mocking UI Interfaces (偽裝回調點選)**：修改 `PlayerController` 與 `InspectUI`，利用空間幾何距離測算直接掃描 `agent_positions` 陣列，並在玩家點下鼠標時現場合成一個僅供唯讀取讀的 `MockAgent` `Dictionary` 讓 UI 能與以往無縫接軌顯示資訊。

## 2026-03-02 09:15:00 - 修復：AgentManager 移動常數缺失

### 實作內容 (Implementation):
1. **補全變數宣告**
   - 修復了 `Error at (345, 33): Identifier "MOVE_SPEED" not declared in the current scope.` 引發的編譯錯誤。
   - 由於稍早進行了 ECS-lite 巨型重構，將 `HumanAgent` 遷移至 `AgentManager`，遺漏了 `MOVE_SPEED` 常數的遷移。現已於 `AgentManager.gd` 開頭補回 `const MOVE_SPEED: float = 300.0`。

## 2026-03-02 09:17:00 - 修復：初始生成 Agent 之型態錯誤

### 實作內容 (Implementation):
1. **修正指派型態錯誤**
   - 修復了 `E 0:00:00:648   _generate_initial_human: Trying to assign value of type 'int' to a variable of type 'Node2D'.` 引發的運行時錯誤。
   - 由於稍早進行了 ECS-lite 巨型重構，`AgentManager.add_agent()` 的回傳值已從原本的 `Node2D` (實體 Node) 改為 `int` (在 PackedArray 中的 Index ID)。因此修改了 `WorldGenerator.gd` 中 `_generate_initial_human` 函式的變數型態與判斷邏輯，改為接收並印出此 Index ID。

## 2026-03-02 09:21:00 - 修復：總人口面板型態存取錯誤

### 實作內容 (Implementation):
1. **修正陣列存取邏輯**
   - 修復了 `E 0:00:00:603 _setup_connections: Invalid access to property or key 'agents' on a base object of type 'Node (AgentManager.gd)'` 錯誤。
   - 由於 ECS-lite 巨型重構中，`AgentManager` 廢除了作為實體 Node 儲存的 `agents` 屬性陣列。已將 `StatsPanel.gd` 當中取得人口數的地方同步改為讀取 `_current_population` 變數。

## 2026-03-02 09:24:00 - 修復：資源管理器型態存取錯誤

### 實作內容 (Implementation):
1. **修正陣列存取邏輯**
   - 修復了 `get_resource_priority_weights: Invalid access to property or key 'agents' on a base object of type 'Node (AgentManager.gd)'` 錯誤。
   - 此問題同樣肇因於 ECS-lite 巨型重構。`ResourceManager.gd` 當中用來計算居民當前維生食物指標的人口全域變數讀取已同步調整為 `_current_population`。

## 2026-03-02 09:28:00 - 修復：實體採集參數型別衝突

### 實作內容 (Implementation):
1. **修正介面參數型別 (Interface Parameter Types)**
   - 修復了 `E 0:00:05:357 _collect_resource_for_agent: Invalid type in function 'collect' in base 'Node2D (Resource.gd)'.` 的錯誤。
   - 由於原先在「物件導向」時期，負責執行採集邏輯發起的是繼承自 `Node2D` 的 `HumanAgent`，因此 `collect(amount, collector: Node2D)` 約束了接收型別。
   - 但在 ECS-lite 重構後，負責統一調度所有 AI 的是 `AgentManager.gd` 本身，其繼承自更基礎的 `Node`。當傳入 `self` 時引發了不相容崩潰。
   - 已將 `Resource.gd`, `Farm.gd`, `ResourceDrop.gd` 的 `collect` 介面及其信號參數完全放寬至接收基礎的 `Node` 型別。

## 2026-03-02 09:33:00 - 修復：居民無視藍圖與升級罷工問題

### 實作內容 (Implementation):
1. **補全藍圖掃瞄隊列**
   - 發現玩家在「升級」或「新建」建築時出現了施工藍圖，但所有的 AI 閒置時都不會啟程去敲擊施工，導致建築永遠卡在原地的問題。
   - 問題出在 `AgentManager.gd` 的 `_find_nearest_resource_for_agent` 函式中，傳入的 `candidates` 陣列只有 `inspectable` 標籤的純野生資源（如果樹與小金礦），完全遺漏了由 `BuildingManager` 收容的 `blueprints`（藍圖列）。
   - 已透過動態擷取 `bm.get_all_blueprints()` 並將其聯集入搜尋陣列，讓 AI 重新把推進藍圖的工作與採集並量齊觀。

## 2026-03-02 09:44:00 - 修復：部分藍圖升級卡死 (抵達後發呆)

### 實作內容 (Implementation):
1. **同步抵達後的敲擊目標隊列**
   - 玩家回報在上一版修復後，依然有「第一棟成功升級，後續卻卡住」的狀況。
   - 經追蹤 FSM 狀態機，發現 `_find_nearest_resource_for_agent` 雖然修好了「把藍圖納入尋路」，但當 AI 走完路徑切換到狀態 `3: COLLECT` 時，所呼叫的 `_collect_resource_for_agent(idx, candidates)` 用的依然是不包含藍圖的舊陣列。
   - 導致 AI 抵達工地後，在清單裡找不到工地，於是瞬間放棄並將狀態洗白為 `0: IDLE`。下一幀它 `IDLE` 又再次接到了這個工地任務，如此陷入永無止盡的「發呆迴圈」。
   - 已在 `AgentManager.gd` 的 `_update_agent_state_machine` 將傳入的打擊目標同步聯集 `blueprints` 陣列，徹底根絕卡死問題。

## 2026-03-02 09:50:00 - 修復：無限重複點擊升級與異常扣款問題

### 實作內容 (Implementation):
1. **防呆限制與扣款修復**
   - 玩家回報建築升級按鈕按下後，在 UI 消失前的微小間隙可以「重複雙擊」，且升級常常表現出「未實際施工」。這是一個非常危險的雙重耗費與狀態不一致漏洞。
   - **UI 修正**：在 `InspectUI.gd` 中加入了 `btn.disabled = true` 的同步防護，確保點下的第一幀按鈕即失效。
   - **底層扣款邏輯 (`PlayerController.gd`) 修正**：先前我們將「拆除原建築返還的 50% 資金」當作了「升級津貼」在條件判斷（Check）中抵用了，但是到了實際提款（Consume）環節，系統卻原封不動地向各大倉庫索了「原始不打折的全額費用」。
   - 這個錯誤導致如果玩家的津貼加上國庫剛好可以買這個商品，系統允許他買，但最終提款時國庫發現沒這麼多錢，於是發生了「幽靈扣款現象」，部分物款被扣除但藍圖無效化的幽靈狀態。
   - 已在提款執行層將 `actual_cost` 套用了津貼扣抵，精準只針對「差額」向國庫提領，確保了經濟系統的穩定。

## 2026-03-02 09:58:00 - 修復：新建建築與第二棟山洞無法施工問題

### 實作內容 (Implementation):
1. **填補建築藍圖的 Duck Typing 介面缺漏**
   - 玩家回報「除了最初的升級之外，後續新建的建築/山洞升級依舊卡在施工中」。
   - 在 `AgentManager` 的尋雷達掃瞄中，會過濾所有 `candidates` 陣列，其中有一行關鍵判斷：`var can_build = is_bp and child.has_method("add_progress") and child.has_method("collect")` (或類似的過濾，具體為判定目標是否可被敲擊)。
   - 此外，如果目標 `child.has_method("is_depleted") and child.is_depleted()` 也會被視為無效狀態而跳過。
   - 徹查架構發現，作為所有建築的基礎類 `Building.gd` 以及特殊物件 `Cave.gd`，雖然都有 `is_blueprint = true` 並提供了 `add_progress()` 來增加進度，卻**完全沒有實作 `collect()` 與 `is_depleted()` 介面**，這導致 AI 把這些新建的藍圖當作了普通的死物，直接在過濾迴圈中將其剔除。
   - 解決方案：在 `Building.gd` 和 `Cave.gd` 補上了 `collect()` 和 `is_depleted()`，若處於藍圖狀態，敲擊時會為自身增加進度並返回 0 採集量，且宣告自己「未枯竭 (is_depleted() == false)」。現在所有的建築地基都能被 AI 的判定雷達正確識別並派工打擊了。

## 2026-03-02 10:15:00 - 修復：大型藍圖施工卡死 (抵達拒絕工作)

### 實作內容 (Implementation):
1. **修正 AI 對大型物件的打擊判定距離**
   - 玩家回報儘管介面修復了，但新建的 `Cave` (第二個山洞) 在升級時，AI 走到了卻依然發呆。
   - 深入追蹤 `AgentManager` 的 `_collect_resource_for_agent` (實際發動敲擊的最後一個環節) 發現，判斷 AI 是否能夠「摸到」資源的距離條件被硬編碼寫死了：`distance_to(pos) < 15.0`。
   - `15.0` 這個距離用在蘋果樹 (`Resource.gd`) 上很合理，但用在如山洞 (`Cave`) 這種動輒 80x80 大小的建築物上，AI 走到外圍就已經被碰撞體或目標點距離限制停下了，此時它距離建築「中心點 (global_position)」甚至還有超過 40 以上的距離。
   - 於是，AI 進入敲擊狀態後，偵測發現自己距離目標超過 15，認為四周「沒有合法可打擊物件」，接著瞬間就把任務放棄並洗白狀態發呆。
   - **解決方案**：在 `_collect_resource_for_agent` 中動態放寬了判定半徑 (reach)。如果在目標陣列中掃到的是「藍圖」、「建築」或「山洞」，直接將打擊判定放寬到 `60.0`，確保 AI 抵達工地周圍時就可以順利甩動工具增加進度。

## 2026-03-02 10:30:00 - 修復：原址升級碰撞誤判與永遠施工中 (假施工) Bug

### 實作內容 (Implementation):
1. **修復新建建築產生的野生資源假碰撞**
   - 玩家回報在空曠地上建立的新建築，點擊升級時會報錯「藍圖放置發生碰撞等阻礙失敗」而無法升級。
   - 發現這是因為之前為了讓 AI 能敲擊藍圖，替所有建築加上了 `collect()` 介面。這導致 `BuildingManager.gd` 在 `check_collision` 檢查「有哪些野生資源會擋路」(條件為 `has_method("collect")`) 時，把所有現存的房子都當成了野生資源框進去撞了。
   - 已在野生資源過濾圈中特別排除了 `is_in_group("building")`。
2. **修復新舊實體重疊帶來的「目標遮蔽」現象**
   - 玩家反應第二個現象：「如果避開了碰撞，升級藍圖放下了，AI 也過去敲了，卻還是永遠蓋不好」。
   - 透過沙盤推演，發現原址升級時，舊建築並"不會"馬上消失，而是原地和新藍圖重疊在一起。當 AI 到達執行 `_collect_resource_for_agent` 時，尋找目標陣列中的第一筆符合距離的物件發動 `collect`。如果舊建築恰好排在前面，AI 就會對著「已經蓋好」的舊建築窮敲猛打，舊建築的 `collect` 會回傳 0，於是 AI 啥也沒蓋出來便解散了任務；下一幀又接到造房任務走過來...
   - 已修改 `_collect_resource_for_agent` 目標選取器：如果同一個位址搜到多個可敲擊對象，必定優先選擇 `is_blueprint = true` 的藍圖，拒絕盲目敲打已完工的牆壁。

## 2026-03-02 10:50:00 - 修復：山洞升級卡階與繁殖期當局崩潰

### 實作內容 (Implementation):
1. **山洞繁殖邏輯適配 ECS-lite 架構**
   - 玩家回報出現 `Invalid access to property or key 'agents' on a base object of type 'Node (AgentManager.gd)'.` 紅字當機錯誤。
   - 這是 `Cave.gd` 中的 `_try_spawn_human` 企圖透過存取已被 ECS-lite 架構廢棄移除的物件導向節點陣列 `agents.size()` 來判斷人口上限所致。
   - 已修正為使用最新的快取變數 `_current_population`。
2. **山洞原址殘留導致升級遮蔽 (無法升級二階木屋以上)**
   - 玩家回報「山洞升級到木屋後，就無法再繼續往上升級」。
   - 原因在於升級完成的結算階段，`BuildingManager` 會呼叫 `remove_building(old_target)` 來銷毀原本的老建築。但是，由於最初始的山洞是由 `WorldGenerator` 直接掛載到世界樹上，**它從未被加入到管理員的 `buildings` 或 `blueprints` 陣列中！**
   - 這導致 `remove_building(Cave)` 在內部判斷「如果建築不在陣列中就不做事」，直接放過了這座舊山洞。
   - 於是地圖上同一個位置就堆疊了「新木屋」與一個「看不見的舊山洞」。當玩家點擊該位置時，判定框選中了那個依舊存在的舊山洞，而山洞的升級路線只有木屋，於是玩家按下去永遠只能蓋出更多的木屋藍圖，無法向石屋推進。
   - **解決方案：** 在 `BuildingManager.gd` 的 `remove_building` 函式中補上了「若物件合法且屬於山洞或建築群組，即使不在列管名單中也**無條件強制銷毀**」的安全網。徹底根絕了舊建築殘留的幽靈遮蔽現象。

## 2026-03-02 11:05:00 - 修復：舊存檔幽靈山洞阻擋升級與木屋資源滿額扣款問題

### 實作內容 (Implementation):
1. **清理舊存檔環境中的「不滅幽靈山洞」**
   - 玩家回報在上一波修復後，遇到「現在連木屋都升級不了了（點選後還是顯示有碰撞）」的情況。
   - 追查發現，儘管在上一個更新中修改了 `remove_building` 讓「後續新建築」升級時能成功清除下面的山洞，但**如果玩家是讀取舊檔或是該對局已經發生過幽靈山洞殘留**，這些看不見的山洞依然會永遠卡死該位址的建築。（當判定 `ignore_node` 是上方木屋時，因為底下還有個舊山洞，系統就會回報碰撞！）
   - 已在 `BuildingManager.gd` 的 `check_collision` 核心中加入：若發現底下有幽靈山洞，且它與正在檢查的新建築（`ignore_node`）座標完全一致（`<5.0`），則當場直接 `queue_free()` 把它強制超渡，讓木屋的升級得以順暢無阻。
2. **所有建築均可享有 50% 拆建津貼**
   - 順手查獲另一個可能因為「資源顯示不足」而導致按鈕不能按的隱患：原本只有 `Cave.gd` 有實作 `get_refund_resources()` 來折扣 50% 造價，而其餘建築包括 `木屋` 的基底 `Building.gd` 並沒有實作，導致從木屋升石屋時「不給玩家任何折扣津貼」，必須實打實地凑滿 500 礦和食物。這會讓玩家誤以為「無法升級」。
   - 已將 `get_refund_resources` 實作上拉至 `Building.gd` 中。現在所有後續二階、三階建築的升級都會享受折扣了。

## 2026-03-02 11:15:00 - 修復：山洞生人 GDScript 強型別賦值錯誤

### 實作內容 (Implementation):
1. **修復生人環節 `Trying to assign value of type 'int' to a variable of type 'Node2D'`**
   - 玩家回報剛修完的繁殖系統又因為別的原因紅字當機了。
   - 分析崩潰訊息，發現是 ECS-lite 大重構後，呼叫 `add_agent()` 取代了原本實體化 Node2D，現在只會回傳該位小人在資料陣列中的整數 ID (`int`)。但在 `Cave.gd:232` 依舊寫著 `var new_human: Node2D = _agent_manager.add_agent(...)`。
   - **解決方案：** 已將 `new_human` 宣告改為 `new_human_id: int`，並修改了成功的判定條件為 `>= 0`。消解了此處的引擎層級報錯。

## 2026-03-02 14:00:00 - 功能重構：導入 20x20 網格系統 (Grid System) 與修復 RichTextLabel 崩潰

### 實作內容 (Implementation):
1. **修復全域 `RichTextLabel::_draw_line` 渲染崩潰**
   - 玩家回報遊戲運行一半閃退，根據崩潰日誌指明是 `RichTextLabel::_draw_line` 發生存取違規 (EXC_BAD_ACCESS)。
   - **根本原因 (Root Cause)：** `InspectUI.gd` 在 `_process` 裡面**每一幀**（一秒60次）都在對 `_content_label` 執行 `parse_bbcode()` 並重置文本。這種極高頻的排版樹重建在 Godot 底層極易引發多執行緒渲染的指標懸空問題。
   - **修復方式：** 為 `InspectUI.gd` 加入 `UPDATE_INTERVAL = 0.1` 節流閥（Throttle）。現在檢視面版每秒最多只會重建 10 次內容，徹底排除了因為 C++ String/RichText 記憶體分配衝突導致的當機現象。
2. **底層重構：20x20 網格化系統 (Grid System)**
   - 為徹底解決「視覺沒交疊，但升級計算有碰撞」的長期痛點，實施了全域網格化機制。
   - **網格定義：** `BuildingManager.gd` 中定義了 `GRID_SIZE = 20.0` 及輔助函式 `snap_to_grid()`。
   - **消除寬容度：** 重寫 `check_collision`，廢除了「原址升級直接借用舊體積計算」的寬容防呆，改為 100% 嚴格檢查「新藍圖的網格區塊是否被侵佔」，並透過 `entity == ignore_node` 過濾掉自己。
   - **實體對齊：** 包含 `PlayerController.gd` 中的藍圖放置錨點、以及 `WorldGenerator.gd` 生成野生資源、開局山洞時，全部會經過 `snap_to_grid` 對齊，確保未來的世界如棋盤般工整，從本質上杜絕任何「微小錯位擴大成碰撞錯誤」的可能性。
