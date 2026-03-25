import os
import pandas as pd

# 1. Leer todos los KO_ID posibles desde el diccionario
ko_ids = set()

with open("dictionary.txt", "r") as f:
    next(f, None)  # Saltar encabezado
    for line in f:
        raw = line.replace("\xa0", " ").strip()
        if not raw:
            continue

        parts = raw.split("\t")
        if len(parts) < 2:
            parts = raw.split()
        if len(parts) < 2:
            continue

        ko = parts[0].strip()
        if ko:
            ko_ids.add(ko)

# 2. Inicializar matriz
records = []

# 3. Procesar cada archivo *_filtered_blastp.tsv
for file in os.listdir():
    if file.endswith("_filtered_blastp.tsv"):
        df = pd.read_csv(file, sep="\t", header=None)
        sample = file

        # Extraer KO_IDs únicos de columna 13 (índice 12)
        found_kos = set(df.iloc[:, 12].dropna().unique())

        # Crear fila de presencia/ausencia para todos los KO_IDs del diccionario
        row = {"Sample": sample}
        for ko in sorted(ko_ids):  # opcional: orden alfabético de genes
            row[ko] = 1 if ko in found_kos else 0

        records.append(row)

# 4. Guardar matriz como DataFrame
ordered_kos = sorted(ko_ids)
columns = ["Sample", *ordered_kos]
df_out = pd.DataFrame(records, columns=columns)
if not df_out.empty:
    df_out = df_out.sort_values(by="Sample")
df_out.to_csv("gene_presence_matrix.tsv", sep="\t", index=False)
print("✅ Archivo de salida: gene_presence_matrix.tsv")
