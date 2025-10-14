# Database Module

This module handles Azure SQL Database connectivity using **Azure Managed Identity only** for enhanced security.

## Files

- **`config.ts`** - Database connection configuration
- **`init.ts`** - Database schema initialization and sample data
- **`users.ts`** - User data access layer

## Authentication Method

The application uses **Azure Managed Identity** exclusively for authentication:
- No credentials stored in code or configuration
- Secure, automatic authentication using the Web App's system-assigned identity
- Token-based authentication with Azure Active Directory
- SQL authentication is NOT supported for security compliance

## Environment Variables

Required:
- `SQL_SERVER` - SQL Server hostname (e.g., `myserver.database.windows.net`)
- `SQL_DATABASE` - Database name (e.g., `UsersDB`)

## Local Development

For local development, you must use Azure Managed Identity authentication by running the application with Azure credentials:

1. Install Azure CLI and login: `az login`
2. The `DefaultAzureCredential` will automatically use your Azure CLI credentials
3. Ensure your Azure account has been granted access to the SQL Database (see DATABASE_SETUP.md)

## Database Schema

### Users Table

```sql
CREATE TABLE Users (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Name NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) NOT NULL UNIQUE,
    CreatedAt DATETIME2 DEFAULT GETDATE()
)
```

## Usage

### Get all users
```typescript
import { getAllUsers } from './db/users.js';

const users = await getAllUsers();
```

### Get user by ID
```typescript
import { getUserById } from './db/users.js';

const user = await getUserById(123);
```

### Create user
```typescript
import { createUser } from './db/users.js';

const newUser = await createUser('John Doe', 'john@example.com');
```

## Connection Pooling

The module uses connection pooling for efficient database access:
- A single connection pool is created on first use
- The pool is reused for all subsequent queries
- Automatic reconnection on connection loss

## Error Handling

All functions throw errors on failure. Implement proper try-catch blocks:

```typescript
try {
    const users = await getAllUsers();
} catch (error) {
    console.error('Failed to fetch users:', error);
    // Handle error appropriately
}
```

## Sample Data

On first initialization, the database is populated with sample users:
- John Doe (john.doe@example.com)
- Jane Smith (jane.smith@example.com)
- Bob Johnson (bob.johnson@example.com)
- Alice Williams (alice.williams@example.com)
- Charlie Brown (charlie.brown@example.com)

## Security

- **Managed Identity only** - SQL authentication is disabled for security compliance
- TLS encryption enabled for all connections
- No credentials stored in code, configuration, or environment variables
- Parameterized queries prevent SQL injection
- Connection strings never logged or exposed
- Token-based authentication with automatic rotation
