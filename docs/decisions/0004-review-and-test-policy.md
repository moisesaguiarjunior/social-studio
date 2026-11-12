# 0004 — Review the system and test meaningful contracts

Status: proposed in PR #6; adoption follows maintainer merge.

## Context

The maintainer requested clean code, strong public-repository standards and
independent review before publication. An earlier draft expressed this with
blanket symbol bans and tests for every behavior. Those rules can encourage
superficial compliance: replacing a simple boundary with complex code, or adding
mirror tests while missing a mistaken system-level premise.

The policy edits accompanying the Quality workflow are a distinct engineering
proposal, not a technical requirement of CI. They are recorded here so review
and adoption are explicit rather than hidden in a CI commit.

## Decision proposed

- Review actual callers and canonical implementations before the author's
  explanation. Search for duplicate sources of truth and missing acceptance
  criteria; agreeing code, tests and docs can share a mistaken premise.
- Keep application logic statically typed. An unavoidable SDK boundary may use
  dynamic values only locally, immediately validate/narrow them, document why,
  and expose a typed contract. No unchecked casts, global suppression or dynamic
  propagation; this is not permission for casual dynamic application code.
- Test material behavior and failure modes. Retain useful regression tests;
  avoid generated-code/getter mirrors added solely to increase counts.
- Demonstrate that a safety check rejects its intended invalid case and accepts
  the valid one. Compilation failure or another guard is not proof. Disposable
  experiments are acceptable evidence; a permanent mutation framework is not
  mandatory for every implementation detail.
- A PR modifying a gate and its tests needs an independent challenge, including
  inspection of deleted/weakened assertions. Its own green suite is insufficient.

Independent exact-commit review, snapshot checks, no pre-review public pushes,
immutable source/media rules and clean analysis remain required.

## Alternatives and consequences

Absolute bans are easier to count but cannot establish safe contracts or good
engineering judgment. Removing standards entirely would lose useful constraints.
The narrower contract-based proposal keeps those constraints while requiring
specific evidence for exceptions. Reviewers can reject an exception, a redundant
implementation or an inadequate test even when automated checks pass.

This decision does not claim coverage thresholds, a renderer, conformance or
package publishing checks have been implemented; they follow the core they guard.
