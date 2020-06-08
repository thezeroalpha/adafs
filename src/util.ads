package util is
  function bshift_l (n, i : Natural) return Natural is (n*(2**i));
  function bshift_r (n, i : Natural) return Natural is (n/(2**i));
end util;
