import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static files from the dist directory
const distPath = path.join(__dirname, '../dist');
app.use(express.static(distPath));

// API Routes
// Add your API endpoints here
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Example API endpoint for data loading
app.get('/api/data/:id', (req, res) => {
  const { id } = req.params;
  // Your server-side data loading logic here
  res.json({ id, data: 'Sample data' });
});

// Example API endpoint for form processing
app.post('/api/submit', (req, res) => {
  const formData = req.body;
  // Your server-side form processing logic here
  console.log('Form submitted:', formData);
  res.json({ success: true, message: 'Form processed successfully' });
});

// SPA fallback - serve index.html for all other routes
// This must be last to allow client-side routing to work
app.get('*', (req, res) => {
  const indexPath = path.join(distPath, 'index.html');
  if (fs.existsSync(indexPath)) {
    res.sendFile(indexPath);
  } else {
    res.status(404).send('Application not found. Please build the app first.');
  }
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});
