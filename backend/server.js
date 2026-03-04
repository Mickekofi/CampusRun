const express = require('express');
const cors = require('cors');
require('dotenv').config();

const signupRoutes = require('./routes/signuproutes');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/api/health', (_req, res) => {
  res.status(200).json({ success: true, message: 'CampusRun backend is running.' });
});

app.use('/api/signuproutes', signupRoutes);

const port = process.env.PORT || 5000;
app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});
