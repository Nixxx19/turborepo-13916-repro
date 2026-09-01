# turbo drops untracked files from hashing when a sibling merely ends in `.gitignore`

Reproduction for https://github.com/vercel/turborepo/pull/13916.

A file that only *ends* in `.gitignore` (here `packages/pkg/Node.gitignore`, the
shape you get from a vendored github/gitignore template) is treated by turbo's
untracked walk as a real ignore file. Git attaches no meaning to it, but turbo
reads its patterns and drops the matching untracked files from package hashing.
Those files then never affect the task hash, so editing one is invisible and
turbo replays a cache entry built from different bytes.

## Run

```
./repro.sh
```

## What it shows

`config.log` is untracked and not ignored by git. Without the stray file it is
hashed:

```
hashed inputs: ['config.log', 'package.json']
```

Add `packages/pkg/Node.gitignore` containing `*.log` and it vanishes:

```
hashed inputs: ['Node.gitignore', 'package.json']
```

So editing it does not change the task hash and turbo restores stale output:

```
run 1:  cache miss, executing 1c9c997c7cd85f3f
edit packages/pkg/config.log
run 2:  cache hit, replaying logs 1c9c997c7cd85f3f
source on disk:   v2-CHANGED
restored output:  v1
```

## With the fix

Pass a turbo built from #13916 and the same script keeps `config.log` in the
inputs, run 2 is a cache miss, and the output matches the source:

```
./repro.sh /path/to/turborepo/target/debug/turbo
```

## Where

`find_untracked_files` in `crates/turborepo-scm/src/repo_index.rs` selects
ignore files with `ends_with(".gitignore")`. #13221 already established the
correct rule for the tracked walk and said so in its message: "Only files
literally named `.gitignore` contribute rules." The untracked walk kept the
loose test.
