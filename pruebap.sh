#!/bin/bash

echo "Dame una URL: "
read url1

timeout 10 ping "$url1"
nslookup "$url1"
whois "$url1"
traceroute "$url1"
findomain "$url1"
echo "Este es el resultado"

