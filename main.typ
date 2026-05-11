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

/ TODO:
  Slide describing the nodes / switches / storage servers.

  Interesting info for everyone, even veterans:
  - Relative bandwidth of different communication paths (intra-node GPU-GPU, intra-node GPU-CPU, inter-node GPU-CPU, inter-node CPU-CPU)
  - Intro to "switches", impact in distributed jobs (controlled somewhat with `--switches` of sbatch)
  - Distributed filesystem implications:
    - Filesystem striping across multiple storage servers --> Higher throughput for large datasets
    - But also higher latency for small files --> Implications for checkpointing, logging, etc.



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

/todo: Slide showing how `srun` is amazing.

= Slurm tips and tricks

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

*problem*: Submitting a lot of jobs, but
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


== Checkpointing <checkpointing>

Proper checkpointing is *crucial*!
- Support for clusters with preemption (only Mila cluster)
- Enables breaking up long jobs into smaller chunks (#ref(<job_chunking>))
- Makes jobs resilient to failures (e.g. hardware failure, software bugs, etc.)

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

== Case Study - UV + Flash-attn

Flash-Attention is notoriously difficult to deal with:
- pre-built wheels are not always available
- Building from source is heavy (terrible on login nodes)
  - 100s of threads, takes a very long time

*Solution 1*: UV can set environment variables when building a specific package!

  ```toml
  #pyproject.toml
  [tool.uv.extra-build-variables.flash-attn]
  MAX_JOBS = "1"
  FLASH_ATTENTION_SKIP_CUDA_BUILD = "0"
  TORCH_CUDA_ARCH_LIST = "9.0"
  ```

#pagebreak()

*Solution 2*: Use a prebuilt wheel from the DRAC wheelhouse (works only on DRAC)

/ TODO: Show a config that uses the DRAC wheelhouse when --extra drac and also works otherwise?

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




= Interactive Development and Debugging

== milatools <milatools>

Small Python package developed by the IDT team at Mila.

Install with `uv tool install milatools`


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

== Smart SSH Config Entries: mila-cpu <mila-cpu>

`mila init` creates an SSH config entry called `mila-cpu`.

`ssh mila-cpu`:
1. Connects to the Mila cluster
2. Checks for a running cpu job with name `'mila-cpu'`.
  - If a job is found, connect to it.
  - If no job is found, submit a new one with `sbatch`.
3. Creates a new interactive terminal attached to the job.
4. Job persists for 10 minutes after exiting.


- Useful for Remote-SSH with vscode (alternative to #ref(<mila-code>))
- Can be modified for any cluster and resource type (e.g. `mila-gpu`, `tamia-cpu`, etc.)

== Typical Research Workflow - Mila

1. `mila code my_project --cluster=mila --salloc --gpus=1 --mem=16G --time=06:00:00`

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

== Smart SSH Config Entries: mila-cpu <mila-cpu>

== Typical Research Workflow - Mila

1. `mila code my_project --cluster=mila --salloc --gpus=1 --mem=16G --time=06:00:00`

2. Develop code iteratively, using the VSCode terminal (inside compute node) to run commands.

3. Once the code is ready, submit a batch job with `sbatch` to run the code on more GPUs, for longer, etc.

4. Move to other cluster if necessary, use same loop (with `--cluster=<cluster>`).

== Debugging Multi-GPU Jobs

/ TODO: Slide showing how to use `srun` + attaching the vscode debugger to each task, to have the VsCode debugger attached to each task in a multi-node setup.


== Debugging Multi-Node Jobs

/ TODO: Slide showing how to use `srun` + attaching the vscode debugger to each task, to debug each gpu/node in a multi-node setup.

== Profiling with TensorBoard + Torch Profiler

/ TODO: Slide showing Tensorboard + torch-tb-profiler


= Writing Great ML Code

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

/ TODO: Slide on useful tips and tricks on using Weights and Biases.

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

== Case Study: Test-Driven Debugging of PyTorch CUDA Code

/ TODO:

  Slide(s) telling the story of user coming in with custom PyTorch module with custom forward/backward passes.
  Using tests to cement the setup, before iteratively debugging and optimizing the code.

  -> Test as a guardrail against regressions, and as a way to validate the fixes.


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

/ TODO: Profiler output showing the GPU doing nothing while waiting for a batch of data.

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

/ TODO: Profiler output showing the overlap between loading and training


== Using the filesystem efficiently

TODO


== RL With Simulation on CPU

- Real Examples of sub-optimal workflows → diagnostic → fix → Outcome
/ TODO:
  Diagram showing the workflow of an RL experiment using simulation on the CPU. Simulation is very slow, and increasing the number of workers makes this slower!



== Job Packing

TODO

== Tip: Mixing PyTorch and Jax

There are Pros to each framework!

Can you use both and get the best of both worlds? --> *Yes!*

- #link("https://github.com/mila-iqia/torch_jax_interop", "torch-jax-interop") (made by me, at Mila)
  - Zero-copy conversion on the GPU!

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



// = Case studies



== Efficient Checkpointing

/ TODO:
  Slide giving link to the Distributed Checkpointing guide of PyTorch (and reference to the TorchTitan implementation.)



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

TODO

== AutoResearch

TODO

= Q&A
