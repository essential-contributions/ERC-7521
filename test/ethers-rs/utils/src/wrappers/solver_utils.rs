use super::client::WrappedClient;
use crate::{abigen::SolverUtils, deploy::TestContracts};
use ethers::{abi::Token, prelude::*};
use k256::ecdsa::SigningKey;

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

    pub fn swap_all_erc20_for_eth_and_forward(
        &self,
        test_contracts: &TestContracts,
        solver_address: Address,
        user_address: Address,
        min_eth: U256,
        forward_amount: U256,
    ) -> Bytes {
        let method = self.contract.swap_all_erc20_for_eth_and_forward(
            test_contracts.test_uniswap.contract.address(),
            test_contracts.test_erc20.contract.address(),
            test_contracts.test_wrapped_native_token.contract.address(),
            min_eth,
            solver_address,
            forward_amount,
            user_address,
        );

        method.calldata().unwrap()
    }
}
