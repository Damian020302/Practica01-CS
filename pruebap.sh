#!/bin/bash

# Para compilar se tiene que pasar "./pruebap.sh -domonio-"

# Verificar que se proporcione un dominio o IP como argumento
if [ -z "$1" ]; then
    echo "Uso: $0 <dominio o IP>"
    exit 1
fi

dominio="$1"

# Verificar si el dominio existe usando host
if ! host "$dominio" &>/dev/null; then
    echo "Error: El dominio '$dominio' no existe o no tiene registros DNS válidos."
    exit 1
fi

salida="reporte_${dominio}.txt"

# Solicitar privilegios sudo al inicio
echo "Se requieren privilegios de administrador para ejecutar EtherApe"
sudo -v

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
whois "$dominio" | grep -vE "^%" | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Ping - Medir latencia y disponibilidad
echo "[Prueba de conectividad (Ping)]" | tee -a "$salida"
ping -c 10 "$dominio" | tee -a "$salida"

# Extraer y mostrar el porcentaje de pérdida de paquetes
loss=$(ping -c 10 "$dominio" | grep -oP '\d+(?=% packet loss)')
echo "Pérdida de paquetes: $loss%" | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Nslookup - Obtener direcciones IPv4 e IPv6
echo "[Registros DNS (IPv4 e IPv6 - Nslookup)]" | tee -a "$salida"
nslookup -query=A "$dominio" | grep -E "Name|Address" | tee -a "$salida" #IPv4
nslookup -query=AAAA "$dominio" | grep -E "Name|Address" | tee -a "$salida" #IPv6
echo "----------------------------------------" | tee -a "$salida"

# Traceroute - Identificar la ruta y los saltos hacia el dominio
echo "[TRACEROUTE (primeros 10 saltos)]" | tee -a "$salida"
traceroute "$dominio" | head -n 12 | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Enumeración de subdominios con Findomain y Subfinder
echo "[Subdominios detectados]" | tee -a "$salida"

# Crear un archivo temporal para almacenar subdominios
subdomains_tmp=$(mktemp)

# Ejecutar findomain y guardar resultados únicos
findomain -t "$dominio" | grep -vE "Error|Usage|Scanning" | tee "$subdomains_tmp"

# Ejecutar subfinder y filtrar resultados que no estén en findomain
subfinder -d "$dominio" | grep -vE "Usage|Enumerating" | grep -Fxv -f "$subdomains_tmp" | tee -a "$salida"

# Agregar los resultados de findomain al reporte final
cat "$subdomains_tmp" >> "$salida"

# Eliminar archivo temporal
rm "$subdomains_tmp"

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

# Ejecutar Nmap con puertos limitados para evitar tiempos excesivos
echo "Ejecutando escaneo Nmap (versión limitada para evitar bloqueos)..." | tee -a "$salida"
nmap -Pn -sV --reason -p 1-1000 "$dominio" | \
grep -E "open|closed|filtered|PORT|SERVICE|STATE|OS details|Traceroute" | tee -a "$salida"

echo "----------------------------------------" | tee -a "$salida"

# Información sobre la monitorización con EtherApe
echo "[Monitoreo con EtherApe]" | tee -a "$salida"
echo "EtherApe ha estado ejecutándose con PID: $etherape_pid" | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Finalizar EtherApe automáticamente
echo "Cerrando EtherApe..."
kill -2 $etherape_pid

# Mensaje final
echo "Análisis finalizado. Resultados guardados en $salida"
