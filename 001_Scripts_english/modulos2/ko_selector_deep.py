import pandas as pd
from pathlib import Path
import argparse

def process_blastp(
    metadata_file: str,
    ko_list_file: str,
    sample_id: str = None,
    min_identity: float = None,
    max_evalue: float = None,
    min_bit_score: float = None,
    criterion: int = 1,
    output_dir: str = "."
):
    """
    Procesa archivos BLASTp según los parámetros especificados,
    usando un ko_list.tsv con columnas [Gene_Name, Reference_ID].

    Args:
        metadata_file: Ruta al archivo TSV con metadata (Blastp_directory, Sample_ID)
        ko_list_file: Archivo con dos columnas: Gene_Name y Reference_ID
        sample_id: ID de la muestra a procesar (opcional)
        min_identity: % mínimo de identidad (opcional)
        max_evalue: Valor máximo de E-value (opcional)
        min_bit_score: Valor mínimo de Bit Score (opcional)
        criterion: 1=Mayor Alignment Length, 2=Mayor Query Length
        output_dir: Directorio de salida para los resultados
    """
    # Leer ko_list.tsv (dos columnas)
    df_ko = pd.read_csv(ko_list_file, sep='\t', header=None, names=['Gene_Name', 'Reference_ID'])
    
    # Cargar metadata
    df_meta = pd.read_csv(metadata_file, sep='\t')
    
    # Determinar muestras a procesar
    samples = [sample_id] if sample_id else df_meta['Sample_ID'].unique()
    
    for sample in samples:
        sample_data = df_meta[df_meta['Sample_ID'] == sample]
        if sample_data.empty:
            print(f"⚠️ Muestra '{sample}' no encontrada en metadata")
            continue
        
        blastp_path = sample_data.iloc[0]['Blastp_directory']
        
        if not Path(blastp_path).exists():
            print(f"❌ Archivo BLASTp no encontrado: {blastp_path}")
            continue
        
        try:
            # Leer archivo BLASTp (12 columnas estándar)
            # Manejar archivos comprimidos
            if blastp_path.endswith('.gz'):
                df_blast = pd.read_csv(blastp_path, sep='\t', header=None, compression='gzip')
            else:
                df_blast = pd.read_csv(blastp_path, sep='\t', header=None)
            
            df_blast.columns = [
                'qseqid','sseqid','pident','length','mismatch','gapopen',
                'qstart','qend','sstart','send','evalue','bitscore'
            ]
            
            # Hacer merge con la tabla de KO (en base al subject ID)
            df_merged = df_blast.merge(df_ko, left_on='sseqid', right_on='Reference_ID', how='inner')
            
            # Aplicar filtros básicos
            if min_identity is not None:
                df_merged = df_merged[df_merged['pident'] >= min_identity]
            if max_evalue is not None:
                df_merged = df_merged[df_merged['evalue'] <= max_evalue]
            if min_bit_score is not None:
                df_merged = df_merged[df_merged['bitscore'] >= min_bit_score]
            
            if df_merged.empty:
                print(f"⚠️ No hay hits para '{sample}' tras los filtros")
                continue
            
            # Calcular Query Length
            df_merged['Query_Length'] = df_merged['qend'] - df_merged['qstart'] + 1
            
            # Ordenar según el criterio
            if criterion == 1:
                df_merged = df_merged.sort_values(by=['length'], ascending=False)
            else:
                df_merged = df_merged.sort_values(by=['Query_Length'], ascending=False)
            
            # Eliminar duplicados: mismo Query_ID + Gene_Name
            df_final = df_merged.drop_duplicates(subset=['qseqid', 'Gene_Name'])
            
            # Crear directorio de salida si no existe
            Path(output_dir).mkdir(parents=True, exist_ok=True)
            
            # Guardar resultados (12 columnas originales + Gene_Name)
            output_path = Path(output_dir) / f"{sample}_filtered_blastp.tsv"
            df_final.to_csv(
                output_path, sep='\t', index=False, header=False,
                columns=[
                    'qseqid','sseqid','pident','length','mismatch','gapopen',
                    'qstart','qend','sstart','send','evalue','bitscore','Gene_Name'
                ]
            )
            
            print(f"✅ {sample}: {len(df_final)} hits guardados en {output_path}")
        
        except Exception as e:
            print(f"❌ Error procesando {sample}: {str(e)}")
            continue

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Filtra resultados BLASTp según ko_list.tsv y elimina duplicados")
    parser.add_argument("--metadata", required=True, help="Archivo TSV con rutas BLASTp y Sample_IDs")
    parser.add_argument("--ko_list", required=True, help="Archivo TSV con columnas: Gene_Name, Reference_ID")
    parser.add_argument("--sample_id", help="Procesar solo esta muestra (opcional)")
    parser.add_argument("--min_identity", type=float, help="% Mínimo de identidad (opcional)")
    parser.add_argument("--max_evalue", type=float, help="Valor máximo de E-value (opcional)")
    parser.add_argument("--min_bit_score", type=float, help="Valor mínimo de Bit Score (opcional)")
    parser.add_argument("--criterion", type=int, choices=[1,2], default=1,
                       help="Criterio para eliminar duplicados: 1=Alignment Length, 2=Query Length")
    parser.add_argument("--output_dir", default=".", help="Directorio para guardar resultados")
    
    args = parser.parse_args()
    
    process_blastp(
        metadata_file=args.metadata,
        ko_list_file=args.ko_list,
        sample_id=args.sample_id,
        min_identity=args.min_identity,
        max_evalue=args.max_evalue,
        min_bit_score=args.min_bit_score,
        criterion=args.criterion,
        output_dir=args.output_dir
    )