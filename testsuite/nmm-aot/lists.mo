encapsulated package Lists
public function sumList
  "Recursive list traversal via match. Stresses uniontype-cons pattern binding + integer accumulation."
  input list<Integer> lst;
  output Integer total;
algorithm
  total := match lst
    local Integer h; list<Integer> t;
    case {} then 0;
    case h :: t then h + sumList(t);
  end match;
end sumList;

public function lastOr
  "Real matchcontinue with backtracking via fail(): first case fails on empty,
   fallthrough returns default."
  input list<Integer> lst;
  input Integer default;
  output Integer v;
algorithm
  v := matchcontinue (lst, default)
    local Integer x;
    case ({x}, _) then x;
    case (_ :: _, _) then lastOr(listRest(lst), default);
    else default;
  end matchcontinue;
end lastOr;

/* Option pattern */
public function orElse
  input Option<Integer> o;
  input Integer d;
  output Integer v;
algorithm
  v := match o
    local Integer x;
    case SOME(x) then x;
    case NONE()  then d;
  end match;
end orElse;
end Lists;
