const express = require('express');
const cors = require('cors');
require('dotenv').config();
/* This File is the Gateway to all the backend resources. Its Like the Network; When Opened or Gets started it allows anything(files) with the RIGHT address. 

<> The Right Address Is made Up of Two Parts:
      1. Server's own address IP address (with a port included),eg: http://192.168.1.100:5000
      
      In addition to(+)
      
      2. the resource address(creating endpoint address(look at step 5 for reference)) which is directly assigned to One Specified route address

      In total(1+2) you get; eg: http://192.168.1.100:5000/api/signuproutes
      
      
*/


//1. Importing and assigning the available routes resources living in the routes folder.
//=================================================================
const signupRoutes = require('./routes/signupRoutes');
const googleRoutes = require('./routes/googleRoutes');
const phoneRoutes = require('./routes/phoneRoutes');
const loginRoutes = require('./routes/login_routes');
const userPasswordRoutes = require('./routes/user_password_routes');


//2.Express makes it possible to create a server and define how it allows, act and respond to different HTTP requests from the client(frontend). Here we create an instance of an Express application, which will be our server.
const app = express();

app.use(cors());//3. allows the server to accept requests form clients different origins
app.use(express.json());//4. Converts incoming JSON request bodies passed from the client(Frontend) into JavaScript objects so that it can be used and read by controllers

app.get('/api/health', (_req, res) => {
  res.status(200).json({ success: true, message: 'CampusRun is Acive...' });
});

// 5. We then create address(endpoints) for each of the imported resources(routes), and assign them to the server(express). This means that client(frontend) is Only allowed to access the the whole backend resources Only  through these available defined address paths
app.use('/api/signuproutes', signupRoutes);
app.use('/api/googleroutes', googleRoutes);
app.use('/api/phoneroutes', phoneRoutes);
app.use('/api/loginroutes', loginRoutes);
app.use('/api/userpasswordroutes', userPasswordRoutes);


//6. Finally we start the server and make it listen on a specified port for incoming requests from the client(frontend). The port can be defined in an environment variable or defaults to 5000 if not specified.
const port = process.env.PORT || 5000;
app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});
