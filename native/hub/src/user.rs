use crate::messages::user::*;

use std::error::Error;

use lettre::{
    message::{header::ContentType, Mailbox},
    transport::smtp::authentication::Credentials,
    Address, Message, SmtpTransport, Transport,
};

pub async fn main_logic() {
    let mut user: Option<User> = None;
    let mut smtp_cli: Option<SmtpTransport> = None;

    let mut action_listener = Action::get_dart_signal_receiver();
    let mut user_proto_listener = UserProto::get_dart_signal_receiver();
    let mut email_proto_listener = EmailProto::get_dart_signal_receiver();

    while let Some(dart_signal) = action_listener.recv().await {
        match dart_signal.message.action {
            0 => {
                if let Some(user_proto) = user_proto_listener.recv().await {
                    if let Some(new_user) = User::build(user_proto.message) {
                        user = Some(new_user.to_owned());
                    } else {
                        RustResult {
                            result: false,
                            info: String::from("用户创建错误，请检查邮箱格式"),
                        }
                        .send_signal_to_dart();
                    }
                }
                if let Some(ref cur_user) = user {
                    match cur_user.connect_smtp() {
                        Ok(smtp_transport) => {
                            smtp_cli = Some(smtp_transport);
                            RustResult {
                                result: true,
                                info: String::new(),
                            }
                            .send_signal_to_dart();
                        }
                        Err(e) => {
                            RustResult {
                                result: false,
                                info: e.to_string(),
                            }
                            .send_signal_to_dart();
                        }
                    }
                }
                ()
            }
            1 => {
                user = None;
                smtp_cli = None;
                RustResult {
                    result: true,
                    info: String::new(),
                }
                .send_signal_to_dart();
            }
            2 => {
                if let Some(email_proto) = email_proto_listener.recv().await {
                    if let Some(ref cur_user) = user {
                        if let Some(ref cur_smtp_cli) = smtp_cli {
                            cur_user.send(cur_smtp_cli, email_proto.message);
                        }
                    }
                }
            }
            _ => {}
        };
    }
}

#[derive(Clone)]
pub struct User {
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

    fn connect_smtp(&self) -> Result<SmtpTransport, Box<dyn Error>> {
        // Open a remote connection to server
        let smtp_cli = SmtpTransport::relay(self.smtp_domain.as_str())
            .unwrap()
            .credentials(Credentials::new(
                self.email_addr.to_string(),
                self.password.to_string(),
            ))
            .build();

        // Connectivity test & return
        match smtp_cli.test_connection() {
            Ok(_) => Ok(smtp_cli),
            Err(e) => Err(Box::new(e)),
        }
    }

    pub fn send(&self, smtp_cli: &SmtpTransport, email_proto: EmailProto) {
        // Build the message
        let email = Message::builder()
            .from(Mailbox::from(self.email_addr.clone()))
            .to(Mailbox::from(
                match email_proto.recipient.parse::<Address>() {
                    Ok(to) => to,
                    Err(e) => {
                        RustResult {
                            result: false,
                            info: e.to_string(),
                        }
                        .send_signal_to_dart();
                        return;
                    }
                },
            ))
            .subject(email_proto.subject)
            .header(ContentType::TEXT_PLAIN)
            .body(email_proto.body)
            .unwrap();

        // Send the message
        match smtp_cli.send(&email) {
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
        };
    }
}
