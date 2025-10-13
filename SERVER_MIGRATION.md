# Server-Side Architecture Migration

## What Changed

The application has been upgraded from a static SPA deployment to a full-stack Node.js application with Express server support.

### Previous Setup (Static Only)
- ❌ Static file server using `serve` package
- ❌ No server-side data loading
- ❌ No server-side form processing
- ❌ No API endpoints

### New Setup (Full-Stack)
- ✅ Express server with API endpoints
- ✅ Server-side data loaders
- ✅ Server-side form processing
- ✅ Client-side React SPA with server support
- ✅ Proper production deployment

## File Changes

### New Files
- `server/index.ts` - Express server with API routes
- `server/README.md` - Server documentation
- `tsconfig.server.json` - TypeScript config for server

### Modified Files
- `package.json` - Added Express, updated scripts
- `.github/workflows/azure-webapp-deploy.yml` - Updated deployment process
- `infrastructure/main.bicep` - Updated Azure configuration
- `.gitignore` - Added `server-dist/`

## Architecture

```
┌─────────────────────────────────────────┐
│         Azure App Service               │
│  ┌───────────────────────────────────┐  │
│  │   Express Server (Node.js)        │  │
│  │                                   │  │
│  │  ┌──────────────────────────┐    │  │
│  │  │   API Routes (/api/*)    │    │  │
│  │  │  - Data loaders          │    │  │
│  │  │  - Form processors       │    │  │
│  │  │  - Custom endpoints      │    │  │
│  │  └──────────────────────────┘    │  │
│  │                                   │  │
│  │  ┌──────────────────────────┐    │  │
│  │  │   Static File Server     │    │  │
│  │  │  - Serves React SPA      │    │  │
│  │  │  - Client-side routing   │    │  │
│  │  └──────────────────────────┘    │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Build Process

### Development
```bash
# Run client dev server (Vite with HMR)
npm run dev

# Run server dev server (with hot reload)
npm run dev:server
```

### Production Build
```bash
# Builds both client and server
npm run build
```

This runs:
1. `vite build` → builds React app to `dev/dist/`
2. `tsc --project tsconfig.server.json` → compiles server to `server-dist/`

### Deployment Package Structure
```
deploy-package/
├── dist/              # Built React app
├── server-dist/       # Compiled Express server
├── package.json       # Production dependencies only
└── .deployment        # Azure config
```

## Azure Deployment Flow

1. **Build Job** (GitHub Actions)
   - Installs dependencies
   - Runs tests
   - Builds client (Vite → `dev/dist/`)
   - Builds server (TypeScript → `server-dist/`)
   - Creates deployment package

2. **Deploy Job** (GitHub Actions)
   - Uploads package to Azure
   - Azure runs: `npm install --production && npm start`
   - Server starts on port 8080
   - App is live!

## API Endpoint Examples

The server is pre-configured with example endpoints in `server/index.ts`:

### Health Check
```
GET /api/health
Response: { status: 'ok', timestamp: '...' }
```

### Data Loader Example
```
GET /api/data/:id
Response: { id: '123', data: '...' }
```

### Form Processing Example
```
POST /api/submit
Body: { field1: 'value', field2: 'value' }
Response: { success: true, message: '...' }
```

## Using Server-Side Features in React

### Data Loading
```typescript
// In your route component
async function loadData(id: string) {
  const response = await fetch(`/api/data/${id}`);
  return response.json();
}
```

### Form Actions
```typescript
// In your Form component
import { Form } from './src/Form';

function MyForm() {
  async function handleSubmit(formData: FormData) {
    const response = await fetch('/api/submit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(Object.fromEntries(formData))
    });
    
    const result = await response.json();
    if (result.success) {
      // Handle success
    }
  }
  
  return (
    <Form action={handleSubmit}>
      <input name="field1" />
      <button type="submit">Submit</button>
    </Form>
  );
}
```

## Next Steps

1. **Install dependencies**
   ```bash
   npm install
   ```

2. **Add your API endpoints** in `server/index.ts`

3. **Test locally**
   ```bash
   # Build everything
   npm run build
   
   # Start production server
   npm start
   
   # Visit http://localhost:8080
   ```

4. **Deploy to Azure**
   - Commit and push changes to `main` branch
   - GitHub Actions will automatically deploy
   - Check the Actions tab for deployment status

## Environment Variables

Set these in Azure App Service Configuration (if needed):
- `NODE_ENV=production` (already set in Bicep)
- `PORT=8080` (already set in Bicep)
- Add your custom environment variables as needed

## Troubleshooting

### Build fails locally
```bash
# Clear build artifacts
rm -rf server-dist dev/dist node_modules
npm install
npm run build
```

### Server doesn't start
Check that:
- `server-dist/index.js` exists after build
- `dev/dist/index.html` exists after build
- Port 8080 is not already in use

### Azure deployment fails
- Check GitHub Actions logs
- Verify `AZURE_CREDENTIALS` secret is set
- Ensure resource group and app service are created
- Check Azure App Service logs in the portal

## Benefits

✅ **Server-Side Data Loading** - Fetch data on the server before rendering  
✅ **API Endpoints** - Build backend logic in the same codebase  
✅ **Form Processing** - Handle form submissions server-side  
✅ **Security** - Keep sensitive logic and secrets on the server  
✅ **SEO** - Potential for future SSR implementation  
✅ **Single Deployment** - One deployment contains both frontend and backend  

## Documentation

- Server setup: `server/README.md`
- Deployment guide: `DEPLOYMENT.md`
- Infrastructure: `infrastructure/README.md`
