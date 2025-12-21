use serde::Deserialize;

#[derive(Deserialize, Debug)]
pub struct RigletMeta {
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub keywords: Vec<String>,
    #[serde(default)]
    pub intent: String,
    #[serde(default)]
    pub status: String,
    #[serde(default)]
    pub broken: bool,
    #[serde(default)]
    pub version: String,
    #[serde(rename = "whenToUse", default)]
    pub when_to_use: Vec<String>,
}
