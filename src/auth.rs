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
}