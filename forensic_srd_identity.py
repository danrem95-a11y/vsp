# -*- coding: utf-8 -*-
"""
Produces an exact identity fingerprint for a .srd file, so we can be certain the file
being analyzed is byte-for-byte the same file being handed to PowerBuilder.
"""
import sys
import hashlib
import re


def fingerprint(path):
    with open(path, 'rb') as fh:
        raw = fh.read()

    sha256 = hashlib.sha256(raw).hexdigest()
    bom = raw[:2]
    encoding = 'utf-16-le' if bom == b'\xff\xfe' else ('utf-16-be' if bom == b'\xfe\xff' else 'unknown/no-BOM')

    text = raw.decode('utf-16') if bom in (b'\xff\xfe', b'\xfe\xff') else raw.decode('utf-8', errors='replace')
    crlf_count = text.count('\r\n')
    lf_only = sum(1 for i, c in enumerate(text) if c == '\n' and (i == 0 or text[i - 1] != '\r'))
    lines = text.split('\r\n')

    print("=" * 60)
    print("FILE IDENTITY:", path)
    print("=" * 60)
    print("Absolute path      :", __import__('os').path.abspath(path))
    print("Bytes              :", len(raw))
    print("SHA-256            :", sha256)
    print("BOM                :", bom.hex())
    print("Encoding           :", encoding)
    print("CRLF line breaks   :", crlf_count)
    print("Bare-LF line breaks:", lf_only)
    print("Total lines (\\r\\n split):", len(lines))
    print()

    for target_line in (73,):
        if target_line - 1 < len(lines):
            l = lines[target_line - 1]
            print(f"--- LINE {target_line} (exists, length={len(l)}) ---")
            print(l)
            if len(l) >= 33:
                print()
                print(f"Character 33: {l[32]!r}")
                lo = max(0, 32 - 20)
                hi = min(len(l), 32 + 21)
                print(f"Context [{lo}:{hi}]: {l[lo:hi]!r}")
            else:
                print(f"Line {target_line} has only {len(l)} characters -- column 33 DOES NOT EXIST on this line.")
        else:
            print(f"--- LINE {target_line} DOES NOT EXIST -- file only has {len(lines)} lines ---")
        print()

    return {
        'path': path, 'bytes': len(raw), 'sha256': sha256, 'bom': bom.hex(),
        'encoding': encoding, 'total_lines': len(lines),
    }


if __name__ == '__main__':
    paths = sys.argv[1:] if len(sys.argv) > 1 else [
        'dw_rpt_is_flat_multibulan01.srd',
        'forensic_bisect/bisect_1_skeleton.srd',
        'forensic_bisect/bisect_7_plus_summary.srd',
    ]
    results = [fingerprint(p) for p in paths]

    print("=" * 60)
    print("CROSS-FILE COMPARISON")
    print("=" * 60)
    for r in results:
        print(r['path'], '-> lines=', r['total_lines'], 'sha256=', r['sha256'][:16] + '...')
