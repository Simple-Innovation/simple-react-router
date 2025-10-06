import React, { useState, useEffect, useMemo } from 'react';
import { RouterContext } from './RouterContext';
import { Location, NavigateOptions } from './types';

interface RouterProps {
  children: React.ReactNode;
}

function getLocation(): Location {
  return {
    pathname: window.location.pathname,
    search: window.location.search,
    hash: window.location.hash,
    state: window.history.state,
  };
}

export function Router({ children }: RouterProps) {
  const [location, setLocation] = useState<Location>(getLocation());

  useEffect(() => {
    const handlePopState = () => {
      setLocation(getLocation());
    };

    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, []);

  const navigate = (to: string, options?: NavigateOptions) => {
    const state = options?.state;
    if (options?.replace) {
      window.history.replaceState(state, '', to);
    } else {
      window.history.pushState(state, '', to);
    }
    setLocation(getLocation());
  };

  const contextValue = useMemo(
    () => ({
      location,
      navigate,
      params: {},
    }),
    [location]
  );

  return (
    <RouterContext.Provider value={contextValue}>
      {children}
    </RouterContext.Provider>
  );
}
