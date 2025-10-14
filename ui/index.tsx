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

function Users() {
  const [users, setUsers] = React.useState<any[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    async function fetchUsers() {
      try {
        const response = await fetch('/api/users');
        if (!response.ok) {
          throw new Error('Failed to fetch users');
        }
        const data = await response.json();
        setUsers(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'An error occurred');
      } finally {
        setLoading(false);
      }
    }

    fetchUsers();
  }, []);

  if (loading) {
    return (
      <div>
        <h1>Users</h1>
        <p>Loading users from database...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div>
        <h1>Users</h1>
        <p style={{ color: 'red' }}>Error: {error}</p>
      </div>
    );
  }

  return (
    <div>
      <h1>Users</h1>
      <p>All users from the Azure SQL Database:</p>
      {users.length === 0 ? (
        <p>No users found.</p>
      ) : (
        <table style={{ borderCollapse: 'collapse', width: '100%', marginTop: '20px' }}>
          <thead>
            <tr style={{ borderBottom: '2px solid #333' }}>
              <th style={{ padding: '10px', textAlign: 'left' }}>ID</th>
              <th style={{ padding: '10px', textAlign: 'left' }}>Name</th>
              <th style={{ padding: '10px', textAlign: 'left' }}>Email</th>
              <th style={{ padding: '10px', textAlign: 'left' }}>Created At</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user) => (
              <tr key={user.Id} style={{ borderBottom: '1px solid #ddd' }}>
                <td style={{ padding: '10px' }}>{user.Id}</td>
                <td style={{ padding: '10px' }}>{user.Name}</td>
                <td style={{ padding: '10px' }}>{user.Email}</td>
                <td style={{ padding: '10px' }}>
                  {new Date(user.CreatedAt).toLocaleString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

function CreateUser() {
  const navigate = useNavigate();
  
  async function handleCreateUser(formData: FormData) {
    const name = formData.get('name') as string;
    const email = formData.get('email') as string;
    
    // Call the /api/submit endpoint
    const response = await fetch('/api/submit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, email }),
    });
    
    const result = await response.json();
    
    if (result.success) {
      alert(`${result.message}\nUser: ${name} (${email})`);
      // Navigate to users list after successful creation
      navigate('/users');
    } else {
      alert('Failed to create user');
    }
  }
  
  return (
    <div>
      <h1>Create User</h1>
      <p>This form demonstrates server-side actions and saves to the database.</p>
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
        <Link to="/users">Users List</Link>
        <Link to="/create-user">Create User</Link>
      </nav>
      
      <main>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/about" element={<About />} />
          <Route path="/users" element={<Users />} />
          <Route path="/users/:userId" element={<UserProfile />} />
          <Route path="/create-user" element={<CreateUser />} />
        </Routes>
      </main>
    </Router>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root')!);
root.render(<App />);
