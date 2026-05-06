// #import "../lib.typ": *
#import "./diatypst.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

// Could be nice to annotate code blocks:
// #import "@preview/codly:1.3.0": *
// #import "@preview/codly-languages:0.1.1": *


#show: slides.with(
  title: "Software Ergonomics", // Required
  subtitle: "Tips and Tricks for Efficient Research with Slurm Compute Clusters",
  date: "2026-05-22",
  authors: ("Fabrice Normandin"),
  // Optional Style Options
  title-color: purple.darken(50%),
  ratio: 25/14, // aspect ratio of the slides, any valid number
  layout: "medium", // one of "small", "medium", "large"
  toc: true,
  count: "number", // one of "dot", "dot-section", "number", or none
  footer: true,
  theme: "normal",
  // footer-title: "FOOO 2026",
  footer-subtitle: "Upper Bound 2026",
  // theme: "full", // one of "normal", "full"
  // ... see the docs for more options
)

== About this presentation
This presentation is a collection of tips, tricks, and best practices for efficient research with Slurm compute clusters, based on my experience and the experience of many researchers at Mila.

There isn't a real narrative thread connecting the different sections.

Sit back, relax, let information rain down on you, and hopefully you'll find some useful nuggets to take back to your research!
#quote([
  The goal of this presentation is to give you useful tips and tricks to increase your productivity and reduce friction in your research workflow with Slurm clusters.
])
The code for this presentation can be accessed at #link("https://github.com/lebrice/upper_bound_2026_slides").

== Intended Audience

This presentation is intended for researchers in AI/ML who have access to Slurm compute clusters.
It can also be useful for the staff of Mila/DRAC/other companies that manage or use compute clusters for researchers.


= Introduction


== What is a Compute cluster, really?

TODO

== Canadian Compute Clusters

#grid(
  columns: (30%, 30%, 30%),
  rows: (auto, auto),
  gutter: 3pt,
  [
    *Mila*
    992 GPUs
    - Quick access to GPUs
    - Preemptible
    - Great for interactive debugging
  ],
  [
    *Tamia*

    308 GPUs (H100/H200)
  ],
  "Rorqual",

)

== Useful Slurm Commands

TODO

== Typical Research Workflow - Mila

TODO


TODO



= Slurm tips and tricks

== Easy job submission <job_submission>

#columns(2)[
  job.sh:
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

  In a terminal:
  ```console
  $ sbatch job.sh --lr=0.01
  $ sbatch job.sh --lr=0.001
  $ sbatch job.sh --lr=0.001 --nlayers=32
  ```
]

== Use Job Dependencies to prevent waste <job_dependencies>

Ties in nicely with the #ref(<job_submission>) setup!


```bash
# Hyper-parameter sweep
jobid_a=$(sbatch --parsable job.sh --lr=0.01)
jobid_b=$(sbatch --parsable job.sh --lr=0.02)
jobid_c=$(sbatch --parsable job.sh --lr=0.03)

# Train once with best hyper-parameters
sbatch --dependency=afterok:$jobid_a,$jobid_b,$jobid_c job.sh --lr=best
```


== Job Chunking: Get scheduled faster <job_chunking>

Easy Job chain!

Assuming your job script does #ref(<checkpointing>) correctly, you can break up a long job into smaller chunks, which can get scheduled faster and reduce the time needed to get your results!

```bash
#!/bin/bash
# Job Chain Example
num_chunks=5
jobid=$(sbatch --parsable --time=03:00:00 job.sh "$@")
for i in $(seq 2 $num_chunks); do
    jobid=$(sbatch --parsable --dependency=afterok:$jobid --time=03:00:00 job.sh "$@")
done
```

== Flexible Job Layout

- On clusters that don't enforce full-node allocations, being flexible about where the GPUs are laid out can help your jobs get scheduled faster!

  --> Use `--ntasks=4 --gpus-per-task=1` instead of `--gpus-per-node=4`.

Performance hit is minimal when using `--switches=1`.

Recommendation: Always be flexible, and use `sbatch --switches=1@3600`
  - Tries to alloca



== Checkpointing <checkpointing>

Checkpointing is *crucial*!
- Support for clusters with preemption (Mila cluster)
- Breaking up long jobs into smaller chunks (#ref(<job_chunking>))
- Being resilient to failures (e.g. hardware failure, software bugs, etc.)

== Code Checkpointing <code_checkpointing>

Using Slurm + Git + UV enables easy code checkpointing, which is a game changer for iterative development on clusters!

- Submit job A
- Edit the code
- Submit job B
- Job A starts running with the new code
- Job B starts running with the new code
- ???

#pagebreak()

```bash
#!/bin/bash
# clone the project from $HOME to $SLURM_TMPDIR at commit $GIT_COMMIT
export UV_OFFLINE=1
srun --ntasks-per-node=1 --ntasks=$SLURM_JOB_NUM_NODES bash -e <<END
    cd $SLURM_TMPDIR
    git clone $HOME/my_project
    git -C $SLURM_TMPDIR/my_project checkout --detach $GIT_COMMIT
    uv sync --directory $SLURM_TMPDIR/my_project
END
srun uv run --directory $SLURM_TMPDIR/my_project "$@"
```

= UV

== uv <uv>

*A game-changer for Python projects*

Awesome commands:
- `uv init`
- `uv add/remove <package>`
- `uv sync`
- `uv run <command>`

Not recommended: `uv pip` / `uv venv`. (pip compatibility, no dependency tracking)

Useful global flags / environment variables:
- `--offline` : Useful on DRAC clusters without internet access on Compute Nodes
- `--directory` Useful with a Code Checkpointing setup in `$SLURM_TMPDIR`



== Using uv on DRAC Clusters

// #set text(
//   size: 8pt
// )

Can use the DRAC wheelhouse when convenient (for example, `flash-attn`)

```toml
# pyproject.toml
[[tool.uv.index]]
name = "drac-gentoo2023-x86-64-v3"
url = "/cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/x86-64-v3"
format = "flat"
explicit = true

[tool.uv.sources]
# Use the pre-built wheel for flash-attn from the DRAC wheelhouse
flash-attn = { index = "drac-gentoo2023-generic" }
```

// ```toml
// [[tool.uv.index]]
// name = "drac-gentoo2023-generic"
// url = "/cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/generic"
// format = "flat"
// explicit = true

// [[tool.uv.index]]
// name = "drac-generic"
// url = "/cvmfs/soft.computecanada.ca/custom/python/wheelhouse/generic"
// format = "flat"
// explicit = true
// ```

== UV advanced tips

- UV can also set environment variables when building a specific package.

  ```toml
  #pyproject.toml
  [tool.uv.extra-build-variables.flash-attn]
  MAX_JOBS = "1"
  FLASH_ATTENTION_SKIP_CUDA_BUILD = "0"
  TORCH_CUDA_ARCH_LIST = "9.0"
  ```

#pagebreak()

- UV dependency groups for different CUDA versions:


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
]


= Interactive Development and Debugging

== milatools <milatools>

TODO


== mila code <mila-code>

TODO

== Smart SSH Config Entries: mila-cpu <mila-cpu>

TODO

== Debugging Multi-GPU Jobs

TODO: Slide showing how to use `srun` + attaching the vscode debugger to each task, to have the VsCode debugger attached to each task in a multi-node setup.


== Debugging Multi-Node Jobs

TODO: Slide showing how to use `srun` + attaching the vscode debugger to each task, to debug each gpu/node in a multi-node setup.

== Profiling with TensorBoard + Torch Profiler


= Writing Great ML Code

== Einops

TODO

== Jaxtyping

TODO

== Weights & Biases (WandB)
== Unit tests for ML

== (!!) GitHub CI + Slurm Clusters <github_ci_slurm>

// (Possibly unique, never seen this done before).

1. Have a self-hosted GitHub Runner on a machine with SSH access to a Cluster
2. PR workflow is reviewed and approved by the repo maintainers
3. Self-hosted runner submits a job on the cluster with `ssh <cluster> sbatch`
4. Job starts an *ephemeral self-hosted GitHub Runner* on a compute node (with GPUs)
5. GitHub runner on compute node runs tests, results appear on GitHub!

#align(center)[
  #image("github_ci_example.png", width: 90%)
]

#align(right)[Example: #ref(<research_template>)]

#pagebreak()

1. Isn't this a security risk?
  - Somewhat. Repo owners have to approve GitHub workflows manually before they can run.
  - CI runners act only as the user, no additional permissions.

2. What about MFA authentication?
  - SSH Multiplexing to preserve manual SSH connections (with MFA) on the machine with initial self-hosted runner.
    - Hacky, brittle, ill-advised, but it works!
  - Robot nodes + dedicated SSH keys that only do `sbatch runner_job.sh`
    - More trouble, more "secure".


= Performance Optimization

== Understanding Hardware is Critical!

// Bandwidth hierarchy across a typical GPU compute cluster node and between nodes.
#align(center)[
  #fletcher.diagram(
    node-stroke: 0.8pt,
    spacing: (2.5em, 3em),

    // --- Node 1 ---
    node((0, 0), [GPU 0], fill: blue.lighten(70%)),
    node((2, 0), [GPU 1], fill: blue.lighten(70%)),
    edge((0, 0), (2, 0), "<->", label: [~600 GB/s (NvLink)]),
    node((1, 1), [CPU + RAM], fill: green.lighten(70%)),
    edge((0, 0), (1, 1), "<->", label: [~32 GB/s (PCIe)]),
    edge((2, 0), (1, 1), "<->"),

    // --- Node 2 ---
    node((4, 0), [GPU 2], fill: blue.lighten(70%)),
    node((6, 0), [GPU 3], fill: blue.lighten(70%)),
    edge((4, 0), (6, 0), "<->", label: [~600 GB/s (NvLink)]),
    node((5, 1), [CPU + RAM], fill: green.lighten(70%)),
    edge((4, 0), (5, 1), "<->"),
    edge((6, 0), (5, 1), "<->", label: [~32 GB/s (PCIe)]),

    // --- Inter-node ---
    edge((1, 1), (5, 1), "<->", label: [~200 GB/s (NvMesh / Infiniband)]),
  )
]


== Dataloader Bottlenecks

TODO

== Using the filesystem efficiently

TODO

== Job Packing

TODO

== Tip: Mixing PyTorch and Jax

TODO


= Case studies

- Real Examples of sub-optimal workflows → diagnostic → fix → Outcome

== RL With Simulation on CPU

TODO

== Efficient Checkpointing

TODO

== Test-Driven Debugging of PyTorch CUDA Code

TODO

= Ongoing work and open problems

== Research Template Repository <research_template>

TODO

== AutoResearch

TODO

= Q&A
