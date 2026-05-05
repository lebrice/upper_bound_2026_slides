// #import "../lib.typ": *
#import "./diatypst.typ": *

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
  count: "dot", // one of "dot", "dot-section", "number", or none
  footer: true,
  theme: "normal",
  // footer-title: "FOOO 2026",
  footer-subtitle: "Upper Bound 2026",
  // theme: "full", // one of "normal", "full"
  // ... see the docs for more options
)


= Introduction

== What is a Compute cluster, really?

== Canadian Compute Clusters

== Slurm

== Typical Research Workflow - Mila

== Assumptions for the rest of the talk


= Tips & Tricks - Master Slurm and Get results, fast!

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

== Job Chunking: Break up long jobs to get scheduled faster <job_chunking>

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

== uv <uv>

== uv + DRAC Clusters


= Interactive Development

== milatools <milatools>

== mila code <mila-code>

== Smart SSH Config Entries: mila-cpu <mila-cpu>

== Debugging Multi-GPU Jobs

// Slide showing how to use `srun` + attaching the vscode debugger to each task, to have the VsCode debugger attached to each task in a multi-node setup.


== Debugging Multi-Node Jobs

// Slide showing how to use `srun` + attaching the vscode debugger to each task, to have the VsCode debugger attached to each task in a multi-node setup.

= Writing Great ML Code

== Einops

== Jaxtyping

== Weights & Biases (WandB)

= Performance Optimization

== Understanding Hardware is Critical!

// Slides describing the different data transfer bandwidth between the typical components of a compute cluster.
// For example: Tiers of GPU memory
// NvLink connections between GPUs (~600GB/s)
// NvMesh connections between nodes (~200GB/s)
= Case studies

- Real Examples of sub-optimal workflows → diagnostic → fix → Outcome

== RL With Simulation on CPU

== Efficient Checkpointing

== Test-Driven Debugging of PyTorch CUDA Code


= Ongoing work and open problems

= Q&A