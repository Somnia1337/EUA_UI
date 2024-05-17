use tokio_with_wasm::tokio;

mod messages;
mod user;

rinf::write_interface!();

async fn main() {
    tokio::spawn(user::main_logic());
}
