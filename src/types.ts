export interface RouteMatch {
  path: string;
  params: Record<string, string>;
}

export interface Location {
  pathname: string;
  search: string;
  hash: string;
  state?: any;
}

export interface NavigateOptions {
  replace?: boolean;
  state?: any;
}

export interface RouteProps {
  path: string;
  element: React.ReactElement;
  action?: (data: FormData) => Promise<any> | any;
}

export interface RouterContextValue {
  location: Location;
  navigate: (to: string, options?: NavigateOptions) => void;
  params: Record<string, string>;
}
