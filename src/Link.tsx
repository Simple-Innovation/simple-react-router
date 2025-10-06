import React from 'react';
import { useRouterContext } from './RouterContext';
import { NavigateOptions } from './types';

interface LinkProps extends Omit<React.AnchorHTMLAttributes<HTMLAnchorElement>, 'href'> {
  to: string;
  replace?: boolean;
  state?: any;
}

export function Link({ to, replace, state, onClick, ...props }: LinkProps) {
  const { navigate } = useRouterContext();

  const handleClick = (event: React.MouseEvent<HTMLAnchorElement>) => {
    // Don't interfere with modified clicks
    if (
      event.button !== 0 || // not left click
      event.metaKey ||
      event.altKey ||
      event.ctrlKey ||
      event.shiftKey
    ) {
      return;
    }

    event.preventDefault();

    if (onClick) {
      onClick(event);
    }

    const options: NavigateOptions = { replace, state };
    navigate(to, options);
  };

  return <a {...props} href={to} onClick={handleClick} />;
}
