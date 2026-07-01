# NativeMetaModelicaCompiler — session insights

Handoff for the AoT-compilation-of-MetaModelica experiment. Not for
upstream. Lives on the `NativeMetaModelicaCompiler` branch of the
`SVAGEN26/OpenModelica` fork.

## Why this branch exists

The `revive-llvm-jit` PR is the JIT for Modelica-model simulation. This
branch asks a separate question: can we lower a compiler `.mo` source
ahead-of-time through the same MidToLLVM infrastructure and produce a
native executable? If yes, that is the foundation for eventually
bootstrapping omc itself through LLVM instead of C.

Scope: Linux + LLVM 16 only. Windows / macOS are out of scope until the
Linux path is boring.

## What is on this branch

1. New debug flag `-d=llvm_aot` (`Flags.mo` id 206,
   registered in `FlagsUtil.mo`).
2. `CevalScript.mo` diverts past `runJIT` when the flag is set:
   after `MidToLLVM.genProgram(...)`, calls
   `EXT_LLVM.writeBitcodeToFile(name + ".bc")` and returns
   `Values.NORETCALL()` instead of executing.
3. Fixtures under `testsuite/nmm-aot/`:
   - `README.md` — invocation recipe and status matrix
   - `fact_simple.mo`, `mc_variants.mo`, `reverse.mo` — MidToLLVM
     coverage probes.
4. No changes to `llvm_gen.cpp` were needed — the C++-side
   `writeBitcodeToFile` was already present.

## Reproduction recipe

Build with LLVM ON:

```
cmake -S /workspace/OpenModelica -B /workspace/OpenModelica/build_cmake \
      -DOM_OMC_ENABLE_LLVM=ON -DOM_OMC_ENABLE_LLVM_JIT=ON
cmake --build /workspace/OpenModelica/build_cmake --target install -j$(nproc)
```

Emit bitcode for one MetaModelica function:

```
cat > /tmp/list_intRange_aot.mos <<'EOF'
setCommandLineOptions("-g=MetaModelica");
setCommandLineOptions("-d=jit_eval_func");
setCommandLineOptions("-d=llvm_aot");
loadFile("/workspace/OpenModelica/OMCompiler/Compiler/Util/List.mo"); getErrorString();
List.intRange(5); getErrorString();
EOF
cd /tmp && omc list_intRange_aot.mos
# -> /tmp/List_intRange.bc
```

Turn into an executable (Linux, LLVM 16):

```
llc-16 List_intRange.bc -filetype=obj -o List_intRange.o
clang-16 -DOM_HAVE_PTHREADS \
    -I${OMC_INSTALL}/include/omc/c \
    -I${OMC_INSTALL}/include/omc \
    -c driver.c -o driver.o
clang-16 driver.o List_intRange.o \
    -L${OMC_INSTALL}/lib/x86_64-linux-gnu/omc \
    -Wl,-rpath,${OMC_INSTALL}/lib/x86_64-linux-gnu/omc \
    -lSimulationRuntimeC -lOpenModelicaCompiler -lOpenModelicaRuntimeC \
    -lpthread \
    -o list_test
```

A minimal `driver.c` that walks the returned `list<Integer>` and prints
elements lives in git history for commit `f3f784c3a9` in the session
transcript; recreate it inline when picking up.

## Coverage matrix as of 2026-07-01

Bitcode emission (does `omc -d=llvm_aot` reach `writeBitcodeToFile`
without a crash)?

| construct                                              | result | notes |
|--------------------------------------------------------|:------:|-------|
| while-loop + cons + int box (`List.intRange`)          | pass   | linked and ran end-to-end, correct output |
| recursive `Integer` with plain `match`                 | pass   | `fact_simple.mo` |
| recursive `Integer` with `matchcontinue`               | pass   | `mc_variants.mo` :: `factA` |
| recursive `Integer` with `match` + `guard`             | pass   | `mc_variants.mo` :: `factB` |
| polymorphic `matchcontinue` + `listAppend` + recursion | pass   | `reverse.mo` :: `myReverse` |
| `match` with `fail()` in `else` branch                 | CRASH  | see next section |

## First real MidToLLVM bug (session's actionable finding)

Repro: `MCVariants.factC(5)` in `testsuite/nmm-aot/mc_variants.mo`.

Symptom on stderr:
```
Attempted to deduce unknown type: 0
Limited backtrace at point of segmentation fault
  MidToLLVM.genCall -> EXT_LLVM.genCall -> createCall
  -> createExternalCallDecl -> llvm::FunctionType::get(nullptr, ...)
```

Localization:
- Message emitted from `OMCompiler/Compiler/runtime/llvm_gen_util.hpp:110`
  when `getLLVMType()` sees a type id `0` (valid MODELICA_* ids start at 1).
- `getLLVMType(0)` returns `nullptr`, which then flows into
  `llvm::FunctionType::get(retTy, argTys, isVariadic)` at the crash site.

Root cause: `MidToLLVM.genCall` (or a predecessor) passes an
uninitialized MODELICA_* type id when lowering the runtime throw call
for `fail()` outside a `matchcontinue` context. This branch does not
touch the fix; it captures the repro.

Where to look when fixing:
- `OMCompiler/Compiler/LLVM/MidToLLVM.mo` — `genTerminator` /
  `genCall` / the `MidCode.LONGJMP` handler around line 814.
- `OMCompiler/Compiler/MidCode/DAEToMid.mo` — how `fail()` lowers to
  `LONGJMP`; does it set a return-type field on the throw call?
- `OMCompiler/Compiler/runtime/llvm_gen.cpp:createCall` — verify what
  type id it receives when the caller intends "no return".

Likely fix: `fail()` should not need a call-return type at all
(it does not return). Either pass `MODELICA_VOID` explicitly, or gate
the LLVM `FunctionType::get` construction on the terminator variant so
`LONGJMP` uses a `void`-returning declaration.

## Warts worth remembering

1. **Runtime library layering is wrong for AoT.** `mmc_mk_box_jit` and
   `mmc_mk_icon_wrapper` live in `libOpenModelicaCompiler.so`. For AoT
   binaries to not drag the compiler in, these need to move into
   `libomcruntime.a` (or a small dedicated `libomcmm_rt`).
2. **`writeBitcodeToFile` writes to CWD, not an explicit dir.** Good
   enough for the experiment; for pipeline work add a path argument
   plumbed from a config flag.
3. **`-d=llvm_aot` is scoped to `jit_eval_func` in `CevalScript.mo`.**
   That means it only fires when omc is evaluating a
   MetaModelica function call in the interpreter. There is no
   "compile every function in this file" driver yet — that is the
   next infra step.
4. **JIT-side return-value marshalling crashes on `List.intRange` under
   `-d=jit_eval_func` without `-d=llvm_aot`.** The crash is in
   `valueLst_to_type_descs` and is orthogonal to this branch's goal.
   Noted so it does not distract when re-exploring the JIT path.

## Next steps when picking this back up

Ordered by expected value / cost ratio.

1. **Fix the `fail()` bug.** Small, precisely located. Once fixed,
   `MCVariants.factC` and any real compiler `.mo` that uses `fail()`
   in a case body should lower. This is a genuine unblock, not just a
   demo.
2. **Add a batch driver.** Replace `List.intRange(5)` at the .mos
   level with a script that walks every function in a loaded package
   and calls it once with dummy inputs, so a single command yields
   `<Pkg>_*.bc` for every function. That gives a coverage bitmap
   in one run instead of one function per attempt.
3. **Try `Compiler/Util/AvlTree.mo`.** 12 `matchcontinue`, 0 imports
   in the module header, uniontype-heavy. First real self-contained
   compiler unit that stresses uniontype pattern binding at scale.
4. **Move runtime wrappers into `libomcruntime`.** `mmc_mk_box_jit`,
   `mmc_mk_icon_wrapper`, `mmc_lcon_to_value_wrapper` in
   `OMCompiler/Compiler/runtime/llvm_gen_wrappers.c`. Path is either
   (a) build them into the runtime library directly, or (b) rename the
   IR-emitted calls to the plain runtime names (`mmc_mk_box*` +
   `mmc_mk_icon`) and drop the wrappers. Option (b) is cleaner but
   touches `llvm_gen.cpp`.
5. **Real bootstrap chain.** Once a small compiler package is fully
   AoT-lowerable, wire a Makefile target that compiles it against the
   in-tree C runtime and swap in the LLVM-hosted object during a
   build. If that works, escalate to the full FrontEnd.
6. **Debug info.** DWARF emission from `MidToLLVM`. Not started.
   Only worth doing after the pipeline is stable.

## What the SVAGEN26/JKRT branch shape looks like right now

```
NativeMetaModelicaCompiler
  6d87f6334a  NativeMetaModelicaCompiler: capture AoT fixtures + first found bug
  f3f784c3a9  NativeMetaModelicaCompiler: add -d=llvm_aot for bitcode emission
  cf721534bc  (base — revive-llvm-jit HEAD at fork point)
```

Fork off from here for further work. Nothing on this branch is
intended to be squashed into the upstream JIT PR.
