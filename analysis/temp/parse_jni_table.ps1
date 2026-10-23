$code = @"
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;

public class ElfParser {
    public struct Elf64_Shdr {
        public uint sh_name;
        public uint sh_type;
        public ulong sh_flags;
        public ulong sh_addr;
        public ulong sh_offset;
        public ulong sh_size;
        public uint sh_link;
        public uint sh_info;
        public ulong sh_addralign;
        public ulong sh_entsize;
    }

    public struct Elf64_Sym {
        public uint st_name;
        public byte st_info;
        public byte st_other;
        public ushort shndx;
        public ulong st_value;
        public ulong st_size;
    }

    public struct Elf64_Rela {
        public ulong r_offset;
        public ulong r_info;
        public long r_addend;
    }

    public static void Analyze(string filePath) {
        byte[] bytes = File.ReadAllBytes(filePath);
        if (bytes[0] != 0x7F || bytes[1] != (byte)'E' || bytes[2] != (byte)'L' || bytes[3] != (byte)'F') {
            Console.WriteLine("Invalid ELF");
            return;
        }

        bool is64 = bytes[4] == 2;
        Console.WriteLine("ELF 64-bit: " + is64);

        ulong e_phoff = BitConverter.ToUInt64(bytes, 32);
        ulong e_shoff = BitConverter.ToUInt64(bytes, 40);
        ushort e_phentsize = BitConverter.ToUInt16(bytes, 54);
        ushort e_phnum = BitConverter.ToUInt16(bytes, 56);
        ushort e_shentsize = BitConverter.ToUInt16(bytes, 58);
        ushort e_shnum = BitConverter.ToUInt16(bytes, 60);
        ushort e_shstrndx = BitConverter.ToUInt16(bytes, 62);

        Console.WriteLine(string.Format("Section Headers: count={0}, offset=0x{1:X}", e_shnum, e_shoff));

        // Read section headers
        Elf64_Shdr[] shdrs = new Elf64_Shdr[e_shnum];
        for (int i = 0; i < e_shnum; i++) {
            int off = (int)e_shoff + i * e_shentsize;
            shdrs[i].sh_name = BitConverter.ToUInt32(bytes, off);
            shdrs[i].sh_type = BitConverter.ToUInt32(bytes, off + 4);
            shdrs[i].sh_flags = BitConverter.ToUInt64(bytes, off + 8);
            shdrs[i].sh_addr = BitConverter.ToUInt64(bytes, off + 16);
            shdrs[i].sh_offset = BitConverter.ToUInt64(bytes, off + 24);
            shdrs[i].sh_size = BitConverter.ToUInt64(bytes, off + 32);
            shdrs[i].sh_link = BitConverter.ToUInt32(bytes, off + 40);
            shdrs[i].sh_info = BitConverter.ToUInt32(bytes, off + 44);
            shdrs[i].sh_addralign = BitConverter.ToUInt64(bytes, off + 48);
            shdrs[i].sh_entsize = BitConverter.ToUInt64(bytes, off + 56);
        }

        // Section header string table
        ulong shstrTabOff = shdrs[e_shstrndx].sh_offset;

        Dictionary<string, Elf64_Shdr> sections = new Dictionary<string, Elf64_Shdr>();
        for (int i = 0; i < e_shnum; i++) {
            int nameOff = (int)shstrTabOff + (int)shdrs[i].sh_name;
            string name = ReadNullTermString(bytes, nameOff);
            sections[name] = shdrs[i];
            Console.WriteLine(string.Format("Section [{0}] '{1}': addr=0x{2:X8}, off=0x{3:X8}, size=0x{4:X8}", i, name, shdrs[i].sh_addr, shdrs[i].sh_offset, shdrs[i].sh_size));
        }

        // Read .dynsym & .dynstr
        if (sections.ContainsKey(".dynsym") && sections.ContainsKey(".dynstr")) {
            Elf64_Shdr dynsym = sections[".dynsym"];
            Elf64_Shdr dynstr = sections[".dynstr"];
            int symCount = (int)(dynsym.sh_size / dynsym.sh_entsize);
            Console.WriteLine(string.Format("\n=== DYNAMIC SYMBOLS ({0}) ===", symCount));

            for (int i = 0; i < symCount; i++) {
                int off = (int)dynsym.sh_offset + i * (int)dynsym.sh_entsize;
                uint nameIdx = BitConverter.ToUInt32(bytes, off);
                byte info = bytes[off + 4];
                ulong value = BitConverter.ToUInt64(bytes, off + 8);
                ulong size = BitConverter.ToUInt64(bytes, off + 16);
                string symName = ReadNullTermString(bytes, (int)dynstr.sh_offset + (int)nameIdx);

                if (!string.IsNullOrEmpty(symName)) {
                    Console.WriteLine(string.Format("Symbol [{0}] '{1}': value=0x{2:X8}, size=0x{3:X8}, info=0x{4:X2}", i, symName, value, size, info));
                }
            }
        }

        // Read .rela.dyn
        if (sections.ContainsKey(".rela.dyn")) {
            Elf64_Shdr relaDyn = sections[".rela.dyn"];
            int count = (int)(relaDyn.sh_size / relaDyn.sh_entsize);
            Console.WriteLine(string.Format("\n=== RELOCATIONS .rela.dyn ({0}) ===", count));
            for (int i = 0; i < count; i++) {
                int off = (int)relaDyn.sh_offset + i * (int)relaDyn.sh_entsize;
                ulong r_offset = BitConverter.ToUInt64(bytes, off);
                ulong r_info = BitConverter.ToUInt64(bytes, off + 8);
                long r_addend = BitConverter.ToInt64(bytes, off + 16);
                uint r_type = (uint)(r_info & 0xFFFFFFFF);
                uint r_sym = (uint)(r_info >> 32);

                // R_AARCH64_RELATIVE = 1027 (0x403)
                if (r_type == 1027) {
                    Console.WriteLine(string.Format("R_AARCH64_RELATIVE at offset 0x{0:X8} -> target RVA 0x{1:X8}", r_offset, r_addend));
                }
            }
        }

        // Search for JNINativeMethod array in .rodata / .data.rel.ro / .data
        Console.WriteLine("\n=== SEARCHING FOR JNINativeMethod TABLE STRUCTS ===");
        // Search all 64-bit pointers pointing to string "nativeSendRawData"
        int targetStrOffset = FindStringOffset(bytes, "nativeSendRawData");
        int sigStrOffset = FindStringOffset(bytes, "(IJ[B)Z");
        int fnPtrOffset = FindStringOffset(bytes, "gst_native_send_data");

        Console.WriteLine(string.Format("File offsets of strings: nativeSendRawData=0x{0:X8}, (IJ[B)Z=0x{1:X8}", targetStrOffset, sigStrOffset));

        // Scan memory for 24-byte JNINativeMethod structures
        for (int i = 0; i < bytes.Length - 24; i += 4) {
            ulong pName = BitConverter.ToUInt64(bytes, i);
            ulong pSig = BitConverter.ToUInt64(bytes, i + 8);
            ulong pFn = BitConverter.ToUInt64(bytes, i + 16);

            // Check if pName and pSig point to string addresses
            if (pName > 0 && pName < (ulong)bytes.Length && pSig > 0 && pSig < (ulong)bytes.Length) {
                string sName = TryReadString(bytes, (int)pName);
                string sSig = TryReadString(bytes, (int)pSig);

                if (sName == "nativeSendRawData" || sSig == "(IJ[B)Z" || sName == "nativeClassInit" || sName == "nativeInit") {
                    Console.WriteLine(string.Format("\n>>> JNINativeMethod FOUND AT FILE OFFSET 0x{0:X8} (RVA 0x{0:X8}) <<<", i));
                    Console.WriteLine(string.Format("   name_ptr : 0x{0:X8} -> '{1}'", pName, sName));
                    Console.WriteLine(string.Format("   sig_ptr  : 0x{0:X8} -> '{1}'", pSig, sSig));
                    Console.WriteLine(string.Format("   fn_ptr   : 0x{0:X8}", pFn));

                    // Inspect adjacent JNINativeMethod entries (before and after)
                    Console.WriteLine("   --- Adjacent JNINativeMethod Table Entries ---");
                    for (int k = -5; k <= 5; k++) {
                        int entryOff = i + k * 24;
                        if (entryOff >= 0 && entryOff <= bytes.Length - 24) {
                            ulong eName = BitConverter.ToUInt64(bytes, entryOff);
                            ulong eSig = BitConverter.ToUInt64(bytes, entryOff + 8);
                            ulong eFn = BitConverter.ToUInt64(bytes, entryOff + 16);
                            string nStr = TryReadString(bytes, (int)eName);
                            string sigStr = TryReadString(bytes, (int)eSig);
                            if (!string.IsNullOrEmpty(nStr) && !string.IsNullOrEmpty(sigStr)) {
                                Console.WriteLine(string.Format("   [Entry {0:+#;-#;0}] FileOffset: 0x{1:X8} | Name: 0x{2:X8} ('{3}') | Sig: 0x{4:X8} ('{5}') | FnPtr: 0x{6:X8}", k, entryOff, eName, nStr, eSig, sigStr, eFn));
                            }
                        }
                    }
                }
            }
        }
    }

    static string ReadNullTermString(byte[] bytes, int off) {
        if (off < 0 || off >= bytes.Length) return "";
        int len = 0;
        while (off + len < bytes.Length && bytes[off + len] != 0) len++;
        return Encoding.ASCII.GetString(bytes, off, len);
    }

    static string TryReadString(byte[] bytes, int off) {
        if (off < 0 || off >= bytes.Length) return null;
        int len = 0;
        while (off + len < bytes.Length && bytes[off + len] >= 0x20 && bytes[off + len] <= 0x7E) {
            len++;
            if (len > 200) break;
        }
        if (len < 2) return null;
        return Encoding.ASCII.GetString(bytes, off, len);
    }

    static int FindStringOffset(byte[] bytes, string str) {
        byte[] sb = Encoding.ASCII.GetBytes(str);
        for (int i = 0; i <= bytes.Length - sb.Length; i++) {
            bool ok = true;
            for (int j = 0; j < sb.Length; j++) {
                if (bytes[i + j] != sb[j]) { ok = false; break; }
            }
            if (ok) return i;
        }
        return -1;
    }
}
"@

Add-Type -TypeDefinition $code
[ElfParser]::Analyze("C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\libgstreamer-appcast.so")
