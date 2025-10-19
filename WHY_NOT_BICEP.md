# Why Can't Directory Readers Be Granted in Bicep?

## The Question

Since Bicep can create the SQL Server with a managed identity, why can't it also grant that identity the Directory Readers role in Azure AD?

## The Short Answer

**Bicep/ARM templates can only manage Azure Resource Manager (ARM) resources. Azure AD roles are NOT ARM resources** - they're managed through the Microsoft Graph API, which is a completely separate system.

## Understanding the Separation

Microsoft intentionally separates two types of management:

### 1. Azure Resource Management (ARM)

- **What it manages:** Azure resources (VMs, databases, storage, networks, etc.)
- **Tools:** Bicep, ARM templates, Azure CLI (`az` commands)
- **API:** Azure Resource Manager API
- **Permissions:** Subscription-level roles (Contributor, Owner, etc.)
- **Examples:**
  - Creating a SQL Server
  - Assigning a managed identity to a resource
  - Creating a storage account
  - Deploying a web app

### 2. Azure Active Directory Management (AAD/Entra ID)

- **What it manages:** Identities, users, groups, directory roles
- **Tools:** Azure Portal (AAD section), Azure CLI (`az ad` commands), Graph API
- **API:** Microsoft Graph API
- **Permissions:** Azure AD roles (Global Administrator, Directory Readers, etc.)
- **Examples:**
  - Creating users
  - Assigning directory roles
  - Managing groups
  - Granting API permissions

## What Bicep CAN Do

```bicep
// ✅ Create SQL Server with managed identity
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  identity: {
    type: 'SystemAssigned'  // Creates the identity in Azure AD
  }
  properties: {
    // ... SQL Server configuration
  }
}

// ✅ Output the principal ID
output sqlServerPrincipalId string = sqlServer.identity.principalId
```

**This works because:**

- The SQL Server resource is an ARM resource
- The managed identity **creation** is part of the ARM resource definition
- Bicep is just setting a property on an ARM resource

## What Bicep CANNOT Do

```bicep
// ❌ This is NOT possible in Bicep
resource directoryRoleAssignment 'Microsoft.Graph/directoryRoles/members' = {
  // This resource type doesn't exist in ARM!
  // Directory roles are not ARM resources
}

// ❌ This is also NOT possible
resource grantDirectoryReaders '???' = {
  // There is no ARM resource type for this
}
```

**This doesn't work because:**

- Directory role assignments are **not** ARM resources
- They're managed through the Microsoft Graph API
- Bicep only works with ARM resources
- Different permission model (Azure AD vs Azure RBAC)

## Why the Separation?

Microsoft separates these for important security reasons:

1. **Different Permission Models**

   - Azure subscription permissions ≠ Azure AD permissions
   - A Contributor on a subscription should NOT automatically have power over the entire directory
   - Directory changes affect the whole organization, not just one subscription

2. **Security Boundaries**

   - Prevents resource deployments from accidentally granting excessive directory permissions
   - Requires explicit Azure AD admin involvement for directory-level changes
   - Audit trail for directory changes is separate from resource changes

3. **Organizational Control**
   - Large organizations often have separate teams managing Azure subscriptions vs Azure AD
   - Security team controls directory roles
   - DevOps team controls resource deployments

## The Workaround: Script-Based Approach

Since Bicep can't do it, we use scripts:

### Step 1: Bicep Creates the Identity

```bicep
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  identity: {
    type: 'SystemAssigned'
  }
}
```

### Step 2: Script Grants Directory Role

```bash
# Get the principal ID that Bicep created
SQL_PRINCIPAL_ID=$(az sql server show --query identity.principalId -o tsv)

# Use Microsoft Graph API to grant Directory Readers role
az rest --method POST \
  --uri "https://graph.microsoft.com/v1.0/directoryRoles/${ROLE_ID}/members/\$ref" \
  --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/directoryObjects/${SQL_PRINCIPAL_ID}\"}"
```

**This works because:**

- We're using the Graph API directly
- We have the appropriate Azure AD permissions
- We're calling a different API than ARM

## Integration in GitHub Actions

In the workflow, we:

1. **Bicep deployment** creates SQL Server with managed identity
2. **Post-deployment script** grants Directory Readers role (if permissions allow)
3. **Fallback** provides instructions if the service principal lacks permissions

```yaml
- name: Deploy Azure Infrastructure
  uses: azure/arm-deploy@v2
  # Creates SQL Server with managed identity

- name: Grant Directory Readers Role
  run: ./scripts/grant-sql-directory-reader.sh
  # Uses Graph API to grant the role
  # May fail if service principal lacks permissions
```

## Could Microsoft Change This?

Theoretically, yes. Microsoft could:

1. Create ARM resource types for directory role assignments
2. Extend Bicep to call Graph API directly
3. Provide a hybrid deployment model

However, this would:

- Blur security boundaries
- Complicate the permission model
- Potentially create security risks
- Go against their design philosophy

**It's unlikely to change** because the separation is intentional and security-focused.

## Best Practices

### For Service Principals Used in CI/CD

Grant the service principal:

- **Contributor** role on the subscription (for resource management)
- **Directory Readers** role in Azure AD (to grant roles to other managed identities)

This allows fully automated deployments while maintaining security boundaries.

### For Manual Deployments

1. Infrastructure team deploys with Bicep (Contributor access)
2. Security team runs role assignment script (Global Admin access)
3. Clear separation of concerns

## Summary

| Aspect            | Bicep/ARM               | Directory Roles                     |
| ----------------- | ----------------------- | ----------------------------------- |
| **API**           | Azure Resource Manager  | Microsoft Graph                     |
| **Permissions**   | Subscription roles      | Azure AD roles                      |
| **Resources**     | VMs, DBs, Storage, etc. | Users, Groups, Roles                |
| **Tool**          | Bicep, ARM templates    | Scripts, Graph API                  |
| **Can automate?** | ✅ Yes                  | ⚠️ Only with proper AAD permissions |

**The bottom line:** This is not a limitation of Bicep - it's an intentional architectural decision by Microsoft to separate resource management from identity/directory management for security and organizational control.

## References

- [Azure Resource Manager Overview](https://learn.microsoft.com/azure/azure-resource-manager/management/overview)
- [Microsoft Graph API](https://learn.microsoft.com/graph/overview)
- [Azure RBAC vs Azure AD Roles](https://learn.microsoft.com/azure/role-based-access-control/rbac-and-directory-admin-roles)
- [Managed Identities for Azure Resources](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)
