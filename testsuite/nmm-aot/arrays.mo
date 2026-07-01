encapsulated package Arrays
public function arrLen
  "arrayLength runtime call."
  input array<Integer> a;
  output Integer n = arrayLength(a);
end arrLen;

public function arrSum
  "For-loop over array."
  input array<Integer> a;
  output Integer total = 0;
protected
  Integer i;
algorithm
  for i in 1:arrayLength(a) loop
    total := total + arrayGet(a, i);
  end for;
end arrSum;

public function arrMake
  "Construct an array literal."
  output array<Integer> a;
algorithm
  a := arrayCreate(3, 42);
end arrMake;

public function listToArray
  input list<Integer> l;
  output array<Integer> a;
algorithm
  a := listArray(l);
end listToArray;
end Arrays;
