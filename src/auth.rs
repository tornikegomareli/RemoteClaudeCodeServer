use log::{error, info};
use qrcode::{render::unicode, QrCode};
use uuid::Uuid;

pub struct AuthManager {
    auth_uuid: String,
}

impl AuthManager {
    pub fn new() -> Self {
        let auth_uuid = Uuid::new_v4().to_string();
        Self { auth_uuid }
    }

    pub fn get_uuid(&self) -> &str {
        &self.auth_uuid
    }

    pub fn validate(&self, provided_uuid: &str) -> bool {
        provided_uuid.trim() == self.auth_uuid
    }

    pub fn display_auth_info(&self) {
        info!("Authentication UUID: {}", self.auth_uuid);
        self.display_qr_code();
    }

    fn display_qr_code(&self) {
        match QrCode::new(&self.auth_uuid) {
            Ok(code) => {
                let image = code
                    .render::<unicode::Dense1x2>()
                    .dark_color(unicode::Dense1x2::Light)
                    .light_color(unicode::Dense1x2::Dark)
                    .build();
                println!("\n=== QR Code for UUID ===");
                println!("{}", image);
                println!("======================\n");
            }
            Err(e) => {
                error!("Failed to generate QR code: {}", e);
            }
        }
    }
}