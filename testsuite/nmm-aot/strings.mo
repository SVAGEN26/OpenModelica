encapsulated package Strings
public function lenTwice
  "Runtime call stringLength, integer arithmetic."
  input String s;
  output Integer n;
algorithm
  n := 2 * stringLength(s);
end lenTwice;

public function concat3
  "Three-way concat."
  input String a;
  input String b;
  input String c;
  output String s = a + b + c;
end concat3;

public function isEmpty
  input String s;
  output Boolean b;
algorithm
  b := stringLength(s) == 0;
end isEmpty;

/* substring: stresses stringGetStringChar / substring runtime */
public function firstChar
  input String s;
  output String c;
algorithm
  c := substring(s, 1, 1);
end firstChar;
end Strings;
