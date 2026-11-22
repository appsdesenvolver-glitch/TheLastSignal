#!/usr/bin/env python3
"""Verificação estrutural leve de GDScript (não substitui o compilador do Godot,
que roda no CI): indentação só com tabs, blocos abertos com ':' seguidos de corpo,
parênteses/colchetes balanceados, lambdas de uma linha com 'if' (inválido),
'return' após ':=' sem tipo inferível em chamadas dinâmicas comuns, e
referências a métodos inexistentes entre scripts conhecidos (heurística)."""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
problems = []


def strip_strings(line):
    out, q, i = [], None, 0
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\":
                i += 2
                continue
            if c == q:
                q = None
            i += 1
            continue
        if c in "\"'":
            q = c
            i += 1
            continue
        if c == "#":
            break
        out.append(c)
        i += 1
    return "".join(out)


def check(path):
    rel = os.path.relpath(path, ROOT)
    lines = open(path, encoding="utf-8").read().split("\n")
    depth = 0
    in_ml_string = False
    pending_block = None
    for n, raw in enumerate(lines, 1):
        if raw.count('"""') % 2 == 1:
            in_ml_string = not in_ml_string
            continue
        if in_ml_string:
            continue
        if raw.strip() == "":
            continue
        lead = raw[: len(raw) - len(raw.lstrip())]
        if " " in lead and depth == 0:
            problems.append(f"{rel}:{n}: indentação com espaços")
        code = strip_strings(raw)
        indent = len(lead)
        if pending_block is not None and depth == 0:
            want, ln = pending_block
            if indent <= want and code.strip():
                problems.append(f"{rel}:{ln}: bloco aberto com ':' sem corpo indentado")
            pending_block = None
        stripped = code.strip()
        if re.search(r"func\s*\([^)]*\)\s*:\s*(if|for|while)\b", stripped):
            problems.append(f"{rel}:{n}: lambda de uma linha com if/for (inválido em GDScript)")
        if re.search(r"\bvar\s+\w+\s*:=\s*null\b", stripped):
            problems.append(f"{rel}:{n}: ':=' com null não infere tipo")
        if re.search(r"\bvar\s+\w+\s*:=\s*(world|hud|dialogue|notebook|cutscene|touch)\.\w+\(", stripped):
            problems.append(f"{rel}:{n}: ':=' com chamada dinâmica (tipo não inferível)")
        opened = stripped.count("(") + stripped.count("[") + stripped.count("{")
        closed = stripped.count(")") + stripped.count("]") + stripped.count("}")
        prev_depth = depth
        depth += opened - closed
        if depth < 0:
            problems.append(f"{rel}:{n}: fechamento sem abertura")
            depth = 0
        if prev_depth == 0 and depth == 0 and stripped.endswith(":") and not stripped.startswith("#"):
            pending_block = (indent, n)
        if prev_depth > 0 and depth == 0 and stripped.endswith(":"):
            pending_block = (indent, n)
    if depth != 0:
        problems.append(f"{rel}: parênteses desbalanceados no fim do arquivo ({depth})")


def method_index():
    """Mapa script -> métodos definidos, para checar chamadas world.X / Game.X etc."""
    idx = {}
    for dp, _, fs in os.walk(os.path.join(ROOT, "scripts")):
        for f in fs:
            if f.endswith(".gd"):
                src = open(os.path.join(dp, f), encoding="utf-8").read()
                idx[f[:-3]] = set(re.findall(r"^(?:static\s+)?func\s+(\w+)", src, re.M)) | set(re.findall(r"^(?:static\s+)?var\s+(\w+)", src, re.M)) | set(re.findall(r"^signal\s+(\w+)", src, re.M)) | set(re.findall(r"^const\s+(\w+)", src, re.M)) | set(re.findall(r"^enum\s+(\w+)", src, re.M))
    return idx


def cross_refs():
    idx = method_index()
    aliases = {"Game": "game", "Data": "data", "Clock": "clock", "Sfx": "audio", "Art": "art", "world": "world",
               "hud": "hud", "dialogue": "dialogue", "notebook": "notebook", "fx": "fx", "UIStyle": "ui_style",
               "Backdrop": "backdrop", "Creature": "creature"}
    node2d = {"position", "visible", "modulate", "queue_free", "get_children", "add_child", "queue_redraw", "name", "get",
              "set_process", "is_instance_valid", "new", "scale", "rotation", "get_tree", "create_tween", "emit", "connect"}
    for dp, _, fs in os.walk(os.path.join(ROOT, "scripts")):
        for f in fs:
            if not f.endswith(".gd"):
                continue
            path = os.path.join(dp, f)
            for n, line in enumerate(open(path, encoding="utf-8"), 1):
                code = strip_strings(line)
                for obj, member in re.findall(r"\b(Game|Data|Clock|Sfx|Art|world|hud|dialogue|notebook|fx|UIStyle|Backdrop|Creature)\.(\w+)", code):
                    script = aliases[obj]
                    if script not in idx:
                        continue
                    if member in idx[script] or member in node2d:
                        continue
                    if obj in ("world",) and f == "world.gd":
                        continue
                    if obj == "fx" and member in ("fade_rect", "camera"):
                        continue
                    problems.append(f"{os.path.relpath(path, ROOT)}:{n}: '{obj}.{member}' não existe em {script}.gd")


if __name__ == "__main__":
    for dp, _, fs in os.walk(os.path.join(ROOT, "scripts")):
        for f in fs:
            if f.endswith(".gd"):
                check(os.path.join(dp, f))
    cross_refs()
    for p in problems:
        print(p)
    print(f"{len(problems)} problema(s)")
    sys.exit(1 if problems else 0)
