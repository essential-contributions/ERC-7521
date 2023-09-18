use utils::setup::setup;

#[tokio::test]
async fn can_setup() {
    let _test_contracts = setup().await.unwrap();
}
