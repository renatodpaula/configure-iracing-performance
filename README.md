# Configure iRacing Performance

[Português](#português) | [English](#english)

## English

`configure-iracing-performance` is a Codex skill for diagnosing and tuning iRacing graphics performance. It helps a driver reach a repeatable, stable FPS target while preserving as much image quality as possible.

It supports single-monitor, triple-monitor, and VR setups. The workflow identifies the active renderer profile, checks common frame-rate limits, distinguishes CPU and GPU bottlenecks, and applies one measured change at a time. It includes a PowerShell diagnostic script for collecting the relevant iRacing, display, and NVIDIA information when available.

### Use it

1. Install the skill in Codex.
2. Ask Codex for iRacing performance help, for example:
   - “Tune iRacing for a stable 144 FPS on triple 1440p monitors.”
   - “Why is iRacing capped at 60 FPS?”
   - “Optimize my OpenXR VR settings for iRacing.”
3. Specify whether you use one monitor, three monitors, or VR. For monitors, provide the target FPS, refresh rate, and resolution. For VR, provide the headset, runtime, and refresh-rate target.
4. Follow the guided baseline, one-change-at-a-time tests, and in-session validation.

### What it does

- Protects renderer files by inspecting and backing them up before changes.
- Avoids edits while iRacing is running, preventing the UI from overwriting settings.
- Uses the matching renderer file for monitors, OpenXR, OpenVR, or Oculus.
- Tunes GPU-bound and CPU-bound scenarios differently.
- Validates changes in the same car, track, weather, and grid conditions.

The diagnostic helper is at `scripts/diagnose.ps1`. The full workflow and safety guardrails are in `SKILL.md`.

## Português

`configure-iracing-performance` é uma skill do Codex para diagnosticar e ajustar o desempenho gráfico do iRacing. Ela ajuda o piloto a alcançar uma meta de FPS estável e reproduzível, preservando a maior qualidade de imagem possível.

Ela atende configurações com um monitor, três monitores e VR. O fluxo identifica o perfil de renderização ativo, verifica limitadores comuns de taxa de quadros, diferencia gargalos de CPU e GPU e aplica uma alteração medida por vez. A skill inclui um script PowerShell de diagnóstico que coleta informações relevantes do iRacing, do monitor e, quando disponível, da NVIDIA.

### Como usar

1. Instale a skill no Codex.
2. Peça ajuda ao Codex para melhorar o desempenho do iRacing, por exemplo:
   - “Ajuste o iRacing para 144 FPS estáveis em três monitores 1440p.”
   - “Por que o iRacing está limitado a 60 FPS?”
   - “Otimize minhas configurações de VR com OpenXR no iRacing.”
3. Informe se usa um monitor, três monitores ou VR. Para monitores, forneça FPS desejado, taxa de atualização e resolução. Para VR, informe headset, runtime e taxa de atualização desejada.
4. Siga os testes guiados: linha de base, uma alteração por vez e validação dentro da mesma sessão.

### O que ela faz

- Protege os arquivos do renderer, inspecionando e criando backup antes de mudanças.
- Evita edições enquanto o iRacing está aberto, impedindo que a interface sobrescreva as configurações.
- Usa o arquivo de renderer adequado para monitores, OpenXR, OpenVR ou Oculus.
- Ajusta cenários limitados por GPU e CPU de formas diferentes.
- Valida alterações nas mesmas condições de carro, pista, clima e quantidade de carros.

O auxiliar de diagnóstico está em `scripts/diagnose.ps1`. O fluxo completo e as proteções estão em `SKILL.md`.
