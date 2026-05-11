# Speaker Notes — Efficient Research with Slurm Compute Clusters

**Upper Bound 2026 — Fabrice Normandin (Mila IDT)**

> Time budget: ~1 minute per slide max. Slides marked *(continued)* are pagebreaks within the same logical slide — keep those very short.

---

## Slide 1 — About this presentation

Hi everyone, I'm Fabrice from Mila's Innovation, Development and Technology (IDT). What you're about to see is basically a grab-bag of tips, tricks, and best practices we've collected from working with researchers on Slurm clusters. There's no single narrative — each section stands alone. So sit back, relax, and hopefully you'll walk away with a few concrete things you can apply on Monday morning. Everything is on GitHub at the link shown — slides, code, configs, all of it. Feel free to fork.

---

## Slide 2 — Intended Audience

This is aimed at AI/ML researchers who already have Slurm cluster access — Mila, DRAC, or otherwise. It's also relevant for staff at companies that operate research clusters. We're going to focus on the workflow level: how to use the cluster efficiently, how to reduce friction day-to-day, and how to set up your code so performance optimization is easy *later*. We will *not* be doing low-level CUDA kernel optimization or distributed-training theory — there are great talks at Upper Bound covering those.

---

## Section: Introduction

---

## Slide 3 — What is a Compute cluster, really?

Before talking about workflows, let's get the mental model right. A cluster is four things: login nodes — where you SSH in, edit files, submit jobs; compute nodes — where actual work happens; storage servers — the shared filesystem; and network switches — the fabric tying it all together. The single most important rule: **never run heavy workloads on the login node.** It's shared with everyone, and it's the fastest way to make sysadmins unhappy. Everything else in this talk assumes you understand these four building blocks.

---

## Slide 4 — Network switches & filesystem implications

Two practical consequences. First, network switches: nodes are grouped hierarchically. A job spread across many switches pays latency for every cross-switch communication. `sbatch --switches=1` tells Slurm to prefer packing your job under one switch — we'll come back to this. Second, the distributed filesystem: it's tuned for big sequential reads, not for opening millions of tiny files. Every `open()` is a network round-trip. If you're working with a dataset of a million JPEGs, that pattern alone can be your bottleneck. Solutions: tar shards, HDF5, WebDataset, or copy the dataset to `$SLURM_TMPDIR` at job start.

---

## Slide 5 — Canadian Compute Clusters

Quick tour of what's available in Canada. Mila is the home cluster for most of our researchers — mixed GPUs, internet access, preemptible long jobs. The DRAC clusters — Rorqual, Fir, Nibi, Trillium — are larger but more restricted: usually no internet on compute nodes. Tamia and Trillium are interesting because they enforce **full-node** allocations, which changes how you size jobs. Killarney and Vulcan have L40S GPUs. The H100-equivalent column is the rough yardstick to compare compute power. The takeaway: each cluster has its quirks — and your workflow should let you move between them without rewriting everything.

---

## Section: Getting Connected

---

## Slide 6 — milatools

`milatools` is a small Python package we built at Mila. Anyone can install it with `uv tool install milatools`, or `pip install milatools` if you don't use uv yet.
The two commands you'll use most: `mila init` walks you through SSH configuration and gives you tailored instructions for getting access to Mila and DRAC clusters.
`mila code` is the most appreciated feature - it launches an interactive Slurm job and opens VSCode directly attached to the compute node. And importantly: `mila code` works with *any* Slurm cluster you can reach via SSH, not just Mila's.

---

## Slide 7 — mila code

Here's the full command. You're saying: give me one GPU, 16 GB of RAM, for 6 hours, and open `my_project` in VSCode connected to that compute node. Behind the scenes it's doing an `salloc`, then waits for the job to start, then launches Remote-SSH through the allocated node. You can also attach to an existing job with `--job <jobid>`, which is great when a long job is already running and you want to poke at it interactively. This is the daily-driver command for most Mila researchers.

---

## Slide 8 — mila-cpu SSH config entry

`mila init` also installs an SSH host called `mila-cpu`. When you do `ssh mila-cpu` — or point VSCode Remote-SSH at it — it checks whether you already have a CPU job named `mila-cpu` running, attaches to it if so, or submits a fresh one if not. The job sticks around for 10 minutes after you disconnect, so reconnects are instant. It's a slightly more automated alternative to `mila code` when you want a persistent dev box without thinking about it. The same pattern can be adapted for any cluster — `tamia-cpu`, `mila-gpu`, etc.

---

## Slide 9 — Typical Research Workflow - Mila

Here's the typical loop. Step one: `mila code` to get an interactive job with a GPU. Step two: develop iteratively in VSCode — the terminal you see is on the compute node, so running scripts is just running scripts. Step three: when the code is solid, switch to `sbatch` to run longer or scale wider. Step four: when you need more or different compute, repeat with `--cluster=<other>`. The point is: one tool, one mental model, all the clusters. No more memorizing the SSH incantation for each one.

---

## Section: Environment Management

---

## Slide 10 — uv

If you take only one thing from this talk: **try uv**. It's a Rust-based Python package manager that's an order of magnitude faster than pip and actually handles lockfiles properly. `uv init` to start, `uv add/remove` for dependencies, `uv sync` to install, and `uv run` to execute commands. (`uv run` transparently re-syncs first). Avoid `uv pip` and `uv venv`: those are pip-compatibility escape hatches that bypass the dependency tracking that makes uv valuable. Two flags I would also recommend using: `--offline` for DRAC compute nodes that have no internet, and `--directory` for the code-checkpointing setup we'll see later.

---

## Slide 11 — uv + PyTorch / CUDA dependencies

Here's where uv really shines for ML. Different clusters often have different CUDA versions. With uv you can declare *both* as extras — `cuda128` and `cuda130` — mark them as mutually exclusive, and pull each from the right PyTorch index. Then on cluster A you `uv sync --extra=cuda128`, and on cluster B `--extra=cuda130`. Same lockfile, same code, same `pyproject.toml`. No more `conda` environments diverging in mysterious ways. This pairs with `cluv`, which I'll show at the end.

---

## Slide 12 — Using uv on DRAC Clusters

DRAC maintains a "wheelhouse" — a directory of pre-built Python wheels optimized for their environment. You can point uv at it as a flat index. Most useful: packages that are painful to build, like `flash-attn`. Just declare the wheelhouse index, tell uv to source `flash-attn` from it, and you skip the long build entirely.

---

## Slide 13 — DRAC wheelhouse as default

If you're doing most of your work on DRAC, flip it around: make the wheelhouse the *default* index, and use PyPI only for packages that aren't there. Once you sync the project once on a login node, the compute nodes will be able to resolve everything locally from cache without an internet connection.

---

## Slide 14 — DRAC: getting modules from PyPI

Some packages — `mpi4py`, `opencv`, `pyarrow`, `rdkit` — are typically only available as modules on DRAC. With `tool.uv.sources` you can override that on a per-package basis and pull them from PyPI instead, which keeps your environment self-contained and reproducible.

---

## Slide 15 — Example: UV + Flash-attn

Concrete example. Flash-attention is notorious — pre-built wheels aren't always available, and building from source uses hundreds of threads and takes forever. If you accidentally trigger it on a login node, you'll be that person. Two solutions: solution one — use a prebuilt wheel from the DRAC wheelhouse, works only on DRAC but it's instant.

---

## Slide 16 — Flash-attn Solution 2: build from source

Solution two — build from source, but use uv's `extra-build-variables` feature to control the build environment. Cap `MAX_JOBS` to 1 so you don't spawn 200 compile threads, set the right CUDA arch, and uv will pass those env vars *only* when building that one package. Clean, declarative, reproducible across machines.

---

## Section: Submitting Jobs

---

## Slide 17 — Useful Slurm Commands

The three commands you'll use constantly. `sbatch` submits a batch job — you give it resources and a script, it runs unattended. `salloc` is the same but interactive — it drops you into a shell on the compute node. `srun` runs a command, typically *inside* a job, once per task. People sometimes use `srun` to create jobs directly — don't, it's brittle. Use `sbatch` or `salloc` to create the allocation, and `srun` to execute things within it.

---

## Slide 18 — srun is all you need!

This is the slide I want everyone to remember. **Inside a job, always use `srun` to launch your command.** `srun` handles binding tasks to GPUs, setting up environment variables like `SLURM_PROCID`, partitioning CPUs and memory correctly across tasks. If you skip it and just run `python main.py` directly, you might end up with all 4 tasks fighting over the same GPU. `srun` also has `--multi-prog`, which lets you run different commands per task — great for sweeps or coordinator/worker setups. And the niche but cool feature: heterogeneous resources, different memory/CPU per task within the same job.

---

## Slide 19 — Example: Easy Job Packing with srun

Two patterns. First: `srun --ntasks-per-gpu=2` runs your script twice per GPU — so on a 4-GPU node you get 8 parallel runs with one command. Use `SLURM_PROCID` inside Python to seed each one differently. Boom, free multi-seed runs. Second: when you want *different* commands per task, write them in a `multi-prog` file — one line per task ID — and pass it to srun. This is hyperparameter sweeping with zero infrastructure.

---

## Slide 20 — Easy job submission

The anti-pattern: one job script per experiment configuration. You end up with `job_lr01.sh`, `job_lr001.sh`, `job_lr001_nlayers32.sh`. The solution: write one generic `job.sh` that forwards `"$@"` to your Python script, and pass the experiment config as command-line arguments to `sbatch`. Now you have one file, infinite experiments. This pattern is the foundation for the dependency chaining we're about to see.

---

## Section: Job Management

---

## Slide 21 — Use Job Dependencies to prevent waste

You're running a hyperparameter sweep, then you want to train once with the best config. If you naively submit the final job, it'll start regardless of whether the sweep succeeded — wasting GPU hours if something crashed. Solution: capture the sweep job IDs with `--parsable`, then submit the follow-up with `--dependency=afterok:<ids>` plus `--kill-on-invalid-dep=yes` so it gets killed cleanly if any dependency fails. Build pipelines, not isolated submissions.

---

## Slide 22 — Job Chunking: Get scheduled faster

The scheduler favors short jobs. A 24-hour job sits in the queue much longer than 8 three-hour jobs. If your code *checkpoints properly* — which we'll get to — you can submit a chain: each chunk depends on the previous one succeeding, and they hand off state through the checkpoint. Same total wall time of computation, much shorter time-to-first-result, and your job survives cluster maintenance windows.

---

## Slide 23 — Flexible Job Layout

If your cluster allows partial-node allocations, give Slurm flexibility. Instead of `--nodes=2 --ntasks-per-node=4` — which demands two full nodes — write `--nodes=1-8 --ntasks=8 --switches=1`. You're saying: I need 8 GPUs, spread them however you want, but ideally under one switch. The scheduler will find a fit much faster. The `--switches=1@3600` form means "prefer one switch, but give up waiting for that after an hour." Find the sweet spot — too flexible can hurt throughput, too rigid hurts queue time.

---

## Slide 24 — Checkpointing is a must!

Proper checkpointing is non-negotiable. It unlocks: running long jobs on preemptible partitions; the job-chunking trick from two slides ago; resilience to hardware failures and bugs. If you're working with large models, use PyTorch's Distributed Checkpointing — every rank writes its own shard in parallel. The async mode overlaps checkpoint I/O with training, so the cost is nearly free. Check out the TorchTitan talk at this conference for a deep dive.

---

## Slide 25 — Code Checkpointing

A subtle bug I've seen many times. You `sbatch` job A. While it sits in the queue, you edit your code. Then you `sbatch` job B. Job A finally starts — using your *modified* code, not the version you intended. Your results are mysteriously inconsistent and you can't reproduce them. The fix is two-part: refuse to submit if the working directory is dirty, and have the job clone the exact commit at the time of submission.

---

## Slide 26 — safe_sbatch

The first piece: a thin wrapper around `sbatch` that bails out if `git status --porcelain` shows anything. Then it exports the current commit hash as an environment variable that the job inherits. Six lines of bash, prevents an entire category of "wait, why is this not reproducing?" bugs.

---

## Slide 27 — Job script with code checkpointing

The job script's first action: `srun` once per node to clone the project into `$SLURM_TMPDIR`, check out the exact commit, and `uv sync` to recreate the environment. After that, the actual training command runs against the frozen code. `uv` rebuilds the venv from its cache, so this works offline on DRAC. The code that runs is the code you submitted — guaranteed.

---

## Section: Tips and Tricks to Write Better ML Code

---

## Slide 28 — Einops

Quick show of hands — who has written a `.reshape().permute().reshape()` chain and come back to it a month later wondering what it does? Yeah. `einops` lets you write the same operation as a single string of named axes. Compare the two sides: the einops version is self-documenting — you can literally read it as "batch, channels, height-and-patch, width-and-patch, rearrange to batch, patches, patch-pixels." Months later, you'll still understand it.

---

## Slide 29 — More einops

Beyond `rearrange`, einops has `reduce` for aggregations, `repeat` for broadcasting, `einsum` for general tensor contractions, and Layer modules you can drop into `nn.Sequential`. Check out einops.rocks — the docs are genuinely fun, with interactive examples. Pair this with `jaxtyping` for shape-checked tensors, coming up next.

---

## Slide 30 — Jaxtyping

`jaxtyping` lets you put shapes and dtypes directly into your type hints. It works for PyTorch, JAX, and NumPy. In the example, `Float[Tensor, "dim1 dim2"]` says: a floating-point tensor with two named axes. The function signature now documents the contract: input shapes must align on `dim2`, output combines `dim1` and `dim3`. Beautiful.

---

## Slide 31 — Jaxtyping runtime checks

Where it gets really powerful: combine it with `beartype` or `typeguard` and the shape annotations are *checked at runtime*. Set this up in your pytest config and every test exercises shape validation for free. Catches an entire class of "I broadcasted the wrong dim" bugs immediately. Also handy as an inline assertion when you want to verify an intermediate tensor.

---

## Slide 32 — Jaxtyping with self-references

You can reference instance attributes inside the annotation — `{self.in_dims}`, `{self.out_dims}`. So your MLP's forward method literally declares: "I take a batch with `in_dims` features and return a batch with `out_dims` features." If someone passes the wrong shape, runtime checks raise immediately with a clear error message. No more silent broadcasting.

---

## Slide 33 — Jaxtyping + einops

Putting it together — here's a SwiGLU block from a modern transformer. The forward signature uses jaxtyping to lock in input and output shapes. Inside, einops splits the fused gate/up projection in one line. The whole thing fits on a slide, is fully type-checked, and reads like a specification. This is what I want my ML code to look like.

---

## Slide 34 — Weights & Biases (WandB)

Quick note for DRAC users — no internet on compute nodes. WandB still works: set `WANDB_MODE=offline`, runs accumulate locally, then `wandb sync` from the login node afterward. You don't lose anything.

---

## Slide 35 — WandB tips: capturing Slurm env

A trick I love: stuff all your `SLURM_*` environment variables into the wandb config. Now every run has its job ID, partition, node, GPU type embedded. When you're hunting down a flaky result months later, you can ask "did this happen on a specific node?" right from the UI.

---

## Slide 36 — WandB Artifacts and Sweeps

Two more features worth knowing. *Artifacts*: version your checkpoints and datasets, with provenance tracking — wandb knows exactly which run produced which checkpoint. *Sweeps*: a sweep controller orchestrates many agents, each running on its own compute node — natural fit for Slurm. Two env vars: `WANDB_SILENT=true` keeps your `.out` files clean; `WANDB_DIR=$SLURM_TMPDIR` puts run files on fast local storage during the job.

---

## Section: Testing for ML code

---

## Slide 37 — Reproducibility testing (tensor_regression)

We built a small pytest plugin called `tensor_regression`. You write a test that calls `tensor_regression.check(some_dict_of_tensors)`. On the first run it records summary statistics — shape, dtype, min/max/mean — into a YAML file you commit to git. On subsequent runs, deviations from those stats fail the test. So you can pin "this model's initialization, with seed 42, produces these statistics" — and any refactor that silently changes that gets caught.

---

## Slide 38 — Reproducibility: training step

Same pattern, applied to a full training step. Make the model, get a batch, run forward + backward + optimizer step, then check the loss, gradients, and resulting state. Now you have a regression test for your *entire training pipeline*. Refactor freely — if you broke something, the test tells you exactly what changed.

---

## Slide 39 — Test-Driven Debugging

Real story: a researcher had a custom op that worked at batch size 16 but blew up at 128. Step one: write a test that pins the forward and backward at both batch sizes — `tensor_regression` records what *correct* looks like at 16, and at 128 you have a clear failure. Now you can iteratively debug knowing exactly when you've fixed it and exactly when you've regressed something else. This pattern turns mysterious numerical bugs into ordinary engineering problems.

---

## Slide 40 — GitHub CI + Slurm Clusters

This one's a bit experimental — I've never seen anyone else do it. Setup: a self-hosted GitHub runner sits on a machine with SSH access to the cluster. When a PR is approved, the runner SSHes in and `sbatch`es a job. That job starts an *ephemeral* GitHub runner on a GPU compute node, which runs your tests and reports back to GitHub. End result: your PR shows green or red CI checks based on actual GPU tests.

---

## Slide 41 — GitHub CI on Slurm — security

Two natural worries. Security: yes, somewhat — but PR workflows require maintainer approval before they can run, and CI runs as the user, no extra privileges. MFA: that's the trickier part. Two options — SSH multiplexing to reuse an authenticated session (hacky), or dedicated "robot" SSH keys restricted to just the `sbatch runner_job.sh` command (cleaner). Imperfect, but it works and the value is huge.

---

## Section: Debugging

---

## Slide 42 — Debugging Multi-GPU Jobs

For PyTorch DDP on a single node: VSCode's `debugpy` can launch `torch.distributed.run` directly. This launch.json drops you into a debugger with all your DDP ranks set up. Set breakpoints, inspect tensors, step through gradient sync — all the things you'd do for a single-process script, but with all the ranks live.

---

## Slide 43 — Debugging Multi-Node Jobs with VSCode

Multi-node is harder. Trick: launch `debugpy` on each task, each listening on a different port — `5678 + SLURM_PROCID`. Use `--wait-for-client` so the processes block until you attach. Then in VSCode, you attach to each rank one at a time. Awkward but it's the only way I know to get a real debugger into a multi-node job. Full launch config in the mila-docs link.

---

## Section: Performance Optimization

---

## Slide 44 — Understanding Hardware is Critical!

This is the most important diagram in the talk. Bandwidth between components varies by *orders of magnitude*. GPU-to-GPU via NVLink: ~600 GB/s. GPU-to-CPU via PCIe: ~32 GB/s — twenty times slower. Node-to-node via InfiniBand: ~200 GB/s. Every performance problem in ML training is, fundamentally, about which of these links you're saturating. Memorize this hierarchy — when something is slow, ask "which link is the bottleneck?" first.

---

## Slide 45 — Dataloader Bottlenecks

Most common bottleneck I see: low GPU utilization, even though the model is big and the batch is big. Look at the profiler timeline: GPU does a training step, then sits *idle* waiting for the next batch, then trains, then idle again. That gap is the CPU loading and preprocessing data synchronously. You're paying for an H100 to wait for `PIL.Image.open()`.

---

## Slide 46 — Dataloader Fix

Two-part fix. First: bump `num_workers` and enable `pin_memory` and `prefetch_factor` so the DataLoader pipelines batches in the background. Second: use a dedicated CUDA stream for the host-to-device copy with `non_blocking=True`. Now the next batch is being transferred *while* the GPU computes the current one. Free speedup, often 2-3x on data-heavy workloads.

---

## Slide 47 — Overlapped timeline

Same profiler timeline, after the fix. No more red gaps. GPU is always doing training, CPU is always prefetching the next batch. This is what you want every training run to look like. If it doesn't, the dataloader is your first suspect.

---

## Slide 48 — Using the filesystem efficiently

Two filesystems, very different characteristics. `$SLURM_TMPDIR` is a local SSD — fast, private, but disappears when the job ends. `$SCRATCH` is the shared network filesystem — slower per-operation but persistent. The rule: copy your dataset *into* `$SLURM_TMPDIR` at job start, write final results back to `$SCRATCH` at job end, and do all your intermediate I/O on the local SSD.

---

## Slide 49 — Filesystem best practices

Here's the pattern in three lines. Copy the dataset in, train against the local copy, copy the final results out. And the small-files warning bears repeating: a million JPEGs in a folder will destroy your throughput on the shared FS — every `open()` is a network round-trip. Use WebDataset, HDF5, or SQLite. Bundle and stream, don't scatter and seek.

---

## Slide 50 — RL With Simulation on CPU

Niche but painful. RL workloads with many CPU-based environment workers — each one uses NumPy. NumPy by default detects all available CPUs and grabs threads. So with N workers each spawning N threads, you have N² threads on N cores, all context-switching against each other. Adding workers makes it *slower*. The one-line fix: `export OMP_NUM_THREADS=1`. I've seen this give 10x speedups.

---

## Slide 51 — Mixing PyTorch and Jax

Sometimes you want JAX for some component and PyTorch for another. With `torch-jax-interop` — a library we built — you can convert between them with zero copy on the GPU using the dlpack protocol. Decorate your JAX function with `@jax_to_torch` and call it transparently from PyTorch code. Google also has `torchax` with a different design — both are worth knowing about.

---

## Slide 52 — Profiling with TensorBoard + Torch Profiler

How do you find your bottleneck? The PyTorch Profiler with TensorBoard's profiler plugin. The `schedule` controls when it records — skip warmup steps, then record N steps. The `tensorboard_trace_handler` writes traces in the right format. Call `prof.step()` every iteration so it knows where step boundaries are.

---

## Slide 53 — TensorBoard Profiler UI

Then `uvx --with=torch-tb-profiler tensorboard --logdir=./log/profiler` and open it in the browser. You get a GPU utilization timeline — idle gaps jump out immediately. Kernel breakdown — which ops dominate compute. Memory over time. Stack traces tied to specific operators. And VSCode auto-forwards the port, so if you're using `mila code` it just works on localhost.

---

## Slide 54 — DEMO

[Live demo: `mila code` to grab a job, run a small training script under the profiler, open TensorBoard, walk through the timeline live, identify a bottleneck and fix it.]

---

## Slide 55 — Efficient Checkpointing

For large multi-GPU models, `torch.distributed.checkpoint` is a huge win. Each rank writes its own shard *in parallel* — checkpoint I/O scales with GPUs instead of bottlenecking on rank 0. It supports resharding on load: train on 8 GPUs, restart on 16, no conversion step. And it's FSDP-aware out of the box. Catch the TorchTitan talk at this conference for more.

---

## Section: Ongoing work and open problems

---

## Slide 56 — cluv

`cluv` — short for "cluster + uv" — is something we're building right now. The idea: a single CLI to manage uv projects across multiple Slurm clusters. `cluv login` for auth, `cluv sync` to keep your project in sync everywhere, `cluv submit <cluster> job.sh` to dispatch, and `cluv submit first` to send the same job to multiple clusters and take whichever schedules first. Early days but very promising.

---

## Slide 57 — Research Template Repository

We also maintain a research template repository at the link shown. It bakes in everything from this talk: uv setup, code checkpointing, tensor regression tests, the GitHub CI on Slurm setup. The goal is: clone it, change the model code, and you have all the infrastructure for free.

---

## Slide 58 — AutoResearch

And the speculative future-y one: AutoResearch. An LLM agent that drives experiments on Slurm. Hypothesize, submit, monitor, analyze, repeat. Slurm is actually a great substrate for this because it's a clean, sandboxed interface — the agent requests compute through the standard scheduler and inherits all the resource management and isolation. Work in progress at Mila, stay tuned.

---

## Slide 59 — Q&A

Thanks everyone — happy to take questions on anything we covered, or anything else about Slurm clusters, the Mila environment, or what the IDT team is up to.
