#import "../template.typ": *
#import "@preview/cetz:0.2.2" as cetz
#import "@preview/codelst:2.0.1" as codelst

#show: project.with(
  title: "并行程序设计第 1 次作业（OpenMP 编程）",
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

= 实验一：矩阵乘法

== 实验内容与方法

使用 OpenMP 并行编程实现矩阵乘法的并行加速，并在不同线程数量下进行实验，记录运行时间并进行分析。
- 矩阵大小：8192 #sym.times 8192
- 矩阵乘法算法：经典三重循环
- 线程数量：1 \~ 16

在程序构造过程中，有以下要点：
+ 为记录矩阵乘法计算时间（含 OpenMP 线程创建、同步、销毁开销），使用 OpenMP 的 ```c omp_get_wtime()``` 函数；
+ 依据环境变量 `OMP_NUM_THREADS` #footnote("https://www.openmp.org/spec-html/5.0/openmpse50.html") 来决定线程数量；
+ 为简要地记录矩阵乘法结果（双精度浮点阵列），使用 OpenSSL 的 SHA1 算法计算其指纹。

代码如 @code:matmul-code 所示，其中 #lineref(<line:omp-matmul>) 使用 OpenMP API 进行并行化。

#figure(
  sourcecode(
    raw(read("matmul/matmul.c"), lang: "c"),
  ),
  caption: "并行矩阵乘法 OpenMP 实现代码",
) <code:matmul-code>

== 实验过程

在如 @chapter:platform-info 所述的实验平台上进行实验，分别使用 1 至 16 个线程进行矩阵乘法实验，记录运行时间，测定 3 次取平均值，原始数据如 @table:matmul-raw-data 所示。

== 实验结果与分析

#let matmul-speedup-max = data-speedup(data.matmul).sorted(key: speedup => speedup.at(1)).last()

矩阵乘法实验测定的运行时间如 @figure:matmul-chart 中的条柱所示，并行加速比如 @figure:matmul-chart 中的折线所示，其中最大加速比在 CPU 数量为 #matmul-speedup-max.at(0) 时达到，最大加速比为 #matmul-speedup-max.at(1)。

可见随着线程数量的增加，运行时间逐渐减少，但在线程数量达到 8 时，运行时间几乎不再减少，甚至有所增加。这可能有多方面的因素：
+ 线程数量过多时，线程创建、同步、销毁的开销超过了并行计算的收益，导致运行时间增加。
+ 线程划分矩阵内存空间时，可能存在线程间共享 cache 行的情况，随着线程数量增加，cache 访问冲突增多，导致 cache 命中率降低，进而影响运行时间。

#figure(
  data-chart(data.matmul, 12, 8.5, 200, 6),
  caption: "矩阵乘法运行时间",
) <figure:matmul-chart>

矩阵乘法实验中的原始数据如 @table:matmul-raw-data 所示。

#figure(
  data-table(data.matmul),
  caption: "矩阵乘法实验原始数据",
) <table:matmul-raw-data>

= 实验二：正弦计算

== 实验内容与方法

使用 OpenMP 并行编程，利用泰勒展开 @equation:sine-taylor 实现任意精度正弦函数的计算，并在不同线程数量下进行实验，记录运行时间并进行分析。

$
sin (x) = x - x^3/3! + x^5/5! - ... + (-1)^n x^{2n+1}/(2n+1)! + ...
$ <equation:sine-taylor>

- $x$ 取值：0.2306212
- 计算泰勒展开项数：2#super[17]，即 131072
- 线程数量：1 \~ 16

程序构造过程中有如下要点：
+ 为实现任意精度的正弦函数计算，使用 GMP 库中的 ```cpp class mpf_class```；
+ 为避免重复计算阶乘、幂运算，同时为使线程的计算负载相当，在正式计算前，预先计算并存储阶乘、幂运算结果；
+ 为缓解分支预测错误，使用 ```cpp (1 - ((i & 1) << 1))``` 的方式来实现 $(-1)^i$；
+ 为记录正弦函数计算时间（含 OpenMP 线程创建、同步、销毁开销），使用 OpenMP 的 ```c omp_get_wtime()``` 函数；
+ 依据环境变量 `OMP_NUM_THREADS` #footnote("https://www.openmp.org/spec-html/5.0/openmpse50.html") 来决定线程数量；
+ 为简要地记录正弦函数计算结果（字符串），使用 OpenSSL 的 SHA1 算法计算其指纹。

代码如 @code:sincal-code 所示，其中 #lineref(<line:omp-fact-powx>) 与 #lineref(<line:omp-sincal>) 使用 OpenMP API 进行并行化。

#figure(
  sourcecode(
    raw(read("sincal/sincal.cpp"), lang: "cpp"),
  ),
  caption: "正弦函数计算 OpenMP 实现代码",
) <code:sincal-code>

== 实验过程

在如 @chapter:platform-info 所述的实验平台上进行实验，分别使用 1 至 16 个线程进行正弦函数计算实验，记录运行时间，测定 3 次取平均值，原始数据如 @table:sincal-raw-data 所示。

== 实验结果与分析

#let sincal-speedup-max = data-speedup(data.sincal).sorted(key: speedup => speedup.at(1)).last()

正弦计算实验测定的运行时间如 @figure:sincal-chart 中的条柱所示，并行加速比如 @figure:sincal-chart 中的折线所示，其中最大加速比在 CPU 数量为 #sincal-speedup-max.at(0) 时达到，最大加速比为 #sincal-speedup-max.at(1)。

可见随着线程数量的增加，运行时间逐渐减少，但在线程数量达到 8 时，运行时间几乎不再减少，甚至有所增加。这可能有多方面的因素：
+ 线程数量过多时，线程创建、同步、销毁的开销超过了并行计算的收益，导致运行时间增加。
+ 线程划分计算任务时，可能存在线程间共享 cache 行的情况，随着线程数量增加，cache 访问冲突增多，导致 cache 命中率降低，进而影响运行时间。

#figure(
  data-chart(data.sincal, 12, 8.5, 72, 6),
  caption: "正弦函数计算运行时间",
) <figure:sincal-chart>

正弦计算实验中的原始数据如 @table:sincal-raw-data 所示。

#figure(
  data-table(data.sincal),
  caption: "正弦计算实验原始数据",
) <table:sincal-raw-data>

= 附注

== 编译与运行

代码依赖 GMP、OpenSSL、OpenMP 库，若未安装这些库，需手动安装。在准备好依赖后，可使用以下命令进行编译与运行：
- 编译：```sh make```；
- 运行：```sh make run```；
  - 可通过环境变量 ```OMP_NUM_THREADS``` 来指定线程数量，例如：```sh OMP_NUM_THREADS=8 make run```；
  - 运行结束后若提示错误（检测到指纹错误），则说明运行结果不正确，该检测机制的大致逻辑由 @code:makefile-fingerprint 中的 Makefile 代码给出；
  #figure(
    sourcecode(
      ```make
      # The fingerprint of the result
      FINGERPRINT := 00 11 22 33 44 55 66 77 88 99 99 88 77 66 55 44 33 22 11 00

      # Run the program `app` and check the fingerprint
      .PHONY: run
      run:
          exec 3>&1; stdbuf -o0 ./app | tee >(cat - >&3) | grep -q "$(FINGERPRINT)"
      ```
    ),
    caption: "Makefile 中的指纹检测代码"
  ) <code:makefile-fingerprint>
- 清理：```sh make clean```。

== 实验平台信息 <chapter:platform-info>

本实验所处平台的各项信息如 @table:platform-info 所示。

#figure(
  table(
    columns: (auto, 1fr),
    table.header([*项目*], [*信息*]),
    [CPU], [11th Gen Intel Core i7-11800H \@ 16x 4.6GHz],
    [内存], [DDR4 32 GB],
    [操作系统], [Manjaro 23.1.4 Vulcan（Linux 6.6.19）],
    [编译器], [GCC 13.2.1（OpenMP 5.0）],
  ),
  caption: "实验平台信息",
) <table:platform-info>
