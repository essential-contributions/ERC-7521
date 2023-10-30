use crate::abigen::{entry_point::IntentSolution, EntryPoint};
use ethers::{abi::AbiDecode, prelude::*};
use eyre::Result;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct EntryPointContract {
    pub contract: EntryPoint<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}

impl EntryPointContract {
    pub async fn deploy(client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>) -> Self {
        Self {
            contract: EntryPoint::deploy(client.clone(), ())
                .unwrap()
                .send()
                .await
                .unwrap(),
        }
    }

    pub async fn register_intent_standard(&self, standard_address: Address) -> Result<[u8; 32]> {
        let tx = self.contract.register_intent_standard(standard_address);
        let standard_id = tx.clone().call().await.unwrap();

        match tx.clone().send().await {
            Ok(_) => Ok(standard_id),
            Err(e) => {
                panic!("{}", e);
            }
        }
    }

    pub async fn get_intent_standard_id(&self, standard_address: Address) -> Result<[u8; 32]> {
        let tx = self.contract.get_intent_standard_id(standard_address);

        match tx.call().await {
            Ok(t) => Result::Ok(t),
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
        let tx = self.contract.handle_intents(solution);

        match tx.clone().send().await {
            Ok(pending_tx) => {
                let receipt = pending_tx.await.unwrap().unwrap();
                dbg!("gas used: {:?}", receipt.gas_used.unwrap());
                Ok(())
            }
            Err(e) => {
                if let Some(decoded_error) = e.decode_revert::<String>() {
                    panic!("{}", decoded_error);
                } else {
                    match e.as_revert() {
                        Some(revert) => {
                            if let Ok(decoded_error) =
                                <crate::abigen::EntryPointErrors as AbiDecode>::decode(revert)
                            {
                                match decoded_error {
                                    crate::abigen::EntryPointErrors::ExecutionResult(_e) => {
                                        panic!("ExecutionResult({})", e);
                                    }
                                    crate::abigen::EntryPointErrors::FailedIntent(e) => {
                                        panic!("FailedIntent({})", e);
                                    }
                                    crate::abigen::EntryPointErrors::ValidationResult(e) => {
                                        panic!("ValidationResult({})", e);
                                    }
                                    crate::abigen::EntryPointErrors::RevertString(e) => {
                                        panic!("RevertString({})", e);
                                    }
                                }
                            } else {
                                panic!("{}", revert);
                            }
                        }
                        None => {
                            panic!("{}", e);
                        }
                    }
                }
            }
        }
    }

    pub async fn handle_multi_solution_intents(&self, multi_solutions: Vec<IntentSolution>) -> Result<()> {
        let tx = self.contract.handle_multi_solution_intents(multi_solutions);

        match tx.clone().send().await {
            Ok(pending_tx) => {
                let receipt = pending_tx.await.unwrap().unwrap();
                dbg!("gas used: {:?}", receipt.gas_used.unwrap());
                Ok(())
            }
            Err(e) => {
                if let Some(decoded_error) = e.decode_revert::<String>() {
                    panic!("{}", decoded_error);
                } else {
                    match e.as_revert() {
                        Some(revert) => {
                            if let Ok(decoded_error) =
                                <crate::abigen::EntryPointErrors as AbiDecode>::decode(revert)
                            {
                                match decoded_error {
                                    crate::abigen::EntryPointErrors::ExecutionResult(_e) => {
                                        panic!("ExecutionResult({})", e);
                                    }
                                    crate::abigen::EntryPointErrors::FailedIntent(e) => {
                                        panic!("FailedIntent({})", e);
                                    }
                                    crate::abigen::EntryPointErrors::ValidationResult(e) => {
                                        panic!("ValidationResult({})", e);
                                    }
                                    crate::abigen::EntryPointErrors::RevertString(e) => {
                                        panic!("RevertString({})", e);
                                    }
                                }
                            } else {
                                panic!("{}", revert);
                            }
                        }
                        None => {
                            panic!("{}", e);
                        }
                    }
                }
            }
        }
    }

    pub async fn simulate_handle_intents(&self, solution: IntentSolution) -> Result<()> {
        let tx = self
            .contract
            .simulate_handle_intents(solution, Address::zero(), Bytes::default());

        match tx.clone().call().await {
            Ok(_) => {
                panic!("simulation should not return successfully");
            }
            Err(e) => {
                if let Some(decoded_error) = e.decode_revert::<String>() {
                    panic!("{}", decoded_error);
                } else {
                    match e.as_revert() {
                        Some(revert) => {
                            if let Ok(decoded_error) =
                                <crate::abigen::EntryPointErrors as AbiDecode>::decode(revert)
                            {
                                match decoded_error {
                                    crate::abigen::EntryPointErrors::ExecutionResult(_e) => Ok(()),
                                    crate::abigen::EntryPointErrors::FailedIntent(e) => {
                                        panic!("FailedIntent({})", e);
                                    }
                                    crate::abigen::EntryPointErrors::ValidationResult(e) => {
                                        panic!("ValidationResult({})", e);
                                    }
                                    crate::abigen::EntryPointErrors::RevertString(e) => {
                                        panic!("RevertString({})", e);
                                    }
                                }
                            } else {
                                panic!("{}", revert);
                            }
                        }
                        None => {
                            panic!("{}", e);
                        }
                    }
                }
            }
        }
    }
}
