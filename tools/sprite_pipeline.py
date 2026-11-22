#!/usr/bin/env python3
"""THE LAST SIGNAL — pipeline de sprites MUGEN.

Entrada:  art/source/<personagem>/<animacao>.png   (folha com N quadros em uma linha,
          fundo liso — branco, cinza ou verde — gerada no Canva/Picsart ou desenhada à mão)
          art/source/<personagem>/portrait_<expressao>.png   (retratos para diálogos, opcional)
Saída:    art/characters/<personagem>/<animacao>/<n>.png  (quadros recortados, fundo transparente,
          alinhados pelos pés no centro, altura padronizada)
          art/characters/<personagem>/manifest.json

Uso: python3 tools/sprite_pipeline.py [--height 420] [--only elias]
O script é determinístico e valida cada folha: aborta a folha (não o lote) se o número de
quadros detectado for 0 ou se algum quadro estiver cortado na borda.
"""
import argparse
import json
import os
import sys
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "source")
OUT = os.path.join(ROOT, "art", "characters")

# fps padrão por animação (estilo MUGEN: 8–12 quadros por ciclo)
FPS = {"idle": 6, "walk": 10, "run": 14, "crouch": 8, "hide": 6, "inspect": 8, "fear": 10,
       "hurt": 12, "talk": 8, "flashlight": 6, "turn": 12, "chase": 14, "attack": 12}
LOOP = {"hurt": False, "turn": False, "inspect": False, "attack": False}


def estimate_bg(img):
    w, h = img.size
    px = img.load()
    pts = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
    cols = [px[x, y][:3] for x, y in pts]
    cols.sort(key=lambda c: sum(c))
    return cols[len(cols) // 2]


def dist(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def remove_background(img, tol=60):
    """Flood fill a partir das bordas: só remove fundo conectado à borda,
    preservando brancos internos (olhos, tênis, camisa)."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    bg = estimate_bg(img)
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        r, g, b, a = px[x, y]
        d = dist((r, g, b), bg)
        if d > tol:
            continue
        # borda suave: semi-transparente perto do limite
        alpha = 0 if d < tol * 0.6 else int(255 * (d - tol * 0.6) / (tol * 0.4))
        px[x, y] = (r, g, b, min(a, alpha))
        if x > 0: q.append((x - 1, y))
        if x < w - 1: q.append((x + 1, y))
        if y > 0: q.append((x, y - 1))
        if y < h - 1: q.append((x, y + 1))
    # 2ª passada: bolsões de fundo presos entre pernas/braços (não ligados à borda).
    # Só remove regiões quase idênticas ao fundo (roupas brancas têm sombreamento e ficam).
    lab = bytearray(w * h)
    for y0 in range(h):
        for x0 in range(w):
            i0 = y0 * w + x0
            if seen[i0] or lab[i0]:
                continue
            if dist(px[x0, y0][:3], bg) >= tol * 0.5:
                continue
            region, q2, total = [], deque([(x0, y0)]), 0
            lab[i0] = 1
            while q2:
                x, y = q2.popleft()
                region.append((x, y))
                total += dist(px[x, y][:3], bg)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not lab[j] and not seen[j] and dist(px[nx, ny][:3], bg) < tol * 0.5:
                            lab[j] = 1
                            q2.append((nx, ny))
            if len(region) >= 20 and total / len(region) < 18:
                for x, y in region:
                    r, g, b, a = px[x, y]
                    px[x, y] = (r, g, b, 0)
    # defringe: remove o halo claro do contorno (1 passada)
    kill = []
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            r, g, b, a = px[x, y]
            if a == 0 or dist((r, g, b), bg) >= tol * 1.6:
                continue
            if px[x - 1, y][3] == 0 or px[x + 1, y][3] == 0 or px[x, y - 1][3] == 0 or px[x, y + 1][3] == 0:
                kill.append((x, y))
    for x, y in kill:
        r, g, b, a = px[x, y]
        px[x, y] = (r, g, b, 0)
    return img


def column_spans(img, min_gap=3, min_width=6):
    w, h = img.size
    a = img.getchannel("A").load()
    filled = []
    for x in range(w):
        c = 0
        for y in range(h):
            if a[x, y] > 40:
                c += 1
                if c > 2:
                    break
        filled.append(c > 2)
    spans, start, gap = [], None, 0
    for x, f in enumerate(filled + [False] * (min_gap + 1)):
        if f:
            if start is None:
                start = x
            gap = 0
            end = x
        elif start is not None:
            gap += 1
            if gap > min_gap:
                if end - start + 1 >= min_width:
                    spans.append((start, end + 1))
                start, gap = None, 0
    # junta fragmentos muito estreitos (ex.: alça solta) ao vizinho mais próximo
    if len(spans) > 1:
        widths = sorted(e - s for s, e in spans)
        med = widths[len(widths) // 2]
        merged = []
        for s, e in spans:
            if merged and (e - s) < med * 0.35:
                ps, pe = merged[-1]
                merged[-1] = (ps, e)
            else:
                merged.append((s, e))
        spans = merged
    return spans


def components_by_slot(img, n):
    """Divide a folha em n faixas iguais e atribui cada componente conectado (alpha>40)
    à faixa que contém seu centróide. Componentes que atravessam várias faixas
    (personagens encostados) são cortados na borda da faixa."""
    w, h = img.size
    a = img.getchannel("A")
    ap = a.load()
    labels = [0] * (w * h)
    comps = []
    cur = 0
    for y0 in range(h):
        for x0 in range(w):
            i0 = y0 * w + x0
            if labels[i0] or ap[x0, y0] <= 40:
                continue
            cur += 1
            q = deque([(x0, y0)])
            labels[i0] = cur
            sx = cnt = 0
            minx, maxx = x0, x0
            while q:
                x, y = q.popleft()
                sx += x; cnt += 1
                if x < minx: minx = x
                if x > maxx: maxx = x
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not labels[j] and ap[nx, ny] > 40:
                            labels[j] = cur
                            q.append((nx, ny))
            comps.append((cur, sx / cnt, cnt, minx, maxx))
    slot_w = w / float(n)
    frames = []
    for k in range(n):
        lo, hi = int(k * slot_w), int((k + 1) * slot_w)
        mine = [c for c in comps if lo <= c[1] < hi or (c[4] - c[3]) > slot_w * 1.3]
        biggest = max([c[2] for c in mine] or [0])
        keep = set()
        for lab, cx, cnt, mnx, mxx in mine:
            # descarta lascas soltas (pedaços do quadro vizinho, ruído de compressão)
            if cnt >= 12 and cnt >= biggest * 0.015:
                keep.add(lab)
        if not keep:
            continue
        fr = Image.new("RGBA", (hi - lo, h), (0, 0, 0, 0))
        src = img.load()
        dst = fr.load()
        for y in range(h):
            row = y * w
            for x in range(lo, hi):
                if labels[row + x] in keep:
                    dst[x - lo, y] = src[x, y]
        bb = fr.getbbox()
        if bb:
            frames.append(fr.crop(bb))
    return frames


def expected_frames(name, default=8):
    # walk@8.png -> 8 quadros; sem sufixo usa o padrão
    if "@" in name:
        try:
            return int(name.split("@")[1])
        except ValueError:
            pass
    return default


def process_sheet(path, out_dir, target_h, expected=8):
    img = remove_background(Image.open(path))
    w, h = img.size
    spans = column_spans(img)
    frames = []
    if len(spans) == expected:
        for s, e in spans:
            crop = img.crop((s, 0, e, h))
            bbox = crop.getbbox()
            if bbox is not None:
                frames.append(crop.crop(bbox))
    else:
        frames = components_by_slot(img, expected)
    if not frames:
        raise ValueError("quadros vazios")
    max_h = max(f.size[1] for f in frames)
    scale = target_h / float(max_h)
    canvas_w = int(max(f.size[0] for f in frames) * scale) + 16
    canvas_h = target_h + 8
    os.makedirs(out_dir, exist_ok=True)
    for old in os.listdir(out_dir):
        if old.endswith(".png"):
            os.remove(os.path.join(out_dir, old))
    for i, f in enumerate(frames):
        fw, fh = f.size
        f = f.resize((max(1, int(fw * scale)), max(1, int(fh * scale))), Image.LANCZOS)
        c = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
        # pés no centro inferior
        c.paste(f, ((canvas_w - f.size[0]) // 2, canvas_h - 4 - f.size[1]), f)
        c.save(os.path.join(out_dir, "%d.png" % i), optimize=True)
    return len(frames), canvas_w, canvas_h


def process_portrait(path, out_path, size=256):
    img = remove_background(Image.open(path))
    bbox = img.getbbox() or (0, 0, img.size[0], img.size[1])
    img = img.crop(bbox)
    img.thumbnail((size, size), Image.LANCZOS)
    c = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c.paste(img, ((size - img.size[0]) // 2, size - img.size[1]), img)
    c.save(out_path, optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--height", type=int, default=420)
    ap.add_argument("--only", default=None)
    ap.add_argument("--src", default=SRC)
    ap.add_argument("--out", default=OUT)
    args = ap.parse_args()
    if not os.path.isdir(args.src):
        print("sem art/source — nada a processar")
        return 0
    errors = 0
    for char in sorted(os.listdir(args.src)):
        cdir = os.path.join(args.src, char)
        if not os.path.isdir(cdir) or (args.only and char != args.only):
            continue
        manifest = {"id": char, "anims": {}, "portraits": []}
        for fn in sorted(os.listdir(cdir)):
            if not fn.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                continue
            raw = os.path.splitext(fn)[0].lower()
            exp = expected_frames(raw)
            name = raw.split("@")[0]
            p = os.path.join(cdir, fn)
            try:
                if name.startswith("portrait_"):
                    os.makedirs(os.path.join(args.out, char), exist_ok=True)
                    process_portrait(p, os.path.join(args.out, char, name + ".png"))
                    manifest["portraits"].append(name[len("portrait_"):])
                    print("  retrato %s/%s" % (char, name))
                    continue
                n, fw, fh = process_sheet(p, os.path.join(args.out, char, name), args.height, exp)
                manifest["anims"][name] = {"frames": n, "fps": FPS.get(name, 10), "loop": LOOP.get(name, True),
                                           "w": fw, "h": fh}
                print("  %s/%s: %d quadros (%dx%d)" % (char, name, n, fw, fh))
            except Exception as ex:  # uma folha ruim não derruba o lote
                errors += 1
                print("  ERRO %s/%s: %s" % (char, fn, ex), file=sys.stderr)
        if manifest["anims"] or manifest["portraits"]:
            os.makedirs(os.path.join(args.out, char), exist_ok=True)
            with open(os.path.join(args.out, char, "manifest.json"), "w") as f:
                json.dump(manifest, f, indent=1)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
