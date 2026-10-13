# Global instructions

These apply on every machine and every project. Project-level `CLAUDE.md` files take precedence where they conflict.

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
- Avoid putting everything in a few file and spread big changes in multiple files. Keep the file names stupid, simple and consistent.
- Keep things agnostic, create code that can be reusable and don't reference things out of context, unless asked.

## Code comments
A comment is a quick note from me to future me. Short, plain, only where it earns its place. This applies to new code and to cleaning up existing comments.

- Section labels are wanted: two or three words that group a few lines, like `# Networking` or `# Helpers`. Keep the ones already there unless the section changes or is deleted.
- No comment on a normal line. A flag, an import, a list, a value that says what it is: leave them bare.
- Comment only the weird stuff: an unusual value, a workaround, something that breaks if removed, a line that does not do what it looks like it does.
- One line. Two at most. If it needs more, fix the code instead. The comment should be a TLDR of a TLDR.
- Say why, or what breaks without it. Never what the line does.
  - Good: `# Retry once because the API drops the first call after a cold start.`
  - Bad: `# Wrap the request in a retry loop with a single attempt so that transient failures caused by the upstream cold start do not surface.`
- Plain words, like talking to a friend. No jargon, no use of weird verbs like `lands`, `sits beside`, `carried over`, `surface` or similar smart sounding phrasing, no "leverage", "ensure", "deliberately", "in order to", "note that". You should sound stupidly simple and modest.
- First person is fine: "my setup", "this machine", "our API".
- Describe the present only. Never "was", "previously", "no longer", "moved from", "kept for now". The code has no history, git has.
- Nothing that only makes sense inside a conversation: no "as requested", "per the task", "as discussed", no references to the prompt or to me asking, to an external task or to another document.
- No pointing at other files or other parts of the code. Keep comments agnostic.
- A short inline comment is fine for a single odd value: `timeout = 30000 # 30 seconds`
- Doc comments on functions, classes and types follow the same rules: what it is for in a few stupidly simple word, no essay.
- When cleaning up existing comments: keep the section labels, cut every other comment down to the one sentence that matters, delete the rest.

Quick test before writing one: would I say this out loud to a friend looking over my shoulder? If not, delete it.

## Working style
- For destructive or hard-to-reverse actions, confirm before acting.
- Report outcomes honestly: if tests fail or a step was skipped, say so plainly.
- Don't leave a task half-done and call it complete.
