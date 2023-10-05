# Shipit Browser Extension

If you have ever pushed to a broken `main` because you forgot to check CI/Slack then we have the extension for you.

This extension will alert you on GitHub's pull request page if `main` is broken, so that you can avoid the embarassment of having merged on red master.

## Installation

### Compiling

Run `bin/build` passing in the host of your shipit instance and your github organization:

```bash
$ ./bin/build shipit.example.com your-org-here
```

This will create the `builds` directory and populate it with the built extension for Chrome and Safari, which you can then upload to their respective web stores.


## Want to make changes to Shipit Extension?

After running `bin/build` to compile your extension:
1. Unzip `builds/hctw-chrome.zip`
2. Go to `chrome://extensions`, enable Developer Mode, and select Load unpacked
extension.
3. Edit `*.js` inside the unzipped extension with your changes.
4. CMD+R on `chrome://extensions` to reload the extension.
5. CMD+R on your GitHub page so the new scripts get included.
