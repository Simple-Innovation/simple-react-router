import { matchPath } from './matchPath';

describe('matchPath', () => {
  it('matches exact paths', () => {
    const result = matchPath('/', '/');
    expect(result).toEqual({
      path: '/',
      params: {},
    });
  });

  it('matches static paths', () => {
    const result = matchPath('/about', '/about');
    expect(result).toEqual({
      path: '/about',
      params: {},
    });
  });

  it('returns null for non-matching paths', () => {
    const result = matchPath('/about', '/contact');
    expect(result).toBeNull();
  });

  it('matches paths with parameters', () => {
    const result = matchPath('/users/:id', '/users/123');
    expect(result).toEqual({
      path: '/users/:id',
      params: { id: '123' },
    });
  });

  it('matches paths with multiple parameters', () => {
    const result = matchPath('/users/:userId/posts/:postId', '/users/123/posts/456');
    expect(result).toEqual({
      path: '/users/:userId/posts/:postId',
      params: { userId: '123', postId: '456' },
    });
  });

  it('handles trailing slashes', () => {
    const result1 = matchPath('/about/', '/about');
    expect(result1).toEqual({
      path: '/about',
      params: {},
    });

    const result2 = matchPath('/about', '/about/');
    expect(result2).toEqual({
      path: '/about',
      params: {},
    });
  });

  it('does not match partial paths', () => {
    const result = matchPath('/about', '/about/more');
    expect(result).toBeNull();
  });
});
