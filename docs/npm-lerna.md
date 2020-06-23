# npm and Lerna

## Publishing to npm

Shipit can be used to publish code to npm.
If your project has a `package.json`, and doesn’t have any other deploy method set up, Shipit will publish it to npm.

### Pre-releases

Shipit identifies pre-release versions (installable via `yarn add <package>@next`) by the following patterns:
`'-beta', '-alpha', '-rc', '-next'`.

Examples:

- `3.0.0-alpha.1`
- `1.2.3-beta.4`
- `2.3.4-rc.1`
- `3.5.6-next`
- `3.5.6-next.6`

If the version in `package.json` contains one of these patterns, Shipit will publish it to npm as a pre-release with the `next` dist-tag.

## Publishing using Lerna

[Lerna](https://github.com/lerna/lerna) is a tool for managing projects with multiple npm packages.
Shipit understands `lerna.json` files (up to version `2.9.x`), and will publish all packages in a Lerna project to npm.

### Pre-releases

Lerna will add a suffix to pre-release versions with the `preid` CLI argument.

```
lerna publish --cd-version prerelease --preid beta
```

will produce a version number like `1.0.0-beta.1`.
