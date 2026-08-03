# Claude harness

Claude Code reads `SKILL.md` at the skill directory root. This repository is the
skill directory, so no separate manifest is required — only installation.

| Item | Value |
| --- | --- |
| Skill name | `configure-iracing-performance` |
| Display name | iRacing Performance |
| Short description | Otimize qualidade, FPS e estabilidade no iRacing |
| Invocation | `/configure-iracing-performance` or any request matching the `description` in `SKILL.md` |
| Entry point | `SKILL.md` |
| Progressive disclosure | `references/*.md`, loaded on demand by the steps in `SKILL.md` |
| Tools used | `Bash` (to run the PowerShell scripts), `Read`, and `Edit` only through the scripts |

## Install

```bash
scripts/install-claude-skill.sh              # ~/.claude/skills, symlink
scripts/install-claude-skill.sh --copy       # independent snapshot
scripts/install-claude-skill.sh --project .  # <project>/.claude/skills
```

```powershell
scripts\install-claude-skill.ps1                       # ~/.claude/skills, junction
scripts\install-claude-skill.ps1 -Copy
scripts\install-claude-skill.ps1 -Scope Project -ProjectPath .
```

## Suggested prompts

- `Use /configure-iracing-performance para diagnosticar gargalos por evidência e otimizar qualidade e FPS com testes por faixa.`
- `Melhor gráfico possível mantendo 144 FPS em três monitores 1440p.`
- `Priorize imersão no VR, mas mantenha pelo menos 90 FPS nativos.`
- `Encontre a causa dos stutters no iRacing sem alterar nada ainda.`

## Harness notes

- The scripts are PowerShell and only run on the Windows machine that runs
  iRacing. On any other platform, ask the driver to run the command and paste the
  JSON output back; see "Run the Bundled Scripts" in `SKILL.md`.
- Paths inside `SKILL.md` are relative to the skill directory, not to the working
  directory of the session.
- Mutation still requires `-Apply`; preview is the default in every script.
