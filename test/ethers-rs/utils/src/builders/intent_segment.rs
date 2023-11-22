use crate::builders::standards::{
    call_intent_standard::CallIntentSegment,
    erc20_release_intent_standard::Erc20ReleaseIntentSegment,
    erc20_require_intent_standard::Erc20RequireIntentSegment,
    eth_release_intent_standard::EthReleaseIntentSegment,
    eth_require_intent_standard::EthRequireIntentSegment, sequential_nonce::SequentialNonceSegment,
    user_operation::UserOperationSegment,
};
use ethers::abi::AbiEncode;

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum IntentSegment {
    Call(CallIntentSegment),
    Erc20Release(Erc20ReleaseIntentSegment),
    EthRelease(EthReleaseIntentSegment),
    Erc20Require(Erc20RequireIntentSegment),
    EthRequire(EthRequireIntentSegment),
    SequentialNonce(SequentialNonceSegment),
    UserOperation(UserOperationSegment),
}

impl AbiEncode for IntentSegment {
    fn encode(self) -> Vec<u8> {
        match self {
            IntentSegment::Call(segment) => segment.encode(),
            IntentSegment::Erc20Release(segment) => segment.encode(),
            IntentSegment::EthRelease(segment) => segment.encode(),
            IntentSegment::Erc20Require(segment) => segment.encode(),
            IntentSegment::EthRequire(segment) => segment.encode(),
            IntentSegment::SequentialNonce(segment) => segment.encode(),
            IntentSegment::UserOperation(segment) => segment.encode(),
        }
    }
}
