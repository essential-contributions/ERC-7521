use super::client::WrappedClient;
use crate::abigen::entry_point::IntentSolution;
use crate::abigen::EntryPoint;
use ethers::abi::AbiDecode;
use ethers::prelude::*;
use eyre::Result;
use k256::ecdsa::SigningKey;

pub struct EntryPointContract {
    pub contract: EntryPoint<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl EntryPointContract {
    pub async fn deploy(wrapped_client: &WrappedClient) -> Self {
        Self {
            contract: EntryPoint::deploy(wrapped_client.client.clone(), ())
                .unwrap()
                .send()
                .await
                .unwrap(),
        }
    }

    pub async fn register_intent_standard(&self, standard_address: Address) -> Result<Bytes> {
        let tx = self
            .contract
            .method::<Address, [u8; 32]>("registerIntentStandard", standard_address)
            .unwrap();
        let to_return = tx.clone().call().await.unwrap();

        match tx.clone().send().await {
            Ok(pending_tx) => match pending_tx.await {
                Ok(_) => Ok(to_return.into()),
                Err(e) => {
                    panic!("{}", e);
                }
            },
            Err(e) => {
                if let Some(decoded_error) = e.decode_revert::<String>() {
                    panic!("{}", decoded_error);
                } else {
                    panic!("{}", e);
                }
            }
        }
    }

    pub async fn get_intent_standard_id(&self, standard_address: Address) -> Result<Bytes> {
        let tx = self.contract.get_intent_standard_id(standard_address);
        match tx.call().await {
            Ok(t) => Result::Ok(Bytes::from(t)),
            Err(e) => {
                if let Some(decoded_error) = e.decode_revert::<String>() {
                    panic!("{}", decoded_error);
                } else {
                    panic!("{}", e);
                }
            }
        }
    }

    pub async fn handle_intents(&self, solution: IntentSolution) -> Result<()> {
        let handle_intents_call = crate::abigen::HandleIntentsCall { solution };

        let tx = self
            .contract
            .method::<_, ()>("handleIntents", handle_intents_call)
            .unwrap();

        let to_return_unwrapped = tx.clone().call().await;
        let value;
        match to_return_unwrapped {
            Ok(t) => {
                value = t;
            }
            Err(e) => match e.as_revert() {
                Some(revert) => {
                    if let Ok(decoded_error) =
                        <crate::abigen::EntryPointErrors as AbiDecode>::decode(revert.as_ref())
                    {
                        panic!("{}", decoded_error);
                    } else {
                        panic!("{}", e);
                    }
                }
                None => {
                    panic!("{}", e);
                }
            },
        };

        match tx.clone().send().await {
            Ok(pending_tx) => match pending_tx.await {
                Ok(_) => Ok(value.into()),
                Err(e) => {
                    panic!("{}", e);
                }
            },
            Err(e) => {
                if let Some(decoded_error) = e.decode_revert::<String>() {
                    panic!("{}", decoded_error);
                } else {
                    panic!("{}", e);
                }
            }
        }
    }
}
