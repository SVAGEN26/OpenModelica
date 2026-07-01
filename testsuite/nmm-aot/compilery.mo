encapsulated package Compilery
/* Production-style tokens: uniontype with mixed fields */
uniontype Token
  record TIDENT  String name;              end TIDENT;
  record TINT    Integer value;            end TINT;
  record TPLUS                             end TPLUS;
  record TMINUS                            end TMINUS;
end Token;

/* Recursive list-of-tokens sum evaluator. */
public function sumTokens
  input list<Token> toks;
  input Integer acc;
  output Integer total;
algorithm
  total := match (toks, acc)
    local
      Integer n;
      list<Token> rest;
      String s;
    case ({}, _) then acc;
    case (TINT(value=n) :: rest, _) then sumTokens(rest, acc + n);
    case (TIDENT(name=s) :: rest, _) then sumTokens(rest, acc);
    case (TPLUS() :: rest, _) then sumTokens(rest, acc);
    case (TMINUS() :: rest, _) then sumTokens(rest, acc);
  end match;
end sumTokens;

/* Guard clauses on a match — classic compiler idiom. */
public function classifyInt
  input Integer n;
  output String label;
algorithm
  label := match n
    case _ guard n < 0 then "neg";
    case 0 then "zero";
    case _ guard n < 10 then "small";
    case _ guard n < 100 then "medium";
    else "big";
  end match;
end classifyInt;

/* Nested option + list */
public function firstOrDefault
  input Option<list<Integer>> ol;
  input Integer default;
  output Integer v;
algorithm
  v := matchcontinue ol
    local Integer x;
    case SOME(x :: _) then x;
    else default;
  end matchcontinue;
end firstOrDefault;
end Compilery;
