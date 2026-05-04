#import "@preview/touying:0.5.3": *
#import "@preview/gh-minimal-slides:0.1.0" as gh
// #import "gh-theme/lib.typ" as gh
// #import "@preview/touying:0.7.3": *
// #import themes.simple: *
#show: gh.register.with(
  theme: "light", accent: "green",
  title: [Tips and Tricks for a Productive Research Workflow],
)

#gh.cover-slide(
  title: [Tips and Tricks for a Productive Research Workflow],
  badges: (("MIT license", "accent"), "docs"),
  footer-left: "Fabrice Normandin · Upper Bound 2026",
)

// #gh.content-slide(title: [Unordered list])[
// - Mix freely with prose, like `npm install`.
// - Links inherit the accent color — #gh.gh-link[see reference →]
// ]

#gh.content-slide(title: [Outline])[
- Intro (10min)
- Software Ergonomics: a Productive Research Setup (20 min)
- Performance Optimization: Getting results, fast! (10-15 mins)
- Case studies (20-30min):
  - Real Examples of sub-optimal workflows → diagnostic → fix → Outcome
- Ongoing work and open problems (10-15min)
- Q&A
]

#gh.section-slide(
  number: "01",
  kicker: "Intro",
  title: [Introduction],
)

#gh.content-slide(title: [Code block])[
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
]




#gh.section-slide(
  number: "02",
  kicker: "Chapter",
  title: [Software Ergonomics: a Productive Research Setup],
)

#gh.content-slide(title: [Software Ergonomics])[
- RL + multiprocessing on the CPU
- Efficient checkpointing / data sharing
]
