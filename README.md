# THE LAST SIGNAL

Jogo 2D de terror sobrenatural em rolagem lateral, estética de sprites **MUGEN**, para **Android e Windows**. Um jogo **KAIKODEV**.

> Ravenhill, outubro de 2004. Quem ouve a frequência 7.17 depois das três da manhã desaparece. Alguns moradores da cidade morreram em 1979 — e ainda não sabem.

## Como jogar
| Ação | Teclado | Controle | Toque |
|---|---|---|---|
| Andar | A/D ou ←/→ | D-pad / analógico | ◀ ▶ |
| Correr | Shift | RB | » |
| Agachar | C / Ctrl | B / analógico ↓ | ▼ |
| Interagir / esconder | E / Enter | A | E |
| Lanterna | F | Y | ☼ |
| Habilidade | Q | X | Q |
| Foto | R | LB | ◉ |
| Caderno / pausa | Tab / Esc | Select / Start | ≡ |
| Pular cutscene | segurar Esc | segurar Start | — |

## Estrutura
```
scripts/core      Game (estado, condições, efeitos, missões, saves), Data, Clock, Sfx (áudio sintetizado), Art
scripts/world     World, Player, NPC, Creature (IA), Actor (sprites), Backdrop (cenários), Prop, ScreenFX
scripts/ui        Título, seleção, HUD, toque, diálogo, caderno, estilo
scripts/cutscene  Diretor de cutscenes (linhas do tempo em JSON)
data/             Todo o conteúdo: personagens, NPCs, locais, missões, diálogos, cutscenes, evidências, finais
art/source        Folhas de sprite brutas (Canva/Picsart/à mão) → processadas pelo pipeline
tools/            sprite_pipeline.py, validate_data.py, lint_gd.py
tests/            Testes automatizados com jogatina completa
docs/             Bíblia de personagens, bíblia da história, checklist
```

## Build
O GitHub Actions (`.github/workflows/build.yml`) valida o conteúdo, processa os sprites, exporta o **APK** e o **.exe** e roda os testes. Os arquivos ficam em *Actions → execução → Artifacts*.

Local: Godot 4.3 → abrir `project.godot` → `python3 tools/sprite_pipeline.py` → Projeto → Exportar.

## Adicionar arte
Coloque a folha em `art/source/<id>/<animacao>.png` (uma linha de quadros, fundo liso, personagem virado para a direita). Veja `docs/CHARACTER_BIBLE.md`.
