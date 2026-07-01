encapsulated package FactSimple
public function fact
  input Integer n;
  output Integer f;
algorithm
  f := match n
    case 0 then 1;
    else n * fact(n - 1);
  end match;
end fact;
end FactSimple;
