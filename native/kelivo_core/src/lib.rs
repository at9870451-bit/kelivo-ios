// kelivo_core — Rust Core（iMessage 风格即时通讯 App 的数据层与安全模块）
// FFI：kelivo_call(json) → json（JSON 总线，与 Dart 侧 KelivoBridge 对应）
mod store;
mod crypto;
mod util;

use std::ffi::{CStr, CString, c_char};

/// 解析入参：{"method": "...", "params": {...}}
fn parse_payload(input: &str) -> (String, serde_json::Value) {
    let v: serde_json::Value = serde_json::from_str(input).unwrap_or(serde_json::Value::Null);
    let method = v
        .get("method")
        .and_then(|m| m.as_str())
        .unwrap_or("")
        .to_string();
    let params = v.get("params").cloned().unwrap_or(serde_json::Value::Null);
    (method, params)
}

fn ok(data: serde_json::Value) -> String {
    serde_json::json!({ "ok": true, "data": data }).to_string()
}

fn err(code: &str, msg: &str) -> String {
    serde_json::json!({ "ok": false, "error": { "code": code, "message": msg } }).to_string()
}

fn dispatch(method: &str, p: &serde_json::Value) -> Option<serde_json::Value> {
    match method {
        "core.version" => Some(serde_json::json!({
            "name": "KelivoCore",
            "version": env!("CARGO_PKG_VERSION"),
            "architecture": "Flutter UI + Rust Core (FFI JSON bus)",
        })),
        "core.init" => {
            let dir = p.get("data_dir").and_then(|v| v.as_str()).unwrap_or("");
            if dir.is_empty() {
                return Some(serde_json::json!({ "error": "data_dir 为空" }));
            }
            store::init(dir);
            Some(serde_json::json!({ "dir": dir }))
        }
        // ---- 联系人（微信风格好友/群组）----
        "contacts.friends" => Some(serde_json::json!({ "friends": store::friends() })),
        "contacts.save_friend" => {
            let v = p.get("friend").cloned().unwrap_or(serde_json::Value::Null);
            Some(serde_json::json!({ "count": store::save_friend(&v) }))
        }
        "contacts.delete_friend" => {
            let id = p.get("id").and_then(|v| v.as_str()).unwrap_or("");
            Some(serde_json::json!({ "count": store::delete_friend(id) }))
        }
        "contacts.groups" => Some(serde_json::json!({ "groups": store::groups() })),
        "contacts.save_group" => {
            let v = p.get("group").cloned().unwrap_or(serde_json::Value::Null);
            Some(serde_json::json!({ "count": store::save_group(&v) }))
        }
        "contacts.delete_group" => {
            let id = p.get("id").and_then(|v| v.as_str()).unwrap_or("");
            Some(serde_json::json!({ "count": store::delete_group(id) }))
        }
        // ---- 消息存储（iMessage 会话）----
        "store.sessions" => Some(serde_json::json!({ "sessions": store::sessions() })),
        "store.messages" => {
            let key = p.get("key").and_then(|v| v.as_str()).unwrap_or("");
            Some(serde_json::json!({ "messages": store::messages(key) }))
        }
        "store.seed_demo" => {
            let n = store::seed_demo();
            Some(serde_json::json!({ "seeded": n }))
        }
        "store.append" => {
            let key = p.get("key").and_then(|v| v.as_str()).unwrap_or("");
            let role = p.get("role").and_then(|v| v.as_str()).unwrap_or("user");
            let content = p.get("content").and_then(|v| v.as_str()).unwrap_or("");
            Some(serde_json::json!({ "count": store::append(key, role, content) }))
        }
        "store.replace" => {
            let key = p.get("key").and_then(|v| v.as_str()).unwrap_or("");
            let msgs = p.get("messages").cloned().unwrap_or(serde_json::Value::Null);
            Some(serde_json::json!({ "count": store::replace(key, &msgs) }))
        }
        "store.remove" => {
            let key = p.get("key").and_then(|v| v.as_str()).unwrap_or("");
            let id = p.get("id").and_then(|v| v.as_u64());
            store::remove(key, id)
        }
        "store.clear" => {
            let key = p.get("key").and_then(|v| v.as_str()).unwrap_or("");
            store::clear(key)
        }
        // ---- 数据处理 ----
        "util.text_stats" => {
            let text = p.get("text").and_then(|v| v.as_str()).unwrap_or("");
            Some(serde_json::json!({ "stats": util::text_stats(text) }))
        }
        "util.eval" => {
            let expr = p.get("expr").and_then(|v| v.as_str()).unwrap_or("");
            match util::eval(expr) {
                Ok(v) => Some(serde_json::json!({ "value": v })),
                Err(e) => Some(serde_json::json!({ "error": e })),
            }
        }
        "util.base64" => {
            let op = p.get("op").and_then(|v| v.as_str()).unwrap_or("encode");
            let data = p.get("data").and_then(|v| v.as_str()).unwrap_or("");
            Some(serde_json::json!({ "result": util::base64(op, data) }))
        }
        // ---- 安全模块（哈希）----
        "crypto.sha256" => {
            let data = p.get("data").and_then(|v| v.as_str()).unwrap_or("");
            Some(serde_json::json!({ "sha256": crypto::sha256_hex(data.as_bytes()) }))
        }
        "crypto.blake2s" => {
            let data = p.get("data").and_then(|v| v.as_str()).unwrap_or("");
            Some(serde_json::json!({ "blake2s": crypto::blake2s_hex(data.as_bytes()) }))
        }
        "crypto.crc32" => {
            let data = p.get("data").and_then(|v| v.as_str()).unwrap_or("");
            Some(serde_json::json!({ "crc32": crypto::crc32_hex(data.as_bytes()) }))
        }
        _ => None,
    }
}

/// FFI 入口：入参 JSON 字符串 → 返回 JSON 字符串（调用方负责释放）
#[no_mangle]
pub extern "C" fn kelivo_call(payload_ptr: *const c_char) -> *mut c_char {
    let input = unsafe {
        if payload_ptr.is_null() {
            String::new()
        } else {
            CStr::from_ptr(payload_ptr).to_string_lossy().to_string()
        }
    };
    let (method, params) = parse_payload(&input);
    let out = match dispatch(&method, &params) {
        Some(data) => ok(data),
        None => err("unknown_method", &format!("未实现的方法: {method}")),
    };
    match CString::new(out) {
        Ok(c) => c.into_raw(),
        Err(_) => CString::new("{\"ok\":false}").unwrap().into_raw(),
    }
}

/// 释放 kelivo_call 返回的字符串
#[no_mangle]
pub extern "C" fn kelivo_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}