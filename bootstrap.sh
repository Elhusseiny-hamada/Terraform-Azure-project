#!/bin/bash
set -euo pipefail

APP_DIR="/opt/vodafone-platform/backend"
FRONTEND_DIR="/var/www/vodafone"

echo "========================================"
echo "Starting Vodafone platform bootstrap..."
echo "========================================"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y curl nginx

# Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

echo "Node version: $(node --version)"
echo "NPM version: $(npm --version)"

# Application directories
mkdir -p "$APP_DIR/src/routes"
mkdir -p "$FRONTEND_DIR"

# package.json
cat > "$APP_DIR/package.json" <<'EOF'
{
  "name": "vodafone-customer-platform-backend",
  "version": "1.0.0",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "init-db": "node src/init-db.js"
  },
  "dependencies": {
    "@azure/identity": "^4.10.0",
    "@azure/keyvault-secrets": "^4.10.0",
    "cors": "^2.8.5",
    "dotenv": "^17.2.1",
    "express": "^5.1.0",
    "mssql": "^12.7.2"
  }
}
EOF

# server.js
cat > "$APP_DIR/src/server.js" <<'EOF'
require("dotenv").config();

const express = require("express");
const cors = require("cors");
const customerRoutes = require("./routes/customer");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/api/health", (req, res) => {
  res.json({
    status: "healthy",
    service: "vodafone-customer-platform",
    timestamp: new Date().toISOString()
  });
});

app.use("/api/customer", customerRoutes);

const PORT = process.env.PORT || 3000;

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Vodafone API running on port ${PORT}`);
});
EOF

# db.js
cat > "$APP_DIR/src/db.js" <<'EOF'
const sql = require("mssql");
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");

const keyVaultUrl = "https://kv-azure-cloud-project01.vault.azure.net";
const credential = new DefaultAzureCredential();
const secretClient = new SecretClient(keyVaultUrl, credential);

async function getDatabaseConfig() {
  const usernameSecret = await secretClient.getSecret("sql-admin-username");
  const passwordSecret = await secretClient.getSecret("sql-admin-password");

  return {
    server: process.env.DB_SERVER,
    database: process.env.DB_NAME,
    user: usernameSecret.value,
    password: passwordSecret.value,
    options: {
      encrypt: true,
      trustServerCertificate: false
    },
    pool: {
      max: 10,
      min: 0,
      idleTimeoutMillis: 30000
    }
  };
}

async function createPool() {
  const config = await getDatabaseConfig();
  return new sql.ConnectionPool(config).connect();
}

const poolPromise = createPool()
  .then(pool => {
    console.log("Connected to Azure SQL through Private Endpoint");
    return pool;
  })
  .catch(error => {
    console.error("Database connection failed:", error.message);
    throw error;
  });

module.exports = { sql, poolPromise, createPool };
EOF

# customer.js
cat > "$APP_DIR/src/routes/customer.js" <<'EOF'
const express = require("express");
const router = express.Router();

const { sql, poolPromise } = require("../db");

router.get("/profile/:id", async (req, res) => {
  try {
    const pool = await poolPromise;

    const result = await pool
      .request()
      .input("id", sql.Int, req.params.id)
      .query(`
        SELECT
          c.id,
          c.name,
          c.phone,
          c.email,
          p.name AS plan_name,
          c.balance
        FROM dbo.Customers AS c
        LEFT JOIN dbo.Plans AS p
          ON c.plan_id = p.id
        WHERE c.id = @id
      `);

    if (result.recordset.length === 0) {
      return res.status(404).json({ message: "Customer not found" });
    }

    res.json(result.recordset[0]);
  } catch (error) {
    console.error("Database error:", error);
    res.status(500).json({ message: "Database connection/query failed" });
  }
});

module.exports = router;
EOF

# Idempotent SQL initializer
# Idempotent SQL initializer
cat > "$APP_DIR/src/init-db.js" <<'EOF'
require("dotenv").config();

const { createPool } = require("./db");

const firstNames = [
  "Ahmed", "Mohamed", "Omar", "Youssef", "Mahmoud",
  "Mostafa", "Amr", "Karim", "Hassan", "Khaled",
  "Tarek", "Hany", "Sherif", "Mina", "Peter",
  "Mariam", "Salma", "Sara", "Nour", "Menna"
];

const lastNames = [
  "Hassan", "Ali", "Mohamed", "Mahmoud", "Ibrahim",
  "Mostafa", "Fathy", "Samir", "Adel", "Kamal",
  "Sayed", "Farouk", "Nasser", "Younis", "Gaber"
];

const plans = [
  "Vodafone Red",
  "Vodafone Flex",
  "Vodafone Plus",
  "Vodafone Business",
  "Vodafone Data"
];

function customerName(index) {
  const first = firstNames[index % firstNames.length];
  const last = lastNames[Math.floor(index / firstNames.length) % lastNames.length];
  return `${first} ${last}`;
}

function customerPhone(index) {
  return `010${String(10000000 + index).padStart(8, "0")}`;
}

function customerEmail(index) {
  return `customer${index}@example.com`;
}

async function initializeDatabase() {
  let pool;

  try {
    console.log("========================================");
    console.log("Starting database initialization...");
    console.log("Target: 100 customers");
    console.log("========================================");

    pool = await createPool();

    // ==============================
    // CREATE TABLES
    // ==============================

    await pool.request().batch(`
      IF OBJECT_ID(N'dbo.Plans', N'U') IS NULL
      BEGIN
        CREATE TABLE dbo.Plans (
          id INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Plans PRIMARY KEY,
          name NVARCHAR(100) NOT NULL
            CONSTRAINT UQ_Plans_name UNIQUE
        );
      END;

      IF OBJECT_ID(N'dbo.Customers', N'U') IS NULL
      BEGIN
        CREATE TABLE dbo.Customers (
          id INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Customers PRIMARY KEY,
          name NVARCHAR(150) NOT NULL,
          phone NVARCHAR(30) NULL,
          email NVARCHAR(150) NULL,
          plan_id INT NULL,
          balance DECIMAL(18,2) NOT NULL
            CONSTRAINT DF_Customers_balance DEFAULT (0),
          CONSTRAINT FK_Customers_Plans
            FOREIGN KEY (plan_id) REFERENCES dbo.Plans(id)
        );
      END;
    `);

    // ==============================
    // INSERT PLANS
    // ==============================

    for (const plan of plans) {
      await pool
        .request()
        .input("name", plan)
        .query(`
          IF NOT EXISTS (
            SELECT 1
            FROM dbo.Plans
            WHERE name = @name
          )
          BEGIN
            INSERT INTO dbo.Plans (name)
            VALUES (@name);
          END
        `);
    }

    console.log("Plans initialized.");

    // ==============================
    // GET PLAN IDS
    // ==============================

    const planResult = await pool.request().query(`
      SELECT id, name
      FROM dbo.Plans
      WHERE name IN (
        N'Vodafone Red',
        N'Vodafone Flex',
        N'Vodafone Plus',
        N'Vodafone Business',
        N'Vodafone Data'
      )
    `);

    const planMap = {};

    for (const row of planResult.recordset) {
      planMap[row.name] = row.id;
    }

    // ==============================
    // INSERT 100 CUSTOMERS
    // ==============================

    let inserted = 0;

    for (let i = 1; i <= 100; i++) {
      const name = customerName(i - 1);
      const phone = customerPhone(i);
      const email = customerEmail(i);

      const planName = plans[(i - 1) % plans.length];
      const planId = planMap[planName];

      const balance = ((i * 37.5) % 500) + 50;

      const result = await pool
        .request()
        .input("name", name)
        .input("phone", phone)
        .input("email", email)
        .input("plan_id", planId)
        .input("balance", balance)
        .query(`
          IF NOT EXISTS (
            SELECT 1
            FROM dbo.Customers
            WHERE email = @email
          )
          BEGIN
            INSERT INTO dbo.Customers
              (name, phone, email, plan_id, balance)
            VALUES
              (@name, @phone, @email, @plan_id, @balance);

            SELECT 1 AS inserted;
          END
          ELSE
          BEGIN
            SELECT 0 AS inserted;
          END
        `);

      if (result.recordset[0].inserted === 1) {
        inserted++;
      }
    }

    // ==============================
    // FINAL COUNTS
    // ==============================

    const result = await pool.request().query(`
      SELECT
        (SELECT COUNT(*) FROM dbo.Plans) AS plans_count,
        (SELECT COUNT(*) FROM dbo.Customers) AS customers_count;
    `);

    console.log("========================================");
    console.log("Database initialization completed.");
    console.log(`New customers inserted: ${inserted}`);
    console.log(`Total plans: ${result.recordset[0].plans_count}`);
    console.log(`Total customers: ${result.recordset[0].customers_count}`);
    console.log("========================================");

  } catch (error) {
    console.error("Database initialization failed:", error);
    process.exitCode = 1;
  } finally {
    if (pool) {
      await pool.close();
    }
  }
}

initializeDatabase();
EOF
# Environment
cat > "$APP_DIR/.env" <<'EOF'
PORT=3000
DB_SERVER=sql-primary-cloud-project.database.windows.net
DB_NAME=webappdb
EOF

# Dependencies
cd "$APP_DIR"
npm install --omit=dev

# systemd
cat > /etc/systemd/system/vodafone-backend.service <<'EOF'
[Unit]
Description=Vodafone Customer Platform Backend
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/vodafone-platform/backend
ExecStart=/usr/bin/node /opt/vodafone-platform/backend/src/server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vodafone-backend
systemctl restart vodafone-backend

# Frontend
cat > "$FRONTEND_DIR/index.html" <<'EOF'
<!doctype html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Vodafone Customer Portal</title><link rel="stylesheet" href="/style.css"></head><body><header><div class="brand"><b>V</b><div><strong>Vodafone</strong><small>Customer Portal</small></div></div><span id="status">● Checking API...</span></header><main><section class="hero"><div><small>MY ACCOUNT</small><h1>Welcome to your customer portal</h1><p>View your plan, contact details and current balance.</p></div><i>✓</i></section><section class="search"><label>Customer ID</label><div><input id="id" type="number" min="1" value="1"><button onclick="load()">Load Profile</button></div><p id="err"></p></section><section id="profile" class="grid" hidden><article class="card identity"><span id="avatar">CU</span><div><small>CUSTOMER</small><h2 id="name">—</h2><p id="email">—</p></div></article><article class="card"><small>MOBILE</small><h3 id="phone">—</h3></article><article class="card"><small>CURRENT PLAN</small><h3 id="plan">—</h3></article><article class="card"><small>BALANCE</small><h3><span id="balance">—</span> EGP</h3></article></section><footer>Vodafone Customer Platform · Secure Azure-hosted application</footer></main><script src="/app.js"></script></body></html>
EOF

cat > "$FRONTEND_DIR/style.css" <<'EOF'
*{box-sizing:border-box}body{margin:0;background:#f5f6f8;color:#202124;font-family:Arial,sans-serif}.topbar,header{height:76px;background:white;border-bottom:4px solid #e60000;display:flex;align-items:center;justify-content:space-between;padding:0 7%;box-shadow:0 2px 10px #0001}.brand{display:flex;align-items:center;gap:12px}.brand b{width:44px;height:44px;border-radius:50%;background:#e60000;color:white;display:grid;place-items:center;font-size:25px}.brand strong{display:block;font-size:20px}.brand small{color:#777}.brand+span{font-size:13px;color:#555}main{max-width:1100px;margin:40px auto;padding:0 22px}.hero{background:linear-gradient(135deg,#e60000,#a90000);color:white;border-radius:18px;padding:36px 40px;display:flex;justify-content:space-between;align-items:center;box-shadow:0 12px 28px #0002}.hero small,.card small{font-weight:bold;letter-spacing:1.2px}.hero h1{margin:8px 0;font-size:34px}.hero p{opacity:.88}.hero i{width:70px;height:70px;border:2px solid #fff8;border-radius:50%;display:grid;place-items:center;font-size:34px}.search,.card{background:white;border-radius:16px;box-shadow:0 5px 18px #0000000d}.search{margin-top:22px;padding:24px}.search label{font-weight:bold;display:block;margin-bottom:10px}.search div{display:flex;gap:12px}.search input{flex:1;border:1px solid #d6d9dd;border-radius:10px;padding:13px;font-size:16px}.search button{border:0;border-radius:10px;padding:13px 22px;background:#e60000;color:white;font-weight:bold;cursor:pointer}.search button:hover{background:#c90000}#err{color:#b00020}.grid{display:grid;grid-template-columns:2fr 1fr 1fr 1fr;gap:16px;margin-top:22px}.card{padding:24px;min-height:130px}.card small{color:#8a9096}.card h2,.card h3{margin:8px 0}.identity{display:flex;align-items:center;gap:16px}.identity>span{width:58px;height:58px;border-radius:50%;background:#f2d6d6;color:#a40000;display:grid;place-items:center;font-weight:bold;font-size:19px}.identity p{color:#687078;margin:5px 0}.card h3{font-size:20px}.card:last-child h3{color:#a40000}footer{text-align:center;color:#8a9096;font-size:12px;margin:35px 0}@media(max-width:800px){.grid{grid-template-columns:1fr 1fr}.identity{grid-column:1/-1}.hero h1{font-size:27px}}@media(max-width:520px){header{padding:0 20px}.brand+span{display:none}main{margin:22px auto}.hero{padding:28px 24px}.hero h1{font-size:24px}.hero i{display:none}.search div{flex-direction:column}.grid{grid-template-columns:1fr}}
EOF

cat > "$FRONTEND_DIR/app.js" <<'EOF'
const $=x=>document.getElementById(x);async function health(){try{let r=await fetch('/api/health',{cache:'no-store'});if(!r.ok)throw 0;$('status').innerHTML='<span style="color:#20a05a">●</span> API Online'}catch(e){$('status').innerHTML='<span style="color:#e60000">●</span> API Unavailable'}}async function load(){let id=$('id').value.trim();$('err').textContent='';$('profile').hidden=true;if(!id)return;try{let r=await fetch('/api/customer/profile/'+encodeURIComponent(id),{cache:'no-store'});let d=await r.json();if(!r.ok)throw Error(d.message||'Customer not found');$('name').textContent=d.name||'—';$('email').textContent=d.email||'—';$('phone').textContent=d.phone||'—';$('plan').textContent=d.plan_name||'No plan';$('balance').textContent=Number(d.balance||0).toFixed(2);$('avatar').textContent=String(d.name||'Customer').split(/\s+/).slice(0,2).map(x=>x[0]).join('').toUpperCase();$('profile').hidden=false}catch(e){$('err').textContent=e.message||'Unable to load customer profile.'}}$('id').addEventListener('keydown',e=>{if(e.key==='Enter')load()});health();load();
EOF

chown -R www-data:www-data "$FRONTEND_DIR"
chmod -R 755 "$FRONTEND_DIR"

# Nginx
cat > /etc/nginx/sites-available/vodafone <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/vodafone;
    index index.html;

    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/vodafone /etc/nginx/sites-enabled/vodafone

nginx -t
systemctl restart nginx

echo "========================================"
echo "Bootstrap completed."
echo "========================================"
systemctl is-active vodafone-backend
systemctl is-active nginx
curl -f http://127.0.0.1:3000/api/health
echo ""
curl -f http://127.0.0.1/api/health
echo ""
echo "Vodafone platform is ready."