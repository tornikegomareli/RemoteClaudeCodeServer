use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Repository {
    pub name: String,
    pub path: PathBuf,
}

pub fn scan_repositories(paths: &[PathBuf]) -> Vec<Repository> {
    let mut repositories = Vec::new();

    for base_path in paths {
        if base_path.exists() && base_path.is_dir() {
            // Only scan subdirectories, not the base path itself
            if let Ok(entries) = std::fs::read_dir(base_path) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.is_dir() && is_git_repository(&path) {
                        if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                            repositories.push(Repository {
                                name: name.to_string(),
                                path: path.clone(),
                            });
                        }
                    }
                }
            }
        }
    }

    repositories.sort_by(|a, b| a.name.cmp(&b.name));
    repositories
}

fn is_git_repository(path: &Path) -> bool {
    path.is_dir() && path.join(".git").exists()
}
