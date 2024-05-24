#import "../template.typ": *
#import "@preview/cetz:0.2.2" as cetz
#import "@preview/codelst:2.0.1" as codelst

#show: project.with(
  title: "并行程序设计第 3 次作业（MPI 编程）",
  authors: (
    (name: "叶焯仁", email: "cn_yzr@qq.com", affiliation: "ACT, SCSE"),
  ),
)

#let data = toml("data.toml")
#let lineref = codelst.lineref.with(supplement: "代码行")
#let sourcecode = codelst.sourcecode.with(
  label-regex: regex("//!\s*(line:[\w-]+)$"),
  highlight-labels: true,
  highlight-color: lime.lighten(50%),
)

#let batch-of(s) = {
  let nodes = s.split("x").at(0)
  let proc-per-node = s.split("x").at(1)
  (int(nodes), int(proc-per-node))
}
#let data-time(raw-data) = raw-data.pairs().map(data => {
  let (batch, time) = data
  let (nodes, proc-per-node) = batch-of(batch)
  ((nodes, proc-per-node), time.sum() / time.len())
})
#let data-speedup(raw-data) = data-time(raw-data).map(data => {
  let pivot = data-time(raw-data).at(0).at(1)
  let (batch, time) = data
  (batch, pivot / time)
})
#let data-table(raw-data) = table(
  columns: (auto, 1fr, 1fr, 0.7fr, 0.7fr, 0.7fr),
  align: horizon + center,
  table.header(table.cell(rowspan: 2)[*进程数量*], table.cell(colspan: 2)[*分布情况*], table.cell(rowspan: 2, colspan: 3)[*运行时间（单位：秒）*], [*结点数*], [*进程数/结点数*]),
  ..raw-data.pairs().enumerate().map(pair => {
    let (index, pair) = pair
    let (batch, data) = pair
    let nodes = batch.split("x").at(0)
    let proc-per-node = batch.split("x").at(1)

    let num-proc = int(nodes) * int(proc-per-node)

    if index == raw-data.keys().enumerate().find(pair => {
      let (i, batch) = pair
      let (nodes, proc-per-node) = batch-of(batch)
      nodes * proc-per-node == num-proc
    }).at(0) {
      (
        table.cell(rowspan: raw-data.keys().filter(batch => {
          let (nodes, proc-per-node) = batch-of(batch)
          nodes * proc-per-node == num-proc
        }).len(), str(num-proc)),
        nodes,
        proc-per-node,
        data.map(str)
      )
    } else {
      (nodes, proc-per-node, data.map(str))
    }
  }).flatten()
)
#let data-chart(raw-data, width, height, time-max, speedup-max) = cetz.canvas({
  let color(index) = {
    let data = data-time(raw-data).at(index)
    let (batch, _) = data
    let (nodes, proc-per-node) = batch
    let procs = calc.log(nodes * proc-per-node, base: 2)
    (
      fill: (red, orange, yellow, blue, green, purple, lime).at(int(procs)),
    )
  }

  cetz.chart.columnchart(
    size: (width, height),
    data-time(raw-data).map(pair => {
      let (batch, time) = pair
      let (nodes, proc-per-node) = batch
      (rotate(-30deg)[
        #set text(size: 0.8em)
        #nodes#sym.times#proc-per-node
      ], time)
    }),
    y-max: time-max,
    x-label: [_结点数量 #sym.times 每结点的进程数量_],
    y-label: [_平均运行时间（单位：秒）_],
    bar-style: color,
  )
  cetz.plot.plot(
    size: (width, height),
    axis-style: "scientific-auto",
    plot-style: (fill: black),
    x-tick-step: none,
    x-min: 0,
    x-max: data-time(raw-data).len() + 1,
    y2-min: 1,
    y2-max: speedup-max,
    x-label: none,
    y2-label: [_加速比_],
    y2-unit: sym.times,
    cetz.plot.add(
      axes: ("x", "y2"),
      data-speedup(raw-data).enumerate().map(pair => {
        let (i, pair) = pair
        let (_, speedup) = pair
        (i + 1, speedup)
      }),
    ),
  )
})

= 实验：矩阵乘法

== 实验内容与方法

使用 MPI 编程实现矩阵乘法的并行加速，并在不同进程数量、不同结点数量下进行实验，记录运行时间并进行分析。
- 矩阵大小：8192 #sym.times 8192
- 矩阵分块算法：给定矩阵 $A$ 与 $B$，计算其乘积 $A B = C$，通过将 $A$ 按行分块来计算，如 @equation:block-matrix 所示。
  $
  A B = mat(A_1; A_2; dots.v; A_n) B = mat(A_1 B; A_2 B; dots.v; A_n B) = C
  $ <equation:block-matrix>
- 进程数量：1 \~ 64
- 结点数量：1 \~ 64

程序构造过程中有如下要点：
+ 计算 $A B$ 时，将 $A$ 按行分块而不是将 $B$ 按列分块，使得 MPI 分发数据（地址连续）时更加方便。
+ 如 @code:script-code 所示，利用脚本 ```bash matmul.slurm.run``` 指定结点数量与每个结点的进程数量，动态生成 Slurm 作业脚本，运行时指定形如 `SLURM_BATCH=AxB` 的环境变量，可指定 MPI 程序运行于 `A` 个结点、每个结点 `B` 个进程上。例如 ```sh SLURM_BATCH=4x4 ./matmul.slurm.run ``` 指定 MPI 程序运行于 4 个结点、每个结点 4 个进程，共 16 个进程上。
+ 为记录排序时间，使用 POSIX 的 ```c gettimeofday()``` 函数；
+ 为简要地记录矩阵乘法结果（双精度浮点阵列），使用 OpenSSL 的 SHA1 算法计算其指纹。

代码如 @code:matmul-code 所示，其中：
- #lineref(<line:mpi-init>)、#lineref(<line:mpi-rank>)、#lineref(<line:mpi-size>) 使用 MPI 进行了初始化、获取进程编号、获取进程数量等操作；
- #lineref(<line:mpi-bcast>) 将 $B$ 矩阵广播到所有进程；
- #lineref(<line:mpi-scatter-1>)、#lineref(<line:mpi-scatter-2>)、#lineref(<line:mpi-scatter-3>) 将 $A$ 矩阵分块分发到所有进程；
- #lineref(<line:mpi-gather-1>)、#lineref(<line:mpi-gather-2>)、#lineref(<line:mpi-gather-3>) 将 $C$ 矩阵收集到进程 0；
- #lineref(<line:mpi-finalize>) 结束 MPI。

#figure(
  sourcecode(
    raw(read("matmul/matmul.c"), lang: "c"),
  ),
  caption: "并行矩阵乘法 MPI 实现代码",
) <code:matmul-code>

== 实验过程

在如 @chapter:platform-info 所述的实验平台上进行实验，分别使用 1 \~ 64 个进程（分布在 1 \~ 64 个结点上）进行矩阵乘法，记录运行时间，测定 3 次取平均值，原始数据如 @table:matmul-raw-data 所示。

== 实验结果与分析

#let matmul-speedup-max = data-speedup(data.matmul).sorted(key: speedup => speedup.at(1)).last()

矩阵乘法实验测定的运行时间如 @figure:matmul-chart 中的条柱所示（相同颜色表示相同的总进程数），并行加速比如 @figure:matmul-chart 中的折线所示，其中最大加速比在结点数为 #matmul-speedup-max.at(0).at(0)、每结点的进程数为 #matmul-speedup-max.at(0).at(1) 时（总进程数为 #{matmul-speedup-max.at(0).at(0) * matmul-speedup-max.at(0).at(1)}）达到，最大加速比为 #matmul-speedup-max.at(1)。

#figure(
  data-chart(data.matmul, 12, 8, 600, 60),
  caption: "矩阵乘法运行时间",
) <figure:matmul-chart>

可见随着进程数量增加，运行时间逐渐减少。具体来说：
+ 随着总进程数量，运行时间逐渐减少，加速比呈现亚线性规律。加速比未呈现完全线性，可能是因为并行本身存在通信开销。
+ 总进程数相同时，进程在集群中的分布情况（结点数量）对运行时间有一定影响，例如：
  - 当总进程数为 16 时，将 16 个进程分散在 16 个结点上的运行时间较长；当总进程数为 64 时，将 64 个进程分散在 32 个结点（每结点 2 个进程）上的运行时间较长。这可能是因为进程在不同结点间通信时，网络延迟较大。
  - 当总进程数为 64 时，将 64 个进程分散在 64 个结点上的运行时间较短。这可能是因为集群中某种拓扑结构使得所分配的 64 个结点互联通信效率较高。

矩阵乘法实验中的原始数据如 @table:matmul-raw-data 所示。

#figure(
  data-table(data.matmul),
  caption: "矩阵乘法实验原始数据",
) <table:matmul-raw-data>

= 附注

== 编译与运行

代码依赖 MPI、OpenSSL 库，若未安装这些库，需手动安装。在准备好依赖后，可使用以下命令进行编译与运行：
- 编译：```sh make```；
- 运行：```sh make run ```；
  - 可通过环境变量 ```SLURM_BATCH``` 指定结点数量与每个结点的进程数量，例如 ```sh SLURM_BATCH=4x4 make run``` 指定 MPI 程序运行于 4 个结点、每个结点 4 个进程，共 16 个进程上。
  - 运行结束后若提示错误（检测到指纹错误），则说明运行结果不正确，该检测机制的大致逻辑由 @code:makefile-fingerprint 中的 Makefile 代码给出；
  #figure(
    sourcecode(
      ```make
      # The fingerprint of the result
      FINGERPRINT := 00 11 22 33 44 55 66 77 88 99 99 88 77 66 55 44 33 22 11 00

      # Run the program `app` and check the fingerprint
      .PHONY: run
      run:
        exec 3>&1; stdbuf -o0 ./app | tee >(cat - >&3) | grep -q $(FINGERPRINT)
      ```
    ),
    caption: "Makefile 中的指纹检测代码"
  ) <code:makefile-fingerprint>
- 清理：```sh make clean```。
  - 将编译产物、Slurm 脚本产生的输出文件全部清除。

其中 ```sh make run``` 实际调用了 ```sh matmul.slurm.run``` 脚本，如 @code:script-code 所示。

#figure(
  sourcecode(
    raw(read("matmul/matmul.slurm.run"), lang: "bash"),
  ),
  caption: "矩阵乘法运行脚本",
) <code:script-code>

== 实验平台信息 <chapter:platform-info>

本实验所处平台为北航校级计算平台，系统配置 260 个 CPU 计算节点，每个节点配置 2 颗 Intel Golden 6240 系列处理器（共 36 物理核）、384 GB 内存。所有节点通过 100Gb/s EDR Infiniband 互联组成计算和存储网络。系统使用 Slurm 作为作业调度系统。
