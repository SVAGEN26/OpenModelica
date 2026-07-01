encapsulated package Advanced
/* Higher-order: function value as argument */
public function applyF
  input FnType f;
  input Integer x;
  output Integer y;
  partial function FnType
    input Integer a;
    output Integer b;
  end FnType;
algorithm
  y := f(x);
end applyF;

public function double
  input Integer a;
  output Integer b = a * 2;
end double;

public function useApply
  input Integer x;
  output Integer y;
algorithm
  y := applyF(double, x);
end useApply;

/* String ops */
public function greet
  input String who;
  output String msg;
algorithm
  msg := "Hello, " + who + "!";
end greet;

/* Tuple return */
public function divmod
  input Integer a;
  input Integer b;
  output Integer q;
  output Integer r;
algorithm
  q := intDiv(a, b);
  r := intMod(a, b);
end divmod;
end Advanced;
