encapsulated package MCVariants
/* Variant A: matchcontinue, no guard, no fail */
public function factA
  input Integer n;
  output Integer f;
algorithm
  f := matchcontinue n
    case 0 then 1;
    else n * factA(n - 1);
  end matchcontinue;
end factA;

/* Variant B: match with guard */
public function factB
  input Integer n;
  output Integer f;
algorithm
  f := match n
    case 0 then 1;
    case _ guard n > 0 then n * factB(n - 1);
    else 0;
  end match;
end factB;

/* Variant C: match with fail() branch */
public function factC
  input Integer n;
  output Integer f;
algorithm
  f := match n
    case 0 then 1;
    case _ guard n > 0 then n * factC(n - 1);
    else algorithm fail(); then 0;
  end match;
end factC;
end MCVariants;
