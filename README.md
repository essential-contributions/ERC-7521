# Galactus [Intent Based Account Abstraction]

<!-- Disable markdownlint for long lines. -->
<!-- markdownlint-disable-file MD013 -->

The Essential Solidity smart contract architecture.

## Build From Source

### Dependencies

| dep     | version                                                           |
| ------- | ----------------------------------------------------------------- |
| Foundry | [latest](https://book.getfoundry.sh/getting-started/installation) |
| Trunk   | [latest](https://docs.trunk.io/docs/install)                      |

### Building

Make sure submodules are up to date:

```sh
git submodule update --init --recursive
```

Build and run tests:

```sh
forge build
forge test
```

## License

The primary license for this repo is `Apache-2.0`, see [`LICENSE`](./LICENSE).
