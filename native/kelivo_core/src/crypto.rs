// crypto.rs — 安全模块：sha256 / blake2s / crc32（消息摘要与完整性校验）
use sha2::{Digest, Sha256};

/// SHA-256 hex（sha2 crate）
pub fn sha256_hex(data: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(data);
    let d = h.finalize();
    let mut out = String::with_capacity(64);
    for b in d {
        out.push_str(&format!("{b:02x}"));
    }
    out
}

/// CRC32（IEEE 802.3，查表）
fn crc_table() -> [u32; 256] {
    let mut t = [0u32; 256];
    let mut i = 0;
    while i < 256 {
        let mut c = i as u32;
        let mut k = 0;
        while k < 8 {
            c = if c & 1 != 0 { 0xEDB88320 ^ (c >> 1) } else { c >> 1 };
            k += 1;
        }
        t[i] = c;
        i += 1;
    }
    t
}

pub fn crc32_hex(data: &[u8]) -> String {
    let table = crc_table();
    let mut c = 0xFFFFFFFFu32;
    for &b in data {
        c = table[((c ^ b as u32) & 0xFF) as usize] ^ (c >> 8);
    }
    format!("{:08x}", c ^ 0xFFFFFFFF)
}

/// BLAKE2s-256（RFC 7693，纯 Rust 实现；空消息补一块、输出小端）
struct Blake2s {
    h: [u32; 8],
}

const IV: [u32; 8] = [
    0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A, 0x510E527F, 0x9B05688C,
    0x1F83D9AB, 0x5BE0CD19,
];

const SIGMA: [[usize; 16]; 10] = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
    [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
    [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
    [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
    [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
    [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
    [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
    [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
    [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0],
];

impl Blake2s {
    fn new() -> Self {
        let mut h = IV;
        h[0] ^= 0x01010000 ^ 32; // keylen=0, outlen=32
        Blake2s { h }
    }

    fn compress(&mut self, block: &[u8], block_count: usize, n: usize, is_last: bool) {
        let t0 = (64 * block_count).min(n) as u32;
        let mut v = [0u32; 16];
        v[..8].copy_from_slice(&self.h);
        v[8..].copy_from_slice(&IV);
        v[12] ^= t0;
        if is_last {
            v[14] ^= 0xFFFFFFFF;
        }
        let mut m = [0u32; 16];
        for i in 0..16 {
            m[i] = u32::from_le_bytes([
                block[i * 4],
                block[i * 4 + 1],
                block[i * 4 + 2],
                block[i * 4 + 3],
            ]);
        }
        let rotr = |x: u32, n: u32| -> u32 { (x >> n) | (x << (32 - n)) };
        for r in 0..10 {
            let s = SIGMA[r];
            macro_rules! g {
                ($a:expr, $b:expr, $c:expr, $d:expr, $x:expr, $y:expr) => {
                    v[$a] = v[$a].wrapping_add(v[$b]).wrapping_add($x);
                    v[$d] = rotr(v[$d] ^ v[$a], 16);
                    v[$c] = v[$c].wrapping_add(v[$d]);
                    v[$b] = rotr(v[$b] ^ v[$c], 12);
                    v[$a] = v[$a].wrapping_add(v[$b]).wrapping_add($y);
                    v[$d] = rotr(v[$d] ^ v[$a], 8);
                    v[$c] = v[$c].wrapping_add(v[$d]);
                    v[$b] = rotr(v[$b] ^ v[$c], 7);
                };
            }
            g!(0, 4, 8, 12, m[s[0]], m[s[1]]);
            g!(1, 5, 9, 13, m[s[2]], m[s[3]]);
            g!(2, 6, 10, 14, m[s[4]], m[s[5]]);
            g!(3, 7, 11, 15, m[s[6]], m[s[7]]);
            g!(0, 5, 10, 15, m[s[8]], m[s[9]]);
            g!(1, 6, 11, 12, m[s[10]], m[s[11]]);
            g!(2, 7, 8, 13, m[s[12]], m[s[13]]);
            g!(3, 4, 9, 14, m[s[14]], m[s[15]]);
        }
        for i in 0..8 {
            self.h[i] ^= v[i] ^ v[i + 8];
        }
    }

    fn finalize_hex(mut self, data: &[u8]) -> String {
        let n = data.len();
        let mut block = [0u8; 64];
        let mut padded = Vec::with_capacity(((n + 63) / 64).max(1) * 64);
        padded.extend_from_slice(data);
        while padded.len() == 0 || padded.len() % 64 != 0 {
            padded.push(0);
        }
        let blocks = padded.len() / 64;
        for bi in 0..blocks {
            block.copy_from_slice(&padded[bi * 64..bi * 64 + 64]);
            let is_last = bi == blocks - 1;
            self.compress(&block, bi + 1, n, is_last);
        }
        let mut out = String::with_capacity(64);
        for w in self.h {
            out.push_str(&format!("{:02x}{:02x}{:02x}{:02x}",
                w & 0xFF, (w >> 8) & 0xFF, (w >> 16) & 0xFF, (w >> 24) & 0xFF));
        }
        out
    }
}

/// BLAKE2s-256 hex（小端输出）
pub fn blake2s_hex(data: &[u8]) -> String {
    Blake2s::new().finalize_hex(data)
}