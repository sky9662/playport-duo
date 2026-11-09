/* SPDX-License-Identifier: GPL-3.0-or-later
 * Actual shared-memory aliases exercise the shipped loader registry and fault
 * service. OS wrappers substitute the host VM API for Mach, not the routing,
 * retirement, protection checks, atomics or instruction-address decoder.
 */
#define _GNU_SOURCE
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <io.h>
typedef LONG NTSTATUS;
typedef uintptr_t mach_vm_address_t;
typedef size_t mach_vm_size_t;
typedef int vm_prot_t;
typedef HANDLE mapping_t;
#define THREAD_RETURN DWORD WINAPI
#else
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <pthread.h>
typedef int BOOL, NTSTATUS, vm_prot_t;
typedef uint16_t WORD;
typedef uint32_t ULONG;
typedef size_t SIZE_T, mach_vm_size_t;
typedef uintptr_t mach_vm_address_t;
typedef int mapping_t;
#define TRUE 1
#define FALSE 0
#define THREAD_RETURN void *
typedef struct { unsigned VirtualAddress, Size; } IMAGE_DATA_DIRECTORY;
typedef struct { struct { unsigned short Machine, NumberOfSections, Characteristics; } FileHeader;
    struct { IMAGE_DATA_DIRECTORY DataDirectory[16]; } OptionalHeader; } IMAGE_NT_HEADERS;
typedef struct { union { unsigned VirtualSize; } Misc;
    unsigned VirtualAddress, SizeOfRawData, Characteristics; } IMAGE_SECTION_HEADER;
typedef struct { unsigned VirtualAddress, SizeOfBlock; } IMAGE_BASE_RELOCATION;
#define IMAGE_FILE_MACHINE_AMD64 0x8664
#define IMAGE_SCN_MEM_EXECUTE 0x20000000
#define IMAGE_SCN_MEM_READ 0x40000000
#define IMAGE_SCN_MEM_WRITE 0x80000000u
#define IMAGE_SCN_MEM_SHARED 0x10000000
#define IMAGE_FILE_RELOCS_STRIPPED 1
#define IMAGE_DIRECTORY_ENTRY_IMPORT 1
#define IMAGE_DIRECTORY_ENTRY_BASERELOC 5
#define IMAGE_DIRECTORY_ENTRY_IAT 12
#define IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG 10
#define IMAGE_REL_BASED_HIGHLOW 3
#define IMAGE_REL_BASED_DIR64 10
#endif

#define VPROT_READ 1
#define VPROT_WRITE 2
#define VPROT_EXEC 4
#define VPROT_WRITECOPY 8
#define VPROT_GUARD 16
#define VPROT_COMMITTED 32
#define VPROT_WRITEWATCH 64
#define VPROT_WOW64_IMAGE 0x1000
#define VPROT_ARM64EC 0x2000
#define VPROT_X64_IMAGE 0x4000
#ifndef STATUS_SUCCESS
#define STATUS_SUCCESS 0
#endif
#ifndef STATUS_INVALID_PARAMETER
#define STATUS_INVALID_PARAMETER 1
#endif
#ifndef STATUS_NOT_SUPPORTED
#define STATUS_NOT_SUPPORTED 2
#endif
#ifndef STATUS_NO_MEMORY
#define STATUS_NO_MEMORY 3
#endif
#ifndef STATUS_INVALID_IMAGE_FORMAT
#define STATUS_INVALID_IMAGE_FORMAT 4
#endif
#ifndef STATUS_ACCESS_DENIED
#define STATUS_ACCESS_DENIED 5
#endif
#ifndef PROT_READ
#define PROT_READ 1
#define PROT_WRITE 2
#define PROT_NONE 0
#define MAP_SHARED 1
#define MAP_FAILED ((void *)-1)
#endif
#define VM_FLAGS_ANYWHERE 1
#define VM_INHERIT_NONE 0
#define VM_PROT_READ 1
#define VM_PROT_WRITE 2
#define ROUND_SIZE(addr,size,mask) (((size) + ((uintptr_t)(addr) & (mask)) + (mask)) & ~(size_t)(mask))
static const size_t page_size = 0x1000, page_mask = 0xfff, host_page_size = 0x4000, host_page_mask = 0x3fff;
struct file_view { void *base; size_t size; unsigned protect; };
struct host_view { mapping_t object; void *guest; unsigned char vprot[4]; };
static struct host_view host_views[4];
static unsigned host_count, canonical_size = 0x1000, canonical_maps;
static mapping_t canonical_object;

static mapping_t make_object(void)
{
#ifdef _WIN32
    HANDLE h = CreateFileMappingW(INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE, 0, 0x10000, NULL);
    assert(h); return h;
#else
    int fd = syscall(SYS_memfd_create, "image-shared-test", 0);
    assert(fd >= 0 && !ftruncate(fd, 0x10000)); return fd;
#endif
}
static void *map_object(mapping_t object, size_t size)
{
#ifdef _WIN32
    void *p = MapViewOfFile(object, FILE_MAP_ALL_ACCESS, 0, 0, size);
    assert(p); return p;
#else
    /* Linux can return a 4 KB-aligned mapping. This fixture models a 16 KB
     * iOS host frame, so reserve our own range before choosing its alignment.
     * MAP_FIXED replaces only pages belonging to that reservation. */
    size_t reserve_size = size + host_page_size, prefix, suffix;
    void *reserve = mmap(NULL, reserve_size, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    uintptr_t aligned;
    void *p;
    assert(reserve != MAP_FAILED);
    aligned = ((uintptr_t)reserve + host_page_mask) & ~(uintptr_t)host_page_mask;
    p = mmap((void *)aligned, size, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_FIXED, object, 0);
    assert(p == (void *)aligned);
    prefix = aligned - (uintptr_t)reserve;
    suffix = reserve_size - prefix - size;
    if (prefix) assert(!munmap(reserve, prefix));
    if (suffix) assert(!munmap((char *)p + size, suffix));
    return p;
#endif
}
static int unmap_object(void *p, size_t size)
{
#ifdef _WIN32
    (void)size; return !UnmapViewOfFile(p);
#else
    return munmap(p, size);
#endif
}
static int protect_object(void *p, size_t size, int prot)
{
#ifdef _WIN32
    DWORD old; return !VirtualProtect(p, size, prot ? PAGE_READWRITE : PAGE_NOACCESS, &old);
#else
    return mprotect(p, size, prot);
#endif
}
static int test_fstat(int fd, struct stat *st) { (void)fd; memset(st, 0, sizeof(*st)); st->st_size = canonical_size; return 0; }
static void *test_mmap(void *addr, size_t size, int prot, int flags, int fd, off_t offset)
{
    (void)addr; (void)fd; assert(!offset && prot == (PROT_READ | PROT_WRITE) && flags == MAP_SHARED);
    canonical_maps++; return map_object(canonical_object, size);
}
static int test_munmap(void *p, size_t size) { canonical_maps--; return unmap_object(p, size); }
static unsigned get_page_vprot(void *addr)
{
    unsigned i;
    for (i = 0; i < host_count; i++)
        if ((uintptr_t)addr >= (uintptr_t)host_views[i].guest &&
            (uintptr_t)addr - (uintptr_t)host_views[i].guest < 0x4000)
            return host_views[i].vprot[((uintptr_t)addr - (uintptr_t)host_views[i].guest) >> 12];
    return 0;
}
static int mach_task_self(void) { return 1; }
static int mach_vm_remap(int task, mach_vm_address_t *alias, size_t size, unsigned mask,
                         int flags, int task2, uintptr_t source, int copy, int *cur, int *max, int inherit)
{
    unsigned i;
    (void)task; (void)mask; (void)flags; (void)task2; (void)copy; (void)cur; (void)max; (void)inherit;
    for (i = 0; i < host_count; i++) if (source == (uintptr_t)host_views[i].guest)
    { *alias = (uintptr_t)map_object(host_views[i].object, size); return 0; }
    return 1;
}
static int mach_vm_protect(int task, uintptr_t addr, size_t size, int maximum, int prot)
{ (void)task; (void)maximum; return protect_object((void *)addr, size, prot); }
static int mach_vm_deallocate(int task, uintptr_t addr, size_t size)
{ (void)task; return unmap_object((void *)addr, size); }
static IMAGE_DATA_DIRECTORY *get_data_dir(IMAGE_NT_HEADERS *nt, SIZE_T total, ULONG index)
{
    IMAGE_DATA_DIRECTORY *d = &nt->OptionalHeader.DataDirectory[index];
    (void)total; return d->Size ? d : NULL;
}
#ifdef _WIN32
#define dprintf test_dprintf
static int test_dprintf(int fd, const char *format, ...) { (void)fd; (void)format; return 0; }
#endif
#define mmap test_mmap
#define munmap test_munmap
#define mprotect protect_object
#define fstat test_fstat
#include "pp_image_shared_ios.h"

/* A stopped CPU context is a seam: use simple architectural load/store effects
 * for the fixture encodings, while exercising the actual shipped service. */
typedef struct { uint64_t regs[32], sp, pc; unsigned char vectors[32][16]; unsigned writebacks; } test_ctx;
#define ucontext_t test_ctx
#define PC_sig(ctx) ((ctx)->pc)
#define SP_sig(ctx) ((ctx)->sp)
static uint64_t ios_get_reg(test_ctx *c, int n) { return n == 31 ? 0 : c->regs[n]; }
static void ios_ld_setreg(test_ctx *c, int n, uint64_t v) { if (n != 31) c->regs[n] = v; }
static int ios_exc_read_insn(uintptr_t pc, uint32_t *insn) { memcpy(insn, (void *)pc, 4); return 1; }
static int ios_subfloor_classify(uint32_t insn, unsigned *bytes, int *write)
{
    switch (insn)
    {
    case 0xb9400001: case 0xb9000001: *bytes = 4; break;
    case 0xf9400001: case 0xf9000001: *bytes = 8; break;
    case 0x3dc00001: case 0x3d800001: *bytes = 16; break;
    default: return 0;
    }
    *write = !(insn & (1u << 22)); return 1;
}
static int ios_emulate_load(test_ctx *c, uint32_t insn, uintptr_t addr)
{
    unsigned bytes; int write;
    if (!ios_subfloor_classify(insn, &bytes, &write) || write) return 0;
    if (bytes == 16) memcpy(c->vectors[1], (void *)addr, bytes);
    else { c->regs[1] = 0; memcpy(&c->regs[1], (void *)addr, bytes); }
    return 1;
}
static int ios_emulate_store(test_ctx *c, uint32_t insn, uintptr_t addr)
{
    unsigned bytes; int write;
    if (!ios_subfloor_classify(insn, &bytes, &write) || !write) return 0;
    memcpy((void *)addr, bytes == 16 ? (void *)c->vectors[1] : (void *)&c->regs[1], bytes); return 1;
}
static int ios_emulate_store_rel(test_ctx *c, uint32_t insn, uintptr_t addr)
{ (void)c; (void)insn; (void)addr; return 0; }
static void ios_subfloor_writeback(test_ctx *c, uint32_t insn, uintptr_t addr)
{ (void)insn; (void)addr; c->writebacks++; }
#include "pp_image_shared_signal.h"

static void make_view(struct file_view *v, IMAGE_NT_HEADERS *nt, IMAGE_SECTION_HEADER *s,
                      unsigned frame_rva, unsigned shared_offset, unsigned char marker)
{
    struct host_view *h = &host_views[host_count++]; unsigned i;
    h->object = make_object(); h->guest = map_object(h->object, 0x4000);
    memset(h->guest, marker, 0x4000);
    for (i = 0; i < 4; i++) h->vprot[i] = VPROT_COMMITTED | VPROT_READ;
    h->vprot[shared_offset >> 12] |= VPROT_WRITE;
    v->base = (void *)((uintptr_t)h->guest - frame_rva); v->size = frame_rva + 0x5000;
    v->protect = VPROT_X64_IMAGE;
    memset(nt, 0, sizeof(*nt)); nt->FileHeader.Machine = IMAGE_FILE_MACHINE_AMD64; nt->FileHeader.NumberOfSections = 3;
    memset(s, 0, 3 * sizeof(*s));
    s[0].VirtualAddress = frame_rva; s[0].Misc.VirtualSize = shared_offset; s[0].Characteristics = IMAGE_SCN_MEM_READ;
    s[1].VirtualAddress = frame_rva + shared_offset; s[1].Misc.VirtualSize = 12;
    s[1].SizeOfRawData = 512; s[1].Characteristics = IMAGE_SCN_MEM_READ | IMAGE_SCN_MEM_WRITE | IMAGE_SCN_MEM_SHARED;
    s[2].VirtualAddress = frame_rva + shared_offset + 0x1000; s[2].Misc.VirtualSize = 0x1000;
    s[2].Characteristics = IMAGE_SCN_MEM_READ;
}
static int access_word(uintptr_t addr, uint32_t insn, uint64_t *value, uintptr_t teb)
{
    test_ctx c = {0}; int result;
    c.regs[0] = addr; c.regs[1] = *value; c.pc = (uintptr_t)&insn;
    result = ios_image_shared_service(&c, (void *)addr, teb);
    *value = c.regs[1]; return result;
}

static THREAD_RETURN increment_worker(void *p)
{
    unsigned i; uint64_t old; struct ppis_reservation reservation = {0};
    for (i = 0; i < 25000; i++) assert(ppis_atomic(0xb8210000, (uintptr_t)p, 0, 1, 1, &reservation, &old));
    return 0;
}

static unsigned retirement_started, retirement_finished;
static THREAD_RETURN retire_worker(void *p)
{
    __atomic_store_n(&retirement_started, 1, __ATOMIC_SEQ_CST);
    ios_image_shared_drop(p);
    __atomic_store_n(&retirement_finished, 1, __ATOMIC_SEQ_CST);
    return 0;
}

int main(void)
{
    struct file_view views[2]; IMAGE_NT_HEADERS nt[2]; IMAGE_SECTION_HEADER s[2][3];
    struct ppis_range ranges[2]; uint64_t epochs[2], value, result; int tokens[2]; unsigned i;
    struct ppis_reservation reservation = {0}; uintptr_t ea; size_t n;
    uint32_t *canonical;
    canonical_object = make_object(); canonical = map_object(canonical_object, 0x4000);
    canonical[0] = 0x11223344;
    /* Real DOOM/Doom Vulkan RVA offsets: private .pdata and .gfids are never
     * widened into the canonical shared mapping. No game code or data fixture. */
    make_view(&views[0], &nt[0], s[0], 0x1237c000, 0x2000, 0xaa);
    make_view(&views[1], &nt[1], s[1], 0x13a6c000, 0x3000, 0xbb);
    for (i = 0; i < 2; i++)
    {
        IMAGE_DATA_DIRECTORY *reloc = &nt[i].OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC];
        IMAGE_BASE_RELOCATION *block = (IMAGE_BASE_RELOCATION *)((char *)host_views[i].guest + 0x1000);
        WORD *fixups = (WORD *)(block + 1);
        nt[i].OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IAT].VirtualAddress = s[i][1].VirtualAddress;
        nt[i].OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IAT].Size = 8;
        assert(ios_image_shared_map(&views[i], 1, &nt[i], s[i], 1, 0x1000, 0, 0x1000) != 0);
        nt[i].OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IAT].Size = 0;
        canonical_size = 12;
        assert(ios_image_shared_map(&views[i], 1, &nt[i], s[i], 1, 0x1000, 0, 0x1000) != 0);
        canonical_size = 0x1000;
        s[i][0].Characteristics |= IMAGE_SCN_MEM_WRITE;
        assert(ios_image_shared_map(&views[i], 1, &nt[i], s[i], 1, 0x1000, 0, 0x1000) != 0);
        s[i][0].Characteristics &= ~IMAGE_SCN_MEM_WRITE;
#ifdef _WIN32
        _putenv_s("PLAYPORT_SMALL_SHARED_IMAGE", "0");
#else
        setenv("PLAYPORT_SMALL_SHARED_IMAGE", "0", 1);
#endif
        assert(ios_image_shared_map(&views[i], 1, &nt[i], s[i], 1, 0x1000, 0, 0x1000) == STATUS_NOT_SUPPORTED);
        assert(ios_image_shared_owned == i);
#ifdef _WIN32
        _putenv_s("PLAYPORT_SMALL_SHARED_IMAGE", "1");
#else
        setenv("PLAYPORT_SMALL_SHARED_IMAGE", "1", 1);
#endif
        assert(!ios_image_shared_map(&views[i], 1, &nt[i], s[i], 1, 0x1000, 0, 0x1000));
        assert(ios_image_shared_pending(&views[i]));
        assert(ios_image_shared_fixups_safe(&views[i], &nt[i], 1));
        reloc->VirtualAddress = s[i][0].VirtualAddress + 0x1000; reloc->Size = 12;
        block->VirtualAddress = s[i][1].VirtualAddress; block->SizeOfBlock = 12;
        fixups[0] = IMAGE_REL_BASED_DIR64 << 12; fixups[1] = 0;
        assert(!ios_image_shared_fixups_safe(&views[i], &nt[i], 1));
        assert(ios_image_shared_fixups_safe(&views[i], &nt[i], 0));
        block->VirtualAddress = s[i][0].VirtualAddress;
        assert(ios_image_shared_fixups_safe(&views[i], &nt[i], 1));
        block->SizeOfBlock = 7;
        assert(!ios_image_shared_fixups_safe(&views[i], &nt[i], 1));
        reloc->Size = 0;
        assert(!ios_image_shared_activate(&views[i]));
        tokens[i] = ios_image_shared_acquire((uintptr_t)host_views[i].guest, 1, &ranges[i], &epochs[i]);
        assert(tokens[i] && ios_image_shared_frame(host_views[i].guest));
        ios_image_shared_release(tokens[i]);
    }
    assert(canonical_maps == 2);
    value = 0; assert(access_word(ranges[0].guest, 0xb9400001, &value, 1) == 1 && value == 0x11223344);
    value = 0x55667788; assert(access_word(ranges[0].guest, 0xb9000001, &value, 1) == 1);
    value = 0; assert(access_word(ranges[1].guest, 0xb9400001, &value, 2) == 1 && value == 0x55667788);
    assert(canonical[0] == 0x55667788);
    value = 0; assert(access_word(ranges[0].frame, 0xb9400001, &value, 1) == 1 && value == 0xaaaaaaaa);
    value = 0; assert(access_word(ranges[1].frame, 0xb9400001, &value, 2) == 1 && value == 0xbbbbbbbb);
    value = 7; assert(access_word(ranges[0].frame, 0xb9000001, &value, 1) == -1); /* read-only neighbour */
    host_views[0].vprot[0] |= VPROT_WRITECOPY;
    assert(access_word(ranges[0].frame, 0xb9000001, &value, 1) == 1);
    assert(*(uint32_t *)ranges[0].private_alias == 7 && *(uint32_t *)ranges[1].private_alias == 0xbbbbbbbb);
    assert(canonical[0] == 0x55667788);
    host_views[0].vprot[2] |= VPROT_GUARD;
    value = 0; assert(access_word(ranges[0].guest, 0xb9400001, &value, 1) == -1);
    host_views[0].vprot[2] &= ~VPROT_GUARD;
    /* A normal load crossing private -> shared gathers from both backings. */
    value = 0; assert(access_word(ranges[0].guest - 4, 0xf9400001, &value, 1) == 1);
    assert(value == UINT64_C(0x55667788aaaaaaaa));
    n = 16; assert(ppis_route(&ranges[0], ranges[0].guest - 4, &n) && n == 4);
    n = 1; assert(!ppis_route(&ranges[0], ranges[0].frame + 0x4000, &n));
    /* True atomic LSE, CAS and exclusive retry; concurrent canonical aliases. */
    canonical[0] = 0;
#ifdef _WIN32
    { HANDLE threads[4]; for (i = 0; i < 4; i++) threads[i] = CreateThread(NULL, 0, increment_worker,
          (void *)(i & 1 ? ranges[0].shared : ranges[1].shared), 0, NULL);
      assert(WaitForMultipleObjects(4, threads, TRUE, INFINITE) == WAIT_OBJECT_0);
      for (i = 0; i < 4; i++) CloseHandle(threads[i]); }
#else
    { pthread_t threads[4]; for (i = 0; i < 4; i++) assert(!pthread_create(&threads[i], NULL, increment_worker,
          (void *)(i & 1 ? ranges[0].shared : ranges[1].shared)));
      for (i = 0; i < 4; i++) assert(!pthread_join(threads[i], NULL)); }
#endif
    assert(canonical[0] == 100000);
    assert(ppis_atomic(0x88a07c01, ranges[0].shared, 9, 100000, epochs[0], NULL, &result) && result == 100000);
    assert(canonical[0] == 9);
    assert(ppis_atomic(0x885f7c01, ranges[0].shared, 0, 0, epochs[0], &reservation, &result) && result == 9);
    canonical[0] = 11;
    assert(ppis_atomic(0x88027c01, ranges[0].shared, 10, 0, epochs[0], &reservation, &result) && result == 1 && canonical[0] == 11);
    assert(ppis_atomic(0x885ffc01, ranges[0].shared, 0, 0, epochs[0], &reservation, &result));
    assert(ppis_atomic(0x8802fc01, ranges[0].shared, 12, 0, epochs[0], &reservation, &result) && !result && canonical[0] == 12);
    assert(ppis_atomic_kind(0x08207c01) == 0); /* CASP is not a scalar CAS. */
    assert(!ppis_atomic(0x88a07c01, ranges[0].shared + 1, 0, 0, epochs[0], NULL, &result));
    /* Register effects and per-thread exclusive state through the fault entry. */
    {
        test_ctx c = {0}; uint32_t instruction = 0x885f7c01;
        c.regs[0] = ranges[1].guest; c.pc = (uintptr_t)&instruction;
        assert(ios_image_shared_service(&c, (void *)ranges[1].guest, 42) == 1 && c.regs[1] == 12);
        canonical[0] = 13; instruction = 0x88027c01; c.regs[1] = 99;
        assert(ios_image_shared_service(&c, (void *)ranges[1].guest, 42) == 1 && c.regs[2] == 1 && canonical[0] == 13);
        instruction = 0x885f7c01;
        assert(ios_image_shared_service(&c, (void *)ranges[1].guest, 42) == 1 && c.regs[1] == 13);
        instruction = 0x88027c01; c.regs[1] = 12;
        assert(ios_image_shared_service(&c, (void *)ranges[1].guest, 42) == 1 && !c.regs[2] && canonical[0] == 12);
        instruction = 0x08a27c01; c.regs[2] = 12; c.regs[1] = 21; /* CASB */
        assert(ios_image_shared_service(&c, (void *)ranges[1].guest, 42) == 1 && c.regs[2] == 12 && canonical[0] == 21);
        canonical[0] = 12;
    }
    assert(ppis_address(0xa9400801, 0x1000, 0, &ea) && ea == 0x1000);
    assert(ppis_address(0xa9ff0801, 0x1000, 0, &ea) && ea == 0xff0); /* LDP pre -16 */
    assert(ppis_address(0xf9400801, 0x1000, 0, &ea) && ea == 0x1010);
    assert(!ppis_address(0, 0x1000, 0, &ea));
    ios_image_shared_drop(&views[0]);
    assert(!ios_image_shared_acquire(ranges[0].guest, 4, &ranges[0], &value));
    value = 0; assert(access_word(ranges[1].guest, 0xb9400001, &value, 2) == 1 && value == 12);
    /* Retirement cannot unmap an alias while a fault reader is using it. */
    tokens[1] = ios_image_shared_acquire(ranges[1].guest, 4, &ranges[1], &epochs[1]);
    assert(tokens[1]);
    {
#ifdef _WIN32
        HANDLE thread = CreateThread(NULL, 0, retire_worker, &views[1], 0, NULL);
        assert(thread);
#else
        pthread_t thread;
        assert(!pthread_create(&thread, NULL, retire_worker, &views[1]));
#endif
        while (!__atomic_load_n(&retirement_started, __ATOMIC_SEQ_CST)) sched_yield();
        while (__atomic_load_n(&ios_image_shared_slots[tokens[1] - 1].epoch, __ATOMIC_SEQ_CST)) sched_yield();
        assert(!__atomic_load_n(&retirement_finished, __ATOMIC_SEQ_CST));
        assert(*(uint32_t *)ranges[1].shared == 12);
        ios_image_shared_release(tokens[1]);
#ifdef _WIN32
        assert(WaitForSingleObject(thread, INFINITE) == WAIT_OBJECT_0); CloseHandle(thread);
#else
        assert(!pthread_join(thread, NULL));
#endif
        assert(__atomic_load_n(&retirement_finished, __ATOMIC_SEQ_CST));
    }
    assert(!canonical_maps);
    puts("shared aliases, private neighbours, permissions, boundary loads, atomics and retirement passed");
    return 0;
}
