// server.js

require("dotenv").config();
const app = require("./app");
const pool = require("./config/db");

const PORT = process.env.PORT || 4000;

async function start() {
  try {
    // Fail fast and loud if DB credentials are wrong — better than
    // discovering it on the first real request.
    const conn = await pool.getConnection();
    await conn.ping();
    conn.release();
    console.log("✅ MySQL connection OK");
  } catch (err) {
    console.error("❌ Could not connect to MySQL:", err.message);
    process.exit(1);
  }

  app.listen(PORT, () => {
    console.log(`🚀  backend running on http://localhost:${PORT}`);
  });
}

start();
