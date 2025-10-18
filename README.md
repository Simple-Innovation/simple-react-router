# simple-react-router

A by the book react router implementation with server side actions.

## Installation

```bash
npm install simple-react-router
```

For instructions on deploying this demo to Azure (including installing the Azure CLI), see `DEPLOYMENT.md`.

## Features

- 🎯 Simple and intuitive API
- 🔄 Declarative routing
- 🪝 React Hooks support
- 📝 Server-side actions
- 🎨 TypeScript support
- 📦 Lightweight with zero dependencies

## Basic Usage

```tsx
import { Router, Routes, Route, Link } from "simple-react-router";

function App() {
  return (
    <Router>
      <nav>
        <Link to="/">Home</Link>
        <Link to="/about">About</Link>
      </nav>

      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/about" element={<About />} />
      </Routes>
    </Router>
  );
}
```

## API Reference

### Components

#### `<Router>`

The root component that provides routing context to your application.

```tsx
<Router>{/* Your app content */}</Router>
```

#### `<Routes>`

Container for `<Route>` components. Only renders the first matching route.

```tsx
<Routes>
  <Route path="/" element={<Home />} />
  <Route path="/about" element={<About />} />
</Routes>
```

#### `<Route>`

Defines a route with a path and element to render.

```tsx
<Route path="/users/:id" element={<UserProfile />} />
```

**Props:**

- `path` (string): The URL path pattern to match
- `element` (ReactElement): The component to render when the route matches
- `action` (optional): Server-side action handler for form submissions

#### `<Link>`

Navigation component that renders an accessible anchor tag.

```tsx
<Link to="/about" replace={false} state={{ from: "home" }}>
  About
</Link>
```

**Props:**

- `to` (string): Destination path
- `replace` (boolean): Replace current history entry instead of pushing
- `state` (any): State to pass with navigation
- All standard anchor tag attributes

#### `<Form>`

Form component with support for server-side actions.

```tsx
<Form
  action={async (formData) => {
    const name = formData.get("name");
    await saveUser(name);
  }}
>
  <input name="name" />
  <button type="submit">Submit</button>
</Form>
```

**Props:**

- `action` (function): Server-side action handler that receives FormData
- All standard form attributes

### Hooks

#### `useNavigate()`

Returns a function to navigate programmatically.

```tsx
import { useNavigate } from "simple-react-router";

function MyComponent() {
  const navigate = useNavigate();

  const handleClick = () => {
    navigate("/dashboard", { replace: true, state: { from: "home" } });
  };

  return <button onClick={handleClick}>Go to Dashboard</button>;
}
```

#### `useLocation()`

Returns the current location object.

```tsx
import { useLocation } from "simple-react-router";

function MyComponent() {
  const location = useLocation();

  return (
    <div>
      <p>Current path: {location.pathname}</p>
      <p>Search: {location.search}</p>
      <p>Hash: {location.hash}</p>
    </div>
  );
}
```

#### `useParams()`

Returns the route parameters for the current route.

```tsx
import { useParams } from "simple-react-router";

function UserProfile() {
  const { id } = useParams<{ id: string }>();

  return <div>User ID: {id}</div>;
}
```

## Dynamic Routes

Routes support dynamic segments using the `:param` syntax:

```tsx
<Routes>
  <Route path="/users/:userId" element={<UserProfile />} />
  <Route path="/posts/:postId/comments/:commentId" element={<Comment />} />
</Routes>
```

Access parameters using the `useParams()` hook:

```tsx
function UserProfile() {
  const { userId } = useParams();
  // userId will be the value from the URL
}
```

## Server-Side Actions

Forms can include server-side actions that run when submitted:

```tsx
async function createUser(formData: FormData) {
  const name = formData.get("name") as string;
  const email = formData.get("email") as string;

  // Call your API
  const response = await fetch("/api/users", {
    method: "POST",
    body: JSON.stringify({ name, email }),
  });

  return response.json();
}

function CreateUser() {
  return (
    <Form action={createUser}>
      <input name="name" placeholder="Name" />
      <input name="email" type="email" placeholder="Email" />
      <button type="submit">Create User</button>
    </Form>
  );
}
```

## TypeScript Support

The library is written in TypeScript and provides full type definitions:

```tsx
import { useParams, Location, NavigateOptions } from "simple-react-router";

// Type-safe params
function UserProfile() {
  const params = useParams<{ id: string; tab: string }>();
  // params.id and params.tab are typed as string
}
```

## Local Development

To run the example application locally:

1. Clone the repository
2. Install dependencies:

   ```bash
   npm install
   ```

3. Start the development server:

   ```bash
   npm run dev
   ```

4. Open your browser to `http://localhost:3000`

The development server will hot-reload as you make changes to the source code in the `src/` directory.

### Azure Development Debugging

If you need to debug Azure deployment issues or test infrastructure changes locally, you can log into Azure using the service principal credentials:

```bash
./scripts/connect-azure-deployment-account.sh
```

This script:

- Reads credentials from `azure-credentials.json`
- Logs in to Azure using the service principal
- Sets the default subscription
- Displays connection confirmation

**Prerequisites:**

- Azure CLI installed (`az`)
- Valid `azure-credentials.json` file in the project root
- Either `jq` or Python 3 for JSON parsing

After running this script, you can use Azure CLI commands to inspect resources, test Bicep deployments, or debug configuration issues.

#### Configure Managed Identity Database Access

To manually configure or troubleshoot managed identity access to the SQL Database:

```bash
./scripts/configure-managed-identity.sh \
  <resource-group> \
  <sql-server> \
  <database-name> \
  <web-app-name> \
  <sql-admin-login> \
  <sql-admin-password>
```

**Example:**

```bash
./scripts/configure-managed-identity.sh \
  simple-react-router-rg \
  server \
  UsersDB \
  simple-react-router-web \
  sqladmin \
  "MySecurePassword123!"
```

This script:

- Retrieves the Web App's system-assigned managed identity
- Creates a database user for the managed identity
- Grants necessary permissions (db_datareader, db_datawriter, db_ddladmin)
- Verifies the user was created successfully

**Prerequisites:**

- Azure CLI logged in (use `connect-azure-deployment-account.sh` first)
- Python 3 with `pyodbc` (automatically installed if missing)
- ODBC Driver 18 for SQL Server
- Azure AD administrator configured on SQL Server
- Web App must have system-assigned managed identity enabled

**Use cases:**

- Debugging database connection issues
- Manually granting permissions after infrastructure changes
- Testing managed identity authentication locally
- Troubleshooting Azure AD authentication problems

## Deployment

### Azure Web App Deployment

This repository includes a GitHub Actions workflow for automatic deployment to Azure Web App. The workflow uses **Bicep** (Infrastructure as Code) to automatically provision Azure resources.

**Features:**

- Automatic infrastructure provisioning using Bicep
- Build, test, and deployment automation
- Node.js 22 LTS on Linux
- Secure service principal authentication

#### Quick Setup

1. **Create Azure Service Principal**:

   ```bash
   az ad sp create-for-rbac --name "simple-react-router-deploy" \
     --role contributor --scopes /subscriptions/{subscription-id} --sdk-auth
   ```

2. **Configure GitHub Secrets and Variables**:

   Required:

   - `AZURE_CREDENTIALS` (secret): Full JSON output from step 1
   - `SQL_ADMIN_PASSWORD` (secret): A secure password for SQL Server admin
   - `AZURE_SUBSCRIPTION_ID` (repository Variable): Your Azure subscription ID

   Optional:

   - `AZURE_WEBAPP_NAME` (repository Variable) — defaults to `simple-react-router-web`
   - `AZURE_RESOURCE_GROUP_NAME` (repository Variable) — defaults to `simple-react-router-rg`
   - `SQL_AZUREAD_ADMIN_USER` (repository Variable) — Azure AD admin user email (if you want a specific admin instead of auto-detection)
   - `SQL_AZUREAD_ADMIN_OBJECT_ID` (repository Variable) — Object ID of the Azure AD admin user (must be provided with SQL_AZUREAD_ADMIN_USER)

   Note: If `SQL_AZUREAD_ADMIN_USER` and `SQL_AZUREAD_ADMIN_OBJECT_ID` are not provided, the workflow will automatically use the current logged-in user (service principal) as the Azure AD administrator.

3. **Deploy**:

   - Push to `main` branch or manually trigger the workflow
   - Infrastructure and application will be deployed automatically

For detailed setup instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## License

MIT
