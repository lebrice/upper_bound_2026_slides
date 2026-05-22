// #import "../lib.typ": *
#import "./diatypst.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
// Could be nice to annotate code blocks:
// #import "@preview/codly:1.3.0": *
// #import "@preview/codly-languages:0.1.1": *


#show: slides.with(
  title: "Efficient Research with Slurm Compute Clusters", // Required
  subtitle: "Tips and Tricks from Mila's IDT team",
  date: "2026-05-22",
  authors: ("Fabrice Normandin"),
  // Optional Style Options
  title-color: purple.darken(50%),
  ratio: 25/14, // aspect ratio of the slides, any valid number
  layout: "medium", // one of "small", "medium", "large"
  toc: false,
  count: "dot-section", // one of "dot", "dot-section", "number", or none
  // count: "dot-section", // one of "dot", "dot-section", "number", or none
  footer: true,
  theme: "normal",
  footer-title: "Tips & tricks for efficient research with Slurm compute clusters",
  footer-subtitle: "Upper Bound 2026",
  // theme: "full", // one of "normal", "full"
  // ... see the docs for more options
)
#set heading(numbering: "1.1.a")
#import "@preview/suboutline:0.3.0": *
#show heading.where(level: 3): set heading(numbering: none)





== About Mila

#columns(2)[
  *AI Research Institute founded in 2018* to bring together researchers from local institutions, with Yoshua Bengio as scientific director,
   now Hugo Larochelle.

  #v(0.5em)
  #align(center)[
    #columns(2)[
    #image("images/slide12_pic04.jpg", width: 90%)
    #colbreak()
    #image("images/portrait-of-hugo-larochelle.png.webp", width: 90%)
    ]
  ]
  #colbreak()
  *Today*
  #v(0.5em)
  #table(
    columns: 2,
    stroke: none,
    align: (right, left),
    inset: (x: 6pt, y: 4pt),
    [*165*], [Professors],
    // Note about students:
    // 411 are Master's students (MSc)
    // 611 are PhD students
    // 193 are Professional Master's students (Maîtrise professionnelle)
    [*1358*], [Students],
    [*185*], [Employees
      - Admin / HR / Staff
      - Applied ML Research
      - IT support, IDT, Infra, BRDG
    ],
    [*176*], [Industry Partners],
    [*41*], [Startups founded by Mila researchers],
  )
]

== About our team (IDT)

*Innovation, Development and Technology*

- Help Researchers use compute resources efficiently
- Build software tools, documentation, tutorial sessions, in-person help

*About Me*:
Fabrice Normandin, Research #strike([Engineer])  Scientist 🎉
- Mila student turned staff (\~4 years ago).
- Office Hours, helped 200+ researchers (Optimize PyTorch/Jax code, use Slurm, scale up jobs, ...)
- Research background: GANs --> Continual Learning --> Deep RL / a bit of LLMs
- Current Goal: Build a very efficient ML research setup (à-la AutoResearch + Slurm) //for (myself and) Mila students!

#v(1cm)

This talk is *very biased* by my background and experience!

I _will_ miss things. Please share your own tips and tricks in the Q&A!


== About this presentation
#quote([
  Goal: Share some useful tips and tricks to increase your productivity and reduce friction in your research workflow with Slurm clusters.
])


Idea: Roughly organized as an _Adventure Book_!

--> *You get to (sometimes) pick where we go!* 😁

// - Organized as roughly follow a "_typical_" ML researcher's workflow
// - Sit back, relax, feel free to ask questions and share your input.
#align(horizon)[
#columns(2,
  [
    #colbreak()
    #align(center)[
    Slides + Code
    #linebreak()
    #image("images/github_qr_code.png", width:30%)
    #link("https://github.com/lebrice/upper_bound_2026_slides", "github.com/lebrice/upper_bound_2026_slides")
    ]
    // #align(center)[
    // Q&A with Slido
    // #linebreak()
    // #image("images/QR_Code_Slido.png", width:40%)
    // #link("https://app.sli.do/event/9c6SVnBwxftYKfCzfihNts", "app.sli.do/event/9c6SVnBwxftYKfCzfihNts")
    // ]
  ]
)]



#outline(title: "Topics")

== About _you_! <start>


// == Intended Audience
You _are_ a researcher in AI/ML at a Canadian university or company.

// You like VsCode.

Your goal is to beat the state of the art method on problem X in your sub-field of ML.

You have a decently-working way to do things, but you are curious about best practices.


#let choices(
  top_part: none,
  left_ref,
  left_title: "⏪ Go Left!",
  right_title: "Go right! ⏩",
  left_color: blue,
  left_desc,
  right_ref,
  right_desc,
  right_color: blue,
) = {
  align(horizon + center)[
    #top_part
    #columns(2)[
      #link(left_ref, rect(fill: left_color.lighten(90%), stroke: left_color)[
        #left_title
        #linebreak()
        #left_desc
      ])
      #colbreak()
      #link(right_ref, rect(fill: right_color.lighten(90%), stroke: right_color)[
        #right_title
        #linebreak()
        #right_desc
      ])
    ]
  ]
}


#let threechoices(
  top_part: none,
  left_ref,
  left_title: "⏪ Go Left!",
  left_color: blue,
  left_desc,
  mid_ref,
  mid_title: "⏬ Go Down!",
  mid_color: blue,
  mid_desc,
  right_ref,
  right_title: "Go right! ⏩",
  right_color: blue,
  right_desc,
) = {
  align(horizon + center)[
    #top_part
    #columns(3)[
      #link(left_ref, rect(fill: left_color.lighten(90%), stroke: left_color)[
        #left_title
        #linebreak()
        #left_desc
      ])
      #colbreak()
      #link(mid_ref, rect(fill: mid_color.lighten(90%), stroke: mid_color)[
        #mid_title
        #linebreak()
        #mid_desc
      ])
      #colbreak()
      #link(right_ref, rect(fill: right_color.lighten(90%), stroke: right_color)[
        #right_title
        #linebreak()
        #right_desc
      ])
    ]
  ]
}


#choices(<failure_end>, [
  It's too much trouble. Don't bother.
], <clusters>, [Find out more about these new clusters!], left_color: gray, top_part: [You hear that new compute clusters are available for researchers!

  It could very well help you get your results faster!]
)



// What this talk *is* about:
// - Using Slurm clusters efficiently
// - Tools / good practices / tips to reduc friction in your research workflow
// - Setting up for easy performance optimization


// What this talk is *not* about:

// - Low-level ML code optimization
// - Theory of parallelism / distributed training


// = Before we Begin

// == What is a Compute cluster, really? <switches>

// *Components*:
// - *Login Nodes*: submit jobs, edit code, transfer files. *Never run heavy workloads here!*
// - *Compute Nodes*: machines with GPUs/CPUs — these run your jobs
// - *Storage Servers*: shared distributed filesystem (Lustre, BeeGFS) accessible from all nodes
// - *Network Switches*: the fabric connecting nodes; placement affects inter-node bandwidth

// / TODO: Add a Diagram of a compute cluster

// Component Connection,Technology Standard,Typical Bandwidth (Current Gen)
// GPU ↔ GPU Memory,HBM3 / HBM3e,3.3 TB/s – 8.0 TB/s
// GPU ↔ GPU (Within Node),NVLink 4.0 / 5.0,900 GB/s – 1.8 TB/s
// GPU ↔ CPU,PCIe Gen 5 / NVLink-C2C,64 GB/s – 900 GB/s
// CPU ↔ System RAM,DDR5 / LPDDR5X,300 GB/s – 500 GB/s
// Node ↔ Node (Network),InfiniBand / 400G+ Ethernet,50 GB/s – 100 GB/s per NIC
// Node ↔ Local Storage,PCIe Gen 5 NVMe Arrays,14 GB/s – 60+ GB/s

// *Bandwidth hierarchy* (approximate):
// #table(
//   columns: (auto, auto),
//   stroke: none,
//   inset: (y: 3pt),
//   [GPU ↔ GPU (NVLink, same node)], [~600 GB/s],
//   [GPU ↔ CPU (PCIe, same node)],   [~32 GB/s],
//   [Node ↔ Node (InfiniBand)],       [~200 GB/s],
//   [Node ↔ Storage (network FS)],    [~10 GB/s],
// )

// #pagebreak()

// == Compute cluster basics?
// *Network Switches*: hierarchy — jobs across many switches pay extra latency. Use `sbatch --switches=1` to prefer one switch.

// *Distributed Filesystem*:
// - _Striped_ data → high throughput for large sequential reads
// - High _metadata latency_ on small files (each `open()` = network round-trip)
// - Avoid millions of tiny files — prefer `.tar` shards, HDF5, WebDataset, or `$SLURM_TMPDIR`
#pagebreak()
// #outline(title: none)

// = Introduction


// #choices(<failure_end>, [
//   It's too much trouble. Keep using your laptop.
// ], <clusters>, [Find more information on this new cluster!], top_part: []
// )


// - _Our job is to help researchers use the compute they have access to, this compute efficiently!_

// - Mila cluster has preemptible long jobs and limited non-preemptible short jobs.

= Connecting to Compute Clusters <connecting>

== Canadian Compute Clusters <clusters>

#let mila(name)  = (table.cell(fill: gray, text(fill: white, name)))
#let drac(name)  = (table.cell(fill: blue, text(fill: white, name)))
#let paice(name) = (table.cell(fill: yellow, name))

#table(
  stroke: 1pt,
  columns: 6,
  align: (auto, center, right, right, right, auto, auto),
  [Cluster],    [#underline("CPUs")], [GPU types], [#underline("H100 GPU-eq.")],[Storage],[Internet?],
  [#mila([Mila])],       [11k],    [A100, L40S, H100],    [\~500],   [2 PB],   [*Yes*],
  [#drac([Narval])],    [83k],     [A100],     [\~209],     [41 PB],  [No],
  [#drac([Rorqual])],    [138k],   [H100],     [372],     [*69 PB*], [No],
  [#drac([Fir])],        [175k],   [H100],     [640],     [51 PB],   [*Yes*],
  [#drac([Nibi])],       [141k],   [H100],     [288],     [25 PB],   [*Yes*],
  [#drac([Trillium])],   [*241k*], [H100],     [640],     [29 PB],   [No],
  [#paice([Tamia])],      [4k],     [H100, H200],[\~315],   [.7 PB], [No],
  [#paice([Killarney])],  [11k],    [L40S, H100],[\~652],   [2 PB],  [Yes?],
  [#paice([Vulcan])],     [16k],    [L40S],     [*\~858*], [5 PB],   [No],
)


// == Context

// / TODO: Add an image of struggling researcher.

//   Setting up access to compute clusters can be a bit annoying!


// #show outline.entry: it => link(
//   it.element.location(),
//   // Keep just the body, dropping
//   // the fill and the page.
//   it.indented(it.prefix()+[#h(0.5em)], it.body()),
// )
// #suboutline(title: "Connecting to Compute Clusters")

// *Section Outline*
// 1. milatools
// 2. mila code
// 3. SSH config entries
// 4. Typical researcher workflow at Mila

== milatools <milatools>

Small Python package by Mila's IDT team.

Install: `uv tool install milatools`, or `pip install milatools`

- `mila init`:
  - SSH config setup
  - Cluster access checks
  - Instructions for Mila/DRAC access

- `mila code --cluster=<cluster> [project_path] [--salloc resources]`

  #underline([Works with *_any_* Slurm cluster!])
  1. Requests interactive job (`salloc <resources>`)
  2. Waits for job to start
  3. Opens `project_path` in VSCode via Remote-SSH
  - Attach to a running job with `--job <job_id>`

== mila code <mila-code>

`mila code my_project --cluster=mila --salloc --gpus=1 --mem=16G --time=06:00:00`

  - Interactive job on Mila: 1 GPU, 16G RAM, 6h
  - Opens `my_project` in VSCode via Remote-SSH on the compute node


/ live demo: `mila code --cluster=mila --salloc --mem=8G --time=2:00:00`

== Useful SSH Config Entries <mila-cpu>

`mila init` creates the `mila-cpu` SSH host. `ssh mila-cpu`:
1. Connects to Mila
2. Finds a running `mila-cpu` job, or submits one with `sbatch`
3. Opens an interactive terminal attached to the job
4. Job persists 10 min after exit

```sshconfig
Host mila-cpu
  (...)
  ProxyCommand ssh mila "./milatools/slurm-proxy.sh mila-cpu --mem=8G"
  RemoteCommand ./milatools/entrypoint.sh mila-cpu
```

- Alternative to #ref(<mila-code>) for VSCode Remote-SSH
// - Can be modified for any cluster and resource type (e.g. `mila-gpu`, `tamia-cpu`, etc.)

/ live demo: `ssh mila-cpu`


== Result: Your new workflow

1. `mila code my_project --cluster=my_cluster --salloc --gpus=1 --mem=16G --time=06:00:00`

2. Develop iteratively in the VSCode terminal (running on the compute node)

3. Once ready, use `sbatch` to submit jobs

4. Same loop on other clusters: `--cluster=<cluster>`


#choices(
  <uv>,
  [Use UV to make your project work on all clusters],
  <slurm>,
  [Learn some neat Slurm tips and tricks],
  left_title: "⏪ Take the left road!",
  right_title: "Take the right road! ⏩",
  top_part: [
    You now have the _power_ to connect and do interactive development on a Slurm cluster.

    You are at a crossroads. Which road shall you take?
  ])


= Managing Python Projects (with uv)
// #suboutline(title: "Managing Python Projects")

== Python Projects Are Messy!


Ideal setup would work on all clusters.

Containers have a learning curve and are not that easy to use on Slurm clusters.


* In this section: *

1. Why uv ?
2. Example: uv + PyTorch
3. uv on DRAC clusters
4. Example: uv + Flash-Attention
5. Sneak-peek at `cluv` (ongoing work at Mila)

== Why uv? <uv>
#columns(2)[
#align(center)[
#image("images/uv.png")
]
#colbreak()


*A game-changer for Python projects!*

// Core commands:
- `uv init`
- `uv add / uv remove`
- `uv sync`
- `uv run <command>`



Useful flags:
- `--offline` (see #ref(<uv_on_drac>, supplement: "UV + DRAC"))
- `--directory` (see #ref(<code_checkpointing>))

Tip: avoid `uv pip` / `uv venv`

/ live demo! : `uv add torch`
]

== Example: uv + PyTorch

Dependency groups for different CUDA versions:


#columns(2)[
  #set text(
    size: 9pt
  )
  ```toml
  [project.optional-dependencies]
  cuda128 = ["torch==2.11.0+cu128"]
  cuda130 = ["torch==2.11.0+cu130"]

  [tool.uv]
  conflicts = [[{ extra = "cuda128" },
                { extra = "cuda130" }]]
  [tool.uv.sources]
  torch = [{index="torch-cuda128", extra="cuda128"},
           {index="torch-cuda130", extra="cuda130"}]

  [[tool.uv.index]]
  name = "torch-cuda128"
  url = "https://download.pytorch.org/whl/cu128"
  explicit = true
  [[tool.uv.index]]
  name = "torch-cuda130"
  url = "https://download.pytorch.org/whl/cu130"
  explicit = true
  ```
  #colbreak()

  ```bash
  uv sync --extra=cuda128
  uv sync --extra=cuda130
  ```

  - Multi-cluster setups with different CUDA versions (see #ref(<cluv>))


  #v(1cm)
  *But wait, can I use this on my cluster?*
]

== Using uv on DRAC Clusters <uv_on_drac>

Disclaimer : DRAC does *not* _currently_ support using uv on their clusters.

Tip: Use DRAC wheelhouse by default; PyPI only as needed:

#columns(2)[

  #set text(
    size: 6pt
  )
  ```toml
  [[tool.uv.index]]
  name = "drac-gentoo2023-x86-64-v3"
  url = "/cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/x86-64-v3"
  format = "flat"

  [[tool.uv.index]]
  name = "drac-gentoo2023-generic"
  url = "/cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/generic"
  format = "flat"

  [[tool.uv.index]]
  name = "drac-generic"
  url = "/cvmfs/soft.computecanada.ca/custom/python/wheelhouse/generic"
  format = "flat"
  default = true

  [[tool.uv.index]]
  name = "pypi"
  url = "https://pypi.org/simple"
  explicit = true
  ```
  #set text(size: 11pt)
  #colbreak()

  Some packages are only available as modules. Use `tool.uv.sources` to get them from PyPI:

  ```toml
  #pyproject.toml
  [tool.uv.sources]
  mpi4py = { index = "pypi" }
  opencv = { index = "pypi" }
  pyarrow = { index = "pypi" }
  rdkit = { index = "pypi" }
  ```
]


#set text( // reset to the original size.
  size: 11pt
)

#pagebreak()

// #set text(
//   size: 8pt
// )


Other approach: use the DRAC wheelhouse when convenient (for example, #ref(<uv-flash_attn>, supplement: `flash-attn`))

```toml
# pyproject.toml
[[tool.uv.index]]
name = "drac-gentoo2023-generic"
url = "/cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/generic"
format = "flat"
explicit = true

[tool.uv.sources]
# Use the pre-built wheel for flash-attn from the DRAC wheelhouse
flash-attn = { index = "drac-gentoo2023-generic" }
```

#pagebreak()

== Ongoing work at Mila: cluv <cluv>

From *Cl*~uster + *UV*: CLI to dispatch jobs and sync uv projects across Slurm clusters.

- Setup: `cluv login`, `cluv sync`, `cluv status`
- Run: `cluv run <cluster> <command>`
- Submit: `cluv submit <cluster> <job_script> [args]`
  - use `first` instead of `<cluster>` to dispatch to all clustes and keep first running job

// #image(https://docs.pytorch.org/tutorials/_static/img/profiler_rocm_chrome_trace_view.png)


/ live demo :
  ```bash
  cluv submit first scripts/job.sh -- python main.py --help
  ```

#align(right + horizon)[Learn more at https://github.com/mila-iqia/cluv]

#pagebreak()
#image("images/cluv.png")

== Result: Your new Python setup

- You already learned to use `mila code` to open a project on a cluster


- You now also _wield the power_ to use `uv` to manage your project dependencies!

#choices(
  <slurm>,
  "Learn some neat Slurm tricks!",
  <clean-code>,
  "Start writing some really clean ML code!",
  left_title: "Pick-up the magic tome and start reading 📚",
  right_title: "Skip ahead ⏩",
  top_part: [
  Your project is now setup properly! *You want to run some experiments!*

  On your journey, you find an intriguing tome. The inscription reads "Slurm Tips & Tricks".
]
)
// #align(horizon + center)[
// Your project is now setup properly!

// *You want to run some experiments!*
// ]

= Slurm Tips and Tricks <slurm>

// #show outline.entry: it => link(
//   it.element.location(),
//   // Keep just the body, dropping
//   // the fill and the page.
//   it.indented(it.prefix()+[#h(0.5em)], it.body()),
// )
// #suboutline(title: "Slurm Tips and Tricks")

== Slurm Tips and Tricks

#table(columns: (60%, auto), stroke: none,
[], [],
[
As you wander on the road, you encounter a strange man.

"_I am Olexa, arch-magus of Slurm clusters"_, he says.

He gives you three pieces of advice:

#quote([- _make your jobs *compact*,_
  - _make your jobs *flexible*_
  - _and make your jobs *short*!_

_Only then, will you be able to gather results in time for the next conference!_
])

You continue walking, slightly confused.

],
[
  #align(horizon + center)[
    #image("images/cluster_archmage.jpeg", width: 90%)
  ]
]
)
// == Slurm Tips and Tricks


// Your project is setup properly!
// *You want to run some experiments!*

// * In this section: *

// 1. Slurm Basics
//   - Reuse your job scripts!
//   - Checkpointing is a must!
//   - Graceful Preemption
//   - Code Checkpointing
// 2. `srun` is all you need!
//   - Easy Job Packing with `srun`
// 3. Faster Results // Short, Flexible jobs always win!
//   // - Use Job Dependencies to prevent waste
//   - Job Chunking: Short jobs always win!
//   - Flexible jobs always win!
//   - Use a Flexible Job Layout


== Slurm Basics

- *`sbatch`* `--ntasks=4 --gpus-per-task=1 --cpus-per-task=16 --mem=64G --time=3:00:00 job.sh`
  - batch job: requests resources to run _*tasks*_ / commands
- *`salloc`* `--ntasks=4 --gpus-per-task=1 --cpus-per-task=16 --mem=64G --time=3:00:00`
  - Interactive job, gives you a terminal on the compute node

- *`srun`* `python main.py`
  - Runs one or more _*tasks*_, (_commands_) inside a job
  - (Avoid using it to create jobs)

// #v()
// #align(end + horizon)[
// ⏩ I barely ever use `srun`, what's so great about it?
// ]

#pagebreak()
=== Reuse your job scripts <job_submission>

Editing the same script for lots of experiments is tedious.
One script per experiment → explosion of scripts.

*Solution:*

//  Generic `job.sh` + forward `"$@"`

#columns(2)[
  ```bash
  #!/bin/bash
  #SBATCH --time=01:00:00
  #SBATCH --gpus=1
  #SBATCH --cpus-per-task=4
  #SBATCH --mem-per-cpu=4G
  #SBATCH --output=logs/%j.out

  # (setup code)

  srun python main.py "$@"
  ```
  #colbreak()
  // In a terminal:
  ```console
  $ sbatch job.sh --lr=0.01
  $ sbatch job.sh --lr=0.001
  $ sbatch job.sh --lr=0.001 --nlayers=32
  ```
]


== Compact Jobs
=== `srun` is all you need!

`srun` is _*the*_ way to run commands in a Slurm job.

// Easily scale your jobs!
// - Launches on all the nodes, with the right env vars, partitions CPUs/GPUs/memory across tasks

/ Example:
  ```bash
  srun uv run python main.py --lr=0.01
  ```

// - Simple to use
- Easy job packing #ref(<job-packing>)
- Extremely flexible! #ref(<flexible_job_layout>)
// - Easy to scale distributed jobs!

_no need_ for `torchrun` / `accelerate launch` / etc!

// *Fancy tips*:
// - `--multi-prog`: allows different commands for each task (sweeps, coordinator/worker)

// - Super Niche: heterogeneous resources per task!
//     ```bash
//     srun -n1 -c8 --mem-per-cpu=2gb server : -n16 --mem-per-cpu=1gb client
//     ```

#align(end + horizon)[
⏩ How?
]

#pagebreak()
// == Compact Jobs
=== Easy Job Packing with srun <job-packing>

Need to run lots of jobs, but each job does not use all the GPU memory!


*Run multiple seeds*
  - ```bash
  srun --ntasks-per-gpu=4 uv run python main.py
  ```
  - ```python
  seed = int(os.environ["SLURM_PROCID"])
  ```

#pagebreak()

=== Different commands per task with `srun --multi-prog`
// #footnote([
See #link("https://slurm.schedmd.com/srun.html#OPT_multi-prog", [`srun` documentation]) for more info!
// ])
// *Different commands per task with`srun --multi-prog`!*

  ```text
  # task_commands.txt
  0-1 python train.py --seed=%o --lr=0.01
  2-3 python train.py --seed=%o --lr=0.001
  ```

  ```bash
  srun --ntasks=4 --ntasks-per-gpu=4 --multi-prog task_commands.txt --batch-size=128
  ```
```bash
python train.py --seed=0 --lr=0.01 --batch-size=128
python train.py --seed=1 --lr=0.01 --batch-size=128
python train.py --seed=0 --lr=0.001 --batch-size=128
python train.py --seed=1 --lr=0.001 --batch-size=128
```

// #align(end + horizon)[
// ⏩ Won't this be difficult to manage with lots of commands?
// ]

== Flexible Jobs <flexible_job_layout>
// Use a Flexible Job Layout
Large jobs can take a long time to schedule!
➡️ Flexible job layout → faster scheduling!

#let computenode(
  // ..free,
  free0, free1, free2, free3) = {
  rect(width: auto)[
    #table(
      align:(auto, auto, auto, auto),
      columns: 4,
      rotate(-90deg, reflow: true, rect([GPU 0], fill: (if free0 {white} else {gray.lighten(10%)} ))),
      rotate(-90deg, reflow: true, rect([GPU 1], fill: (if free1 {white} else {gray.lighten(10%)} ))),
      rotate(-90deg, reflow: true, rect([GPU 2], fill: (if free2 {white} else {gray.lighten(10%)} ))),
      rotate(-90deg, reflow: true, rect([GPU 3], fill: (if free3 {white} else {gray.lighten(10%)} ))),
      stroke: 1pt,
    )
    #columns(2)[#rect[CPUs]#colbreak() #rect[RAM]]
  ]
}


// #align(center)[
//   #fletcher.diagram(
//     node-stroke: 0.8pt,
//     spacing: (0.2em, 1em),
//     node((0, 0), [#computenode(true, true, true, true)], shape: rect),
//     node((2, 0), [#computenode(true, true, true, true)], shape: rect),
//     node((4, 0), [#computenode(true, true, true, true)], shape: rect),
//     node((6, 0), [#computenode(true, true, true, true)], shape: rect),
//     node((1, 1), [Switch 1], fill: orange.lighten(60%), shape: rect),
//     node((5, 1), [Switch 2], fill: orange.lighten(60%), shape: rect),
//     edge((0, 0), (1, 1), "-"),
//     edge((2, 0), (1, 1), "-"),
//     edge((4, 0), (5, 1), "-"),
//     edge((6, 0), (5, 1), "-"),
//     edge((1, 1), (5, 1), "-", label: [inter-switch]),
//   )
// ]



#columns(4)[
#computenode(true, false, false, true) #colbreak()
#computenode(false, true, true, true) #colbreak()
#computenode(true, false, false, false) #colbreak()
#computenode(true, false, true, true)
]

#v(10%)
// #rect([
//   #columns(4)[
//     #rect() #colbreak()#rect() #colbreak()#rect() #colbreak()#rect()
//   ]
// ])

// *Suggestion*


- From: `sbatch --nodes=2 --gpus-per-node=4 job.sh`

- To: `sbatch `*`--nodes=1-4 --switches=1 --ntasks=8 --gpus-per-task=1`*` job.sh`
  - 8 GPUs across 1-4 nodes, prefer one network switch // (see #ref(<switches>, supplement: "switches"))


#v(3em)

// *Recommendations*:
// - use `sbatch --switches=1@3600` and monitor training throughput (with e.g. #ref(<wandb>))
// - Goal: optimize time-to-result! (queue time + runtime)


== Use Short Jobs / Job _Chunking_

=== Checkpointing is a must <checkpointing>

Proper checkpointing is *crucial*. It enables:
- Long jobs on preemptible clusters (e.g. Mila)
- Job chunking (#ref(<job_chunking>))
- Resilience to hardware/software failures

- *Tip*: #link("https://docs.pytorch.org/tutorials/recipes/distributed_checkpoint_recipe.html", [Distributed Checkpointing]) for large multi-GPU models
  - More: #ref(<efficient-checkpointing>) and the TorchTitan talk at Upper Bound 2026
  - "Async" mode overlaps checkpointing with training

#pagebreak()
=== Graceful Preemption <graceful_preemption>

// On preemptible clusters (e.g. Mila), Slurm sends a signal *before* killing your job. Catch it, checkpoint, exit cleanly.

```bash
#!/bin/bash
#SBATCH --signal=B:USR1@60   # send SIGUSR1 60s before timeout/preemption
#SBATCH --requeue            # auto-resubmit after preemption
srun uv run python train.py "$@"
```

```python
import signal
def _on_preempt(signum, frame):
    save_checkpoint(model, optimizer, step)   # final flush
    sys.exit(0)                                # exit 0 → Slurm requeues cleanly
signal.signal(signal.SIGUSR1, _on_preempt)
```

// - Pairs with #ref(<checkpointing>): you _*must*_ have a working checkpoint path first
// - `--requeue` + an `id` derived from `SLURM_JOB_ID` (see #ref(<wandb>)) → seamless resumption


// == Short jobs always win!
#pagebreak()
=== Easy job chunking with job arrays <job_chunking>


With #ref(<checkpointing>, supplement:"checkpointing"), break long jobs into chunks → schedule faster, results sooner.

Chunking with job arrays and `%1` (`%1` := only one job in the array can be running at a time):

```bash
#!/bin/bash
#SBATCH --array=1-5%1
#SBATCH --time=03:00:00
#(...)

# Consider `SLURM_ARRAY_JOB_ID` (id of first job in the array)
# as the "Job ID" for all jobs in this array.
# For example, for WandB:
export WANDB_RUN_ID=$SLURM_ARRAY_JOB_ID
srun uv run "$@"
```



#pagebreak()
=== Job chunking with Job Dependencies

// Alternative approach using job dependencies:


```bash
#!/bin/bash
# Job Chain Example
num_chunks=5
jobid=$(sbatch --parsable --time=03:00:00 job.sh "$@")
for i in $(seq 2 $num_chunks); do
    jobid=$(sbatch --parsable --dependency=afterok:$jobid --kill-on-invalid-dep=yes
            --time=03:00:00 job.sh "$@")
done
```

And in Python:
```python
previous_job_id = int(os.environ["SLURM_JOB_DEPENDENCY"].removeprefix("afterok:"))
```


== Result: Slurm tips & Tricks

In addition to being able to connect and run code interactively on a compute node, and manage your Python project with uv,

*You are now able to submit jobs that are Compact, Flexible, and Short!*

Your jobs get scheduled much faster.
Things are looking up!

#threechoices(
  <debugging-profiling>,
  [Run and Debug the code to understand it better],
  <clean-code>,
  [
    Clean-up the code, make it nice and readable
  ],
  <testing>,
  [Write some tests before doing anything],
  mid_title: "⏫ Go Up!",
  top_part: [
    We just received some confusing baseline code from a colleague.

    It sort-of works, maybe? You're not sure.
  ],
)






= Libraries for Cleaner ML Code <clean-code>

// #show outline.entry: it => link(
//   it.element.location(),
//   // Keep just the body, dropping
//   // the fill and the page.
//   it.indented(it.prefix()+[#h(0.5em)], it.body()),
// )
// #suboutline(title: "Writing Cleaner ML Code")

== Libraries for Cleaner ML Code

ML code can be very hard to read and write!

"ML code" := tensor logic, neural networks, etc

A small taster of some libraries that make ML code much nicer to read and write:


- Einops
- Tensordict
- Jaxtyping


Misc.:
- Config Management / Argument Parsing
- Weights and Biases


// == What to do?
// You want to start a new project. How do you go about doing it?

== Make code readable with Einops <einops>

Works with PyTorch / Jax / Numpy / etc!

// *Problem*: `reshape` / `permute` / `view` chains are cryptic and error-prone

// *Solution*: `einops` — tensor ops as named axes

// Example: patchifying an image batch (ViT)

#set text(size: 9pt)

#columns(2)[

  // Without einops:
  ```python
  import torch

  def patchify(images: torch.Tensor, p: int):
      B, C, H, W = images.shape
      x = images.reshape(B, C, H // p, p, W // p, p)
      x = x.permute(0, 2, 4, 3, 5, 1).contiguous()
      x = x.reshape(B, (H//p) * (W//p), p*p*C)
      return x
  ```
  #colbreak()

  // With einops:
  ```python
  from einops import rearrange

  def patchify(images: torch.Tensor, p: int):
      return rearrange(
          images,
          "b c (h p1) (w p2) -> b (h w) (p1 p2 c)",
          p1=p, p2=p,
      )
  ```
]

#set text(size: 11pt)

#pagebreak()

Also useful:

- `einops.reduce(x, "b c h w -> b c", "mean")`
- `einops.repeat(x, "h w -> h w c", c=3)`
- `einops.einsum`
- Layers: `Rearrange`, `Reduce`, `EinMix` (drop in `nn.Sequential`)

Docs: https://einops.rocks/.

#align(end + horizon)[
⏩ Pairs beautifully with #ref(<jaxtyping>)!
]


== Make code readable and modular with TensorDict

```python
from tensordict import TensorDict

data = TensorDict(
    obs=torch.randn(128, 84),
    action=torch.randn(128, 4),
    reward=torch.randn(128, 1),
    batch_size=[128],
)

data_gpu = data.to("cuda")      # all tensors move together
sub = data_gpu[:64]              # all tensors are sliced
stacked = torch.stack([data, data])  # works like a tensor
```
#align(right + horizon)[
https://docs.pytorch.org/tensordict/stable/index.html
]


== Make code readable and modular with tensorclass


```python
from tensordict import tensorclass
import torch

@tensorclass
class MyData:
    x: torch.Tensor
    y: torch.Tensor
```

#align(right + horizon)[
https://docs.pytorch.org/tensordict/stable/reference/generated/tensordict.tensorclass.html
]


== Make code explicit with Jaxtyping <jaxtyping>

Works with Jax / PyTorch / NumPy.
// Shape + dtype in tensor type hints.

#set text(size: 9pt)
```python
from jaxtyping import Float, Integer
from torch import Tensor

def matrix_multiply(
  x: Float[Tensor, "A B"],
  y: Float[Tensor, "B C"]
) -> Float[Tensor, "A C"]:
    return x @ y

Image = Float[jax.Array, "C H W"]
Images = Float[Image, "B"] # --> Float[jax.Array, "B C H W"]
Labels = Integer[jax.Array, "B"]

@dataclass
class Batch:
    x: Images
    y: Labels
```
#set text(size: 11pt)

#pagebreak()

Checks an be enforced at runtime with `beartype` or `typeguard`:


For example while running tests (See #ref(<testing>))

```toml
#pyproject.toml
[tool.pytest.ini_options]
addopts = "--jaxtyping-packages=my_project,beartype.beartype"
```

Also handy as an inline shape check:

```python
assert isinstance(output, Float32[Tensor, "3 128 128"])
```

#pagebreak()

Annotations can reference function arguments or module attributes!

#set text(size: 9pt)

```python
class MLP(nn.Module):
    def __init__(self, in_dims: int, out_dims: int):
        super().__init__()
        self.in_dims = in_dims
        self.out_dims = out_dims
        ...

    def forward(self, input: Float[Tensor, "b {self.in_dims}"]) -> Float[Tensor, "b {self.out_dims}"]:
        return self.linear2(self.activation(self.linear1(input)))
```
#set text(size: 11pt)

== Bringing it all together!
```python
from tensordict import tensorclass
from jaxtyping import Float, Integer
from torch import Tensor

Image = Float[Tensor, "c h w"]
Images = Float[Image, "b"] # --> Float[Tensor, "b c h w"]
Labels = Integer[Tensor, "b"]

@tensorclass
class Batch:
    x: Images
    y: Labels


def patchify(images: Float[Tensor, "b c h w"], p: int,
) -> Float[Tensor, " b (h/{p})*(w/{p}) ({p}*{p}*c)"]:
    return rearrange(images, "b c (hp p1) (wp p2) -> b (hp wp) (p1 p2 c)", p1=p, p2=p)
```


== Extra: Config / Argument Parsing

Recommendations, from simplest to most complex


*Simple-Parsing*: https://github.com/lebrice/SimpleParsing
  - Simplest, neatly-typed (based on Dataclasses). Simple extension of argparse. (Also, made by me)


*Tyro CLI*: https://github.com/brentyi/tyro
- Same idea. More widely used (not as flexible, but good enough)


*Hydra*: https://hydra.cc
  - More complex, used a lot in combination with the Submitit launcher (really not great).
  - Steep learning curve, quite heavy, poorly/unmaintained.
  - *Avoid using Hydra* unless you really have lots of datasets / models to run, over more than one project.

Lots of other great options!


== Slurm & Weights & Biases (WandB) <wandb>


#link("https://wandb.ai", "WandB") is amazing! Consider trying it!

*Tips*:
- Save Slurm environment variables in the WandB config! Very useful for debugging later.
- Use `resume: allow` and an `id` based on Job ID to easily resume runs, or for #ref(<job_chunking>, supplement: "job chunking")

#set text(size: 9pt)
```python
import os
import wandb
run = wandb.init(
    name=os.environ.get("SLURM_JOB_ID"),
    id=os.environ.get("SLURM_JOB_ID"),
    resume="allow",
    config=vars(args) | {
        "env": {k: v for k, v in os.environ.items() if k.startswith("SLURM_")}
    }
)

for batch in dataloader:
    loss, acc = training_step(batch)
    wandb.log({"train/loss": loss, "train/acc": acc})
```
#set text(size: 11pt)


#pagebreak()

*Tip*: Combine with #ref(<job-packing>, supplement: "job-packig with `srun`") to easily group multiple seeds per run!

```python
import os
import wandb
JOB_ID=os.environ["SLURM_JOB_ID"]
TASK_ID=os.environ["SLURM_PROCID"]
run = wandb.init(
  id=f"{JOB_ID}_{TASK_ID}",  # unique run ID per task
  name=f"{JOB_ID}_{TASK_ID}",
  group=JOB_ID, # group by job ID (e.g. all seeds in the same job are grouped together)
  resume="allow",
  config=vars(args) | {
    "env": {k: v for k, v in os.environ.items() if k.startswith("SLURM_")}
  }
)
```

#pagebreak()

*No internet on compute nodes?* Log offline, sync later:

```bash
export WANDB_MODE=offline
export UV_OFFLINE=1
srun uv run python train.py        # logs to ./wandb/run-*/
```
Later, from the login node:
```
wandb sync --sync-all
```

Or in code: `wandb.init(mode="offline")`.


⏩ Next up: Testing for ML Code!


= Testing for ML code <testing>

== Why/How to do testing for ML code?

Testing is the *safety net* that allows you to experiment freely.

You already _do_ testing!

- Run small experiments to check that things are working.

- Use successively more difficult (and compute-intensive) problems:
  - Vision: MNIST → CIFAR10 → CIFAR100 → ImageNet → ...
  - RL: CartPole → Atari → Craftax → ...
  - NLP: WikiText → ... → C4 → The Pile → ...

- Common sanity-checks in ML:
  - *Overfitting test*
    - Also works in RL!
  - Checkpoint / resuming
  - 1 / 2 / 4 GPUs, multi-node

#align(right + horizon)[
⏩ *How to write such tests in practice?*
]

== Simple Testing for ML

From a description:
#quote(["My model should be able to reach 95% accuracy on MNIST in 3 epochs of training, in less than 10 seconds."])


#align(horizon)[
To an implementation:
```python
@pytest.mark.timeout(10)  # Fails if test takes more than 10 seconds.
def test_train_mnist():
    train_dataset, test_dataset = MNIST(train=True), MNIST(train=False)
    model = make_model(input_size=28, num_classes=10, seed=42)
    trained_model = train_model(model, train_dataset, epochs=3)
    accuracy = evaluate(trained_model, test_dataset)
    assert accuracy > 0.95
```
]

== Reproducibility testing <tensor-regression>

// From a description:
#quote(["Given the same seed, my model should always have the same initial weights and state."])


```python
import pytest
from my_project import make_model

@pytest.mark.parametrize("seed", [42])
def test_initialization_is_reproducible(seed: int, tensor_regression):
    model = make_model(seed=seed)
    tensor_regression.check(model.state_dict())
```


*#link("https://github.com/mila-iqia/tensor_regression", "github.com/mila-iqia/tensor_regression")*

Based on #link("https://github.com/ESSS/pytest-regressions", "pytest-regressions")
- Saves tensor stats (shape, dtype, min/max/mean) in a git-committed `.yaml`
- Test fails if stats differ or the file is missing (generate with `--gen-missing` / `--regen-all`)


#pagebreak()

#set text(size: 9pt)
```python
import pytest
from my_project import make_model

@pytest.mark.parametrize("seed", [42])
def test_train_step_is_reproducible(seed: int, tensor_regression):
    model = make_model(seed=seed)
    dataloader = DataLoader(SomeDataset(), ...)
    batch = next(iter(dataloader))

    model.zero_grad()
    loss = model.training_step(batch)
    loss.backward()
    model.optimizer_step()

    tensor_regression.check({
      "batch": batch,
      "loss": loss,
      "model_state": model.state_dict()
    )
```
#set text(size: 11pt)

== Example: Test-Driven Debugging of PyTorch Code

Custom PyTorch op with hand-written fwd/bwd: works at batch=16, CUDA OOMs at batch=128.

*Step 1*: Pin the forward/backward passes with a test:

#set text(size: 9pt)

```python
@pytest.mark.parametrize("batch_size", [16, 128])  # works for 16, blows up for 128
def test_custom_op_forward_backward(tensor_regression, batch_size: int):
    x = torch.randn(batch_size, 128, dtype=torch.float64, requires_grad=True, device="cuda")
    out = MyCustomOp.apply(x)
    loss = out.sum()
    loss.backward()
    tensor_regression.check({
        "input": x,
        "output": out,
        "input_grad": x.grad,
    })
```

#set text(size: 11pt)

*Step 2*: Iterative debug/optimize — instantly know if you break fwd/bwd!

== Result: Testing for ML

You are now able to write tests for your ML code!


Some of you might even consider writing tests _*before*_ writing algorithms!
(Some of you would be right!)

#align(horizon)[
You wrote some tests for your ML code. All is well.

However, as you keep working, you encounter some unexpected behaviour!

#align(right)[
⏩ Next up: _How to debug this?_
]
]

= Debugging & Profiling <debugging-profiling>

#show outline.entry: it => link(
  it.element.location(),
  // Keep just the body, dropping
  // the fill and the page.
  it.indented(it.prefix()+[#h(0.5em)], it.body()),
)
#suboutline(title: "Debugging & Profiling")

== Debugging Multi-GPU Jobs with VSCode

(PyTorch) VSCode Debugger + `torchrun`:

#set text(size: 9pt)

```json
{
  "configurations": [
    {
      // Loosely based on https://medium.com/@franoisponchon/pytorch-ddp-debugging-in-vscode-4fb162eba07e
      "name": "Debug job with torchrun (Single-node)",
      "type": "debugpy",
      "request": "launch",
      // we launch a module...
      "module": "torch.distributed.run",
      // with args...
      "args": "--nproc_per_node=${input:NumGPUs} ${file} ${command:pickArgs}",
      "console": "integratedTerminal",
      "justMyCode": false
    }
  ]
}
```

#set text(size: 11pt)

== Debugging Multi-Node Jobs with VSCode

`debugpy` per task on a unique port, then attach VSCode:

```bash
# job.sh — each task listens on a different port (5678, 5679, …)
srun python -m debugpy --listen 0.0.0.0:$((5678 + SLURM_PROCID)) \
    --wait-for-client main.py
```

```json
// .vscode/launch.json
{ "configurations": [
    { "type": "debugpy", "request": "attach", "name": "Attach debugger to running task",
      "connect": { "host": "${input:NodeHostname}", "port": "${input:DebugpyPort" } },
  ],
}
```

Full VSCode launch config: https://github.com/lebrice/mila-docs/blob/8919d6a352e7c6f3ec0c99441571400848ce8ae5/docs/examples/advanced/imagenet/.vscode/launch.json

== Profiling with TensorBoard + Torch Profiler

Basic setup:

```python
import torch
from torch.profiler import profile, tensorboard_trace_handler, schedule

with profile(
    schedule=schedule(wait=1, warmup=1, active=5),
    on_trace_ready=tensorboard_trace_handler("./log/profiler", worker_name=f"rank_{RANK}"),
    record_shapes=True,
    with_modules=True,
    profile_memory=True,
    with_flops=True,
) as prof:
    for batch in dataloader:
        train_step(batch)
        prof.step()   # <-- must call this every step
```

#pagebreak()

```bash
uvx --with=torch-tb-profiler tensorboard --logdir=logs
```
#align(center)[
#image("images/tensorboard_torch_profiler.png", width: 70%)
]

// Browser view shows:
// - GPU utilization timeline (spot idle gaps!)
// - Kernel-level breakdown
// - Memory usage over time
// - Operator-level stack traces

VSCode auto-forwards the port → localhost:6006 (with #ref(<mila-code>))


#pagebreak()
== Live Demo : Debugging & Profiling with VSCode

/ DEMO :

  Interactive demo (`mila code` + Debugging with VsCode + Profiling with TensorBoard + Torch Profiler)


// == Understanding Hardware is Critical!

// // Bandwidth hierarchy across a typical GPU compute cluster node and between nodes.
// #align(center)[
//   #fletcher.diagram(
//     node-stroke: 0.8pt,
//     spacing: (2.5em, 3em),

//     // --- Node 1 ---
//     node((0, 0), [GPU 0], fill: blue.lighten(70%)),
//     node((2, 0), [GPU 1], fill: blue.lighten(70%)),
//     edge((0, 0), (2, 0), "<->", label: [~600 GB/s (NvLink)]),
//     node((1, 1), [CPU + RAM], fill: green.lighten(70%)),
//     edge((0, 0), (1, 1), "<->", label: [~32 GB/s (PCIe)]),
//     edge((2, 0), (1, 1), "<->"),

//     // --- Node 2 ---
//     node((4, 0), [GPU 2], fill: blue.lighten(70%)),
//     node((6, 0), [GPU 3], fill: blue.lighten(70%)),
//     edge((4, 0), (6, 0), "<->", label: [~600 GB/s (NvLink)]),
//     node((5, 1), [CPU + RAM], fill: green.lighten(70%)),
//     edge((4, 0), (5, 1), "<->"),
//     edge((6, 0), (5, 1), "<->", label: [~32 GB/s (PCIe)]),

//     // --- Inter-node ---
//     edge((1, 1), (5, 1), "<->", label: [~200 GB/s (NvMesh / Infiniband)]),
//   )
// ]


// == Job Packing


= Thank You!

== Thank You!
#align(center)[
    Slides + Code
  #linebreak()
  #image("images/github_qr_code.png", width:30%)
  #link("https://github.com/lebrice/upper_bound_2026_slides", "github.com/lebrice/upper_bound_2026_slides")
]


== 🎉 Success! 🎉 <success_end>

You were able to submit all the jobs required for your experiments!

- Your jobs were compact, short, efficient
- Your code was clean, nicely-typed, well-tested
- You feel confident, you own your code, you already have ideas for what to do next!

You can expect good results at the next conference cycle! 😉
🎉

== 😢 Oh No! <failure_end>

Unfortunately, one of these happened:

- your jobs spent a lot of time in the queue and did not run fast enough.
- your code was impossible for anyone else to understand, so you worked alone
- Your results were inconclusive or unreproducible.

You are not sure what went wrong, but you really want to try better next time.

#align(center + horizon)[
  #link(<start>, rect(fill: blue.lighten(90%), stroke: blue)[
          Try again!
          #linebreak()
    ]
  )
]


= Extras (overflow slides)

#suboutline(title: "Extras")




== (!!) Run tests with GitHub CI + Slurm Clusters <github_ci_slurm>

// (Possibly unique, never seen this done before).

1. Self-hosted GitHub Runner on a machine with SSH access to the cluster
2. PR workflow is approved by maintainers → runner submits via `ssh <cluster> sbatch`
3. Job spawns an *ephemeral GitHub Runner* on a GPU compute node → runs tests → results appear on GitHub!

#align(center)[
  #image("images/github_ci_example.png", width: 90%)
]

#align(right)[Example: #ref(<research_template>)]

#pagebreak()

1. Isn't this a security risk?
  - Somewhat — but maintainers must approve PR workflows, and the runner acts as the user with no extra permissions

2. MFA?
  - SSH multiplexing (reuse an authenticated session — hacky but works), or robot SSH keys restricted to `sbatch runner_job.sh`



== Oh No! Incomprehensible results!

// / *problem*:
1. Submit a job 1 with `sbatch`
2. Continue working, improving the python code
3. Submit a new job 2 with `sbatch`
4. Results for job 1 are weird?!
5. Results for job 2 are fine?
What's going on?



== Use _Code Checkpointing_ <code_checkpointing>

/ *problem*:
  1. `sbatch` job A
  2. Edit Python scripts
  3. `sbatch` job B
  4. Job A runs with *modified* code (BAD!)
  5. Job B runs with modified code
  6. Results are weird???

*Solution*:
1. `safe_sbatch`: refuses to submit with uncommitted changes
2. Job script clones code at the submitted commit ("code checkpointing")

#pagebreak()

Slurm + Git + #ref(<uv>, supplement: "uv") enables easy code checkpointing:

safe_sbatch:
```bash
#!/bin/bash
# safe_sbatch wrapper
if [ -n "`git status --porcelain`" ]; then
    echo "Your working directory is dirty! "
    echo "Please add and commit changes before submitting a job."
    exit 1
fi
export GIT_COMMIT=`git rev-parse HEAD`
exec sbatch "$@"
```

```console
safe_sbatch --gpus=1 --time=3-00:00:00 job.sh
```

#pagebreak()

Job clones the exact submitted commit into `$SLURM_TMPDIR`, runs from there.

- Venv recreated from uv cache (works offline)
// - Commands are run in the cloned project

/ *Job.sh*: ```bash
srun --ntasks-per-node=1 --ntasks=$SLURM_JOB_NUM_NODES bash -e <<END
    cd $SLURM_TMPDIR
    git clone $HOME/my_project
    git -C $SLURM_TMPDIR/my_project checkout --detach $GIT_COMMIT
    uv sync --directory $SLURM_TMPDIR/my_project
END
srun uv run --directory $SLURM_TMPDIR/my_project "$@"
```




== Use Job Dependencies to prevent waste <job_dependencies>

*Problem*: Some jobs fail → downstream jobs waste resources

/ todo: Add a Simple DAG diagram to illustrate job dependencies?



Pairs nicely with #ref(<job_submission>):

```bash
# Hyper-parameter sweep
jobid_a=$(sbatch --parsable job.sh --lr=0.01)
jobid_b=$(sbatch --parsable job.sh --lr=0.02)
jobid_c=$(sbatch --parsable job.sh --lr=0.03)

# Train once with best hyper-parameters, *only if all runs succeed*!
sbatch --kill-on-invalid-dep=yes --dependency=afterok:$jobid_a,$jobid_b,$jobid_c \
        job.sh --lr=best
```

== Tip: UV + Flash-attn <uv-flash_attn>

// Flash-Attention pain points:
// - Pre-built wheels not always available
- Building from source = 100s of threads, very slow (*don't do this on login nodes!*)

*Solution \#1*: Prebuilt wheel from DRAC wheelhouse (DRAC only)

// / TODO: Show a config that uses the DRAC wheelhouse when --extra drac and also works otherwise?

```toml
# pyproject.toml
[[tool.uv.index]]
name = "drac-gentoo2023-generic"
url = "/cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/generic"
format = "flat"
explicit = true

[tool.uv.sources]
# Use the pre-built wheel for flash-attn from the DRAC wheelhouse
flash-attn = { index = "drac-gentoo2023-generic" }
```


#pagebreak()

*Solution \#2*: Build from source.

/ Tip: uv allows setting environment variables when building specific packages!

```toml
#pyproject.toml
[tool.uv.extra-build-variables.flash-attn]
MAX_JOBS = "1"
FLASH_ATTENTION_SKIP_CUDA_BUILD = "0"
TORCH_CUDA_ARCH_LIST = "9.0"
```


== The incredible power of `jax.vmap`

First: Example of a Jax training loop.

#columns(2)[
  #set text(size: 10pt)
```python
import jax
import jax.numpy as jnp

def training_epoch(state, epoch: int):
  # does one training epoch.
  return new_state, metrics

def train(rng, config):
  initial_state = some_fn(rng, config)
  final_state = jax.lax.scan(
    training_epoch,
    init=initial_state,
    xs=jnp.arange(config.num_epochs),
  )
  accuracy = evaluate(final_state)
  return accuracy
```
#colbreak()

```python
from jax.random import key
config = Config(...)
rng = jax.random.key(123)
accuracy = jax.jit(train)(rng, config)
```
]
#pagebreak()


Varying seeds would usually works like this (e.g. in pytorch).
#set text(size: 10pt)
```python
from jax.random import key
config = Config(...)
accuracy_123 = train(key(123), config)
accuracy_456 = train(key(456), config)
```

Now, behold the power of `jax.vmap`!
```python
rng = key(123)
num_seeds = 2
rngs = jax.random.split(rng, num_seeds)

train_fn = lambda rng: train(rng, config)
accuracies = jax.vmap(train_fn)(rngs)  # Vectorize!!
```
#set text(size: 11pt)

_What's the big deal?_ : Vectorization is the *single most efficient way to do N things at once*!

#pagebreak()

Vectorization is the *single most efficient way to do N things at once*!

Advantages of Vectorization (`jax.vmap`) vs Multiprocessing:

- Vectorization: Rewrites the code to use vectorized operations with respect to an argument.
  - Low-level vectorized instructions (vector_add vs multiple adds)
  - Reduced context switching on hardware. (Single big matmul vs lots of small cuda kernels)
- Overhead is minimized (ex. datasets, buffers, anything that is not affected by the vmap-ed argument)

As a result, vectorization is *orders of magnitude faster and more efficient* than multiprocessing.

== Tip: Mixing PyTorch and Jax

Use both, get the best of both worlds:

- #link("https://github.com/mila-iqia/torch_jax_interop", "torch-jax-interop") (Mila)
  - `dlpack` API → zero-copy GPU conversion

```python
import torch
import jax.numpy as jnp
from torch_jax_interop import jax_to_torch, torch_to_jax

@jax_to_torch
def some_jax_function(x: jnp.ndarray) -> jnp.ndarray:
    return x + jnp.ones_like(x)

some_torch_tensor = torch.arange(5, device="cuda")
torch_output = some_jax_function(some_torch_tensor)
```

Also: #link("https://github.com/google/torchax", "torchax") (Google, different approach)


== Wandb Artifacts and Sweeps

- *Artifacts*: version datasets, checkpoints, results
  ```python
  artifact = wandb.Artifact("model-v1", type="model")
  artifact.add_file("checkpoint.pt")
  run.log_artifact(artifact)
  ```

- *Sweeps*: distributed hyperparameter search — controller + many agents
  ```bash
  wandb sweep sweep.yaml          # define search space, returns sweep ID
  wandb agent <entity>/<project>/<sweep_id>   # run on each compute node
  ```

- `WANDB_SILENT=true` → cleaner job `.out` files
- `WANDB_DIR=$SLURM_TMPDIR` → run files on fast local storage



== Dataloader Bottlenecks


*Easy to check* using a `tqdm` progress bar:

// - Note the throughput in samples per second with/without training (e.g. add `continue` in for-loop)
//   - Throughput is much faster without training → no bottleneck in data loading
//   - Throughput stays roughly the same → *bottleneck in data loading / transfer*

```python
import tqdm
for batch in tqdm.tqdm(dataloader, unit_scale=dataloader.batch_size, unit="samples"):
    batch = batch.to(device)
    if not training:
        continue  # skip training entirely.
    metrics = model.training_step(batch)
    ...
# will produce output like this:
# 100%|██████████| 500/500 [00:10<00:00, 50.0 samples/s]
```

#table(
  columns: (auto, auto, auto),
  [*`training=True`*], [*`training=False`*], [*conclusion*],
  [100 samples/s], [500 samples/s], [Dataloader is _*not*_ the bottleneck!],
  [100 samples/s], [\~100 samples/s], [Dataloader _*is*_ the bottleneck!],
)

#pagebreak()

*Symptom*: On Wandb or using a Profiler, low GPU utilization despite large model and big batches.


- Simplified Profiler timeline — `num_workers=0` (GPU starved):

#set text(size: 8pt)
#grid(
  columns: (3.5em, 2fr, 1fr, 2fr, 1fr, 2fr, 1fr),
  rows: (1.3em, 1.3em),
  gutter: 2pt,
  align: horizon + center,
  [*GPU*],
    rect(fill: red.lighten(55%), width: 100%, height: 1.3em, inset: 2pt)[*idle*],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 1],
    rect(fill: red.lighten(55%), width: 100%, height: 1.3em, inset: 2pt)[*idle*],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 2],
    rect(fill: red.lighten(55%), width: 100%, height: 1.3em, inset: 2pt)[*idle*],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 3],
  [*CPU*],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 1],
    rect(fill: red.lighten(55%), width: 100%, height: 1.3em)[idle],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 2],
    rect(fill: red.lighten(55%), width: 100%, height: 1.3em)[idle],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 3],
    rect(fill: red.lighten(55%), width: 100%, height: 1.3em)[idle],
)
#set text(size: 11pt)


- Simplified Profiler timeline — `num_workers=4, pin_memory=True` (overlapped):
#set text(size: 8pt)
#grid(
  columns: (3.5em, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
  rows: (1.3em, 1.3em),
  gutter: 2pt,
  align: horizon + center,
  [*GPU*],
    rect(fill: red.lighten(55%), width: 100%, height: 1.3em, inset: 2pt)[*idle*],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 1],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 2],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 3],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 4],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 5],
  [*CPU*],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 1],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 2],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 3],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 4],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 5],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 6],
)
#set text(size: 11pt)


// - Simplified Profiler timeline — `num_workers=4, pin_memory=True, non_blocking=True` (overlapped + async):
// // NOTE: This is quite tricky to get right. Probably best to reference this guide above.
// #set text(size: 8pt)
// #grid(
//   columns: (8em, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
//   rows: (1.3em, 1.3em),
//   gutter: 2pt,
//   align: horizon + center,
//   [*CUDA Stream 0*],
//     rect(fill: red.lighten(55%), width: 100%, height: 1.3em, inset: 2pt)[*idle*],
//     rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 1],
//     rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 2],
//     rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 3],
//     rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 4],
//     rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 5],
//   [*CUDA Stream 1*],
//     rect(fill: red.lighten(55%), width: 100%, height: 1.3em, inset: 2pt)[*idle*],
//     rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 1],
//     rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 2],
//     rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 3],
//     rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 4],
//     rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train batch 5],
//   [*CPU*],
//     rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 1],
//     rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 2],
//     rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 3],
//     rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 4],
//     rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 5],
//     rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load batch 6],
// )
// #set text(size: 11pt)


GPU stays busy — next batch always ready.


// #pagebreak()


#pagebreak()

== `torch.compile` + Mixed Precision <torch_compile>

Often the cheapest 2–4× speedup left on the table.

```python
import torch

torch.set_float32_matmul_precision("high")   # enables TF32 on Ampere+ (free on H100/A100)

model = MyModel().to("cuda")
model = torch.compile(model)                  # JITs into fused kernels (first step is slow!)

scaler = torch.amp.GradScaler()
for batch in dataloader:
    with torch.amp.autocast("cuda", dtype=torch.bfloat16):
        loss = model(batch)
    loss.backward()
    optimizer.step()
```


== Using the filesystem efficiently

#table(
  columns: (1fr, 1fr),
  stroke: 0.5pt,
  inset: 8pt,
  [*`$SLURM_TMPDIR`* (local SSD)],  [*`$SCRATCH`* (shared network FS)],
  [Fast — no network overhead],      [Slower — every read/write goes over the network],
  [Private per-job, per-node],       [Shared across all nodes and jobs],
  [Ideal for: dataset copies, build artifacts, intermediate outputs], [Ideal for: final checkpoints, logs, results to keep],
  [*Disappears when job ends!*],     [Persistent],
)

#pagebreak()

*Pattern — Extract directly to `$SLURM_TMPDIR`, copy results out at end*:
```bash
srun --ntasks-per-node=1 --ntasks=$SLURM_JOB_NUM_NODES \
  tar -xf $SCRATCH/my_dataset.tar -C $SLURM_TMPDIR/

srun uv run python train.py --data-dir=$SLURM_TMPDIR "$@"

mkdir -p $SCRATCH/$SLURM_JOB_ID
srun --ntasks=1 cp -r $SLURM_TMPDIR/final_results $SCRATCH/$SLURM_JOB_ID
```

*Avoid millions of small files* on the shared FS — metadata latency kills throughput.
Prefer: WebDataset (`.tar` shards), HDF5, or SQLite.


== Efficient Checkpointing <efficient-checkpointing>

Large multi-GPU models → `torch.distributed.checkpoint`. Each rank saves/loads its shard *in parallel*!

/ todo : Add image of distributed checkpointing from their docs

// #set text(size: 9pt)
// ```python
// import torch.distributed.checkpoint as dcp
// # Save (all ranks participate simultaneously)
// state = {"model": model, "optimizer": optimizer, "step": step}
// dcp.save(state, checkpoint_id=f"{checkpoint_dir}/step_{step}")
// # Load (resharding supported — can change number of GPUs between runs!)
// dcp.load(state, checkpoint_id=f"{checkpoint_dir}/step_{step}")
// ```
// #set text(size: 11pt)

Advantages over rank-0-only:
- *Much faster* — I/O parallelized across all ranks
- *Reshard-on-load* (8 → 16 GPUs, no re-save) — and *FSDP-aware* (handles sharded optimizer states)

See: #link("https://docs.pytorch.org/tutorials/recipes/distributed_checkpoint_recipe.html", [PyTorch Distributed Checkpointing tutorial]) + the *TorchTitan* talk at Upper Bound 2026!



== Combining Jaxtyping + einops <jaxtyping_einops>

// Combining `jaxtyping` with `einops` allows you to have very explicit, strictly typed code:

// #set text(size: 9pt)
// ```python
// from jaxtyping import Float
// from torch import Tensor

// def patchify(
//     images: Float[Tensor, "b c h w"],
//     p: int,
// ) -> Float[Tensor, " b (h/{p})*(w/{p}) ({p}*{p}*c)"]:
//     return rearrange(images, "b c (hp p1) (wp p2) -> b (hp wp) (p1 p2 c)", p1=p, p2=p)
// ```
// #set text(size: 11pt)

// #pagebreak()

#set text(size: 9pt)
```python
class SwiGLU(nn.Module):
    """SwiGLU feed-forward block: down(silu(gate) * up).
    Used in LLaMA, PaLM, Gemma — replaces the standard 2-layer ReLU MLP.
    """
    def __init__(self, d_model: int, d_ff: int):
        super().__init__()
        self.d_model = d_model
        self.d_ff = d_ff
        # Fused gate + up: one matmul instead of two, split with einops.
        self.gate_up = nn.Linear(d_model, 2 * d_ff, bias=False)
        self.down = nn.Linear(d_ff, d_model, bias=False)

    @jaxtyped(typechecker=beartype)
    def forward(
      self, x: Float[Tensor, "b n {self.d_model}"]
    ) -> Float[Tensor, "b n {self.d_model}"]:
        gate, up = rearrange(
            self.gate_up(x),  "b n (two d_ff) -> two b n d_ff", two=2,
        )
        return self.down(F.silu(gate) * up)
```
#set text(size: 11pt)



== Tip: Use CUDA Streams + non_blocking=True!

Enables maximal overlap without forcing synchronization at each step!

#set text(size: 9pt)
```python
dataloader = DataLoader(
    dataset,
    batch_size=64,
    num_workers=len(os.sched_getaffinity(0)), # as many workers as allocated CPUs
    pin_memory=True,
    # prefetch_factor=2, # Helps if there is variance in load times.
)
data_transfer_stream = torch.cuda.Stream()

for batch in dataloader:
    # Use cuda streams to overlap data transfer and training step without a sync
    with data_transfer_stream:
        batch = batch.to(device, non_blocking=True)
    # Training step on the main stream
    training_step(batch)
```

#set text(size: 11pt)

Excellent guide (*must read*!): https://docs.pytorch.org/tutorials/intermediate/pinmem_nonblock.html

*Still GPU-starved after this?* Look at #link("https://github.com/libffcv/ffcv", "FFCV") or #link("https://developer.nvidia.com/dali", "NVIDIA DALI") (input processing on the GPU)


== RL With Simulation on CPU

#align(center)[
  #fletcher.diagram(
    node-stroke: 0.8pt,
    spacing: (3em, 1.2em),
    node((0, 0), [ENV worker 0], fill: green.lighten(70%), shape: rect),
    node((0, 1), [ENV worker 1], fill: green.lighten(70%), shape: rect),
    node((0, 2), [ENV worker 2], fill: green.lighten(70%), shape: rect),
    node((2, 1), [Replay\ Buffer], fill: yellow.lighten(60%)),
    node((4, 1), [GPU Policy\ (training)], fill: blue.lighten(70%)),
    edge((0, 0), (2, 1), "->", label: [experience]),
    edge((0, 1), (2, 1), "->"),
    edge((0, 2), (2, 1), "->"),
    edge((2, 1), (4, 1), "->", label: [batch]),
    edge((4, 1), (0, 0), "->", label: [new weights], bend: -35deg),
    edge((4, 1), (0, 1), "..>", label: [], bend: -35deg),
    edge((4, 1), (0, 2), "..>", label: [], bend: -35deg),
    // edge((4, 1), (0, 1), "->"),
    // edge((4, 1), (0, 2), "->", bend: -35deg),
  )
]

*Problem*: NumPy and other libraries used in env worker auto-detect `num_threads = num_cpus`!
- `N x n_cpus` threads on `n_cpus` cores → context-switching → *slower jobs*!

// *Fix*:
```bash
export OMP_NUM_THREADS=1   # <-- Simple solution!
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK   # <-- Better!
```

== Slurm MCP
#align(center)[
  #image("images/slurm_mcp.png", height: 90%)
  https://github.com/mila-iqia/slurm_mcp
]

== Research Template Repository <research_template>

Research Template Repository: https://mila-iqia.github.io/ResearchTemplate/

/ TODO: Highlight some of the features of the template repo.

== AutoResearch

*AutoResearch* + *Slurm*: AI agent framework that autonomously runs experiments on Slurm clusters.

#align(center)[
  #fletcher.diagram(
    node-stroke: 0.8pt,
    spacing: (2.5em, 2em),
    node((1, 0), [*LLM Agent*\ (Hypothesize)], fill: purple.lighten(70%)),
    node((2, 1), [Slurm Job\ (`sbatch`)], fill: blue.lighten(70%)),
    node((1, 2), [Result\ Analysis], fill: green.lighten(70%)),
    node((0, 1), [Knowledge\ Base], fill: orange.lighten(70%)),
    edge((1, 0), (2, 1), "->", label: [submit]),
    edge((2, 1), (1, 2), "->", label: [results + logs]),
    edge((1, 2), (0, 1), "->", label: [update]),
    edge((0, 1), (1, 0), "->", label: [context]),
  )
]

1. *Hypothesize*: LLM proposes experiment (architecture, hyperparams, code)
2. *Submit + Monitor*: agent `sbatch`es the job, then polls for completion and reads logs/metrics
3. *Analyze*: LLM interprets results, refines direction
4. *Repeat* → progressively targeted experiments

*Why Slurm?* Clean, sandboxed interface — agent inherits resource management and isolation for free.

WIP at Mila — stay tuned!
