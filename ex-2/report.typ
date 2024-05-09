#import "../template.typ": *
#import "@preview/cetz:0.2.2" as cetz
#import "@preview/codelst:2.0.1" as codelst

#show: project.with(
  title: "并行程序设计第 2 次作业（POSIX Thread 编程）",
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

#let data-time(raw-data) = raw-data.enumerate().map(data => {
  let (i, data) = data
  (i + 1, data.sum() / data.len())
})
#let data-speedup(raw-data) = data-time(raw-data).map(data => {
  let time = data-time(raw-data)
  let (i, t) = data
  (i, time.at(0).at(1) / t)
})

#let data-table(raw-data) = table(
  columns: (auto, 1fr, 1fr, 1fr),
  table.header([*线程数量*], table.cell([*运行时间（单位：秒）*], colspan: 3)),
  ..raw-data.enumerate().map(e => {
    let (i, data) = e
    (str(i + 1), data.map(str))
  }).flatten()
)
#let data-chart(raw-data, width, height, time-max, speedup-max) = cetz.canvas({
  cetz.chart.columnchart(
    size: (width, height),
    data-time(raw-data),
    y-max: time-max,
    x-label: [_线程数量_],
    y-label: [_平均运行时间（单位：秒）_],
    bar-style: none,
  )
  cetz.plot.plot(
    size: (width, height),
    axis-style: "scientific-auto",
    plot-style: (fill: black),
    x-tick-step: none,
    x-min: 0,
    x-max: 17,
    y2-min: 1,
    y2-max: speedup-max,
    x-label: none,
    y2-label: [_加速比_],
    y2-unit: sym.times,
    cetz.plot.add(
      axes: ("x", "y2"),
      data-speedup(raw-data),
    ),
  )
})

= 实验：快速排序

== 实验内容与方法

使用 pthread 多线程编程实现快速排序算法的并行加速，并在不同线程数量下进行实验，记录运行时间并进行分析。
- 数组大小：2#super[29]
- 线程数量：1 \~ 16

在程序构造过程中，有以下要点：
+ 为记录排序时间，使用 POSIX 的 ```c gettimeofday()``` 函数；
+ 依据环境变量 `PTHREAD_NUM` 来决定线程数量；
+ 排序后检查数组是否有序。

代码如 @code:qsort-code 所示，其中 #lineref(<line:pthread-qsort-create>) 与 #lineref(<line:pthread-qsort-join>) 为 POSIX 线程创建与同步的代码行。

#figure(
  sourcecode(
    raw(read("qsort/qsort.c"), lang: "c"),
  ),
  caption: "并行快速排序 pthread 实现代码",
) <code:qsort-code>

== 实验过程

在如 @chapter:platform-info 所述的实验平台上进行实验，分别使用 1 至 16 个线程进行快速排序实验，记录运行时间，测定 3 次取平均值，原始数据如 @table:qsort-raw-data 所示。

== 实验结果与分析

#let qsort-speedup-max = data-speedup(data.qsort).sorted(key: speedup => speedup.at(1)).last()

快速排序实验测定的运行时间如 @figure:qsort-chart 中的条柱所示，并行加速比如 @figure:qsort-chart 中的折线所示，其中最大加速比在 CPU 数量为 #qsort-speedup-max.at(0) 时达到，最大加速比为 #qsort-speedup-max.at(1)。

可见随着线程数量的增加，运行时间逐渐减少，但在线程数量达到 10 后，运行时间几乎不再减少。这可能有多方面的因素：
+ 线程数量过多时，线程创建、同步、销毁的开销超过了并行计算的收益，导致运行时间增加。
+ 划分快速排序区间时，选择划分点不够均匀，线程负载不一致，导致部分线程空闲。

#figure(
  data-chart(data.qsort, 12, 8.5, 50, 4.4),
  caption: "快速排序运行时间",
) <figure:qsort-chart>

快速排序实验中的原始数据如 @table:qsort-raw-data 所示。

#figure(
  data-table(data.qsort),
  caption: "快速排序实验原始数据",
) <table:qsort-raw-data>

= 附注

== 编译与运行

代码依赖 POSIX 库，若未安装 POSIX 库，需手动安装。在准备好依赖后，可使用以下命令进行编译与运行：
- 编译：```sh make```；
- 运行：```sh make run```；
  - 可通过环境变量 ```PTHREAD_NUM``` 来指定线程数量，例如：```sh PTHREAD_NUM=8 make run```；
- 清理：```sh make clean```。

== 实验平台信息 <chapter:platform-info>

本实验所处平台的各项信息如 @table:platform-info 所示。

#figure(
  table(
    columns: (auto, 1fr),
    table.header([*项目*], [*信息*]),
    [CPU], [11th Gen Intel Core i7-11800H \@ 16x 4.6GHz],
    [内存], [DDR4 32 GB],
    [操作系统], [Manjaro 23.1.4 Vulcan（Linux 6.6.26）],
    [编译器], [GCC 13.2.1],
  ),
  caption: "实验平台信息",
) <table:platform-info>
