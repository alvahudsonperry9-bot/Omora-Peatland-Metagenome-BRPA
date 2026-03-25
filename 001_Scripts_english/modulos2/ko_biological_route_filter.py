import argparse
import csv
from pathlib import Path
from typing import Optional

RUTAS_PROHIBIDAS_ARQUEAS = {
    "A02_ccoNOPQ", "A03_CoxABC",
    "A05_cyoABCDE", "A18__Assimilatory_nitrate_reduction",
    "A19_Denitrification", "A20_anamox",
    "A21_Calvin_cycle", "A23_3HP", "A25_methane_oxidation", "A26_Formaldehyde_assimilation"
}

RUTAS_PROHIBIDAS_BACTERIAS = {
    "A24_3HP_HB", "A11_HdrD", "A27_M_CO2", "A28_M_acetate",
    "A29_M_methanol", "A30_M_mono_di_trimethylamine",
    "A31_M_monomethylamine", "A32_M_trimethylamine"
}


def clean_text(value: Optional[object]) -> str:
    if value is None:
        return ""
    return str(value).replace("\xa0", " ").strip()


def route_code(route_name: str) -> str:
    route_name = clean_text(route_name)
    if "_" in route_name:
        return route_name.split("_", 1)[0]
    return route_name


def load_dictionary(dictionary_file: Path):
    ko_to_category = {}
    with dictionary_file.open("r", encoding="utf-8", errors="replace") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            ko_id = clean_text(
                row.get("KO_ID")
                or row.get("ko_id")
                or row.get("KO")
            )
            category = clean_text(
                row.get("Functional_category")
                or row.get("functional_category")
                or row.get("Metabolic_route")
                or row.get("metabolic_route")
                or row.get("Ruta_metabolica")
                or row.get("ruta_metabolica")
            )
            if ko_id:
                ko_to_category[ko_id] = category
    return ko_to_category


def detect_domain(classification: str):
    first = clean_text(classification).split(";", 1)[0]
    if first == "d__Archaea":
        return "Archaea"
    if first == "d__Bacteria":
        return "Bacteria"
    return None


def load_sample_domains(ar53_tsv: Path, bac120_tsv: Path):
    sample_to_domain = {}
    for file_path in (ar53_tsv, bac120_tsv):
        if not file_path.exists():
            continue
        with file_path.open("r", encoding="utf-8", errors="replace") as handle:
            reader = csv.DictReader(handle, delimiter="\t")
            for row in reader:
                sample = clean_text(row.get("user_genome", ""))
                classification = clean_text(row.get("classification", ""))
                domain = detect_domain(classification)
                if sample and domain:
                    sample_to_domain[sample] = domain
    return sample_to_domain


def filter_file(file_path: Path, ko_to_category: dict, prohibited_codes: set):
    with file_path.open("r", encoding="utf-8", errors="replace") as handle:
        rows = [line.rstrip("\n").split("\t") for line in handle if line.strip()]

    kept_rows = []
    removed = 0

    for row in rows:
        if len(row) < 13:
            kept_rows.append(row)
            continue

        ko_id = clean_text(row[12])
        category = ko_to_category.get(ko_id, "")
        category_code = route_code(category)

        if category_code in prohibited_codes:
            removed += 1
            continue

        kept_rows.append(row)

    with file_path.open("w", encoding="utf-8") as handle:
        for row in kept_rows:
            handle.write("\t".join(row) + "\n")

    return len(rows), len(kept_rows), removed


def main():
    parser = argparse.ArgumentParser(
        description="Filtra rutas prohibidas por dominio (Archaea/Bacteria) usando GTDB-Tk + dictionary"
    )
    parser.add_argument("--filtered_dir", required=True, help="Directorio con *_filtered_blastp.tsv")
    parser.add_argument("--dictionary", required=True, help="Archivo dictionary.txt (KO_ID, Functional_category)")
    parser.add_argument("--gtdb-ar53", required=True, help="Ruta a gtdbtk.ar53.summary.tsv")
    parser.add_argument("--gtdb-bac120", required=True, help="Ruta a gtdbtk.bac120.summary.tsv")
    parser.add_argument("--show-filters", action="store_true", help="Imprime rutas prohibidas y sale")

    args = parser.parse_args()

    prohibited_archaea_codes = {route_code(x) for x in RUTAS_PROHIBIDAS_ARQUEAS}
    prohibited_bacteria_codes = {route_code(x) for x in RUTAS_PROHIBIDAS_BACTERIAS}

    if args.show_filters:
        print("Rutas prohibidas Archaea:")
        for x in sorted(RUTAS_PROHIBIDAS_ARQUEAS):
            print(f" - {x}")
        print("Rutas prohibidas Bacteria:")
        for x in sorted(RUTAS_PROHIBIDAS_BACTERIAS):
            print(f" - {x}")
        return

    filtered_dir = Path(args.filtered_dir)
    dictionary_file = Path(args.dictionary)
    ar53_tsv = Path(args.gtdb_ar53)
    bac120_tsv = Path(args.gtdb_bac120)

    if not filtered_dir.exists():
        raise FileNotFoundError(f"No existe filtered_dir: {filtered_dir}")
    if not dictionary_file.exists():
        raise FileNotFoundError(f"No existe dictionary: {dictionary_file}")
    if not ar53_tsv.exists():
        raise FileNotFoundError(f"No existe ar53 TSV: {ar53_tsv}")
    if not bac120_tsv.exists():
        raise FileNotFoundError(f"No existe bac120 TSV: {bac120_tsv}")

    ko_to_category = load_dictionary(dictionary_file)
    sample_to_domain = load_sample_domains(ar53_tsv, bac120_tsv)

    files = sorted(filtered_dir.glob("*_filtered_blastp.tsv"))
    if not files:
        print(f"⚠️ No hay archivos *_filtered_blastp.tsv en {filtered_dir}")
        return

    total_removed = 0
    processed = 0
    skipped = 0

    for file_path in files:
        sample = file_path.name.replace("_filtered_blastp.tsv", "")
        domain = sample_to_domain.get(sample)

        if domain is None:
            print(f"⚠️ Sin dominio GTDB para {sample}, se deja sin cambios")
            skipped += 1
            continue

        prohibited_codes = prohibited_archaea_codes if domain == "Archaea" else prohibited_bacteria_codes
        before, after, removed = filter_file(file_path, ko_to_category, prohibited_codes)
        total_removed += removed
        processed += 1
        print(f"✅ {sample} ({domain}): {before} -> {after} (removidos={removed})")

    print(f"\nResumen filtro biológico: procesados={processed}, sin_dominio={skipped}, removidos_totales={total_removed}")


if __name__ == "__main__":
    main()
