# Generalized Intents for Smart Contract Wallets

<!-- Disable markdownlint for long lines. -->
<!-- markdownlint-disable-file MD013 -->

A generalized intent specification for smart contract wallets, allowing authorization of current and future intent standards at sign time.

## Specification

View the spec here: [ERC-7521](https://github.com/essential-contributions/EIPs/blob/master/EIPS/eip-7521.md).

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

Build and run hardhat scenario tests and benchmarking:

```sh
npx hardhat compile
npx hardhat test
```

## Contributing

Code must pass tests and coverage requirements as well as follow formatting requirements.

```sh
forge test
forge coverage
npx hardhat test
```

```sh
trunk fmt
```

## License

The primary license for this repo is `Apache-2.0`, see [`LICENSE`](./LICENSE).
