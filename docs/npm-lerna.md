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
Shipit understands `lerna.json` files (up to version `3.22.x`), and will publish all packages in a Lerna project to npm.

### From Git

In addition to the `semver` keyword supported by [`lerna version`](https://github.com/lerna/lerna/tree/main/commands/version#positionals), [`lerna publish`](https://github.com/lerna/lerna/tree/main/commands/publish) also supports the `from-git` keyword. This will identify packages tagged by `lerna version` and publish them to npm. This is useful in CI scenarios where you wish to manually increment versions, but have the package contents themselves consistently published by an automated process.

In order to use this feature with `shipit-engine`, you will need to add the following to your `shipit.yml`:

#### Usage
```
machine:
  environment:
    SHIPIT_LERNA_PUBLISH_FROM_GIT: true
```

### From Packages (Default)

Similar to the from-git keyword except the list of packages to publish is determined by inspecting each package.json and determining if any package version is not present in the registry. Any versions not present in the registry will be published. This is useful when a previous lerna publish failed to publish all packages to the registry.

### Pre-releases

Lerna will add a suffix to pre-release versions with the `preid` CLI argument.

```
lerna publish --cd-version prerelease --preid beta
```

will produce a version number like `1.0.0-beta.1`.
