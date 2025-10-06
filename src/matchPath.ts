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
  
  // First, extract and replace parameter segments
  // Then escape all regex special characters in the remaining parts
  let regexPattern = normalizedPattern;
  
  // Replace param segments with placeholders temporarily
  const placeholders: string[] = [];
  regexPattern = regexPattern.replace(/:([^/]+)/g, (_, paramName) => {
    paramNames.push(paramName);
    const placeholder = `__PARAM_${placeholders.length}__`;
    placeholders.push(placeholder);
    return placeholder;
  });
  
  // Escape all regex special characters
  regexPattern = regexPattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  
  // Replace placeholders with capture groups
  placeholders.forEach((placeholder) => {
    regexPattern = regexPattern.replace(placeholder, '([^/]+)');
  });

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
