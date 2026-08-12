import os
import struct
import sys

ELF_PT_LOAD = 1
PAGE16K = 0x4000

def fix_alignment(filepath):
    with open(filepath, 'r+b') as f:
        ident = f.read(16)
        if ident[:4] != b'\x7fELF':
            raise ValueError("Not an ELF file")
        is_64 = ident[4] == 2

        if is_64:
            f.seek(0x20)
            phoff = struct.unpack('<Q', f.read(8))[0]
            f.seek(0x38)
            phnum = struct.unpack('<H', f.read(2))[0]
            ph_size = 56
            align_off = 48
            pack_fmt = '<Q'
        else:
            f.seek(0x1C)
            phoff = struct.unpack('<I', f.read(4))[0]
            f.seek(0x2C)
            phnum = struct.unpack('<H', f.read(2))[0]
            ph_size = 32
            align_off = 28
            pack_fmt = '<I'

        f.seek(phoff)
        headers = []
        for _ in range(phnum):
            data = f.read(ph_size)
            if len(data) < ph_size:
                break
            p_type = struct.unpack('<I', data[0:4])[0]
            p_align = struct.unpack(pack_fmt, data[align_off:align_off + (8 if is_64 else 4)])[0]
            headers.append({'type': p_type, 'align': p_align, 'data': data})

        modified = False
        for h in headers:
            if h['type'] == ELF_PT_LOAD and h['align'] < PAGE16K:
                old_align = h['align']
                h['align'] = PAGE16K
                # Rewrite p_align in the header data
                hdr = h['data']
                new_align_bytes = struct.pack(pack_fmt, PAGE16K)
                hdr = hdr[:align_off] + new_align_bytes + hdr[align_off + len(new_align_bytes):]
                h['data'] = hdr
                modified = True
                print(f"  Fixed LOAD segment: align 0x{old_align:X} -> 0x{PAGE16K:X}")

        if modified:
            f.seek(phoff)
            for h in headers:
                f.write(h['data'])
            print(f"  [OK] Alignment patched to 16 KB")
            return True
        else:
            print(f"  [OK] Already 16 KB aligned")
            return True


def process_dir(path):
    for root, dirs, files in os.walk(path):
        for fn in files:
            if fn.endswith('.so') and fn != 'libflutter.so':
                fp = os.path.join(root, fn)
                sz = os.path.getsize(fp)
                if sz < 1000:
                    continue
                print(f"\nChecking: {os.path.relpath(fp, path)}")
                try:
                    fix_alignment(fp)
                except Exception as e:
                    print(f"  Error: {e}")


if __name__ == '__main__':
    if len(sys.argv) > 1:
        target = sys.argv[1]
        if os.path.isdir(target):
            process_dir(target)
        elif os.path.isfile(target):
            fix_alignment(target)
        else:
            print(f"Path not found: {target}")
    else:
        print("Usage: fix_elf_alignment.py <path_to_so_or_dir>")
