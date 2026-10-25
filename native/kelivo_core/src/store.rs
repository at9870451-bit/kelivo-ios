// store.rs — 会话消息存储（JSON 文件，iMessage 演示数据）
use serde_json::{Value, json};
use std::fs;
use std::path::PathBuf;
use std::sync::OnceLock;
use std::time::{SystemTime, UNIX_EPOCH};

static DATA_DIR: OnceLock<String> = OnceLock::new();

pub fn init(dir: &str) {
    let _ = DATA_DIR.set(dir.to_string());
    let im = im_dir();
    let _ = fs::create_dir_all(&im);
    // 不预置演示数据；清除历史版本遗留的演示会话/好友/群组
    clean_demo();
}

/// 清除演示数据（im_xiaoman/im_yinuo/im_lizhe/im_hike），保留用户自己添加的
fn clean_demo() {
    const DEMO: [&str; 4] = ["im_xiaoman", "im_yinuo", "im_lizhe", "im_hike"];
    let mut list = sessions();
    list.retain(|s| {
        let id = s.get("id").and_then(|v| v.as_str()).unwrap_or("");
        !DEMO.contains(&id)
    });
    save_sessions(&list);
    let mut fl = friends();
    fl.retain(|f| {
        let id = f.get("id").and_then(|v| v.as_str()).unwrap_or("");
        !DEMO.contains(&id)
    });
    save_friends(&fl);
    let mut gl = groups();
    gl.retain(|g| {
        let id = g.get("id").and_then(|v| v.as_str()).unwrap_or("");
        !DEMO.contains(&id)
    });
    save_groups(&gl);
    for id in DEMO {
        let _ = fs::remove_file(history_file(id));
    }
}

fn im_dir() -> PathBuf {
    let d = DATA_DIR.get().cloned().unwrap_or_else(|| ".".to_string());
    PathBuf::from(&d).join("im")
}

fn sessions_file() -> PathBuf {
    im_dir().join("sessions.json")
}

fn friends_file() -> PathBuf {
    im_dir().join("friends.json")
}

fn groups_file() -> PathBuf {
    im_dir().join("groups.json")
}

/// 好友列表（微信风格联系人）
pub fn friends() -> Vec<Value> {
    read_json(&friends_file()).as_array().cloned().unwrap_or_default()
}

fn save_friends(list: &[Value]) {
    write_json(&friends_file(), &json!(list));
}

/// 群组列表
pub fn groups() -> Vec<Value> {
    read_json(&groups_file()).as_array().cloned().unwrap_or_default()
}

fn save_groups(list: &[Value]) {
    write_json(&groups_file(), &json!(list));
}

pub fn save_friend(v: &Value) -> usize {
    let id = v.get("id").and_then(|x| x.as_str()).unwrap_or("").to_string();
    let mut list = friends();
    list.retain(|f| f.get("id").and_then(|x| x.as_str()).unwrap_or("") != id);
    list.push(v.clone());
    save_friends(&list);
    list.len()
}

pub fn delete_friend(id: &str) -> usize {
    let mut list = friends();
    let before = list.len();
    list.retain(|f| f.get("id").and_then(|x| x.as_str()).unwrap_or("") != id);
    save_friends(&list);
    // 同时删除对应会话与历史（彻底删除好友）
    remove_session(id);
    let _ = fs::remove_file(history_file(id));
    before - list.len()
}

/// 从会话列表移除某项（不删历史，由调用方决定）
fn remove_session(key: &str) {
    let mut list = sessions();
    list.retain(|s| s.get("id").and_then(|v| v.as_str()).unwrap_or("") != key);
    save_sessions(&list);
}

pub fn save_group(v: &Value) -> usize {
    let id = v.get("id").and_then(|x| x.as_str()).unwrap_or("").to_string();
    let mut list = groups();
    list.retain(|g| g.get("id").and_then(|x| x.as_str()).unwrap_or("") != id);
    list.push(v.clone());
    save_groups(&list);
    list.len()
}

pub fn delete_group(id: &str) -> usize {
    let mut list = groups();
    let before = list.len();
    list.retain(|g| g.get("id").and_then(|x| x.as_str()).unwrap_or("") != id);
    save_groups(&list);
    remove_session(id);
    let _ = fs::remove_file(history_file(id));
    before - list.len()
}

fn history_file(key: &str) -> PathBuf {
    im_dir().join(format!("{key}.json"))
}

fn now_ts() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs_f64())
        .unwrap_or(0.0)
}

fn read_json(path: &PathBuf) -> Value {
    fs::read_to_string(path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or(Value::Null)
}

fn write_json(path: &PathBuf, v: &Value) {
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::write(path, v.to_string());
}

/// 会话列表
pub fn sessions() -> Vec<Value> {
    read_json(&sessions_file())
        .as_array()
        .cloned()
        .unwrap_or_default()
}

fn save_sessions(list: &[Value]) {
    write_json(&sessions_file(), &json!(list));
}

/// 某会话消息（含 read 已读字段）
pub fn messages(key: &str) -> Vec<Value> {
    read_json(&history_file(key)).as_array().cloned().unwrap_or_default()
}

pub fn append(key: &str, role: &str, content: &str) -> usize {
    let mut msgs = messages(key);
    let id = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_micros() as u64)
        .unwrap_or(0);
    let ts = now_ts();
    msgs.push(json!({
        "id": id, "role": role, "content": content,
        "ts": ts, "read": false,
    }));
    write_json(&history_file(key), &json!(msgs));
    // 维护会话列表：按 key 查找联系人名称与类型，upsert sessions.json
    upsert_session(key, role, content, msgs.len(), ts);
    msgs.len()
}

/// 更新/新建会话列表项（名称源于好友/群组表；未知 key 用 key 本身）
fn upsert_session(key: &str, role: &str, content: &str, msg_count: usize, ts: f64) {
    let mut is_group = key.starts_with("im_g_");
    let mut name = key.to_string();
    let mut avatar = String::new();
    if is_group {
        for g in groups() {
            if g.get("id").and_then(|v| v.as_str()).unwrap_or("") == key {
                name = g.get("name").and_then(|v| v.as_str()).unwrap_or(key).to_string();
                avatar = "群".to_string();
                break;
            }
        }
    } else {
        for f in friends() {
            if f.get("id").and_then(|v| v.as_str()).unwrap_or("") == key {
                name = f.get("name").and_then(|v| v.as_str()).unwrap_or(key).to_string();
                // 优先用本地照片路径（avatarPath），否则用 emoji/文字头像
                let path = f.get("avatarPath").and_then(|v| v.as_str()).unwrap_or("");
                avatar = if path.is_empty() {
                    f.get("avatar").and_then(|v| v.as_str()).unwrap_or("").to_string()
                } else {
                    path.to_string()
                };
                break;
            }
        }
    }
    // seed 会话（im_xiaoman 等）已在 sessions.json——仅 upsert
    let mut list = sessions();
    list.retain(|s| s.get("id").and_then(|v| v.as_str()).unwrap_or("") != key);
    list.push(json!({
        "id": key,
        "name": name,
        "kind": if is_group { "group" } else { "friend" },
        "avatar": if avatar.is_empty() {
            name.chars().next().map(|c| c.to_string()).unwrap_or_default()
        } else { avatar },
        "last": content,
        "ts": ts,
        "count": msg_count,
    }));
    save_sessions(&list);
}

pub fn replace(key: &str, msgs: &Value) -> usize {
    let list = msgs.as_array().cloned().unwrap_or_default();
    write_json(&history_file(key), &json!(list));
    list.len()
}

pub fn remove(key: &str, id: Option<u64>) -> Option<Value> {
    let mut msgs = messages(key);
    let before = msgs.len();
    if let Some(target) = id {
        msgs.retain(|m| m.get("id").and_then(|v| v.as_u64()).map(|i| i != target).unwrap_or(true));
    } else {
        msgs.pop();
    }
    let removed = before - msgs.len();
    write_json(&history_file(key), &json!(msgs));
    Some(json!({ "count": removed }))
}

pub fn clear(key: &str) -> Option<Value> {
    let n = messages(key).len();
    let _ = fs::remove_file(history_file(key));
    Some(json!({ "count": n }))
}

/// 预置 iMessage 风格演示会话（首次启动 seed）
pub fn seed_demo() -> usize {
    let mut sessions = Vec::new();
    let t = now_ts();

    fn msg(role: &str, content: &str, ts: f64, read: bool, id: u64) -> Value {
        json!({ "id": id, "role": role, "content": content, "ts": ts, "read": read })
    }

    // 会话 1：林小满（末条自己消息已读）
    {
        let key = "im_xiaoman";
        let msgs = vec![
            msg("assistant", "在忙吗？晚上一起吃饭？", t - 4200.0, true, 1),
            msg("user", "好呀，老地方？", t - 4100.0, true, 2),
            msg("assistant", "嗯！七点见～今天想喝那家新开的粥铺", t - 4050.0, true, 3),
            msg("user", "没问题，我定位置", t - 4000.0, true, 4),
            msg("assistant", "对了，明天方案评审你帮我看看吗", t - 800.0, true, 5),
            msg("user", "发我，晚上帮你看", t - 600.0, true, 6),
        ];
        write_json(&history_file(key), &json!(msgs));
        sessions.push(json!({
            "id": key, "name": "林小满", "kind": "friend",
            "avatar": "林", "last": "发我，晚上帮你看", "ts": t - 600.0,
        }));
    }

    // 会话 2：陈一诺（末条自己消息未读）
    {
        let key = "im_yinuo";
        let msgs = vec![
            msg("assistant", "新头像好看！哪拍的呀", t - 9000.0, true, 1),
            msg("user", "上周去海边拍的嘿嘿", t - 8900.0, true, 2),
            msg("assistant", "好羡慕，我也想去看海了", t - 8600.0, true, 3),
            msg("user", "下次一起！", t - 8500.0, true, 4),
            msg("assistant", "周末有空吗，陪我看展", t - 200.0, false, 5),
        ];
        write_json(&history_file(key), &json!(msgs));
        sessions.push(json!({
            "id": key, "name": "陈一诺", "kind": "friend",
            "avatar": "陈", "last": "周末有空吗，陪我看展", "ts": t - 200.0,
        }));
    }

    // 会话 3：李哲
    {
        let key = "im_lizhe";
        let msgs = vec![
            msg("assistant", "接口文档我更新了，记得看", t - 15000.0, true, 1),
            msg("user", "收到，晚点看", t - 14800.0, true, 2),
            msg("assistant", "今晚发版，有问题随时叫我", t - 7200.0, true, 3),
            msg("user", "辛苦了", t - 7000.0, true, 4),
        ];
        write_json(&history_file(key), &json!(msgs));
        sessions.push(json!({
            "id": key, "name": "李哲", "kind": "friend",
            "avatar": "李", "last": "辛苦了", "ts": t - 7000.0,
        }));
    }

    // 会话 4：群聊（周末爬山小分队）
    {
        let key = "im_hike";
        let msgs = vec![
            msg("assistant", "这周六去爬香山吗", t - 6000.0, true, 1),
            msg("user", "去去去！好久没运动了", t - 5900.0, true, 2),
            msg("assistant", "我也去，带点水果", t - 5800.0, true, 3),
            msg("user", "好，那周六早上八点北门集合！", t - 600.0, true, 4),
        ];
        write_json(&history_file(key), &json!(msgs));
        sessions.push(json!({
            "id": key, "name": "周末爬山小分队", "kind": "group",
            "avatar": "⛰", "last": "好，那周六早上八点北门集合！", "ts": t - 600.0,
        }));
    }

    save_sessions(&sessions);

    // 好友实体（微信风格联系人：头像字符/性别/简介）
    save_friends(&vec![
        json!({"id": "im_xiaoman", "name": "林小满", "gender": "female", "note": "产品经理 · 喜欢咖啡和猫", "avatar": "林"}),
        json!({"id": "im_yinuo", "name": "陈一诺", "gender": "female", "note": "设计师 · 追星女孩", "avatar": "陈"}),
        json!({"id": "im_lizhe", "name": "李哲", "gender": "male", "note": "后端工程师 · 夜猫子", "avatar": "李"}),
    ]);
    // 群组实体
    save_groups(&vec![
        json!({"id": "im_hike", "name": "周末爬山小分队", "memberIds": ["im_xiaoman", "im_yinuo", "im_lizhe"]}),
    ]);

    sessions.len()
}