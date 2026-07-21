# Git Restore Mtime Buildkite Plugin

[![Build status](https://badge.buildkite.com/24a8f173dbd8ce2122a378dbb2c8bd6ab2ee3d52d5f5580030.svg)](https://buildkite.com/jessexoc/buildkite-git-restore-mtime-plugin)

A [Buildkite](https://buildkite.com/) plugin that restores the modification time
(`mtime`) of checked-out files to the date of the last commit that touched each
file, using [`git-restore-mtime`](https://github.com/MestreLion/git-tools).

Git does not preserve file timestamps — every checkout stamps files with the
_current_ time. That defeats mtime-based caching and incremental build tools
(Make, Sphinx, Webpack, Bazel, rsync, etc.), which then rebuild everything on a
fresh agent. This plugin runs `git-restore-mtime` right after checkout so those
timestamps reflect real change history again.

The plugin runs in the `post-checkout` hook, so it applies before your command
steps execute.

## Example

Restore modification times for the whole repository:

```yaml
steps:
  - label: "🔨 Build"
    command: "make"
    plugins:
      - git-restore-mtime#v1.0.0: ~
```

Limit the restore to specific paths and use commit time instead of author time:

```yaml
steps:
  - label: "🔨 Build docs"
    command: "make -C docs html"
    plugins:
      - git-restore-mtime#v1.0.0:
          paths:
            - "docs"
            - "src"
          commit-time: true
```

By default the plugin runs `git-restore-mtime` from the
[`ghcr.io/jessexoc/git-restore-mtime`](Dockerfile) Docker image, so agents only
need Docker. Use the `tool-location` option to run a custom image or a
`git-restore-mtime` already installed on the agent:

```yaml
steps:
  - label: "🔨 Build"
    command: "make"
    plugins:
      # Use git-restore-mtime installed on the agent's PATH instead of Docker.
      - git-restore-mtime#v1.0.0:
          tool-location: "path"
```

## Options

All options are optional. With no configuration the plugin restores the mtime of
the entire work tree using author time.

### `paths` (array)

One or more [pathspecs](https://git-scm.com/docs/gitglossary#Documentation/gitglossary.txt-aiddefpathspecapathspec)
limiting which files are updated. Restores the whole work tree when omitted.

### `commit-time` (boolean)

Use the commit time instead of the author time. Maps to `--commit-time`.
Defaults to `false`.

### `first-parent` (boolean)

Only consider the first parent when evaluating merge commits. Maps to
`--first-parent`. Defaults to `false`.

### `skip-missing` (boolean)

Do not retry finding files in merge commits. Maps to `--skip-missing`. Defaults
to `false`.

### `merge` (boolean)

Include merge commits when evaluating file timestamps. Maps to `--merge`.
Defaults to `false`.

### `no-directories` (boolean)

Do not update the mtime of directories. Maps to `--no-directories`. Defaults to
`false`.

### `force` (boolean)

Update files even if they have uncommitted modifications. Maps to `--force`.
Defaults to `false`.

### `skip-older-than` (number)

Ignore files whose current mtime is already older than this many seconds. Maps
to `--skip-older-than`.

### `dry-run` (boolean)

Report what would change without modifying any timestamps. Maps to `--test`.
Defaults to `false`.

### `verbose` (boolean)

Print additional information per file. Maps to `--verbose`. Defaults to `false`.

### `quiet` (boolean)

Suppress informative messages and the summary. Maps to `--quiet`. Defaults to
`false`.

### `tool-location` (string)

Where to find `git-restore-mtime`. Defaults to `docker`.

| Value            | Behaviour                                                             |
| :--------------- | :------------------------------------------------------------------- |
| `docker`         | Run the `ghcr.io/jessexoc/git-restore-mtime` image (the default).    |
| `docker:<image>` | Run a custom image, e.g. `docker:example.com/git-restore-mtime:1.0`. |
| `path`           | Use `git-restore-mtime` found on the agent's `PATH`.                 |
| `path:<file>`    | Use the executable at an explicit path, e.g. `path:/opt/bin/grm`.   |

For the `docker` locations the checkout is bind-mounted at `/workdir` and any
flags and pathspecs are passed through to the container's entrypoint. A custom
image is expected to invoke `git-restore-mtime` as its entrypoint (as the
bundled [Dockerfile](Dockerfile) does).

> **Note:** Buildkite agents run on Linux, where bind-mounted timestamp writes
> work as expected. When testing the `docker` tool-location locally on **macOS**,
> Docker Desktop's virtiofs mounts may not persist `mtime` changes back to the
> host — use the `path` tool-location for local macOS testing.

## Docker image

A minimal Alpine-based image (`python3` + `git` + the `git-restore-mtime`
script, ~96 MB) backs the default `docker` tool-location and is published to
[`ghcr.io/jessexoc/git-restore-mtime`](https://github.com/jessexoc/buildkite-git-restore-mtime-plugin/pkgs/container/git-restore-mtime)
by the [build workflow](.github/workflows/docker-publish.yml). It is also
published to the Buildkite package registry
(`packages.buildkite.com/jessexoc/buildkite-git-restore-mtime-plugin/git-restore-mtime`)
by the [pipeline](.buildkite/pipeline.yml). It can also be used directly,
outside of Buildkite.

Build it (optionally overriding the pinned tool version):

```bash
docker build -t git-restore-mtime:latest .
docker build -t git-restore-mtime:latest \
  --build-arg GIT_TOOLS_REF=main \
  --build-arg GIT_RESTORE_MTIME_CHECKSUM=<sha256> .
```

Run it against a repository by mounting the work tree at `/workdir`. Any extra
arguments are passed straight through to `git-restore-mtime`:

```bash
docker run --rm -v "$PWD:/workdir" git-restore-mtime:latest
docker run --rm -v "$PWD:/workdir" git-restore-mtime:latest --commit-time --verbose
```

## Requirements

- `bash`
- Either `docker` (for the `docker` tool-location, the default) or a
  `git-restore-mtime` executable on the agent (for the `path` tool-location).

## Developing

Run the tests with the Buildkite plugin tester:

```bash
docker run -it --rm -v "$PWD:/plugin:ro" buildkite/plugin-tester:latest
```

Lint the plugin structure:

```bash
docker run -it --rm -v "$PWD:/plugin:ro" buildkite/plugin-linter --id git-restore-mtime --path /plugin
```

Run shellcheck:

```bash
shellcheck hooks/* lib/*.bash
```

## License

MIT (see [LICENSE](LICENSE)).
