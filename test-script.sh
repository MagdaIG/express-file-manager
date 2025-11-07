#!/bin/bash

BASE_URL="http://localhost:3000"
TEMP_DIR=$(mktemp -d)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

cleanup() {
    rm -rf "$TEMP_DIR"
    rm -f /tmp/test.exe
    rm -f /tmp/last_uploaded_file.txt
}

trap cleanup EXIT

echo "=========================================="
echo "Iniciando pruebas de la API de archivos"
echo "=========================================="
echo ""

if ! curl -s "$BASE_URL/files" > /dev/null 2>&1; then
    echo -e "${RED}Error: El servidor no está ejecutándose en $BASE_URL${NC}"
    echo "Por favor, inicia el servidor con: npm start"
    exit 1
fi

echo -e "${GREEN}✓ Servidor está ejecutándose${NC}"
echo ""

echo "Creando archivos de prueba temporales..."
echo "Este es un archivo de texto de prueba para verificar la funcionalidad de carga." > "$TEMP_DIR/ejemplo.txt"

cat > "$TEMP_DIR/ejemplo.pdf" << 'EOF'
%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj
2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj
3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 4 0 R
>>
endobj
4 0 obj
<<
/Length 44
>>
stream
BT
/F1 12 Tf
100 700 Td
(Ejemplo de PDF) Tj
ET
endstream
endobj
xref
0 5
trailer
<<
/Size 5
/Root 1 0 R
>>
startxref
200
%%EOF
EOF

echo -e "${GREEN}✓ Archivos de prueba creados${NC}"
echo ""

test_count=0
pass_count=0
fail_count=0

test_upload() {
    local file=$1
    local expected_status=$2
    test_count=$((test_count + 1))

    echo "Prueba $test_count: Subiendo archivo $file"
    response=$(curl -s -w "\n%{http_code}" -X POST -F "file=@$TEMP_DIR/$file" "$BASE_URL/upload")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq "$expected_status" ]; then
        echo -e "${GREEN}✓ Éxito (HTTP $http_code)${NC}"
        echo "$body" | head -c 200
        echo "..."
        pass_count=$((pass_count + 1))

        if [ "$expected_status" -eq 200 ]; then
            stored_name=$(echo "$body" | grep -o '"storedName":"[^"]*' | cut -d'"' -f4)
            echo "$stored_name" > /tmp/last_uploaded_file.txt
        fi
    else
        echo -e "${RED}✗ Falló (esperado HTTP $expected_status, recibido HTTP $http_code)${NC}"
        echo "$body"
        fail_count=$((fail_count + 1))
    fi
    echo ""
}

test_delete() {
    local filename=$1
    local expected_status=$2
    test_count=$((test_count + 1))

    echo "Prueba $test_count: Eliminando archivo $filename"
    response=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/delete/$filename")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq "$expected_status" ]; then
        echo -e "${GREEN}✓ Éxito (HTTP $http_code)${NC}"
        echo "$body"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ Falló (esperado HTTP $expected_status, recibido HTTP $http_code)${NC}"
        echo "$body"
        fail_count=$((fail_count + 1))
    fi
    echo ""
}

test_list() {
    test_count=$((test_count + 1))

    echo "Prueba $test_count: Listando archivos"
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/files")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq 200 ]; then
        echo -e "${GREEN}✓ Éxito (HTTP 200)${NC}"
        echo "$body" | head -c 300
        echo "..."
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ Falló (esperado HTTP 200, recibido HTTP $http_code)${NC}"
        echo "$body"
        fail_count=$((fail_count + 1))
    fi
    echo ""
}

test_invalid_extension() {
    test_count=$((test_count + 1))

    echo "Prueba $test_count: Intentando subir archivo con extensión no permitida"
    echo "test content" > /tmp/test.exe
    response=$(curl -s -w "\n%{http_code}" -X POST -F "file=@/tmp/test.exe" "$BASE_URL/upload")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    rm -f /tmp/test.exe

    if [ "$http_code" -eq 400 ]; then
        echo -e "${GREEN}✓ Éxito - Extensión rechazada correctamente (HTTP 400)${NC}"
        echo "$body" | head -c 200
        echo "..."
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ Falló (esperado HTTP 400, recibido HTTP $http_code)${NC}"
        echo "$body"
        fail_count=$((fail_count + 1))
    fi
    echo ""
}

test_delete_nonexistent() {
    test_count=$((test_count + 1))

    echo "Prueba $test_count: Intentando eliminar archivo inexistente"
    response=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/delete/archivo_inexistente_12345.txt")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq 404 ]; then
        echo -e "${GREEN}✓ Éxito - Archivo inexistente manejado correctamente (HTTP 404)${NC}"
        echo "$body"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ Falló (esperado HTTP 404, recibido HTTP $http_code)${NC}"
        echo "$body"
        fail_count=$((fail_count + 1))
    fi
    echo ""
}

echo "=== Pruebas de Carga de Archivos ==="
test_upload "ejemplo.txt" 200
test_upload "ejemplo.pdf" 200

echo "=== Prueba de Archivo Duplicado ==="
test_upload "ejemplo.txt" 200

echo "=== Prueba de Listado de Archivos ==="
test_list

echo "=== Prueba de Extensión No Permitida ==="
test_invalid_extension

echo "=== Pruebas de Eliminación ==="
if [ -f /tmp/last_uploaded_file.txt ]; then
    last_file=$(cat /tmp/last_uploaded_file.txt)
    test_delete "$last_file" 200
fi
test_delete_nonexistent

echo "=========================================="
echo "Resumen de Pruebas"
echo "=========================================="
echo -e "Total de pruebas: $test_count"
echo -e "${GREEN}Pruebas exitosas: $pass_count${NC}"
if [ $fail_count -gt 0 ]; then
    echo -e "${RED}Pruebas fallidas: $fail_count${NC}"
else
    echo -e "${GREEN}Pruebas fallidas: $fail_count${NC}"
fi
echo ""

if [ $fail_count -eq 0 ]; then
    echo -e "${GREEN}¡Todas las pruebas pasaron exitosamente!${NC}"
    exit 0
else
    echo -e "${RED}Algunas pruebas fallaron${NC}"
    exit 1
fi
