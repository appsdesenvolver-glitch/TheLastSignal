# THE LAST SIGNAL — Bíblia de Personagens (padrão visual MUGEN)

Regra de ouro: **todo personagem é um sprite 2D de jogo de luta MUGEN em alta definição** — desenhado à mão, anatomia realista (~7,5 cabeças), sombreamento de tecido, contorno escuro fino, luz de recorte fria. **Nunca** pixel art, cartoon, chibi, low poly ou ilustração chapada.

Toda folha de sprite segue o mesmo formato para o pipeline funcionar:
- **uma linha** com N quadros (padrão 8), personagem **de perfil virado para a direita**, corpo inteiro;
- **fundo branco liso** (ou verde chapado), sem sombra no chão, sem cenário;
- mesma roupa, rosto e proporção em todos os quadros;
- nome do arquivo = animação: `idle.png`, `walk.png`, `run.png`, `crouch.png`, `hide.png`, `inspect.png`, `fear.png`, `hurt.png`, `talk.png`, `flashlight.png`, `turn.png` (use `run@10.png` se a folha tiver 10 quadros);
- retratos de diálogo: `portrait_neutral.png`, `portrait_scared.png`, `portrait_sad.png`, `portrait_smile.png` (busto, 3/4, fundo liso).

## Modelo de prompt (Canva / Picsart)

> Classic high-quality MUGEN fighting game character sprite sheet, hand-drawn HD 2D fighting game sprite (NOT pixel art, NOT cartoon), **[DESCRIÇÃO FIXA DO PERSONAGEM]**. Side view facing right, full body, one row of 8 frames: **[ANIMAÇÃO]**, the exact same character, face, clothes and proportions in every frame, realistic human anatomy, detailed cloth shading and folds, plain flat white background, supernatural horror game.

Animações (substitua **[ANIMAÇÃO]**):
| arquivo | texto |
|---|---|
| idle | relaxed idle breathing loop, subtle shoulder movement |
| walk | idle pose then a smooth walk cycle |
| run | fast run cycle, leaning forward, arms pumping |
| crouch | crouching and sneaking slowly, low stance |
| hide | crouched hiding, hugging knees, looking over shoulder |
| inspect | kneeling and examining something on the ground, then standing up |
| fear | frightened recoil, arms raised to protect face, trembling |
| hurt | hit from the front, staggering back |
| talk | talking with hand gestures, small head movements |
| flashlight | holding a flashlight forward with both hands, scanning slowly |
| turn | turning around in fear to look behind |

## Protagonistas (descrição fixa — copiar exatamente)

**ELIAS VANCE, 17** — `17-year-old teenage boy named Elias: messy dark brown hair with short undercut sides, pale skin, tired expressive eyes, dark olive military field jacket over a grey hoodie, black jeans, worn white sneakers, small backpack with an old walkie-talkie radio strapped to it`
Silhueta: capuz + mochila com antena. Paleta: oliva, cinza, branco gasto.
✅ Ciclo de caminhada gerado (Canva, mídia `MAHbnB9OICQ`).

**MAYA CORDEIRO, 17** — `17-year-old teenage girl named Maya: shoulder-length straight black hair with blunt bangs, light brown skin, sharp determined eyes, burgundy plaid flannel shirt open over a black turtleneck, dark slim jeans, black combat boots, vintage instant camera hanging from a strap around her neck`
Silhueta: franja reta + câmera no peito. Paleta: bordô xadrez, preto.
✅ Ciclo de caminhada gerado (Canva, mídia `MAHbnMSdEqc`).

**THEO ASHFORD, 21** — `21-year-old young man named Theo, paramedic trainee: tall lean build, short ash-blond hair, light skin, light stubble, long dark navy wool coat over a white hospital scrub shirt, grey scarf, dark trousers, brown boots, flashlight clipped to his belt and a red first-aid pouch`
Silhueta: casaco longo + cachecol. Paleta: azul-marinho, branco, vermelho do kit.
✅ Ciclo de caminhada gerado (Canva, mídia `MAHbnJ6RoB0`).

**NAOMI REYES, 22** — `22-year-old young woman named Naomi, gas station mechanic: athletic build, dark brown skin, curly black hair tied up in a high puff with a red bandana, worn brown leather jacket over a white tank top, grey mechanic jumpsuit tied around her waist, heavy work boots, wrench on her belt`
Silhueta: coque alto + bandana + macacão amarrado. Paleta: couro marrom, cinza, vermelho.
⏳ Pendente (cota do Canva esgotou na geração).

## NPCs (mesmo modelo de prompt)
- **Edith Marlowe** (espírito, benevolente) — `elderly diner owner in her sixties, silver hair in a tight bun, light blue 1970s waitress dress with a white apron, kind tired face` (sem reflexo em espelhos)
- **Sr. Abel / Aurelio Halvorsen** (espírito, o Maestro) — `old night watchman, grey cap, olive work jacket, pocket radio at his ear, gentle grandfather smile, round eyeglasses hidden in his pocket`
- **Lúcia Cordeiro** (espírito) — `small elderly woman, white bob hair, purple cardigan over a dark dress, knitting needles, warm smile`
- **Clara Wynn** (espírito) — `young 1970s nurse, brown hair in a bob under a white nurse cap, old-fashioned white uniform dress, red cross pin`
- **Iris Halvorsen, 8** (espírito) — `8-year-old girl, long dark hair soaking wet, yellow 1970s dress dripping water, barefoot` *(criança: apenas design de personagem, nunca conteúdo impróprio)*
- **Marta Kessler** (espírito) — `woman in her thirties, long auburn hair, dark blue 1970s coat`
- **Jonah Pike** (humano) — `teen boy, messy ginger hair, teal windbreaker, headphones with electrical tape`
- **Walt Greer** (humano) — `bald man in his seventies, brown cardigan, reading glasses on a chain`
- **Padre Tomás Ilha** (humano) — `heavyset priest in black cassock and white collar`
- **Delegado Roy Kessler** (humano) — `broad police chief in his sixties, grey-blue uniform, tired moustache`
- **Benny Okafor** (humano) — `heavyset Nigerian-American man, rust work shirt, cap, oil-stained hands`
- **Dra. Helen Vasquez** (humana) — `doctor in her forties, long black hair, white coat over navy scrubs`
- **Daniel Vance** e **Sam Ashford** — aparecem nas cutscenes/finais.

## Criaturas (humanoides, nada geométrico)
- **Oco** — `emaciated faceless humanoid, too-long limbs and fingers, smooth skin where the face should be, tattered clothes of the person it used to be, cold pale glowing eyes in the dark`
- **A Estática** — `humanoid made of flickering TV static and broken light, body tearing into horizontal scanlines`
- **O Ouvinte** — `very tall blind creature, hunched, spine made of old radio antennas, no eyes, huge ears`
- **O Maestro** — `tall dark silhouette of an old man in a lab coat with round glasses, body wrapped in radio cables, glowing red eyes`

## Onde colocar os arquivos
`art/source/<id>/<animacao>.png` → o CI recorta, remove o fundo e gera `art/characters/<id>/` automaticamente. IDs: `elias, maya, theo, naomi, edith, abel, lucia, clara, iris, marta, jonah, greer, tomas, kessler, benny, helen, daniel, sam, hollow, static, listener, maestro`.
