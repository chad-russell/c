use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq)]
pub struct Subvolume {
    pub id: u64,
    pub path: PathBuf,
    pub uuid: String,
    pub parent_uuid: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TargetRoots {
    A, // @active_a
    B, // @active_b
}

impl TargetRoots {
    pub fn as_str(&self) -> &'static str {
        match self {
            TargetRoots::A => "@active_a",
            TargetRoots::B => "@active_b",
        }
    }
}
