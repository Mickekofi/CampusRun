// hash.js
const bcrypt = require("bcrypt");

async function generate() {
  const hash = await bcrypt.hash("snow@123", 10);
  console.log(hash);
}

generate();


/*
INSERT INTO admins (
    full_name,
    email,
    phone,
    password_hash,
    role,
    account_status
) VALUES (
    'snow',
    'snow@gmail.com',
    '+233000000000',
    '$2b$10$YJn9rG0xkN55xufzfkacae2sEJ41W..1kyihV7q8HzQFCfoqt5hkO',
    'super_admin',
    'active'
);

*/

