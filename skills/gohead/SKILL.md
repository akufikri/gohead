---
name: gohead
description: >
  Scope-first coding workflow. Use for coding tasks to understand the request,
  inspect the codebase, make only the necessary changes, handle blockers
  transparently, and verify the result. Also activate when the user says
  "Gohead" or asks for strict task boundaries and concise communication.
argument-hint: "[coding task]"
---

# GOHEAD

Complete the assigned task with the smallest relevant change that meets the
request. Understand the task before editing, inspect the codebase before
choosing a solution, stay within scope, and verify the result.

Communicate in the user's preferred language. Keep updates and explanations
clear, simple, and to the point.

## 1. Understand the task

Before making changes, identify:

- The task's goal and expected result.
- The behavior or part of the system in scope.
- Any constraints or explicit instructions.
- Any ambiguity that could materially change the implementation.

Do not invent extra requirements. Ask for clarification when an ambiguity could
lead to a substantially different solution. Otherwise, use a reasonable
assumption and state it if it affects the result.

## 2. Inspect the codebase

Review the relevant code, tests, and project conventions before deciding what
to change.

Determine whether the task is:

- Already implemented correctly.
- Partially implemented and needs an adjustment.
- Not implemented and needs a change.
- Already satisfied and requires no code changes.

Follow the existing architecture and patterns where practical. Avoid
unnecessary refactoring or new abstractions.

## 3. Keep changes within scope

Before editing, identify the files and changes needed to complete the task.

- Change only code directly related to the task.
- Update related tests or documentation when needed to implement or verify the
  task.
- You may inspect other files to understand the codebase, but do not change
  them unless the task requires it.
- Do not include unrelated fixes, cleanup, formatting changes, or refactors.
- If a necessary change would expand the task or affect unrelated
  functionality, explain why and ask for confirmation before making it.
- Do not treat discovering an unrelated issue as permission to fix it.

**Example:** For “Add a query to search products by tags,” work on that query
and its relevant tests. Do not change other filters or restructure the
catalog unless required and approved.

## 4. Make the change

- Choose the simplest maintainable solution that fully meets the task.
- Reuse existing patterns and utilities where appropriate.
- Avoid unnecessary complexity and duplication.
- Do not claim the task is complete before verifying the result.

## 5. Verify the result

After making changes, check that:

- The result matches the task and its intended context.
- The change works as expected.
- Relevant tests or checks have been run.
- No unrelated files or functionality were changed.
- The change has not introduced an obvious regression.

If a test cannot be run, state why and describe what you checked instead.
Report unrelated issues you discover, but do not fix them without approval.

## Blockers

A blocker is anything that prevents safe or correct progress, such as unclear
requirements, missing dependencies, insufficient access, or a required change
outside the task's scope.

When blocked:

- Stop work on the affected part of the task.
- Do not guess, hide the blocker, or make out-of-scope changes to work around
  it.
- Continue with other parts only if they can be completed safely and
  independently.
- Explain the blocker in plain language and say what is needed to proceed.

Report blockers using this format:

- **Blocker:** What is preventing progress.
- **Impact:** Which part of the task is affected.
- **Checked:** What has already been inspected or tried.
- **Needed:** The information, decision, or access required to continue.

If a test fails because of a pre-existing issue, distinguish it from failures
caused by the new change.

## Final response

Keep the final response concise and easy to understand. Include:

- **Status:** Complete, partially complete, or blocked.
- **Changes:** What changed and why.
- **Checks:** Tests or other verification performed and their results.
- **Blockers:** Any unresolved issue and what is needed next.

Do not imply that the task is fully complete if any required part remains
unfinished.
