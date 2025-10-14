# Database Module

This module handles Azure SQL Database connectivity with support for both managed identity (Azure) and SQL authentication (local development).

## Files

- **`config.ts`** - Database connection configuration
- **`init.ts`** - Database schema initialization and sample data
- **`users.ts`** - User data access layer

## Authentication Methods

### Production (Azure)
When deployed to Azure App Service, the application uses **Azure Managed Identity** for authentication:
- No credentials stored in code or configuration
- Secure, automatic authentication using the Web App's system-assigned identity
- Token-based authentication with Azure Active Directory

### Local Development
For local development, use SQL authentication:
- Requires `SQL_USER` and `SQL_PASSWORD` environment variables
- Connects directly to Azure SQL Database or local SQL Server

## Environment Variables

Required for all environments:
- `SQL_SERVER` - SQL Server hostname (e.g., `myserver.database.windows.net`)
- `SQL_DATABASE` - Database name (e.g., `UsersDB`)

Additional for local development:
- `SQL_USER` - SQL authentication username
- `SQL_PASSWORD` - SQL authentication password

Auto-detected (set by Azure):
- `WEBSITE_INSTANCE_ID` - Indicates running in Azure App Service

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

- TLS encryption enabled for all connections
- Managed identity eliminates credential management in production
- Parameterized queries prevent SQL injection
- Connection strings never logged or exposed
