"""Acrescenta as traduções de damarals/biblias, preservando as existentes.

python ferramentas/importar_damarals.py [checkout da fonte]
O checkout padrão é baixado na revisão fixada, para permitir reprodução.
"""
import gzip
from contextlib import closing
import json
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile

from referencias_pt import CAPITULOS

RAIZ = Path(__file__).resolve().parents[1]
REVISAO = "08bfb8f3d569e5a8dd53a0ebefafda416eb066d7"
FONTE = "https://github.com/damarals/biblias"
NOVAS = ("AS21", "JFAA", "KJF", "NBV", "TB", "ALM1911", "OL", "MENS", "VFL")


def obter_fonte():
    pasta = RAIZ / "ferramentas/cache/damarals-biblias"
    if not pasta.exists():
        subprocess.run(["git", "clone", FONTE, str(pasta)], check=True)
    subprocess.run(["git", "-C", str(pasta), "checkout", "--detach", REVISAO], check=True)
    return pasta


def acrescentar(db, pasta):
    """Valida cada versão antes de inserir. IDs fixos não alteram preferências."""
    db.execute("CREATE TABLE IF NOT EXISTS versiculo_intervalo ("
               "versao INTEGER, livro INTEGER, capitulo INTEGER, inicio INTEGER, "
               "fim INTEGER, PRIMARY KEY(versao,livro,capitulo,inicio))")
    for vid, sigla in enumerate(NOVAS, 16):
        existente = db.execute("SELECT id FROM versao WHERE sigla=?", (sigla,)).fetchone()
        if existente:
            if existente[0] != vid:
                raise ValueError(f"ID inesperado para {sigla}")
            continue
        diretorio = Path(pasta) / "data/canonical" / sigla
        meta = json.loads((diretorio / "meta.json").read_text(encoding="utf-8"))
        linhas, intervalos, livros = [], [], set()
        for arquivo in sorted(diretorio.glob("*.json")):
            if arquivo.name == "meta.json":
                continue
            livro = json.loads(arquivo.read_text(encoding="utf-8"))
            n = livro["id"]
            if not 1 <= n <= 66 or n in livros:
                raise ValueError(f"Livro inválido em {arquivo}")
            livros.add(n)
            caps = livro["chapters"]
            if {c["number"] for c in caps} != set(range(1, CAPITULOS[n-1]+1)):
                raise ValueError(f"Capítulos incompletos em {arquivo}")
            for cap in caps:
                if not cap["verses"]:
                    raise ValueError(f"Capítulo vazio em {arquivo}")
                for verso in cap["verses"]:
                    texto, numero = verso["text"].strip(), verso["number"]
                    if not texto or numero < 1:
                        raise ValueError(f"Versículo inválido em {arquivo}")
                    linhas.append((vid, n, cap["number"], numero, texto))
                    grupo = re.match(r"^(\d+)[-–](\d+)\s", texto)
                    if sigla == "MENS" and grupo and int(grupo[1]) == numero:
                        fim = int(grupo[2])
                        if fim < numero:
                            print(f"Aviso: intervalo invertido na fonte: {sigla} {n}:{cap['number']}:{numero}")
                            continue
                        intervalos.append((vid, n, cap["number"], numero, fim))
        if livros != set(range(1, 67)):
            raise ValueError(f"{sigla}: faltam livros")
        db.execute("INSERT INTO versao VALUES (?,?,?,?)", (vid, sigla, meta["name"], vid-4))
        db.executemany("INSERT INTO versiculo VALUES (?,?,?,?,?)", linhas)
        db.executemany("INSERT INTO versiculo_intervalo VALUES (?,?,?,?,?)", intervalos)
        db.execute("INSERT OR REPLACE INTO info VALUES (?,?)", (
            "fonte_" + sigla, json.dumps({**meta, "repositorio": FONTE, "revisao": REVISAO}, ensure_ascii=False)))
        print(f"{sigla}: {len(linhas)} registros, {len(intervalos)} intervalos")


def main():
    pasta = Path(sys.argv[1]) if len(sys.argv) > 1 else obter_fonte()
    asset = RAIZ / "assets/biblia.db.gz"
    with tempfile.TemporaryDirectory() as temporario:
        banco = Path(temporario) / "biblia.db"
        banco.write_bytes(gzip.decompress(asset.read_bytes()))
        with closing(sqlite3.connect(banco)) as db:
            with db:
                acrescentar(db, pasta)
                if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                    raise ValueError("Banco inválido")
        parcial = asset.with_suffix(".gz.parcial")
        with banco.open("rb") as entrada, gzip.GzipFile(str(parcial), "wb", mtime=0) as saida:
            shutil.copyfileobj(entrada, saida)
        parcial.replace(asset)


if __name__ == "__main__":
    main()
