use crate::abigen::entry_point::{IntentSolution, UserIntent};
use ethers::prelude::*;

impl IntentSolution {
    pub fn new(timestamp: U256, intents: Vec<UserIntent>, order: Vec<U256>) -> Self {
        Self {
            timestamp,
            intents,
            order,
        }
    }
}
