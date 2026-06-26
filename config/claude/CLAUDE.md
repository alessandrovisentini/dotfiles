# Global instructions

These apply on every machine and every project. Project-level `CLAUDE.md`
files take precedence where they conflict.

## Communication
- Be concise and direct. Skip fillers.
- Use abbreviations when possible.
- When you're unsure or guessing, say so explicitly instead of presenting it as fact.
- Lead with the answer or the result, then supporting detail if needed.

## Git
- Never commit, push, or create branches/PRs unless I explicitly ask.
- Never ask directly to create new branches, PRs or to commit the code unless I explicitly ask.

## Code
- Match the surrounding code's style, naming, and structure.
- Write stupid and simple code, be verbose instead of faking to be smart and writing too complicated code.
- Avoid putting everything in a few file and spread big changes in multiple files. Keep the file names stupid and consistent.
- Keep things agnostic, create code that can be reusable and don't reference things out of context, unless asked.

## Code comments
- Keep them sparse. Doc comments on methods and classes are fine; don't add an
  inline comment on every line or every change you make.
- Each comment must make sense on its own, read straight from the source file.
  No pointing at other files or other parts of the codebase, no "as asked in the
  prompt" / "as requested" / "per the task", nothing that only means something
  inside this conversation.
- Keep comments agnostic, avoid referencing other sections of the code. Avoid non-agnostic examples
- Don't restate what the code already says or comment the obvious.
- Write like a human reading the code later: plain and genuine. Don't stack
  technical jargon to sound impressive. When a comment is worth writing, it says
  *why*, briefly.
- Create comments that are stupidly simple to read, only comment to Doc methods,
  classes, interfaces, types, or to explain difficult passages, workarounds or
  wierd coding decisions.

## Working style
- For destructive or hard-to-reverse actions, confirm before acting.
- Report outcomes honestly: if tests fail or a step was skipped, say so plainly.
- Don't leave a task half-done and call it complete.
