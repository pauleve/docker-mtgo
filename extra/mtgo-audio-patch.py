#!/usr/bin/env python3
"""Patch the locally installed MTGO client so that its audio works under Wine.

MTGO's managed audio code takes three paths that Wine cannot serve:

  * ``AudioManager.IsMuted()`` enumerates WASAPI sessions and casts them to
    ``ISimpleAudioVolume``.  Wine answers ``E_NOINTERFACE`` and the client dies
    with an ``InvalidCastException``.
  * ``AudioManager.GetWindowsVolume()`` reads the master volume through
    ``waveOutGetVolume(IntPtr.Zero, ...)``.  Wine leaves the value at 0, so every
    sound is played at volume 0.
  * every sample is pushed through ``MediaFoundationResampler`` because the
    format comparison in ``SoundQueue.ActiveSample..ctor`` compares
    ``WaveFormat`` *references*, which never match.  Media Foundation is not
    usable in Wine, so playback crashes or stays silent.

This script rewrites those code paths in the ``SharedResources.dll`` of your own
installation (no patched binary is distributed), and converts the handful of
sound files whose format does not match the mixer, since bypassing the resampler
requires the samples to already be in the mixer's format.

Everything is reversible: originals are kept outside the ClickOnce application
directory and ``--restore`` puts them back.

Nothing but the Python standard library is required.

See https://github.com/pauleve/docker-mtgo/issues/217
"""

import argparse
import array
import hashlib
import json
import os
import shutil
import struct
import sys
import time
import wave

VERSION = 2

# --------------------------------------------------------------------------
# CIL opcodes: mnemonic + operand kind, enough to walk a method body
# --------------------------------------------------------------------------

NONE, U1, I1, I2, U2, I4, I8, R4, R8, TOK, BR1, BR4, SWITCH = range(13)
OPSZ = {NONE: 0, U1: 1, I1: 1, I2: 2, U2: 2, I4: 4, I8: 8, R4: 4, R8: 8,
        TOK: 4, BR1: 1, BR4: 4}

OPS1 = {
    0x00: ('nop', NONE), 0x01: ('break', NONE),
    0x02: ('ldarg.0', NONE), 0x03: ('ldarg.1', NONE), 0x04: ('ldarg.2', NONE),
    0x05: ('ldarg.3', NONE),
    0x06: ('ldloc.0', NONE), 0x07: ('ldloc.1', NONE), 0x08: ('ldloc.2', NONE),
    0x09: ('ldloc.3', NONE),
    0x0a: ('stloc.0', NONE), 0x0b: ('stloc.1', NONE), 0x0c: ('stloc.2', NONE),
    0x0d: ('stloc.3', NONE),
    0x0e: ('ldarg.s', U1), 0x0f: ('ldarga.s', U1), 0x10: ('starg.s', U1),
    0x11: ('ldloc.s', U1), 0x12: ('ldloca.s', U1), 0x13: ('stloc.s', U1),
    0x14: ('ldnull', NONE), 0x15: ('ldc.i4.m1', NONE),
    0x16: ('ldc.i4.0', NONE), 0x17: ('ldc.i4.1', NONE), 0x18: ('ldc.i4.2', NONE),
    0x19: ('ldc.i4.3', NONE), 0x1a: ('ldc.i4.4', NONE), 0x1b: ('ldc.i4.5', NONE),
    0x1c: ('ldc.i4.6', NONE), 0x1d: ('ldc.i4.7', NONE), 0x1e: ('ldc.i4.8', NONE),
    0x1f: ('ldc.i4.s', I1), 0x20: ('ldc.i4', I4), 0x21: ('ldc.i8', I8),
    0x22: ('ldc.r4', R4), 0x23: ('ldc.r8', R8),
    0x25: ('dup', NONE), 0x26: ('pop', NONE), 0x27: ('jmp', TOK),
    0x28: ('call', TOK), 0x29: ('calli', TOK), 0x2a: ('ret', NONE),
    0x2b: ('br.s', BR1), 0x2c: ('brfalse.s', BR1), 0x2d: ('brtrue.s', BR1),
    0x2e: ('beq.s', BR1), 0x2f: ('bge.s', BR1), 0x30: ('bgt.s', BR1),
    0x31: ('ble.s', BR1), 0x32: ('blt.s', BR1), 0x33: ('bne.un.s', BR1),
    0x34: ('bge.un.s', BR1), 0x35: ('bgt.un.s', BR1), 0x36: ('ble.un.s', BR1),
    0x37: ('blt.un.s', BR1),
    0x38: ('br', BR4), 0x39: ('brfalse', BR4), 0x3a: ('brtrue', BR4),
    0x3b: ('beq', BR4), 0x3c: ('bge', BR4), 0x3d: ('bgt', BR4),
    0x3e: ('ble', BR4), 0x3f: ('blt', BR4), 0x40: ('bne.un', BR4),
    0x41: ('bge.un', BR4), 0x42: ('bgt.un', BR4), 0x43: ('ble.un', BR4),
    0x44: ('blt.un', BR4), 0x45: ('switch', SWITCH),
    0x6f: ('callvirt', TOK), 0x70: ('cpobj', TOK), 0x71: ('ldobj', TOK),
    0x72: ('ldstr', TOK), 0x73: ('newobj', TOK), 0x74: ('castclass', TOK),
    0x75: ('isinst', TOK), 0x79: ('unbox', TOK), 0x7a: ('throw', NONE),
    0x7b: ('ldfld', TOK), 0x7c: ('ldflda', TOK), 0x7d: ('stfld', TOK),
    0x7e: ('ldsfld', TOK), 0x7f: ('ldsflda', TOK), 0x80: ('stsfld', TOK),
    0x81: ('stobj', TOK), 0x8c: ('box', TOK), 0x8d: ('newarr', TOK),
    0x8f: ('ldelema', TOK), 0xa3: ('ldelem', TOK), 0xa4: ('stelem', TOK),
    0xa5: ('unbox.any', TOK), 0xc2: ('refanyval', TOK), 0xc6: ('mkrefany', TOK),
    0xd0: ('ldtoken', TOK),
    0xdc: ('endfinally', NONE), 0xdd: ('leave', BR4), 0xde: ('leave.s', BR1),
}
# the remaining single-byte opcodes take no operand
for _base, _names in (
    (0x46, 'ldind.i1 ldind.u1 ldind.i2 ldind.u2 ldind.i4 ldind.u4 ldind.i8 ldind.i '
           'ldind.r4 ldind.r8 ldind.ref stind.ref stind.i1 stind.i2 stind.i4 stind.i8 '
           'stind.r4 stind.r8 add sub mul div div.un rem rem.un and or xor shl shr '
           'shr.un neg not conv.i1 conv.i2 conv.i4 conv.i8 conv.r4 conv.r8 conv.u4 '
           'conv.u8'),
    (0x76, 'conv.r.un'),
    (0x82, 'conv.ovf.i1.un conv.ovf.i2.un conv.ovf.i4.un conv.ovf.i8.un conv.ovf.u1.un '
           'conv.ovf.u2.un conv.ovf.u4.un conv.ovf.u8.un conv.ovf.i.un conv.ovf.u.un'),
    (0x8e, 'ldlen'),
    (0x90, 'ldelem.i1 ldelem.u1 ldelem.i2 ldelem.u2 ldelem.i4 ldelem.u4 ldelem.i8 '
           'ldelem.i ldelem.r4 ldelem.r8 ldelem.ref stelem.i stelem.i1 stelem.i2 '
           'stelem.i4 stelem.i8 stelem.r4 stelem.r8 stelem.ref'),
    (0xb3, 'conv.ovf.i1 conv.ovf.u1 conv.ovf.i2 conv.ovf.u2 conv.ovf.i4 conv.ovf.u4 '
           'conv.ovf.i8 conv.ovf.u8'),
    (0xc3, 'ckfinite'),
    (0xd1, 'conv.u2 conv.u1 conv.i conv.ovf.i conv.ovf.u add.ovf add.ovf.un mul.ovf '
           'mul.ovf.un sub.ovf sub.ovf.un'),
    (0xdf, 'stind.i conv.u'),
):
    for _i, _name in enumerate(_names.split()):
        OPS1.setdefault(_base + _i, (_name, NONE))
for _op in range(0x00, 0xe1):
    OPS1.setdefault(_op, ('op.%02x' % _op, NONE))

OPS2 = {
    0x00: ('arglist', NONE), 0x01: ('ceq', NONE), 0x02: ('cgt', NONE),
    0x03: ('cgt.un', NONE), 0x04: ('clt', NONE), 0x05: ('clt.un', NONE),
    0x06: ('ldftn', TOK), 0x07: ('ldvirtftn', TOK), 0x09: ('ldarg', U2),
    0x0a: ('ldarga', U2), 0x0b: ('starg', U2), 0x0c: ('ldloc', U2),
    0x0d: ('ldloca', U2), 0x0e: ('stloc', U2), 0x0f: ('localloc', NONE),
    0x11: ('endfilter', NONE), 0x12: ('unaligned.', U1), 0x13: ('volatile.', NONE),
    0x14: ('tail.', NONE), 0x15: ('initobj', TOK), 0x16: ('constrained.', TOK),
    0x17: ('cpblk', NONE), 0x18: ('initblk', NONE), 0x19: ('no.', U1),
    0x1a: ('rethrow', NONE), 0x1c: ('sizeof', TOK), 0x1d: ('refanytype', NONE),
    0x1e: ('readonly.', NONE),
}


class Insn(object):
    __slots__ = ('off', 'size', 'name', 'kind', 'value')

    def __init__(self, off, size, name, kind, value):
        self.off, self.size, self.name, self.kind, self.value = \
            off, size, name, kind, value

    @property
    def end(self):
        return self.off + self.size

    def __repr__(self):
        return 'IL_%04x: %s%s' % (self.off, self.name,
                                  '' if self.value is None else ' %s' % (self.value,))


def disasm(code):
    """Decode a method body into a list of Insn (offsets relative to the code)."""
    out = []
    i = 0
    n = len(code)
    while i < n:
        start = i
        if code[i] == 0xfe:
            name, kind = OPS2.get(code[i + 1], ('unk.fe%02x' % code[i + 1], NONE))
            i += 2
        else:
            name, kind = OPS1[code[i]]
            i += 1
        value = None
        if kind == SWITCH:
            cnt = struct.unpack_from('<I', code, i)[0]
            i += 4 + 4 * cnt
        else:
            sz = OPSZ[kind]
            if sz:
                if kind == I1:
                    value = struct.unpack_from('<b', code, i)[0]
                elif kind == U1:
                    value = code[i]
                elif kind == I2:
                    value = struct.unpack_from('<h', code, i)[0]
                elif kind == U2:
                    value = struct.unpack_from('<H', code, i)[0]
                elif kind == I4:
                    value = struct.unpack_from('<i', code, i)[0]
                elif kind == I8:
                    value = struct.unpack_from('<q', code, i)[0]
                elif kind == R4:
                    value = struct.unpack_from('<f', code, i)[0]
                elif kind == R8:
                    value = struct.unpack_from('<d', code, i)[0]
                elif kind == TOK:
                    value = struct.unpack_from('<I', code, i)[0]
                elif kind == BR1:
                    value = i + 1 + struct.unpack_from('<b', code, i)[0]
                elif kind == BR4:
                    value = i + 4 + struct.unpack_from('<i', code, i)[0]
                i += sz
        out.append(Insn(start, i - start, name, kind, value))
    return out


# --------------------------------------------------------------------------
# Just enough ECMA-335 metadata to find a method body in the file
# --------------------------------------------------------------------------

# tables we walk over, in table order; rows are laid out in table order, so
# reaching MemberRef (0x0A) means sizing everything below it as well.
NTABLES = 0x0B


class Assembly(object):
    def __init__(self, data):
        self.data = bytearray(data)
        self._parse_pe()
        self._parse_metadata()

    # -- PE ----------------------------------------------------------------
    def _parse_pe(self):
        d = self.data
        if d[:2] != b'MZ':
            raise ValueError('not a PE file')
        pe = struct.unpack_from('<I', d, 0x3c)[0]
        if d[pe:pe + 4] != b'PE\0\0':
            raise ValueError('not a PE file')
        coff = pe + 4
        nsec, = struct.unpack_from('<H', d, coff + 2)
        opt_size, = struct.unpack_from('<H', d, coff + 16)
        opt = coff + 20
        magic, = struct.unpack_from('<H', d, opt)
        dirs = opt + (96 if magic == 0x10b else 112)
        sect = opt + opt_size
        self.sections = []
        for i in range(nsec):
            s = sect + 40 * i
            vsize, vaddr, rsize, raddr = struct.unpack_from('<IIII', d, s + 8)
            self.sections.append((vaddr, max(vsize, rsize), raddr))
        cli_rva, = struct.unpack_from('<I', d, dirs + 14 * 8)
        if not cli_rva:
            raise ValueError('not a managed assembly')
        cli = self.rva2off(cli_rva)
        md_rva, = struct.unpack_from('<I', d, cli + 8)
        self.md = self.rva2off(md_rva)

    def rva2off(self, rva):
        for vaddr, vsize, raddr in self.sections:
            if vaddr <= rva < vaddr + vsize:
                return rva - vaddr + raddr
        raise ValueError('RVA %#x outside of any section' % rva)

    # -- metadata ----------------------------------------------------------
    def _parse_metadata(self):
        d = self.data
        md = self.md
        if struct.unpack_from('<I', d, md)[0] != 0x424A5342:
            raise ValueError('bad metadata signature')
        vlen, = struct.unpack_from('<I', d, md + 12)
        p = md + 16 + ((vlen + 3) & ~3)
        nstreams, = struct.unpack_from('<H', d, p + 2)
        p += 4
        streams = {}
        for _ in range(nstreams):
            off, size = struct.unpack_from('<II', d, p)
            p += 8
            end = d.index(b'\0', p)
            name = bytes(d[p:end]).decode('ascii')
            p = md + (((end + 1 - md) + 3) & ~3)
            streams[name] = (md + off, size)
        self.streams = streams
        if '#~' not in streams:
            raise ValueError('unsupported (uncompressed) metadata stream')
        self.strings = streams['#Strings'][0]
        self.blobs = streams.get('#Blob', (0, 0))[0]
        self._parse_tables(*streams['#~'])

    def _parse_tables(self, off, size):
        d = self.data
        heaps = d[off + 6]
        valid, = struct.unpack_from('<Q', d, off + 8)
        p = off + 24
        rows = {}
        for t in range(64):
            if valid & (1 << t):
                rows[t] = struct.unpack_from('<I', d, p)[0]
                p += 4
        self.rows = rows
        self.str_sz = 4 if heaps & 0x01 else 2
        self.guid_sz = 4 if heaps & 0x02 else 2
        self.blob_sz = 4 if heaps & 0x04 else 2

        def idx(*tables):
            return 4 if max(rows.get(t, 0) for t in tables) >= 0x10000 else 2

        def coded(bits, *tables):
            limit = 1 << (16 - bits)
            return 4 if max(rows.get(t, 0) for t in tables) >= limit else 2

        S, G, B = self.str_sz, self.guid_sz, self.blob_sz
        res_scope = coded(2, 0x00, 0x1A, 0x23, 0x01)
        typedeforref = coded(2, 0x02, 0x01, 0x1B)
        self.memberref_parent = coded(3, 0x02, 0x01, 0x1A, 0x06, 0x1B)
        self.field_idx = idx(0x04)
        self.method_idx = idx(0x06)
        self.param_idx = idx(0x08)
        sizes = {
            0x00: 2 + S + 3 * G,
            0x01: res_scope + 2 * S,
            0x02: 4 + 2 * S + typedeforref + self.field_idx + self.method_idx,
            0x03: self.field_idx,
            0x04: 2 + S + B,
            0x05: self.method_idx,
            0x06: 4 + 2 + 2 + S + B + self.param_idx,
            0x07: self.param_idx,
            0x08: 2 + 2 + S,
            0x09: idx(0x02) + typedeforref,
            0x0a: self.memberref_parent + S + B,
        }
        self.row_size = sizes
        self.table_off = {}
        q = p
        for t in range(NTABLES):
            if t in rows:
                self.table_off[t] = q
                q += rows[t] * sizes[t]

    # -- accessors ---------------------------------------------------------
    def _uint(self, off, size):
        if size == 2:
            return struct.unpack_from('<H', self.data, off)[0]
        return struct.unpack_from('<I', self.data, off)[0]

    def string(self, idx):
        d = self.data
        start = self.strings + idx
        return bytes(d[start:d.index(b'\0', start)]).decode('utf-8', 'replace')

    def blob(self, idx):
        d = self.data
        p = self.blobs + idx
        b0 = d[p]
        if b0 & 0x80 == 0:
            n, p = b0, p + 1
        elif b0 & 0xC0 == 0x80:
            n, p = ((b0 & 0x3F) << 8) | d[p + 1], p + 2
        else:
            n = ((b0 & 0x1F) << 24) | (d[p + 1] << 16) | (d[p + 2] << 8) | d[p + 3]
            p += 4
        return bytes(d[p:p + n])

    def typedefs(self):
        """Yield (namespace, name, first_method_rid) for every TypeDef."""
        n = self.rows.get(0x02, 0)
        base = self.table_off[0x02]
        sz = self.row_size[0x02]
        S = self.str_sz
        for i in range(n):
            r = base + i * sz
            name = self.string(self._uint(r + 4, S))
            ns = self.string(self._uint(r + 4 + S, S))
            mlist = self._uint(r + sz - self.method_idx, self.method_idx)
            yield ns, name, mlist

    def methods_of(self, rid_start, rid_end):
        """Yield (name, rva, signature_blob) for MethodDef rids in [start, end)."""
        base = self.table_off[0x06]
        sz = self.row_size[0x06]
        S, B = self.str_sz, self.blob_sz
        n = self.rows.get(0x06, 0)
        for rid in range(rid_start, min(rid_end, n + 1)):
            r = base + (rid - 1) * sz
            rva, = struct.unpack_from('<I', self.data, r)
            name = self.string(self._uint(r + 8, S))
            sig = self.blob(self._uint(r + 8 + S, B))
            yield name, rva, sig

    def _row(self, table, rid):
        return self.table_off[table] + (rid - 1) * self.row_size[table]

    def type_name(self, table, rid):
        """Full name of a TypeDef (0x02) or TypeRef (0x01) row."""
        S = self.str_sz
        if table == 0x02:
            r = self._row(0x02, rid)
            name, ns = self.string(self._uint(r + 4, S)), self.string(self._uint(r + 4 + S, S))
        elif table == 0x01:
            r = self._row(0x01, rid)
            base = self.row_size[0x01] - 2 * S
            name, ns = self.string(self._uint(r + base, S)), \
                self.string(self._uint(r + base + S, S))
        else:
            return 'table%02x[%d]' % (table, rid)
        return '%s.%s' % (ns, name) if ns else name

    MEMBERREF_PARENT = {0: 0x02, 1: 0x01, 2: 0x1A, 3: 0x06, 4: 0x1B}

    def token_name(self, tok):
        """Best-effort human readable name for a metadata token."""
        table, rid = tok >> 24, tok & 0xFFFFFF
        S = self.str_sz
        try:
            if table == 0x0A:  # MemberRef
                r = self._row(0x0a, rid)
                parent = self._uint(r, self.memberref_parent)
                name = self.string(self._uint(r + self.memberref_parent, S))
                ptable = self.MEMBERREF_PARENT.get(parent & 7)
                owner = self.type_name(ptable, parent >> 3) if ptable in (0x01, 0x02) \
                    else 'table%02x[%d]' % (ptable, parent >> 3)
                return '%s::%s' % (owner, name)
            if table == 0x06:  # MethodDef
                return '%s (this assembly)' % self.string(
                    self._uint(self._row(0x06, rid) + 8, S))
            if table == 0x04:  # Field
                return 'field %s' % self.string(self._uint(self._row(0x04, rid) + 2, S))
            if table in (0x01, 0x02):
                return self.type_name(table, rid)
            if table == 0x70:
                return '"..."'
        except Exception:
            pass
        return 'token(%08x)' % tok

    def find_methods(self, type_name, method_name, namespace=None):
        """Return [(full_type_name, rva, signature)] matching a type/method name."""
        tds = list(self.typedefs())
        nmethods = self.rows.get(0x06, 0)
        out = []
        for i, (ns, name, mlist) in enumerate(tds):
            if name != type_name:
                continue
            if namespace is not None and ns != namespace:
                continue
            end = tds[i + 1][2] if i + 1 < len(tds) else nmethods + 1
            for mname, rva, sig in self.methods_of(mlist, end):
                if mname == method_name and rva:
                    out.append(('%s.%s' % (ns, name) if ns else name, rva, sig))
        return out


def sig_return_type(sig):
    """Return the ELEMENT_TYPE byte of a method signature's return type."""
    p = 0
    conv = sig[p]
    p += 1
    if conv & 0x10:  # generic
        p += _skip_compressed(sig, p)
    p += _skip_compressed(sig, p)  # param count
    while sig[p] in (0x1f, 0x20):  # CMOD_REQD / CMOD_OPT
        p += 1
        p += _skip_compressed(sig, p)
    return sig[p]


def _skip_compressed(b, p):
    if b[p] & 0x80 == 0:
        return 1
    if b[p] & 0xC0 == 0x80:
        return 2
    return 4


class Body(object):
    """A method body: header, code and the ability to rewrite both."""

    def __init__(self, asm, rva):
        self.asm = asm
        self.off = asm.rva2off(rva)
        d = asm.data
        b0 = d[self.off]
        if (b0 & 0x3) == 0x2:
            self.fat = False
            self.hdr = 1
            self.size = b0 >> 2
        else:
            self.fat = True
            flags, = struct.unpack_from('<H', d, self.off)
            self.hdr = (flags >> 12) * 4
            self.flags = flags
            self.size, = struct.unpack_from('<I', d, self.off + 4)
        self.code_off = self.off + self.hdr

    @property
    def code(self):
        return self.asm.data[self.code_off:self.code_off + self.size]

    def disasm(self):
        return disasm(self.code)

    def write(self, rel_off, data):
        if rel_off + len(data) > self.size:
            raise ValueError('patch does not fit in method body')
        self.asm.data[self.code_off + rel_off:self.code_off + rel_off + len(data)] = data

    def drop_exception_handlers(self):
        """Clear CorILMethod_MoreSects so the (now unused) EH clauses are ignored."""
        if self.fat and (self.flags & 0x08):
            self.flags &= ~0x08
            struct.pack_into('<H', self.asm.data, self.off, self.flags)

    def replace_all(self, code):
        """Replace the whole body with `code`.

        The padding goes *before* the new code: a method body may not fall off
        its end, so the replacement has to finish exactly on the last byte with
        its `ret`, and the leading nops simply run into it.
        """
        if len(code) > self.size:
            raise ValueError('replacement body too large')
        self.drop_exception_handlers()
        self.write(0, b'\x00' * (self.size - len(code)) + code)


# --------------------------------------------------------------------------
# the patches
# --------------------------------------------------------------------------

ELEMENT_TYPE_BOOLEAN = 0x02
ELEMENT_TYPE_R4 = 0x0C
ELEMENT_TYPE_R8 = 0x0D

LDC_I4_0, LDC_I4_1, LDC_I4_2, LDC_R4, LDC_R8, RET, BR_S, BR, NOP = \
    b'\x16', b'\x17', b'\x18', b'\x22', b'\x23', b'\x2a', b'\x2b', b'\x38', b'\x00'


class PatchError(Exception):
    pass


def _single(asm, type_name, method_name, namespace=None):
    found = asm.find_methods(type_name, method_name, namespace)
    if not found:
        raise PatchError('%s.%s not found' % (type_name, method_name))
    if len(found) > 1:
        raise PatchError('%s.%s is ambiguous (%d matches)'
                         % (type_name, method_name, len(found)))
    return found[0]


def patch_is_muted(asm):
    """AudioManager.IsMuted() -> false, without touching WASAPI/COM."""
    name, rva, sig = _single(asm, 'AudioManager', 'IsMuted', 'Shiny.Utilities')
    if sig_return_type(sig) != ELEMENT_TYPE_BOOLEAN:
        raise PatchError('%s.IsMuted does not return bool' % name)
    body = Body(asm, rva)
    ops = body.disasm()
    if not any(op.name in ('callvirt', 'call') for op in ops):
        raise PatchError('IsMuted looks already patched or unexpected')
    body.replace_all(LDC_I4_0 + RET)
    return 'IsMuted() -> false (was %d bytes of WASAPI session enumeration)' % body.size


def _return_one(asm, type_name, method_name, namespace=None):
    name, rva, sig = _single(asm, type_name, method_name, namespace)
    ret = sig_return_type(sig)
    if ret == ELEMENT_TYPE_R8:
        code = LDC_R8 + struct.pack('<d', 1.0) + RET
    elif ret == ELEMENT_TYPE_R4:
        code = LDC_R4 + struct.pack('<f', 1.0) + RET
    else:
        raise PatchError('%s.%s does not return a float' % (name, method_name))
    body = Body(asm, rva)
    body.replace_all(code)
    return '%s() -> 1.0' % method_name


def patch_windows_volume(asm):
    """AudioManager.GetWindowsVolume() -> 1.0.

    Wine's waveOutGetVolume() leaves the out parameter at 0 for the null
    handle MTGO passes, which mutes every sample.
    """
    return _return_one(asm, 'AudioManager', 'GetWindowsVolume', 'Shiny.Utilities')


def patch_get_volume(asm):
    """AudioManager.GetVolume(setting) -> 1.0 (optional: ignores in-game sliders)."""
    return _return_one(asm, 'AudioManager', 'GetVolume', 'Shiny.Utilities')


def patch_mixer_stereo(asm):
    """SoundQueue..ctor: build the mixer in stereo instead of mono.

    Returns (message, sample_rate) -- the sample rate every sound file must use
    once the resampler is bypassed.
    """
    name, rva, sig = _single(asm, 'SoundQueue', '.ctor')
    body = Body(asm, rva)
    ops = body.disasm()
    hits = []
    for i in range(len(ops) - 2):
        rate = ops[i]
        chan = ops[i + 1]
        call = ops[i + 2]
        if rate.name not in ('ldc.i4', 'ldc.i4.s'):
            continue
        if not (8000 <= (rate.value or 0) <= 192000):
            continue
        if call.name != 'call':
            continue
        if chan.name == 'ldc.i4.2':
            return ('mixer already stereo @ %dHz' % rate.value, rate.value)
        if chan.name != 'ldc.i4.1':
            continue
        hits.append((i, rate.value))
    if len(hits) != 1:
        raise PatchError('expected exactly one mono mixer format in SoundQueue..ctor,'
                         ' found %d' % len(hits))
    i, rate = hits[0]
    body.write(ops[i + 1].off, LDC_I4_2)
    return ('mixer format 1ch -> 2ch @ %dHz' % rate, rate)


def patch_bypass_resampler(asm):
    """SoundQueue.ActiveSample..ctor: never build a MediaFoundationResampler.

    The original code is

        if (sample.format == outputFormat) source = stream;
        else source = new MediaFoundationResampler(stream, outputFormat);

    where the comparison is a reference comparison that is never true.  Media
    Foundation is not usable under Wine, so the branch is turned into an
    unconditional jump to the "formats already match" arm.  The comparison
    operands are removed as well, so the evaluation stack stays empty and the
    result still verifies.
    """
    name, rva, sig = _single(asm, 'ActiveSample', '.ctor')
    body = Body(asm, rva)
    ops = body.disasm()
    by_off = dict((op.off, i) for i, op in enumerate(ops))
    hits = []
    for i in range(3, len(ops)):
        beq = ops[i]
        if beq.name not in ('beq.s', 'beq'):
            continue
        a, fld, b = ops[i - 3], ops[i - 2], ops[i - 1]
        if not (a.name.startswith('ldarg') and fld.name == 'ldfld'
                and b.name.startswith('ldarg')):
            continue
        # the sequence must start on an empty evaluation stack
        prev = ops[i - 4]
        if not (prev.name.startswith('stfld') or prev.name.startswith('stloc')
                or prev.name.startswith('stsfld') or prev.name == 'pop'):
            continue
        # the not-taken arm must be the one building the resampler
        j = by_off.get(beq.end)
        if j is None or not any(op.name == 'newobj'
                                for op in ops[j:by_off.get(beq.value, j)]):
            continue
        hits.append(i)
    if len(hits) != 1:
        raise PatchError('expected exactly one resampler branch in ActiveSample..ctor,'
                         ' found %d' % len(hits))
    i = hits[0]
    start = ops[i - 3].off
    end = ops[i].end
    target = ops[i].value
    delta = target - (start + 2)
    if -128 <= delta <= 127:
        jump = BR_S + struct.pack('<b', delta)
    else:
        jump = BR + struct.pack('<i', target - (start + 5))
    body.write(start, jump + NOP * (end - start - len(jump)))
    return 'MediaFoundationResampler bypassed (IL_%04x -> IL_%04x)' % (start, target)


DUMP_DEFAULT = [
    'Shiny.Utilities.AudioManager::IsMuted',
    'Shiny.Utilities.AudioManager::GetWindowsVolume',
    'Shiny.Utilities.AudioManager::GetVolume',
    'Shiny.Utilities.AudioManager::PlaySound',
    'SoundQueue::.ctor',
    'ActiveSample::.ctor',
]


def dump_methods(data, specs, out=sys.stdout):
    """Disassemble methods given as [Namespace.]Type::Method.

    This is what the patches were derived from: when a client update makes a
    patch fail, dump the methods below and compare with what the patch expects.
    """
    asm = Assembly(data)
    for spec in specs:
        type_part, _, method = spec.partition('::')
        namespace, _, type_name = type_part.rpartition('.')
        found = asm.find_methods(type_name, method, namespace or None)
        if not found:
            out.write('\n=== %s: not found\n' % spec)
            continue
        for name, rva, sig in found:
            body = Body(asm, rva)
            out.write('\n=== %s::%s  rva=%#x  %s  code_size=%d  return_type=%#x%s\n'
                      % (name, method, rva, 'fat' if body.fat else 'tiny', body.size,
                         sig_return_type(sig),
                         '  exception handlers' if body.fat and (body.flags & 8) else ''))
            for op in disasm(body.code):
                if op.kind == TOK:
                    detail = '  ' + asm.token_name(op.value)
                elif op.kind in (BR1, BR4):
                    detail = '  -> IL_%04x' % op.value
                elif op.value is not None:
                    detail = '  %s' % (op.value,)
                else:
                    detail = ''
                out.write('  IL_%04x: %s\n'
                          % (op.off, ('%-14s%s' % (op.name, detail)).rstrip()))


def already_patched(asm):
    """True when IsMuted() is already the two-instruction stub."""
    try:
        name, rva, sig = _single(asm, 'AudioManager', 'IsMuted', 'Shiny.Utilities')
    except PatchError:
        return False
    code = Body(asm, rva).code
    return bytes(code[-2:]) == LDC_I4_0 + RET and set(code[:-2]) <= {0x00}


def patch_assembly(data, force_volume=False):
    """Apply every patch to `data`; return (new_bytes, messages, sample_rate)."""
    asm = Assembly(data)
    msgs = []
    msgs.append(patch_is_muted(asm))
    msgs.append(patch_windows_volume(asm))
    if force_volume:
        msgs.append(patch_get_volume(asm))
    msg, rate = patch_mixer_stereo(asm)
    msgs.append(msg)
    msgs.append(patch_bypass_resampler(asm))
    return bytes(asm.data), msgs, rate


# --------------------------------------------------------------------------
# sound files
# --------------------------------------------------------------------------

def convert_wav(src, dst, rate, channels=2):
    """Rewrite a PCM wav as `channels` x `rate`, 16 bit.  Returns a description."""
    with wave.open(src, 'rb') as w:
        nch, width, sr, nframes = (w.getnchannels(), w.getsampwidth(),
                                   w.getframerate(), w.getnframes())
        if w.getcomptype() != 'NONE':
            raise ValueError('compressed wav')
        raw = w.readframes(nframes)
    if width != 2 or nch not in (1, 2):
        raise ValueError('unsupported %d-bit %dch wav' % (width * 8, nch))
    samples = array.array('h')
    samples.frombytes(raw)
    if sys.byteorder == 'big':
        samples.byteswap()
    if nch == 2:
        left = samples[0::2]
        right = samples[1::2]
    else:
        left = right = samples
    n = len(left)
    if sr != rate and n:
        step = float(sr) / rate
        m = int(n / step)
        out_l = array.array('h', bytes(2 * m))
        out_r = array.array('h', bytes(2 * m))
        for i in range(m):
            pos = i * step
            k = int(pos)
            frac = pos - k
            k2 = min(k + 1, n - 1)
            out_l[i] = int(left[k] + (left[k2] - left[k]) * frac)
            out_r[i] = int(right[k] + (right[k2] - right[k]) * frac)
        left, right = out_l, out_r
    inter = array.array('h', bytes(4 * len(left)))
    inter[0::2] = left
    inter[1::2] = right
    if sys.byteorder == 'big':
        inter.byteswap()
    with wave.open(dst, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(inter.tobytes())
    return '%dch %dHz -> 2ch %dHz' % (nch, sr, rate)


def wav_format(path):
    try:
        with wave.open(path, 'rb') as w:
            return w.getnchannels(), w.getframerate(), w.getsampwidth()
    except Exception:
        return None


# --------------------------------------------------------------------------
# installation handling
# --------------------------------------------------------------------------

DLL = 'SharedResources.dll'
STATE_DIRNAME = 'mtgo-audio-patch'


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def find_app_dirs(prefix):
    """Every installed MTGO application directory below a wine prefix."""
    out = []
    users = os.path.join(prefix, 'drive_c', 'users')
    for root, dirs, files in os.walk(users):
        if DLL in files and os.path.basename(root).startswith('mtgo..'):
            out.append(root)
            dirs[:] = []
    return sorted(out)


def state_dir_for(app_dir):
    """Keep backups out of the ClickOnce directory, but on the same volume."""
    local = os.path.dirname(app_dir)
    while local and os.path.basename(local) not in ('Local', 'Apps'):
        parent = os.path.dirname(local)
        if parent == local:
            break
        local = parent
    if os.path.basename(local) == 'Apps':
        local = os.path.dirname(local)
    if not local or os.path.basename(local) != 'Local':
        local = os.path.dirname(app_dir)
    return os.path.join(local, STATE_DIRNAME, os.path.basename(app_dir))


def load_state(state_dir):
    try:
        with open(os.path.join(state_dir, 'state.json')) as f:
            return json.load(f)
    except Exception:
        return {}


def save_state(state_dir, state):
    os.makedirs(state_dir, exist_ok=True)
    tmp = os.path.join(state_dir, 'state.json.tmp')
    with open(tmp, 'w') as f:
        json.dump(state, f, indent=1, sort_keys=True)
    os.replace(tmp, os.path.join(state_dir, 'state.json'))


def log(quiet, msg):
    if not quiet:
        sys.stdout.write('mtgo-audio-patch: %s\n' % msg)
        sys.stdout.flush()


def restore(app_dir, quiet=False):
    state_dir = state_dir_for(app_dir)
    state = load_state(state_dir)
    backup = os.path.join(state_dir, DLL + '.orig')
    n = 0
    if os.path.exists(backup):
        shutil.copy2(backup, os.path.join(app_dir, DLL))
        log(quiet, 'restored %s' % os.path.join(app_dir, DLL))
        n += 1
    wav_backup = os.path.join(state_dir, 'wav')
    for rel in state.get('wavs', []):
        src = os.path.join(wav_backup, rel)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(app_dir, rel))
            n += 1
    save_state(state_dir, {})
    log(quiet, 'restored %d file(s) in %s' % (n, app_dir))
    return n


def patch_app_dir(app_dir, force_volume=False, do_wavs=True, quiet=False,
                  dry_run=False):
    """Patch one MTGO installation.  Returns True when something was changed."""
    dll = os.path.join(app_dir, DLL)
    state_dir = state_dir_for(app_dir)
    state = load_state(state_dir)
    digest = sha256(dll)

    if (state.get('version') == VERSION and state.get('patched_sha') == digest
            and state.get('force_volume') == bool(force_volume)):
        log(quiet, 'already patched: %s' % app_dir)
        return False

    with open(dll, 'rb') as f:
        data = f.read()

    if already_patched(Assembly(data)):
        # patched by an older run (or by hand) but the state file is stale;
        # fall back to the backup so patches always apply to pristine IL
        backup = os.path.join(state_dir, DLL + '.orig')
        if os.path.exists(backup):
            with open(backup, 'rb') as f:
                data = f.read()
        else:
            log(quiet, '%s is already patched but no backup exists; leaving it alone'
                % dll)
            return False

    patched, msgs, rate = patch_assembly(data, force_volume=force_volume)
    for m in msgs:
        log(quiet, '  %s' % m)

    wavs = []
    if do_wavs:
        audio = os.path.join(app_dir, 'Audio')
        for root, _dirs, files in os.walk(audio):
            for f in sorted(files):
                if not f.lower().endswith('.wav'):
                    continue
                path = os.path.join(root, f)
                fmt = wav_format(path)
                if fmt is None or (fmt[0] == 2 and fmt[1] == rate and fmt[2] == 2):
                    continue
                wavs.append(os.path.relpath(path, app_dir))

    if dry_run:
        log(quiet, 'dry run: would patch %s and convert %d sound file(s)'
            % (dll, len(wavs)))
        return False

    os.makedirs(state_dir, exist_ok=True)
    backup = os.path.join(state_dir, DLL + '.orig')
    if not os.path.exists(backup) or state.get('orig_sha') != sha256(backup):
        shutil.copy2(dll, backup + '.tmp')
        os.replace(backup + '.tmp', backup)

    for rel in wavs:
        src = os.path.join(app_dir, rel)
        dst = os.path.join(state_dir, 'wav', rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst):
            shutil.copy2(src, dst)
        try:
            tmp = src + '.tmp'
            what = convert_wav(dst, tmp, rate)
            os.replace(tmp, src)
            log(quiet, '  %s: %s' % (rel, what))
        except Exception as e:
            log(quiet, '  %s: cannot convert (%s)' % (rel, e))

    tmp = dll + '.tmp'
    with open(tmp, 'wb') as f:
        f.write(patched)
    shutil.copystat(dll, tmp)
    os.replace(tmp, dll)

    save_state(state_dir, {
        'version': VERSION,
        'time': time.strftime('%Y-%m-%dT%H:%M:%S'),
        'orig_sha': sha256(backup),
        'patched_sha': sha256(dll),
        'force_volume': bool(force_volume),
        'sample_rate': rate,
        'wavs': wavs,
    })
    log(quiet, 'patched %s' % dll)
    return True


def main(argv=None):
    p = argparse.ArgumentParser(
        description='Make MTGO audio work under Wine (see issue #217).')
    p.add_argument('--prefix', default=os.environ.get('WINEPREFIX')
                   or os.path.expanduser('~/.wine'),
                   help='wine prefix to look into (default: $WINEPREFIX)')
    p.add_argument('--app-dir', action='append', default=[],
                   help='patch this MTGO application directory only')
    p.add_argument('--force-volume', action='store_true',
                   help="also force AudioManager.GetVolume() to 1.0, ignoring "
                        "MTGO's own volume sliders")
    p.add_argument('--no-wav', action='store_true',
                   help='do not convert sound files that do not match the mixer')
    p.add_argument('--restore', action='store_true',
                   help='put the original files back')
    p.add_argument('--dry-run', action='store_true', help='do not write anything')
    p.add_argument('--dump', action='store_true',
                   help='disassemble the patched methods (or those given as '
                        'arguments) instead of patching anything')
    p.add_argument('--dll', help='act on this SharedResources.dll (with --dump)')
    p.add_argument('methods', nargs='*', metavar='Type::Method',
                   help='methods to disassemble with --dump')
    p.add_argument('--quiet', action='store_true')
    args = p.parse_args(argv)

    if args.dump:
        dll = args.dll
        if not dll:
            dirs = args.app_dir or find_app_dirs(args.prefix)
            if not dirs:
                sys.stderr.write('mtgo-audio-patch: no MTGO installation found\n')
                return 1
            dll = os.path.join(dirs[-1], DLL)
        sys.stdout.write('# %s\n' % dll)
        with open(dll, 'rb') as f:
            dump_methods(f.read(), args.methods or DUMP_DEFAULT)
        return 0

    if args.methods:
        p.error('method names are only used with --dump')

    app_dirs = args.app_dir or find_app_dirs(args.prefix)
    if not app_dirs:
        log(args.quiet, 'no MTGO installation found under %s (nothing to do)'
            % args.prefix)
        return 0

    changed = 0
    for app_dir in app_dirs:
        try:
            if args.restore:
                restore(app_dir, quiet=args.quiet)
            elif patch_app_dir(app_dir, force_volume=args.force_volume,
                               do_wavs=not args.no_wav, quiet=args.quiet,
                               dry_run=args.dry_run):
                changed += 1
        except (PatchError, ValueError) as e:
            sys.stderr.write('mtgo-audio-patch: %s: %s\n' % (app_dir, e))
            sys.stderr.write('mtgo-audio-patch: this MTGO version is not supported '
                             'by the audio patch; sound may not work.\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
