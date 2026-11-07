# Repository instructions

## Skills

- Skills in `ai/skillshare/skills` are custom or vendor-installed. A custom skill has `metadata.origin: custom` in its `SKILL.md` frontmatter. Vendor skills do not have this tag.
- When you create a custom skill, add this tag to its frontmatter:

  ```yaml
  metadata:
    origin: custom
  ```

- Do not add the tag to a vendor skill, and do not edit a vendor skill locally. Its upstream updates replace local changes.
- To list the custom skills, run `grep -lx '  origin: custom' ai/skillshare/skills/*/SKILL.md`.
