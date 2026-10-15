selector:
let
  metric = name: "node_memory_${name}_bytes{${selector}}";
  macUsed = "${metric "internal"} - ${metric "purgeable"} + ${metric "wired"} + ${metric "compressed"}";
in
{
  total = "(${metric "MemTotal"} or ${metric "total"})";
  available = "(${metric "MemAvailable"} or (${metric "total"} - (${macUsed})))";
}
