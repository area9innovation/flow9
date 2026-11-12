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

Report only what the range introduced. A defect that was there before the range
is not a finding of this review; name it in one line under "seen, not new".

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
- **Skipped, with the reason:** documentation, files that only tests use,
  changes that are only layout or wording.

## 3. Learn how this code protects itself

Before you judge a change, find what the code around it already does:

- the escaping, sanitising and validation functions in use, and where the
  siblings of the changed function call them;
- where input enters and which side of a trust boundary the changed code is on;
- the checks a similar decoder, parser or native already makes.

A change that leaves an established pattern, or that opens a new way in, is the
first place to look.

## 4. Look for defects

Read the whole function and its callers, not only the changed lines. Follow the
data from where it enters to where it is used.

**Input and memory**

- A length, index, offset or count from the input that is used before it is
  checked. A size computation that can overflow.
- In the C++ runtime: a read or a write outside a buffer, a use after free, an
  index taken from bytecode or a file.
- Time and depth: a loop or a recursion that scans the rest of the input again
  for each element, a recursion whose depth the input sets, a pattern that
  backtracks without bound.

**Injection and code execution**

- Input that reaches SQL, a shell or a process argument, `eval`, a file path
  (path traversal) or a URL whose host or protocol it controls.
- HTML or script that reaches the page without the sanitiser its siblings use.
- XML entities, and the decoding of serialised data into structures that the
  caller then trusts.

**Authentication and authorisation**

- A path that skips a check its siblings make. A way to act as another user or
  with more rights.
- Sessions and tokens: signature, algorithm, expiry and audience of a JWT; a
  cookie without the flags its siblings set.

**Cryptography and secrets**

- A key, password or token written in the code.
- A weak algorithm or mode, a predictable source of randomness, a comparison
  that is not constant-time on a secret.
- Certificate or signature validation that is skipped or made optional.

**Data exposure**

- A secret, a password or personal data in a log, an error message or a
  response.
- Debug output or an endpoint that returns more than its caller may see.

**Consistency**

- A sibling of the changed function has a check that this one lacks.

A rewrite of a parser or a decoder is one unit of work for a sub-agent. Give it
the diff, the version before the range and these questions. Ask it to compare
the old and the new code on the same inputs.

## 5. Verify each candidate

A candidate is a finding only after this step. Verify candidates independently
of each other; a sub-agent for each one is the usual way.

- Trace the input. Find the guards above the code, and confirm that input from
  outside reaches it.
- Measure when a measure exists. Compile a small driver (`bin/flowc1 jar=…`
  needs only Java; `CLAUDE.md` says how to build the JavaScript targets). For
  time, run it at sizes that double and read the growth. For behaviour, compare
  the output before and after.
- A fix comes with a test that fails without it.

Keep drivers and their output outside the tree, or delete them before a commit.

### What is not a finding

Drop a candidate that matches one of these, unless you can show a concrete path
from outside input to harm:

- A missing rate limit, or load that any service has under many requests. Time
  or memory that grows faster than the input is a finding; see section 4.
- A general best practice that the code does not follow, with no input that
  makes it matter. A missing bound on input from outside is not this case.
- Missing validation of a field that no security decision depends on.
- A secret or credential on disk that is otherwise protected.
- A value from an environment variable or a command-line flag. The person who
  runs the program sets them, and they are trusted.
- A missing permission check in client-side code. The server is where it must
  be; the same holds for input the client sends on to the server.
- A race or a timing attack that is only theoretical.
- An outdated third-party library. The dependency audit handles those.
- A memory-safety defect in a memory-safe language (flow, Java, Haxe,
  JavaScript, safe Rust). In C++ it is a finding.
- Unsanitised input in a log line, and the logging of a URL or of data that is
  not a secret and not personal.
- A request forgery that controls only the path of a URL.
- Input in a regular expression as such. Unbounded backtracking is a finding.
- A missing audit log, a resource that is not released, a file descriptor leak.
- A file that only tests use, a notebook, a documentation file.
- A shell script or a CI workflow, unless input that nobody trusts reaches it.
- Tabnabbing, cross-site leaks, prototype pollution and open redirects, unless
  the path is certain.
- A UUID may be taken as unguessable.

### Confidence

Give each candidate that is left a confidence from 1 to 10 that it is real:

- **8 to 10:** the path from input to effect is traced, and measured or
  reproduced where that is possible. It is a finding.
- **4 to 7:** a suspicious pattern that needs conditions you could not confirm.
- **1 to 3:** probably noise.

Only 8 and above is a finding. Name each candidate below 8 under "dropped", with
its score and the reason. When the effect would be serious and the score is 6
or 7, say so there: a person decides whether to look again.

## 6. Decide what happens to each finding

Give each finding a severity:

- **High:** directly usable for code execution, a data breach or an
  authentication bypass.
- **Medium:** needs specific conditions, and the effect is significant.
- **Low:** defence in depth. A missing bound or a slow path with no practical
  way to use it against a deployment.

The task says which findings become a pull request and which stay private. With
no such rule, only a low finding is fixed in public: a fix for a high or medium
one in a public repository is a disclosure. A finding you cannot place is the
private kind.

## 7. Report

- The range and the number of commits.
- The files read closely and the files skipped.
- Each finding: file and line, severity, the class of defect, confidence, how
  it was verified, and the fix or the recommendation.
- Candidates dropped, with score and reason. Defects seen that are not new.
- What was not verified.

In a public place, describe the change in behaviour. Never describe the input
that triggers a defect.

---

Parts of this method are adapted from the `security-review` command of
[anthropics/claude-code-security-review](https://github.com/anthropics/claude-code-security-review)
(MIT License, Copyright (c) 2025 Anthropic).
