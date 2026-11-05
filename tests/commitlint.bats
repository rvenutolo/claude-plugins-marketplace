# .commitlintrc.yml, through the devShell commitlint the commit-msg hook runs.
# The CI commitlint job runs the version bundled in its action, which these
# tests do not cover. Each test feeds one commit message on stdin and asserts
# the verdict. `--cwd` pins config discovery to the repo root, so the test sees
# the repo's config no matter where bats runs from.

function setup() {
  load 'test_helper/common'
}

# @description Run commitlint against the repo config on a message.
# @arg $1 message the full commit message
function lint() {
  run commitlint --cwd "${REPO_DIR}" <<< "$1"
}

@test "accepts an ordinary subject" {
  lint 'feat: add a flag'
  assert_success
}

@test "accepts a scoped subject" {
  lint 'fix(api): handle an empty list'
  assert_success
}

@test "accepts a breaking-change subject" {
  lint 'feat!: drop a flag'
  assert_success
}

@test "accepts a scoped breaking-change subject" {
  lint 'feat(api)!: drop a flag'
  assert_success
}

@test "accepts a revert subject" {
  lint $'revert: feat: add a flag\n\nThis reverts commit 0123456789abcdef0123456789abcdef01234567.'
  assert_success
}

@test "rejects a subject with no type" {
  lint 'drop a flag'
  assert_failure
  assert_output --partial 'type may not be empty'
}

@test "rejects an unknown type" {
  lint 'feature: add a flag'
  assert_failure
  assert_output --partial 'type must be one of'
}

# Without the issuePrefixes override, `#12` opens a footer and
# footer-leading-blank warns; the message still passes, so assert on the warning.
@test "does not read a mid-paragraph issue reference as a footer" {
  lint $'fix: handle an empty list\n\nThe parser mishandled this.\nSee #12 for the report on it.'
  assert_success
  refute_output --partial 'footer-leading-blank'
}

# footer-leading-blank is a warning in config-conventional, so the message
# passes; the test pins that the rule still sees the footer.
@test "warns on a BREAKING CHANGE footer with no blank line above it" {
  lint $'feat: drop a flag\n\nThe flag is gone.\nBREAKING CHANGE: the flag is gone'
  assert_success
  assert_output --partial 'footer must have leading blank line'
}

@test "warns on a BREAKING-CHANGE footer with no blank line above it" {
  lint $'feat: drop a flag\n\nThe flag is gone.\nBREAKING-CHANGE: the flag is gone'
  assert_success
  assert_output --partial 'footer must have leading blank line'
}
