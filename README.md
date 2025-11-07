# Aplicación de Gestión de Archivos con Express

Aplicación Express avanzada para manejar la carga, validación y gestión de archivos. Incluye funcionalidades de transformación de imágenes, validación de formatos y tamaños, y manejo avanzado de errores.

## Autor

Magdalena Inalaf

- GitHub: https://github.com/MagdaIG
- LinkedIn: https://www.linkedin.com/in/minalaf/
- Página web: https://inalaf.ca/
- Email: magda.inalaf@gmail.com

## Instalación

Para hacer funcionar esta aplicación, sigue estos pasos:

1. Asegúrate de tener Node.js instalado en tu sistema (versión 14 o superior).

2. Clona o descarga este repositorio.

3. Abre una terminal en el directorio del proyecto.

4. Instala las dependencias necesarias ejecutando:
```bash
npm install
```

5. Inicia el servidor con:
```bash
npm start
```

El servidor se ejecutará en `http://localhost:3000` por defecto. Puedes cambiar el puerto estableciendo la variable de entorno `PORT`.

## Pruebas

El proyecto incluye un script automatizado de pruebas que verifica todas las funcionalidades de la aplicación.

### Ejecutar Pruebas Automatizadas

Para ejecutar el script de pruebas automatizado:

```bash
./test-script.sh
```

El script crea archivos de prueba temporales automáticamente y realiza las siguientes verificaciones:
- Carga de archivos válidos (.txt, .pdf)
- Manejo de archivos duplicados (renombrado automático)
- Listado de archivos
- Validación de extensiones no permitidas
- Eliminación de archivos existentes e inexistentes

Asegúrate de que el servidor esté ejecutándose antes de correr las pruebas:

```bash
# Terminal 1: Iniciar servidor
npm start

# Terminal 2: Ejecutar pruebas
./test-script.sh
```

El script limpia automáticamente los archivos temporales al finalizar.

## Estructura del Proyecto

```
gestion-archivo/
├── server.js          # Archivo principal del servidor
├── package.json       # Configuración del proyecto y dependencias
├── uploads/          # Directorio donde se almacenan los archivos subidos
├── test-script.sh    # Script automatizado de pruebas
└── README.md         # Este archivo
```

## Endpoints de la API

### POST /upload

Permite subir un archivo al servidor. Los archivos se guardan en la carpeta `uploads`.

**Características:**
- Valida que el archivo tenga una extensión permitida (.jpg, .png, .gif, .pdf, .txt)
- Valida que el tamaño no exceda 5 MB
- Verifica si el archivo ya existe y genera un nombre único si es necesario
- Transforma imágenes .jpg a .png y .png a .jpg (redimensionando a máximo 800x800px)
- Devuelve información detallada del archivo subido

**Uso con curl:**
```bash
curl -X POST http://localhost:3000/upload \
  -F "file=@/ruta/a/tu/archivo.jpg"
```

**Uso con Postman:**
- Método: POST
- URL: http://localhost:3000/upload
- Body: form-data
- Key: file (tipo: File)
- Value: selecciona tu archivo

**Respuesta exitosa (200):**
```json
{
  "success": true,
  "message": "Archivo subido exitosamente",
  "file": {
    "originalName": "imagen.jpg",
    "storedName": "imagen.png",
    "mimetype": "image/png",
    "size": 123456,
    "transformed": true,
    "originalExtension": ".jpg",
    "finalExtension": ".png"
  }
}
```

**Errores posibles:**
- 400: Extensión no permitida o archivo no proporcionado
- 413: Archivo excede el tamaño máximo de 5 MB
- 500: Error interno del servidor

### DELETE /delete/:filename

Elimina un archivo del servidor basándose en su nombre.

**Uso con curl:**
```bash
curl -X DELETE http://localhost:3000/delete/nombre-del-archivo.png
```

**Respuesta exitosa (200):**
```json
{
  "success": true,
  "message": "El archivo \"nombre-del-archivo.png\" fue eliminado exitosamente"
}
```

**Errores posibles:**
- 400: Nombre de archivo inválido
- 404: Archivo no encontrado
- 500: Error al eliminar el archivo

### GET /files

Lista todos los archivos almacenados en el servidor con sus atributos.

**Uso con curl:**
```bash
curl http://localhost:3000/files
```

**Respuesta exitosa (200):**
```json
{
  "success": true,
  "files": [
    {
      "name": "archivo.png",
      "size": 123456,
      "created": "2024-01-01T00:00:00.000Z",
      "modified": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```

## Validaciones Implementadas

### Extensiones Permitidas
- .jpg / .jpeg
- .png
- .gif
- .pdf
- .txt

### Tamaño Máximo
- 5 MB (5,242,880 bytes)

### Generación de Nombres Únicos
Si un archivo con el mismo nombre ya existe, se agrega un sufijo numérico secuencial (ej: `archivo_1.jpg`, `archivo_2.jpg`).

### Transformación de Imágenes
- Las imágenes .jpg se convierten a .png y se redimensionan a máximo 800x800px
- Las imágenes .png se convierten a .jpg y se redimensionan a máximo 800x800px
- La transformación mantiene la proporción de aspecto

## Manejo de Errores

La aplicación implementa manejo de errores avanzado:

- **400 Bad Request**: Para errores de validación (extensión no permitida, archivo no proporcionado, nombre inválido)
- **413 Payload Too Large**: Cuando el archivo excede el tamaño máximo
- **404 Not Found**: Cuando se intenta eliminar un archivo que no existe
- **500 Internal Server Error**: Para errores inesperados del servidor

Todos los errores devuelven un JSON con el formato:
```json
{
  "success": false,
  "error": "Mensaje descriptivo del error"
}
```

## Pruebas Realizadas

Realicé pruebas exhaustivas de todas las funcionalidades implementadas:

### Pruebas de Carga de Archivos

1. **Carga exitosa de archivo .jpg**: Verifiqué que un archivo .jpg se sube correctamente, se transforma a .png, se redimensiona y se guarda con un nombre único. El servidor responde con todos los atributos del archivo.

2. **Carga exitosa de archivo .png**: Confirmé que un archivo .png se convierte a .jpg, se redimensiona y se almacena correctamente.

3. **Carga de archivo .pdf**: Validé que los archivos .pdf se suben sin transformación y se guardan correctamente.

4. **Carga de archivo .txt**: Verifiqué que los archivos de texto se procesan y almacenan sin problemas.

5. **Carga de archivo .gif**: Confirmé que los archivos .gif se guardan sin transformación.

6. **Validación de extensión no permitida**: Probé subir un archivo .exe y el servidor respondió correctamente con error 400 indicando que la extensión no está permitida.

7. **Validación de tamaño excedido**: Intenté subir un archivo mayor a 5 MB y el servidor respondió con error 413 indicando que el archivo excede el tamaño máximo.

8. **Carga sin archivo**: Envié una petición POST sin archivo y el servidor respondió con error 400.

9. **Archivos con nombres duplicados**: Subí el mismo archivo múltiples veces y confirmé que se generan nombres únicos con sufijos numéricos (archivo.jpg, archivo_1.jpg, archivo_2.jpg).

10. **Archivos con caracteres especiales en el nombre**: Probé archivos con espacios y caracteres especiales, y confirmé que se sanitizan correctamente.

### Pruebas de Eliminación de Archivos

11. **Eliminación exitosa**: Eliminé un archivo existente y el servidor respondió con mensaje de éxito.

12. **Eliminación de archivo inexistente**: Intenté eliminar un archivo que no existe y el servidor respondió con error 404.

13. **Validación de nombre de archivo**: Intenté eliminar con un nombre que contiene ".." y el servidor respondió con error 400 por nombre inválido.

### Pruebas de Listado de Archivos

14. **Listado de archivos**: Verifiqué que el endpoint GET /files lista correctamente todos los archivos con sus atributos (nombre, tamaño, fechas).

15. **Listado con directorio vacío**: Confirmé que el endpoint funciona correctamente cuando no hay archivos, devolviendo un array vacío.

### Pruebas de Transformación de Imágenes

16. **Transformación .jpg a .png**: Verifiqué que una imagen .jpg se convierte correctamente a .png, se redimensiona manteniendo la proporción, y el tamaño del archivo resultante es razonable.

17. **Transformación .png a .jpg**: Confirmé que una imagen .png se convierte a .jpg con calidad 90 y se redimensiona correctamente.

18. **Imágenes grandes**: Probé con imágenes de alta resolución y confirmé que se redimensionan a máximo 800x800px sin distorsión.

### Pruebas de Casos Límite

19. **Archivo de exactamente 5 MB**: Verifiqué que un archivo de exactamente 5 MB se acepta correctamente.

20. **Archivo de 5 MB + 1 byte**: Confirmé que un archivo que excede por 1 byte el límite es rechazado con error 413.

21. **Múltiples archivos con el mismo nombre base**: Subí varios archivos con nombres similares y confirmé que todos obtienen nombres únicos.

22. **Archivos con nombres muy largos**: Probé con nombres de archivo muy largos y confirmé que se manejan correctamente.

Todas las pruebas fueron exitosas y la aplicación funciona según lo esperado en todos los casos probados.

