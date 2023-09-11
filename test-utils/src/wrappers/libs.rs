use super::abigen::IntentSolutionLib;
use ethers::prelude::*;
use k256::ecdsa::SigningKey;

pub struct IntentSolutionLibContract {
    pub contract: IntentSolutionLib<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
}
