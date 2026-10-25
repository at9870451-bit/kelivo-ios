// util.rs — 数据处理：文本统计 / 表达式求值 / base64
const B64: &[u8; 64] =
    b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

pub fn base64(op: &str, data: &str) -> String {
    match op {
        "encode" => {
            let bytes = data.as_bytes();
            let mut out = String::new();
            let mut i = 0;
            while i < bytes.len() {
                let a = bytes[i];
                let b = if i + 1 < bytes.len() { bytes[i + 1] } else { 0 };
                let c = if i + 2 < bytes.len() { bytes[i + 2] } else { 0 };
                out.push(B64[(a >> 2) as usize] as char);
                out.push(B64[(((a & 3) << 4) | (b >> 4)) as usize] as char);
                out.push(if i + 1 < bytes.len() { B64[(((b & 15) << 2) | (c >> 6)) as usize] as char } else { '=' });
                out.push(if i + 2 < bytes.len() { B64[(c & 63) as usize] as char } else { '=' });
                i += 3;
            }
            out
        }
        "decode" => {
            let mut vals = Vec::with_capacity(data.len());
            for ch in data.chars() {
                if ch == '=' {
                    break;
                }
                if let Some(pos) = B64.iter().position(|&b| b == ch as u8) {
                    vals.push(pos as u8);
                }
            }
            let mut out = Vec::new();
            let mut i = 0;
            while i + 3 < vals.len() {
                let a = vals[i] << 2 | vals[i + 1] >> 4;
                let b = (vals[i + 1] & 15) << 4 | vals[i + 2] >> 2;
                let c = (vals[i + 2] & 3) << 6 | vals[i + 3];
                out.push(a);
                out.push(b);
                out.push(c);
                i += 4;
            }
            // 剩余不足 4 位组
            let rest = vals.len() - i;
            if rest >= 2 {
                let a = vals[i] << 2 | vals[i + 1] >> 4;
                out.push(a);
                if rest >= 3 {
                    out.push((vals[i + 1] & 15) << 4 | vals[i + 2] >> 2);
                }
            }
            String::from_utf8_lossy(&out).to_string()
        }
        _ => "用法：util.base64 encode|decode".to_string(),
    }
}

/// 文本统计：字符（不含空白）/ 总字符 / 词语 / 段落 / 行
pub fn text_stats(text: &str) -> serde_json::Value {
    let chars_no_ws = text.chars().filter(|c| !c.is_whitespace()).count();
    let words = text.split_whitespace().count();
    let paras = text
        .split("\n\n")
        .filter(|p| !p.trim().is_empty())
        .count();
    let lines = if text.is_empty() { 0 } else { text.lines().count() };
    serde_json::json!({
        "chars": chars_no_ws,
        "chars_total": text.chars().count(),
        "words": words,
        "paragraphs": paras,
        "lines": lines,
    })
}

/// 表达式求值（递归下降：+ - * / % ^ ( ) 与 sin cos sqrt abs round floor ceil）
pub fn eval(expr: &str) -> Result<f64, String> {
    let tokens = tokenize(expr)?;
    if tokens.is_empty() {
        return Err("表达式为空".into());
    }
    let mut p = Parser { t: &tokens, pos: 0 };
    let v = p.add()?;
    if p.pos < tokens.len() {
        return Err(format!("表达式有多余内容：{}", tokens[p.pos]));
    }
    Ok(v)
}

fn tokenize(expr: &str) -> Result<Vec<String>, String> {
    let mut out = Vec::new();
    let mut buf = String::new();
    let mut i = 0;
    let chars: Vec<char> = expr.chars().collect();
    while i < chars.len() {
        let c = chars[i];
        if c.is_whitespace() {
            i += 1;
            continue;
        }
        if c.is_ascii_digit() || c == '.' {
            buf.clear();
            while i < chars.len() && (chars[i].is_ascii_digit() || chars[i] == '.') {
                buf.push(chars[i]);
                i += 1;
            }
            out.push(buf.clone());
            continue;
        }
        if "+-*/%^()".contains(c) {
            out.push(c.to_string());
            i += 1;
            continue;
        }
        if c.is_alphabetic() {
            buf.clear();
            while i < chars.len() && chars[i].is_alphabetic() {
                buf.push(chars[i]);
                i += 1;
            }
            out.push(buf.clone());
            continue;
        }
        return Err(format!("无法识别的字符「{c}」"));
    }
    Ok(out)
}

struct Parser<'a> {
    t: &'a [String],
    pos: usize,
}

impl<'a> Parser<'a> {
    fn add(&mut self) -> Result<f64, String> {
        let mut v = self.mul()?;
        while self.pos < self.t.len() {
            let k = self.t[self.pos].as_str();
            if k == "+" {
                self.pos += 1;
                v += self.mul()?;
            } else if k == "-" {
                self.pos += 1;
                v -= self.mul()?;
            } else {
                break;
            }
        }
        Ok(v)
    }

    fn mul(&mut self) -> Result<f64, String> {
        let mut v = self.unary()?;
        while self.pos < self.t.len() {
            let k = self.t[self.pos].as_str();
            if k == "*" {
                self.pos += 1;
                v *= self.unary()?;
            } else if k == "/" {
                self.pos += 1;
                v /= self.unary()?;
            } else if k == "%" {
                self.pos += 1;
                v %= self.unary()?;
            } else if k == "^" {
                self.pos += 1;
                v = v.powf(self.unary()?);
            } else {
                break;
            }
        }
        Ok(v)
    }

    fn unary(&mut self) -> Result<f64, String> {
        if self.pos < self.t.len() && self.t[self.pos] == "-" {
            self.pos += 1;
            return Ok(-self.unary()?);
        }
        if self.pos < self.t.len() && self.t[self.pos] == "+" {
            self.pos += 1;
            return self.unary();
        }
        self.atom()
    }

    fn atom(&mut self) -> Result<f64, String> {
        if self.pos >= self.t.len() {
            return Err("表达式不完整".into());
        }
        let k = self.t[self.pos].clone();
        if k == "(" {
            self.pos += 1;
            let v = self.add()?;
            if self.pos >= self.t.len() || self.t[self.pos] != ")" {
                return Err("缺少右括号".into());
            }
            self.pos += 1;
            return Ok(v);
        }
        // 函数调用
        const FNS: [(&str, fn(f64) -> f64); 7] = [
            ("sin", f64::sin),
            ("cos", f64::cos),
            ("sqrt", f64::sqrt),
            ("abs", f64::abs),
            ("round", f64::round),
            ("floor", f64::floor),
            ("ceil", f64::ceil),
        ];
        for (name, f) in FNS {
            if k == name {
                self.pos += 1;
                if self.pos >= self.t.len() || self.t[self.pos] != "(" {
                    return Err(format!("函数 {name} 后需要 ("));
                }
                self.pos += 1;
                let arg = self.add()?;
                if self.pos >= self.t.len() || self.t[self.pos] != ")" {
                    return Err(format!("函数 {name} 缺少右括号"));
                }
                self.pos += 1;
                return Ok(f(arg));
            }
        }
        k.parse::<f64>()
            .map_err(|_| format!("无法解析「{k}」（支持数字与 + - * / % ^ 及函数）"))
    }
}