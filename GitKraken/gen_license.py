#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_lic.py
用途：生成本地 license.dat 解密链路可解析的 raw JSON（用于测试/格式验证）
说明：仅生成 JSON，不做签名/加密，不用于解锁行为
"""

import argparse
import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List

ALLOWED_FEATURES = {
    "enterprise",
    "enterpriseTrial",
    "pro",
    "student",
    "advanced",
    "teamsLicense",
    "trial",
    "unregisteredTrial",
}

def dt_str(days: int | None = None) -> str:
    now = datetime.now(timezone.utc)
    if days is None:
        return now.isoformat()
    return (now + timedelta(days=days)).isoformat()

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate candidate raw license JSON for parsing tests")
    p.add_argument("--mode", choices=["minimal", "full"], default="full")
    p.add_argument("--out", type=str,required=True)
    p.add_argument("--indent", type=int, default=2)

    # 通用字段
    p.add_argument("--expires-at", default=(datetime.now(timezone.utc) + timedelta(days=365)).isoformat())
    p.add_argument("--guid", default=str(uuid.uuid4()))
    p.add_argument("--id", default=str(uuid.uuid4()))
    p.add_argument("--name", default="QA User")
    p.add_argument("--email", default="qa-user@example.com")
    p.add_argument("--status", default="activated")
    p.add_argument("--eula-version", default="8.3.1")
    p.add_argument("--login-type", default="username_and_password")

    # full 模式字段
    p.add_argument("--licensed-features", default="pro,advanced,teamsLicense")
    p.add_argument("--features", default="")
    p.add_argument("--available-trial-days", type=int, default=14)
    p.add_argument("--org-trial", action="store_true")
    p.add_argument("--org-trial-owner", action="store_true")
    p.add_argument("--can-create-org-trial", action="store_true")
    p.add_argument("--trial-start", default=dt_str(0))
    p.add_argument("--trial-end", default=dt_str(30))
    p.add_argument("--whitelist", default="")
    p.add_argument("--access-token", default="")
    return p.parse_args()

def build_minimal(args: argparse.Namespace) -> Dict[str, Any]:
    return {
        "expiresAt": args.expires_at,
    }

def build_full(args: argparse.Namespace) -> Dict[str, Any]:
    licensed_features = [x.strip() for x in args.licensed_features.split(",") if x.strip()]
    features = [x.strip() for x in args.features.split(",") if x.strip()]

    return {
        "expiresAt": args.expires_at,
        "guid": args.guid,
        "id": args.id,
        "status": args.status,
        "licenseExpiresAt": args.expires_at,
        "licensedFeatures": licensed_features,
        "features": features,
        "eulaVersion": args.eula_version,
        "loginType": args.login_type,
        "proAccessState": {
            "trial": {
                "isOrgTrial": bool(args.org_trial),
                "canCreateOrgTrial": bool(args.can_create_org_trial),
                "start": args.trial_start,
                "end": args.trial_end,
            }
        },
        "availableTrialDays": args.available_trial_days,
        "whitelist": None if args.whitelist == "" else args.whitelist,
        "isOrgTrialOwner": bool(args.org_trial_owner),
        "name": args.name,
        "email": args.email,
        "accessToken": args.access_token,
        "registration": {
            "status": args.status,
            "loginType": args.login_type,
            "name": args.name,
            "email": args.email,
            "EULA": {
                "status": "agree_verified",
                "version": args.eula_version,
            },
        },
    }

def validate_minimal(doc: Dict[str, Any]) -> List[str]:
    if "expiresAt" not in doc:
        return ["缺少必需字段: expiresAt"]
    return []

def validate_full(doc: Dict[str, Any]) -> List[str]:
    errs = validate_minimal(doc)
    lf = doc.get("licensedFeatures", [])
    if not isinstance(lf, list):
        errs.append("licensedFeatures 必须是数组")
    else:
        for v in lf:
            if not isinstance(v, str):
                errs.append(f"licensedFeatures 包含非字符串项: {v!r}")
            elif v not in ALLOWED_FEATURES:
                errs.append(f"未知 licensedFeatures: {v}")
    if "proAccessState" in doc and doc["proAccessState"] is not None:
        trial = doc["proAccessState"].get("trial", {})
        for k in ["isOrgTrial", "canCreateOrgTrial"]:
            if k in trial and not isinstance(trial[k], bool):
                errs.append(f"proAccessState.trial.{k} 必须是 boolean")
        for k in ["start", "end"]:
            if k in trial and not isinstance(trial[k], (str, int, type(None))):
                errs.append(f"proAccessState.trial.{k} 必须是 string/number/null")
    if args := doc.get("status"):
        if not isinstance(args, str):
            errs.append("status 必须是字符串")
    return errs

def main():
    args = parse_args()
    if args.mode == "minimal":
        doc = build_minimal(args)
        errors = validate_minimal(doc)
    else:
        doc = build_full(args)
        errors = validate_full(doc)

    if errors:
        print("[INVALID]")
        for e in errors:
            print(f" - {e}")
        raise SystemExit(1)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=args.indent)
        f.write("\n")
    

    print(f"[OK] 已生成: {args.out}")
    print(f"[MODE] {args.mode}")
    print("[NOTE] 仅生成原始 JSON，不包含加密/签名。")

if __name__ == "__main__":
    main()