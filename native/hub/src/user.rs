use crate::messages::user::*;

use std::{
    error::Error,
    fs::{self, File},
    io::Write,
    path::Path,
    str,
};

use base64::prelude::*;
use imap::{self, Connection, Session};
use lettre::{
    message::{
        header::{self, ContentType},
        Attachment, Mailbox, MultiPart, SinglePart,
    },
    transport::smtp::authentication::Credentials,
    Address, Message, SmtpTransport, Transport,
};
use mailparse::*;

use mime_guess::from_path;
use rinf::debug_print;

pub async fn main_logic() {
    let mut user: Option<User> = None;
    let mut smtp_cli: Option<SmtpTransport> = None;
    let mut imap_cli: Option<Session<Connection>> = None;

    let mut action_listener = Action::get_dart_signal_receiver();
    let mut user_proto_listener = UserProto::get_dart_signal_receiver();
    let mut email_send_listener = Email::get_dart_signal_receiver();
    let mut mailbox_selection_listener = MailboxSelection::get_dart_signal_receiver();

    while let Some(dart_signal) = action_listener.recv().await {
        match dart_signal.message.action {
            // Login
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
                            info: String::from(
                                "用户创建失败，请检查邮箱格式\n仅支持 qq.com | 163.com | 126.com",
                            ),
                        }
                        .send_signal_to_dart();
                        continue;
                    }
                }

                // Connect to SMTP server
                match user.as_ref().unwrap().connect_smtp() {
                    Ok(smtp_transport) => smtp_cli = Some(smtp_transport),
                    Err(e) => {
                        RustResult {
                            result: false,
                            info: e.to_string(),
                        }
                        .send_signal_to_dart();
                        continue;
                    }
                }

                // Connect to IMAP server
                match user.as_ref().unwrap().connect_imap() {
                    Ok(imap_session) => imap_cli = Some(imap_session),
                    Err(e) => {
                        RustResult {
                            result: false,
                            info: e.to_string(),
                        }
                        .send_signal_to_dart();
                        continue;
                    }
                }

                RustResult {
                    result: true,
                    info: String::new(),
                }
                .send_signal_to_dart();
            }

            // Logout
            1 => {
                let _ = imap_cli.as_mut().unwrap().logout();
                user = None;
                smtp_cli = None;
                imap_cli = None;
                RustResult {
                    result: true,
                    info: String::new(),
                }
                .send_signal_to_dart();
            }

            // Send
            2 => {
                if let Some(email_proto) = email_send_listener.recv().await {
                    if user.as_ref().is_some() && smtp_cli.as_ref().is_some() {
                        user.as_ref()
                            .unwrap()
                            .send(smtp_cli.as_ref().unwrap(), email_proto.message)
                            .await;
                    }
                }
            }

            // Fetch mailboxes
            3 => {
                MailboxesFetch {
                    mailboxes: user
                        .as_ref()
                        .unwrap()
                        .fetch_mailboxes(imap_cli.as_mut().unwrap())
                        .await,
                }
                .send_signal_to_dart();
            }

            // Fetch email
            4 => {
                if let Some(mailbox_selection) = mailbox_selection_listener.recv().await {
                    match user
                        .as_ref()
                        .unwrap()
                        .fetch_messages(
                            imap_cli.as_mut().unwrap(),
                            mailbox_selection.message.mailbox,
                        )
                        .await
                    {
                        Ok(messages) => {
                            RustResult {
                                result: true,
                                info: String::new(),
                            }
                            .send_signal_to_dart();
                            MessagesFetch { emails: messages }.send_signal_to_dart();
                        }
                        Err(e) => {
                            RustResult {
                                result: true,
                                info: e.to_string(),
                            }
                            .send_signal_to_dart();
                        }
                    };
                }
            }

            _ => unreachable!(),
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
    fn build(user_proto: UserProto) -> Option<User> {
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

    pub async fn send(&self, smtp_cli: &SmtpTransport, email: Email) {
        let email = if email.attachments.is_empty() {
            Message::builder()
                .from(Mailbox::from(self.email_addr.clone()))
                .to(Mailbox::from(match email.to.parse::<Address>() {
                    Ok(to) => to,
                    Err(e) => {
                        RustResult {
                            result: false,
                            info: e.to_string(),
                        }
                        .send_signal_to_dart();
                        return;
                    }
                }))
                .subject(email.subject)
                .header(ContentType::TEXT_PLAIN)
                .body(email.body)
                .unwrap()
        } else {
            let builder = Message::builder()
                .from(Mailbox::from(self.email_addr.clone()))
                .to(Mailbox::from(match email.to.parse::<Address>() {
                    Ok(to) => to,
                    Err(e) => {
                        RustResult {
                            result: false,
                            info: e.to_string(),
                        }
                        .send_signal_to_dart();
                        return;
                    }
                }))
                .subject(email.subject);

            let mut multi_part = MultiPart::mixed().singlepart(
                SinglePart::builder()
                    .header(header::ContentType::TEXT_PLAIN)
                    .body(email.body),
            );

            for path in email.attachments.iter() {
                let mime_type = from_path(&path.clone()).first_or_octet_stream();
                multi_part = multi_part.singlepart(Attachment::new(path.clone()).body(
                    fs::read(path).unwrap(),
                    mime_type.to_string().parse().unwrap(),
                ));
            }

            builder.multipart(multi_part).unwrap()
        };

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

    pub async fn fetch_mailboxes(&self, imap_cli: &mut Session<Connection>) -> Vec<String> {
        imap_cli
            .list(Some(""), Some("*"))
            .unwrap()
            .iter()
            .filter(|&s| !s.name().contains('&'))
            .map(|s| s.name().to_string())
            .collect::<Vec<_>>()
    }

    pub async fn fetch_messages(
        &self,
        imap_cli: &mut Session<Connection>,
        mailbox: String,
    ) -> Result<Vec<Email>, Box<dyn Error>> {
        let mut messages = vec![];
        imap_cli.select(mailbox).unwrap();

        // Fetch all messages in the mailbox
        let mut i = 1;
        loop {
            let message = imap_cli.fetch(i.to_string(), "RFC822").unwrap();
            if message.is_empty() {
                break;
            }
            let message_body = message
                .iter()
                .flat_map(|m| {
                    str::from_utf8(m.body().expect("message has no body"))
                        .unwrap()
                        .lines()
                        .map(String::from)
                })
                .collect::<Vec<_>>();

            let mut from_st = -1;
            let mut date_st = -1;
            for (i, l) in message_body.iter().enumerate() {
                if l.starts_with("From: ") {
                    from_st = i as i32;
                } else if l.starts_with("Date: ") {
                    date_st = i as i32 + 1;
                    break;
                }
            }

            if from_st == -1 {
                debug_print!("from_st == -1");
                continue;
            }

            let con = message_body
                .iter()
                .skip(from_st as usize)
                .map(|s| s.to_string())
                .collect::<Vec<_>>()
                .join("\n");

            let mut body = message_body
                .iter()
                .skip(date_st as usize)
                .map(|s| s.to_string())
                .collect::<Vec<_>>()
                .join("\n")
                .trim()
                .to_string();
            if body.is_empty() {
                body = String::from("[无正文]");
            } else {
                body = String::from_utf8(
                    BASE64_STANDARD
                        .decode(body.as_bytes())
                        .unwrap_or("[decoding failed]".as_bytes().to_vec()),
                )
                .unwrap();
            }

            let parsed = match parse_mail(con.as_bytes()) {
                Ok(p) => p,
                Err(e) => return Err(Box::new(e)),
            };

            debug_print!("{}", parsed.subparts.len());

            let download_path = dirs::download_dir().unwrap();

            for (i, part) in parsed.subparts.iter().enumerate() {
                let disposition = part.get_content_disposition();
                if disposition.disposition == DispositionType::Attachment {
                    let default = format!("attachment_{}", i);
                    let filename = disposition.params.get("filename").unwrap_or(&default);
                    println!("Attachment: {}", filename);

                    let file_path = download_path
                        .join(Path::new(filename).file_name().unwrap());

                    let content = part.get_body_raw()?;

                    Self::save_attachment(file_path.to_str().unwrap(), &content)?;
                }
            }

            messages.push(Email {
                from: parsed
                    .headers
                    .get_first_value("From")
                    .unwrap_or(String::from("[未知发件人]")),
                to: parsed
                    .headers
                    .get_first_value("To")
                    .unwrap_or(String::from("[未知收件人]")),
                subject: parsed
                    .headers
                    .get_first_value("Subject")
                    .unwrap_or(String::from("[无主题]")),
                date: parsed
                    .headers
                    .get_first_value("Date")
                    .unwrap_or(String::from("[未知日期]")),
                attachments: vec![],
                body,
            });
            i += 1;
        }

        Ok(messages)
    }

    fn save_attachment(filename: &str, content: &[u8]) -> std::io::Result<()> {
        let path = Path::new(filename);
        let mut file = File::create(&path)?;
        file.write_all(content)?;
        println!("Saved attachment to {}", path.display());
        Ok(())
    }
}
