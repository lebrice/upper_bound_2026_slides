# Speaker Notes — Efficient Research with Slurm Compute Clusters

**Upper Bound 2026 — Fabrice Normandin (Mila IDT)**

> Time budget: ~1 minute per slide max. Most slides much less. Section-divider slides ("§") are 5–10s flips. "(continued)" pages are pagebreaks within the same logical slide — keep those short.
>
> Audience reminder: ~8k attendees overall; this room self-selects to the technical research subset. Still expect ~35% industry / startup / non-Mila — lead with *the problem*, not the syntax. Many will not know Slurm intimately, and few will know Mila/IDT.

---

## Slide 1 — Title

Hi everyone — Fabrice Normandin from Mila's Innovation, Development and Technology team. This is a grab-bag of tips and tricks we've collected from working with researchers on Slurm clusters every day. No grand narrative — pick what's useful and ignore the rest.

---

## Slide 2 — About this presentation

The goal here is friction reduction: things you can apply Monday morning to make your research cycle faster. Most of it generalizes beyond Mila — DRAC, Amii's clusters, your company's private cluster, anything Slurm-ish. Slides and code are on GitHub (left QR). Live questions on Slido (right QR) — I'll glance at it during transitions.

---

## Slide 3 — Outline

Quick map: Introduction, then connection tools, environment management, job submission, job management, ML coding patterns, testing, debugging & profiling, then some ongoing work. Sit back, ask questions whenever. Sections stand alone, so if a topic isn't relevant just wait for the next.

---

## Slide 4 — § Introduction

[Section divider — flip through fast.]

---

## Slide 5 — About Mila

Since most of you aren't from Mila: Mila is the AI research institute in Montreal, founded in 2018 to bring researchers from local universities together — Yoshua Bengio was the scientific director, Hugo Larochelle now too. Today: ~160 professors, ~1150 students mostly PhD-level, ~185 employees, 145 industry partners. We're one of the larger academic AI institutes globally — and we run our own compute cluster.

---

## Slide 6 — About our team (IDT)

I sit on the Innovation, Development and Technology team. Our mandate is helping researchers use compute resources efficiently — we build software tools, write docs, run tutorials, and do a lot of in-person help. About me personally: former Mila student, came back as staff four years ago, drifted through GANs → continual learning → deep RL and LLMs. The goal driving most of what you'll see today: build the most efficient ML research setup, and actually use it.

---

## Slide 7 — Canadian Compute Clusters

Quick map of what's available in Canada — relevant if you're a Canadian researcher or collaborating with one. Mila has mixed GPUs, internet access on compute nodes, preemptible long jobs. The DRAC clusters — Rorqual, Fir, Nibi, Trillium — are bigger but more restricted, often no internet on compute nodes. Tamia and Trillium enforce full-node allocations. Killarney and Vulcan are heavy on L40S. The H100-equivalent column is the rough yardstick. The point: each cluster has its quirks, and your workflow should let you move between them without rewriting things.

---

## Slide 8 — § Connecting to Compute Clusters

[Section divider — flip through fast.]

---

## Slide 9 — milatools

`milatools` is a small Python package we built. Anyone can install it: `uv tool install milatools`. Two commands matter. `mila init` sets up your SSH config and gives tailored access instructions for Mila and DRAC. `mila code` is the daily-driver: launches an interactive Slurm job and opens VSCode attached to the compute node. Crucially: `mila code` works with *any* SSH-accessible Slurm cluster, not just Mila's — point it at your company cluster and it works.

---

## Slide 10 — mila code

Here's the canonical command: give me one GPU, 16 GB of RAM, six hours, open `my_project` in VSCode. Under the hood it runs `salloc`, waits for the job to start, then launches VSCode Remote-SSH through the allocated node. Attach to an existing job with `--job <jobid>` — useful when a long run is happening and you want to poke at it. We'll do this live in the demo later.

---

## Slide 11 — mila-cpu SSH config entry

`mila init` also installs an SSH host called `mila-cpu`. `ssh mila-cpu` checks for a running CPU job by that name, attaches if found, otherwise submits a new one. The job sticks around 10 minutes after disconnect, so reconnects are instant. Slightly more "set and forget" than `mila code`. The same pattern works for `tamia-cpu`, `mila-gpu`, etc. — adapt to your cluster.

---

## Slide 12 — Typical Research Workflow — Mila

The loop in three steps. One: `mila code` to grab an interactive GPU. Two: develop in VSCode — the terminal is on the compute node, so running scripts is just running scripts. Three: once stable, switch to `sbatch` for longer or wider runs. Same loop, different cluster — `--cluster=<name>`. One mental model, all the clusters.

---

## Slide 13 — § Python Environment Management with uv

[Section divider — flip through fast.]

---

## Slide 14 — uv

If you take one thing away today: **try uv.** Rust-based Python package manager, an order of magnitude faster than pip, and lockfiles actually work. `uv init`, `uv add`, `uv sync`, `uv run` — that's basically the API. `uv run` transparently re-syncs first. Avoid `uv pip` and `uv venv` — those are pip-compat escape hatches that bypass dependency tracking. Two flags to remember: `--offline` for DRAC compute nodes, `--directory` for code checkpointing. Quick note for the container-curious: for most Python-only workflows, uv is dramatically simpler than Apptainer/Singularity — no image build step, no bind-mount juggling, no rebuild for a one-line dep change. Reach for containers only when you need system libraries or non-Python toolchains.

---

## Slide 15 — uv + PyTorch / CUDA dependencies

Where uv really shines for ML. Different clusters have different CUDA versions. With uv you declare both as extras — `cuda128`, `cuda130` — mark them mutually exclusive, pull each from the right PyTorch index. Then on cluster A you `uv sync --extra=cuda128`, on cluster B `--extra=cuda130`. Same lockfile, same code, same `pyproject.toml`. No more conda environments diverging in mysterious ways. This is the killer feature for multi-cluster work.

---

## Slide 16 — Using uv on DRAC Clusters

Quick disclaimer: DRAC doesn't officially support uv yet — but it works. They maintain a wheelhouse — pre-built wheels optimized for their environment. Trick: make the wheelhouse the *default* index and use PyPI only when needed. Once you sync on a login node, compute nodes resolve everything from cache without internet. Right column: some packages — mpi4py, opencv, pyarrow, rdkit — are only available as DRAC modules. Use `tool.uv.sources` to override per-package and pull them from PyPI for portability.

---

## Slide 17 — DRAC wheelhouse alternative pattern (continued)

If you're not full-DRAC, the inverse pattern works: use PyPI by default, but pull specific painful packages from the DRAC wheelhouse — `flash-attn` being the prime example. Same `pyproject.toml`, just `explicit = true` on the wheelhouse index.

---

## Slide 18 — Example: UV + Flash-attn (Solution 1)

Concrete example. Flash-attention is notorious — wheels aren't always pre-built, source builds use hundreds of threads and take forever. If you trigger one on a login node you'll be *that person* the sysadmins hate. Solution 1 — use the prebuilt wheel from the DRAC wheelhouse. Works only on DRAC, but it's instant.

---

## Slide 19 — Flash-attn Solution 2: build from source (continued)

Solution 2 — build from source, but use uv's `extra-build-variables` feature to control the build environment. Cap `MAX_JOBS` to 1 so you don't spawn 200 compile threads, set the right CUDA arch, uv passes those env vars *only* when building that one package. Clean, declarative, reproducible.

---

## Slide 20 — § Submitting Jobs

[Section divider — flip through fast.]

---

## Slide 21 — Slurm Basics

Three commands. `sbatch` submits a batch job — resources plus script, runs unattended. `salloc` is the same but interactive — drops you on the compute node. `srun` runs a command, typically *inside* a job, once per task. People sometimes use `srun` to create jobs directly — don't, it's brittle. Use `sbatch` or `salloc` to create the allocation, `srun` to execute things within it.

---

## Slide 22 — `srun` is all you need!

This is the slide I want everyone to remember. **Inside a job, always launch your command with `srun`.** It handles binding tasks to GPUs, partitioning CPUs and memory, setting variables like `SLURM_PROCID`. Skip it and you can end up with all four tasks fighting over the same GPU. You usually don't need `torchrun` or `accelerate launch` — `srun` already does the right thing. Niche features: `--multi-prog` runs different commands per task, and you can request heterogeneous resources per task.

---

## Slide 23 — Example: Easy Job Packing with `srun`

Two patterns. First: `srun --ntasks-per-gpu=2` runs your script twice per GPU — on a 4-GPU node that's 8 parallel runs from one command. Use `SLURM_PROCID` inside Python to seed each one differently — free multi-seed runs. Second: `srun --multi-prog` with a one-line-per-task file lets you do hyperparameter sweeping with zero infrastructure.

---

## Slide 24 — Easy job submission

The anti-pattern: one job script per experiment configuration — `job_lr01.sh`, `job_lr001_nlayers32.sh`, dozens of them. The fix: one generic `job.sh` that forwards `"$@"` to the Python script, and pass the config as command-line arguments to `sbatch`. One file, infinite experiments. This pattern is the foundation for everything we'll do with dependencies next.

---

## Slide 25 — § Job Management

[Section divider — flip through fast.]

---

## Slide 26 — Use Job Dependencies to prevent waste

Scenario: hyperparameter sweep, then train once with the best config. If you naively `sbatch` the final job, it runs regardless of whether the sweep succeeded — wasting GPU hours when something crashed. Capture sweep IDs with `--parsable`, submit the follow-up with `--dependency=afterok:<ids>` plus `--kill-on-invalid-dep=yes`. Build pipelines, not isolated submissions.

---

## Slide 27 — Job Chunking: Get scheduled faster

The scheduler favors short jobs. A 24-hour job sits in the queue much longer than 8 three-hour chunks. If your code checkpoints properly — which we'll get to — submit a chain. Easiest form: a job array with `%1` so only one runs at a time, and use `SLURM_ARRAY_JOB_ID` as a stable identifier (e.g. for WandB run IDs).

---

## Slide 28 — Job Chunking via dependency chain (continued)

Alternative: chain manually with `--dependency=afterok` for each chunk. Inside Python you can read `SLURM_JOB_DEPENDENCY` to find the previous chunk's job ID and locate its checkpoint. Same total compute, much faster time-to-first-result, survives maintenance windows.

---

## Slide 29 — Use a Flexible Job Layout

On clusters that allow partial-node allocations, give Slurm flexibility. Instead of "two full nodes, four GPUs each" — which demands two specific full nodes — say "1 to 4 nodes, 8 GPUs total, prefer one switch." The scheduler finds a fit faster. The `--switches=1@3600` form means "prefer one switch, but give up waiting after an hour." Goal: minimize *queue time + runtime*, not runtime alone. This is often worth the experimentation.

---

## Slide 30 — Checkpointing is a must!

Proper checkpointing is non-negotiable. It unlocks: long jobs on preemptible partitions like Mila's, the job-chunking trick we just saw, resilience to hardware failures and bugs. For large multi-GPU models, use PyTorch's Distributed Checkpointing — every rank writes its own shard in parallel. The async mode overlaps I/O with training, so cost is nearly free. There's a TorchTitan talk at this conference that goes deeper.

---

## Slide 31 — Graceful Preemption

Preemptible clusters like Mila kill your job when something higher-priority shows up — but Slurm sends a signal *first*. Set `--signal=B:USR1@60` and you get a SIGUSR1 sixty seconds before the kill. Catch it in Python, flush a final checkpoint, exit with code 0, and `--requeue` makes Slurm automatically resubmit. Combine that with a deterministic run ID — say, `SLURM_JOB_ID` driving your WandB resume — and a preempted run is indistinguishable from a continuous one. This is the unlock for "I want to run a 5-day job on a preemptible 3-hour partition."

---

## Slide 32 — Code Checkpointing

Subtle bug I've seen many times. You `sbatch` job A. While it sits in the queue, you edit your code. You `sbatch` job B. Job A finally starts using your *modified* code. Results are mysteriously inconsistent and you can't reproduce them. The fix is two parts: refuse to submit when the working tree is dirty, and have the job clone the exact commit at submission time.

---

## Slide 33 — safe_sbatch (continued)

The first piece: a six-line bash wrapper around `sbatch` that bails if `git status --porcelain` shows anything, then exports the current commit hash for the job. Prevents an entire category of "wait, why isn't this reproducing" bugs.

---

## Slide 34 — Job script with code checkpointing (continued)

The second piece: the job's first action is `srun` once per node to clone the project into `$SLURM_TMPDIR`, check out the recorded commit, and `uv sync` to recreate the environment from cache. After that, the training command runs against frozen code. Works offline on DRAC because uv rebuilds from cache. The code that runs is the code you submitted — guaranteed.

---

## Slide 35 — § Writing Better ML Code

[Section divider — flip through fast.]

---

## Slide 36 — Einops

Show of hands — who has written a `.reshape().permute().reshape()` chain and come back to it a month later wondering what it does? Yeah. `einops` lets you write the same operation as a string of named axes. The right column reads as "batch, channels, height-and-patch, width-and-patch, rearrange to batch, patches, patch-pixels." Months later you still understand it.

---

## Slide 37 — More einops (continued)

Beyond `rearrange`: `reduce` for aggregations, `repeat` for broadcasting, `einsum` for general contractions, and Layer modules — `Rearrange`, `Reduce`, `EinMix` — you drop into `nn.Sequential`. einops.rocks has interactive docs. Pair it with `jaxtyping`, coming up next.

---

## Slide 38 — Jaxtyping

`jaxtyping` puts shapes and dtypes directly into type hints. Works for PyTorch, JAX, and NumPy. `Float[Tensor, "dim1 dim2"]` says "floating-point tensor with two named axes." The function signature now documents the contract: shapes align on `dim2`, output combines `dim1` and `dim3`. Self-documenting and machine-checkable.

---

## Slide 39 — Jaxtyping runtime checks (continued)

Where it gets powerful: combine with `beartype` or `typeguard` and shape annotations are *checked at runtime*. Wire it into your pytest config and every test exercises shape validation for free. Catches an entire class of "I broadcast the wrong dim" bugs. Also useful as an inline assert on intermediate tensors.

---

## Slide 40 — Jaxtyping self-references (continued)

You can reference instance attributes or function arguments inside the annotation — `{self.in_dims}`, `{self.out_dims}`. So the MLP literally declares: "I take a batch with `in_dims` features and return one with `out_dims` features." Wrong shape? Runtime check raises immediately with a clear message. No more silent broadcasting.

---

## Slide 41 — Jaxtyping + einops (SwiGLU)

Putting it together — a SwiGLU block from a modern transformer. Forward signature locks in input and output shapes. Inside, einops splits the fused gate/up projection in one line. The whole thing fits on a slide, is fully type-checked, reads like a specification. This is what I want my ML code to look like.

---

## Slide 42 — TensorDict

Quick mention. `TensorDict` is a dict-like container where every value is a tensor that shares a batch dimension. `.to("cuda")` moves them all together, slicing slices them all, `torch.stack` works. Especially useful in RL where you carry around obs/action/reward/done bundles everywhere. PyTorch project — battle-tested.

---

## Slide 43 — tensorclass

If you don't like the dict ergonomics, `@tensorclass` turns a dataclass into the same thing — typed attribute access, IDE autocomplete. Same tensor-like batch operations. Drop-in replacement for ad-hoc namedtuples or dicts.

---

## Slide 44 — Config / Argument Parsing

Three recommendations, simplest to most complex. **SimpleParsing**: dataclass-based, lightweight extension of argparse — full disclosure, I wrote it. **Tyro**: similar idea, more widely used, slightly less flexible but plenty good. **Hydra**: heavy, steep learning curve, somewhat unmaintained — *avoid unless* you really need its composition story across many datasets and models. Lots of other good options out there too — the worst choice is hand-rolled argparse for a complex project.

---

## Slide 45 — Weights & Biases (WandB)

If you don't use WandB yet, try it. The basic flow is fine; what's worth highlighting is two patterns. First: stuff your `SLURM_*` environment variables into the wandb config. Now every run records its job ID, partition, node, GPU type. When you're chasing a flaky result months later, you can ask "was this a specific node?" right from the UI. Second: use `resume="allow"` and an `id` derived from the Slurm job ID — this makes job-chunking and re-runs work transparently.

---

## Slide 46 — WandB + job packing (continued)

Combine with the `srun --ntasks-per-gpu` job packing trick: derive the run id from `SLURM_JOB_ID` + `SLURM_PROCID`, and use `SLURM_JOB_ID` as the `group`. All seeds from one launch end up grouped together in the UI — clean comparison without manual tagging.

---

## Slide 47 — WandB offline mode (continued)

DRAC compute nodes have no internet. WandB still works: `export WANDB_MODE=offline` (and `UV_OFFLINE=1` while you're at it), runs accumulate locally, `wandb sync --sync-all` from the login node afterward. You don't lose anything.

---

## Slide 48 — WandB Artifacts & Sweeps (continued)

Two more features worth knowing. **Artifacts**: version your checkpoints and datasets with provenance — wandb knows which run produced which checkpoint. **Sweeps**: controller plus agents, natural fit for Slurm — submit a wandb agent on each compute node. Two env vars worth setting: `WANDB_SILENT=true` keeps `.out` files clean, `WANDB_DIR=$SLURM_TMPDIR` puts run files on fast local storage.

---

## Slide 49 — § Testing for ML code

[Section divider — flip through fast.]

---

## Slide 50 — Reproducibility testing

We built a small pytest plugin called `tensor_regression`. You write a test that calls `tensor_regression.check(some_dict)`. On the first run it records summary stats — shape, dtype, min/max/mean — into a YAML file you commit. On subsequent runs, deviations fail the test. You can pin "this model's initialization, seed 42, produces these stats" — and any refactor that silently changes that is caught immediately.

---

## Slide 51 — Reproducibility: training step (continued)

Same pattern applied to a full training step. Make the model, get a batch, do forward + backward + optimizer step, check the loss, gradients, and resulting state. You now have a regression test for your entire training pipeline. Refactor freely — anything that broke gets flagged with exactly what changed.

---

## Slide 52 — Test-Driven Debugging

Real story: a custom op worked at batch size 16, OOM'd at 128. Step one: write a test pinning the forward and backward at both — `tensor_regression` records correct behavior at 16, and at 128 you have a clear failure. Now you can iteratively debug, knowing precisely when you've fixed it and when you've regressed something else. Turns mysterious numerical bugs into ordinary engineering.

---

## Slide 53 — GitHub CI + Slurm Clusters

This one I haven't seen elsewhere. Setup: a self-hosted GitHub runner sits on a machine with SSH access to the cluster. When a PR is approved, the runner SSHes in and `sbatch`es a job. That job starts an *ephemeral* GitHub runner on a GPU compute node, runs your tests, reports back. End result: your PR shows green or red CI based on real GPU tests. Example from our research template repo.

---

## Slide 54 — GitHub CI security & MFA (continued)

Two natural worries. Security: yes, somewhat — but PR workflows require maintainer approval, and CI runs as the user with no extra privileges. MFA: trickier. Two options — SSH multiplexing to reuse an authenticated session (hacky but works), or dedicated "robot" SSH keys restricted to one command, `sbatch runner_job.sh` (cleaner). Imperfect, but the value is huge.

---

## Slide 55 — § Debugging & Profiling

[Section divider — flip through fast.]

---

## Slide 56 — Debugging Multi-GPU Jobs

For PyTorch DDP on a single node: VSCode's `debugpy` can launch `torch.distributed.run` directly. This launch.json drops you into a debugger with all DDP ranks live. Breakpoints, tensor inspection, step through gradient sync — same things you'd do for a single-process script, but with every rank attached.

---

## Slide 57 — Debugging Multi-Node Jobs with VSCode

Multi-node is harder. Trick: launch `debugpy` on each task, each listening on a different port — `5678 + SLURM_PROCID`. Use `--wait-for-client` so processes block until you attach. Then in VSCode, attach to each rank one at a time. Awkward but it's the only way I know to get a real debugger into a multi-node job. Full launch config link on the slide.

---

## Slide 58 — Profiling with TensorBoard + Torch Profiler

How do you find your bottleneck? PyTorch's profiler with the TensorBoard plugin. The `schedule` skips warmup steps then records N. `tensorboard_trace_handler` writes traces in the right format. Call `prof.step()` every iteration so it knows step boundaries.

---

## Slide 59 — TensorBoard Profiler UI (continued)

Then `uvx --with=torch-tb-profiler tensorboard --logdir=logs` and open in the browser. GPU utilization timeline — idle gaps jump out. Kernel breakdown — which ops dominate. Memory over time. Stack traces tied to operators. And VSCode auto-forwards port 6006, so with `mila code` you just open localhost in your browser.

---

## Slide 60 — DEMO (continued)

[Live demo: `mila code` to grab a job, run a small training script under the profiler, open TensorBoard, walk through the timeline, identify a bottleneck and fix it. If demo gods are unkind, skip and reference the screenshots.]

---

## Slide 61 — Dataloader Bottlenecks

Easiest bottleneck diagnostic in the world: wrap your training loop in `tqdm` with `unit="samples"`, run once with training and once with `continue` skipping training. If the numbers are similar, your dataloader is the bottleneck. If non-training is much faster, your model is the bottleneck. Two lines of code, immediate diagnosis.

---

## Slide 62 — Dataloader profiler timelines (continued)

The picture: `num_workers=0` means GPU trains, then sits idle waiting for the next batch, then trains, then idle. That gap is the CPU loading and preprocessing synchronously — you're paying for an H100 to wait for `PIL.Image.open`. Bottom row: with `num_workers=4` and `pin_memory=True`, the next batch loads *while* the GPU computes the current one. GPU stays busy. Free 2–3x on data-heavy workloads.

---

## Slide 63 — CUDA Streams + `non_blocking=True`

To squeeze out the last bit of overlap: dedicated CUDA stream for the host-to-device transfer with `non_blocking=True`. Transfer happens on a different stream than training, so neither blocks the other unnecessarily. This is genuinely tricky to get right — read the PyTorch pinned-memory guide linked on the slide before applying. But the gain on memory-bound workloads is real.

---

## Slide 64 — CUDA Streams + FFCV/DALI mention (continued)

If after all of that you're *still* GPU-starved — usually vision-heavy workloads with heavy JPEG decoding — two industrial-strength options. **FFCV** (libffcv) and **NVIDIA DALI** both replace PyTorch's `DataLoader` with much faster, GPU-aware pipelines. They cost some integration work — custom dataset format for FFCV, learning a new graph API for DALI — but for production-scale vision they're often the only way to keep H100s fed.

---

## Slide 65 — `torch.compile` + Mixed Precision

This is the cheapest 2-to-4× speedup most people leave on the table. Three lines. First: `torch.set_float32_matmul_precision("high")` — turns on TF32 on Ampere and newer, free 2× on matmuls. Second: `model = torch.compile(model)` — JITs your model into fused kernels. The first step is slow because of compilation; everything after is much faster. Third: wrap your forward in `torch.amp.autocast("cuda", dtype=torch.bfloat16)` for mixed precision.

---

## Slide 66 — `torch.compile` continued

bf16 over fp16 — same dynamic range as fp32, no `GradScaler` headaches on Hopper or Ampere. `torch.compile` plays nicely with DDP and FSDP — use `mode="default"` for training, `"max-autotune"` for inference. And combining `torch.compile` with activation checkpointing — gradient checkpointing inside the model — cuts VRAM significantly, letting you push bigger batches or longer contexts. Pair it with the distributed checkpointing we'll see in a few slides.

---

## Slide 67 — Using the filesystem efficiently

Two filesystems, very different characteristics. `$SLURM_TMPDIR` is local SSD — fast, private per job, but vanishes when the job ends. `$SCRATCH` is the shared network FS — slower per operation but persistent. Match the filesystem to the access pattern.

---

## Slide 68 — Filesystem pattern (continued)

The recipe in three lines. Copy/extract the dataset into `$SLURM_TMPDIR` at job start. Train against the local copy. Copy final results back to `$SCRATCH`. And the small-files warning: a million JPEGs in a folder will destroy throughput on a shared FS — every `open()` is a network round-trip. Use WebDataset, HDF5, SQLite. Bundle and stream, don't scatter and seek.

---

## Slide 69 — RL With Simulation on CPU

Niche but painful — especially relevant to the Amii crowd here. RL workload with many CPU env workers, each running NumPy. NumPy by default detects all CPUs and grabs that many threads. So with N workers each spawning N threads, you've got N² threads on N cores, all context-switching. Adding workers makes it *slower*. One-line fix: `export OMP_NUM_THREADS=1`. I've seen 10x speedups from this alone.

---

## Slide 70 — Mixing PyTorch and Jax

Sometimes you want JAX for one component and PyTorch for another. With `torch-jax-interop` — Mila-built — you convert between them with zero copy on the GPU using the dlpack protocol. Decorate your JAX function with `@jax_to_torch` and call it transparently from PyTorch code. Google's `torchax` is a different design, also worth knowing.

---

## Slide 71 — Efficient Checkpointing

For large multi-GPU models, `torch.distributed.checkpoint` is a huge win. Every rank writes its own shard in parallel — checkpoint I/O scales with GPUs instead of bottlenecking on rank 0. Supports resharding on load — train on 8 GPUs, restart on 16, no conversion. FSDP-aware. Again, the TorchTitan talk at this conference goes deeper.

---

## Slide 72 — § Ongoing work and open problems

[Section divider — flip through fast.]

---

## Slide 73 — cluv

`cluv` — short for "cluster + uv" — is what we're building right now. Single CLI for uv projects across multiple Slurm clusters. `cluv login`, `cluv sync`, `cluv status`, `cluv submit <cluster> job.sh`. The fun one: `cluv submit first` dispatches to multiple clusters and keeps whichever schedules first. Early days, promising.

---

## Slide 74 — Research Template Repository

We also maintain a research template repository. Clone it and you get the GitHub-CI-on-Slurm setup, code checkpointing, tensor regression tests, uv setup — everything from this talk baked in. The goal: change the model code, get the infrastructure for free.

---

## Slide 75 — AutoResearch

The speculative future-y one. AutoResearch is an LLM agent that drives experiments on Slurm. The loop: LLM proposes an experiment, the agent `sbatch`es it, polls for completion, reads logs and metrics, the LLM interprets the results and decides what to try next.

---

## Slide 76 — AutoResearch (continued)

Step four is "repeat" — and the experiments get progressively more targeted as the knowledge base grows. The reason Slurm is the right substrate: it's a clean, sandboxed interface, and the agent inherits all the resource management and isolation for free. Work in progress at Mila — stay tuned.

---

## Slide 77 — § Q&A

Thanks everyone — happy to take questions on anything we covered, or anything else about Slurm clusters, the Mila environment, or what the IDT team is up to.
