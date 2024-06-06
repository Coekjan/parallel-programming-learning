#import "../template.typ": *
#import "@preview/cetz:0.2.2" as cetz
#import "@preview/codelst:2.0.1" as codelst

#show: project.with(
  title: "并行程序设计第 4 次作业（CUDA 编程）",
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

#let data-time(raw-data) = raw-data.pairs().map(pair => {
  let (tpb, data) = pair
  (str(tpb), data.sum() / data.len())
})

#let data-chart(raw-data, width, height, time-max) = cetz.canvas({
  cetz.chart.columnchart(
    size: (width, height),
    data-time(raw-data),
    y-max: time-max,
    x-label: [_线程块内线程数量_],
    y-label: [_平均运行时间（单位：秒）_],
    bar-style: none,
  )
})
#let data-table(raw-data) = table(
  columns: (auto, 1fr, 1fr, 1fr),
  table.header([*线程块内线程数量*], table.cell([*运行时间（单位：秒）*], colspan: 3)),
  ..raw-data.pairs().map(pair => {
    let (tpb, data) = pair
    (str(tpb), data.map(str))
  }).flatten()
)

= 实验：矩阵乘法

== 实验内容与方法

使用 NVIDIA CUDA 异构编程接口实现矩阵乘法的并行加速，并在不同的线程配置下运行，记录运行时间并进行分析。
- 矩阵大小：8192 #sym.times 8192
- CUDA 配置（记各网格中线程块数量为 $B$、各线程块中线程数量为 $T$）：
  - 二维排布线程与线程块
  - 确保 $B times T = 8192$
  - 调整线程块中线程数量：2 \~ 32

程序构造过程中有如下要点：
+ 禁用 GPU 上的 FMAD 指令，避免浮点误差；
+ 依据环境变量 `THREADS_PER_BLOCK` 决定线程块中线程数量；
+ 编写 ```c cudaCheck()``` 宏函数检查 CUDA 函数调用的错误；
+ 为记录排序时间，使用 POSIX 的 ```c gettimeofday()``` 函数；
+ 为简要地记录矩阵乘法结果（双精度浮点阵列），使用 OpenSSL 的 SHA1 算法计算其指纹。

代码如 @code:matmul-code 所示，其中：
- #lineref(<line:cuda-kernel>) 定义了矩阵乘法在 CUDA 中的核函数；
- #lineref(<line:cuda-blk-th-1>)、#lineref(<line:cuda-blk-th-2>) 利用 CUDA API 获取线程块与线程的划分信息；
- #lineref(<line:cuda-malloc-1>)、#lineref(<line:cuda-malloc-2>)、#lineref(<line:cuda-malloc-3>) 在 GPU 上申请内存，#lineref(<line:cuda-free-1>)、#lineref(<line:cuda-free-2>)、#lineref(<line:cuda-free-3>) 释放 GPU 上的内存；
- #lineref(<line:cuda-memcpy-1>)、#lineref(<line:cuda-memcpy-2>)、#lineref(<line:cuda-memcpy-3>)、#lineref(<line:cuda-memcpy-4>)、#lineref(<line:cuda-memcpy-5>)、#lineref(<line:cuda-memcpy-6>) 在 CPU 与 GPU 之间进行数据传输；
- #lineref(<line:cuda-tpb>)、#lineref(<line:cuda-bpg-1>) 与 #lineref(<line:cuda-bpg-2>) 划分线程块与线程；
- #lineref(<line:cuda-matmul-1>)、#lineref(<line:cuda-matmul-2>)、#lineref(<line:cuda-matmul-3>) 与 #lineref(<line:cuda-matmul-4>) 调用 CUDA 核函数进行矩阵乘法；
- #lineref(<line:cuda-check-last-err>) 检查 CUDA 函数调用的错误；
- #lineref(<line:cuda-sync>) 同步核函数的执行。

#figure(
  sourcecode(
    raw(read("matmul/matmul.cu"), lang: "cpp"),
  ),
  caption: "并行矩阵乘法 MPI 实现代码",
) <code:matmul-code>

== 实验过程

在如 @chapter:platform-info 所述的实验平台上进行实验，分别使用 2、4、8、16、32 作为线程块中的线程数量，记录运行时间，测定 3 次取平均值，原始数据如 @table:matmul-raw-data 所示。

== 实验结果与分析

矩阵乘法实验测定的运行时间如 @figure:matmul-chart 所示。

可见，当线程块内线程数量较少时，GPU 内调度和同步开销大，导致性能显著下降，因为无法充分利用 CUDA 的并行计算能力；而当线程块内线程数量增多时，性能逐渐提升，并趋于稳定。

#figure(
  data-chart(data.matmul, 12, 8, 100),
  caption: "矩阵乘法运行时间",
) <figure:matmul-chart>

矩阵乘法实验中的原始数据如 @table:matmul-raw-data 所示。

#figure(
  data-table(data.matmul),
  caption: "矩阵乘法实验原始数据",
) <table:matmul-raw-data>

= 附注

== 编译与运行

代码依赖 NVIDIA CUDA 库（及其对应驱动）、OpenSSL 库，若未安装这些库，需手动安装。在准备好依赖后，可使用以下命令进行编译与运行：
- 编译：```sh make```；
  - 通过添加 `nvcc` 命令行选项 `--fmad=false` 来禁用 GPU 上的 FMAD 指令；
- 运行：```sh make run```；
  - 可通过环境变量 ```THREADS_PER_BLOCK``` 来指定线程块内线程数量，例如：```sh THREADS_PER_BLOCK=32 make run```；
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

== 实验平台信息 <chapter:platform-info>

#figure(
  table(
    columns: (auto, 1fr),
    table.header([*项目*], [*信息*]),
    [CPU], [11th Gen Intel Core i7-11800H \@ 16x 4.6GHz],
    [GPU], [NVIDIA GeForce RTX 3060 Laptop GPU],
    [内存], [DDR4 32 GB],
    [显存], [6 GB],
    [操作系统], [Manjaro 24.0.1 Wynsdey（Linux 6.6.32）],
    [CUDA], [12.4],
  ),
  caption: "实验平台信息",
) <table:platform-info>
