#!/usr/bin/env bash
# Exercises the FIRST HALF of .\wsl.ps1 build - the questions - with no Docker
# Desktop and no instance.
#
# fake-docker-run.ps1 puts a stand-in docker on the PATH: it answers the
# preflight and the first steps, then hands the import a file that is not a tar
# - so every run stops on the deployment-error path with the packs already
# chosen, the only path where the packs show without a real build.
#
# The conversation, in the order it runs: the name, the road (Dockerfile,
# image, registry), the source (the list, one answer, even for one row - the
# suite is not another checkout's checkout), the pack checklist, the
# onboarding, the account, and the two closing ticks. The folder question and
# the entry options left the build with the last refonte - a machine's own
# checkout is the assets folders now, and the window uploads into them - so
# the scenes that walked them are gone with them.
#
# What it proves:
#   - the pack checklist is asked after the name and the source, and before
#     the run goes on to the build - the shell pack opens ticked, applied
#     as-is it chooses it; cancelling means no pack, says so, and is asked no
#     confirmation
#   - the user name is asked with the other questions (after the checklist,
#     before the making), and refused names come back to the question - the
#     case ('Root'), and the leading underscore adduser would not take
#   - an empty answer takes the proposed Windows name, cleaned into one the
#     rule accepts
#   - the onboarding is asked with the rest ([Y/n] on an empty answer) and the
#     shell list follows it; on 'n' nothing of the onboarding is asked, the
#     account question included
#   - the registry road: a reference naming no host goes to Docker Hub's door,
#     one naming its host to the daemon's - each refusing and going on, the
#     question's own words the hint
#   - nothing is left behind: no instance, no tar, no folder, exit code 1
#
# Usage: bash tests/build-question-test.sh
#        PS_ENGINE=powershell bash tests/build-question-test.sh   (the old PowerShell)
set -u

TestsDir=$(cd "$(dirname "$0")" && pwd)
RepoTemplate=$(cd "$TestsDir/.." && pwd)
# powershell -File wants the Windows form of the path: the checkout may live
# anywhere, under a Git Bash that spells it /d/...
Run=$(cygpath -w "$TestsDir/fake-docker-run.ps1")
# The engine under test: PowerShell 7, or what PS_ENGINE names.
PS=${PS_ENGINE:-pwsh}
# The Windows account name the build proposes: dotted and cased, so the
# cleaning is exercised wherever the suite runs - the sandbox is not Windows.
export USERNAME="Jean.Dupont"

Failures=0
Out=$(mktemp)
# Where the checkout stands before the runs: they write nothing, and this is
# what says so - whether the tree is clean or carries work in progress. The
# seeds are the writes a run is meant to make (the first import fills
# assets\packs, assets\dockerfiles and assets\onboardings from src), so they
# are left out of the picture.
tree_state() {
    git -C "$RepoTemplate" status --short | grep -vE 'assets/(packs|dockerfiles|onboardings)' || true
}
Before=$(tree_state)

# The world the questions need: a fresh checkout has the assets folders empty,
# so the suite stages its own slots - two Dockerfiles of the Debian family (a
# list of one is taken without a question, and the scenes always answer one,
# so two), one onboarding, and the packs the checklist shows. Nothing already
# there is ever touched: the user's tree carries real ones, and only what this
# suite created is taken back out.
Assets="$RepoTemplate/assets"
Created=()
ensure_dir() { if [ ! -d "$1" ]; then mkdir -p "$1"; Created+=("$1"); fi; }
ensure_file() { if [ ! -f "$1" ]; then printf '%s\n' "$2" > "$1"; Created+=("$1"); fi; }
ensure_dir  "$Assets/dockerfiles/question-test-a"
ensure_file "$Assets/dockerfiles/question-test-a/Dockerfile" "FROM debian:bookworm-slim"
ensure_dir  "$Assets/dockerfiles/question-test-b"
ensure_file "$Assets/dockerfiles/question-test-b/Dockerfile" "FROM debian:bookworm-slim"
ensure_dir  "$Assets/onboardings/question-test"
ensure_file "$Assets/onboardings/question-test/onboarding.sh" "#!/bin/sh"
ensure_dir  "$Assets/packs/oh_my_shell"
ensure_file "$Assets/packs/oh_my_shell/pack.conf" "PACK_DESCRIPTION := The shell"
ensure_dir  "$Assets/packs/question-a"
ensure_file "$Assets/packs/question-a/pack.conf" "PACK_DESCRIPTION := A question test pack"

run_build() {
    printf '%b' "$1" | $PS -NoProfile -ExecutionPolicy Bypass -File "$Run" build > "$Out" 2>&1
    Code=$?
}

check() {
    if [ "$2" = "$3" ]; then
        echo "OK   $1"
    else
        echo "FAIL $1 : expected '$3', got '$2'"
        Failures=$((Failures + 1))
    fi
}

contains() { if grep -aqF "$1" "$Out"; then echo yes; else echo no; fi; }
line_of()  { grep -anF "$1" "$Out" | head -1 | cut -d: -f1; }
# Both lines must be there before their order means anything: a check comparing
# two empty strings answers yes and proves nothing - the shape of the mistake
# that once made a check unable to fail.
before() {
    local a b
    a=$(line_of "$1"); b=$(line_of "$2")
    if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then echo yes; else echo no; fi
}

# The road and its source, in answers: Dockerfile, then the row of OUR staged
# Dockerfile - read from a run that cancels, whatever else the checkout
# carries, so the family the checklist pre-ticks is the staged one's. The
# reads that follow are the checklist, the onboarding, the account, and the
# two closing ticks.
run_build 'qtest-read\n1\n0\n'
DockerfilePick=$(printf '%s' "$(sed -n '/^Dockerfile$/,/^   0\./p' "$Out" | grep 'question-test' | head -1 | sed -E 's/^ *([0-9]+)\..*/\1/')")
if [ -z "$DockerfilePick" ]; then DockerfilePick=1; fi
DOCKERFILE_ROAD="1\n$DockerfilePick"

echo "--- cancelled at the checklist (answer 0)"
# The user name is left empty: the proposed Windows name must be taken - the
# check on the hint is what says the empty was understood and not a refusal.
# The build then dies on the stand-in import, which is the end of every scene
# here.
run_build "pack-qtest-1\n${DOCKERFILE_ROAD}\n0\n\n1\n\n\n\n"
check "says no pack was selected"     "$(contains '[OK] No pack selected.')" "yes"
check "an empty answer takes the proposed name" "$(contains 'Lowercase letters, digits')" "no"
check "and the run goes on to the making" "$(contains 'could not be imported')" "yes"
check "exit code 1"                      "$Code" "1"

echo ""
echo "--- the pre-ticked shell, applied as-is (answer v, then the confirmation)"
run_build "pack-qtest-2\n${DOCKERFILE_ROAD}\nv\n\n1\n\n\n\n"
check "does not say no pack was selected" "$(contains '[OK] No pack selected.')" "no"
check "and the run goes on to the making" "$(contains 'could not be imported')" "yes"
check "exit code 1"                       "$Code" "1"

echo ""
echo "--- one pack chosen (2 = the second in the list) and confirmed"
# Two names the rule refuses first - 'Root' for the case, '_jean' for the
# leading underscore adduser would not take - so the question's own re-ask
# shows in the output. The Read-Host prompt itself cannot be asserted on -
# the runner's pwsh does not write it to a captured stream, a Write-Host does.
run_build "pack-qtest-3\n${DOCKERFILE_ROAD}\n2\nv\n\n1\nRoot\n_jean\nqtestuser\n\n\n"
check "the checklist arrives after the name and the source" "$(before 'Name of the instance' "Packs for 'pack-qtest-3'")" "yes"
check "the user name is asked after the checklist" "$(before "Packs for 'pack-qtest-3'" 'Lowercase letters, digits')" "yes"
check "and a refused name is asked again" "$(contains 'Lowercase letters, digits')" "yes"
check "both refused names come back to the question" "$(grep -ac 'Lowercase letters, digits' "$Out")" "2"
check "and the making starts only after it" "$(before 'Lowercase letters, digits' 'could not be imported')" "yes"
check "exit code 1" "$Code" "1"

echo ""
echo "--- the onboarding skipped (answer n): no account is asked for"
# 'Root' follows the 'n': if the account question were asked, the rule would
# refuse it and print the hint - with the onboarding off, nothing reads it.
run_build "pack-qtest-5\n${DOCKERFILE_ROAD}\n0\nn\nRoot\n\n\n"
check "says no pack was selected"         "$(contains '[OK] No pack selected.')" "yes"
check "the account question is not asked" "$(contains 'Lowercase letters')" "no"
check "and the run goes on to the making" "$(contains 'could not be imported')" "yes"
check "exit code 1"                       "$Code" "1"

echo ""
echo "--- the registry road: the Hub door and the host door, each refusing and going on"
# The third road takes a name from the registry - no list, no file to check.
# The reference decides which door validates it: one naming no host goes to
# Hub's API (the stand-in curl answers 200 for the one reference the scenes
# know, 404 for the rest - fake-docker\curl), one naming its host keeps the
# daemon's road (the stand-in docker refuses them all) - both with no network.
run_build 'reg-qtest-1\n3\nzrgzrg\nalpine:latest\n0\nn\n\n'
check "the road question offers the registry" "$(contains 'Docker registry')" "yes"
check "and asks for the reference"            "$(contains 'Docker image from a registry')" "yes"
check "an unknown name comes back to the question" "$(contains "Unknown registry image 'zrgzrg'")" "yes"
check "the Hub door's own words carry the why" "$(contains 'no such image or tag on Docker Hub')" "yes"
check "before the packs are asked"            "$(before "Unknown registry image" "Packs for 'reg-qtest-1'")" "yes"
check "the run reaches the making"            "$(contains 'could not be imported')" "yes"
check "exit code 1"                           "$Code" "1"

# A reference naming its host skips Hub's door and is asked of the daemon:
# the stand-in docker knows none, and the empty answer that follows is the
# question's own cancel.
run_build 'reg-qtest-2\n3\nexample.com/nope\n\n'
check "a host-named reference is refused" "$(contains "Unknown registry image 'example.com/nope'")" "yes"
check "with the daemon's words - not the Hub door's" "$(contains 'no such manifest: example.com/nope')" "yes"
check "an empty answer cancels the run"   "$(contains '[ABORT] Operation cancelled by user.')" "yes"
check "nothing is made"                   "$(contains 'could not be imported')" "no"
check "exit code 0"                       "$Code" "0"

echo ""
echo "--- nothing left on the machine"
check "no instance registered" "$(wsl.exe --list --quiet 2>/dev/null | tr -d '\0' | grep -ac 'pack-qtest\|reg-qtest' )" "0"
check "no folder left"         "$(find /d/WSL -maxdepth 1 -name '*qtest*' 2>/dev/null | wc -l)" "0"
check "no tar left"            "$(find /d/WSL -maxdepth 1 -name '*rootfs.tar' 2>/dev/null | wc -l)" "0"
echo "--- and the checkout is untouched by the runs"
check "the runs left the checkout exactly as it was" \
    "$([ "$Before" = "$(tree_state)" ] && echo yes || echo no)" "yes"

for staged in "${Created[@]:-}"; do
    [ -n "$staged" ] && rm -rf "$staged"
done
rm -f "$Out"
echo ""
echo "failures: $Failures"
exit $Failures
