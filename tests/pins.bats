# .ci/check-pins, against a fixture git remote and a fixture raw-content tree
# in BATS_TEST_TMPDIR. CHECK_PINS_REMOTE_BASE and CHECK_PINS_RAW_BASE point the
# script at them, so no test touches the network.
#
# The fixture remote holds two commits: v1.0.0 is a lightweight tag on the
# first, v2.0.0 an annotated tag on the second. The annotated tag's object sha
# differs from its commit sha, which is the case a pin must get right.
#
# `run --separate-stderr` is a bats 1.5.0 flag: the check prints every verdict
# on stderr.
bats_require_minimum_version 1.5.0

function setup() {
  load 'test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-pins"
  ROOT="${BATS_TEST_TMPDIR}/root"
  REMOTE="${BATS_TEST_TMPDIR}/remote/acme/widget"
  RAW="${BATS_TEST_TMPDIR}/raw"
  mkdir --parents "${ROOT}/.claude-plugin" "${REMOTE}"
  export CHECK_PINS_REMOTE_BASE="file://${BATS_TEST_TMPDIR}/remote"
  export CHECK_PINS_RAW_BASE="file://${RAW}"

  git -C "${REMOTE}" init --quiet
  git -C "${REMOTE}" config user.name 'Fixture'
  git -C "${REMOTE}" config user.email 'fixture@example.invalid'
  git -C "${REMOTE}" config commit.gpgsign false
  git -C "${REMOTE}" config tag.gpgsign false
  git -C "${REMOTE}" commit --quiet --allow-empty --message 'first'
  git -C "${REMOTE}" tag v1.0.0
  SHA_LIGHT="$(git -C "${REMOTE}" rev-parse HEAD)"
  git -C "${REMOTE}" commit --quiet --allow-empty --message 'second'
  git -C "${REMOTE}" tag --annotate --message 'release' v2.0.0
  SHA_ANNOTATED="$(git -C "${REMOTE}" rev-parse 'v2.0.0^{commit}')"
  TAG_OBJECT="$(git -C "${REMOTE}" rev-parse v2.0.0)"
}

# @description Write the fixture plugin.json served for a sha.
# @arg $1 sha the commit sha the file is served under
# @arg $2 name the plugin name
# @arg $3 version the plugin version
function serve_plugin_json() {
  local -r sha="$1" name="$2" version="$3"
  mkdir --parents "${RAW}/acme/widget/${sha}/.claude-plugin"
  printf '{"name": "%s", "version": "%s"}\n' "${name}" "${version}" \
    > "${RAW}/acme/widget/${sha}/.claude-plugin/plugin.json"
}

# @description Write the fixture marketplace.json with one object-sourced entry.
# @arg $1 ref the tag
# @arg $2 sha the pinned sha
function write_manifest() {
  local -r ref="$1" sha="$2"
  cat > "${ROOT}/.claude-plugin/marketplace.json" << JSON
{"name": "m", "plugins": [{"name": "widget",
  "source": {"source": "github", "repo": "acme/widget", "ref": "${ref}", "sha": "${sha}"}}]}
JSON
}

@test "pins: passes when sha is the lightweight tag's commit" {
  serve_plugin_json "${SHA_LIGHT}" widget 1.0.0
  write_manifest v1.0.0 "${SHA_LIGHT}"
  run --separate-stderr "${CHECK}" "${ROOT}"
  assert_success
  [[ "${stderr}" == *'OK:'* ]]
}

@test "pins: passes when sha is the annotated tag's peeled commit" {
  serve_plugin_json "${SHA_ANNOTATED}" widget 2.0.0
  write_manifest v2.0.0 "${SHA_ANNOTATED}"
  run --separate-stderr "${CHECK}" "${ROOT}"
  assert_success
}

@test "pins: fails when sha is the annotated tag object" {
  serve_plugin_json "${TAG_OBJECT}" widget 2.0.0
  write_manifest v2.0.0 "${TAG_OBJECT}"
  run --separate-stderr "${CHECK}" "${ROOT}"
  assert_failure 1
  [[ "${stderr}" == *'FAIL: widget:'* ]]
  [[ "${stderr}" == *"${TAG_OBJECT}"* ]]
  [[ "${stderr}" == *"${SHA_ANNOTATED}"* ]]
}

@test "pins: fails when ref tag does not exist" {
  write_manifest v9.9.9 "${SHA_LIGHT}"
  run --separate-stderr "${CHECK}" "${ROOT}"
  assert_failure 1
  [[ "${stderr}" == *'FAIL: widget:'* ]]
  [[ "${stderr}" == *'v9.9.9'* ]]
}

@test "pins: fails when plugin.json name differs from entry name" {
  serve_plugin_json "${SHA_LIGHT}" gadget 1.0.0
  write_manifest v1.0.0 "${SHA_LIGHT}"
  run --separate-stderr "${CHECK}" "${ROOT}"
  assert_failure 1
  [[ "${stderr}" == *'FAIL: widget:'* ]]
  [[ "${stderr}" == *'gadget'* ]]
  [[ "${stderr}" == *'widget'* ]]
}

@test "pins: fails when plugin.json version differs from ref" {
  serve_plugin_json "${SHA_LIGHT}" widget 1.0.1
  write_manifest v1.0.0 "${SHA_LIGHT}"
  run --separate-stderr "${CHECK}" "${ROOT}"
  assert_failure 1
  [[ "${stderr}" == *'FAIL: widget:'* ]]
  [[ "${stderr}" == *'1.0.1'* ]]
  [[ "${stderr}" == *'v1.0.0'* ]]
}

@test "pins: fails when source is a string or lacks sha or ref" {
  cat > "${ROOT}/.claude-plugin/marketplace.json" << JSON
{"name": "m", "plugins": [
  {"name": "as-string", "source": "./"},
  {"name": "no-sha", "source": {"source": "github", "repo": "acme/widget", "ref": "v1.0.0"}},
  {"name": "no-ref", "source": {"source": "github", "repo": "acme/widget", "sha": "${SHA_LIGHT}"}}
]}
JSON
  run --separate-stderr "${CHECK}" "${ROOT}"
  assert_failure 1
  [[ "${stderr}" == *'FAIL: as-string:'* ]]
  [[ "${stderr}" == *'FAIL: no-sha:'* ]]
  [[ "${stderr}" == *'FAIL: no-ref:'* ]]
}

@test "pins: reports unreachable remote as FAIL not a crash" {
  export CHECK_PINS_REMOTE_BASE="file://${BATS_TEST_TMPDIR}/does-not-exist"
  write_manifest v1.0.0 "${SHA_LIGHT}"
  run --separate-stderr "${CHECK}" "${ROOT}"
  assert_failure 1
  [[ "${stderr}" == *'FAIL: widget: cannot reach acme/widget'* ]]
  [[ "${stderr}" != *'ERROR:'* ]]
}

@test "pins: exits 2 on a surplus argument" {
  run --separate-stderr "${CHECK}" "${ROOT}" extra
  assert_failure 2
  [[ "${stderr}" == *'usage:'* ]]
}

@test "pins: reports invalid plugin.json as FAIL not a crash" {
  mkdir --parents "${RAW}/acme/widget/${SHA_LIGHT}/.claude-plugin"
  printf 'not json at all\n' > "${RAW}/acme/widget/${SHA_LIGHT}/.claude-plugin/plugin.json"
  write_manifest v1.0.0 "${SHA_LIGHT}"
  run --separate-stderr "${CHECK}" "${ROOT}"
  assert_failure 1
  [[ "${stderr}" == *'FAIL: widget:'* ]]
  [[ "${stderr}" == *'not valid JSON'* ]]
  [[ "${stderr}" != *'ERROR:'* ]]
  [[ "${stderr}" != *'parse error'* ]]
}

@test "pins: reports a non-object plugin.json as not a JSON object" {
  mkdir --parents "${RAW}/acme/widget/${SHA_LIGHT}/.claude-plugin"
  printf '[]\n' > "${RAW}/acme/widget/${SHA_LIGHT}/.claude-plugin/plugin.json"
  write_manifest v1.0.0 "${SHA_LIGHT}"
  run --separate-stderr "${CHECK}" "${ROOT}"
  assert_failure 1
  [[ "${stderr}" == *'FAIL: widget:'* ]]
  [[ "${stderr}" == *'is not a JSON object'* ]]
  [[ "${stderr}" != *'not valid JSON'* ]]
}

@test "pins: ignores url rewrites in the user's git config" {
  # test_helper/common points GIT_CONFIG_GLOBAL at /dev/null; this test swaps in
  # a config that rewrites the fixture remote to an unreachable URL, so the
  # check only passes when it ignores user config.
  printf '[url "file:///nonexistent/"]\n\tinsteadOf = %s/\n' "file://${BATS_TEST_TMPDIR}/remote" \
    > "${BATS_TEST_TMPDIR}/gitconfig"
  export GIT_CONFIG_GLOBAL="${BATS_TEST_TMPDIR}/gitconfig"
  serve_plugin_json "${SHA_LIGHT}" widget 1.0.0
  write_manifest v1.0.0 "${SHA_LIGHT}"
  run --separate-stderr "${CHECK}" "${ROOT}"
  assert_success
  [[ "${stderr}" == *'OK:'* ]]
}

@test "pins: reports an unfetchable plugin.json as FAIL" {
  write_manifest v1.0.0 "${SHA_LIGHT}"
  run --separate-stderr "${CHECK}" "${ROOT}"
  assert_failure 1
  [[ "${stderr}" == *'FAIL: widget:'* ]]
  [[ "${stderr}" != *'ERROR:'* ]]
}
