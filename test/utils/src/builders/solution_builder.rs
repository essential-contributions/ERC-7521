use crate::abigen::entry_point::{IntentSolution, UserIntent};
use ethers::prelude::*;

impl IntentSolution {
    pub fn create(timestamp: U256, intents: Vec<UserIntent>, order: Vec<U256>) -> Self {
        Self {
            timestamp,
            intents,
            order,
        }
    }

    pub fn new(intent1: UserIntent, intent2: UserIntent) -> Self {
        Self {
            timestamp: U256::from(0),
            intents: vec![intent1, intent2],
            order: vec![],
        }
    }
}
