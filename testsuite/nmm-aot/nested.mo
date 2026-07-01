encapsulated package Nested
uniontype Expr
  record LIT   Integer v;                 end LIT;
  record ADD   Expr l; Expr r;            end ADD;
  record MUL   Expr l; Expr r;            end MUL;
end Expr;

/* Recursive tree eval — construction + pattern binding of nested fields */
public function eval
  input Expr e;
  output Integer v;
algorithm
  v := match e
    local Expr a, b;
    case LIT(v=v)      then v;
    case ADD(l=a, r=b) then eval(a) + eval(b);
    case MUL(l=a, r=b) then eval(a) * eval(b);
  end match;
end eval;

/* Constructor test */
public function twoPlusThree
  output Integer v;
algorithm
  v := eval(ADD(LIT(2), LIT(3)));
end twoPlusThree;

/* Tuple pattern binding on the outputs of a multi-output call */
public function useTuple
  input Integer a;
  input Integer b;
  output Integer sum;
  output Integer prod;
algorithm
  sum := a + b;
  prod := a * b;
end useTuple;

public function tupleCaller
  output Integer answer;
protected
  Integer s, p;
algorithm
  (s, p) := useTuple(3, 4);
  answer := s + p; // 7 + 12 = 19
end tupleCaller;
end Nested;
