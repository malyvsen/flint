use tauri_plugin_log::{Target, TargetKind};

const MAX_FILE_SIZE: u128 = 4 * 1024 * 1024;

pub fn plugin() -> tauri::plugin::TauriPlugin<tauri::Wry> {
    tauri_plugin_log::Builder::new()
        // No Webview target: the frontend mirrors console output here, so it would loop.
        .targets([
            Target::new(TargetKind::Stdout),
            Target::new(TargetKind::LogDir {
                file_name: Some("__LOG_FILE_NAME__".into()),
            }),
        ])
        .max_file_size(MAX_FILE_SIZE)
        .timezone_strategy(tauri_plugin_log::TimezoneStrategy::UseLocal)
        .level(level())
        .build()
}

fn level() -> log::LevelFilter {
    env_level("__LOG_LEVEL_ENV__")
        .or_else(|| env_level("RUST_LOG"))
        .unwrap_or(default_level())
}

fn env_level(name: &str) -> Option<log::LevelFilter> {
    std::env::var(name).ok()?.parse().ok()
}

fn default_level() -> log::LevelFilter {
    if cfg!(debug_assertions) {
        log::LevelFilter::Debug
    } else {
        log::LevelFilter::Info
    }
}
