use uuid::Uuid;
use crate::types::AuthMethod;

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

    pub fn generate_reconnection_token() -> String {
        Uuid::new_v4().to_string()
    }

    pub fn generate_client_id() -> String {
        format!("client_{}", Uuid::new_v4().simple())
    }

    pub fn validate_auth(&self, auth_method: &AuthMethod) -> bool {
        match auth_method {
            AuthMethod::InitialUuid(uuid) => uuid.trim() == self.auth_uuid,
            AuthMethod::ReconnectionToken(_) => true, // Token validation happens in connection handler
        }
    }
}