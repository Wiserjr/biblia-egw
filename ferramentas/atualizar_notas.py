"""Regrava só as notas de estudo em ``assets/estudo.db.gz``.

    python ferramentas/atualizar_notas.py

Depois de revisar ``ferramentas/notas/NN-livro.txt`` não é preciso refazer o
banco inteiro com o ``construir_estudo.py`` (que exige os 106 PDFs indexados
em ``ferramentas/cache/``): este script abre o banco atual, troca a tabela
``nota`` pelas notas dos arquivos, com as mesmas conferências (versículos que
existem, citações "O Desejado, cap. N" que existem no índice), e grava de
novo. As notas geradas (``cache/notas.jsonl``), se houver, entram também.
"""
import gzip
import os
import shutil
import sqlite3
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import construir_estudo as ce  # noqa: E402


def main():
    tmp = tempfile.mkdtemp()
    try:
        biblia = os.path.join(tmp, "biblia.db")
        with gzip.open(ce.BIBLIA) as g, open(biblia, "wb") as f:
            shutil.copyfileobj(g, f)
        textos, _ = ce._texto_ara(biblia)
        existe = {(l, c * 1000 + v) for (l, c, v) in textos}

        caminho = os.path.join(tmp, "estudo.db")
        with gzip.open(ce.DESTINO) as g, open(caminho, "wb") as f:
            shutil.copyfileobj(g, f)
        con = sqlite3.connect(caminho)
        antes = con.execute("SELECT count(*) FROM nota").fetchone()[0]
        con.execute("DROP INDEX IF EXISTS ix_nota")
        con.execute("DELETE FROM nota")
        ce.notas(con, existe)
        con.commit()
        con.execute("VACUUM")
        con.close()

        with open(caminho, "rb") as f, \
                gzip.GzipFile(ce.DESTINO, "wb", compresslevel=9, mtime=0) as g:
            shutil.copyfileobj(f, g)
        print("Regravado %s (%.1f MB; antes havia %d notas)" % (
            ce.DESTINO, os.path.getsize(ce.DESTINO) / 1e6, antes))
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
