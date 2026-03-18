const express = require('express');
const {
  listStations,
  createStation,
  updateStation,
  deleteStation,
  createPayment,
  listTransportPrices,
  createTransportPrice,
  deleteTransportPrice,
  listBannedZones,
  createBannedZone,
  deleteBannedZone,
} = require('../../controllers/Administrator/admin_station_upload_controller');

const router = express.Router();

router.get('/stations', listStations);
router.post('/stations', createStation);
router.put('/stations/:stationId', updateStation);
router.delete('/stations/:stationId', deleteStation);
router.post('/payments', createPayment);

router.get('/prices', listTransportPrices);
router.post('/prices', createTransportPrice);
router.delete('/prices/:priceId', deleteTransportPrice);

router.get('/banned-zones', listBannedZones);
router.post('/banned-zones', createBannedZone);
router.delete('/banned-zones/:zoneId', deleteBannedZone);

module.exports = router;
