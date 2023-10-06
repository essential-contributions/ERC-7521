use super::segment_builder::AssetBasedIntentSegment;
use crate::abigen::entry_point::UserIntent;
use ethers::abi::AbiEncode;
use ethers::prelude::*;

impl UserIntent {
    pub fn create_asset_based(
        standard_id: Bytes,
        sender: Address,
        nonce: u128,
        timestamp: u128,
    ) -> Self {
        Self {
            standard: standard_id.to_vec().try_into().unwrap(),
            sender,
            nonce: U256::from(nonce),
            timestamp: U256::from(timestamp),
            intent_data: vec![],
            signature: Bytes::default(),
        }
    }

    pub fn add_segment_asset_based(&mut self, segment: AssetBasedIntentSegment) -> &mut Self {
        let encoded_prefix =
            U256::from(0x00000000000000000000000000000000000000000000000000000000000f4240).encode();
        let mut encoded_segment = segment.clone().encode();
        encoded_segment[0..32].copy_from_slice(&encoded_prefix[0..32]);

        self.intent_data.push(Bytes::from(encoded_segment));

        self
    }
}
