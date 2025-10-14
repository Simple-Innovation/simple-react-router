import sql from "mssql";
import { DefaultAzureCredential } from "@azure/identity";

export async function getDbConfig(): Promise<sql.config> {
  const server = process.env.SQL_SERVER;
  const database = process.env.SQL_DATABASE;

  if (!server || !database) {
    throw new Error("SQL_SERVER and SQL_DATABASE environment variables are required");
  }

  // Use Azure Managed Identity authentication only
  console.log("Using Azure Managed Identity for SQL authentication");
  const credential = new DefaultAzureCredential();
  
  // Get access token for Azure SQL Database
  const tokenResponse = await credential.getToken("https://database.windows.net/.default");
  
  const config: sql.config = {
    server,
    database,
    options: {
      encrypt: true,
      trustServerCertificate: false,
    },
    authentication: {
      type: "azure-active-directory-access-token",
      options: {
        token: tokenResponse.token,
      },
    },
  };
  
  return config;
}

let pool: sql.ConnectionPool | null = null;

export async function getDbPool(): Promise<sql.ConnectionPool> {
  if (!pool) {
    const config = await getDbConfig();
    pool = await new sql.ConnectionPool(config).connect();
    console.log("Database connection pool established");
  }
  return pool;
}

export async function closeDbPool(): Promise<void> {
  if (pool) {
    await pool.close();
    pool = null;
    console.log("Database connection pool closed");
  }
}
