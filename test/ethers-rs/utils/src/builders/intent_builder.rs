use super::{
    asset_based_intent_standard::segment_builder::AssetBasedIntentSegment,
    default_intent_standard::segment_builder::DefaultIntentSegment,
};
use crate::abigen::entry_point::UserIntent;
use ethers::{abi::AbiEncode, prelude::*};

impl UserIntent {
    pub fn create(sender: Address, nonce: u128, timestamp: u128) -> Self {
        Self {
            standards: vec![],
            sender,
            nonce: U256::from(nonce),
            timestamp: U256::from(timestamp),
            intent_data: vec![],
            signature: Bytes::default(),
        }
    }

    pub fn add_segment_asset_based(
        &mut self,
        standard_id: Bytes,
        segment: AssetBasedIntentSegment,
    ) -> &mut Self {
        let encoded_segment = segment.clone().encode();

        self.intent_data.push(Bytes::from(encoded_segment));
        self.standards
            .push(standard_id.to_vec().try_into().unwrap());

        self
    }

    pub fn add_segment_default(
        &mut self,
        standard_id: Bytes,
        segment: DefaultIntentSegment,
    ) -> &mut Self {
        let encoded_segment = segment.clone().encode();

        self.intent_data.push(Bytes::from(encoded_segment));
        self.standards
            .push(standard_id.to_vec().try_into().unwrap());

        self
    }
}
