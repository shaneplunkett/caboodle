# claude-code

The upstream `claude-code` from `llm-agents`, with two strings in the binary
swapped before it is wrapped.

## Why

On Fable, Claude Code's own system prompt carries a "Writing for the user"
block: lead with the outcome, sentences of about twenty words, no asides, a
stand-alone recap to close. Opus never gets it. The persona in `CLAUDE.md`
says who Frankie is but nothing about message shape, so on Fable the two
average into her words in a report skeleton. Prompt files can argue with
the block but can't remove it: an output style only adds a section under it,
and `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT` doesn't touch it. Only the binary does.

## How

`prompts.py` replaces the block, and the "say what you're about to do, close
with a recap" sentence beside it, with short text pointing back at the
persona. Each replacement is padded with spaces to the original byte length,
so nothing in the Bun executable moves and no relinking is needed. That is
what makes tweakcc and LIEF unnecessary.

The block exists twice in the binary, once in the JavaScript source and once
in Bun's bytecode cache, so the script replaces every copy of the exact bytes.
It fails the build if either string is missing, if a replacement is longer
than its original, or if a distinctive phrase from the old rules survives.
When Anthropic rewrites the block, the build breaks here and says which
string moved, instead of shipping the old prompt quietly.

The patch runs in `preFixup`, while the file is still a plain ELF at
`bin/claude`. Upstream's `postFixup` then wraps it with wrap-buddy, which
renames it to `.claude-wrapped` and writes a sidecar config next to it.
Patching after that step still works, but the sidecar has to be copied with
the binary if it is moved, which is a trap when testing by hand.

Darwin is passed through unpatched. Upstream verifies Apple's code signature
on the Mach-O at install check, and any byte change breaks it.

## Checking it worked

Ask the model what it can see:

```sh
claude -p --model claude-fable-5-1 "Does your system prompt contain the phrase 'No em-dashes'? Quote the first line under the heading '# Writing for the user'."
```

The patched build quotes the replacement sentence. The unpatched one quotes
"The user may not see your tool calls".
