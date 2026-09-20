// GoldenFloat Rust Wrapper
//
// Provides FFI bindings to Zig-compiled golden-float binary
// Downloads the appropriate binary from GitHub releases

pub const VERSION: &str = "1.0.0";
pub const GITHUB_RELEASES: &str = "https://github.com/gHashTag/zig-golden-float/releases/download";

#[cfg(target_os = "windows")]
use std::os::windows::process::Command;

/// Get binary path for current platform
pub fn get_binary_path() -> std::path.PathBuf {
    let bin_name = "golden-float";
    let mut path = std::env::var("HOME").unwrap();
    path.push(".golden-float");
    path.push(bin_name);

    #[cfg(windows)]
    {
        path.set_extension("exe");
    }

    path
}

/// Launch golden-float binary
pub fn run_golden_float(args: &[&str]) -> std::process::Child {
    let binary = get_binary_path();

    let cmd = Command::new(&binary);
    cmd.args(args);

    cmd.spawn().expect("Failed to spawn golden-float binary")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_binary_path() {
        let path = get_binary_path();
        assert!(path.to_str().unwrap().contains("golden-float"));
    }
}
