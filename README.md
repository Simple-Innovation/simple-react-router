# simple-react-router

A by the book react router implementation with server side actions.

## Installation

```bash
npm install simple-react-router
```

## Features

- 🎯 Simple and intuitive API
- 🔄 Declarative routing
- 🪝 React Hooks support
- 📝 Server-side actions
- 🎨 TypeScript support
- 📦 Lightweight with zero dependencies

## Basic Usage

```tsx
import { Router, Routes, Route, Link } from 'simple-react-router';

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
<Router>
  {/* Your app content */}
</Router>
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
<Link to="/about" replace={false} state={{ from: 'home' }}>
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
<Form action={async (formData) => {
  const name = formData.get('name');
  await saveUser(name);
}}>
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
import { useNavigate } from 'simple-react-router';

function MyComponent() {
  const navigate = useNavigate();
  
  const handleClick = () => {
    navigate('/dashboard', { replace: true, state: { from: 'home' } });
  };
  
  return <button onClick={handleClick}>Go to Dashboard</button>;
}
```

#### `useLocation()`

Returns the current location object.

```tsx
import { useLocation } from 'simple-react-router';

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
import { useParams } from 'simple-react-router';

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
  const name = formData.get('name') as string;
  const email = formData.get('email') as string;
  
  // Call your API
  const response = await fetch('/api/users', {
    method: 'POST',
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
import { useParams, Location, NavigateOptions } from 'simple-react-router';

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

## Deployment

### Azure Web App Deployment

This repository includes a GitHub Actions workflow for automatic deployment to Azure Web App. The workflow is configured to:

1. Build and test the library
2. Build the demo application for production
3. Deploy to Azure Web App on every push to the `main` branch

#### Setup Instructions

1. **Create an Azure Web App**:
   - Go to [Azure Portal](https://portal.azure.com)
   - Create a new Web App (choose Node.js runtime)
   - Note down your app name

2. **Configure GitHub Secrets**:
   - In your Azure Web App, go to the "Overview" page
   - Click "Download publish profile" from the top menu
   - Copy the contents of the downloaded file
   - In your GitHub repository, go to Settings > Secrets and variables > Actions
   - Create a new repository secret named `AZURE_WEBAPP_PUBLISH_PROFILE`
   - Paste the publish profile contents as the value

3. **Update Workflow Configuration**:
   - Edit `.github/workflows/azure-webapps-deploy.yml`
   - Update the `AZURE_WEBAPP_NAME` environment variable with your Azure Web App name

4. **Deploy**:
   - Push to the `main` branch or manually trigger the workflow
   - The demo application will be automatically deployed to your Azure Web App

The workflow includes web.config for proper SPA routing support on Azure App Service.

## License

MIT
