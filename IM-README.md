# Kelivo — iMessage 风格即时通讯 App（Flutter + Rust）

在 Kelivo（Flutter LLM Chat Client）基础上改造的 **iMessage 风格即时通讯 App**：
新增 **Rust Core**（FFI JSON 总线：消息存储/数据处理/安全模块）与
**iMessage 原生 UI**（蓝/灰气泡、已读状态、会话列表、附件菜单、毛玻璃导航）。

## 一、项目结构

```
kelivo/
├── lib/
│   ├── features/im/                 # ★ 新增：iMessage 即时通讯模块
│   │   ├── im_bridge.dart           # Flutter ↔ Rust 通信（C FFI dlsym JSON 总线）
│   │   ├── im_store.dart            # KelivoStore：会话/消息/数据处理/安全 API
│   │   └── pages/
│   │       ├── im_session_list_page.dart  # 会话列表（头像/名称/最后消息/时间）
│   │       └── im_chat_page.dart          # 聊天页（蓝/灰气泡/已读/时间/输入/附件）
│   ├── features/home/pages/home_mobile_layout.dart
│   │                               # 底部毛玻璃导航 3 tab：消息(IM) / 聊天 / 设置
│   └── …（kelivo 原有模块保留）
├── native/kelivo_core/               # ★ 新增：Rust Core（crate）
│   ├── Cargo.toml                    # 依赖：serde_json / sha2
│   └── src/
│       ├── lib.rs                    # FFI 入口 kelivo_call / kelivo_free + 方法分发
│       ├── store.rs                  # 会话/消息 JSON 存储 + 首次启动 seed 演示数据
│       ├── crypto.rs                 # 安全模块：sha256 / blake2s / crc32
│       └── util.rs                   # 数据处理：文本统计 / 表达式求值 / base64
├── ios/Flutter/Workspace.xcconfig    # -lkelivo_core -force_load 链接
└── .github/workflows/build-ios.yml   # CI：Rust 编译 + flutter build → ipa → Release
```

## 二、Flutter ↔ Rust 通信示例（C FFI JSON 总线）

Rust 侧（`native/kelivo_core/src/lib.rs`）：

```rust
/// 入参：{"method":"store.messages","params":{"key":"im_xiaoman"}}
/// 出参：{"ok":true,"data":{"messages":[...]}}
#[no_mangle]
pub extern "C" fn kelivo_call(payload: *const c_char) -> *mut c_char {
    let input = unsafe { CStr::from_ptr(payload) }.to_string_lossy().to_string();
    let (method, params) = parse(&input);
    let out = match dispatch(&method, &params) {
        Some(data) => ok_envelope(data),
        None => err_envelope(&method),
    };
    CString::new(out).unwrap().into_raw()
}
```

Dart 侧（`lib/features/im/im_bridge.dart`）：

```dart
final _call = DynamicLibrary.process()
    .lookupFunction<Pointer<Utf8> Function(Pointer<Utf8>),
                     Pointer<Utf8> Function(Pointer<Utf8>)>('kelivo_call');

static Map<String, dynamic> call(String method, Map<String, dynamic> params) {
  final out = _call(_toUtf8(jsonEncode({'method': method, 'params': params})));
  return jsonDecode(out.cast<Utf8>().toDartString())['data'];
}
```

调用示例（`im_store.dart`）：

```dart
// 会话与消息（Rust 存储）
final sessions = KelivoStore.sessions();                    // → store.sessions
final msgs = KelivoStore.messages('im_xiaoman');            // → store.messages
KelivoStore.append(key, 'user', '你好');                    // → store.append
KelivoStore.replace(key, msgs);                             // → store.replace（写 read 标记）

// 数据处理与安全模块（Rust 执行）
final stats = KelivoStore.textStats('hello 你好');          // → util.text_stats
KelivoStore.eval('12*(3+4)^2');                             // → util.eval
KelivoStore.sha256('hi');                                   // → crypto.sha256
KelivoStore.blake2s('hi');                                  // → crypto.blake2s（RFC7693 纯 Rust）
KelivoStore.crc32('hi');                                    // → crypto.crc32
```

## 三、模拟聊天数据

首次进入「消息」tab 自动通过 Rust seed（`store.seed_demo`）生成 4 个会话：

| 会话 | 消息 | 已读 |
|---|---|---|
| 林小满 | 6 条（约饭/帮看方案） | 末条自己消息**已读** |
| 陈一诺 | 5 条（头像/看展） | 末条**未读（已送达）** |
| 李哲 | 4 条（接口文档/发版） | 已读 |
| 周末爬山小分队（群） | 4 条 | 已读 |

数据全部经 Rust 持久化（沙盒 `im/*.json`），支持发送（含模拟回复）、图片附件、已读标记、清空会话。

## 四、iMessage UI 实现要点

- **气泡**：我方 `#007AFF` 蓝 / 对方 `#E5E5EA` 灰（深色模式 `#26262A`），不对称圆角（18/4）
- **已读状态**：气泡下方「已读」（绿 `#34C759`）/「已送达」
- **会话列表**：圆头像（群=绿）、名称、最后消息省略、右侧时间
- **附件菜单**：照片/拍照（image_picker），图片真实发送并持久化
- **底部导航**：Liquid Glass 毛玻璃 3 tab（26px 模糊 + 半透明白 78% + 白细边框 + 圆角 26 + 胶囊选中态）
- **配色**：苹果白 `#FFFFFF/#F5F5F7/#1D1D1F/#86868B` + 系统蓝 `#007AFF`，支持深色模式，无渐变

## 五、iOS 编译部署

```bash
# 1) Rust Core（静态库）
rustup toolchain install 1.84.1 --target aarch64-apple-ios --profile minimal
cargo build --release --target aarch64-apple-ios \
    --manifest-path native/kelivo_core/Cargo.toml
cp native/kelivo_core/target/aarch64-apple-ios/release/libkelivo_core.a \
   ios/sandbox/build/iphoneos/   # 与 libish.a 同目录（xcconfig 已配搜索路径+force_load）

# 2) iOS 工程（kelivo 自带 ios/）
flutter build ios --release --no-codesign

# 3) 打包
cd build/ios/iphoneos && mkdir Payload && cp -R Runner.app Payload/
zip -r Kelivo.ipa Payload
```

**CI 自动构建**（push master 触发）：`build-ios.yml` —— Rust 编译 → iSH 沙箱产物 →
flutter build → 打包 ipa → 自动 Release（kelivo-build-N）。