import json
from pathlib import Path

def md(s):
    return {"kind":1,"language":"markdown","value":s}

def sv(s):
    return {"kind":2,"language":"systemverilog","value":s}

def write(name, cells):
    data = {"version":1,"cells":cells}
    Path(name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")

write("uvm_object.svmd", [
md("""# uvm_object 详解

## 一句话总结

> **`uvm_object` 是 UVM 所有类的根，任何想被 factory 创建、能被 copy/compare/print 的数据类，最终都继承自它。**

---

## 1. 为什么要有 uvm_object

SystemVerilog 的 class 本身已经提供了 new() 和基本继承，为什么还要 uvm_object？

因为验证环境需要比“普通对象”更多的能力：

- 需要知道对象的名字和类型
- 需要能在运行时打印、复制、比较、打包对象
- 需要让 factory 根据类型名统一创建对象
- 需要支持 override 机制

`uvm_object` 就是在 SV class 之上，加了这一整套“验证专用”的基础能力。

## 2. 继承体系

```text
uvm_object
  ├── uvm_transaction
  │     └── uvm_sequence_item
  ├── uvm_component
  │     ├── uvm_env
  │     ├── uvm_agent
  │     ├── uvm_driver
  │     ├── uvm_monitor
  │     ├── uvm_scoreboard
  │     └── uvm_sequencer
  └── uvm_sequence
```

- `uvm_object`：根类，提供名字、创建、复制、比较、打印、打包等通用能力
- `uvm_transaction`：加了时间戳和事务记录
- `uvm_sequence_item`：再加 sequence 接口
- `uvm_component`：加了层次结构、phase、parent/child

## 3. uvm_object 提供了什么

### 3.1 名字管理

每个 uvm_object 都有一个字符串名字：

```systemverilog
function string get_name();
function void set_name(string name);
```

这个名字在打印、调试、report 里非常重要。

### 3.2 类型创建接口

配合宏注册后，可以通过 factory 统一创建：

```systemverilog
my_obj = my_class::type_id::create("my_obj");
```

这个能力是后面 override、config_db、phase 的基础。

### 3.3 数据处理能力

`uvm_object` 提供了常用 hook 和对外接口：

- `copy()` / `do_copy()`
- `compare()` / `do_compare()`
- `print()` / `do_print()`
- `pack()` / `do_pack()`
- `unpack()` / `do_unpack()`
- `record()` / `do_record()`

你既可以直接用宏自动生成，也可以自己重写 do_* 函数。

## 4. 最小例子

```systemverilog
class my_obj extends uvm_object;
    rand bit [31:0] data;

    `uvm_object_utils_begin(my_obj)
        `uvm_field_int(data, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "my_obj");
        super.new(name);
    endfunction
endclass
```

这个对象已经具备：

- 被 factory 创建
- 自动 copy/compare/print/pack
- 有名字

## 5. uvm_object 和 uvm_component 的区别

| 对比项 | uvm_object | uvm_component |
|--------|------------|---------------|
| 是否参与层次树 | 否 | 是 |
| 是否有 phase | 否 | 是 |
| 是否有 parent | 否 | 是 |
| 常见用途 | transaction、配置对象、sequence item | env、agent、driver、monitor、scoreboard |
| 创建方式 | `type_id::create()` | `type_id::create(name, parent)` |

## 6. 什么时候继承 uvm_object

当你的类满足这些条件之一：

- 需要被 factory 创建
- 需要 copy / compare / print / pack
- 需要在 sequence、test、env 之间传递
- 需要 override

就优先考虑继承 `uvm_object` 或其子类。

## 7. 一句话总结

`uvm_object` 是 UVM 的“对象基础设施”，它把普通 class 升级成了支持工厂、自动化数据处理和统一命名管理的验证对象。"""),
sv("""class cfg_obj extends uvm_object;
  rand bit [31:0] base_addr;
  rand bit [31:0] addr_mask;

  `uvm_object_utils_begin(cfg_obj)
    `uvm_field_int(base_addr, UVM_ALL_ON)
    `uvm_field_int(addr_mask, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "cfg_obj");
    super.new(name);
  endfunction
endclass

cfg_obj cfg;
cfg = cfg_obj::type_id::create("cfg");
cfg.base_addr = 32'h0000_0000;
cfg.print();""")
])

write("uvm_factory.svmd", [
md("""# uvm_factory 详解

## 一句话总结

> **`uvm_factory` 是 UVM 的“对象生产线”，负责登记类型、按名字创建对象、并支持 override 替换实现。**

---

## 1. 为什么需要 factory

没有 factory 时，对象创建就是直接写死：

```systemverilog
drv = new("drv", this);
```

这带来两个问题：

- 创建代码和具体类强绑定
- 想换一种实现时，必须改很多处代码

factory 的思想是：

- 先注册类型
- 再通过统一入口创建
- 需要替换时，只改注册/override，不改使用代码

## 2. factory 的核心职责

1. **注册类型**  
   用宏把类登记到 factory 表里。

2. **创建对象**  
   通过 `type_id::create()` 统一创建实例。

3. **支持 override**  
   在运行时把某个类型/实例替换成另一个子类。

## 3. 注册方式

### 3.1 非参数化类

```systemverilog
class my_item extends uvm_sequence_item;
  `uvm_object_utils(my_item)
endclass
```

### 3.2 参数化类

```systemverilog
class my_item #(int WIDTH = 32) extends uvm_sequence_item;
  `uvm_object_param_utils(my_item #(WIDTH))
endclass
```

### 3.3 组件类

```systemverilog
class my_driver extends uvm_driver #(my_item);
  `uvm_component_utils(my_driver)
endclass
```

注册之后，factory 才知道“这个类叫什么、怎么创建”。

## 4. 创建方式

### 4.1 uvm_object 类

```systemverilog
my_item item;
item = my_item::type_id::create("item");
```

### 4.2 uvm_component 类

```systemverilog
my_driver drv;
drv = my_driver::type_id::create("drv", this);
```

区别：component 需要传 parent。

## 5. override

factory 最大的价值就是 override。

### 5.1 按类型替换

```systemverilog
set_type_override_by_type(base_item::get_type(), child_item::get_type());
```

### 5.2 按实例替换

```systemverilog
set_inst_override_by_type("env.agent.drv", base_drv::get_type(), child_drv::get_type());
```

## 6. factory 创建和 new 的区别

| 对比项 | new() | factory create() |
|--------|-------|------------------|
| 是否支持 override | 否 | 是 |
| 是否记录层次 | 否 | component 会记录 |
| 是否统一入口 | 否 | 是 |
| 是否便于复用 | 差 | 好 |

## 7. 常见调试

### 7.1 打印 factory 注册信息

不同仿真器有各自命令，但常见思路是：

- 看某个类有没有注册成功
- 看 override 是否生效
- 看 create 时真正返回的是哪个类型

### 7.2 典型错误

- 忘了写注册宏
- 参数化类用了错误宏
- override 写错路径
- create 前就期待 override 生效

## 8. 一句话总结

`uvm_factory` 是 UVM 的“对象装配车间”，它让创建、替换、扩展都集中到统一入口完成，是 UVM 可复用验证环境的核心。"""),
sv("""class base_item extends uvm_sequence_item;
  rand bit [31:0] addr;
  `uvm_object_utils(base_item)
  function new(string name="base_item"); super.new(name); endfunction
endclass

class child_item extends base_item;
  rand bit [3:0] len;
  `uvm_object_utils(child_item)
  function new(string name="child_item"); super.new(name); endfunction
endclass

class my_test extends uvm_test;
  `uvm_component_utils(my_test)

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    set_type_override_by_type(base_item::get_type(), child_item::get_type());
  endfunction
endclass""")
])

write("uvm_component.svmd", [
md("""# uvm_component 详解

## 一句话总结

> **`uvm_component` 是 UVM 组件树的节点基类，负责层次结构、phase 调度和组件间连接。**

---

## 1. 为什么需要 uvm_component

验证平台不是单个对象，而是一棵组件树：

```text
uvm_test_top
└── env
    ├── agent
    │   ├── sequencer
    │   ├── driver
    │   └── monitor
    ├── ref_model
    └── scoreboard
```

这些组件需要：

- 有父子层次关系
- 按 phase 顺序执行
- 能互相连接端口
- 能被统一打印拓扑

这就是 `uvm_component` 的职责。

## 2. uvm_component 提供的能力

### 2.1 层次结构

每个 component 创建时都要指定 parent：

```systemverilog
my_driver drv;
drv = my_driver::type_id::create("drv", this);
```

其中 `this` 就是父组件。

### 2.2 phase 回调

component 可以实现：

```systemverilog
function void build_phase(uvm_phase phase);
function void connect_phase(uvm_phase phase);
function void end_of_elaboration_phase(uvm_phase phase);
function void start_of_simulation_phase(uvm_phase phase);
task run_phase(uvm_phase phase);
function void extract_phase(uvm_phase phase);
function void check_phase(uvm_phase phase);
function void report_phase(uvm_phase phase);
function void final_phase(uvm_phase phase);
```

UVM 会按顺序自动调用。

### 2.3 组件查找和遍历

常见方法：

- `get_parent()`
- `get_full_name()`
- `lookup()`
- `print_topology()`

## 3. component 的创建

```systemverilog
class my_env extends uvm_env;
  my_agent agent;
  my_scoreboard scb;

  `uvm_component_utils(my_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = my_agent::type_id::create("agent", this);
    scb   = my_scoreboard::type_id::create("scb", this);
  endfunction
endclass
```

## 4. component 和 object 的关键区别

| 对比项 | uvm_component | uvm_object |
|--------|---------------|------------|
| 是否有 parent | 有 | 无 |
| 是否进入层次树 | 是 | 否 |
| 是否有 phase | 是 | 否 |
| 创建参数 | `create(name, parent)` | `create(name)` |
| 常见对象 | env/agent/driver/monitor | transaction/config/sequence_item |

## 5. component 生命周期

典型顺序：

1. new()
2. build_phase()
3. connect_phase()
4. end_of_elaboration_phase()
5. start_of_simulation_phase()
6. run_phase()
7. extract_phase()
8. check_phase()
9. report_phase()
10. final_phase()

## 6. 常见错误

- 创建时忘了传 parent
- 在 `build_phase` 之外创建 component
- 把 component 当 object 用
- 忘记调用 `super.build_phase(phase)`

## 7. 一句话总结

`uvm_component` 是 UVM 的“骨架节点”，把各个验证单元组织成层次树，并让它们在统一 phase 下协同工作。"""),
sv("""class my_agent extends uvm_agent;
  my_driver drv;
  my_monitor mon;
  my_sequencer sqr;

  `uvm_component_utils(my_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = my_sequencer::type_id::create("sqr", this);
    drv = my_driver  ::type_id::create("drv", this);
    mon = my_monitor ::type_id::create("mon", this);
  endfunction
endclass""")
])

write("uvm_phases_detail.svmd", [
md("""# UVM Phase 详解（从 build 到 final）

## 一句话总结

> **UVM phase 是验证平台的“时间轴”，把建环境、连端口、跑激励、查结果分阶段执行。**

---

## 1. 为什么 phase 这么重要

如果没有 phase，driver、monitor、scoreboard、sequence 都会乱序执行，结果不可控。phase 的意义在于：

- 先建组件，再连端口
- 先初始化，再跑仿真
- 先收集结果，再统一报告

## 2. 常用 phase 顺序

```text
build_phase
  -> connect_phase
  -> end_of_elaboration_phase
  -> start_of_simulation_phase
  -> run_phase
  -> extract_phase
  -> check_phase
  -> report_phase
  -> final_phase
```

## 3. 每个 phase 做什么

### 3.1 build_phase

负责创建对象：

```systemverilog
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  agent = my_agent::type_id::create("agent", this);
endfunction
```

常见操作：

- 创建 component
- 创建 config object
- 设置 override
- 从 config_db 取参数

### 3.2 connect_phase

负责连接端口：

```systemverilog
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  mon.ap.connect(scb.analysis_export);
endfunction
```

### 3.3 end_of_elaboration_phase

结构已经稳定，常用于：

- 打印拓扑
- 检查层次是否正确

```systemverilog
uvm_top.print_topology();
```

### 3.4 start_of_simulation_phase

仿真开始前做初始化：

- 打开日志
- 打印开始信息
- 做最后一次状态检查

### 3.5 run_phase

真正耗时间的仿真阶段：

```systemverilog
task run_phase(uvm_phase phase);
  phase.raise_objection(this);
  seq.start(env.agent.sqr);
  phase.drop_objection(this);
endtask
```

### 3.6 extract_phase

提取统计结果：

- pass/fail 计数
- 覆盖率数据
- 错误信息

### 3.7 check_phase

检查结果是否满足要求。

### 3.8 report_phase

输出最终报告。

### 3.9 final_phase

最后收尾，一般很少写复杂逻辑。

## 4. function phase 和 task phase

| phase | 类型 | 是否能耗时 |
|-------|------|------------|
| build/connect/end_of_elaboration/start_of_simulation | function | 不能 |
| run | task | 可以 |
| extract/check/report/final | function | 不能 |

## 5. objection 机制

run_phase 里常用：

```systemverilog
phase.raise_objection(this);
...
phase.drop_objection(this);
```

作用：

- 防止仿真提前结束
- 等所有 objection 都 drop 后才退出 run_phase

## 6. 常见坑

- 在 build_phase 里写 `#10`，这是不行的
- 忘记 raise_objection，导致仿真直接结束
- 在 connect_phase 才创建组件，太晚
- 忘记调用 `super.xxx_phase(phase)`

## 7. 一句话总结

UVM phase 就是“验证平台的生命周期管理器”，它让每个组件都知道自己该在什么时候做什么事。"""),
sv("""class my_test extends uvm_test;
  `uvm_component_utils(my_test)

  my_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST", "run_phase start", UVM_LOW)
    #100ns;
    phase.drop_objection(this);
  endtask
endclass""")
])

write("uvm_config_db.svmd", [
md("""# uvm_config_db 详解

## 一句话总结

> **`uvm_config_db` 是 UVM 的“全局参数快递站”，用键值方式在 test/env/agent/driver 之间传递配置。**

---

## 1. 为什么需要 config_db

如果靠逐级 new 传参，层次一深就会非常麻烦：

- test -> env -> agent -> driver
- 每层都要重复写构造函数参数
- 结构一改变，所有中间层都要改

config_db 解决的是：

- 参数集中设置
- 按需获取
- 不破坏组件层次

## 2. 基本用法

### 2.1 set

```systemverilog
uvm_config_db#(int)::set(this, "env.agent.drv", "max_txn", 100);
```

### 2.2 get

```systemverilog
int max_txn;
if (!uvm_config_db#(int)::get(this, "", "max_txn", max_txn))
  `uvm_fatal("CFG", "max_txn not found")
```

## 3. 参数含义

```systemverilog
uvm_config_db#(T)::set(cntxt, inst_name, field_name, value);
uvm_config_db#(T)::get(cntxt, inst_name, field_name, value);
```

- `T`：传递的数据类型
- `cntxt`：路径上下文
- `inst_name`：实例路径
- `field_name`：字段名
- `value`：值

## 4. 典型场景

### 4.1 传 virtual interface

```systemverilog
uvm_config_db#(virtual my_if)::set(null, "uvm_test_top.env.agent.drv", "vif", tb_if);
```

driver 中：

```systemverilog
virtual my_if vif;
if (!uvm_config_db#(virtual my_if)::get(this, "", "vif", vif))
  `uvm_fatal("VIF", "vif not set")
```

### 4.2 传配置对象

```systemverilog
my_cfg cfg;
cfg = my_cfg::type_id::create("cfg");
cfg.max_len = 16;
uvm_config_db#(my_cfg)::set(this, "env", "cfg", cfg);
```

### 4.3 传开关参数

```systemverilog
uvm_config_db#(bit)::set(this, "env.scb", "enable_check", 1);
```

## 5. 常见坑

- 类型不匹配：set 用 int，get 用 bit
- 路径写错，导致 get 不到
- 在错误 phase 里 get，组件还没创建
- 用 config_db 传太多本该显式连接的数据，导致结构不清晰

## 6. config_db 和资源数据库的关系

可以把 config_db 看作：

- 全局可查找的配置仓库
- 但需要自己保证类型、路径、字段名一致

## 7. 一句话总结

`uvm_config_db` 就是 UVM 的“参数快递系统”，把 test 里的配置精准送到任何需要的组件。"""),
sv("""class my_cfg extends uvm_object;
  rand bit [31:0] base_addr;
  `uvm_object_utils(my_cfg)
  function new(string name="my_cfg"); super.new(name); endfunction
endclass

class my_test extends uvm_test;
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    my_cfg cfg = my_cfg::type_id::create("cfg");
    cfg.base_addr = 32'h1000_0000;
    uvm_config_db#(my_cfg)::set(this, "env", "cfg", cfg);
  endfunction
endclass

class my_env extends uvm_env;
  my_cfg cfg;
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(my_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("CFG", "cfg not found")
  endfunction
endclass""")
])

write("uvm_sequence.svmd", [
md("""# uvm_sequence 详解

## 一句话总结

> **`uvm_sequence` 是“发激励的脚本”，负责创建、随机化并发送 sequence_item 给 sequencer。**

---

## 1. sequence 和 sequence_item 的关系

- `sequence_item`：数据包，描述“发什么”
- `sequence`：发送逻辑，描述“怎么发、发多少、按什么顺序发”

比如：

- 先写 10 次，再读 10 次
- 先发 short burst，再发 long burst
- 先发合法包，再发错误包

这些控制逻辑都写在 sequence 里。

## 2. 基本结构

```systemverilog
class my_seq extends uvm_sequence #(my_item);
  `uvm_object_utils(my_seq)

  function new(string name = "my_seq");
    super.new(name);
  endfunction

  task body();
    my_item item;
    repeat (10) begin
      item = my_item::type_id::create("item");
      start_item(item);
      if (!item.randomize())
        `uvm_error("SEQ", "randomize failed")
      finish_item(item);
    end
  endtask
endclass
```

## 3. body() 是关键

`body()` 是 sequence 的主任务，真正发激励的代码都写在这里。

## 4. start_item / finish_item

### 4.1 start_item

- 向 sequencer 申请发送
- 等待许可

### 4.2 finish_item

- 把 item 交给 driver
- 等 driver 完成

## 5. sequence 怎么启动

### 5.1 在 test 中启动

```systemverilog
my_seq seq;
seq = my_seq::type_id::create("seq");
seq.start(env.agent.sqr);
```

### 5.2 在 run_phase 中启动

```systemverilog
task run_phase(uvm_phase phase);
  my_seq seq;
  phase.raise_objection(this);
  seq = my_seq::type_id::create("seq");
  seq.start(env.agent.sqr);
  phase.drop_objection(this);
endtask
```

## 6. 常见 sequence 类型

### 6.1 定向 sequence

固定数据，验证特定场景。

### 6.2 随机 sequence

通过 randomize 产生大量合法组合。

### 6.3 嵌套 sequence

一个 sequence 中启动另一个 sequence。

## 7. 和 sequencer 的分工

- sequence：产生激励
- sequencer：把激励交给 driver
- driver：真正把激励驱动到 DUT

## 8. 一句话总结

`uvm_sequence` 就是“激励剧本”，它决定数据包的产生顺序、数量和约束，是 UVM 动态激励的核心。"""),
sv("""class my_item extends uvm_sequence_item;
  rand bit [31:0] addr;
  rand bit [31:0] data;
  `uvm_object_utils(my_item)
  function new(string name="my_item"); super.new(name); endfunction
endclass

class my_seq extends uvm_sequence #(my_item);
  `uvm_object_utils(my_seq)
  function new(string name="my_seq"); super.new(name); endfunction

  task body();
    my_item item;
    repeat (5) begin
      item = my_item::type_id::create("item");
      start_item(item);
      item.randomize();
      finish_item(item);
    end
  endtask
endclass""")
])

write("uvm_sequencer.svmd", [
md("""# uvm_sequencer 详解

## 一句话总结

> **`uvm_sequencer` 是 sequence 和 driver 之间的“中转站”，负责把 sequence_item 从 sequence 送到 driver。**

---

## 1. sequencer 的位置

```text
sequence -> sequencer -> driver -> DUT
```

它不直接产生激励，也不直接驱动信号，它只做调度和传递。

## 2. 为什么需要 sequencer

如果没有 sequencer，sequence 和 driver 会强耦合：

- sequence 直接依赖 driver 实现
- 多 sequence 同时运行时不好管理
- driver 获取 item 的方式不统一

sequencer 把两者解耦。

## 3. sequencer 的职责

1. 接收 sequence 的 item 请求  
2. 仲裁多个 sequence 的发送顺序  
3. 把 item 交给 driver  
4. 管理 item_done/get_next_item 等握手

## 4. 最小例子

```systemverilog
class my_sequencer extends uvm_sequencer #(my_item);
  `uvm_component_utils(my_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

一般情况下，sequencer 不需要写太多自定义逻辑，UVM 已经实现了大部分功能。

## 5. driver 和 sequencer 的连接

```systemverilog
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  drv.seq_item_port.connect(sqr.seq_item_export);
endfunction
```

## 6. sequence 如何在 sequencer 上运行

```systemverilog
seq.start(sqr);
```

这表示：

- sequence 通过这个 sequencer 发送 item
- sequencer 再把 item 交给连接的 driver

## 7. sequencer 和 sequence 的区别

| 对比项 | sequence | sequencer |
|--------|----------|-----------|
| 作用 | 产生激励 | 调度并转发激励 |
| 是否是 component | 否 | 是 |
| 是否有 phase | 否 | 是 |
| 是否直接驱动 DUT | 否 | 否 |

## 8. 一句话总结

`uvm_sequencer` 就是“激励快递员”，把 sequence 产生的 item 有序地送到 driver 手里。"""),
sv("""class my_sequencer extends uvm_sequencer #(my_item);
  `uvm_component_utils(my_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class my_agent extends uvm_agent;
  my_sequencer sqr;
  my_driver    drv;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = my_sequencer::type_id::create("sqr", this);
    drv = my_driver   ::type_id::create("drv", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass""")
])

write("uvm_driver.svmd", [
md("""# uvm_driver 详解

## 一句话总结

> **`uvm_driver` 是把 sequence_item 翻译成 DUT 引脚动作的“执行者”。**

---

## 1. driver 的位置

```text
sequence -> sequencer -> driver -> DUT
```

driver 是最后一个“软件侧”组件，再往下就是 DUT 信号。

## 2. driver 的职责

- 从 sequencer 获取 item
- 按协议把 item 转换成接口信号
- 控制时序
- 返回 item_done()

## 3. 基本结构

```systemverilog
class my_driver extends uvm_driver #(my_item);
  `uvm_component_utils(my_driver)

  virtual my_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual my_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "vif not found")
  endfunction

  task run_phase(uvm_phase phase);
    my_item item;
    forever begin
      seq_item_port.get_next_item(item);
      drive_item(item);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(my_item item);
    @(posedge vif.clk);
    vif.addr <= item.addr;
    vif.data <= item.data;
  endtask
endclass
```

## 4. driver 和 interface 的关系

driver 一般不直接操作 module，而是通过 virtual interface 操作接口信号。

好处：

- testbench 和 DUT 解耦
- 代码更容易复用
- 时序更清晰

## 5. get_next_item 和 item_done

### 5.1 get_next_item

- 从 sequencer 取下一个 item
- 会阻塞等待

### 5.2 item_done

- 告诉 sequencer 当前 item 已经处理完
- sequencer 才能继续发下一个

## 6. driver 中常见写法

### 6.1 复位处理

```systemverilog
task run_phase(uvm_phase phase);
  wait (vif.rst_n === 1'b1);
  forever begin
    seq_item_port.get_next_item(item);
    drive_item(item);
    seq_item_port.item_done();
  end
endtask
```

### 6.2 分时操作

```systemverilog
task drive_item(my_item item);
  @(posedge vif.clk);
  vif.req <= 1'b1;
  vif.addr <= item.addr;
  @(posedge vif.clk);
  vif.req <= 1'b0;
endtask
```

## 7. 常见坑

- 忘拿 virtual interface
- 在 function phase 里写时序逻辑
- 忘记 item_done()
- 驱动和采样同一拍，导致竞争

## 8. 一句话总结

`uvm_driver` 就是“翻译官”，把抽象的 transaction 翻译成 DUT 真正能看到的引脚行为。"""),
sv("""class my_driver extends uvm_driver #(my_item);
  `uvm_component_utils(my_driver)

  virtual my_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    my_item item;
    forever begin
      seq_item_port.get_next_item(item);
      drive(item);
      seq_item_port.item_done();
    end
  endtask

  task drive(my_item item);
    @(posedge vif.clk);
    vif.start <= 1'b1;
    vif.addr  <= item.addr;
    @(posedge vif.clk);
    vif.start <= 1'b0;
  endtask
endclass""")
])

write("uvm_monitor.svmd", [
md("""# uvm_monitor 详解

## 一句话总结

> **`uvm_monitor` 是“观察者”，负责从 DUT 接口上采样信号，还原成 transaction 并广播给其他组件。**

---

## 1. monitor 的位置

```text
DUT -> monitor -> analysis port -> scoreboard / coverage / subscriber
```

monitor 不驱动 DUT，只看。

## 2. monitor 的职责

- 采样接口信号
- 按协议拼成 transaction
- 发给 scoreboard、coverage、logger
- 不修改 DUT 行为

## 3. 基本结构

```systemverilog
class my_monitor extends uvm_monitor;
  `uvm_component_utils(my_monitor)

  virtual my_if vif;
  uvm_analysis_port #(my_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual my_if)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "vif not found")
  endfunction

  task run_phase(uvm_phase phase);
    my_item item;
    forever begin
      @(posedge vif.clk);
      if (vif.valid) begin
        item = my_item::type_id::create("item");
        item.addr = vif.addr;
        item.data = vif.data;
        ap.write(item);
      end
    end
  endtask
endclass
```

## 4. analysis_port 的作用

monitor 通常用 analysis_port 广播数据：

- scoreboard 订阅
- coverage 订阅
- logger 订阅

一对多，互不影响。

## 5. monitor 和 driver 的区别

| 对比项 | driver | monitor |
|--------|--------|---------|
| 方向 | testbench -> DUT | DUT -> testbench |
| 是否驱动信号 | 是 | 否 |
| 是否主动控制时序 | 是 | 否 |
| 输出 | 引脚动作 | transaction |

## 6. monitor 采样注意点

- 注意 setup/hold 时间
- 避免和 driver 在同一时刻竞争
- 采样时使用 clocking block 更稳妥
- 不要在 monitor 里做复杂协议修复，保持“观察”职责

## 7. 一句话总结

`uvm_monitor` 就是“雷达”，专门盯着 DUT 的接口，把看到的信号翻译成可分析的 transaction。"""),
sv("""class my_monitor extends uvm_monitor;
  `uvm_component_utils(my_monitor)

  virtual my_if vif;
  uvm_analysis_port #(my_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    my_item tr;
    forever begin
      @(posedge vif.clk);
      if (vif.valid) begin
        tr = my_item::type_id::create("tr");
        tr.addr = vif.addr;
        tr.data = vif.data;
        ap.write(tr);
      end
    end
  endtask
endclass""")
])

write("uvm_agent.svmd", [
md("""# uvm_agent 详解

## 一句话总结

> **`uvm_agent` 是把 driver、monitor、sequencer 打包在一起的“协议小组”。**

---

## 1. agent 的作用

一个完整接口通常需要：

- sequencer：产生/转发激励
- driver：驱动 DUT
- monitor：观察 DUT

agent 就是把这三者装在一起，对外统一暴露。

## 2. 为什么需要 agent

如果没有 agent，env 里会直接堆很多零散组件：

- driver 一个
- monitor 一个
- sequencer 一个
- 端口连接也散在各处

agent 的意义是：

- 复用一个接口协议
- 统一创建和连接
- 对外只暴露一个整体

## 3. 典型结构

```systemverilog
class my_agent extends uvm_agent;
  `uvm_component_utils(my_agent)

  my_sequencer sqr;
  my_driver    drv;
  my_monitor   mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = my_sequencer::type_id::create("sqr", this);
    drv = my_driver   ::type_id::create("drv", this);
    mon = my_monitor  ::type_id::create("mon", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
```

## 4. agent 的 active / passive

### 4.1 active agent

- 有 driver + sequencer + monitor
- 既能驱动 DUT，也能观察 DUT

### 4.2 passive agent

- 只有 monitor
- 只观察，不驱动

通常会通过配置参数决定：

```systemverilog
if (is_active == UVM_ACTIVE) begin
  sqr = ...;
  drv = ...;
end
mon = ...;
```

## 5. agent 和 env 的关系

- env 是“更大的容器”
- agent 是 env 里的“接口小组”

一个 env 可以包含多个 agent：

- AHB agent
- APB agent
- UART agent

## 6. 一句话总结

`uvm_agent` 是“协议套件”，把一个接口相关的发送、驱动、监控打包成一个可复用模块。"""),
sv("""class my_agent extends uvm_agent;
  `uvm_component_utils(my_agent)

  my_sequencer sqr;
  my_driver    drv;
  my_monitor   mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = my_sequencer::type_id::create("sqr", this);
    drv = my_driver   ::type_id::create("drv", this);
    mon = my_monitor  ::type_id::create("mon", this);
  endfunction
endclass""")
])

write("uvm_scoreboard.svmd", [
md("""# uvm_scoreboard 详解

## 一句话总结

> **`uvm_scoreboard` 是“裁判”，负责比较期望值和实际值，判断 DUT 是否正确。**

---

## 1. scoreboard 的作用

验证平台的核心问题是：

- DUT 输出对不对？
- 数据有没有丢？
- 顺序对不对？
- 响应对不对？

scoreboard 就是专门回答这些问题的组件。

## 2. 数据来源

scoreboard 通常接收两类数据：

- expected transaction（来自 reference model / predictor）
- actual transaction（来自 monitor）

## 3. 基本结构

```systemverilog
class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_analysis_imp_exp #(my_item, my_scoreboard) exp_export;
  uvm_analysis_imp_act #(my_item, my_scoreboard) act_export;

  my_item exp_q[$];
  my_item act_q[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    exp_export = new("exp_export", this);
    act_export = new("act_export", this);
  endfunction

  function void write_exp(my_item item);
    exp_q.push_back(item);
    compare();
  endfunction

  function void write_act(my_item item);
    act_q.push_back(item);
    compare();
  endfunction

  function void compare();
    if (exp_q.size() > 0 && act_q.size() > 0) begin
      my_item e = exp_q.pop_front();
      my_item a = act_q.pop_front();
      if (a.data !== e.data)
        `uvm_error("SCB", $sformatf("data mismatch exp=%h act=%h", e.data, a.data))
    end
  endfunction
endclass
```

## 4. scoreboard 常见比较方式

### 4.1 顺序比较

- 队列一一对应
- 最常见

### 4.2 无序比较

- 适合乱序完成的事务
- 需要 transaction id 匹配

### 4.3 窗口比较

- 允许一定时间窗口内匹配

## 5. scoreboard 的职责边界

scoreboard 不应该：

- 驱动 DUT
- 修改 transaction
- 承担 reference model 的全部职责

它应该专注：

- 接收 expected/actual
- 比较
- 报错和统计

## 6. 一句话总结

`uvm_scoreboard` 就是“比对器”，把期望结果和真实结果放在一起对答案。"""),
sv("""class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_analysis_imp_exp #(my_item, my_scoreboard) exp_export;
  uvm_analysis_imp_act #(my_item, my_scoreboard) act_export;

  my_item exp_q[$];
  my_item act_q[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    exp_export = new("exp_export", this);
    act_export = new("act_export", this);
  endfunction

  function void write_exp(my_item item);
    exp_q.push_back(item);
  endfunction

  function void write_act(my_item item);
    act_q.push_back(item);
  endfunction
endclass""")
])

write("uvm_subscriber.svmd", [
md("""# uvm_subscriber 详解

## 一句话总结

> **`uvm_subscriber` 是“监听者”，专门接收 analysis port 广播的 transaction，用来做覆盖率、日志或统计。**

---

## 1. subscriber 是什么

subscriber 本质上是 analysis 接收端的封装：

- monitor 发出 transaction
- subscriber 接收 transaction
- subscriber 再做统计、覆盖率、打印

## 2. 为什么需要 subscriber

有些功能不适合写在 scoreboard 里：

- coverage collector
- transaction logger
- performance monitor
- protocol statistics

这些“旁听型组件”就很适合 subscriber。

## 3. 基本结构

```systemverilog
class my_subscriber extends uvm_subscriber #(my_item);
  `uvm_component_utils(my_subscriber)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void write(my_item t);
    `uvm_info("SUB", $sformatf("get item addr=%h data=%h", t.addr, t.data), UVM_LOW)
  endfunction
endclass
```

## 4. subscriber 和 scoreboard 的区别

| 对比项 | subscriber | scoreboard |
|--------|------------|------------|
| 主要用途 | 统计/覆盖率/日志 | 正确性比较 |
| 是否判断对错 | 不一定 | 是 |
| 接收方式 | analysis port | analysis export/imp |
| 典型场景 | coverage collector | expected vs actual |

## 5. subscriber 的典型用法

### 5.1 coverage collector

把 transaction 中的字段采样进 covergroup。

### 5.2 logger

打印所有 transaction，方便调试。

### 5.3 统计器

统计不同命令、地址、长度的出现次数。

## 6. 一句话总结

`uvm_subscriber` 就是“旁听席”，不直接判决对错，但会把 transaction 收集起来做分析。"""),
sv("""class my_subscriber extends uvm_subscriber #(my_item);
  `uvm_component_utils(my_subscriber)

  covergroup cg;
    cp_addr: coverpoint t.addr;
    cp_data: coverpoint t.data;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction

  function void write(my_item t);
    cg.sample();
  endfunction
endclass""")
])

write("uvm_env_test.svmd", [
md("""# uvm_env 与 uvm_test 详解

## 一句话总结

> **`uvm_env` 是“验证平台总装车间”，`uvm_test` 是“导演”，决定这次仿真用哪个环境、发什么激励、做什么配置。**

---

## 1. env 和 test 的关系

```text
uvm_test
  └── env
        ├── agent
        ├── scoreboard
        └── subscriber
```

- test 负责选择和配置
- env 负责组织和连接

## 2. uvm_env 的职责

env 通常做这些事：

- 创建 agent、scoreboard、subscriber
- 连接 analysis port
- 接收配置对象
- 组织验证拓扑

### 2.1 env 示例

```systemverilog
class my_env extends uvm_env;
  `uvm_component_utils(my_env)

  my_agent      agent;
  my_scoreboard scb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = my_agent     ::type_id::create("agent", this);
    scb   = my_scoreboard::type_id::create("scb",   this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(scb.analysis_export);
  endfunction
endclass
```

## 3. uvm_test 的职责

test 通常做这些事：

- 创建 env
- 设置 config_db
- 设置 factory override
- 启动 sequence
- 控制 objection

### 3.1 test 示例

```systemverilog
class my_test extends uvm_test;
  `uvm_component_utils(my_test)

  my_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    my_seq seq;
    phase.raise_objection(this);
    seq = my_seq::type_id::create("seq");
    seq.start(env.agent.sqr);
    phase.drop_objection(this);
  endtask
endclass
```

## 4. env 和 test 的分工

| 对比项 | env | test |
|--------|-----|------|
| 主要作用 | 搭平台 | 定场景 |
| 是否复用 | 高 | 通常每个测试一个 |
| 是否启动 sequence | 一般不 | 经常 |
| 是否设置 override | 可以 | 最常见 |
| 是否连接 agent/scoreboard | 是 | 一般不直接做细节连接 |

## 5. 常见模式

### 5.1 base test + 派生 test

- base_test：搭公共环境
- smoke_test / random_test / error_test：只改配置和 sequence

### 5.2 env 可复用，test 多样化

这是 UVM 最典型的复用方式。

## 6. 一句话总结

`uvm_env` 负责“把验证平台搭起来”，`uvm_test` 负责“决定这次怎么跑”。"""),
sv("""class my_env extends uvm_env;
  `uvm_component_utils(my_env)
  my_agent agent;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = my_agent::type_id::create("agent", this);
  endfunction
endclass

class my_test extends uvm_test;
  `uvm_component_utils(my_test)
  my_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
  endfunction
endclass""")
])

write("uvm_tlm.svmd", [
md("""# UVM TLM 端口详解

## 一句话总结

> **TLM 是 UVM 组件之间传 transaction 的“标准插座”，让组件不靠直接调函数也能通信。**

---

## 1. 为什么需要 TLM

如果组件之间直接互相调用函数，会有几个问题：

- 组件耦合太紧
- 层次一深就很难维护
- 替换一个组件会牵连很多代码

TLM 的思想是：

- 组件只暴露端口
- 连接关系由上层决定
- 数据怎么流动和组件内部实现解耦

## 2. 常见端口类型

### 2.1 analysis_port

一对多广播，常见于 monitor：

```systemverilog
uvm_analysis_port #(my_item) ap;
```

### 2.2 analysis_export / analysis_imp

接收 analysis_port 的数据：

```systemverilog
uvm_analysis_imp #(my_item, my_scoreboard) analysis_export;
```

### 2.3 seq_item_port / seq_item_export

sequencer 和 driver 之间传递 item：

```systemverilog
drv.seq_item_port.connect(sqr.seq_item_export);
```

## 3. connect 方向

```systemverilog
mon.ap.connect(scb.analysis_export);
drv.seq_item_port.connect(sqr.seq_item_export);
```

原则：

- port 连 export
- export 连 imp
- 最终在 imp 端实现 write()/get()/put() 等方法

## 4. analysis 通信的特点

- 单向广播
- 一对多
- 接收方不阻塞发送方
- 常用于 monitor -> scoreboard / coverage / subscriber

## 5. 常见组合

### 5.1 monitor -> scoreboard

```systemverilog
mon.ap.connect(scb.analysis_export);
```

### 5.2 monitor -> coverage

```systemverilog
mon.ap.connect(cov.analysis_export);
```

### 5.3 sequencer -> driver

```systemverilog
drv.seq_item_port.connect(sqr.seq_item_export);
```

## 6. 一句话总结

TLM 就是 UVM 组件之间的“标准化数据接口”，让组件像积木一样插接。"""),
sv("""class my_monitor extends uvm_monitor;
  uvm_analysis_port #(my_item) ap;
  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction
endclass

class my_scoreboard extends uvm_scoreboard;
  uvm_analysis_imp #(my_item, my_scoreboard) analysis_export;
  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction
  function void write(my_item t);
    `uvm_info("SCB", "got item", UVM_LOW)
  endfunction
endclass""")
])

write("uvm_reporting.svmd", [
md("""# UVM Report / Message 机制详解

## 一句话总结

> **UVM 消息机制就是“统一打印系统”，用 info/warning/error/fatal 分级输出调试和检查结果。**

---

## 1. 为什么不用 $display

`$display` 当然能用，但问题是：

- 没有统一级别
- 不能方便过滤
- 不利于大规模平台调试

UVM 消息机制提供了：

- 消息级别
- 消息 ID
- verbosity 控制
- report catcher / handler

## 2. 常用宏

### 2.1 info

```systemverilog
`uvm_info("ID", "message", UVM_LOW)
```

### 2.2 warning

```systemverilog
`uvm_warning("ID", "message")
```

### 2.3 error

```systemverilog
`uvm_error("ID", "message")
```

### 2.4 fatal

```systemverilog
`uvm_fatal("ID", "message")
```

## 3. verbosity

常见级别：

- `UVM_NONE`
- `UVM_LOW`
- `UVM_MEDIUM`
- `UVM_HIGH`
- `UVM_FULL`
- `UVM_DEBUG`

verbosity 越高，打印越详细。

## 4. 消息 ID 的作用

ID 用来分类消息，比如：

- "DRV"
- "MON"
- "SCB"
- "CFG"
- "TEST"

好处：

- 方便过滤
- 方便定位问题来源

## 5. report 和 phase 的配合

- run_phase：打印关键进度
- check_phase：输出 error / fatal
- report_phase：汇总 pass/fail 统计

## 6. 常见建议

- 关键流程用 UVM_LOW
- 调试细节用 UVM_HIGH / UVM_DEBUG
- 真正错误用 `uvm_error`，不要只 `$display`
- 致命配置缺失用 `uvm_fatal`

## 7. 一句话总结

UVM report 机制就是“分级、可过滤、可统一管理的打印系统”，比裸 `$display` 更适合大型验证平台。"""),
sv("""class my_driver extends uvm_driver #(my_item);
  `uvm_component_utils(my_driver)

  task run_phase(uvm_phase phase);
    `uvm_info("DRV", "driver started", UVM_LOW)
    `uvm_warning("DRV", "this is a warning example")
    `uvm_error("DRV", "this is an error example")
  endtask
endclass""")
])

write("uvm_objection.svmd", [
md("""# UVM Objection 机制详解

## 一句话总结

> **objection 就是“别急着结束仿真”的计数器，所有 objection 都 drop 后，run_phase 才结束。**

---

## 1. 为什么需要 objection

UVM 默认会想尽快结束仿真，但很多 test 其实还在发激励、等响应。如果没有 objection，仿真可能提前终止。

objection 的作用：

- 告诉 UVM“我还没干完”
- 阻止 run_phase 过早结束

## 2. 基本用法

```systemverilog
task run_phase(uvm_phase phase);
  phase.raise_objection(this);
  // do something
  phase.drop_objection(this);
endtask
```

## 3. 工作机制

- `raise_objection()`：计数 +1
- `drop_objection()`：计数 -1
- 当所有 objection 都为 0，run_phase 结束

## 4. 常见场景

### 4.1 test 中启动 sequence

```systemverilog
task run_phase(uvm_phase phase);
  phase.raise_objection(this);
  seq.start(env.agent.sqr);
  phase.drop_objection(this);
endtask
```

### 4.2 等待多个并行任务

```systemverilog
task run_phase(uvm_phase phase);
  phase.raise_objection(this);
  fork
    task1();
    task2();
  join
  phase.drop_objection(this);
endtask
```

## 5. 常见坑

- raise 了但忘了 drop，仿真永远不结束
- 只在 driver raise，但 test 早退出
- objection 加在错误组件上，导致层次混乱

## 6. 一句话总结

objection 就是 UVM 的“仿真刹车”，确保该跑的任务跑完之前，仿真不会提前收工。"""),
sv("""class my_test extends uvm_test;
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    #100ns;
    phase.drop_objection(this);
  endtask
endclass""")
])

write("uvm_analysis_imp.svmd", [
md("""# uvm_analysis_imp 详解

## 一句话总结

> **`uvm_analysis_imp` 是 analysis 通信的“最终接收口”，真正实现 write() 函数来处理广播来的 transaction。**

---

## 1. analysis_port / export / imp 的关系

```text
analysis_port -> analysis_export -> analysis_imp
```

- `analysis_port`：发送方
- `analysis_export`：中间转发口
- `analysis_imp`：真正实现接收逻辑的端口

## 2. 为什么需要 imp

因为最终总得有个地方真正实现：

```systemverilog
function void write(my_item t);
```

这个“真正实现”就落在 imp 上。

## 3. 基本写法

```systemverilog
class my_scoreboard extends uvm_scoreboard;
  uvm_analysis_imp #(my_item, my_scoreboard) analysis_export;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(my_item t);
    `uvm_info("SCB", "received item", UVM_LOW)
  endfunction
endclass
```

## 4. 一个组件多个 imp

当一个组件要同时接收两种不同来源的数据时，可以用多个 imp：

```systemverilog
uvm_analysis_imp_exp #(my_item, my_scoreboard) exp_export;
uvm_analysis_imp_act #(my_item, my_scoreboard) act_export;
```

然后分别实现：

```systemverilog
function void write_exp(my_item t);
function void write_act(my_item t);
```

## 5. 常见场景

- scoreboard 接收 expected/actual
- subscriber 接收 monitor 数据
- logger 接收 transaction 做打印

## 6. 一句话总结

`uvm_analysis_imp` 是 analysis 广播的“终点站”，真正实现接收和处理逻辑。"""),
sv("""class my_scb extends uvm_scoreboard;
  uvm_analysis_imp #(my_item, my_scb) analysis_export;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(my_item t);
    `uvm_info("SCB", $sformatf("addr=%h", t.addr), UVM_LOW)
  endfunction
endclass""")
])
