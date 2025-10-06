import { RouteMatch } from './types';

/**
 * Matches a pathname against a route path pattern
 * Supports dynamic segments like /users/:id
 */
export function matchPath(pattern: string, pathname: string): RouteMatch | null {
  // Normalize paths - remove trailing slashes except for root
  const normalizedPattern = pattern === '/' ? pattern : pattern.replace(/\/$/, '');
  const normalizedPathname = pathname === '/' ? pathname : pathname.replace(/\/$/, '');

  // Convert pattern to regex
  const paramNames: string[] = [];
  const regexPattern = normalizedPattern
    .replace(/:[^/]+/g, (match) => {
      paramNames.push(match.slice(1)); // Remove the ':' prefix
      return '([^/]+)';
    })
    .replace(/\//g, '\\/');

  const regex = new RegExp(`^${regexPattern}$`);
  const match = normalizedPathname.match(regex);

  if (!match) {
    return null;
  }

  const params: Record<string, string> = {};
  paramNames.forEach((name, index) => {
    params[name] = match[index + 1];
  });

  return {
    path: normalizedPattern,
    params,
  };
}
