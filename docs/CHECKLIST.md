# THE LAST SIGNAL — Checklist de desenvolvimento (estado real)

Legenda: ✅ feito e verificado · 🧪 feito, verificação depende do CI · ⏳ pendente · ⚠️ limitação conhecida

## Marco 0 — Identidade visual
- ✅ Bíblia de personagens com descrição fixa e prompts por animação (`docs/CHARACTER_BIBLE.md`)
- ✅ Ciclo de caminhada MUGEN gerado no Canva: Elias, Maya, Theo (8 quadros, consistentes)
- ⏳ Naomi: folha não gerada (cota do Canva esgotou)
- ⏳ Demais animações (idle, run, crouch, hide, inspect, fear, hurt, talk, flashlight, turn) dos 4 protagonistas
- ⏳ Retratos de diálogo (4 expressões × 4 protagonistas)
- ⏳ Sprites dos 14 NPCs e 4 criaturas
- ⏳ Cenários pintados (opcional: hoje são pintados proceduralmente pelo motor)
- ⚠️ Até a arte chegar, o motor desenha uma **silhueta provisória** no lugar do sprite (aparece marcada na seleção de personagem)

## Marco 1 — Pipeline de arte
- ✅ `tools/sprite_pipeline.py`: remove fundo (borda + bolsões internos), remove halo, separa quadros (colunas ou componentes conectados), alinha pelos pés, padroniza altura, gera `manifest.json` — testado nas 3 folhas geradas
- ✅ Motor carrega os sprites automaticamente (`Art.frames_for`) com fallback de animações faltantes
- ✅ CI roda o pipeline antes de exportar

## Marco 2 — Motor e sistemas (Godot 4.3, renderizador Compatibility)
- 🧪 Movimento lateral, corrida com fôlego, agachar, esconder, lanterna (luz real 2D)
- 🧪 Habilidades: Sintonia (Elias), Flash (Maya), Primeiros socorros (Theo), Visão (Naomi)
- 🧪 Câmera fotográfica com revelação de espíritos (fotos queimadas)
- 🧪 Ciclo dia/noite contínuo + agenda de NPCs por hora/local
- 🧪 IA de criaturas: Oco (visão/luz), Estática (postes), Ouvinte (som), Maestro (chefe)
- 🧪 Diálogos com retrato, máquina de escrever, escolhas, variação por personagem/hora/capítulo
- 🧪 Caderno: missões, evidências, quadro de deduções, marcação de espíritos, mapa, sistema
- 🧪 Cutscenes animadas com os mesmos atores/cenários (câmera, zoom, chuva, relâmpago, flash, falas, escolhas)
- 🧪 Salvamento atômico com MD5 + backup automático; autosave por troca de local
- 🧪 Áudio 100% sintetizado (7 camadas ambiente + 25 efeitos), muda com local/hora/perigo
- 🧪 Controles: teclado, controle (gamepad) e toque multitoque no Android
- 🧪 Menus animados: título, seleção de personagem, capítulos, galeria de finais, configurações

## Marco 3 — Conteúdo
- ✅ 20 locais (8 externos, 12 interiores), 14 NPCs (6 espíritos), 4 criaturas
- ✅ 5 capítulos, 18 missões (principais, pessoais, secundárias, noturna, secreta)
- ✅ 17 árvores de diálogo, 28 cutscenes, 51 evidências, 12 deduções, 10 finais
- ✅ Validação cruzada de todo o conteúdo (`tools/validate_data.py`): 0 erros
- ⏳ Dublagem: não há arquivos de voz (o sistema aceita `res://audio/<nome>.ogg` quando existirem)

## Marco 4 — Testes e builds
- ✅ Validador de dados e verificador estrutural de GDScript rodando localmente (0 problemas)
- 🧪 `tests/run_tests.gd`: jogatina completa de cada protagonista (abertura → 5 capítulos → final), visita a todos os locais de dia e de noite, todas as cutscenes isoladas, saves (incl. corrupção), todos os 10 finais
- 🧪 Export APK (Android, debug assinado) e Windows .exe via GitHub Actions
- ⚠️ O Godot não pôde ser executado no ambiente onde o código foi escrito (sem rede para baixar o motor). **A primeira compilação real acontece no CI** — erros de compilação, se houver, aparecem lá e serão corrigidos.
- ⏳ Teste em aparelho Android real (desempenho/toque)

## Próximos passos
1. Criar o repositório no GitHub e enviar o projeto
2. Primeira execução do CI → corrigir o que o compilador do Godot apontar
3. Baixar as folhas do Canva em resolução cheia para `art/source/`
4. Gerar o resto das animações e NPCs (cota de imagens do Canva/Picsart)
