#!/bin/tcsh
# repo.sh: keep master tracking upstream, keep my changes, optionally build an integrated branch.
# Usage:
#   ./repo.sh
#   ./repo.sh --integrate

set UPSTREAM_REMOTE = "upstream"
set UPSTREAM_BRANCH = "master"
set ORIGIN_REMOTE   = "origin"

set BASE_BRANCH     = "master"
set MY_BRANCH       = "feature/my-changes"
set INTEG_BRANCH    = "integrated/custom"

set DO_INTEGRATE = 0
if ($#argv >= 1) then
  if ("$argv[1]" == "--integrate") then
    set DO_INTEGRATE = 1
  endif
endif

echo "=== Sync: upstream -> $BASE_BRANCH, then update $MY_BRANCH ==="

# Must be a git repo and clean
set DIRTY = `git status --porcelain | wc -l`
if ("$DIRTY" != "0") then
  echo "[ERROR] Working tree not clean. Commit or stash first."
  exit 1
endif

echo "\n[1/5] Fetch upstream..."
git fetch $UPSTREAM_REMOTE
if ($status) then
  echo "[ERROR] git fetch failed."
  exit 1
endif

echo "\n[2/5] Update $BASE_BRANCH from $UPSTREAM_REMOTE/$UPSTREAM_BRANCH (ff-only)..."
git checkout $BASE_BRANCH
if ($status) then
  echo "[ERROR] checkout $BASE_BRANCH failed."
  exit 1
endif

git merge --ff-only $UPSTREAM_REMOTE/$UPSTREAM_BRANCH
if ($status) then
  echo "[ERROR] Cannot fast-forward $BASE_BRANCH from $UPSTREAM_REMOTE/$UPSTREAM_BRANCH."
  echo "        Resolve manually (likely divergence)."
  exit 1
endif

git push $ORIGIN_REMOTE $BASE_BRANCH
if ($status) then
  echo "[ERROR] push $BASE_BRANCH failed."
  exit 1
endif

echo "\n[3/5] Rebase $MY_BRANCH onto latest $BASE_BRANCH..."
git checkout $MY_BRANCH
if ($status) then
  echo "[ERROR] checkout $MY_BRANCH failed. Create it first:"
  echo "        git checkout -b $MY_BRANCH"
  exit 1
endif

git rebase $BASE_BRANCH
if ($status) then
  echo "[ERROR] Rebase conflict."
  echo "        Fix conflicts, then run:"
  echo "          git add <files>"
  echo "          git rebase --continue"
  exit 1
endif

git push --force-with-lease $ORIGIN_REMOTE $MY_BRANCH
if ($status) then
  echo "[ERROR] push $MY_BRANCH failed."
  exit 1
endif

if ($DO_INTEGRATE == 1) then
  echo "\n[4/5] Build integrated branch: $INTEG_BRANCH = $BASE_BRANCH + merge($MY_BRANCH)"
  git checkout $BASE_BRANCH
  if ($status) exit 1

  git checkout -B $INTEG_BRANCH
  if ($status) then
    echo "[ERROR] create/switch to $INTEG_BRANCH failed."
    exit 1
  endif

  # Merge my changes into integrated branch (safe, no rewrite)
  git merge --no-ff --no-edit $MY_BRANCH
  if ($status) then
    echo "[ERROR] Merge conflict while integrating $MY_BRANCH into $INTEG_BRANCH."
    echo "        Resolve, then:"
    echo "          git add <files>"
    echo "          git commit"
    exit 1
  endif

  git push -u $ORIGIN_REMOTE $INTEG_BRANCH
  if ($status) then
    echo "[ERROR] push $INTEG_BRANCH failed."
    exit 1
  endif
endif

echo "\n[5/5] Done."
echo "Tip: normal use = ./repo.sh"
echo "     integrated build = ./repo.sh --integrate"

