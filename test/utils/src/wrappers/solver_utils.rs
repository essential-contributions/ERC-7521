use std::{ops::Add, sync::Arc};

use super::client::WrappedClient;
use crate::{abigen::SolverUtils, deploy::TestContracts};
use ethers::{
    abi::{AbiEncode, Function, Token},
    prelude::*,
    utils::parse_ether,
};
use eyre::Result;
use k256::{ecdsa::SigningKey, Secp256k1};

pub struct SolverUtilsContract {
    pub contract: SolverUtils<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl SolverUtilsContract {
    pub async fn deploy(
        wrapped_client: &WrappedClient,
        uniswap_address: Address,
        erc20_address: Address,
        wrapped_native_token_address: Address,
    ) -> Self {
        Self {
            contract: SolverUtils::deploy(
                wrapped_client.client.clone(),
                Token::Tuple(vec![
                    Token::Address(uniswap_address),
                    Token::Address(erc20_address),
                    Token::Address(wrapped_native_token_address),
                ]),
            )
            .unwrap()
            .send()
            .await
            .unwrap(),
        }
    }

    pub fn swap_all_erc20_for_eth_and_forward(&self, test_contracts: &TestContracts) -> Bytes {
        let method = self
            .contract
            .method::<(Address, Address, Address, U256, Address, U256, Address), ()>(
                "swapAllERC20ForETHAndForward",
                (
                    test_contracts.test_uniswap.contract.address(),
                    test_contracts.test_erc20.contract.address(),
                    test_contracts.test_wrapped_native_token.contract.address(),
                    parse_ether(1).unwrap(),
                    test_contracts.test_uniswap.contract.address(),
                    U256::from(0),
                    test_contracts.test_uniswap.contract.address(),
                ),
            )
            .unwrap();

        method.calldata().unwrap()
    }
}
