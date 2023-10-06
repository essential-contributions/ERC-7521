use crate::{abigen::SolverUtils, deploy::TestContracts};
use ethers::{abi::Token, prelude::*};
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct SolverUtilsContract {
    pub contract: SolverUtils<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl SolverUtilsContract {
    pub async fn deploy(
        client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
        uniswap_address: Address,
        erc20_address: Address,
        wrapped_native_token_address: Address,
    ) -> Self {
        Self {
            contract: SolverUtils::deploy(
                client.clone(),
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

    pub fn swap_all_erc20_for_eth_calldata(
        &self,
        test_contracts: &TestContracts,
        solver_address: Address,
        min_eth: U256,
    ) -> Bytes {
        let method = self.contract.swap_all_erc20_for_eth(
            test_contracts.test_uniswap.contract.address(),
            test_contracts.test_erc20.contract.address(),
            test_contracts.test_wrapped_native_token.contract.address(),
            min_eth,
            solver_address,
        );

        method.calldata().unwrap()
    }

    pub fn swap_all_erc20_for_eth_and_forward_calldata(
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

    pub fn swap_all_erc20_for_eth_buy_nft_and_forward_calldata(
        &self,
        test_contracts: &TestContracts,
        user_address: Address,
        min_eth: U256,
        forward_amount: U256,
        nft_price: U256,
    ) -> Bytes {
        let method = self.contract.swap_all_erc20_for_eth_buy_nft_and_forward(
            test_contracts.test_uniswap.contract.address(),
            test_contracts.test_erc721.contract.address(),
            test_contracts.test_erc20.contract.address(),
            test_contracts.test_wrapped_native_token.contract.address(),
            min_eth,
            nft_price,
            forward_amount,
            user_address,
        );

        method.calldata().unwrap()
    }

    pub fn buy_erc721_calldata(
        &self,
        test_contracts: &TestContracts,
        price: U256,
        forward_to: Address,
    ) -> Bytes {
        let method = self.contract.buy_erc721(
            test_contracts.test_erc721.contract.address(),
            price,
            forward_to,
        );

        method.calldata().unwrap()
    }

    pub fn sell_erc721_and_forward_all_calldata(
        &self,
        test_contracts: &TestContracts,
        token_id: U256,
        to: Address,
    ) -> Bytes {
        let method = self.contract.sell_erc721_and_forward_all(
            test_contracts.test_erc721.contract.address(),
            token_id,
            to,
        );

        method.calldata().unwrap()
    }
}
