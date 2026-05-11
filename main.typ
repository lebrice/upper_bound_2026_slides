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
  toc: true,
  // count: "number", // one of "dot", "dot-section", "number", or none
  count: "dot-section", // one of "dot", "dot-section", "number", or none
  footer: true,
  theme: "normal",
  footer-title: "Tips & tricks for efficient research with Slurm compute clusters",
  footer-subtitle: "Upper Bound 2026",
  // theme: "full", // one of "normal", "full"
  // ... see the docs for more options
)

== About this presentation
This presentation is a collection of tips, tricks, and best practices for efficient research with Slurm compute clusters, based on the experience of Mila's IDT team and of many researchers at Mila.

There isn't really a narrative thread that connects the different sections.

Sit back, relax, let information rain down on you, and hopefully you'll find some useful nuggets to take back to your research!
#quote([
  The goal of this presentation is to give you useful tips and tricks to increase your productivity and reduce friction in your research workflow with Slurm clusters.
])
The code for this presentation is available at #link("https://github.com/lebrice/upper_bound_2026_slides").

== Intended Audience

This presentation is aimed at researchers in AI/ML who have access to Slurm compute clusters.

It can also be useful for the staff of companies that manage or use compute clusters for research.

What this talk is about:

- How to use Slurm clusters efficiently
- How to reduce friction in your research workflow
- How do facilitate performance optimization


What this talk is *not* about:

- In-depth, low-level optimization of ML code
- Theoretical aspects of parallelism, distributed training, etc.


= Introduction


== What is a Compute cluster, really? <switches>

*Components*:
- *Login Nodes*: submit jobs, edit code, transfer files. *Never run heavy workloads here!*
- *Compute Nodes*: machines with GPUs/CPUs — these run your jobs
- *Storage Servers*: shared distributed filesystem (Lustre, BeeGFS) accessible from all nodes
- *Network Switches*: the fabric connecting nodes; placement affects inter-node bandwidth

/ TODO: Add a Diagram of a compute cluster

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

#pagebreak()

*Network Switches*: nodes are grouped under switches in a hierarchy. Jobs spread across many switches pay extra latency. `sbatch --switches=1` tells Slurm to prefer nodes under a single switch.

*Distributed Filesystem implications*:
- Data is _striped_ across storage servers → high throughput for large sequential reads
- High _metadata latency_ for small files (each `open()` is a network round-trip)
- Avoid millions of tiny files — prefer `.tar` shards, HDF5, WebDataset, or copy to `$SLURM_TMPDIR`



== Canadian Compute Clusters <clusters>

#table(
  stroke: 1pt,
  columns: 8,
  align: (auto, center, right, right, right, right, auto, auto),
  [Cluster],    [#text([CPU/GPU Nodes], size:0.7em)],[#underline("CPUs")], [GPUs],              [#underline("H100-eq.")],[Storage],[Internet?], [Full Node?],
  [Mila],       [12 / 190],     [11k],    [992 (mixed)],       [\~500],   [2 PB],   [*Yes*], [No],
  [Rorqual],    [686 / 93],     [138k],   [372 H100],          [372],     [*69 PB*],  [No], [No],
  [Fir],        [872 / 160],    [175k],   [640 H100],          [640],     [51 PB],  [*Yes*], [No],
  [Nibi],       [710 / 42],     [141k],   [288 H100],          [288],     [25 PB],  [*Yes*], [No],
  [Tamia],      [8 / 65],       [4k],     [212 H100 + 96 H200],[\~315],   [? PB],   [No], [Yes],
  [Killarney],  [0 / 178],      [11k],    [672 L40S + 80 H100],[\~652],   [2 PB],   [Yes?], [No],
  [Vulcan],     [0 / *252*],    [16k],    [1008 L40S],         [*\~858*],   [5 PB],   [No], [No],
  [Trillium],   [*1224* / 63],  [*241k*], [640 H100],         [640],     [29 PB],   [No], [Yes/No],
)

- Mila cluster has preemptible long jobs and limited non-preemptible short jobs.

= Slurm tips and tricks

== Useful Slurm Commands

- *`sbatch`* `--ntasks=4 --gpus=4 --cpus-per-task=16 --mem=32G --time=03:00:00 job.sh`
  - Requests resources (GPUs, CPUs, RAM) for one or more _*tasks*_ and runs a job script (`job.sh`) on one or more of the cluster's compute nodes.
- *`salloc`* `--ntasks=4 --gpus=4 --cpus-per-task=16 --mem=32G --time=03:00:00`
  - Similar to sbatch, but allocates resources and gives you an interactive shell on the compute node.
  - Useful for debugging, testing, etc.

- *`srun`* `python main.py`
  - Runs a "command" (e.g. `python main.py`) once per _*task*_ inside a job.
  - (Can also be used to create jobs, but we don't recommend it)

== `srun` is all you need!

`srun` is _*the*_ way to run commands in a SLURM job.

- `srun` takes care of launching the command on the right nodes, with the right environment variables,
- Slurm partitions the resources (CPUs, GPUs, and memory) properly across tasks!

- `srun` can be used to spawn different commands for each task (with `--multi-prog`)
  - Hyper-Parameter Sweeps, or Coordinator / Worker setups for distributed training, etc.


// - Slurm can even allocate different resources to different tasks within the same job!
    // ```bash
    // srun -n1 -c8 --mem-per-cpu=2gb server : -n16 --mem-per-cpu=1gb client
    // ```




== Example: Easy Job Packing with `srun`

- `srun --ntasks-per-gpu=2 uv run python main.py`
  - Easily run multiple seeds with something like `seed=os.environ["SLURM_PROCID"]` in the python code!

What about when we want very different commands for each task?

-> `srun --multi-prog` to the rescue!

  ```text
  # task_commands.txt
  0 python train.py --lr=0.01
  1 python train.py --lr=0.001
  2 python train.py --lr=0.0001
  3 python train.py --lr=0.00001
  ```
  ```bash
  srun --ntasks=4 --ntasks-per-gpu=4 --multi-prog task_commands.txt
  ```

(See #link("https://slurm.schedmd.com/srun.html#OPT_multi-prog", [`srun` documentation]))



== Easy job submission <job_submission>

*Problem*: Having the commands in your job script leads to having to manage lots of jobs scripts!

*Solution*

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

*problem*: Submitting a lot of jobs, but some of them fail (e.g. bug in the code, cluster instability, etc.) --> Waste of resources and time!

(This pairs nicely with the #ref(<job_submission>) setup)

```bash
# Hyper-parameter sweep
jobid_a=$(sbatch --parsable job.sh --lr=0.01)
jobid_b=$(sbatch --parsable job.sh --lr=0.02)
jobid_c=$(sbatch --parsable job.sh --lr=0.03)

# Train once with best hyper-parameters, *only if all runs succeed*!
sbatch --kill-on-invalid-dep=yes --dependency=afterok:$jobid_a,$jobid_b,$jobid_c \
        job.sh --lr=best
```


== Job Chunking: Get scheduled faster <job_chunking>


Assuming your job script does #ref(<checkpointing>) correctly, you can break up a long job into smaller chunks, which can get scheduled faster and reduce the time needed to get your results!

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

== Flexible Job Layout

On clusters that don't enforce full-node allocations (See #ref(<clusters>, supplement: "clusters")), being flexible about where the GPUs are laid out can help your jobs get scheduled faster!

*Suggestion*

- Go from this: `sbatch --nodes=2 --ntasks-per-node=4 --gpus-per-task=1 job.sh`
  - Asks for two full nodes with 4 GPUs each
  - Can take a long time to schedule

- To this: `sbatch `*`--nodes=1-8 --ntasks=8 --switches=1`*` --gpus-per-task=1 job.sh`
  - Asks for 8 tasks with 1 GPU each, spread across 1 to 8 nodes, but preferably on a single switch
  - Performance hit is minimized when using `--switches=1`. (Recall: #ref(<switches>, supplement: "switches"))

#linebreak()

*Recommendations*
- Be as flexible as possible, and use `sbatch --switches=1@3600`
- Monitor the throughput degradation, find sweet-spot.


== Checkpointing is a must! <checkpointing>

Proper checkpointing is *crucial*!
- Support for clusters with preemption
- Enables breaking up long jobs into smaller chunks (#ref(<job_chunking>))
- Makes jobs resilient to failures (e.g. hardware failure, software bugs, etc.)

- Consider using #link("https://docs.pytorch.org/tutorials/recipes/distributed_checkpoint_recipe.html", [Distributed Checkpointing]) when working with large models and multi-GPU jobs.
  - Also see the TorchTitan talk here at Upper Bound 2026!
  - Using "Async" mode enables more overlap between checkpointing and training


== Code Checkpointing <code_checkpointing>

/ *problem*:
  1. Submit job A with sbatch
  2. Modify the Python scripts
  3. Submit job B with sbatch
  4. Job A starts running with the *modified* code (BAD!)
  5. Job B starts running with the modified code
  6. Results are weird???

*Solution*:
1. `safe_sbatch`: Prevents the job from being submitted if there are uncommitted changes.
2. Job script uses the code at the commit when the job was submitted ("code checkpointing")

#pagebreak()

Using Slurm + Git + #ref(<uv>) enables easy code checkpointing:

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

Job script creates a copy of the code at the _exact_ commit that was used to submit the job, in a temporary directory (`$SLURM_TMPDIR`), and runs the code from there.

- Virtual environment is recreated in `/tmp` by #ref(<uv>) from the cache (also works in offline mode).
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

= uv

== uv <uv>

*A game-changer for Python projects*

Awesome commands:
- `uv init`
- `uv add/remove <package>`
- `uv sync`
- `uv run <command>`

Not recommended: `uv pip` / `uv venv`: (pip compatibility, no dep. tracking)

Useful global flags / environment variables:
- `--offline` : Useful on clusters with no internet access on Compute Nodes (see #ref(<uv_on_drac>, supplement: "UV + DRAC"))
- `--directory` Useful with a _Code Checkpointing_ setup in `$SLURM_TMPDIR` (see #ref(<code_checkpointing>))

== uv + PyTorch / CUDA dependencies

You can use dependency groups for different CUDA versions!


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

  - Very useful with a multi-cluster setup, where CUDA versions may differ between clusters. (See #ref(<cluv>) in later slides!)
]

== Using uv on DRAC Clusters <uv_on_drac>

// #set text(
//   size: 8pt
// )

Use the DRAC wheelhouse when convenient (for example, `flash-attn`)

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

Alternatively, you can also use the DRAC wheelhouse by default, and use PyPI only as needed:

#set text(
  size: 8pt
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

#pagebreak()

#set text( // reset to the original size.
  size: 11pt
)

Some packages are normally only available though modules.

Use the `sources` section of your project's `pyproject.toml` to get them from PyPI:

```toml
#pyproject.toml
[tool.uv.sources]
mpi4py = { index = "pypi" }
opencv = { index = "pypi" }
pyarrow = { index = "pypi" }
rdkit = { index = "pypi" }
```

== Example: UV + Flash-attn

Flash-Attention is notoriously difficult to deal with:
- pre-built wheels are not always available
- Building from source is heavy (terrible on login nodes)
  - 100s of threads, takes a very long time

*Solution 1*: Use a prebuilt wheel from the DRAC wheelhouse (works only on DRAC)

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

*Solution 2*: Build from source, and use a neat UV feature:

UV can set environment variables when building a specific package!

```toml
#pyproject.toml
[tool.uv.extra-build-variables.flash-attn]
MAX_JOBS = "1"
FLASH_ATTENTION_SKIP_CUDA_BUILD = "0"
TORCH_CUDA_ARCH_LIST = "9.0"
```


= Interactive Development and Debugging

== milatools <milatools>

Small Python package developed by the IDT team at Mila.

Install with `uv tool install milatools`

- `mila init`:
  - Sets up SSH configuration.
  - Checks access to clusters
  - Gives instructions for setting up access to Mila/DRAC clusters.

- `mila code --cluster=<cluster> [project_path] [--salloc resources]`

  Works with *_any_* Slurm cluster accessible with SSH
  1. Requests an interactive job with `salloc <resources>`;
  2. Waits for job to start;
  3. Opens `project_path` in VSCode with Remote-SSH connected to the compute node.
  - Can also connect to an already running job with `--job <job_id>`.

== mila code <mila-code>

`mila code my_project --cluster=mila --salloc --gpus=1 --mem=16G --time=06:00:00`
  - Requests an interactive job on the Mila cluster with `salloc` and requested resources;
  - Waits for job to start;
  - Opens `my_project` folder in VSCode with Remote-SSH connected to the compute node.

== Useful SSH Config Entries: mila-cpu <mila-cpu>

`mila init` creates an SSH config entry called `mila-cpu`. When used with `ssh mila-cpu`:
1. Connects to the Mila cluster
2. Checks for a running cpu job with name `'mila-cpu'`.
  - If a job is found, connect to it.
  - If no job is found, submit a new one with `sbatch`.
3. Creates a new interactive terminal attached to the job.
4. Job persists for 10 minutes after exiting.

```sshconfig
Host mila-cpu
  (...)
  ProxyCommand ssh mila "./milatools/slurm-proxy.sh mila-cpu --mem=8G"
  RemoteCommand ./milatools/entrypoint.sh mila-cpu
```

- Useful for Remote-SSH with vscode (alternative to #ref(<mila-code>))
// - Can be modified for any cluster and resource type (e.g. `mila-gpu`, `tamia-cpu`, etc.)

== Typical Research Workflow - Mila

/ TODO: Unsure where to place this slide.

1. `mila code my_project --cluster=mila --salloc --gpus=1 --mem=16G --time=06:00:00`

2. Develop code iteratively, using the VSCode terminal (inside compute node) to run commands.

3. Once the code is ready, submit a batch job with `sbatch` to run the code on more GPUs, for longer, etc.

4. Move to other cluster if necessary, use same loop (with `--cluster=<cluster>`).


== Debugging Multi-GPU Jobs

Easiest:

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

Launch `debugpy` on each task with a unique port, then attach VSCode to each process:

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

See: https://github.com/lebrice/mila-docs/blob/8919d6a352e7c6f3ec0c99441571400848ce8ae5/docs/examples/advanced/imagenet/.vscode/launch.json for the full VsCode launch configuration.


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
uvx --with=torch-tb-profiler tensorboard --logdir=./log/profiler
```

Opens an interactive view in the browser with:
- GPU utilization timeline (spot idle gaps instantly)
- Kernel-level breakdown (which ops dominate)
- Memory usage over time
- Operator-level stack traces

VsCode automatically forwards the port so the profiler UI is available on localhost:6006 (for example with #ref(<mila-code>)).


#pagebreak()

/ DEMO :

  Interactive demo (`mila code` + Debugging with VsCode + Profiling with TensorBoard + Torch Profiler)

= Tips and Tricks to Write Better ML Code

== Einops <einops>

*Problem*: Tensor `reshape` / `unsqueeze` / `permute` / `view` chains are cryptic, error-prone, and a pain to read months later.

*Solution*: `einops` lets you write tensor manipulations as a string of named axes.

Example: patchifying an image batch for a Vision Transformer.

#set text(size: 9pt)
#columns(2)[
  Without einops:
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

  With einops:
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

Also very useful:

- `einops.reduce(x, "b c h w -> b c", "mean")`
- `einops.repeat(x, "h w -> h w c", c=3)`
- `einops.einsum`
- `einops` Layers! (`Rearrange`, `Reduce`, `EinMix`), which can be used in `nn.Sequential` blocks, etc.
- And lots more!

Check out the docs at https://einops.rocks/ for more examples and use cases.


Pair with #ref(<jaxtyping>) for shape-checked tensors!

== Jaxtyping <jaxtyping>

`jaxtyping` adds shape + dtype to tensor type hints.

- Works for Jax / PyTorch / NumPy, etc

```python
from jaxtyping import Float
from torch import Tensor

# Accepts floating-point 2D arrays with matching axes
def matrix_multiply(x: Float[Tensor, "dim1 dim2"],
                    y: Float[Tensor, "dim2 dim3"]
                  ) -> Float[Tensor, "dim1 dim3"]:
    return x @ y
```

#pagebreak()

- Can be checked at runtime (for example during tests) when combined with `beartype` (or `typeguard`).

```toml
#pyproject.toml
[tool.pytest.ini_options]
addopts = "--jaxtyping-packages=my_project,beartype.beartype"
```

Also, useful as a shorthand for checking tensor type, dtype and shape:

```python
assert isinstance(output, Float32[Tensor, "3 128 128"])
```

#pagebreak()

Annotations can reference function arguments or module attributes!

#set text(size: 9pt)

```python
class MLP(nn.Module):
    """Standard 2-layer MLP with ReLU activation."""
    def __init__(self, in_dims: int, out_dims: int, hidden_dims: int = 128):
        super().__init__()
        self.in_dims = in_dims
        self.hidden_dims = hidden_dims
        self.out_dims = out_dims
        self.linear1 = nn.Linear(in_dims, hidden_dims)
        self.linear2 = nn.Linear(hidden_dims, out_dims)
        self.activation = nn.ReLU()

    @jaxtyped(typechecker=beartype)
    def forward(
        self, input: Float[Tensor, "b {self.in_dims}"]            # <---- (here)
    ) -> Float[Tensor, "b {self.out_dims}"]:                      # <---- (here)
        return self.linear2(self.activation(self.linear1(input)))
```
#set text(size: 11pt)

== Jaxtyping + einops <jaxtyping_einops>

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
        self,
        x: Float[Tensor, "b n {self.d_model}"],
    ) -> Float[Tensor, "b n {self.d_model}"]:
        gate, up = rearrange(
            self.gate_up(x),  "b n (two d_ff) -> two b n d_ff", two=2,
        )
        return self.down(F.silu(gate) * up)
```
#set text(size: 11pt)

== Weights & Biases (WandB)

*No internet on compute nodes?* Log offline, sync later:

```bash
export WANDB_MODE=offline
uv run python train.py        # logs to ./wandb/run-*/
# Later, from the login node:
wandb sync --sync-all
```

Or in code: `wandb.init(mode="offline")`.

#pagebreak()

*Useful tips*:

- Save Slurm environment variables in the wandb config!
```python
import os
import wandb
run = wandb.init(
  ...,
  config=vars(args) | {
    "env": {k: v for k, v in os.environ.items() if k.startswith("SLURM_")}
  }
)
```

#pagebreak()

- *Artifacts*: version datasets, checkpoints, and results — reproducible and shareable
  ```python
  artifact = wandb.Artifact("model-v1", type="model")
  artifact.add_file("checkpoint.pt")
  run.log_artifact(artifact)
  ```

- *Sweeps*: distributed hyperparameter search — one sweep controller, many agents
  ```bash
  wandb sweep sweep.yaml          # define search space, returns sweep ID
  wandb agent <entity>/<project>/<sweep_id>   # run on each compute node
  ```

- `WANDB_SILENT=true` suppresses noisy logging in job `.out` files
- `WANDB_DIR=$SLURM_TMPDIR` keeps run files on fast local storage during the job





= Testing for ML code

== Reproducibility testing <tensor-regression>

URL: #link("https://github.com/mila-iqia/tensor_regression", "github.com/mila-iqia/tensor_regression")

```python
import pytest
from my_project import make_model

@pytest.mark.parametrize("seed", [42])
def test_initialization_is_reproducible(seed: int, tensor_regression):
    model = make_model(seed=seed)
    tensor_regression.check(model.state_dict())
```

Based on #link("https://github.com/ESSS/pytest-regressions", "pytest-regressions")
- Saves simple tensor statistics (shape, dtype, min/max/mean) in a `.yaml` file that can be saved with git.
- Value differs from expected --> Error
- File not present --> Error. (Generate missing files with `--gen-missing` or `--regen-all`)


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

== Case Study: Test-Driven Debugging of PyTorch Code

A researcher is having issues with a custom PyTorch op with hand-written forward + backward passes.
It works correctly for small inputs, but explodes and CUDA OOMs for larger inputs.

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

*Step 2*: Iterative debugging / optimization. Always know whenever you break the forward/backward pass!

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

*Symptom*: GPU utilization is low even though the model is large and batches are big.

#set text(size: 8pt)
*Profiler timeline — `num_workers=0` (GPU starved):*
#grid(
  columns: (3.5em, 2fr, 1fr, 2fr, 1fr, 2fr, 1fr),
  rows: (1.3em, 1.3em),
  gutter: 2pt,
  align: horizon + center,
  [*GPU*],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train],
    rect(fill: red.lighten(55%), width: 100%, height: 1.3em, inset: 2pt)[*idle*],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train],
    rect(fill: red.lighten(55%), width: 100%, height: 1.3em, inset: 2pt)[*idle*],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train],
    rect(fill: red.lighten(55%), width: 100%, height: 1.3em, inset: 2pt)[*idle*],
  [*CPU*],
    rect(fill: white, width: 100%, height: 1.3em)[],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load],
    rect(fill: white, width: 100%, height: 1.3em)[],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load],
    rect(fill: white, width: 100%, height: 1.3em)[],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[load],
)
#set text(size: 11pt)

GPU blocks on every batch — wasted compute budget!

#pagebreak()

*Solution*

```python
dataloader = DataLoader(
    dataset,
    batch_size=64,
    num_workers=4,  # <-- Too low --> GPU waits for data
    pin_memory=True, # <-- Useful for GPU training
    prefetch_factor=2, # <-- Useful for GPU training
)
data_transfer_stream = torch.cuda.Stream()

for batch in dataloader:
    # Use cuda streams to overlap data transfer and training step
    with torch.cuda.stream(data_transfer_stream):
        batch = batch.to(device, non_blocking=True)
    # Training step on the main stream
    trainin_step(batch)
```

#pagebreak()

#set text(size: 8pt)
*Profiler timeline — `num_workers=4, pin_memory=True` (overlapped):*
#grid(
  columns: (3.5em, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
  rows: (1.3em, 1.3em),
  gutter: 2pt,
  align: horizon + center,
  [*GPU*],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train 0],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train 1],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train 2],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train 3],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train 4],
    rect(fill: blue.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[train 5],
  [*CPU*],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[prefetch 1],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[prefetch 2],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[prefetch 3],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[prefetch 4],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[prefetch 5],
    rect(fill: orange.lighten(50%), width: 100%, height: 1.3em, inset: 2pt)[prefetch 6],
)
#set text(size: 11pt)

GPU stays fully busy — the next batch is always ready before the step ends.


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

*Best practice — copy dataset in at job start, results out at job end*:
```bash
cp -r $SCRATCH/datasets/my_dataset $SLURM_TMPDIR/

python train.py \
    --data-dir=$SLURM_TMPDIR/my_dataset \
    --checkpoint-dir=$SCRATCH/checkpoints/

cp -r $SLURM_TMPDIR/final_results $SCRATCH/
```

*Avoid millions of small files* on the shared FS — high metadata latency kills throughput.
Prefer: WebDataset (`.tar` shards), HDF5, or SQLite over directories of individual images/arrays.



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
    edge((2, 1), (4, 1), "<->", label: [batch / update]),
    edge((4, 1), (0, 0), "->", label: [new weights], bend: 35deg),
    edge((4, 1), (0, 1), "->"),
    edge((4, 1), (0, 2), "->", bend: -35deg),
  )
]

*Problem*: Each worker uses Numpy, which detects N-cpus available cpus. With N workers and default `OMP_NUM_THREADS`, you get `N x OMP_NUM_THREADS` threads competing for N_CPU cores → constant context-switching → adding more workers makes simulation *slower*.

*Fix*:
```bash
export OMP_NUM_THREADS=1
```

// == Job Packing


== Tip: Mixing PyTorch and Jax

There are Pros to each framework!
Can you use both and get the best of both worlds? --> *Yes!*

- #link("https://github.com/mila-iqia/torch_jax_interop", "torch-jax-interop") (made by us at Mila)
  - Uses `dlpack` api from Jax/PyTorch, with Zero-copy conversion on the GPU!

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

Also: #link("https://github.com/google/torchax", "torchax") (Different approach, made by Google.)




== Efficient Checkpointing

For large multi-GPU models, use `torch.distributed.checkpoint` — each rank saves/loads its own shard *in parallel*:

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

Advantages over rank-0-only checkpointing:
- *Much faster* — I/O is parallelized across all ranks
- *Reshard on load* — switch from 8 to 16 GPUs without re-saving
- *FSDP-aware* — handles sharded optimizer states correctly

See: #link("https://docs.pytorch.org/tutorials/recipes/distributed_checkpoint_recipe.html", [PyTorch Distributed Checkpointing tutorial]) as well as the talk from the *TorchTitan* team here at Upper Bound 2026!


= Ongoing work and open problems

== cluv <cluv>

Cluv: *Cl* uster + *uv*: Simple CLI tool to dispatch jobs and synchronize uv projects across multiple Slurm clusters.

- `cluv login`
- `cluv sync`
- `cluv status`
- `cluv run <cluster> <command>`
- `cluv submit <cluster> <job_script> [args]`
- `cluv submit   first   <job_script> [args]`


== Research Template Repository <research_template>

Research Template Repository: https://mila-iqia.github.io/ResearchTemplate/

/ TODO: Highlight some of the features of the template repo.

== AutoResearch

*AutoResearch* + *Slurm*: an AI agent framework that autonomously conducts experiments on Slurm compute clusters.

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

1. *Hypothesize*: LLM agent proposes an experiment (architecture, hyperparameters, code changes)
2. *Submit*: agent calls `sbatch` to run the experiment on real GPUs
3. *Monitor*: polls for job completion, reads logs and metrics
4. *Analyze*: LLM interprets results and refines its research direction
5. *Repeat* → progressively more targeted experiments

*Why Slurm?* Clean, sandboxed interface — the agent requests compute through the standard scheduler, inheriting all resource management and isolation for free.

Work in progress at Mila — stay tuned!

= Q&A
