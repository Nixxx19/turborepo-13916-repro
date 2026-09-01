# turbo hashes wrong when a file ends in .gitignore

Reproduction for https://github.com/vercel/turborepo/pull/13916.

Turbo treats any untracked file whose name ends in `.gitignore` as a real gitignore. Git does not. So a copied template like `packages/pkg/Node.gitignore` makes turbo skip the files it matches when hashing a package. Editing one of those files then does not change the task hash, and turbo restores old output from the cache.

Run it:

    ./repro.sh

`config.log` is untracked and git does not ignore it. Without the stray file turbo hashes it:

    hashed inputs: ['config.log', 'package.json']

With `packages/pkg/Node.gitignore` containing `*.log` it is gone:

    hashed inputs: ['Node.gitignore', 'package.json']

So the task hash does not change when you edit it:

    run 1:  cache miss, executing 1c9c997c7cd85f3f
    edit packages/pkg/config.log
    run 2:  cache hit, replaying logs 1c9c997c7cd85f3f
    source on disk:   v2-CHANGED
    restored output:  v1

To check the fix, pass a turbo built from #13916:

    ./repro.sh /path/to/turborepo/target/debug/turbo

`config.log` stays in the inputs, run 2 is a miss, and the output matches the source.

The bug is in `find_untracked_files` in `crates/turborepo-scm/src/repo_index.rs`. It picks gitignore files with `ends_with(".gitignore")`. #13221 fixed the same thing for tracked files and left this one.
