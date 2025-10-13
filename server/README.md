# Server Documentation

## Overview

This Express server provides:

- Server-side rendering support (SSR)
- API endpoints for data loading
- Server-side form processing
- Static file serving for the React SPA

## Project Structure

```text
server/
  index.ts          # Main server entry point
server-dist/        # Compiled server code (generated)
dev/dist/          # Built React client app (generated)
```

## Development

### Run the development server with hot reload

```bash
npm run dev:server
```

This will watch for changes in the `server/` directory and automatically restart.

### Run the client dev server (Vite)

```bash
npm run dev
```

## Building

Build both client and server:

```bash
npm run build
```

This will:

1. Build the React client app with Vite → `dev/dist/`
2. Compile the TypeScript server → `server-dist/`

## Production

Start the production server:

```bash
npm start
```

The server will:

- Serve the built React app from `dev/dist/`
- Handle API routes at `/api/*`
- Fallback to SPA routing for all other routes

## Adding API Endpoints

Edit `server/index.ts` to add your endpoints:

```typescript
// Data loader example
app.get("/api/users/:id", (req, res) => {
  const { id } = req.params;
  // Fetch data from database
  res.json({ id, name: "John Doe" });
});

// Form processing example
app.post("/api/forms/submit", (req, res) => {
  const data = req.body;
  // Process form data
  res.json({ success: true });
});
```

## Client-Side Integration

Call your API endpoints from React components:

```typescript
// In your React component
async function loadUserData(userId: string) {
  const response = await fetch(`/api/users/${userId}`);
  const data = await response.json();
  return data;
}

// In your Form action
async function handleSubmit(formData: FormData) {
  const response = await fetch("/api/forms/submit", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(Object.fromEntries(formData)),
  });
  return response.json();
}
```

## Environment Variables

- `PORT`: Server port (default: 8080)
- `NODE_ENV`: Environment (development/production)

## Azure Deployment

The GitHub Actions workflow automatically:

1. Builds the client and server
2. Packages both for deployment
3. Deploys to Azure App Service
4. Runs `npm install --production && npm start` on Azure

The server serves both API endpoints and the static React app.
