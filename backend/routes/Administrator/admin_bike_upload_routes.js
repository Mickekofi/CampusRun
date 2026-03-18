const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const {
  listBikes,
  createBike,
  updateBike,
  deleteBike,
  uploadBikeImage,
} = require('../../controllers/Administrator/admin_bike_upload_controller');

const router = express.Router();




// =====================================================
// This path is very Crutial Path for All Admin Screens, Because it is the source of path where all the bike images will be stored and accessed from, so it is important to ensure that this path is correctly set up and accessible by the server. The images uploaded through the admin interface will be saved in this directory, and the server will serve these images to the frontend when requested. Proper handling of this path ensures that bike images are displayed correctly in the user interface and that the upload functionality works seamlessly for administrators.
//===================================================

const uploadDir = path.join(__dirname, '..','..', 'uploads', 'bikes');


//=================================================End






if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, uploadDir);
  },
  filename: (_req, file, cb) => {
    const safeName = (file.originalname || 'bike-image')
      .replace(/\s+/g, '-')
      .replace(/[^a-zA-Z0-9_.-]/g, '');
    cb(null, `${Date.now()}-${safeName}`);
  },
});

const upload = multer({ storage });

router.get('/bikes', listBikes);
router.post('/upload-image', upload.single('bike_image'), uploadBikeImage);
router.post('/bikes', createBike);
router.put('/bikes/:bikeId', updateBike);
router.delete('/bikes/:bikeId', deleteBike);

module.exports = router;
