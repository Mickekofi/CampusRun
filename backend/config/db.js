const mysql = require("mysql2");

// STEP 1: Define connection variables
const dbHost = process.env.DB_HOST;
const dbUser = process.env.DB_USER;
const dbPassword = process.env.DB_PASSWORD;
const dbName = process.env.DB_NAME;

// STEP 2: Define connecti  on configuration
const dbConfig = {
  host: dbHost,
  user: dbUser,
  password: dbPassword,
  database: dbName
};

// STEP 3: Extra security & performance options
const poolOptions = {
  ...dbConfig,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

// STEP 4: Create connection pool instance
const pool = mysql.createPool(poolOptions);

// STEP 5: Handle connection test
pool.getConnection((err, connection) => {
  if (err) {
    console.error("Database connection failed:", err.message);
  } else {
    console.log("Database connected successfully");
    connection.release();
  }
});

module.exports = pool;