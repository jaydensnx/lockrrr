# Git Quick Guide

## 1. One-sentence mental model

> **Git** = save points for code + a way for multiple people to edit t
he same project without overwriting each other.

---

## 2. Initial setup (do once per machine)

```bash
git --version                                   # check that git is installed
git config --global user.name "Your Name"
git config --global user.email "you@dukes.jmu.edu"
```

---

## 3. Getting the project

If the repo already exists on GitHub (or similar):

```bash
# clone once
git clone <repo-url>
cd <project-folder>
```

> From now on, just `cd` into this folder to work — never re-clone the same repo on the same machine.

---

## 4. Everyday workflow (the 5 commands you'll use constantly)

From inside the project folder:

### 1. Update your local copy first
```bash
git pull origin main    # or 'master' or whatever the main branch is
```

### 2. Create / switch to a feature branch
```bash
git checkout -b feature/something   # first time
# later, to come back to it:
git checkout feature/something
```

### 3. See what changed
```bash
git status
```

### 4. Stage and commit your changes
```bash
git add .                            # stage everything changed
git commit -m "short, clear message"
```

### 5. Push your branch
```bash
git push -u origin feature/something   # first push
# afterwards:
git push
```

Then open a **Pull Request (PR)** from your branch into `main` on GitHub.

---

## 5. Basic branching rules for our team

- Don't code directly on `main` (or `master`).
- One task/bug/feature = one branch.
- Always `git pull origin main` before starting new work.

**If your branch is old, update it:**
```bash
git checkout feature/something
git pull origin main
# if needed, resolve conflicts, then:
git add .
git commit -m "Resolve merge conflicts"
git push
```

---

## 6. Common commands cheat sheet

```bash
# check repo status
git status

# see recent commits
git log --oneline

# create and switch to a new branch
git checkout -b feature/something

# switch branches
git checkout main

# list branches
git branch

# delete a local branch (after merge)
git branch -d feature/something

# discard local changes in a file (careful!)
git checkout -- path/to/file

# undo last commit but keep changes staged
git reset --soft HEAD~1
```

---

## 7. Commit message tips

| Bad | Better |
|-----|--------|
| `update` | `Add login form validation` |
| `fix` | `Fix crash when song list is empty` |
| `stuff` | `Refactor user service for clarity` |

> Aim for **one logical change per commit**.

---

## 8. Minimal "how not to break things"

1. **Pull before you start.**
2. **Commit often**, in small chunks.
3. **Don't commit secrets** (passwords, API keys).
4. If you get stuck or see a merge conflict you don't understand — **stop and ask** before making it worse.
