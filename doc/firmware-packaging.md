# OSTC Companion firmware package format

## Conclusion

The `*_ostc3_firmware.hex` files accepted by OSTC Companion are **not Intel
HEX**. They are encrypted firmware containers produced by the separate
Windows-only `o3pack.exe` release tool. `hwos_tiny.hex` is an Intel HEX upload
image for TinyBld and is not an OSTC Companion package.

The repository does not contain source code for `o3pack.exe`, its key material,
or a specification of its cryptographic protocol. Do not attempt to recreate,
modify, decrypt, or substitute this packaging step. In particular, a package
created from unvalidated firmware must not be offered for device installation.

## Evidence

The read-only upstream Mercurial checkout contains this release command in
`tools/o3pack.bat`:

```bat
o3pack.exe -ostc3 ../hwos.X/dist/default/production/hwos.X.production.hex -f dev_ostc3_firmware.hex
```

This is the MPLAB X production-output layout. The vendor's known-good local
environment is MPLAB X 5.10 with C18 v3.42 and a checkout at
`C:\hw\hwos_code`; its supplied `tools` directory contains this batch file and
the packer runtime. `tools/build_hwos.ps1` packages by default using
`tools/o3pack.exe` relative to the repository root, alongside its upstream
runtime DLLs. These files are retained from the public upstream Mercurial
manifest at their original paths. Their inclusion is not evidence of a licence
grant for redistribution.

`o3pack.exe` accepts an Intel HEX input and produces the container when invoked
as follows:

```text
o3pack.exe [-frog|-ostc3] input.hex [-f] output.hex
```

Its diagnostics reject malformed Intel HEX input. Static inspection identifies
AES/Rijndael CFB-mode and SHA-256 code, and its Windows imports include
`CryptGenRandom`. There is no source or public-key signing interface in this
checkout. This supports the conclusion that the tool uses a symmetric,
randomised packaging transformation with an integrity value. It does **not**
establish the key, nonce/IV layout, or an independently implementable format.

For the `-ostc3` mode, a harmless valid Intel HEX fixture with only 16 loaded
bytes produced a 307,256-byte container. Running the tool twice produced two
different outputs, confirming that the packaging is non-deterministic. The
tool reported a fixed 120 KiB firmware area.

## Container layout observed in released packages

The output is ASCII, but only superficially resembles Intel HEX:

- 7,682 records;
- 7,681 records have `:` followed by a six-hex-digit offset and 16 opaque
  bytes, with offsets `0x000000` through `0x01E000` in steps of 16;
- the final record has offset `0x01E010` and four opaque bytes;
- total opaque payload is 122,900 bytes; and
- there are no Intel HEX byte counts, record types, checksums, or EOF record.

The same structure is present in the upstream `tools/dev_ostc3_firmware.hex`
fixture and in the inspected release packages. The container format therefore
cannot be processed by Intel HEX tools such as SRecord.

## Build boundary

This Git checkout retains the upstream `tools/o3pack.exe`, `tools/o3pack.bat`,
and required runtime DLLs at their original paths so the authorised packaging
workflow remains reproducible. The repository does not contain their source,
key material, or a redistribution licence. Retention mirrors the public
upstream manifest only; it does not grant publication or redistribution rights.

This repository is a mirror and working fork of the upstream Mercurial
repository. It retains the upstream packer, `tools/o3pack.exe` and
`tools/o3pack.bat`, and their co-located runtime DLLs exactly as published
upstream. It asserts no rights beyond that publication, and it does not
reproduce, modify, or substitute the packaging protocol those files
implement.
