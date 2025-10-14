import { getDbPool } from "./config.js";

export async function initializeDatabase(): Promise<void> {
  try {
    const pool = await getDbPool();
    
    // Create Users table if it doesn't exist
    await pool.request().query(`
      IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Users' AND xtype='U')
      CREATE TABLE Users (
        Id INT PRIMARY KEY IDENTITY(1,1),
        Name NVARCHAR(100) NOT NULL,
        Email NVARCHAR(100) NOT NULL UNIQUE,
        CreatedAt DATETIME2 DEFAULT GETDATE()
      )
    `);
    
    // Check if table is empty and add sample data
    const result = await pool.request().query('SELECT COUNT(*) as count FROM Users');
    const count = result.recordset[0].count;
    
    if (count === 0) {
      console.log("Adding sample users to database...");
      await pool.request().query(`
        INSERT INTO Users (Name, Email) VALUES
        ('John Doe', 'john.doe@example.com'),
        ('Jane Smith', 'jane.smith@example.com'),
        ('Bob Johnson', 'bob.johnson@example.com'),
        ('Alice Williams', 'alice.williams@example.com'),
        ('Charlie Brown', 'charlie.brown@example.com')
      `);
      console.log("Sample users added successfully");
    }
    
    console.log("Database initialized successfully");
  } catch (error) {
    console.error("Error initializing database:", error);
    throw error;
  }
}
