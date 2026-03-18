const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

/* This File is the Gateway to all the backend resources. Its Like the Network; When Opened or Gets started it allows anything(files) with the RIGHT address. 

<> The Right Address Is made Up of Two Parts:
      1. Server's own address IP address (with a port included),eg: http://192.168.1.100:5000
      
      In addition to(+)
      
      2. the resource address(creating endpoint address(look at step 5 for reference)) which is directly assigned to One Specified route address

      In total(1+2) you get; eg: http://192.168.1.100:5000/api/signuproutes
     
      

  

      
*/

// Add this import near the top

// Mount the endpoint securely


// Add this import near your other route imports at the top

// Add this where you mount the rest of your /api routes


//1. Importing and assigning the available routes resources living in the routes folder.
//=================================================================
const signupRoutes = require('./routes/Users/signupRoutes');
const googleRoutes = require('./routes/googleRoutes');
const phoneRoutes = require('./routes/Users/phoneRoutes');
const loginRoutes = require('./routes/login_routes');
const userPasswordRoutes = require('./routes/Users/user_password_routes');
const userDashboardRoutes = require('./routes/Users/user_dashboard_routes');
const userBikeSelectionRoutes = require('./routes/Users/user_bikeSelection_routes');
const userConfirmBikeRoutes = require('./routes/Users/user_confirm_bike_routes');
const userPaymentRoutes = require('./routes/Users/user_payment_routes');
const userDepositRoutes = require('./routes/Users/user_deposit_screen_routes');
const userScanQrRoutes = require('./routes/Users/user_scanQR_routes');
const userRideModeRoutes = require('./routes/Users/user_ridemode_routes');
const userAccountRoutes = require('./routes/Users/user_account_routes');


const adminBikeUploadRoutes = require('./routes/Administrator/admin_bike_upload_routes');
const adminStationUploadRoutes = require('./routes/Administrator/admin_station_upload_routes');
const adminBikeOperationsRoutes = require('./routes/Administrator/admin_bike_operations_routes');
const adminUserMonitorRoutes = require('./routes/Administrator/admin_user_monitor_routes');
const adminLiveTrackerRoutes = require('./routes/Administrator/admin_live_tracker_routes');


//2.Express makes it possible to create a server and define how it allows, act and respond to different HTTP requests from the client(frontend). Here we create an instance of an Express application, which will be our server.
const app = express();

app.use(cors());//3. allows the server to accept requests form clients different origins
app.use(express.json());//4. Converts incoming JSON request bodies passed from the client(Frontend) into JavaScript objects so that it can be used and read by controllers


app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.get('/api/health', (_req, res) => {
  res.status(200).json({ success: true, message: 'CampusRun is Acive...' });
});

// 5. We then create address(endpoints) for each of the imported resources(routes), and assign them to the server(express). This means that client(frontend) is Only allowed to access the the whole backend resources Only  through these available(listed below) defined address paths
app.use('/api/signuproutes', signupRoutes);
app.use('/api/googleroutes', googleRoutes);
app.use('/api/phoneroutes', phoneRoutes);
app.use('/api/loginroutes', loginRoutes);
app.use('/api/userpasswordroutes', userPasswordRoutes);
app.use('/api/user_dashboard_routes', userDashboardRoutes);
app.use('/api/user_bikeSelection_routes', userBikeSelectionRoutes);
app.use('/api/confirm-bike', userConfirmBikeRoutes);
app.use('/api/payment', userPaymentRoutes);
app.use('/api/deposit', userDepositRoutes);
app.use('/api/scan', userScanQrRoutes);
app.use('/api/ridemode', userRideModeRoutes);
app.use('/api/account', userAccountRoutes);



app.use('/api/admin_bike_upload_routes', adminBikeUploadRoutes);
app.use('/api/admin_station_upload_routes', adminStationUploadRoutes);
app.use('/api/admin_bike_operations_routes', adminBikeOperationsRoutes);
app.use('/api/admin_user_monitor_routes', adminUserMonitorRoutes);
app.use('/api/admin_live_tracker_routes', adminLiveTrackerRoutes);



//6. Finally we start the server and make it listen on a specified port for incoming requests from the client(frontend). The port can be defined in an environment variable or defaults to 5000 if not specified.
const port = process.env.PORT || 5000;
app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});