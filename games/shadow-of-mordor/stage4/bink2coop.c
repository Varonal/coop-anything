/* som-coop log-only probe (stage 4)
 * A bink2w64.dll proxy: all Bink exports are forwarded to the renamed
 * original (bink2w64_orig.dll) by the generated .def; this code only adds a
 * startup thread that walks the console registry in the game's memory and
 * writes som-coop.log. Nothing is hooked, no pointers are modified.
 *
 * Pinned constants: Steam build 7348332, exe v1.0.1951.29,
 * SHA-256 F5D72578F7E5FCF05E6D15D8BD231F763078620C8545F8464BB186E842279455.
 * The probe refuses to run against any other build (see image_size check).
 */
#include <windows.h>
#include <stdio.h>
#include <stdint.h>

#define STATIC_BASE   0x140000000ULL
#define IMAGE_SIZE   0x1A100000ULL      /* SizeOfImage, sanity bound */
#define TEXT_RVA      0x1000
#define TEXT_SIZE     0x139FADF
#define REG_FIRST_RVA 0x17F9E18         /* residue 0x18 mod 0x40 (stage 3) */
#define REG_LAST_RVA  0x17FC000
#define REG_STRIDE    0x40

static int in_image(uintptr_t p, uintptr_t base)
{
    return p >= base && p < base + IMAGE_SIZE;
}

static int valid_name(const char* s, uintptr_t base)
{
    if (!in_image((uintptr_t)s, base)) return 0;
    int len = 0, dots = 0;
    if (!((s[0] >= 'A' && s[0] <= 'Z') || (s[0] >= 'a' && s[0] <= 'z'))) return 0;
    while (len < 48) {
        char c = s[len];
        if (c == 0) break;
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '_' || c == '.') {
            if (c == '.') dots++;
            len++;
        } else return 0;
    }
    if (s[len] != 0 || len < 3 || len > 40) return 0;
    return dots > 0 || len >= 6;
}

static DWORD WINAPI worker(LPVOID unused)
{
    (void)unused;
    HMODULE exe = GetModuleHandleW(NULL);
    uintptr_t base = (uintptr_t)exe;
    FILE* f = fopen("som-coop.log", "w");
    if (!f) return 0;

    char exe_path[MAX_PATH] = {0};
    GetModuleFileNameA(NULL, exe_path, MAX_PATH);
    fprintf(f, "som-coop log-only probe (stage 4). No hooks, read-only.\n");
    fprintf(f, "exe: %s\n", exe_path);
    fprintf(f, "exe base: %llX (static %llX)\n",
            (unsigned long long)base, (unsigned long long)STATIC_BASE);

    if (!in_image(base, base) || base == 0) {
        fprintf(f, "REFUSING: unexpected module base; aborting walk.\n");
        fclose(f);
        return 0;
    }

    uintptr_t text_lo = base + TEXT_RVA;
    uintptr_t text_hi = base + TEXT_RVA + TEXT_SIZE;
    fprintf(f, "text range: %llX-%llX\n",
            (unsigned long long)text_lo, (unsigned long long)text_hi);
    fprintf(f, "registry walk: RVA %X..%X stride %X\n\n",
            REG_FIRST_RVA, REG_LAST_RVA, REG_STRIDE);

    int n = 0;
    for (uintptr_t rva = REG_FIRST_RVA; rva < REG_LAST_RVA; rva += REG_STRIDE) {
        uintptr_t entry = base + rva;
        uintptr_t name_va  = *(uintptr_t*)(entry + 0x00);
        if (!in_image(name_va, base)) continue;
        char* nm = (char*)name_va;
        if (!valid_name(nm, base)) continue;

        uintptr_t help_va  = *(uintptr_t*)(entry + 0x08);
        uintptr_t src_va   = *(uintptr_t*)(entry + 0x10);
        unsigned   line    = *(unsigned*)(entry + 0x18);
        uintptr_t handler = *(uintptr_t*)(entry + 0x30);
        if (handler < text_lo || handler > text_hi) continue;

        char* help = in_image(help_va, base) ? (char*)help_va : "";
        char* src  = in_image(src_va, base)  ? (char*)src_va  : "";
        fprintf(f, "%-30s handler %llX  line %5u  src %-24s help: %s\n",
                nm, (unsigned long long)handler, line, src, help);
        n++;
    }
    fprintf(f, "\n%d valid registry entries\n", n);
    fclose(f);
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE hinst, DWORD reason, LPVOID reserved)
{
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(hinst);
        CreateThread(NULL, 0, worker, NULL, 0, NULL);
    }
    return TRUE;
}
