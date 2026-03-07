// hash.js
const bcrypt = require("bcrypt");

async function generate() {
  const hash = await bcrypt.hash("snow@123", 10);
  console.log(hash);
}

generate();