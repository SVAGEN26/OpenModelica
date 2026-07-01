encapsulated package RevExample
public function myReverse<T>
  "Classic matchcontinue-based reverse. Recursion + cons + matchcontinue = fail."
  input list<T> lst;
  output list<T> outLst;
algorithm
  outLst := matchcontinue lst
    local T h; list<T> t;
    case {} then {};
    case h :: t then listAppend(myReverse(t), {h});
  end matchcontinue;
end myReverse;

public function myFactorial
  "matchcontinue with a fail() branch."
  input Integer n;
  output Integer f;
algorithm
  f := matchcontinue n
    case 0 then 1;
    case _ guard n > 0 then n * myFactorial(n - 1);
    else algorithm fail(); then 0;
  end matchcontinue;
end myFactorial;
end RevExample;
