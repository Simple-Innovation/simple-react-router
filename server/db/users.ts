import { getDbPool } from "./config.js";

export interface User {
  Id: number;
  Name: string;
  Email: string;
  CreatedAt: Date;
}

export async function getAllUsers(): Promise<User[]> {
  try {
    const pool = await getDbPool();
    const result = await pool.request().query('SELECT Id, Name, Email, CreatedAt FROM Users ORDER BY CreatedAt DESC');
    return result.recordset;
  } catch (error) {
    console.error("Error fetching users:", error);
    throw error;
  }
}

export async function getUserById(id: number): Promise<User | null> {
  try {
    const pool = await getDbPool();
    const result = await pool.request()
      .input('id', id)
      .query('SELECT Id, Name, Email, CreatedAt FROM Users WHERE Id = @id');
    
    return result.recordset.length > 0 ? result.recordset[0] : null;
  } catch (error) {
    console.error("Error fetching user:", error);
    throw error;
  }
}

export async function createUser(name: string, email: string): Promise<User> {
  try {
    const pool = await getDbPool();
    const result = await pool.request()
      .input('name', name)
      .input('email', email)
      .query('INSERT INTO Users (Name, Email) OUTPUT INSERTED.* VALUES (@name, @email)');
    
    return result.recordset[0];
  } catch (error) {
    console.error("Error creating user:", error);
    throw error;
  }
}
