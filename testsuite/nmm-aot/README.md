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

Status snapshot (LLVM 16, 2026-07-01, after the fix session on this branch)
---------------------------------------------------------------------------

Passing (bitcode emission):

  Compiler/Util/List.mo :: List.intRange
      end-to-end to native exe; returns {1,2,3,4,5}.

  fact_simple.mo :: FactSimple.fact
      recursive Integer, plain match.

  mc_variants.mo :: MCVariants.factA / factB / factC
      matchcontinue (A); match+guard (B); match with fail() in else (C).
      factC was crashing pre-fix (see below); now passes.

  mc_real.mo :: MCReal.safeDiv
      matchcontinue with fail() -> next-case backtracking.

  mc_real.mo :: MCReal.area
      uniontype pattern with field binding.

  reverse.mo :: RevExample.myReverse
      polymorphic matchcontinue + listAppend + recursion.

  nested.mo :: Nested.eval / twoPlusThree / useTuple
      nested uniontype (Expr with LIT/ADD/MUL) recursive tree traversal;
      DAE.TUPLE lowering (was failing pre-fix); multi-output function
      definition.

  lists.mo :: Lists.sumList / lastOr / orElse
      cons pattern + Integer accumulator; matchcontinue with fall-through;
      Option SOME/NONE match.

  strings.mo :: Strings.lenTwice / concat3 / isEmpty / firstChar
      string runtime calls (stringLength, +, ==, substring).

  compilery.mo :: Compilery.sumTokens / classifyInt / firstOrDefault
      4-variant uniontype with mixed fields + recursion; guarded match
      with 5 arms including else; nested SOME(x :: _).

Out of attack surface (interpreter dispatch limits, not our bugs):

  advanced.mo :: Advanced.useApply
      higher-order (function-typed argument). Silently skipped by the
      classical interpreter; never reaches JIT_EVAL_FUNC. Would need
      a real Modelica-level driver to exercise.

  nested.mo :: Nested.tupleCaller
      multi-output destructuring at .mos scope. Front-end interpreter
      limitation: (s, p) := f(...) fails with "Type mismatch in Tuple".

  arrays.mo :: Arrays.*
      array<Integer> functions never reach the JIT case. Some earlier
      matchcontinue arm in CevalScript.cevalCallFunctionEvaluateOrGenerate
      catches array-returning calls first. Not investigated further.

Bugs fixed on this branch (all with Cherry-pick-to: revive-llvm-jit)
-------------------------------------------------------------------

  1. MidToLLVM.genCall + llvm_gen_util.hpp createExternalCallDecl
     (commit 8ff3d1698a).
     fail() in a case body crashed because DAEToMid types the
     mmc_throw_internal call as T_UNKNOWN, and createExternalCallDecl
     fed the resulting null Type* into llvm::FunctionType::get. Fix
     overrides the return type to MODELICA_VOID at the site, plus a
     defensive MMC_THROW when retTy is null (mirrors the existing
     check in createFunctionType at llvm_gen.cpp:2562).

  2. DAEToMid.ExpToMid + MidToLLVM.genTypeCtorIndex
     (commit 33097a58b0).
     Nested uniontype construction (ADD(LIT(2), LIT(3))) hit
     "DAE.Exp to Mid conversion failed: TUPLE" because DAE.TUPLE was
     unhandled in ExpToMid. Added the lowering (same shape as
     META_TUPLE) plus the corresponding T_TUPLE ctor tag in
     MidToLLVM.

Non-bugs (documented, do not chase):

  - Values.NORETCALL() result is expected from -d=llvm_aot: the
    flag deliberately skips the JIT execution and returns nothing.
  - JIT-side valueLst_to_type_descs crash on List.intRange under
    -d=jit_eval_func WITHOUT -d=llvm_aot is orthogonal to this branch;
    documented in INSIGHT.md.

Next steps
----------

See INSIGHT.md for the ordered pickup list. Highest-value next moves:

  - Move runtime wrappers (mmc_mk_box_jit, mmc_mk_icon_wrapper,
    mmc_lcon_to_value_wrapper) out of libOpenModelicaCompiler and into
    libomcruntime, so AoT binaries do not need to link against the
    whole compiler shared object.

  - Add a batch driver that lowers every function in a loaded package
    to .bc in one command, rather than one-function-per-jit-eval-func
    call. That unblocks compiling a real compiler .mo end-to-end.

  - Once the batch driver is in place, try Compiler/Util/AvlSetInt.mo
    (extends BaseAvlSet) or Compiler/Util/Testsuite.mo (small,
    matchcontinue-based).
