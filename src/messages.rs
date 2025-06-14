use crate::repository::Repository;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ClientMessage {
    #[serde(rename = "list_repos")]
    ListRepositories,

    #[serde(rename = "select_repo")]
    SelectRepository { path: String },

    #[serde(rename = "prompt")]
    Prompt { text: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ServerMessage {
    #[serde(rename = "repo_list")]
    RepositoryList { repositories: Vec<Repository> },

    #[serde(rename = "repo_selected")]
    RepositorySelected { repository: Repository },

    #[serde(rename = "error")]
    Error { message: String },

    #[serde(rename = "response")]
    Response { text: String },
}
