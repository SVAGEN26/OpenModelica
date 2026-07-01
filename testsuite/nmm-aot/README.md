NativeMetaModelicaCompiler AoT fixtures
=======================================

Regression + isolation fixtures for the `-d=llvm_aot` path added on this branch.
Not part of the CI testsuite. Runs one `.mo` file at a time under the pattern:

  omc -g=MetaModelica -d=jit_eval_func -d=llvm_aot <script>.mos

That emits `<Pkg>_<function>.bc` in cwd. Turn it into a native executable
with `llc-16 <bc> -filetype=obj -o out.o` + a small C driver linked against
`libSimulationRuntimeC` + `libOpenModelicaCompiler` (until the JIT-only
runtime wrappers `mmc_mk_box_jit` / `mmc_mk_icon_wrapper` migrate into
`libomcruntime`).

Status snapshot (LLVM 16, 2026-07-01)
-------------------------------------

- `list_intRange` from `Compiler/Util/List.mo`: PASSES end-to-end. Native
  binary returns `{1,2,3,4,5}` matching the classical omc.

- `fact_simple.mo` :: `FactSimple.fact` (recursive Integer with plain
  `match`): PASSES bitcode emission.

- `mc_variants.mo` :: `MCVariants.factA` (recursive Integer with
  `matchcontinue`, no guard, no fail): PASSES bitcode emission.

- `mc_variants.mo` :: `MCVariants.factB` (recursive Integer with `match`
  and `guard`): PASSES bitcode emission.

- `mc_variants.mo` :: `MCVariants.factC` (recursive Integer with `match`
  and `fail()` in the else branch): CRASHES `MidToLLVM.genCall` ->
  `llvm_gen.cpp createCall` -> `llvm_gen_util.hpp:110 getLLVMType(0)`
  returns `nullptr`, then `llvm::FunctionType::get(nullptr, ...)`
  segfaults. Diagnostic: "Attempted to deduce unknown type: 0" printed
  to stderr just before the crash. Root cause: `MidToLLVM.genCall`
  passes an uninitialized MODELICA_* type id when lowering the runtime
  throw call for `fail()` in a non-matchcontinue context.

- `reverse.mo` :: `RevExample.myReverse` (polymorphic matchcontinue +
  listAppend + recursion): PASSES bitcode emission. Not linked / run
  yet.
