---
name: security-review-range
description: Security review of a range of commits that are already on the base branch (since..head). Use it when a routine or a person asks to review what was committed, not a branch against its base.
---

# Security review of a commit range

The built-in `/security-review` reviews a branch against its base. A routine
branch starts at its base, so that diff is empty. It also leaves out resource
exhaustion and missing hardening, which are in scope here, and it forbids running
anything. This skill reviews a range of commits instead, and it measures.

The task that names this skill decides what is published and what is not. Where
this file and the task disagree, the task wins.

## 1. Read the range

Take `<since>..<head>` from the task. With no range, or when `git log` of it is
empty, use the last 20 commits on the base branch and say so in the report.

```sh
git log --no-merges --format='%h %s' <since>..<head>
git diff --stat <since>..<head>
git diff <since>..<head> -- <path>
```

Read a large change one commit at a time (`git show <sha> -- <path>`).

## 2. Sort the changed files

Put each changed file in one of two groups, and keep the list for the report:

- **Read closely:** code that takes input from the network, a document or a
  file; the runtimes; server natives; anything the task lists.
- **Skipped, with the reason:** documentation, tests, changes that are only
  layout or wording.

## 3. Look for defects

Read the whole function and its callers, not only the changed lines. For each
change in the first group, answer these questions:

- **Bounds.** Is every length, index, offset and count that comes from the input
  checked before it is used? Can a size computation overflow?
- **Time and depth.** Does a loop or a recursion scan the rest of the input again
  for each element? Is the recursion depth set by the input?
- **Injection.** Does input reach SQL, a shell, HTML, `eval`, a file path or a
  URL without the escaping its siblings use?
- **Authentication and cryptography.** Is a check skipped on one path? Is a
  comparison, a default or a source of randomness weaker than before?
- **Consistency.** Does a sibling of the changed function have a check that this
  one lacks?

A rewrite of a parser or a decoder is one unit of work for a sub-agent. Give it
the diff, the version before the range and these questions. Ask it to compare
the old and the new code on the same inputs.

## 4. Verify each candidate

A candidate is a finding only after this step.

- Trace the input. Find the guards above the code, and confirm that input from
  outside reaches it.
- Measure when a measure exists. Compile a small driver (`bin/flowc1 jar=…`
  needs only Java; `CLAUDE.md` says how to build the JavaScript targets). For
  time, run it at sizes that double and read the growth. For behaviour, compare
  the output before and after.
- Drop a candidate you cannot substantiate, and name it under "dropped".
- A fix comes with a test that fails without it.

Keep drivers and their output outside the tree, or delete them before a commit.

## 5. Decide what happens to each finding

The task says which findings become a pull request and which stay private. With
no such rule, publish nothing that can be used against a deployment: a fix in a
public repository is a disclosure. A finding you cannot place is the private kind.

## 6. Report

- The range and the number of commits.
- The files read closely and the files skipped.
- Each finding: file and line, the class of defect, how it was verified.
- Candidates dropped, and what was not verified.
