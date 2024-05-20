use crate::messages::user::*;

use std::{
    collections::HashMap,
    error::Error,
    fs::{self, File},
    io::{self, Write},
    path::{Path, PathBuf},
    str,
};

use imap::{self, types::Fetches, Connection, Session};
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

pub async fn main_logic() {
    let mut user: Option<User> = None;
    let mut smtp_cli: Option<SmtpTransport> = None;
    let mut imap_cli: Option<Session<Connection>> = None;
    let mut uid_to_detail: Option<HashMap<String, EmailDetailFetch>> = None;

    let mut action_listener = Action::get_dart_signal_receiver();
    let mut user_proto_listener = UserProto::get_dart_signal_receiver();
    let mut new_email_listener = NewEmail::get_dart_signal_receiver();
    let mut mailbox_request_listener = MailboxRequest::get_dart_signal_receiver();
    let mut email_detail_request_listener = EmailDetailRequest::get_dart_signal_receiver();

    while let Some(dart_signal) = action_listener.recv().await {
        match dart_signal.message.action {
            // Login
            0 => {
                // Build user
                if let Some(user_proto) = user_proto_listener.recv().await {
                    if let Some(new_user) = User::build(user_proto.message) {
                        user = Some(new_user.to_owned());
                    } else {
                        send_signal_failure(String::from(
                            "用户创建失败，请检查邮箱格式\n仅支持 qq.com | 163.com | 126.com",
                        ));
                        continue;
                    }
                }

                // Connect to SMTP server
                match user.as_ref().unwrap().connect_smtp() {
                    Ok(smtp_transport) => smtp_cli = Some(smtp_transport),
                    Err(e) => {
                        send_signal_failure(e.to_string());
                        continue;
                    }
                }

                // Connect to IMAP server
                match user.as_ref().unwrap().connect_imap() {
                    Ok(imap_session) => imap_cli = Some(imap_session),
                    Err(e) => {
                        send_signal_failure(e.to_string());
                        continue;
                    }
                }

                uid_to_detail = Some(HashMap::new());
                send_signal_succeed();
            }

            // Logout
            1 => {
                let _ = imap_cli.as_mut().unwrap().logout();
                user = None;
                smtp_cli = None;
                imap_cli = None;
                uid_to_detail = None;
                send_signal_succeed();
            }

            // Send
            2 => {
                if let Some(email_proto) = new_email_listener.recv().await {
                    user.as_ref()
                        .unwrap()
                        .send(smtp_cli.as_ref().unwrap(), email_proto.message);
                }
            }

            // Fetch mailboxes
            3 => {
                MailboxesFetch {
                    mailboxes: user
                        .as_ref()
                        .unwrap()
                        .fetch_mailboxes(imap_cli.as_mut().unwrap()),
                }
                .send_signal_to_dart();
            }

            // Fetch email metadata
            4 => {
                if let Some(mailbox_selection) = mailbox_request_listener.recv().await {
                    match user.as_ref().unwrap().fetch_message_headers(
                        imap_cli.as_mut().unwrap(),
                        mailbox_selection.message.mailbox,
                    ) {
                        Ok(email_metadatas) => {
                            send_signal_succeed();
                            EmailMetadataFetch { email_metadatas }.send_signal_to_dart();
                        }
                        Err(e) => {
                            send_signal_failure(e.to_string());
                        }
                    };
                }
            }

            // Fetch email detail
            5 => {
                if let Some(email_detail_request) = email_detail_request_listener.recv().await {
                    let uid = email_detail_request.message.uid;
                    if uid_to_detail.as_ref().unwrap().contains_key(&uid) {
                        send_signal_succeed();
                        uid_to_detail
                            .as_ref()
                            .unwrap()
                            .get(&uid)
                            .unwrap()
                            .send_signal_to_dart();
                    } else {
                        match user.as_ref().unwrap().fetch_detail(
                            imap_cli.as_mut().unwrap(),
                            uid,
                            email_detail_request.message.folder_path,
                            uid_to_detail.as_mut().unwrap(),
                        ) {
                            Ok(email_detail_fetch) => {
                                send_signal_succeed();
                                email_detail_fetch.send_signal_to_dart();
                            }
                            Err(e) => send_signal_failure(e.to_string()),
                        };
                    }
                }
            }

            _ => unreachable!(),
        };
    }
}

fn send_signal_succeed() {
    RustResult {
        result: true,
        info: String::new(),
    }
    .send_signal_to_dart();
}

fn send_signal_failure(e: String) {
    RustResult {
        result: false,
        info: e,
    }
    .send_signal_to_dart();
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

    fn connect_imap(&self) -> imap::error::Result<Session<Connection>> {
        match imap::ClientBuilder::new(self.imap_domain.as_str(), 993).connect() {
            Ok(session) => match session.login(&self.email_addr, &self.password) {
                Ok(session) => Ok(session),
                Err(e) => Err(e.0),
            },
            Err(e) => Err(e),
        }
    }

    fn send(&self, smtp_cli: &SmtpTransport, new_email: NewEmail) {
        let builder = Message::builder()
            .from(Mailbox::from(self.email_addr.clone()))
            .to(Mailbox::from(match new_email.to.parse::<Address>() {
                Ok(to) => to,
                Err(e) => {
                    send_signal_failure(e.to_string());
                    return;
                }
            }))
            .subject(new_email.subject);

        // Build message
        let email = if new_email.attachments.is_empty() {
            // Message with no attachment
            builder
                .header(ContentType::TEXT_PLAIN)
                .body(new_email.body)
                .unwrap()
        } else {
            // Message with attachments
            let mut multi_part = MultiPart::mixed().singlepart(
                SinglePart::builder()
                    .header(header::ContentType::TEXT_PLAIN)
                    .body(new_email.body),
            );

            for path in new_email.attachments.iter() {
                let mime_type = from_path(&path.clone()).first_or_octet_stream();
                multi_part = multi_part.singlepart(Attachment::new(path.clone()).body(
                    fs::read(path).unwrap(),
                    mime_type.to_string().parse().unwrap(),
                ));
            }

            builder.multipart(multi_part).unwrap()
        };

        // Send message
        match smtp_cli.send(&email) {
            Ok(_) => send_signal_succeed(),
            Err(e) => send_signal_failure(e.to_string()),
        };
    }

    fn fetch_mailboxes(&self, imap_cli: &mut Session<Connection>) -> Vec<String> {
        imap_cli
            .list(Some(""), Some("*"))
            .unwrap()
            .iter()
            .filter_map(|s| {
                let name = s.name();
                if !name.contains('&') {
                    Some(name.to_string())
                } else {
                    None
                }
            })
            .collect()
    }

    fn fetch_message_headers(
        &self,
        imap_cli: &mut Session<Connection>,
        mailbox: String,
    ) -> Result<Vec<EmailMetadata>, Box<dyn Error>> {
        // Select mailbox
        imap_cli.select(&mailbox).unwrap();
        let mut messages = vec![];

        // Fetch all messages from the mailbox
        let mut i = 1;
        loop {
            // Construct uid
            let uid = format!("{}:{}", mailbox, i);

            // Fetch metadata
            let fetch = imap_cli.fetch(i.to_string(), "RFC822.HEADER").unwrap();
            if fetch.is_empty() {
                break;
            }
            let message_header = parse_message_header_or_body(fetch, true);
            let parsed = match parse_mail(message_header.as_bytes()) {
                Ok(p) => p,
                Err(e) => return Err(Box::new(e)),
            };

            messages.push(EmailMetadata {
                uid,
                from: get_header(&parsed, "From", "[未知发件人]"),
                to: get_header(&parsed, "To", "[未知收件人]"),
                subject: get_header(&parsed, "Subject", "[无主题]"),
                date: get_header(&parsed, "Date", "[未知日期]"),
            });

            i += 1;
        }

        Ok(messages)
    }

    fn fetch_detail(
        &self,
        imap_cli: &mut Session<Connection>,
        uid: String,
        folder_path: String,
        map: &mut HashMap<String, EmailDetailFetch>,
    ) -> Result<EmailDetailFetch, Box<dyn Error>> {
        // Select mailbox and fetch
        let (mailbox, index) = parse_uid(uid.as_str());
        imap_cli.select(mailbox).unwrap();
        let fetch = imap_cli.fetch(index.to_string(), "RFC822").unwrap();

        // Parse message body
        let message_body = parse_message_header_or_body(fetch, false);
        let parsed = match parse_mail(message_body.as_bytes()) {
            Ok(p) => p,
            Err(e) => return Err(Box::new(e)),
        };

        let mut attachments = vec![];
        let mut body = String::new();

        let download_path = PathBuf::from(folder_path);

        if parsed.subparts.is_empty() {
            body = parsed.get_body().unwrap_or(String::from("[正文解析错误]"));
        } else {
            for (i, part) in parsed.subparts.iter().enumerate() {
                let disposition = part.get_content_disposition();

                match disposition.disposition {
                    DispositionType::Attachment => {
                        let default = format!("attachment_{}", i);
                        let filename = disposition.params.get("filename").unwrap_or(&default);
                        let filename = Path::new(filename).file_name().unwrap();

                        let file_path = download_path.join(filename);
                        let content = part.get_body_raw()?;
                        save_attachment(file_path.to_str().unwrap(), &content)?;
                        attachments.push(filename.to_string_lossy().into_owned());
                    }
                    DispositionType::Inline => {
                        body += &part.get_body()?.to_string();
                    }
                    _ => {}
                }
            }
        }

        let email_detail = EmailDetailFetch {
            attachments,
            body: body.trim().to_string(),
        };
        map.insert(uid, email_detail.to_owned());
        Ok(email_detail)
    }
}

fn save_attachment(filename: &str, content: &[u8]) -> io::Result<()> {
    let mut path = PathBuf::from(filename);
    let mut counter = 1;

    while path.exists() {
        let new_filename = format!(
            "{}({}).{}",
            path.file_stem().unwrap().to_string_lossy(),
            counter,
            path.extension().unwrap_or_default().to_string_lossy()
        );
        path = path.with_file_name(new_filename);
        counter += 1;
    }

    let mut file = File::create(&path)?;
    file.write_all(content)?;
    Ok(())
}

fn parse_message_header_or_body(message: Fetches, is_header: bool) -> String {
    message
        .iter()
        .flat_map(|m| {
            str::from_utf8(
                (if is_header { m.header() } else { m.body() }).unwrap_or(b"error parsing message"),
            )
            .unwrap()
            .lines()
        })
        .collect::<Vec<_>>()
        .join("\n")
}

fn get_header(parsed: &ParsedMail, key: &str, default: &str) -> String {
    parsed
        .headers
        .get_first_value(key)
        .unwrap_or(default.to_string())
}

fn parse_uid(uid: &str) -> (String, usize) {
    let seg = uid.split(':').collect::<Vec<_>>();
    (seg[0].to_string(), seg[1].parse().unwrap())
}
