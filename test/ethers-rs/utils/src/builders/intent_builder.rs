use super::intent_segment::IntentSegment;
use crate::abigen::entry_point::UserIntent;
use ethers::{abi::AbiEncode, prelude::*};

impl UserIntent {
    pub fn create(sender: Address, timestamp: u128) -> Self {
        Self {
            sender,
            timestamp: U256::from(timestamp),
            intent_data: vec![],
            signature: Bytes::default(),
        }
    }

    pub fn add_segment(&mut self, segment: IntentSegment) -> &mut Self {
        self.intent_data.push(Bytes::from(segment.encode()));
        self
    }
}