// A GitHub login, checked rather than trusted, in exactly one place.
//
// Every board on the Queen's page turns a login into an `href` and an
// `<img src>`. A page that builds a profile link out of an unchecked string can
// be pointed at somebody else's account by whoever writes that string, and that
// stays true when the string comes from our own server or our own file. This
// check used to live in four files; now they all ask this one.
//
// No imports on purpose: plain node runs it in the qa contracts.

const GITHUB_LOGIN = /^[a-zA-Z\d](?:[a-zA-Z\d]|-(?=[a-zA-Z\d])){0,38}$/

export const githubLogin = (s: unknown): string | null =>
  typeof s === 'string' && GITHUB_LOGIN.test(s) ? s : null
