use test_utils::setup::setup;

#[tokio::test]
async fn can_setup() {
    setup().await.unwrap();
}
