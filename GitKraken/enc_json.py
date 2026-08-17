#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
license_dat_codec.py
- decode: dat -> json
- encode: json -> dat
Format:
  raw bytes -> gzip -> reverse -> tar(blocks/*) -> RSA raw block transform
"""

from __future__ import annotations

import argparse
import io
import json
import os
import re
import tarfile
import gzip
from pathlib import Path
from typing import Iterable, List, Optional

from cryptography.hazmat.primitives import serialization


class KeyMaterial:
    def __init__(self, n: int, e: int, d: Optional[int] = None):
        self.n = n
        self.e = e
        self.d = d
        self.k = (n.bit_length() + 7) // 8  # modulus bytes

    @classmethod
    def from_private_pem(cls, pem_path: str, password: Optional[str] = None) -> "KeyMaterial":
        key_bytes = Path(pem_path).read_bytes()
        key = serialization.load_pem_private_key(
            key_bytes, password=password.encode() if password else None
        )
        nums = key.private_numbers()
        return cls(nums.public_numbers.n, nums.public_numbers.e, nums.d)

    @classmethod
    def from_public_pem(cls, pem_path: str) -> "KeyMaterial":
        key_bytes = Path(pem_path).read_bytes()
        key = serialization.load_pem_public_key(key_bytes)
        nums = key.public_numbers()
        return cls(nums.n, nums.e, None)


def _i2osp(x: int, k: int) -> bytes:
    if x < 0 or x >= (1 << (8 * k)):
        raise ValueError("integer too large for I2OSP")
    return x.to_bytes(k, byteorder="big")


def _pkcs1_pad(data: bytes, k: int, block_type: int = 0x01) -> bytes:
    """
    PKCS#1 v1.5 padding:
      0x00 || BT || PS || 0x00 || M
    BT=0x01 for RSA private "sign" style, BT=0x02 for RSA public "encrypt" style.
    """
    if len(data) > k - 11:
        raise ValueError(f"message too long: {len(data)} > {k-11}")
    ps_len = k - len(data) - 3
    if block_type == 0x01:
        ps = b"\xFF" * ps_len
    elif block_type == 0x02:
        # non-zero random bytes
        ps = bytearray()
        while len(ps) < ps_len:
            b = os.urandom(1)
            if b != b"\x00":
                ps += b
        ps = bytes(ps)
    else:
        raise ValueError("block_type must be 0x01 or 0x02")

    return b"\x00" + bytes([block_type]) + ps + b"\x00" + data


def _pkcs1_unpad(em: bytes) -> bytes:
    if len(em) < 11:
        raise ValueError("decrypted block too short")
    if em[0] != 0x00 or em[1] not in (0x01, 0x02):
        raise ValueError("invalid block prefix")
    # find separator 0x00
    sep = em.find(b"\x00", 2)
    if sep == -1 or sep < 10:
        raise ValueError("invalid padding: separator not found")
    # 0x01 的填充必须全是 0xFF，0x02 的填充必须全非 0x00
    bt = em[1]
    if bt == 0x01 and any(x != 0xFF for x in em[2:sep]):
        raise ValueError("invalid 0x01 padding")
    if bt == 0x02 and any(x == 0x00 for x in em[2:sep]):
        raise ValueError("invalid 0x02 padding")
    return em[sep + 1 :]


def rsa_private_transform_block(key: KeyMaterial, plain_block: bytes) -> bytes:
    if key.d is None:
        raise ValueError("private key required")
    padded = _pkcs1_pad(plain_block, key.k, block_type=0x01)
    m = int.from_bytes(padded, "big")
    c = pow(m, key.d, key.n)  # raw RSA (private exponent)
    return _i2osp(c, key.k)


def rsa_public_recover_block(key: KeyMaterial, enc_block: bytes) -> bytes:
    if len(enc_block) != key.k:
        raise ValueError(f"cipher block size mismatch: {len(enc_block)} != {key.k}")
    c = int.from_bytes(enc_block, "big")
    em_int = pow(c, key.e, key.n)  # raw RSA (public exponent)
    em = _i2osp(em_int, key.k)
    return _pkcs1_unpad(em)


def _split_chunks(data: bytes, chunk: int) -> Iterable[bytes]:
    for i in range(0, len(data), chunk):
        yield data[i : i + chunk]


def encode_json_to_dat(raw_json: dict, pub_key: Optional[str], priv_key: Optional[str], password: Optional[str] = None) -> bytes:
    """
    raw_json -> license.bin payload bytes -> tar(blocks) -> gzip -> reverse -> dat
    """
    if priv_key is None:
        raise ValueError("encode requires a private key")

    plaintext = json.dumps(raw_json, ensure_ascii=False).encode("utf-8")
    key = KeyMaterial.from_private_pem(priv_key, password=password)
    block_size = key.k - 11

    enc_blocks: List[bytes] = []
    for idx, chunk in enumerate(_split_chunks(plaintext, block_size)):
        enc_blocks.append(rsa_private_transform_block(key, chunk))

    # Build tar with members blocks/0, blocks/1, ...
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w") as tf:
        for i, block in enumerate(enc_blocks):
            name = f"blocks/{i}"
            ti = tarfile.TarInfo(name)
            ti.size = len(block)
            ti.mtime = 0
            ti.mode = 0o600
            ti.type = tarfile.REGTYPE
            tf.addfile(ti, io.BytesIO(block))

    packed = buf.getvalue()
    gz = gzip.compress(packed)
    return gz[::-1]


def decode_dat_to_json(dat_path: str, pub_key_path: str) -> dict:
    dat = Path(dat_path).read_bytes()
    key = KeyMaterial.from_public_pem(pub_key_path)

    # reverse -> gzip -> tar
    tar_bytes = gzip.decompress(dat[::-1])

    blocks = []
    with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:") as tf:
        members = [m for m in tf.getmembers() if m.isfile() and m.name.startswith("blocks/")]
        # names: blocks/0, blocks/1 ...
        def sort_key(m):
            m2 = re.fullmatch(r"blocks/(\d+)$", m.name)
            return int(m2.group(1)) if m2 else 10**9
        members.sort(key=sort_key)

        for m in members:
            fp = tf.extractfile(m)
            if fp is None:
                raise ValueError(f"cannot read tar member {m.name}")
            enc_block = fp.read()
            plain = rsa_public_recover_block(key, enc_block)
            blocks.append(plain)

    payload = b"".join(blocks)
    return json.loads(payload.decode("utf-8"))


def cmd_encode(args):
    key = KeyMaterial.from_private_pem(args.private_key, password=args.password)
    with open(args.input_json, "r", encoding="utf-8") as f:
        raw_json = json.load(f)

    block_size = key.k - 11
    plaintext = json.dumps(raw_json, ensure_ascii=False).encode("utf-8")
    enc_blocks = [
        rsa_private_transform_block(key, chunk) for chunk in _split_chunks(plaintext, block_size)
    ]

    tar_buf = io.BytesIO()
    with tarfile.open(fileobj=tar_buf, mode="w") as tf:
        for i, block in enumerate(enc_blocks):
            name = f"blocks/{i}"
            info = tarfile.TarInfo(name)
            info.size = len(block)
            info.mtime = 0
            info.mode = 0o600
            tf.addfile(info, io.BytesIO(block))

    out_dat = gzip.compress(tar_buf.getvalue())[::-1]
    Path(args.output_dat).write_bytes(out_dat)
    print(f"wrote: {args.output_dat} ({len(out_dat)} bytes, blocks={len(enc_blocks)})")


def cmd_decode(args):
    dat = Path(args.input_dat).read_bytes()
    key = KeyMaterial.from_public_pem(args.public_key)
    payload_gz = gzip.decompress(dat[::-1])

    with tarfile.open(fileobj=io.BytesIO(payload_gz), mode="r:") as tf:
        members = [m for m in tf.getmembers() if m.isfile() and m.name.startswith("blocks/")]
        members.sort(key=lambda m: int(re.fullmatch(r"blocks/(\\d+)$", m.name).group(1)))

        chunks: list[bytes] = []
        for m in members:
            fp = tf.extractfile(m)
            if fp is None:
                raise ValueError(f"cannot read {m.name}")
            enc = fp.read()
            chunks.append(rsa_public_recover_block(key, enc))

    plaintext = b"".join(chunks).decode("utf-8")
    raw = json.loads(plaintext)

    if args.output_json:
        Path(args.output_json).write_text(json.dumps(raw, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"wrote: {args.output_json}")
    else:
        print(json.dumps(raw, ensure_ascii=False, indent=2))


def main():
    parser = argparse.ArgumentParser(description="license.dat codec")
    sub = parser.add_subparsers(dest="mode", required=True)

    p1 = sub.add_parser("decode", help="dat -> json")
    p1.add_argument("input_dat", help="license.dat path")
    p1.add_argument("--public-key", required=True, help="public_key.pem")
    p1.add_argument("--output-json", help="optional json output path")
    p1.set_defaults(func=cmd_decode)

    p2 = sub.add_parser("encode", help="json -> dat")
    p2.add_argument("input_json", help="raw.json path")
    p2.add_argument("output_dat", help="license.dat output path")
    p2.add_argument("--private-key", required=True, help="private_key.pem")
    p2.add_argument("--password", help="private key password (if needed)")
    p2.set_defaults(func=cmd_encode)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()