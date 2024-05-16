use crate::messages::user::*;

use std::{error::Error, str};

use imap::{self, Connection, Session};
use lettre::{
    message::{header::ContentType, Mailbox},
    transport::smtp::authentication::Credentials,
    Address, Message, SmtpTransport, Transport,
};
use mailparse::*;

use rinf::debug_print;

pub async fn main_logic() {
    let mut user: Option<User> = None;
    let mut smtp_cli: Option<SmtpTransport> = None;
    let mut imap_cli: Option<Session<Connection>> = None;

    let mut action_listener = Action::get_dart_signal_receiver();
    let mut user_proto_listener = UserProto::get_dart_signal_receiver();
    let mut email_proto_listener = EmailProto::get_dart_signal_receiver();
    let mut mailbox_selection_listener = MailboxSelection::get_dart_signal_receiver();

    while let Some(dart_signal) = action_listener.recv().await {
        match dart_signal.message.action {
            0 => {
                user = None;
                smtp_cli = None;
                imap_cli = None;

                // Build user
                if let Some(user_proto) = user_proto_listener.recv().await {
                    if let Some(new_user) = User::build(user_proto.message) {
                        user = Some(new_user.to_owned());
                    } else {
                        RustResult {
                            result: false,
                            info: String::from("用户创建失败，请检查邮箱格式\n当前仅支持 qq.com | 163.com | 126.com"),
                        }
                        .send_signal_to_dart();
                    }
                }

                // Connect to SMTP server
                if let Some(ref cur_user) = user {
                    match cur_user.connect_smtp() {
                        Ok(smtp_transport) => {
                            smtp_cli = Some(smtp_transport);
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

                // Connect to IMAP server
                if let Some(ref cur_user) = user {
                    match cur_user.connect_imap() {
                        Ok(imap_session) => {
                            imap_cli = Some(imap_session);
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

                if user.is_some() && smtp_cli.is_some() && imap_cli.is_some() {
                    RustResult {
                        result: true,
                        info: String::new(),
                    }
                    .send_signal_to_dart();
                }
            }
            1 => {
                user = None;
                smtp_cli = None;
                if imap_cli.is_some() {
                    match imap_cli.as_mut().unwrap().logout() {
                        Ok(_) => {}
                        Err(e) => {
                            debug_print!("{:?}", e);
                        }
                    };
                }
                imap_cli = None;
                RustResult {
                    result: true,
                    info: String::new(),
                }
                .send_signal_to_dart();
            }
            2 => {
                if let Some(email_proto) = email_proto_listener.recv().await {
                    if user.as_ref().is_some() && smtp_cli.as_ref().is_some() {
                        user.as_ref()
                            .unwrap()
                            .send(smtp_cli.as_ref().unwrap(), email_proto.message);
                    }
                }
            }
            3 => {
                if user.as_ref().is_some() && imap_cli.as_ref().is_some() {
                    let mailboxes = user
                        .as_ref()
                        .unwrap()
                        .fetch_mailboxes(imap_cli.as_mut().unwrap());
                    MailboxesFetch { mailboxes }.send_signal_to_dart();
                }
            }
            4 => {
                if user.as_ref().is_some() && imap_cli.as_ref().is_some() {
                    if let Some(mailbox_selection) = mailbox_selection_listener.recv().await {
                        let messages = user.as_ref().unwrap().fetch_messages(
                            imap_cli.as_mut().unwrap(),
                            mailbox_selection.message.mailbox,
                        );
                        MessagesFetch { emails: messages }.send_signal_to_dart();
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

        if !matches!(domain, "qq.com" | "163.com" | "126.com") {
            return None;
        }

        Some(User {
            smtp_domain: format!("smtp.{}", domain),
            imap_domain: format!("imap.{}", domain),
            email_addr: email,
            password,
        })
    }

    fn connect_smtp(&self) -> Result<SmtpTransport, Box<dyn Error>> {
        // Open a remote connection to server
        let smtp_cli_builder = SmtpTransport::relay(self.smtp_domain.as_str())
            .unwrap()
            .credentials(Credentials::new(
                self.email_addr.to_string(),
                self.password.to_string(),
            ));
        let smtp_cli = smtp_cli_builder.build();

        // Connectivity test & return
        match smtp_cli.test_connection() {
            Ok(_) => Ok(smtp_cli),
            Err(e) => Err(Box::new(e)),
        }
    }

    fn connect_imap(&self) -> imap::error::Result<Session<Connection>> {
        match imap::ClientBuilder::new(self.imap_domain.as_str(), 993).connect() {
            Ok(session) => match session.login(&self.email_addr, &self.password) {
                Ok(session) => Ok(session),
                Err(e) => Err(e.0),
            },
            Err(e) => Err(e),
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

    pub fn fetch_mailboxes(&self, imap_cli: &mut Session<Connection>) -> Vec<String> {
        imap_cli
            .list(Some(""), Some("*"))
            .unwrap()
            .iter()
            .filter(|&s| !s.name().contains('&'))
            .map(|s| s.name().to_string())
            .collect::<Vec<_>>()
    }

    fn fetch_messages(
        &self,
        imap_cli: &mut Session<Connection>,
        mailbox: String,
    ) -> Vec<EmailFetch> {
        let mut messages = vec![];
        imap_cli.select(mailbox).unwrap();

        // Fetch all messages in the mailbox and print their "Subject: " line
        let mut i = 1;
        loop {
            let message = imap_cli.fetch(i.to_string(), "RFC822").unwrap();
            if message.is_empty() {
                break;
            }
            let message_body = message
                .iter()
                .flat_map(|m| {
                    str::from_utf8(m.body().expect("message did not have a body!"))
                        .unwrap()
                        .lines()
                        .map(String::from)
                })
                .map(|s| s.to_string())
                .collect::<Vec<_>>();

            let mut is_body = false;
            let mut is_after_date = false;
            let mut from = String::from("[未知发送者]");
            let mut to = String::from("[未知收件人]");
            let mut subject = String::from("[无主题]");
            let mut date = String::from("[未知日期]");
            let mut body = String::from("[无正文]");
            for line in message_body.iter() {
                // Real body starts at line "From: "
                if line.starts_with("From: ") {
                    is_body = true;
                }

                // Lines after "Date: " are "body" part
                if let Some(_date) = line.strip_prefix("Date: ") {
                    date = _date.to_string();
                    is_after_date = true;
                    continue;
                }
                if is_after_date {
                    body += line;
                    continue;
                }

                // Ignore "Content" header
                if is_body {
                    if let Some(_from) = line.strip_prefix("From: ") {
                        from = _from.to_string();
                    } else if let Some(_to) = line.strip_prefix("To: ") {
                        to = _to.to_string();
                    } else if let Some(_subject) = line.strip_prefix("Subject: ") {
                        subject = _subject.to_string();
                    }
                }
            }

            messages.push(EmailFetch {
                from,
                to,
                subject,
                date,
                body,
            });
            i += 1;
        }

        messages
    }
}
