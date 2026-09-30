#!/usr/bin/env python3
"""
Escolhe quais conversas sincronizam entre as máquinas.

    cc-conversas.py                    lista tudo
    cc-conversas.py ignorar <busca>    para de sincronizar
    cc-conversas.py incluir <busca>    volta a sincronizar

<busca> é parte do nome de uma conversa, ou o nome de um grupo. Grupos são as
pastas em que as sessões foram abertas — uma conversa sobre um projeto, mas
iniciada na pasta de usuário, pertence ao grupo da pasta de usuário.

Ignorar nunca apaga nada: os arquivos ficam na máquina e seguem utilizáveis
aqui. Apenas param de viajar para a outra.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

BRAIN = Path(os.environ.get("BRAIN_DIR") or (Path.home() / "claude-brain"))
HISTORICO = BRAIN / "historico"
IGNORADOS = HISTORICO / ".gitignore"

CABECALHO_IGNORADOS = [
    "# Conversas que você escolheu não sincronizar.",
    "# Os arquivos continuam nesta máquina; apenas param de viajar.",
    "# Use bin/cc-conversas.sh para editar.",
    "",
]


def linhas_ignoradas():
    if not IGNORADOS.exists():
        return []
    return [l.rstrip("\n") for l in IGNORADOS.read_text(encoding="utf-8").splitlines()]


def gravar_ignorados(linhas):
    IGNORADOS.parent.mkdir(parents=True, exist_ok=True)
    IGNORADOS.write_text("\n".join(linhas) + "\n", encoding="utf-8")


def primeira_ocorrencia(caminho, chaves, limite=400):
    """Primeiro valor de texto encontrado para uma das chaves, nas primeiras
    linhas do arquivo. O formato da transcrição é interno ao Claude Code e muda
    entre versões, então isto é sempre uma tentativa, nunca uma garantia."""
    try:
        with caminho.open(encoding="utf-8", errors="replace") as f:
            for i, linha in enumerate(f):
                if i >= limite:
                    break
                try:
                    dado = json.loads(linha)
                except ValueError:
                    continue
                for chave in chaves:
                    valor = dado.get(chave)
                    if isinstance(valor, str) and valor.strip():
                        return valor.strip()
                    if isinstance(valor, dict):
                        conteudo = valor.get("content")
                        if isinstance(conteudo, str) and conteudo.strip():
                            return conteudo.strip()
    except OSError:
        pass
    return None


def titulo_de(grupo_dir, sid):
    # O título que você deu pelo app fica ao lado da transcrição.
    custom = grupo_dir / sid / "custom-title.json"
    if custom.exists():
        try:
            dado = json.loads(custom.read_text(encoding="utf-8"))
            for chave in ("title", "customTitle", "name"):
                valor = dado.get(chave)
                if isinstance(valor, str) and valor.strip():
                    return valor.strip()
        except (OSError, ValueError):
            pass
    jsonl = grupo_dir / f"{sid}.jsonl"
    achado = primeira_ocorrencia(jsonl, ("summary", "title", "message"))
    if achado:
        achado = re.sub(r"\s+", " ", achado)
        return achado[:70] + ("…" if len(achado) > 70 else "")
    return "(sem título)"


def caminho_de(grupo_dir):
    for jsonl in sorted(grupo_dir.glob("*.jsonl")):
        cwd = primeira_ocorrencia(jsonl, ("cwd",), limite=5)
        if cwd:
            return cwd
    return "(sem conversas)"


def tamanho_legivel(n):
    for unidade in ("B", "K", "M", "G"):
        if n < 1024 or unidade == "G":
            return f"{n:.0f}{unidade}" if unidade == "B" else f"{n:.1f}{unidade}"
        n /= 1024
    return f"{n:.1f}G"


def tamanho_de(caminho):
    total = 0
    for raiz, _, arquivos in os.walk(caminho):
        for a in arquivos:
            try:
                total += (Path(raiz) / a).stat().st_size
            except OSError:
                pass
    return total


def levantar():
    """Todos os grupos, com suas conversas."""
    ignorados = set(linhas_ignoradas())
    grupos = []
    if not HISTORICO.is_dir():
        return grupos
    for grupo_dir in sorted(p for p in HISTORICO.iterdir() if p.is_dir()):
        nome = grupo_dir.name
        conversas = []
        for jsonl in sorted(grupo_dir.glob("*.jsonl"), key=lambda p: -p.stat().st_mtime):
            sid = jsonl.stem
            conversas.append({
                "id": sid,
                "titulo": titulo_de(grupo_dir, sid),
                "tamanho": jsonl.stat().st_size + tamanho_de(grupo_dir / sid),
                "ignorada": f"/{nome}/{sid}.jsonl" in ignorados,
            })
        grupos.append({
            "nome": nome,
            "caminho": caminho_de(grupo_dir),
            "tamanho": tamanho_de(grupo_dir),
            "ignorado": f"/{nome}/" in ignorados,
            "conversas": conversas,
        })
    return grupos


def listar():
    grupos = levantar()
    if not grupos:
        print("Nenhuma conversa encontrada em", HISTORICO)
        return
    for g in grupos:
        marca = "ignorado  " if g["ignorado"] else "sincroniza"
        print(f"\n[{marca}] {g['caminho']}  ({tamanho_legivel(g['tamanho'])}, "
              f"{len(g['conversas'])} conversa(s))")
        print(f"             grupo: {g['nome']}")
        for c in g["conversas"]:
            if g["ignorado"]:
                m = "  ·  "
            elif c["ignorada"]:
                m = "  ✗  "
            else:
                m = "  ✓  "
            print(f"{m}{c['titulo']}  ({tamanho_legivel(c['tamanho'])})")
    print("\n  ✓ sincroniza   ✗ ignorada   · dentro de grupo ignorado")
    print("\n  ignorar/incluir uma conversa:  cc-conversas.sh ignorar \"parte do nome\"")
    print("  ignorar/incluir um grupo:      cc-conversas.sh ignorar <nome-do-grupo>")


def procurar(busca):
    """Devolve ('grupo', g) ou ('conversa', g, c), ou levanta as ambiguidades."""
    grupos = levantar()
    alvo = busca.strip().lower()

    for g in grupos:
        if g["nome"].lower() == alvo:
            return [("grupo", g, None)]

    achados = [("conversa", g, c)
               for g in grupos for c in g["conversas"]
               if alvo in c["titulo"].lower()]
    if achados:
        return achados

    for g in grupos:
        if alvo in g["nome"].lower() or alvo in g["caminho"].lower():
            return [("grupo", g, None)]
    return []


def destrava_git(padrao_caminho):
    """O .gitignore só vale para o que o git ainda não conhece: sem isto, um
    arquivo já rastreado continuaria sendo enviado."""
    subprocess.run(
        ["git", "-C", str(BRAIN), "rm", "-r", "--cached", "--quiet", "--", padrao_caminho],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False,
    )


def maiuscula(texto):
    """Só a primeira letra. capitalize() rebaixaria o resto, estragando o
    título que o usuário escreveu."""
    return texto[:1].upper() + texto[1:]


def aplicar(busca, ignorar):
    achados = procurar(busca)
    if not achados:
        print(f"Nada encontrado para \"{busca}\".", file=sys.stderr)
        print("Rode sem argumentos para ver a lista.", file=sys.stderr)
        return 1
    if len(achados) > 1:
        print(f"\"{busca}\" casa com mais de uma conversa. Seja mais específico:\n", file=sys.stderr)
        for _, g, c in achados:
            print(f"  {c['titulo']}", file=sys.stderr)
        return 1

    tipo, g, c = achados[0]
    linhas = linhas_ignoradas() or list(CABECALHO_IGNORADOS)

    if tipo == "grupo":
        entradas = [f"/{g['nome']}/"]
        rotulo = f"o grupo {g['caminho']}"
    else:
        entradas = [f"/{g['nome']}/{c['id']}.jsonl", f"/{g['nome']}/{c['id']}/"]
        rotulo = f"a conversa \"{c['titulo']}\""

    if ignorar:
        novas = [e for e in entradas if e not in linhas]
        if not novas:
            print(f"{maiuscula(rotulo)} já está ignorad{'o' if tipo == 'grupo' else 'a'}.")
            return 0
        gravar_ignorados(linhas + novas)
        for e in entradas:
            destrava_git(f"historico{e.rstrip('/')}")
        print(f"{maiuscula(rotulo)} não será mais sincronizad{'o' if tipo == 'grupo' else 'a'}.")
        print("Os arquivos continuam nesta máquina, intactos.")
        print("\nO que já foi enviado antes segue no histórico do repositório —")
        print("veja \"Tirar conversas já enviadas\" no README para apagar de vez.")
    else:
        restantes = [l for l in linhas if l not in entradas]
        if len(restantes) == len(linhas):
            print(f"{maiuscula(rotulo)} já sincroniza.")
            return 0
        gravar_ignorados(restantes)
        print(f"{maiuscula(rotulo)} volta a sincronizar no próximo envio.")
    return 0


def main():
    if not HISTORICO.is_dir():
        print(f"não encontrei {HISTORICO}", file=sys.stderr)
        return 1
    args = sys.argv[1:]
    if not args or args[0] == "listar":
        listar()
        return 0
    if args[0] in ("ignorar", "incluir") and len(args) >= 2:
        return aplicar(" ".join(args[1:]), ignorar=(args[0] == "ignorar"))
    print("uso: cc-conversas.sh [listar | ignorar <busca> | incluir <busca>]", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
