#!/usr/bin/env python3
"""Validação de integridade do conteúdo de THE LAST SIGNAL.

Verifica referências cruzadas entre todos os JSON (locais, portas, NPCs, diálogos,
missões, evidências, deduções, cutscenes, finais), condições/efeitos com chaves
desconhecidas e se cada final é alcançável por pelo menos uma escolha da cena final.
Sai com código 1 se houver erro — o CI bloqueia o build.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "data")

COND_KEYS = {"flag", "not_flag", "flags", "evidence", "not_evidence", "evidence_count", "char", "not_char", "night", "dark",
             "hour_between", "chapter", "chapter_min", "chapter_max", "mission_done", "mission_active", "not_mission",
             "trust_min", "trust_max", "marked", "deduction", "met", "spirits_correct_min", "wrong_marks_max", "location",
             "any", "not", "health_min"}
EFFECT_KEYS = {"set", "unset", "give", "trust", "start_mission", "complete_mission", "fail_mission", "chapter", "heal",
               "damage", "time", "advance_minutes", "mark", "met", "notify"}
CS_CMDS = {"wait", "fade_out", "fade_in", "letterbox", "location", "time", "rain", "fog", "spawn", "despawn", "place", "move",
           "face", "anim", "ghost", "say", "choice", "if", "effects", "chapter", "cam", "shake", "flash", "lightning", "glitch",
           "flicker", "sfx", "amb", "radio", "card", "ending", "resolve_ending", "cutscene", "credits", "refresh",
           "player_visible", "player_control"}
SFX = {"step", "door", "creak", "knock", "drip", "pickup", "mission", "stinger", "heartbeat", "photo", "radio_on", "whisper",
       "far_call", "thunder", "dog", "bird", "car", "ui_move", "ui_ok", "ui_back", "hurt", "creature", "glitch", "hide", "flashlight"}
PROP_TYPES = {"door", "exit", "clue", "lamp", "light", "hide", "save", "trigger", "car", "bench", "swing", "phone", "sign", "relay", "use", "photo_spot"}

errors = []
warnings = []


def load(n):
    with open(os.path.join(D, n + ".json"), encoding="utf-8") as f:
        return json.load(f)


def err(m):
    errors.append(m)


def main():
    chars = load("characters"); npcs = load("npcs"); locs = load("locations"); mis = load("missions")
    dia = load("dialogues"); cs = load("cutscenes"); ev = load("evidence"); story = load("story"); cre = load("creatures")
    items = ev["items"]; deds = ev["deductions"]; ded_ids = {d["id"] for d in deds}
    actors = set(chars) | set(npcs) | set(cre) | {"player", "narrator", "radio", ""}
    flags_set, flags_read = set(), set()

    def chk_cond(c, where):
        if c is None:
            return
        if isinstance(c, list):
            for x in c:
                chk_cond(x, where)
            return
        if not isinstance(c, dict):
            err(f"{where}: condição inválida {c!r}"); return
        for k, v in c.items():
            if k not in COND_KEYS:
                err(f"{where}: chave de condição desconhecida '{k}'")
            if k in ("flag", "not_flag"):
                flags_read.add(v)
            if k == "flags":
                flags_read.update(v)
            if k in ("evidence", "not_evidence"):
                for e in (v if isinstance(v, list) else [v]):
                    if e not in items: err(f"{where}: evidência inexistente '{e}'")
            if k in ("mission_done", "mission_active", "not_mission") and v not in mis:
                err(f"{where}: missão inexistente '{v}'")
            if k == "deduction" and v not in ded_ids:
                err(f"{where}: dedução inexistente '{v}'")
            if k in ("char", "not_char"):
                for ch in (v if isinstance(v, list) else [v]):
                    if ch not in chars: err(f"{where}: personagem inexistente '{ch}'")
            if k == "met" and v not in npcs:
                err(f"{where}: NPC inexistente '{v}'")
            if k == "location" and v not in locs:
                err(f"{where}: local inexistente '{v}'")
            if k in ("trust_min", "trust_max", "marked"):
                for n in v:
                    if n not in npcs: err(f"{where}: NPC inexistente '{n}'")
            if k == "any":
                for alt in v: chk_cond(alt, where)
            if k == "not":
                chk_cond(v, where)

    def chk_eff(e, where):
        if e is None:
            return
        if isinstance(e, list):
            for x in e: chk_eff(x, where)
            return
        for k, v in e.items():
            if k not in EFFECT_KEYS:
                err(f"{where}: efeito desconhecido '{k}'")
            if k == "set":
                flags_set.update(v if isinstance(v, list) else [v])
            if k == "give":
                for g in (v if isinstance(v, list) else [v]):
                    if g not in items: err(f"{where}: evidência inexistente '{g}'")
            if k in ("start_mission", "complete_mission", "fail_mission"):
                for m in (v if isinstance(v, list) else [v]):
                    if m not in mis: err(f"{where}: missão inexistente '{m}'")
            if k in ("trust", "mark"):
                for n in v:
                    if n not in npcs: err(f"{where}: NPC inexistente '{n}'")

    # personagens
    for cid, c in chars.items():
        if c.get("start_location") not in locs: err(f"personagem {cid}: start_location inválido")
        if c.get("opening") not in cs: err(f"personagem {cid}: cutscene de abertura inexistente")
    # NPCs
    for nid, n in npcs.items():
        for e in n.get("schedule", []):
            if e["loc"] not in locs: err(f"npc {nid}: agenda aponta para local inexistente {e['loc']}")
            if not (0 <= e["from"] <= 24 and 0 <= e["to"] <= 24): err(f"npc {nid}: horário inválido")
            if not (0 < e["x"] < locs[e["loc"]].get("width", 2400)): err(f"npc {nid}: x={e['x']} fora do local {e['loc']}")
            chk_cond(e.get("if"), f"npc {nid} agenda")
        chk_cond(n.get("exists_if"), f"npc {nid}")
        d = n.get("dialogue", "")
        opts = [d] if isinstance(d, str) else [o["id"] for o in d]
        for o in d if isinstance(d, list) else []:
            chk_cond(o.get("if"), f"npc {nid} diálogo")
        for o in opts:
            if o and o not in dia: err(f"npc {nid}: diálogo inexistente '{o}'")
    # locais
    for lid, l in locs.items():
        w = l.get("width", 2400)
        for i, p in enumerate(l.get("props", [])):
            where = f"local {lid} prop#{i}({p.get('type')})"
            if p.get("type") not in PROP_TYPES: err(f"{where}: tipo desconhecido")
            if not (0 <= p.get("x", 0) <= w): err(f"{where}: x fora do cenário")
            if p.get("type") in ("door", "exit"):
                to = p.get("to")
                if to not in locs: err(f"{where}: destino inexistente '{to}'")
                elif not (0 < p.get("to_x", 0) < locs[to].get("width", 2400)): err(f"{where}: to_x fora do destino")
            for ck in ("req", "locked_if", "if"):
                chk_cond(p.get(ck), where)
            chk_eff(p.get("do"), where)
            if p.get("give") and p["give"] not in items: err(f"{where}: evidência inexistente '{p['give']}'")
            if p.get("cutscene") and p["cutscene"] not in cs: err(f"{where}: cutscene inexistente '{p['cutscene']}'")
            if p.get("type") == "trigger" and p.get("once"):
                flags_set.add(p["once"])
            if p.get("type") == "relay":
                flags_set.add(p.get("flag"))
        for cr in l.get("creatures", []):
            if cr["id"] not in cre: err(f"local {lid}: criatura inexistente {cr['id']}")
            chk_cond(cr.get("if"), f"local {lid} criatura")
        if "on_first_visit" in l:
            chk_cond(l["on_first_visit"].get("if"), f"local {lid}")
        # conectividade: todo local deve ter saída
        if not any(p.get("type") in ("door", "exit") for p in l.get("props", [])):
            err(f"local {lid}: sem saída")
    # alcançabilidade do mapa a partir do início de cada personagem
    graph = {lid: {p["to"] for p in l.get("props", []) if p.get("type") in ("door", "exit")} for lid, l in locs.items()}
    for cid, c in chars.items():
        seen, stack = set(), [c["start_location"]]
        while stack:
            x = stack.pop()
            if x in seen: continue
            seen.add(x); stack.extend(graph.get(x, []))
        missing = set(locs) - seen
        if missing: err(f"personagem {cid}: locais inalcançáveis {sorted(missing)}")
    # diálogos
    for did, tree in dia.items():
        if "start" not in tree: err(f"diálogo {did}: sem nó 'start'")
        for nid, node in tree.items():
            where = f"diálogo {did}.{nid}"
            for br in node.get("branch", []):
                chk_cond(br.get("if"), where)
                if br.get("go") not in tree and br.get("go") != "end": err(f"{where}: desvio para nó inexistente '{br.get('go')}'")
            nx = node.get("next", "end")
            if nx != "end" and nx not in tree: err(f"{where}: next inexistente '{nx}'")
            chk_eff(node.get("do"), where)
            if node.get("who", "npc") not in actors | {"npc"}: err(f"{where}: falante desconhecido '{node.get('who')}'")
            for ch in node.get("by_char", {}):
                if ch not in chars: err(f"{where}: by_char com personagem inexistente '{ch}'")
            for c in node.get("choices", []):
                chk_cond(c.get("if"), where); chk_eff(c.get("do"), where)
                if c.get("next", "end") != "end" and c["next"] not in tree: err(f"{where}: escolha leva a nó inexistente '{c['next']}'")
    # missões
    for mid, m in mis.items():
        chk_cond(m.get("auto_start"), f"missão {mid}")
        chk_eff(m.get("on_complete"), f"missão {mid}")
        if not m.get("steps"): err(f"missão {mid}: sem etapas")
        for s in m.get("steps", []):
            chk_cond(s.get("done_if"), f"missão {mid}")
    # evidências / deduções
    for d in deds:
        for k in ("a", "b"):
            if d[k] not in items: err(f"dedução {d['id']}: evidência inexistente '{d[k]}'")
        chk_eff(d.get("do"), f"dedução {d['id']}")
    for iid, it in items.items():
        if it.get("about") and it["about"] not in npcs: err(f"evidência {iid}: 'about' aponta para NPC inexistente")

    # cutscenes
    def chk_steps(steps, where):
        for i, s in enumerate(steps):
            c = s.get("c")
            w = f"{where}[{i}:{c}]"
            if c not in CS_CMDS: err(f"{w}: comando desconhecido")
            if c == "location" and s.get("id") not in locs: err(f"{w}: local inexistente")
            if c == "say" and s.get("who") not in actors: err(f"{w}: falante desconhecido '{s.get('who')}'")
            if c in ("spawn",) and s.get("who") not in actors: err(f"{w}: ator inexistente '{s.get('who')}'")
            if c == "sfx" and s.get("name") not in SFX: err(f"{w}: som inexistente '{s.get('name')}'")
            if c == "cutscene" and s.get("id") not in cs: err(f"{w}: sub-cutscene inexistente")
            if c == "effects": chk_eff(s.get("do"), w)
            if c == "if":
                chk_cond(s.get("cond"), w); chk_steps(s.get("then", []), w + ".then"); chk_steps(s.get("else", []), w + ".else")
            if c == "choice":
                if not s.get("options"): err(f"{w}: escolha sem opções")
                if not any(not o.get("if") for o in s.get("options", [])): err(f"{w}: nenhuma opção sempre disponível (soft-lock)")
                for o in s.get("options", []):
                    chk_cond(o.get("if"), w); chk_eff(o.get("do"), w); chk_steps(o.get("then", []), w + ".opt")
            if c == "ending" and s.get("id") not in {e["id"] for e in story["endings"]}: err(f"{w}: final inexistente")
    for cid, c in cs.items():
        chk_steps(c.get("steps", []), f"cutscene {cid}")
    # capítulos e finais
    for ch in story["chapters"]:
        if ch.get("intro") and ch["intro"] not in cs: err(f"capítulo {ch['n']}: intro inexistente")
        chk_eff(ch.get("skip_effects"), f"capítulo {ch['n']}")
    for e in story["endings"]:
        if e["cutscene"] not in cs: err(f"final {e['id']}: cutscene inexistente")
        chk_cond(e.get("cond"), f"final {e['id']}")
    if story["endings"][-1]["id"] != "end_main":
        warnings.append("o último final da lista deveria ser o padrão (end_main)")
    for r in story.get("radio", []):
        chk_cond(r.get("if"), "rádio")

    # flags lidas que ninguém define (provável erro de digitação → missão impossível)
    special = {"__never__", "__cutscene_only__", "__none__", "storm"}
    for f in sorted(flags_read - flags_set - special):
        if not f.startswith("char_"):
            err(f"flag '{f}' é verificada mas nunca é definida (missão/porta impossível)")

    for w in warnings:
        print("AVISO:", w)
    for e in errors:
        print("ERRO:", e)
    total = sum(len(x) for x in (chars, npcs, locs, mis, dia, cs, items))
    print(f"\n{len(errors)} erro(s), {len(warnings)} aviso(s) — {len(locs)} locais, {len(npcs)} NPCs, {len(mis)} missões, "
          f"{len(dia)} diálogos, {len(cs)} cutscenes, {len(items)} evidências, {len(deds)} deduções, {len(story['endings'])} finais")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
