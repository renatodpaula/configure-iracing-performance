# Configure iRacing Performance

[Português](#português) | [English](#english)

> **Version 2 / Versão 2:** objective-first tuning, section-aware diagnosis, independent driving/replay profiles, measured before/after tests, atomic backup, and verified rollback. [Documentation / Documentação](https://github.com/renatodpaula/configure-iracing-performance/wiki)

## English

`configure-iracing-performance` is a Codex skill for diagnosing, testing, and safely tuning iRacing graphics on one monitor, triple monitors, or VR.

It does not apply a universal preset. It first establishes the driver's objective:

- Maximum visual immersion, with an agreed minimum acceptable FPS.
- The best graphics possible at a specific stable FPS.
- Maximum consistency and low latency, with explicit visual trade-offs.

Every recommendation is tested in the same car, track, weather, grid, and demanding scene. A documentation recommendation is treated as a starting hypothesis: if measured performance, smoothness, latency, or perceived quality becomes worse, the change is reverted.

### Driving and replay are separate

The skill reads and tunes `[Graphics Options]` for driving without mixing it with `[Replay Graphics]`.

Replay quality is preserved by default and should normally remain high or maximum. Replays do not usually require racing-level FPS and are often used to review incidents or record cinematic takes. Replay settings change only when explicitly requested; real-time capture also receives its own resolution and FPS target.

### Typical use

Ask Codex, for example:

- “Give me the best graphics possible while holding 144 FPS on triple 1440p monitors.”
- “Prioritize immersion in VR, but keep at least 90 native FPS.”
- “Find the cause of my iRacing stutters without changing anything yet.”
- “Keep my replay graphics at maximum while optimizing race performance.”

Codex will ask for the display path and objective when they are missing, collect a section-aware diagnosis, establish a baseline, change one performance lever, and compare the result before keeping it.

### Included tools

- `scripts/diagnose.ps1`: reads the exact renderer, separates driving and replay sections, identifies blocking processes, and returns structured hardware and configuration evidence.
- `scripts/update-renderer.ps1`: previews a section-specific edit, validates the current hash, protects replay, and creates an atomic backup when `-Apply` is used.
- `scripts/restore-renderer.ps1`: previews and restores a generated backup while preserving the configuration being replaced as a safety copy.

Direct edits are blocked while iRacing UI or the simulator is running. Preview is the default; mutation requires `-Apply`.

## Português

`configure-iracing-performance` é uma skill do Codex para diagnosticar, testar e ajustar com segurança os gráficos do iRacing em um monitor, três monitores ou VR.

Ela não aplica um preset universal. Primeiro, define o objetivo do piloto:

- Máxima imersão visual, com um FPS mínimo aceitável combinado.
- O melhor gráfico possível dentro de uma meta específica de FPS estável.
- Máxima consistência e baixa latência, com perdas visuais explícitas.

Toda recomendação é testada no mesmo carro, pista, clima, grid e trecho exigente. Uma recomendação da documentação é tratada como hipótese inicial: se desempenho medido, fluidez, latência ou qualidade percebida piorar, a alteração é revertida.

### Corrida e replay são independentes

A skill lê e ajusta `[Graphics Options]` para a condução sem misturar esses valores com `[Replay Graphics]`.

A qualidade do replay é preservada por padrão e normalmente deve permanecer alta ou máxima. Replay geralmente não exige o mesmo FPS da corrida e costuma ser usado para rever incidentes ou gravar takes cinematográficos. Suas configurações só mudam quando isso for pedido explicitamente; uma gravação em tempo real também recebe meta própria de resolução e FPS.

### Exemplos de uso

Peça ao Codex, por exemplo:

- “Use o melhor gráfico possível mantendo 144 FPS em três monitores 1440p.”
- “Priorize imersão no VR, mas mantenha pelo menos 90 FPS nativos.”
- “Encontre a causa dos stutters no iRacing sem alterar nada ainda.”
- “Mantenha o replay no máximo e otimize apenas o desempenho durante a corrida.”

Quando faltarem informações, o Codex perguntará o modo de exibição e o objetivo, coletará um diagnóstico separado por seções, estabelecerá uma linha de base, mudará uma variável de desempenho e comparará o resultado antes de mantê-la.

### Ferramentas incluídas

- `scripts/diagnose.ps1`: lê o renderer exato, separa corrida e replay, identifica processos bloqueadores e retorna evidências estruturadas de hardware e configuração.
- `scripts/update-renderer.ps1`: mostra uma prévia da alteração na seção correta, valida o hash atual, protege replay e cria backup atômico quando `-Apply` é usado.
- `scripts/restore-renderer.ps1`: mostra uma prévia e restaura o backup gerado, preservando também a configuração substituída como cópia de segurança.

Edições diretas são bloqueadas enquanto a interface ou o simulador do iRacing estiverem abertos. A prévia é o comportamento padrão; alterações exigem `-Apply`.

## Créditos

Autor: Renato de Paula — Instagram: [@mrupgrade.simracing](https://www.instagram.com/mrupgrade.simracing/)
