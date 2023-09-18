use super::segment_builder::AssetBasedIntentSegment;
use crate::abigen::entry_point::UserIntent;
use ethers::{
    abi::{AbiDecode, AbiEncode},
    prelude::*,
};

impl UserIntent {
    pub fn create(standard_id: Bytes, sender: Address, nonce: u128, timestamp: u128) -> Self {
        Self {
            standard: standard_id.to_vec().try_into().unwrap(),
            sender: sender,
            nonce: U256::from(nonce),
            timestamp: U256::from(timestamp),
            intent_data: vec![],
            signature: Bytes::default(),
        }
    }

    pub fn add_segment(&mut self, segment: AssetBasedIntentSegment) -> &mut Self {
        let mut segments: Vec<AssetBasedIntentSegment> = self.decode_data();

        segments.push(segment);

        self.encode_data(segments)
    }

    pub fn encode_data(&mut self, segments: Vec<AssetBasedIntentSegment>) -> &mut Self {
        let data: Vec<Bytes> = segments
            .into_iter()
            .map(|segment| Bytes::from(AbiEncode::encode(segment)))
            .collect();

        self.intent_data = data;

        self
    }

    pub fn decode_data(&self) -> Vec<AssetBasedIntentSegment> {
        self.intent_data
            .clone()
            .into_iter()
            .map(|segment: Bytes| AbiDecode::decode(segment).unwrap())
            .collect()
    }
}
