use ethers::prelude::*;
use ethers::types::Address;
use utils::setup::setup;

#[tokio::test]
async fn can_setup() {
    let test_contracts = setup().await.unwrap();
}
