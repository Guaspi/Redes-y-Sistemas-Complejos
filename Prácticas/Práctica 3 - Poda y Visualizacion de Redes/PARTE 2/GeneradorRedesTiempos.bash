
#!/bin/bash

# Configuración de parámetros para la generación de redes y ejecución de Pathfinder
size=10000
symmetry=1               # Red no dirigida
diagonal_value=0
weight_type=1            # Pesos reales
min_weight=1.5
max_weight=10.5
edge_prob=0.1            # Probabilidad de enlace
iterations=5           # Número de redes a generar 
pathfinder_variants=(
"/mnt/c/PARTE_2/codigos_Pathfinder_2024/OriginalPathfinder/pathfinder"
"/mnt/c/PARTE_2/codigos_Pathfinder_2024/BinaryPathfinder/binary-pathfinder"
"/mnt/c/PARTE_2/codigos_Pathfinder_2024/Fast-Pathfinder/fast-pathfinder"
"/mnt/c/PARTE_2/codigos_Pathfinder_2024/MST-Pathfinder-Practico/mst-pathfinder"
"/mnt/c/PARTE_2/codigos_Pathfinder_2024/MST-Pathfinder-BComplejidad/mst-pathfinder"

)
create_mod_path="/mnt/c/PARTE_2/RandomNets2024/genera_red_ponderada_aleatoria"

# Tiempo máximo permitido en segundos
max_time=1800  # 30 minutos

# Carpeta de resultados
results_dir="custom_results"         
originals_dir="$results_dir/network_originals"
pruned_dir="$results_dir/network_pruned"
csv_dir="$results_dir/network_csv"

# Crear carpetas
mkdir -p "$originals_dir" "$pruned_dir" "$csv_dir"

# Archivo de salida CSV
output_file="$csv_dir/pathfinder_times_n${size}.csv"
echo "Variante,Red,Tiempo Ejecucion(s)" > "$output_file"  # Usamos segundos en lugar de milisegundos

# Crear un diccionario para registrar si una variante excedió el tiempo
declare -A exceeded_time
for variant in "${pathfinder_variants[@]}"; do
  variant_name=$(echo "$variant" | awk -F'/' '{print $(NF-1)}')
  exceeded_time["$variant_name"]=0
done

# Generar redes y ejecutar cada variante de Pathfinder
for ((i = 1; i <= iterations; i++)); do
  echo "Generando red aleatoria $i de tamaño $size"
  original_network_file="$originals_dir/network_original_n=${size}_${i}.net"
  "$create_mod_path" "$size" "$symmetry" "$diagonal_value" "$weight_type" "$min_weight" "$max_weight" "$edge_prob" > "$original_network_file"

  # Ejecutar cada variante de Pathfinder y medir tiempo
  for variant in "${pathfinder_variants[@]}"; do
    # Extraer solo el nombre de la carpeta intermedia (sin la ruta completa)
    variant_name=$(echo "$variant" | awk -F'/' '{print $(NF-1)}')

    # Verificar si la variante ya excedió el tiempo previamente
    if [[ ${exceeded_time["$variant_name"]} -eq 1 ]]; then
      echo "Variante $variant_name ya excedió el tiempo en una red anterior. Registrando $max_time segundos para red $i."
      echo "$variant_name,$i,$max_time" >> "$output_file"
      continue
    fi

    echo "Ejecutando $variant_name en red $i con límite de tiempo de $max_time segundos"
    start_time=$(date +%s.%N)

    # Archivo para la red podada
    pruned_network_file="$pruned_dir/network_pruned_${variant_name}_n=${size}_${i}.net"

    # Ejecutar el comando con límite de tiempo usando `timeout` y guardar la red podada
    timeout "$max_time"s "$variant" "$original_network_file" > "$pruned_network_file"
    exit_status=$?

    # Calcular el tiempo real consumido
    end_time=$(date +%s.%N)
    elapsed_time=$(echo "$end_time - $start_time" | bc -l)

    if [[ $exit_status -eq 124 ]]; then
      # Código 124 indica que `timeout` finalizó el proceso
      echo "Variante $variant_name excedió el tiempo límite de $max_time segundos en red $i."
      elapsed_time=$max_time  # Registrar el tiempo máximo
      exceeded_time["$variant_name"]=1  # Activar la bandera para esta variante
    elif [[ $exit_status -ne 0 ]]; then
      echo "Variante $variant_name falló en red $i. Código de salida: $exit_status"
      exceeded_time["$variant_name"]=1  # Marcar como fallida
      continue
    fi

    # Guardar el tiempo de ejecución en el archivo CSV
    echo "$variant_name,$i,$elapsed_time" >> "$output_file"
  done
done

# Calcular y mostrar el promedio de cada variante
echo -e "\nPromedios de tiempos de ejecución para cada variante:"
for variant in "${pathfinder_variants[@]}"; do
  # Extraer solo el nombre de la carpeta intermedia
  variant_name=$(echo "$variant" | awk -F'/' '{print $(NF-1)}')

  # Extraer los tiempos registrados
  times=($(awk -F, -v var="$variant_name" '$1 == var {print $3}' "$output_file"))
  sum=0
  for time in "${times[@]}"; do
    sum=$(echo "$sum + $time" | bc -l)
  done
  avg_time=$(echo "scale=3; $sum / ${#times[@]}" | bc)

  # Escribir el promedio al final del CSV
  echo "$variant_name,$avg_time" >> "$output_file"
  echo "$variant_name: $avg_time segundos"
done

# Ordenar el archivo CSV por nombre de variante
sort -t, -k1,1 "$output_file" -o "$output_file"

echo "Resultados almacenados en $output_file ordenados por variante."
echo "Redes originales guardadas en: $originals_dir"
echo "Redes podadas guardadas en: $pruned_dir"
echo "Archivo CSV guardado en: $csv_dir"
