# Git Workflow & Commit Management

## Table of Contents
- [Repository History Management](#repository-history-management)
- [Squashing Commits Before a Pull Request](#squashing-commits-before-a-pull-request)
- [Common Scenarios](#common-scenarios)
- [Best Practices](#best-practices)

---

## Repository History Management

### What We Did: Complete History Rewrite

This repository was initialized with a clean, single commit containing all the infrastructure code. This approach was taken to:

1. **Remove Sensitive Information**: Ensure no sensitive data (subscription IDs, company names) appears in the commit history
2. **Clean Slate**: Start with a professional, portfolio-ready repository
3. **Simplified History**: Make the repository easier to understand and maintain

### How It Was Done

```bash
# 1. Create a new orphan branch (no history)
git checkout --orphan temp_branch

# 2. Stage all current files
git add -A

# 3. Create a single comprehensive commit
git commit -m "Initial commit: Multi-region Windows Server 2022 infrastructure"

# 4. Delete the old main branch
git branch -D main

# 5. Rename the new branch to main
git branch -m main

# 6. Force push to remote (overwrites history)
git push -f origin main
```

⚠️ **Warning**: Force pushing rewrites remote history. Only do this on repositories where you're the sole contributor or have team agreement.

---

## Squashing Commits Before a Pull Request

### Why Squash Commits?

- **Clean History**: Multiple WIP commits like "fix typo", "oops forgot file" clutter the main branch
- **Logical Units**: Each commit should represent a complete, logical change
- **Easier Rollbacks**: Reverting one feature is simpler than reverting 10 small commits
- **Professional**: Shows thoughtful, organized development

### Method 1: Interactive Rebase (Recommended)

Best for squashing multiple commits into one before merging.

```bash
# 1. Ensure you're on your feature branch
git checkout feature-branch

# 2. Start interactive rebase for last N commits
# Replace 'N' with the number of commits to squash
git rebase -i HEAD~N

# Example: Squash last 5 commits
git rebase -i HEAD~5
```

**In the editor that opens:**

```bash
pick abc1234 First commit message
pick def5678 Second commit message
pick ghi9012 Third commit message
pick jkl3456 Fourth commit message
pick mno7890 Fifth commit message

# Change 'pick' to 'squash' (or 's') for commits to squash:
pick abc1234 First commit message
squash def5678 Second commit message
squash ghi9012 Third commit message
squash jkl3456 Fourth commit message
squash mno7890 Fifth commit message
```

Save and close. You'll then get another editor to write the final commit message.

```bash
# 3. Force push to update your feature branch
git push -f origin feature-branch
```

### Method 2: Reset and Recommit

Simpler approach for squashing all commits into one.

```bash
# 1. Find the commit hash where your feature branch started
# (usually the commit on main before you branched)
git log --oneline

# 2. Soft reset to that commit (keeps all changes staged)
git reset --soft <commit-hash-from-main>

# Example:
git reset --soft abc1234

# 3. All your changes are now staged as one change
# Create a single commit
git commit -m "Add feature: comprehensive description"

# 4. Force push
git push -f origin feature-branch
```

### Method 3: Squash via GitHub/GitLab UI

The easiest method if your platform supports it:

1. Create your pull request as normal
2. When merging, select **"Squash and merge"** option
3. GitHub/GitLab will combine all commits automatically
4. Edit the final commit message before confirming

✅ **Recommended for most teams** - No local git commands needed, history is clean on main branch.

---

## Common Scenarios

### Scenario 1: Feature Branch with Many Small Commits

**Situation**: You have 10 commits like "WIP", "fix test", "update docs", "oops"

**Solution**: Use interactive rebase before creating PR

```bash
# On your feature branch
git rebase -i HEAD~10

# Squash all into the first commit
# Result: 1 clean commit representing the entire feature
```

### Scenario 2: Accidentally Committed Sensitive Data

**Situation**: You committed a subscription ID, API key, or sensitive info

**Solution**: Complete history rewrite (like this repo)

```bash
# 1. Remove sensitive data from files
# 2. Add to .gitignore
# 3. Create clean history:

git checkout --orphan clean_branch
git add -A
git commit -m "Initial commit: [description without sensitive info]"
git branch -D main
git branch -m main
git push -f origin main
```

⚠️ **Important**: After force pushing, anyone who cloned the repo needs to:
```bash
git fetch origin
git reset --hard origin/main
```

### Scenario 3: Preparing Multiple Features for One PR

**Situation**: You want to combine several related commits into logical groups

**Solution**: Interactive rebase with selective squashing

```bash
git rebase -i HEAD~8

# In the editor:
pick abc1234 Add authentication module
squash def5678 Fix auth tests
squash ghi9012 Update auth docs
pick jkl3456 Add database migrations
squash mno7890 Fix migration script
pick pqr1234 Update README
squash stu5678 Add deployment guide
squash vwx9012 Fix typos

# Results in 3 clean commits:
# 1. Add authentication module
# 2. Add database migrations  
# 3. Update README
```

### Scenario 4: Already Pushed, Need to Squash

**Situation**: You already pushed multiple commits and want to clean them up

**Solution**: Rebase locally, then force push

```bash
# 1. Rebase/squash locally
git rebase -i HEAD~5

# 2. Force push (overwrites remote history)
git push -f origin feature-branch

# ⚠️ Only do this on feature branches, NOT on shared/main branches
```

---

## Best Practices

### ✅ DO

- **Squash before merging**: Keep main branch history clean
- **Write meaningful commit messages**: Explain what and why
- **Test after squashing**: Ensure code still works
- **Communicate with team**: Let them know if you're force pushing
- **Use squash-merge on GitHub**: Simplest and safest for most teams
- **Keep .gitignore updated**: Prevent sensitive files from being committed

### ❌ DON'T

- **Don't force push to main/master**: Unless you're certain and have backups
- **Don't squash too much**: Each commit should still represent a logical unit
- **Don't lose important context**: Good commit messages matter even when squashing
- **Don't squash public/shared branches**: Only feature branches you control
- **Don't forget to notify team**: If you rewrite history on shared branches

### Commit Message Format

When squashing, write clear commit messages:

```bash
# Good ✅
"Add multi-region deployment support

- Implement region-based VM distribution
- Add network security groups per region
- Update documentation with scaling examples
- Add terraform.tfvars template"

# Bad ❌
"updates and fixes"
"WIP"
"asdf"
```

### Checking What Will Be Squashed

Before squashing, review what you're combining:

```bash
# See commit history
git log --oneline -10

# See detailed changes
git log -p -5

# See changes compared to main
git log main..HEAD --oneline
```

---

## Quick Reference Commands

```bash
# Squash last 3 commits interactively
git rebase -i HEAD~3

# Squash all commits since branching from main
git rebase -i main

# Reset and recommit everything as one commit
git reset --soft main
git commit -m "Your message"

# Undo a rebase (if something went wrong)
git reflog
git reset --hard HEAD@{1}

# Force push (after squashing)
git push -f origin your-branch

# Pull after someone force pushed
git fetch origin
git reset --hard origin/main
```

---

## Tools & Resources

- **GitKraken**: Visual git client with interactive rebase UI
- **VS Code Git Graph**: Extension for visualizing and managing commits
- **GitHub Desktop**: Simplified git interface with squash support
- **git reflog**: Your safety net when things go wrong

---

## Summary

Squashing commits is a powerful tool for maintaining clean repository history. Use it:
- Before merging feature branches
- When sensitive data was committed
- To clean up WIP commits
- To create logical, reviewable units of change

Remember: **Force pushing rewrites history**. Only do it on branches you control or with team agreement.
