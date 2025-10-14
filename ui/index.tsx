import React from 'react';
import ReactDOM from 'react-dom/client';
import { Router, Routes, Route, Link, Form, useParams, useNavigate, useLocation } from '../src/index';

// Example components
function Home() {
  const navigate = useNavigate();
  
  return (
    <div>
      <h1>Home Page</h1>
      <p>Welcome to the Simple React Router example!</p>
      <button onClick={() => navigate('/about')}>Go to About</button>
    </div>
  );
}

function About() {
  const location = useLocation();
  
  return (
    <div>
      <h1>About Page</h1>
      <p>Current path: {location.pathname}</p>
      <p>This is a simple React router implementation with server-side actions.</p>
    </div>
  );
}

function UserProfile() {
  const { userId } = useParams<{ userId: string }>();
  
  return (
    <div>
      <h1>User Profile</h1>
      <p>User ID: <strong>{userId}</strong></p>
      <p>This demonstrates dynamic route parameters.</p>
    </div>
  );
}

function CreateUser() {
  async function handleCreateUser(formData: FormData) {
    const name = formData.get('name') as string;
    const email = formData.get('email') as string;
    
    // Simulate API call
    console.log('Creating user:', { name, email });
    alert(`User created: ${name} (${email})`);
  }
  
  return (
    <div>
      <h1>Create User</h1>
      <p>This form demonstrates server-side actions.</p>
      <Form action={handleCreateUser}>
        <input name="name" placeholder="Name" required />
        <input name="email" type="email" placeholder="Email" required />
        <button type="submit">Create User</button>
      </Form>
    </div>
  );
}

// Main App
function App() {
  return (
    <Router>
      <nav>
        <Link to="/">Home</Link>
        <Link to="/about">About</Link>
        <Link to="/users/123">User 123</Link>
        <Link to="/create-user">Create User</Link>
      </nav>
      
      <main>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/about" element={<About />} />
          <Route path="/users/:userId" element={<UserProfile />} />
          <Route path="/create-user" element={<CreateUser />} />
        </Routes>
      </main>
    </Router>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root')!);
root.render(<App />);
