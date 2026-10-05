"""Set the icon/version strings of a .NET single-file apphost without
breaking its appended bundle: edit only the PE image with rcedit, then
re-append the bundle and shift every absolute offset in its manifest."""
import struct, subprocess, sys, os
src, ico, rcedit, dst = sys.argv[1:5]
d = open(src, 'rb').read()
L = len(d)
# Placeholder in the apphost: int64 header offset followed by the bundle signature.
ph = hdr = None
pe_end = None
import re
for m in re.finditer(re.escape(bytes.fromhex('8b1202b96a612038727b930214d7a032')), d):
    i = m.start() - 8
    v = struct.unpack_from('<q', d, i)[0]
    if 0 < v < L and struct.unpack_from('<I', d, v)[0] == 6:
        ph, hdr = i, v; break
assert ph, 'bundle header not found'
# PE end = end of last section's raw data.
e_lfanew = struct.unpack_from('<I', d, 0x3c)[0]
nsec = struct.unpack_from('<H', d, e_lfanew + 6)[0]
optsz = struct.unpack_from('<H', d, e_lfanew + 20)[0]
sec0 = e_lfanew + 24 + optsz
pe_end = max(struct.unpack_from('<II', d, sec0 + 40*k + 16)[1] + struct.unpack_from('<II', d, sec0 + 40*k + 16)[0] for k in range(nsec))
overlay = d[pe_end:]
tmp = dst + '.pe.exe'
open(tmp, 'wb').write(d[:pe_end])
subprocess.check_call([rcedit, tmp, '--set-icon', ico,
    '--set-version-string', 'FileDescription', 'Duo Desktop',
    '--set-version-string', 'ProductName', 'Duo Desktop'])
pe = bytearray(open(tmp, 'rb').read()); os.remove(tmp)
delta = len(pe) - pe_end
pad = (-delta) % 4096          # keep bundled files on their original 4K alignment
pe += b'\0' * pad; delta += pad
out = bytearray(pe) + overlay
# Fix placeholder (search again: .data may have moved if rcedit reordered sections).
sigtail = d[ph:ph+40]
j = out.find(sigtail); assert j >= 0, 'placeholder lost'
struct.pack_into('<q', out, j, hdr + delta)
pos = hdr + delta
maj, mino, cnt = struct.unpack_from('<IIi', out, pos); pos += 12
def skipstr(p):
    n = s = 0
    while True:
        b = out[p]; p += 1; n |= (b & 0x7f) << s; s += 7
        if b < 0x80: return p + n
pos = skipstr(pos)
for k in range(2):              # deps.json, runtimeconfig.json (offset, size)
    o = struct.unpack_from('<q', out, pos)[0]
    if o: struct.pack_into('<q', out, pos, o + delta)
    pos += 16
pos += 8                        # flags
for _ in range(cnt):
    o = struct.unpack_from('<q', out, pos)[0]
    struct.pack_into('<q', out, pos, o + delta)
    pos += 8 + 8 + 8 + 1        # offset, size, compressedSize, type
    pos = skipstr(pos)
open(dst, 'wb').write(out)
print(f'pe {pe_end} -> {len(pe)}, delta {delta}, files {cnt}')
