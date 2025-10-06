import React from 'react';
import { useRouterContext } from './RouterContext';
import { matchPath } from './matchPath';
import { RouterContext } from './RouterContext';

interface RoutesProps {
  children: React.ReactNode;
}

export function Routes({ children }: RoutesProps) {
  const { location } = useRouterContext();
  const routes = React.Children.toArray(children);

  // Find the first matching route
  for (const route of routes) {
    if (React.isValidElement(route) && route.props.path) {
      const match = matchPath(route.props.path, location.pathname);
      if (match) {
        // Create a new context value with the matched params
        return (
          <RouterContext.Consumer>
            {(contextValue) => {
              if (!contextValue) return null;
              const newContextValue = {
                ...contextValue,
                params: match.params,
              };
              return (
                <RouterContext.Provider value={newContextValue}>
                  {route.props.element}
                </RouterContext.Provider>
              );
            }}
          </RouterContext.Consumer>
        );
      }
    }
  }

  // No matching route found
  return null;
}

interface RouteProps {
  path: string;
  element: React.ReactElement;
  action?: (data: FormData) => Promise<any> | any;
}

export function Route({ element }: RouteProps) {
  return element;
}
