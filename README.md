# Generalized Intent Specification for Account Abstraction

<!-- Disable markdownlint for long lines. -->
<!-- markdownlint-disable-file MD013 -->

A generalized intent specification entry point contract which enables support for a multitude of intent standards as they evolve over time.

## Specification

The full spec and EIP/ERC can be viewed [here](./proposal/EIPS/eip-8337.md).

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

## Contributing

Code must pass tests and coverage requirements as well as follow formatting requirements.

```sh
forge test
forge coverage
forge fmt
```

## License

The primary license for this repo is `Apache-2.0`, see [`LICENSE`](./LICENSE).
