import express from "express";
import fs from "fs";
import path, { dirname } from "path";
import { fileURLToPath } from "url";
import { initializeDatabase } from "./db/init.js";
import { getAllUsers, getUserById, createUser } from "./db/users.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const PORT = process.env.PORT || 8080;

// Initialize database on startup
let dbInitialized = false;
async function initDb() {
  if (!dbInitialized) {
    try {
      await initializeDatabase();
      dbInitialized = true;
      console.log("Database initialization completed");
    } catch (error) {
      console.error("Database initialization failed:", error);
      // Continue running the app even if DB init fails
    }
  }
}
initDb();

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// API Routes - Must be defined BEFORE static file middleware
// to ensure API requests are handled correctly
app.get("/api/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Example API endpoint for data loading
app.get("/api/data/:id", (req, res) => {
  const { id } = req.params;
  // Your server-side data loading logic here
  res.json({ id, data: "Sample data" });
});

// Example API endpoint for form processing
app.post("/api/submit", async (req, res) => {
  try {
    const formData = req.body;
    const { name, email } = formData;
    
    if (name && email && dbInitialized) {
      // Try to create user in database
      const user = await createUser(name, email);
      console.log("User created in database:", user);
      res.json({ success: true, message: "User created successfully", user });
    } else {
      // Fallback if DB not available
      console.log("Form submitted:", formData);
      res.json({ success: true, message: "Form processed successfully" });
    }
  } catch (error) {
    console.error("Error processing form:", error);
    res.status(500).json({ success: false, message: "Error processing form" });
  }
});

// Get all users from database
app.get("/api/users", async (req, res) => {
  try {
    if (!dbInitialized) {
      return res.status(503).json({ error: "Database not initialized" });
    }
    const users = await getAllUsers();
    res.json(users);
  } catch (error) {
    console.error("Error fetching users:", error);
    res.status(500).json({ error: "Failed to fetch users" });
  }
});

// Get a specific user by ID
app.get("/api/users/:id", async (req, res) => {
  try {
    if (!dbInitialized) {
      return res.status(503).json({ error: "Database not initialized" });
    }
    const id = parseInt(req.params.id);
    const user = await getUserById(id);
    
    if (user) {
      res.json(user);
    } else {
      res.status(404).json({ error: "User not found" });
    }
  } catch (error) {
    console.error("Error fetching user:", error);
    res.status(500).json({ error: "Failed to fetch user" });
  }
});

// Serve static files from the dist directory
// In development, files are in ui-dist/
// In production (Azure deployment), files are in dist/
// This must be AFTER API routes to prevent conflicts
const distPath = fs.existsSync(path.join(__dirname, "../dist"))
  ? path.join(__dirname, "../dist")
  : path.join(__dirname, "../ui-dist");
app.use(express.static(distPath));

// SPA fallback - serve index.html for all other routes
// This must be last to allow client-side routing to work
app.get("*", (req, res) => {
  const indexPath = path.join(distPath, "index.html");
  if (fs.existsSync(indexPath)) {
    res.sendFile(indexPath);
  } else {
    res.status(404).send("Application not found. Please build the app first.");
  }
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || "development"}`);
});
