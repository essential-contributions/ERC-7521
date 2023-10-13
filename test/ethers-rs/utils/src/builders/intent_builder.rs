use super::{
    asset_release_intent_standard::segment_builder::AssetReleaseIntentSegment,
    asset_require_intent_standard::segment_builder::AssetRequireIntentSegment,
    call_intent_standard::segment_builder::CallIntentSegment,
    eth_release_intent_standard::segment_builder::EthReleaseIntentSegment,
    eth_require_intent_standard::segment_builder::EthRequireIntentSegment,
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

    pub fn add_segment_asset_release(
        &mut self,
        standard_id: Bytes,
        segment: AssetReleaseIntentSegment,
    ) -> &mut Self {
        let encoded_segment = segment.clone().encode();

        self.intent_data.push(Bytes::from(encoded_segment));
        self.standards
            .push(standard_id.to_vec().try_into().unwrap());

        self
    }

    pub fn add_segment_eth_release(
        &mut self,
        standard_id: Bytes,
        segment: EthReleaseIntentSegment,
    ) -> &mut Self {
        let encoded_segment = segment.clone().encode();

        self.intent_data.push(Bytes::from(encoded_segment));
        self.standards
            .push(standard_id.to_vec().try_into().unwrap());

        self
    }

    pub fn add_segment_asset_require(
        &mut self,
        standard_id: Bytes,
        segment: AssetRequireIntentSegment,
    ) -> &mut Self {
        let encoded_segment = segment.clone().encode();

        self.intent_data.push(Bytes::from(encoded_segment));
        self.standards
            .push(standard_id.to_vec().try_into().unwrap());

        self
    }

    pub fn add_segment_eth_require(
        &mut self,
        standard_id: Bytes,
        segment: EthRequireIntentSegment,
    ) -> &mut Self {
        let encoded_segment = segment.clone().encode();

        self.intent_data.push(Bytes::from(encoded_segment));
        self.standards
            .push(standard_id.to_vec().try_into().unwrap());

        self
    }

    pub fn add_segment_call(
        &mut self,
        standard_id: Bytes,
        segment: CallIntentSegment,
    ) -> &mut Self {
        let encoded_segment = segment.clone().encode();

        self.intent_data.push(Bytes::from(encoded_segment));
        self.standards
            .push(standard_id.to_vec().try_into().unwrap());

        self
    }
}
