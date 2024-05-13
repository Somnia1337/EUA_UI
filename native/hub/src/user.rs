use crate::messages::{self, user::UserProto};

use std::error::Error;

use imap::{self, Connection, Session};
use lettre::{
    message::{header::ContentType, Mailbox},
    transport::smtp::authentication::Credentials,
    Address, Message, SmtpTransport, Transport,
};

struct User {
    pub smtp_domain: String,
    pub imap_domain: String,
    pub email_addr: Address,
    password: String,
}

impl User {
    pub fn build(user_proto: UserProto) -> Option<User> {
        let email: Address = match user_proto.email_addr.trim().parse().ok() {
            Some(e) => e,
            None => return None,
        };
        let password = user_proto.password;
        let domain = email.domain();

        Some(User {
            smtp_domain: format!("smtp.{}", domain),
            imap_domain: format!("imap.{}", domain),
            email_addr: email,
            password,
        })
    }
}

pub async fn login() {
    use messages::user::*;

    let mut receiver = UserProto::get_dart_signal_receiver();
    while let Some(dart_signal) = receiver.recv().await {
        let user_proto = dart_signal.message;
        let user = match User::build(user_proto) {
            Some(u) => u,
            None => {
                RustResult {
                    result: false,
                    info: "Unknown error".to_string(),
                }
                .send_signal_to_dart();
                return;
            }
        };
        match connect_smtp(&user) {
            Ok(_) => RustResult {
                result: true,
                info: String::new(),
            }
            .send_signal_to_dart(),
            Err(e) => RustResult {
                result: false,
                info: e.to_string(),
            }
            .send_signal_to_dart(),
        }
    }
}

fn connect_smtp(user: &User) -> Result<SmtpTransport, Box<dyn Error>> {
    // Open a remote connection to server
    let smtp_cli = SmtpTransport::relay(user.smtp_domain.as_str())
        .unwrap()
        .credentials(Credentials::new(
            user.email_addr.to_string(),
            user.password.to_string(),
        ))
        .build();

    // Connectivity test & return
    match smtp_cli.test_connection() {
        Ok(_) => Ok(smtp_cli),
        Err(e) => Err(Box::new(e)),
    }
}
