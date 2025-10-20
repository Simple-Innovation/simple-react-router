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
  console.log(`Connecting to server: ${server}`);
  console.log(`Database: ${database}`);
  
  const credential = new DefaultAzureCredential();
  
  try {
    // Get access token for Azure SQL Database
    const tokenResponse = await credential.getToken("https://database.windows.net/.default");
    console.log("Successfully acquired Azure AD token for database access");
    
    // Decode token to check identity (for debugging)
    try {
      const tokenParts = tokenResponse.token.split('.');
      if (tokenParts.length === 3) {
        const payload = JSON.parse(Buffer.from(tokenParts[1], 'base64').toString());
        console.log("Token identity info:", {
          oid: payload.oid || 'not present',
          appid: payload.appid || 'not present', 
          upn: payload.upn || 'not present',
          unique_name: payload.unique_name || 'not present'
        });
      }
    } catch (decodeError) {
      console.log("Could not decode token for debugging (this is not a critical error)");
    }
    
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
  } catch (error) {
    console.error("Failed to acquire Azure AD token:", error);
    throw new Error(`Failed to acquire Azure AD token for database authentication: ${error instanceof Error ? error.message : String(error)}`);
  }
}

let pool: sql.ConnectionPool | null = null;

export async function getDbPool(): Promise<sql.ConnectionPool> {
  if (!pool) {
    const config = await getDbConfig();
    try {
      pool = await new sql.ConnectionPool(config).connect();
      console.log("Database connection pool established successfully");
    } catch (error) {
      console.error("Failed to establish database connection:", error);
      if (error instanceof Error) {
        console.error("Error details:", {
          message: error.message,
          name: error.name,
        });
      }
      throw new Error(`Database connection failed: ${error instanceof Error ? error.message : String(error)}`);
    }
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
