# impl_mask_lock 详细设计

## 状态与组合通路

N=NUM_REQ，IW=max(1,clog2(N))。状态为locked(1)、owner(IW)、next(IW)；
长度模式另有remaining(LEN_W)。所有状态异步复位至0；外部负责同步释放。
elig[i]=req[i]且(EOP模式或length[i]!=0)。masked[i]=elig[i]且i>=next。
两个复用的优先编码器产生g_all和g_mask；有masked时使用g_mask，否则g_all。
锁定时grant为owner的onehot，否则grant为候选；复位强制grant=0。
ready不参与grant选择，避免下游ready→选择→valid组合环。锁定时不重新检查length。
fire=ready且选中req；done=fire且(EOP模式选中eop，或长度模式有效remaining==1)。
未锁定时有效remaining取候选length，已锁定时取remaining寄存器。

## 沿更新优先级

| 条件（沿前） | locked/owner | next | remaining（仅长度模式） |
|---|---|---|---|
| reset | 0/0 | 0 | 0 |
| done，不论原先是否locked | 清locked；owner保留 | 选中索引+1，N-1时回0 | 0 |
| unlocked且有候选，未done | 置locked，保存候选索引 | 保留 | 候选length减去本沿fire |
| locked且fire且未done | 保留 | 保留 | 减1 |
| 其他 | 保留 | 保留 | 保留 |

done分支必须先于capture，保证单拍包第一次接受即完成，不遗留锁。
首拍背压仍capture，剩余拍数不减；包内req为0时保持，末拍eop在ready为0时不完成。
next更新不用取模运算，显式比较N-1并回绕；所有索引赋值显式IW位转换。
N=1索引固定0，长度1首次接受直接完成；最大长度2^LEN_W-1可完整表示。
长度0仅在未锁定仲裁时过滤，已锁定后的length变化不参与任何状态转移。

## 守恒与公平性论证

优先选择子模块输出互斥；二选一或onehot(owner)保持互斥。
除done/reset外不能改变locked owner，故不同包不交织；grant不等于fire，不会把空拍计入长度。
设采样长度L、已接受A，则锁定时remaining=L-A且1<=remaining<=L；
只在fire时递减，remaining=1的接受沿直接完成，排除下溢。reset丢弃未完成包是显式契约。
next仅在done更新到owner后继；连续eligible请求至多被N-1个其他完成包越过。
此为完成事件数上界，前提是owner和下游最终进展，不能推出周期上界。

## 验证与失效注入

独立TB用顺序扫描选请求、累计已接受拍数比较长度，避免复制RTL的双编码器/倒计数算法。
逐拍沿前核对grant，沿后状态由下一拍检查；驱动在negedge，禁止#1后的ready反推当前接受。
覆盖单拍、首末背压、泡泡、未选EOP、长度采样后变化、最大长度、N=1/非2幂、复位中断。
变异分别删除fire限定、错误轮转、提前计数完成；必须被checker捕获。
关键SVA反转应失败；单独关闭该属性后对同一故障的检测能力变化也记录。
消费者示例在每路附加序号，经真实数据mux校验接受数据、来源和顺序。

## PPA优化点（设计期PPA-E0结构推导，现已附真实表征）

状态位数EOP模式为1+2IW，长度模式另加LEN_W。编码器前缀网络单路
O(N log N)面积、O(log N)深度；两路并行后仅增加选择mux。
请求有效性（长度非零归约）与指针比较、编码、grant mux构成未锁定关键通路；
锁定通路短，仅owner解码/选中元数据和计数更新。计数器减法有LEN_W相关进位链。
理论上输出互斥选择至少需覆盖N输入；不声称综合一定保留原结构或达到特定频率。
EOP模式generate裁剪计数状态；next显式回绕避免除法；无寄存输出保留零延迟契约。
保留子层级综合，分别报告父/子面积贡献；不把子模块优化归为父级收益。
已探测PDK_READY；初始400MHz、TT角，扫描N=1/4/17/64与两模式，长度模式LEN_W=8，
并补LEN_W=1/16代表点。真实面积、setup slack、动态功耗及漏电由后续DC测量填入报告。
无SAIF时功耗仅为默认活动概率估计；单实现没有“最优微架构”比较结论。

验收结果：10点真实DC工艺绑定表征及Formality等价均通过，具体面积、
父子贡献、功耗和时序见[实测报告](../../reports/ppa-report.md)。全部报告路径为MET，
部分点余量接近显示精度，不能据此声称生产多角签核或额外频率裕量。
