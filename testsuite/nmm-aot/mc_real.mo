encapsulated package MCReal
/* Real-world matchcontinue: fail() inside a case body forces
   backtracking to the next case. Classic MetaModelica idiom. */
public function safeDiv
  input Integer a;
  input Integer b;
  output Integer r;
algorithm
  r := matchcontinue (a, b)
    /* First case: divide by zero — fail(), fall to next case */
    case (_, 0) algorithm fail(); then 0;
    case (_, _) then intDiv(a, b);
  end matchcontinue;
end safeDiv;

/* matchcontinue on a uniontype with backtracking */
uniontype Shape
  record CIRCLE  Real r; end CIRCLE;
  record SQUARE  Real s; end SQUARE;
end Shape;

public function area
  input Shape sh;
  output Real a;
algorithm
  a := matchcontinue sh
    local Real x;
    case CIRCLE(r=x) then 3.14 * x * x;
    case SQUARE(s=x) then x * x;
  end matchcontinue;
end area;
end MCReal;
