use super::client::WrappedClient;
use crate::abigen::SolverUtils;
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
}
