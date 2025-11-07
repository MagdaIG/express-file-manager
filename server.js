const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const fs = require('fs').promises;
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const UPLOAD_DIR = path.join(__dirname, 'uploads');
const MAX_FILE_SIZE = 5 * 1024 * 1024;
const ALLOWED_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.gif', '.pdf', '.txt'];
const ALLOWED_IMAGE_EXTENSIONS = ['.jpg', '.jpeg', '.png'];

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase();
  if (ALLOWED_EXTENSIONS.includes(ext)) {
    cb(null, true);
  } else {
    cb(new Error(`Extensión de archivo no permitida. Extensiones permitidas: ${ALLOWED_EXTENSIONS.join(', ')}`), false);
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: MAX_FILE_SIZE
  }
});

async function ensureUploadDir() {
  try {
    await fs.access(UPLOAD_DIR);
  } catch {
    await fs.mkdir(UPLOAD_DIR, { recursive: true });
  }
}

async function generateUniqueFilename(originalName) {
  const ext = path.extname(originalName);
  const baseName = path.basename(originalName, ext);
  const sanitizedBaseName = baseName.replace(/[^a-zA-Z0-9-_]/g, '_');

  let filename = `${sanitizedBaseName}${ext}`;
  let counter = 1;

  while (true) {
    const filePath = path.join(UPLOAD_DIR, filename);
    try {
      await fs.access(filePath);
      filename = `${sanitizedBaseName}_${counter}${ext}`;
      counter++;
    } catch {
      break;
    }
  }

  return filename;
}

async function transformImage(buffer, originalExt) {
  try {
    const ext = originalExt.toLowerCase();

    if (ext === '.jpg' || ext === '.jpeg') {
      const transformedBuffer = await sharp(buffer)
        .resize(800, 800, {
          fit: 'inside',
          withoutEnlargement: true
        })
        .png()
        .toBuffer();

      return {
        buffer: transformedBuffer,
        newExt: '.png',
        transformed: true
      };
    } else if (ext === '.png') {
      const transformedBuffer = await sharp(buffer)
        .resize(800, 800, {
          fit: 'inside',
          withoutEnlargement: true
        })
        .jpeg({ quality: 90 })
        .toBuffer();

      return {
        buffer: transformedBuffer,
        newExt: '.jpg',
        transformed: true
      };
    }

    return {
      buffer: buffer,
      newExt: originalExt,
      transformed: false
    };
  } catch (error) {
    throw new Error(`Error al transformar la imagen: ${error.message}`);
  }
}

app.post('/upload', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'No se proporcionó ningún archivo'
      });
    }

    await ensureUploadDir();

    const originalExt = path.extname(req.file.originalname).toLowerCase();
    let finalBuffer = req.file.buffer;
    let finalExt = originalExt;
    let transformed = false;

    if (ALLOWED_IMAGE_EXTENSIONS.includes(originalExt)) {
      const transformation = await transformImage(req.file.buffer, originalExt);
      finalBuffer = transformation.buffer;
      finalExt = transformation.newExt;
      transformed = transformation.transformed;
    }

    const originalNameWithoutExt = path.basename(req.file.originalname, originalExt);
    const sanitizedBaseName = originalNameWithoutExt.replace(/[^a-zA-Z0-9-_]/g, '_');
    const tempFilename = `${sanitizedBaseName}${finalExt}`;

    const finalFilename = await generateUniqueFilename(tempFilename);
    const filePath = path.join(UPLOAD_DIR, finalFilename);

    await fs.writeFile(filePath, finalBuffer);

    const fileStats = await fs.stat(filePath);

    res.status(200).json({
      success: true,
      message: 'Archivo subido exitosamente',
      file: {
        originalName: req.file.originalname,
        storedName: finalFilename,
        mimetype: transformed ? (finalExt === '.png' ? 'image/png' : 'image/jpeg') : req.file.mimetype,
        size: fileStats.size,
        transformed: transformed,
        originalExtension: originalExt,
        finalExtension: finalExt
      }
    });
  } catch (error) {
    if (error instanceof multer.MulterError) {
      if (error.code === 'LIMIT_FILE_SIZE') {
        return res.status(413).json({
          success: false,
          error: 'El archivo excede el tamaño máximo permitido de 5 MB'
        });
      }
      return res.status(400).json({
        success: false,
        error: `Error al procesar el archivo: ${error.message}`
      });
    }

    if (error.message.includes('Extensión de archivo no permitida')) {
      return res.status(400).json({
        success: false,
        error: error.message
      });
    }

    res.status(500).json({
      success: false,
      error: `Error interno del servidor: ${error.message}`
    });
  }
});

app.delete('/delete/:filename', async (req, res) => {
  try {
    const filename = req.params.filename;

    if (!filename || filename.includes('..') || filename.includes('/') || filename.includes('\\')) {
      return res.status(400).json({
        success: false,
        error: 'Nombre de archivo inválido'
      });
    }

    const filePath = path.join(UPLOAD_DIR, filename);

    try {
      await fs.access(filePath);
    } catch {
      return res.status(404).json({
        success: false,
        error: `El archivo "${filename}" no existe en el servidor`
      });
    }

    await fs.unlink(filePath);

    res.status(200).json({
      success: true,
      message: `El archivo "${filename}" fue eliminado exitosamente`
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: `Error al eliminar el archivo: ${error.message}`
    });
  }
});

app.get('/files', async (req, res) => {
  try {
    await ensureUploadDir();
    const files = await fs.readdir(UPLOAD_DIR);
    const fileDetails = [];

    for (const file of files) {
      const filePath = path.join(UPLOAD_DIR, file);
      const stats = await fs.stat(filePath);
      fileDetails.push({
        name: file,
        size: stats.size,
        created: stats.birthtime,
        modified: stats.mtime
      });
    }

    res.status(200).json({
      success: true,
      files: fileDetails
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: `Error al listar archivos: ${error.message}`
    });
  }
});

app.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({
        success: false,
        error: 'El archivo excede el tamaño máximo permitido de 5 MB'
      });
    }
    return res.status(400).json({
      success: false,
      error: `Error de Multer: ${err.message}`
    });
  }

  if (err.message && err.message.includes('Extensión de archivo no permitida')) {
    return res.status(400).json({
      success: false,
      error: err.message
    });
  }

  res.status(500).json({
    success: false,
    error: `Error del servidor: ${err.message}`
  });
});

app.listen(PORT, async () => {
  await ensureUploadDir();
  console.log(`Servidor ejecutándose en http://localhost:${PORT}`);
  console.log(`Directorio de carga: ${UPLOAD_DIR}`);
});

