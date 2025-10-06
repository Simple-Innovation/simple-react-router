import React from 'react';
import { RouterContextValue } from './types';

export const RouterContext = React.createContext<RouterContextValue | null>(null);

export function useRouterContext(): RouterContextValue {
  const context = React.useContext(RouterContext);
  if (!context) {
    throw new Error('useRouterContext must be used within a Router');
  }
  return context;
}
