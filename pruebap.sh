#!/bin/bash

# Verificar que se proporcione un dominio o IP como argumento
# Para compilar se tiene que pasar "./prueba.sh domonio"
if [ -z "$1" ]; then
    echo "Uso: $0 <dominio o IP>"
    exit 1
fi

dominio="$1"
salida="reporte_${dominio}.txt"

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

# Ejecutar findomain y filtrar resultados relevantes
findomain -t "$dominio" | grep -vE "Error|Usage|Scanning" | tee -a "$salida"

# Ejecutar subfinder y evitar mensajes de uso
subfinder -d "$dominio" | grep -vE "Usage|Enumerating" | tee -a "$salida"

echo "----------------------------------------" | tee -a "$salida"

# Escaneo DNS con dnsrecon - Filtrar registros relevantes
echo "[Escaneo DNS con dnsrecon]" | tee -a "$salida"
dnsrecon -d "$dominio" | grep -E "A |AAAA |NS |SOA |MX |TXT |SRV |CNAME " | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Registros PTR (búsqueda inversa de IPs)
echo "[Resolución inversa (PTR)]" | tee -a "$salida"
for ip in $(host "$dominio" | awk '/has address/ {print $4}'); do
    host "$ip" | tee -a "$salida"
done
echo "----------------------------------------" | tee -a "$salida"

# Escaneo de puertos y servicios con Nmap
echo "[Escaneo de Puertos con Nmap]" | tee -a "$salida"

# Ejecutar Nmap con escaneo profundo (-Pn ignora ping, -sV detecta servicios, -O detecta SO)
nmap -Pn -sV -O --traceroute "$dominio" | grep -E "open|PORT|SERVICE|STATE|OS details|Traceroute" | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Instrucción para monitoreo con EtherApe (requiere ejecución manual)
echo "[Monitoreo con EtherApe]" | tee -a "$salida"
echo "Ejecutar manualmente: sudo etherape &" | tee -a "$salida"
echo "----------------------------------------" | tee -a "$salida"

# Mensaje final
echo "Análisis finalizado. Resultados guardados en $salida"


