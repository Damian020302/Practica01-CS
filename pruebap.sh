#!/bin/bash

# Verificar que se proporcione un dominio o IP como argumento
# Para compilar se tiene que pasar "./pruebap.sh -domonio-"
if [ -z "$1" ]; then
    echo "Uso: $0 <dominio o IP>"
    exit 1
fi

dominio="$1"
salida="reporte_${dominio}.txt"

# Crear directorio para capturas de pantalla
capturas_dir="capturas_${dominio}"
mkdir -p "$capturas_dir"

# Verificar que scrot esté instalado
if ! command -v scrot &> /dev/null; then
    echo "Instalando scrot para capturas de pantalla automáticas..."
    sudo apt-get update && sudo apt-get install -y scrot
fi

# Lanzar EtherApe en segundo plano antes de iniciar los escaneos
echo "Iniciando EtherApe para monitoreo visual de tráfico..."
sudo etherape &
etherape_pid=$!
# Dar tiempo para que EtherApe arranque completamente
sleep 3

# Encabezado del reporte
echo "Análisis de: $dominio" | tee "$salida"
echo "----------------------------------------" | tee -a "$salida"

# WHOIS - Obtener información del dominio (fechas, propietario, ubicación)
echo "[WHOIS Information]" | tee -a "$salida"
whois "$dominio" | grep -E "Domain Name|Registrar|Creation Date|Updated Date|Expiry Date|Registrant|Admin|Tech|Country|State|City|Street|Postal" | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Ping - Medir latencia y disponibilidad
echo "[Prueba de conectividad (Ping)]" | tee -a "$salida"
ping -c 10 "$dominio" | tee -a "$salida"

# Extraer y mostrar el porcentaje de pérdida de paquetes
loss=$(ping -c 10 "$dominio" | grep -oP '\d+(?=% packet loss)')
echo "Pérdida de paquetes: $loss%" | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Nslookup - Obtener direcciones IPv4 e IPv6
echo "[Registros DNS (Nslookup)]" | tee -a "$salida"
nslookup "$dominio" | grep -E "Name|Address" | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Traceroute - Identificar la ruta y los saltos hacia el dominio
echo "[TRACEROUTE (primeros 10 saltos)]" | tee -a "$salida"
traceroute "$dominio" | head -n 12 | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Enumeración de subdominios con Findomain y Subfinder
echo "[Subdominios detectados]" | tee -a "$salida"

# Tomar captura de EtherApe antes de enumeración de subdominios
echo "Tomando captura de pantalla antes de enumeración de subdominios..."
scrot -u "$capturas_dir/etherape_antes_subdominios.png"
echo "Captura guardada en $capturas_dir/etherape_antes_subdominios.png" | tee -a "$salida"

# Ejecutar findomain y filtrar resultados relevantes
findomain -t "$dominio" | grep -vE "Error|Usage|Scanning" | tee -a "$salida"

# Tomar captura durante el proceso
scrot -u "$capturas_dir/etherape_durante_findomain.png"
echo "Captura guardada en $capturas_dir/etherape_durante_findomain.png" | tee -a "$salida"

# Ejecutar subfinder y evitar mensajes de uso
subfinder -d "$dominio" | grep -vE "Usage|Enumerating" | tee -a "$salida"

# Tomar captura después de subfinder
scrot -u "$capturas_dir/etherape_despues_subdominios.png"
echo "Captura guardada en $capturas_dir/etherape_despues_subdominios.png" | tee -a "$salida"

echo "----------------------------------------" | tee -a "$salida"

# Escaneo DNS con dnsrecon - Filtrar registros relevantes
echo "[Escaneo DNS con dnsrecon]" | tee -a "$salida"
dnsrecon -d "$dominio" | grep -E "A |AAAA |NS |SOA |MX |TXT |SRV |CNAME " | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Registros PTR (búsqueda inversa de IPs)
echo "[Resolución inversa (PTR)]" | tee -a "$salida"
for ip in $(host "$dominio" | awk '/has address/ {print $4}'); do
    ptr_record=$(host "$ip" 8.8.8.8 | grep -v "not found")  # Filtrar NXDOMAIN
    if [ -n "$ptr_record" ]; then
        echo "$ptr_record" | tee -a "$salida"
    else
        echo "No se encontró un registro PTR para $ip" | tee -a "$salida"
    fi
done
echo "----------------------------------------" | tee -a "$salida"

# Escaneo de puertos y servicios con Nmap
echo "[Escaneo de Puertos con Nmap]" | tee -a "$salida"

# Tomar captura antes de Nmap
echo "Tomando captura de EtherApe antes de Nmap..." | tee -a "$salida"
scrot -u "$capturas_dir/etherape_antes_nmap.png"

# Ejecutar Nmap con puertos limitados para evitar tiempos excesivos
echo "Ejecutando escaneo Nmap (versión limitada para evitar bloqueos)..." | tee -a "$salida"
nmap -Pn -sV --reason -p 1-1000 "$dominio" | \
grep -E "open|closed|filtered|PORT|SERVICE|STATE|OS details|Traceroute" | tee -a "$salida"

# Tomar captura después de Nmap
scrot -u "$capturas_dir/etherape_despues_nmap.png"

echo "----------------------------------------" | tee -a "$salida"

# Información sobre la monitorización con EtherApe
echo "[Monitoreo con EtherApe]" | tee -a "$salida"
echo "EtherApe ha estado ejecutándose con PID: $etherape_pid" | tee -a "$salida"
echo "Las capturas de pantalla se guardaron en: $capturas_dir" | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Finalizar EtherApe automáticamente
echo "Cerrando EtherApe..."
kill $etherape_pid

# Mensaje final
echo "Análisis finalizado. Resultados guardados en $salida"
