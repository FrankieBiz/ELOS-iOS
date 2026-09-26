# Skill: obsidian-vault

## Purpose
Query the user's Obsidian vault for design notes, research, or reference material.

## How to use
- Obsidian runs locally with the Local REST API plugin on port 27124.
- API key is in the environment variable OBSIDIAN_API_KEY.
- Use `curl -k` with the Authorization header.

## Example commands
- List root files: curl -k -H "Authorization: Bearer $OBSIDIAN_API_KEY" https://127.0.0.1:27124/vault/
- Read a note: curl -k -H "Authorization: Bearer $OBSIDIAN_API_KEY" https://127.0.0.1:27124/vault/path/to/note.md
- Search: use Bash with grep or ripgrep on vault contents if needed.

## Constraints
- Only read notes. Do not write or delete unless explicitly asked.
- Do not expose the API key in output.
