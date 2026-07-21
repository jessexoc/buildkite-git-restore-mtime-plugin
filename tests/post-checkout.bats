#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # A throwaway work tree with a .git directory so the hook's git-repo check
  # passes without needing the git binary in the test image.
  TEST_REPO="$(mktemp -d)"
  mkdir -p "${TEST_REPO}/.git"
  export BUILDKITE_BUILD_CHECKOUT_PATH="${TEST_REPO}"

  # Directory for fake executables placed on PATH during tests.
  FAKE_BIN="${BATS_TEST_TMPDIR}/fake-bin"
  mkdir -p "${FAKE_BIN}"
}

teardown() {
  rm -rf "${TEST_REPO}"
}

# make_fake <name> [target-path]
# Creates an executable that prints the command name and its arguments, so tests
# can assert on how the hook invoked it.
make_fake() {
  local name="$1"
  local target="${2:-${FAKE_BIN}/${name}}"
  cat > "${target}" <<'SH'
#!/usr/bin/env bash
echo "FAKE $(basename "$0") args: $*"
SH
  chmod +x "${target}"
}

@test "Defaults to the ghcr.io/jessexoc/git-restore-mtime docker image" {
  make_fake docker
  export PATH="${FAKE_BIN}:${PATH}"

  run "$PWD"/hooks/post-checkout

  assert_success
  assert_output --partial 'Using git-restore-mtime from Docker image: ghcr.io/jessexoc/git-restore-mtime'
  assert_output --partial "FAKE docker args: run --rm -v ${TEST_REPO}:/workdir -w /workdir ghcr.io/jessexoc/git-restore-mtime"
  assert_output --partial 'File modification times restored'
}

@test "docker:<image> uses a custom image" {
  export BUILDKITE_PLUGIN_GIT_RESTORE_MTIME_TOOL_LOCATION='docker:example.com/mine:1.2.3'
  make_fake docker
  export PATH="${FAKE_BIN}:${PATH}"

  run "$PWD"/hooks/post-checkout

  assert_success
  assert_output --partial 'Using git-restore-mtime from Docker image: example.com/mine:1.2.3'
  assert_output --partial "FAKE docker args: run --rm -v ${TEST_REPO}:/workdir -w /workdir example.com/mine:1.2.3"
}

@test "docker mount and flags are passed through to the image" {
  export BUILDKITE_PLUGIN_GIT_RESTORE_MTIME_COMMIT_TIME='true'
  export BUILDKITE_PLUGIN_GIT_RESTORE_MTIME_PATHS_0='src'
  make_fake docker
  export PATH="${FAKE_BIN}:${PATH}"

  run "$PWD"/hooks/post-checkout

  assert_success
  assert_output --partial 'ghcr.io/jessexoc/git-restore-mtime --commit-time src'
}

@test "Fails when docker tool-location is set but docker is missing" {
  export PATH="${FAKE_BIN}:/usr/bin:/bin"

  run "$PWD"/hooks/post-checkout

  assert_failure 1
  assert_output --partial 'docker is not available on the agent'
}

@test "path finds git-restore-mtime on PATH" {
  export BUILDKITE_PLUGIN_GIT_RESTORE_MTIME_TOOL_LOCATION='path'
  make_fake git-restore-mtime
  export PATH="${FAKE_BIN}:${PATH}"

  run "$PWD"/hooks/post-checkout

  assert_success
  assert_output --partial 'Using git-restore-mtime found on PATH'
  assert_output --partial 'FAKE git-restore-mtime args:'
  assert_output --partial 'File modification times restored'
}

@test "path passes flags and pathspecs to the tool" {
  export BUILDKITE_PLUGIN_GIT_RESTORE_MTIME_TOOL_LOCATION='path'
  export BUILDKITE_PLUGIN_GIT_RESTORE_MTIME_DRY_RUN='true'
  export BUILDKITE_PLUGIN_GIT_RESTORE_MTIME_PATHS_0='docs'
  export BUILDKITE_PLUGIN_GIT_RESTORE_MTIME_PATHS_1='README.md'
  make_fake git-restore-mtime
  export PATH="${FAKE_BIN}:${PATH}"

  run "$PWD"/hooks/post-checkout

  assert_success
  assert_output --partial 'FAKE git-restore-mtime args: --test docs README.md'
}

@test "path:<file> uses an explicit executable" {
  local tool="${BATS_TEST_TMPDIR}/my-grm"
  make_fake git-restore-mtime "${tool}"
  export BUILDKITE_PLUGIN_GIT_RESTORE_MTIME_TOOL_LOCATION="path:${tool}"

  run "$PWD"/hooks/post-checkout

  assert_success
  assert_output --partial "Using git-restore-mtime at: ${tool}"
  assert_output --partial 'FAKE my-grm args:'
}

@test "path:<file> fails when the file is not executable" {
  export BUILDKITE_PLUGIN_GIT_RESTORE_MTIME_TOOL_LOCATION="path:${BATS_TEST_TMPDIR}/nope"

  run "$PWD"/hooks/post-checkout

  assert_failure 1
  assert_output --partial 'which is not an executable file'
}

@test "path finds nothing and fails clearly" {
  export BUILDKITE_PLUGIN_GIT_RESTORE_MTIME_TOOL_LOCATION='path'
  export PATH="${FAKE_BIN}:/usr/bin:/bin"

  run "$PWD"/hooks/post-checkout

  assert_failure 1
  assert_output --partial 'git-restore-mtime was not found on PATH'
}

@test "Skips gracefully when not in a git repository" {
  export BUILDKITE_BUILD_CHECKOUT_PATH="$(mktemp -d)"

  run "$PWD"/hooks/post-checkout

  assert_success
  assert_output --partial 'Not inside a git repository'

  rm -rf "${BUILDKITE_BUILD_CHECKOUT_PATH}"
}
