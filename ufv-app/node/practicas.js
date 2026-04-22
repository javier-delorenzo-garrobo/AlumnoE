const express = require('express');
const { Pool } = require('pg');
const AWS = require('aws-sdk');
const multer = require('multer');

const app = express();
const port = 3003;

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

const s3 = new AWS.S3({ region: 'eu-south-2' });
const BUCKET_NAME = 'entregas-practicas-ufv-equipo-e';

const pool = new Pool({
  host: '10.0.1.10',
  user: 'backend',
  password: 'backend_password',
  database: 'ufv',
  port: 5432,
});

const upload = multer({ storage: multer.memoryStorage() });

app.get('/practicas', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM academico.practicas');
    let html = '<h1>Lista de Prácticas</h1>';
    html += '<ul>';
    result.rows.forEach(row => {
      html += `<li>ID: ${row.id} | Asignatura: ${row.asignatura_id} | Título: ${row.titulo} | Límite: ${row.fecha_limite}</li>`;
    });
    html += '</ul>';
    html += '<a href="/practicas/nueva"><button>Nueva Práctica</button></a>';
    res.send(html);
  } catch (err) {
    console.error(err);
    res.status(500).send('Error');
  }
});

app.get('/practicas/nueva', (req, res) => {
  const html = `
    <h1>Nueva Práctica</h1>
    <form action="/practicas" method="POST">
      <label>ID Asignatura:</label> <input type="number" name="asignatura_id" required /><br/>
      <label>Título:</label> <input type="text" name="titulo" required /><br/>
      <label>Descripción:</label> <textarea name="descripcion" required></textarea><br/>
      <label>Fecha Límite:</label> <input type="date" name="fecha_limite" required /><br/>
      <button type="submit">Crear Práctica</button>
    </form>
  `;
  res.send(html);
});

app.post('/practicas', async (req, res) => {
  try {
    const { asignatura_id, titulo, descripcion, fecha_limite } = req.body;
    await pool.query(
      'INSERT INTO academico.practicas (asignatura_id, titulo, descripcion, fecha_limite) VALUES ($1, $2, $3, $4)',
      [asignatura_id, titulo, descripcion, fecha_limite]
    );
    res.redirect('/practicas');
  } catch (err) {
    console.error(err);
    res.status(500).send('Error');
  }
});

app.post('/practicas/entregar', upload.single('archivo'), async (req, res) => {
  try {
    const { practica_id, alumno_id } = req.body;
    const file = req.file;

    if (!file) {
      return res.status(400).send('Archivo no subido');
    }

    const key = `entregas/${practica_id}/${alumno_id}_${file.originalname}`;

    const s3Params = {
      Bucket: BUCKET_NAME,
      Key: key,
      Body: file.buffer,
    };

    await s3.upload(s3Params).promise();

    await pool.query(
      'INSERT INTO academico.entregas (practica_id, alumno_id, fecha_entrega, comentario) VALUES ($1, $2, NOW(), $3)',
      [practica_id, alumno_id, `Ruta S3: ${key}`]
    );

    res.send('Entrega realizada con éxito');
  } catch (err) {
    console.error(err);
    res.status(500).send('Error');
  }
});

app.listen(port, () => {
  console.log(`Backend escuchando en http://localhost:${port}`);
});
