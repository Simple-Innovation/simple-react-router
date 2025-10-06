import { useRouterContext } from './RouterContext';
import { Location } from './types';

/**
 * Returns the current location object
 */
export function useLocation(): Location {
  const { location } = useRouterContext();
  return location;
}

/**
 * Returns a function to navigate programmatically
 */
export function useNavigate() {
  const { navigate } = useRouterContext();
  return navigate;
}

/**
 * Returns the route parameters for the current route
 */
export function useParams<T extends Record<string, string> = Record<string, string>>(): T {
  const { params } = useRouterContext();
  return params as T;
}
