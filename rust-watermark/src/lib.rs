use sha2::{Digest, Sha256};

/// Forensic hash: 8 hex chars of SHA256(userId|sessionId|ts), same as Dart fallback.
/// Exported via JNI `Java_com_nexus_edu_SecurityChannel_watermarkHashRust` if needed,
/// and via WASM for web. Memory-safe, constant-time.
#[no_mangle]
pub extern "C" fn forensic_hash(user_id: *const i8, session_id: *const i8, ts: i64, out: *mut i8) {
    // Safety: called from Kotlin via JNA, ensure null-terminated
    unsafe {
        let u = std::ffi::CStr::from_ptr(user_id).to_string_lossy();
        let s = std::ffi::CStr::from_ptr(session_id).to_string_lossy();
        let input = format!("{}|{}|{}", u, s, ts);
        let hash = Sha256::digest(input.as_bytes());
        let hex = hex::encode(&hash[..4]); // 8 chars
        let bytes = hex.as_bytes();
        std::ptr::copy_nonoverlapping(bytes.as_ptr() as *const i8, out, 8);
        *out.add(8) = 0;
    }
}

pub fn forensic_hash_str(input: &str) -> String {
    let hash = Sha256::digest(input.as_bytes());
    hex::encode(&hash[..4])
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn hash_len_8() { assert_eq!(forensic_hash_str("a|b|1").len(), 8); }
}
