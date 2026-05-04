import sql from 'mssql';
import dotenv from 'dotenv';
dotenv.config();

const config: sql.config = {
  server: process.env.DB_HOST || '10.11.3.10',
  port: parseInt(process.env.DB_PORT || '1433'),
  database: process.env.DB_NAME || 'ValueAT_UAT_Nippon',
  user: process.env.DB_USER || 'da_user',
  password: process.env.DB_PASSWORD || 'DA@@DA@@123',
  options: {
    encrypt: false,
    trustServerCertificate: true,
    enableArithAbort: true,
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

let pool: sql.ConnectionPool | null = null;

export async function getPool(): Promise<sql.ConnectionPool> {
  if (!pool) {
    pool = await new sql.ConnectionPool(config).connect();
  }
  return pool;
}

export { sql };
